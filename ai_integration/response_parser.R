# =============================================
# ARTI-2026: AI Cavab Emalçısı
# Claude və GPT cavablarının emalı
# =============================================

#' Prompt şablonunu yüklə
#' @param template_name Şablon adı (fayl adı .txt olmadan)
#' @return Şablon mətni
load_prompt_template <- function(template_name) {
  template_path <- file.path("ai_integration", "prompt_templates", paste0(template_name, ".txt"))

  if (!file.exists(template_path)) {
    warning(paste("Prompt şablonu tapılmadı:", template_path))
    return("")
  }

  paste(readLines(template_path, encoding = "UTF-8"), collapse = "\n")
}

#' AI cavabından JSON çıxar
#' @param response AI cavab mətni
#' @return Emal edilmiş JSON və ya NULL
extract_json_from_response <- function(response) {
  if (is.null(response) || !is.character(response)) return(NULL)

  # JSON blokunu tap (```json ... ``` arasında)
  json_match <- regmatches(response, regexpr("```json\\s*\\n(.*?)\\n\\s*```", response, perl = TRUE))

  if (length(json_match) > 0) {
    json_text <- gsub("```json\\s*\\n|\\n\\s*```", "", json_match[1])
  } else {
    # Birbaşa JSON ola bilər ([ və ya { ilə başlayan)
    json_text <- trimws(response)
    if (!grepl("^[\\[{]", json_text)) return(NULL)
  }

  tryCatch(
    jsonlite::fromJSON(json_text, simplifyVector = TRUE),
    error = function(e) {
      warning(paste("JSON emal xətası:", e$message))
      NULL
    }
  )
}

#' AI cavabından sualları emal et
#' @param response AI cavabı
#' @return Suallar data frame-i
parse_questions_response <- function(response) {
  if (!response$success) {
    return(data.frame(xəta = response$message, stringsAsFactors = FALSE))
  }

  questions <- extract_json_from_response(response$message)

  if (is.null(questions)) {
    return(data.frame(sual = response$message, stringsAsFactors = FALSE))
  }

  # Standart sütun adlarına çevir
  expected_cols <- c("question_text", "option_a", "option_b", "option_c", "option_d",
                     "correct_answer", "difficulty", "bloom_level", "dok_level")

  if (is.data.frame(questions)) {
    # Sütun adlarını normallaşdır
    names(questions) <- tolower(names(questions))
    names(questions) <- gsub("[^a-z_]", "_", names(questions))
    return(questions)
  }

  if (is.list(questions)) {
    tryCatch(
      as.data.frame(do.call(rbind, lapply(questions, as.data.frame)), stringsAsFactors = FALSE),
      error = function(e) data.frame(sual = response$message, stringsAsFactors = FALSE)
    )
  } else {
    data.frame(sual = response$message, stringsAsFactors = FALSE)
  }
}

#' AI cavabından kurikulum analizini emal et
#' @param response AI cavabı
#' @return Analiz nəticələri siyahısı
parse_curriculum_analysis <- function(response) {
  if (!response$success) {
    return(list(
      success = FALSE,
      message = response$message,
      coverage = 0,
      gaps = character(0),
      recommendations = character(0)
    ))
  }

  json_data <- extract_json_from_response(response$message)

  if (!is.null(json_data)) {
    return(list(
      success = TRUE,
      coverage = json_data$coverage %||% 0,
      gaps = json_data$gaps %||% character(0),
      redundancies = json_data$redundancies %||% character(0),
      recommendations = json_data$recommendations %||% character(0),
      webb_index = json_data$webb_index %||% 0,
      raw = response$message
    ))
  }

  # JSON tapılmadısa, mətni qaytaraq
  list(
    success = TRUE,
    coverage = NA,
    gaps = character(0),
    recommendations = character(0),
    raw = response$message
  )
}

#' AI cavabından şagird rəyini emal et
#' @param response AI cavabı
#' @return Formatlanmış rəy
parse_student_feedback <- function(response) {
  if (!response$success) {
    return(list(
      success = FALSE,
      feedback = response$message
    ))
  }

  # HTML formatına çevir
  feedback_html <- markdown_to_html(response$message)

  list(
    success = TRUE,
    feedback = response$message,
    feedback_html = feedback_html,
    usage = response$usage
  )
}

#' Sadə markdown-ı HTML-ə çevir
#' @param text Markdown mətni
#' @return HTML mətni
markdown_to_html <- function(text) {
  if (is.null(text) || nchar(text) == 0) return("")

  html <- text
  # Başlıqlar
  html <- gsub("### (.+)", "<h5>\\1</h5>", html)
  html <- gsub("## (.+)", "<h4>\\1</h4>", html)
  html <- gsub("# (.+)", "<h3>\\1</h3>", html)
  # Qalın
  html <- gsub("\\*\\*(.+?)\\*\\*", "<strong>\\1</strong>", html)
  # Kursiv
  html <- gsub("\\*(.+?)\\*", "<em>\\1</em>", html)
  # Siyahı
  html <- gsub("^- (.+)", "<li>\\1</li>", html)
  html <- gsub("(<li>.*</li>)", "<ul>\\1</ul>", html)
  # Yeni sətir
  html <- gsub("\n\n", "</p><p>", html)
  html <- gsub("\n", "<br>", html)

  paste0("<div class='ai-feedback'>", html, "</div>")
}

#' Ümumi AI sorğusu (provider seçimi ilə)
#' @param prompt Sorğu mətni
#' @param provider AI provayderi ("claude" və ya "gpt")
#' @param system_prompt Sistem promptu
#' @param temperature Kreativlik
#' @return API cavabı
call_ai <- function(prompt, provider = "claude", system_prompt = NULL, temperature = 0.7) {
  if (provider == "claude") {
    call_claude_api(prompt, system_prompt, temperature = temperature)
  } else if (provider == "gpt") {
    call_gpt_api(prompt, system_prompt, temperature = temperature)
  } else {
    list(success = FALSE, message = paste("Naməlum AI provayderi:", provider))
  }
}

#' Token istifadəsini logla
#' @param provider Provayder adı
#' @param usage Token istifadə məlumatları
log_token_usage <- function(provider, usage) {
  if (is.null(usage)) return(invisible(NULL))

  total <- if (provider == "claude") {
    (usage$input_tokens %||% 0) + (usage$output_tokens %||% 0)
  } else {
    usage$total_tokens %||% 0
  }

  log_action(NULL, "ai_token_usage", details = paste(
    "Provider:", provider,
    "| Tokens:", total
  ))
}
