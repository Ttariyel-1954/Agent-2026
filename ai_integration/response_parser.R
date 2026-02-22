# =============================================
# ARTI-2026: AI Cavab Emalçısı (Genişləndirilmiş)
# Claude/GPT cavablarının emalı + DB saxlama
# =============================================

# === Prompt Şablonu Yüklə ===
load_prompt_template <- function(template_name) {
  template_path <- file.path("ai_integration", "prompt_templates", paste0(template_name, ".txt"))

  if (!file.exists(template_path)) {
    log_warning("Prompt şablonu tapılmadı: {template_path}")
    return("")
  }

  tryCatch(
    paste(readLines(template_path, encoding = "UTF-8", warn = FALSE), collapse = "\n"),
    error = function(e) {
      log_error("Prompt şablon oxuma xətası: {e$message}")
      ""
    }
  )
}

# === Mövcud Şablonları Siyahıla ===
list_prompt_templates <- function() {
  template_dir <- file.path("ai_integration", "prompt_templates")
  if (!dir.exists(template_dir)) return(character(0))
  files <- list.files(template_dir, pattern = "\\.txt$", full.names = FALSE)
  gsub("\\.txt$", "", files)
}

# === JSON Çıxarma (Təkmilləşdirilmiş) ===
extract_json_from_response <- function(response) {
  if (is.null(response) || !is.character(response)) return(NULL)

  # 1. ```json ... ``` bloku ((?s) — dot matches newline)
  json_match <- regmatches(response, regexpr("(?s)```json\\s*\\n(.*?)\\n\\s*```", response, perl = TRUE))
  if (length(json_match) > 0 && nchar(json_match[1]) > 0) {
    json_text <- sub("(?s)^```json\\s*\\n", "", json_match[1], perl = TRUE)
    json_text <- sub("(?s)\\n\\s*```$", "", json_text, perl = TRUE)
    result <- try_parse_json(json_text)
    if (!is.null(result)) return(result)
  }

  # 2. ``` ... ``` bloku (json etiketsiz)
  code_match <- regmatches(response, regexpr("(?s)```\\s*\\n(.*?)\\n\\s*```", response, perl = TRUE))
  if (length(code_match) > 0 && nchar(code_match[1]) > 0) {
    code_text <- sub("(?s)^```\\s*\\n", "", code_match[1], perl = TRUE)
    code_text <- sub("(?s)\\n\\s*```$", "", code_text, perl = TRUE)
    result <- try_parse_json(code_text)
    if (!is.null(result)) return(result)
  }

  # 3. Birbaşa JSON ([ və ya { ilə başlayan)
  json_text <- trimws(response)
  if (grepl("^[\\[{]", json_text)) {
    result <- try_parse_json(json_text)
    if (!is.null(result)) return(result)
  }

  # 4. Mətn içindən ən böyük JSON blokunu tap
  all_braces <- gregexpr("[{\\[]", response)[[1]]
  if (all_braces[1] != -1) {
    for (pos in all_braces) {
      substr_text <- substring(response, pos)
      result <- try_parse_json(substr_text)
      if (!is.null(result)) return(result)
    }
  }

  NULL
}

# JSON parse cəhdi (yardımçı)
try_parse_json <- function(text) {
  tryCatch(
    jsonlite::fromJSON(text, simplifyVector = TRUE),
    error = function(e) {
      # Trailing text-i kəs və yenidən cəhd et
      tryCatch({
        # Sonuncu } və ya ] tapana qədər kəs
        last_brace <- max(gregexpr("[}\\]]", text)[[1]])
        if (last_brace > 0) {
          trimmed <- substring(text, 1, last_brace)
          jsonlite::fromJSON(trimmed, simplifyVector = TRUE)
        } else NULL
      }, error = function(e2) NULL)
    }
  )
}

