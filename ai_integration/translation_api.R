# =============================================
# ARTI-2026: AI Tərcümə API
# Kontekstli tərcümə sistemi
# =============================================

#' Bloom taksonomiyası ingilis-azərbaycan xəritəsi
BLOOM_EN_TO_AZ <- c(
  "Remembering"   = "Bilmə",
  "Understanding" = "Anlama",
  "Applying"      = "Tətbiq",
  "Analyzing"     = "Təhlil",
  "Evaluating"    = "Qiymətləndirmə",
  "Creating"      = "Sintez"
)

#' Terminologiya lüğətindən uyğun terminləri çək
#' @param domain Sahə (curriculum, assessment, pisa, pedagogy, irt, general)
#' @param source_lang Mənbə dili
#' @param target_lang Hədəf dili
#' @param subject_id Fənn ID-si (opsional)
#' @param db_pool Verilənlər bazası pool-u
#' @return data.frame: source_term, target_term, confidence
get_terminology <- function(domain, source_lang = "en", target_lang = "az",
                            subject_id = NULL, db_pool) {
  query <- "SELECT source_term, target_term, confidence
            FROM translation_terminology
            WHERE (domain = $1 OR domain = 'general')
              AND source_lang = $2 AND target_lang = $3"
  params <- list(domain, source_lang, target_lang)
  idx <- 4

  if (!is.null(subject_id) && !is_empty(subject_id)) {
    query <- paste0(query, " AND (subject_id = $", idx, " OR subject_id IS NULL)")
    params[[idx]] <- subject_id
  }

  query <- paste0(query, " ORDER BY is_verified DESC, confidence DESC")

  tryCatch(
    db_query(db_pool, query, params = params),
    error = function(e) {
      log_error("Terminologiya sorğusu xətası: {e$message}")
      data.frame(source_term = character(0), target_term = character(0),
                 confidence = numeric(0), stringsAsFactors = FALSE)
    }
  )
}

#' Tərcümə promptu yarat
#' @param text Tərcümə ediləcək mətn
#' @param context Kontekst siyahısı (type, source_lang, target_lang, subject, grade, bloom, dok, options, correct_answer, subject_area)
#' @param terminology_df Terminologiya data.frame-i
#' @return Formatlanmış prompt mətni
build_translation_prompt <- function(text, context, terminology_df) {
  # Terminləri glossary formatına çevir
  glossary <- ""
  if (!is.null(terminology_df) && nrow(terminology_df) > 0) {
    glossary <- paste(
      sprintf("- %s -> %s", terminology_df$source_term, terminology_df$target_term),
      collapse = "\n"
    )
  }
  if (nchar(glossary) == 0) glossary <- "(Lüğət boşdur)"

  template_name <- paste0("translation_", context$type %||% "curriculum")
  template <- load_prompt_template(template_name)

  if (nchar(template) == 0) {
    # Fallback: birbaşa prompt yarat
    return(paste0(
      "Aşağıdakı mətni ", context$source_lang %||% "en", " dilindən ",
      context$target_lang %||% "az", " dilinə tərcümə et.\n\n",
      "Terminologiya lüğəti:\n", glossary, "\n\n",
      "Mətn:\n", text, "\n\n",
      "Cavabı JSON formatında qaytar: {\"translated_text\": \"...\", \"notes\": \"...\"}"
    ))
  }

  # Template-ə görə format
  if (context$type == "curriculum") {
    sprintf(template,
      context$source_lang %||% "en",
      context$target_lang %||% "az",
      context$subject %||% "",
      context$grade %||% "",
      context$bloom %||% "",
      context$dok %||% "",
      glossary,
      text
    )
  } else if (context$type == "research") {
    sprintf(template,
      context$source_lang %||% "en",
      context$subject_area %||% "təhsil",
      glossary,
      text
    )
  } else if (context$type == "pisa") {
    options <- context$options %||% list("", "", "", "")
    sprintf(template,
      context$subject %||% "",
      context$grade %||% "",
      glossary,
      text,
      options[[1]] %||% "",
      options[[2]] %||% "",
      options[[3]] %||% "",
      options[[4]] %||% "",
      context$correct_answer %||% ""
    )
  } else {
    sprintf(template, glossary, text)
  }
}

#' Tərcümə cavabını emal et
#' @param response API cavabı
#' @return Emal edilmiş list və ya NULL
parse_translation_response <- function(response) {
  if (is.null(response) || !response$success) return(NULL)

  parsed <- extract_json_from_response(response$message)

  if (!is.null(parsed)) return(parsed)

  # Fallback: raw mətni qaytaraq
  list(translated_text = response$message, notes = "JSON emal edilmədi, raw mətn qaytarıldı")
}

