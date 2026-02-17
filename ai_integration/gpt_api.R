# =============================================
# ARTI-2026: GPT API İnteqrasiyası
# OpenAI GPT API ilə əlaqə
# =============================================

#' GPT API konfiqurasiyası
gpt_config <- list(
  api_url = "https://api.openai.com/v1/chat/completions",
  model = "gpt-4o",
  max_tokens = 4096
)

#' GPT API-yə sorğu göndər
#' @param prompt İstifadəçi sorğusu
#' @param system_prompt Sistem promptu
#' @param max_tokens Maksimum token sayı
#' @param temperature Kreativlik parametri (0-2)
#' @return API cavabının mətni
call_gpt_api <- function(prompt, system_prompt = NULL, max_tokens = 4096, temperature = 0.7) {
  api_key <- Sys.getenv("GPT_API_KEY")
  if (api_key == "") {
    stop("GPT_API_KEY mühit dəyişəni təyin edilməyib. .env faylını yoxlayın.")
  }

  # Mesajlar siyahısı
  messages <- list()

  if (!is.null(system_prompt) && nchar(system_prompt) > 0) {
    messages <- c(messages, list(list(role = "system", content = system_prompt)))
  }

  messages <- c(messages, list(list(role = "user", content = prompt)))

  # Sorğu gövdəsi
  body <- list(
    model = gpt_config$model,
    messages = messages,
    max_tokens = max_tokens,
    temperature = temperature
  )

  # API sorğusu
  response <- tryCatch({
    httr::POST(
      url = gpt_config$api_url,
      httr::add_headers(
        Authorization = paste("Bearer", api_key),
        `Content-Type` = "application/json"
      ),
      body = jsonlite::toJSON(body, auto_unbox = TRUE),
      encode = "raw"
    )
  }, error = function(e) {
    log_action(NULL, "gpt_api_error", details = e$message)
    return(NULL)
  })

  if (is.null(response)) {
    return(list(success = FALSE, message = "API ilə əlaqə qurmaq mümkün olmadı."))
  }

  # Cavabı emal et
  status <- httr::status_code(response)
  content <- httr::content(response, as = "text", encoding = "UTF-8")
  parsed <- jsonlite::fromJSON(content, simplifyVector = FALSE)

  if (status == 200) {
    text <- parsed$choices[[1]]$message$content
    list(
      success = TRUE,
      message = text,
      model = parsed$model,
      usage = list(
        prompt_tokens = parsed$usage$prompt_tokens,
        completion_tokens = parsed$usage$completion_tokens,
        total_tokens = parsed$usage$total_tokens
      )
    )
  } else {
    error_msg <- parsed$error$message %||% "Naməlum xəta"
    log_action(NULL, "gpt_api_error", details = paste("Status:", status, "Xəta:", error_msg))
    list(success = FALSE, message = paste("API xətası:", error_msg))
  }
}

#' GPT ilə sual generasiyası
#' @param subject Fənn adı
#' @param grade Sinif
#' @param topic Mövzu
#' @param difficulty Çətinlik səviyyəsi
#' @param count Sual sayı
#' @return Generasiya edilmiş suallar
generate_questions_gpt <- function(subject, grade, topic, difficulty = "orta", count = 5) {
  template <- load_prompt_template("question_generation")
  prompt <- sprintf(template, subject, grade, topic, difficulty, count)

  system_prompt <- "Sən Azərbaycan təhsil sistemi üçün sual hazırlayan ekspert müəllimsən.
Sualları Azərbaycan dilində, Bloom taksonomiyasına və DOK səviyyələrinə uyğun hazırla.
Cavabları JSON formatında qaytar."

  result <- call_gpt_api(prompt, system_prompt, temperature = 0.8)

  if (result$success) {
    questions <- tryCatch(
      jsonlite::fromJSON(result$message),
      error = function(e) NULL
    )
    if (!is.null(questions)) {
      return(list(success = TRUE, questions = questions))
    }
  }

  list(success = FALSE, message = result$message)
}

#' GPT ilə mətn analizi
#' @param text Analiz ediləcək mətn
#' @param analysis_type Analiz növü
#' @return Analiz nəticələri
analyze_text_gpt <- function(text, analysis_type = "general") {
  system_prompts <- list(
    general = "Verilmiş mətni təhlil et və əsas fikirləri çıxar.",
    grammar = "Verilmiş Azərbaycan dilindəki mətndə qrammatik səhvləri tap və düzəlişlər təklif et.",
    readability = "Mətni oxunaqlılıq baxımından təhlil et. Flesch-Kincaid ekvivalent hesabla.",
    bloom = "Mətndəki sualları Bloom taksonomiyasına görə təsnif et."
  )

  system_prompt <- system_prompts[[analysis_type]] %||% system_prompts$general
  call_gpt_api(text, system_prompt, temperature = 0.3)
}

#' GPT ilə söhbət
#' @param messages Söhbət tarixçəsi
#' @param context Əlavə kontekst
#' @return Söhbət cavabı
chat_with_gpt <- function(messages, context = NULL) {
  system_prompt <- "Sən ARTI-2026 Təhsil İdarəetmə Sisteminin AI köməkçisisən.
Azərbaycan təhsil sistemi, qiymətləndirmə, kurikulum, IRT/CAT, və pedaqogika mövzularında kömək edirsən.
Həmişə Azərbaycan dilində, peşəkar və yardımsevər tərzdə cavab ver."

  if (!is.null(context)) {
    system_prompt <- paste(system_prompt, "\n\nƏlavə kontekst:", context)
  }

  last_msg <- messages[[length(messages)]]$content

  if (length(messages) > 1) {
    history <- sapply(messages[-length(messages)], function(m) {
      paste0(ifelse(m$role == "user", "İstifadəçi", "Köməkçi"), ": ", m$content)
    })
    last_msg <- paste(c("Söhbət tarixçəsi:", history, "", "İstifadəçi:", last_msg), collapse = "\n")
  }

  call_gpt_api(last_msg, system_prompt, temperature = 0.7)
}