# === Sual Cavabı Emalı ===
parse_questions_response <- function(response) {
  if (!response$success) {
    return(data.frame(xeta = response$message %||% response$content, stringsAsFactors = FALSE))
  }

  text <- response$message %||% response$content
  questions <- extract_json_from_response(text)

  if (is.null(questions)) {
    return(data.frame(sual = text, stringsAsFactors = FALSE))
  }

  if (is.data.frame(questions)) {
    names(questions) <- tolower(names(questions))
    names(questions) <- gsub("[^a-z_]", "_", names(questions))
    return(questions)
  }

  if (is.list(questions)) {
    tryCatch(
      as.data.frame(do.call(rbind, lapply(questions, as.data.frame)), stringsAsFactors = FALSE),
      error = function(e) data.frame(sual = text, stringsAsFactors = FALSE)
    )
  } else {
    data.frame(sual = text, stringsAsFactors = FALSE)
  }
}

# === Kurikulum Analiz Emalı ===
parse_curriculum_analysis <- function(response) {
  if (!response$success) {
    return(list(
      success = FALSE,
      message = response$message %||% response$content,
      coverage = 0, gaps = character(0), recommendations = character(0)
    ))
  }

  text <- response$message %||% response$content
  json_data <- extract_json_from_response(text)

  if (!is.null(json_data)) {
    return(list(
      success = TRUE,
      coverage = json_data$coverage %||% 0,
      webb_index = json_data$webb_index %||% 0,
      gaps = json_data$gaps %||% character(0),
      redundancies = json_data$redundancies %||% character(0),
      recommendations = json_data$recommendations %||% character(0),
      overall_quality_score = json_data$overall_quality_score %||% NA,
      raw = text
    ))
  }

  list(success = TRUE, coverage = NA, gaps = character(0),
       recommendations = character(0), raw = text)
}

# === Şagird Rəyi Emalı ===
parse_student_feedback <- function(response) {
  if (!response$success) {
    return(list(success = FALSE, feedback = response$message %||% response$content))
  }

  text <- response$message %||% response$content
  feedback_html <- markdown_to_html(text)

  list(
    success = TRUE,
    feedback = text,
    feedback_html = feedback_html,
    usage = response$usage
  )
}

# === Markdown → HTML ===
markdown_to_html <- function(text) {
  if (is.null(text) || nchar(text) == 0) return("")

  html <- text
  html <- gsub("### (.+)", "<h5>\\1</h5>", html)
  html <- gsub("## (.+)", "<h4>\\1</h4>", html)
  html <- gsub("# (.+)", "<h3>\\1</h3>", html)
  html <- gsub("\\*\\*(.+?)\\*\\*", "<strong>\\1</strong>", html)
  html <- gsub("\\*(.+?)\\*", "<em>\\1</em>", html)
  html <- gsub("^- (.+)", "<li>\\1</li>", html)
  html <- gsub("(<li>.*</li>)", "<ul>\\1</ul>", html)
  html <- gsub("\n\n", "</p><p>", html)
  html <- gsub("\n", "<br>", html)

  paste0("<div class='ai-feedback'>", html, "</div>")
}

# === Ümumi AI Çağırışı (köhnə uyğunluq) ===
call_ai <- function(prompt, provider = "claude", system_prompt = NULL, temperature = 0.7) {
  if (provider == "claude") {
    call_claude_api(prompt, system_prompt, temperature = temperature)
  } else if (provider == "gpt") {
    call_gpt_api(prompt, system_prompt, temperature = temperature)
  } else {
    list(success = FALSE, message = paste("Naməlum AI provayderi:", provider),
         content = paste("Naməlum AI provayderi:", provider))
  }
}

# === Token Loqlama ===
log_token_usage <- function(provider, usage) {
  if (is.null(usage)) return(invisible(NULL))

  total <- if (provider == "claude") {
    (usage$input_tokens %||% 0) + (usage$output_tokens %||% 0)
  } else {
    usage$total_tokens %||% 0
  }

  log_info("AI token istifadəsi - Provider: {provider} | Tokens: {total}")
}

# =============================================
# AI Cavablarının DB-də Saxlanması (Supabase sxemi)
# Cədvəl: ai_responses (id, user_id, task_type, input_text,
#          output_text, model, tokens_used, response_time_ms, created_at)
# =============================================