#' Tərcümə tarixçəsinə yaz
#' @return UUID və ya NULL
save_translation_history <- function(source_text, translated_text, source_lang, target_lang,
                                      translation_type, domain, subject_id, tokens_used,
                                      model_used, created_by, db_pool) {
  tryCatch({
    history_id <- generate_uuid()
    db_execute(db_pool,
      "INSERT INTO translation_history
       (id, source_text, translated_text, source_lang, target_lang,
        translation_type, domain, subject_id, tokens_used, model_used, created_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)",
      params = list(
        history_id, source_text, translated_text, source_lang, target_lang,
        translation_type, domain %||% "general", subject_id,
        tokens_used %||% 0L, model_used %||% claude_config$model, created_by
      )
    )
    history_id
  }, error = function(e) {
    log_error("Tərcümə tarixçəsi yazma xətası: {e$message}")
    NULL
  })
}

#' Əsas tərcümə funksiyası — kontekstli tərcümə
#' @param text Tərcümə ediləcək mətn
#' @param source_lang Mənbə dili (default: "en")
#' @param target_lang Hədəf dili (default: "az")
#' @param domain Sahə (curriculum, assessment, pisa, pedagogy, irt, general)
#' @param subject Fənn adı (opsional)
#' @param subject_id Fənn UUID (opsional)
#' @param context Əlavə kontekst siyahısı
#' @param db_pool Verilənlər bazası pool-u
#' @param user_id İstifadəçi ID-si
#' @return list(success, translated_text, terms_used, notes, usage, history_id)
translate_with_context <- function(text, source_lang = "en", target_lang = "az",
                                    domain = "general", subject = NULL, subject_id = NULL,
                                    context = list(), db_pool, user_id = NULL) {
  if (is_empty(text)) {
    return(list(success = FALSE, message = "Tərcümə üçün mətn daxil edilməyib"))
  }

  # 1. Terminologiyanı al
  terminology <- get_terminology(domain, source_lang, target_lang, subject_id, db_pool)

  # 2. Promptu yarat
  ctx <- modifyList(list(
    type = "general",
    source_lang = source_lang,
    target_lang = target_lang,
    subject = subject
  ), context)

  prompt <- build_translation_prompt(text, ctx, terminology)

  # 3. Sistem promptu
  system_prompt <- paste0(
    "Sən təhsil sahəsində ixtisaslaşmış peşəkar tərcüməçisən. ",
    "Tərcümələrini terminologiya lüğətinə uyğun aparırsan. ",
    "Cavabı YALNIZ düzgün JSON formatında qaytar, başqa heç nə yazma."
  )

  # 4. Claude API çağırışı
  result <- tryCatch(
    call_claude_api(prompt, system_prompt,
                    max_tokens = context$max_tokens %||% 4096,
                    temperature = context$temperature %||% 0.3),
    error = function(e) list(success = FALSE, message = e$message)
  )

  if (!result$success) {
    return(list(success = FALSE, message = result$message))
  }

  # 5. Cavabı emal et
  parsed <- parse_translation_response(result)

  if (is.null(parsed)) {
    return(list(success = FALSE, message = "API cavabı emal edilə bilmədi"))
  }

  translated_text <- parsed$translated_text %||% ""

  # 6. Tarixçəyə yaz
  tokens_total <- (result$usage$input_tokens %||% 0) + (result$usage$output_tokens %||% 0)
  history_id <- save_translation_history(
    source_text = text,
    translated_text = translated_text,
    source_lang = source_lang,
    target_lang = target_lang,
    translation_type = ctx$type %||% "general",
    domain = domain,
    subject_id = subject_id,
    tokens_used = tokens_total,
    model_used = result$model,
    created_by = user_id,
    db_pool = db_pool
  )

  # 7. Token istifadəsini logla
  log_token_usage("claude", result$usage)

  list(
    success = TRUE,
    translated_text = translated_text,
    terms_used = parsed$terms_used %||% parsed$key_terms %||% list(),
    notes = parsed$notes %||% "",
    usage = result$usage,
    history_id = history_id,
    raw = parsed
  )
}

#' Kurikulum standartını tərcümə et
#' @param standard_text Standart mətni
#' @param subject Fənn adı
#' @param grade Sinif
#' @param source_lang Mənbə dili
#' @param target_lang Hədəf dili
#' @param bloom_level Bloom səviyyəsi (ingilis dilində)
#' @param dok_level DOK səviyyəsi
#' @param db_pool Verilənlər bazası pool-u
#' @param user_id İstifadəçi ID-si
#' @return list(success, translated_text, bloom_az, dok_level, terms_used, notes, history_id)
translate_curriculum_standard <- function(standard_text, subject, grade,
                                          source_lang = "en", target_lang = "az",
                                          bloom_level = NULL, dok_level = NULL,
                                          db_pool, user_id = NULL) {
  # Bloom səviyyəsini AZ-a map et
  bloom_az <- BLOOM_EN_TO_AZ[bloom_level] %||% bloom_level %||% ""

  # Subject ID-ni al
  subject_id <- NULL
  if (!is_empty(subject)) {
    subj <- db_get_one(db_pool, "SELECT id FROM subjects WHERE name = $1", params = list(subject))
    subject_id <- subj$id
  }

  context <- list(
    type = "curriculum",
    subject = subject,
    grade = grade,
    bloom = bloom_level %||% "",
    dok = dok_level %||% "",
    temperature = 0.3
  )

  result <- translate_with_context(
    text = standard_text,
    source_lang = source_lang,
    target_lang = target_lang,
    domain = "curriculum",
    subject = subject,
    subject_id = subject_id,
    context = context,
    db_pool = db_pool,
    user_id = user_id
  )

  if (result$success) {
    result$bloom_az <- result$raw$bloom_az %||% bloom_az
    result$dok_level <- result$raw$dok_level %||% dok_level
  }

  result
}