# === Cavabı DB-yə Saxla ===
save_ai_response <- function(db_pool, provider = NULL, model = NULL, task_type,
                              prompt, system_prompt = NULL, response_text = NULL,
                              input_tokens = 0, output_tokens = 0,
                              response_time_ms = 0, status = "success",
                              error_message = NULL, user_id = NULL,
                              cached = FALSE, session_id = NULL) {
  # Giriş mətnini hazırla (prompt + system_prompt birləşdirilir)
  input_text <- if (!is.null(system_prompt) && nchar(system_prompt %||% "") > 0) {
    paste0("[system] ", substr(system_prompt, 1, 2000), "\n\n", substr(prompt %||% "", 1, 8000))
  } else {
    substr(prompt %||% "", 1, 10000)
  }

  # Çıxış mətni (uğurlu cavab və ya xəta mesajı)
  output_text <- if (status == "success" && !is.null(response_text)) {
    substr(response_text, 1, 50000)
  } else if (!is.null(error_message)) {
    paste0("[error] ", error_message)
  } else {
    NULL
  }

  # Model adına provayderi əlavə et
  model_name <- if (!is.null(model) && nchar(model) > 0) {
    substr(model, 1, 50)
  } else {
    substr(provider %||% "unknown", 1, 50)
  }

  tokens_used <- as.integer(input_tokens) + as.integer(output_tokens)

  # Təxmini xərc hesabla (Claude: $3/$15 per 1M, GPT: $2.5/$10 per 1M)
  cost <- if (!is.null(provider) && provider == "claude") {
    (as.numeric(input_tokens) * 3 + as.numeric(output_tokens) * 15) / 1e6
  } else if (!is.null(provider) && provider == "gpt") {
    (as.numeric(input_tokens) * 2.5 + as.numeric(output_tokens) * 10) / 1e6
  } else {
    (as.numeric(input_tokens) * 3 + as.numeric(output_tokens) * 15) / 1e6
  }

  tryCatch({
    db_execute(db_pool,
      "INSERT INTO ai_responses
       (user_id, task_type, input_text, output_text, model, tokens_used, response_time_ms,
        provider, status, input_tokens, output_tokens, estimated_cost, prompt_text, response_text, error_message)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)",
      params = list(
        if (!is.null(user_id) && user_id != "") user_id else NA_character_,
        task_type %||% "general",
        input_text %||% "",
        output_text %||% NA_character_,
        model_name %||% "unknown",
        as.integer(tokens_used %||% 0),
        as.integer(response_time_ms %||% 0),
        provider %||% "unknown",
        status %||% "success",
        as.integer(input_tokens %||% 0),
        as.integer(output_tokens %||% 0),
        round(cost %||% 0, 6),
        substr(prompt %||% "", 1, 10000),
        substr(response_text %||% "", 1, 50000),
        error_message %||% NA_character_
      ))
    invisible(TRUE)
  }, error = function(e) {
    log_error("AI cavab saxlama xətası: {e$message}")
    invisible(FALSE)
  })
}

# === AI İstifadə Xülasəsi ===
get_ai_usage_summary <- function(db_pool, days = 30) {
  summary <- db_get_one(db_pool,
    "SELECT
       COUNT(*) as total_requests,
       COALESCE(SUM(tokens_used), 0) as total_tokens,
       COALESCE(AVG(response_time_ms), 0) as avg_response_time,
       COALESCE(MAX(response_time_ms), 0) as max_response_time
     FROM ai_responses
     WHERE created_at >= CURRENT_DATE - $1",
    params = list(as.integer(days)))

  if (is.null(summary)) {
    return(list(total_requests = 0, total_tokens = 0,
                avg_response_time = 0, max_response_time = 0))
  }

  summary
}

# === Model üzrə Statistika ===
get_model_stats <- function(db_pool, days = 30) {
  db_query(db_pool,
    "SELECT model,
            COUNT(*) as requests,
            COALESCE(AVG(response_time_ms), 0) as avg_time_ms,
            COALESCE(SUM(tokens_used), 0) as total_tokens
     FROM ai_responses
     WHERE created_at >= CURRENT_DATE - $1
     GROUP BY model
     ORDER BY requests DESC",
    params = list(as.integer(days)))
}

# === Tapşırıq Növü Statistikası ===
get_task_type_stats <- function(db_pool, days = 30) {
  db_query(db_pool,
    "SELECT task_type,
            COUNT(*) as requests,
            COALESCE(AVG(response_time_ms), 0) as avg_time_ms,
            COALESCE(SUM(tokens_used), 0) as total_tokens
     FROM ai_responses
     WHERE created_at >= CURRENT_DATE - $1
     GROUP BY task_type
     ORDER BY requests DESC",
    params = list(as.integer(days)))
}

# === Son Cavablar ===
get_recent_ai_responses <- function(db_pool, limit = 50, task_type = NULL,
                                     model = NULL) {
  where <- "1=1"
  params <- list()
  p <- 0

  if (!is.null(task_type) && task_type != "") {
    p <- p + 1
    where <- paste(where, sprintf("AND task_type = $%d", p))
    params[[p]] <- task_type
  }
  if (!is.null(model) && model != "") {
    p <- p + 1
    where <- paste(where, sprintf("AND model = $%d", p))
    params[[p]] <- model
  }

  p <- p + 1
  query <- sprintf("
    SELECT id, model, task_type, tokens_used,
           response_time_ms, created_at,
           LEFT(input_text, 100) as input_preview,
           LEFT(output_text, 200) as output_preview
    FROM ai_responses
    WHERE %s
    ORDER BY created_at DESC
    LIMIT $%d
  ", where, p)
  params[[p]] <- limit

  db_query(db_pool, query, params = params)
}

# === Gündəlik Token Hesabatı ===
get_ai_daily_report <- function(db_pool, days = 30) {
  db_query(db_pool,
    "SELECT DATE(created_at) as date,
            model,
            COUNT(*) as requests,
            COALESCE(SUM(tokens_used), 0) as tokens,
            COALESCE(AVG(response_time_ms), 0) as avg_time_ms
     FROM ai_responses
     WHERE created_at >= CURRENT_DATE - $1
     GROUP BY DATE(created_at), model
     ORDER BY date DESC, model",
    params = list(as.integer(days)))
}

# =============================================
# Əlavə Köməkçi Funksiyalar
# analytics_chat.R və ai_tutor.R üçün
# =============================================

# === Sadə Markdown → HTML çevirici ===
simple_md_to_html <- function(text) {
  if (is.null(text) || nchar(trimws(text)) == 0) return("")

  html <- htmltools::htmlEscape(text)
  # Headers
  html <- gsub("### (.+)", "<h5>\\1</h5>", html)
  html <- gsub("## (.+)", "<h4>\\1</h4>", html)
  html <- gsub("# (.+)", "<h3>\\1</h3>", html)
  # Bold, italic
  html <- gsub("\\*\\*(.+?)\\*\\*", "<strong>\\1</strong>", html)
  html <- gsub("\\*(.+?)\\*", "<em>\\1</em>", html)
  # Code inline
  html <- gsub("`([^`]+)`", "<code>\\1</code>", html)
  # Lists
  html <- gsub("(?m)^- (.+)", "<li>\\1</li>", html, perl = TRUE)
  html <- gsub("(?m)^\\d+\\. (.+)", "<li>\\1</li>", html, perl = TRUE)
  # Paragraphs
  html <- gsub("\n\n", "</p><p>", html)
  html <- gsub("\n", "<br>", html)

  paste0("<div class='ai-response'>", html, "</div>")
}

# === Analitik Kontekst Toplama (DB-dən) ===
gather_analytics_context <- function(db_pool, user_question, school_filter = "", date_range = NULL) {
  context_parts <- c()

  # Ümumi şagird/müəllim sayı
  counts <- tryCatch({
    students <- get_total_count(db_pool, "students", "status = 'active'")
    teachers <- get_total_count(db_pool, "teachers", "status = 'active'")
    schools  <- get_total_count(db_pool, "schools", "status = 'active'")
    paste0("Ümumi: ", students, " aktiv şagird, ", teachers, " müəllim, ", schools, " məktəb.")
  }, error = function(e) "Ümumi saylar əlçatan deyil.")
  context_parts <- c(context_parts, counts)

  # Fənn orta balları
  scores <- tryCatch({
    data <- db_query(db_pool,
      "SELECT sub.name as subject_name, ROUND(AVG(g.score)::numeric, 1) as avg_score, COUNT(*) as cnt
       FROM grades g JOIN subjects sub ON g.subject_id = sub.id
       GROUP BY sub.name ORDER BY avg_score DESC LIMIT 10")
    if (nrow(data) > 0) {
      paste0("Fənn ortalamaları: ",
        paste(sprintf("%s: %.1f%% (%d qiymət)", data$subject_name, data$avg_score, data$cnt), collapse = "; "))
    } else "Fənn qiymətləri əlçatan deyil."
  }, error = function(e) "Fənn qiymətləri sorğusu uğursuz.")
  context_parts <- c(context_parts, scores)

  # Davamiyyət
  attendance <- tryCatch({
    r <- db_get_one(db_pool,
      "SELECT ROUND(COUNT(CASE WHEN status = 'present' THEN 1 END) * 100.0 / NULLIF(COUNT(*), 0), 1) as rate,
              COUNT(*) as total
       FROM attendance WHERE attendance_date >= CURRENT_DATE - INTERVAL '30 days'")
    paste0("Son 30 gün davamiyyət: ", r$rate %||% 0, "% (", r$total %||% 0, " qeyd)")
  }, error = function(e) "Davamiyyət məlumatı əlçatan deyil.")
  context_parts <- c(context_parts, attendance)

  # Məktəb filteri
  if (!is.null(school_filter) && school_filter != "") {
    school_data <- tryCatch({
      r <- db_get_one(db_pool, "SELECT name FROM schools WHERE id = $1", params = list(school_filter))
      paste0("Seçilmiş məktəb: ", r$name %||% "Naməlum")
    }, error = function(e) NULL)
    if (!is.null(school_data)) context_parts <- c(context_parts, school_data)
  }

  paste(context_parts, collapse = "\n")
}

# === AI cavabından Chart JSON çıxar ===
extract_chart_json <- function(response_text) {
  if (is.null(response_text)) return(NULL)

  # {"chart": {...}} blokunu axtar
  pattern <- '\\{\\s*"chart"\\s*:\\s*\\{.*?"data"\\s*:\\s*\\[.*?\\]\\s*\\}\\s*\\}'
  match <- regmatches(response_text, regexpr(pattern, response_text, perl = TRUE))

  if (length(match) == 0 || match == "") return(NULL)

  tryCatch({
    parsed <- jsonlite::fromJSON(match[1], simplifyVector = FALSE)
    parsed$chart
  }, error = function(e) NULL)
}

# === Chart JSON-u cavab mətnindən sil ===
remove_chart_json <- function(response_text) {
  if (is.null(response_text)) return("")

  pattern <- '\\{\\s*"chart"\\s*:\\s*\\{.*?"data"\\s*:\\s*\\[.*?\\]\\s*\\}\\s*\\}'
  cleaned <- gsub(pattern, "", response_text, perl = TRUE)
  trimws(cleaned)
}

# === Orta Performans (bütün qiymətlər) ===
get_average_performance <- function(db_pool) {
  tryCatch({
    r <- db_get_one(db_pool,
      "SELECT ROUND(AVG(score)::numeric, 1) as avg_score
       FROM grades
       WHERE created_at >= CURRENT_DATE - INTERVAL '90 days'")
    as.numeric(r$avg_score %||% 0)
  }, error = function(e) 0)
}