#' Tədqiqat mətnini tərcümə et
#' @param text Tədqiqat mətni
#' @param subject_area Tədqiqat sahəsi
#' @param source_lang Mənbə dili
#' @param db_pool Verilənlər bazası pool-u
#' @param user_id İstifadəçi ID-si
#' @return list(success, translated_text, key_terms, abbreviations, notes, history_id)
translate_research_text <- function(text, subject_area = "təhsil",
                                     source_lang = "en", db_pool, user_id = NULL) {
  # Sahəyə görə domain müəyyən et
  domain <- switch(tolower(subject_area),
    "pisa" = "pisa",
    "timss" = "pisa",
    "pirls" = "pisa",
    "qiymətləndirmə" = "assessment",
    "assessment" = "assessment",
    "irt" = "irt",
    "item response theory" = "irt",
    "pedagogy"
  )

  context <- list(
    type = "research",
    subject_area = subject_area,
    max_tokens = 8192,
    temperature = 0.3
  )

  result <- translate_with_context(
    text = text,
    source_lang = source_lang,
    target_lang = "az",
    domain = domain,
    context = context,
    db_pool = db_pool,
    user_id = user_id
  )

  if (result$success) {
    result$key_terms <- result$raw$key_terms %||% list()
    result$abbreviations <- result$raw$abbreviations %||% list()
  }

  result
}

#' PISA sualını lokalizasiya et
#' @param item_text Sual mətni
#' @param options 4 variant siyahısı
#' @param correct_answer Düzgün cavab hərfi
#' @param subject PISA fənni
#' @param grade Sinif
#' @param db_pool Verilənlər bazası pool-u
#' @param user_id İstifadəçi ID-si
#' @return list(success, localized_text, localized_options, correct_answer, adaptation_notes, difficulty_preserved, history_id)
localize_pisa_item <- function(item_text, options = list("", "", "", ""),
                                correct_answer = "A", subject = "Riyaziyyat",
                                grade = 8, db_pool, user_id = NULL) {
  context <- list(
    type = "pisa",
    subject = subject,
    grade = grade,
    options = options,
    correct_answer = correct_answer,
    temperature = 0.4
  )

  result <- translate_with_context(
    text = item_text,
    source_lang = "en",
    target_lang = "az",
    domain = "pisa",
    context = context,
    db_pool = db_pool,
    user_id = user_id
  )

  if (result$success) {
    result$localized_text <- result$raw$localized_text %||% result$translated_text
    result$localized_options <- result$raw$localized_options %||% list()
    result$correct_answer <- result$raw$correct_answer %||% correct_answer
    result$adaptation_notes <- result$raw$adaptation_notes %||% list()
    result$difficulty_preserved <- result$raw$difficulty_preserved %||% TRUE
  }

  result
}

#' Toplu tərcümə
#' @param texts Mətnlər vektoru
#' @param source_lang Mənbə dili
#' @param target_lang Hədəf dili
#' @param domain Sahə
#' @param subject_id Fənn ID-si
#' @param db_pool Verilənlər bazası pool-u
#' @param user_id İstifadəçi ID-si
#' @param progress_callback Progress funksiyası (opsional)
#' @return Nəticələr siyahısı
batch_translate <- function(texts, source_lang = "en", target_lang = "az",
                             domain = "curriculum", subject_id = NULL,
                             db_pool, user_id = NULL, progress_callback = NULL) {
  results <- list()
  total <- length(texts)

  for (i in seq_along(texts)) {
    if (!is.null(progress_callback)) {
      progress_callback(value = i / total,
                        message = sprintf("Tərcümə edilir: %d / %d", i, total))
    }

    results[[i]] <- tryCatch(
      translate_with_context(
        text = texts[i],
        source_lang = source_lang,
        target_lang = target_lang,
        domain = domain,
        subject_id = subject_id,
        context = list(type = ifelse(domain == "pisa", "pisa", "curriculum"),
                        temperature = 0.3),
        db_pool = db_pool,
        user_id = user_id
      ),
      error = function(e) {
        list(success = FALSE, message = e$message, original = texts[i])
      }
    )

    # Rate limiting
    if (i < total) Sys.sleep(0.5)
  }

  results
}
