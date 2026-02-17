# =============================================
# ARTI-2026: Claude API İnteqrasiyası
# Anthropic Claude API ilə əlaqə
# =============================================

#' Claude API konfiqurasiyası
claude_config <- list(
  api_url = "https://api.anthropic.com/v1/messages",
  model = "claude-sonnet-4-5-20250929",
  max_tokens = 4096,
  api_version = "2023-06-01"
)

#' Claude API-yə sorğu göndər
#' @param prompt İstifadəçi sorğusu
#' @param system_prompt Sistem promptu
#' @param max_tokens Maksimum token sayı
#' @param temperature Kreativlik parametri (0-1)
#' @return API cavabının mətni
call_claude_api <- function(prompt, system_prompt = NULL, max_tokens = 4096, temperature = 0.7) {
  api_key <- Sys.getenv("CLAUDE_API_KEY")
  if (api_key == "") {
    stop("CLAUDE_API_KEY mühit dəyişəni təyin edilməyib. .env faylını yoxlayın.")
  }

  # Sorğu gövdəsi
  body <- list(
    model = claude_config$model,
    max_tokens = max_tokens,
    temperature = temperature,
    messages = list(
      list(role = "user", content = prompt)
    )
  )

  # Sistem promptu varsa əlavə et
  if (!is.null(system_prompt) && nchar(system_prompt) > 0) {
    body$system <- system_prompt
  }

  # API sorğusu
  response <- tryCatch({
    httr::POST(
      url = claude_config$api_url,
      httr::add_headers(
        `x-api-key` = api_key,
        `anthropic-version` = claude_config$api_version,
        `content-type` = "application/json"
      ),
      body = jsonlite::toJSON(body, auto_unbox = TRUE),
      encode = "raw"
    )
  }, error = function(e) {
    log_action(NULL, "claude_api_error", details = e$message)
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
    text <- parsed$content[[1]]$text
    list(
      success = TRUE,
      message = text,
      model = parsed$model,
      usage = list(
        input_tokens = parsed$usage$input_tokens,
        output_tokens = parsed$usage$output_tokens
      )
    )
  } else {
    error_msg <- parsed$error$message %||% "Naməlum xəta"
    log_action(NULL, "claude_api_error", details = paste("Status:", status, "Xəta:", error_msg))
    list(success = FALSE, message = paste("API xətası:", error_msg))
  }
}

#' Claude ilə sual generasiyası
#' @param subject Fənn adı
#' @param grade Sinif
#' @param topic Mövzu
#' @param difficulty Çətinlik səviyyəsi
#' @param count Sual sayı
#' @return Generasiya edilmiş suallar
generate_questions_claude <- function(subject, grade, topic, difficulty = "orta", count = 5) {
  template <- load_prompt_template("question_generation")
  prompt <- sprintf(template, subject, grade, topic, difficulty, count)

  system_prompt <- "Sən Azərbaycan təhsil sistemi üçün sual hazırlayan ekspert müəllimsən.
Sualları Azərbaycan dilində, Bloom taksonomiyasına və DOK səviyyələrinə uyğun hazırla.
Cavabları JSON formatında qaytar."

  result <- call_claude_api(prompt, system_prompt, temperature = 0.8)

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

#' Claude ilə kurikulum analizi
#' @param standards Standartlar siyahısı
#' @param items Suallar siyahısı
#' @return Analiz nəticələri
analyze_curriculum_claude <- function(standards, items) {
  template <- load_prompt_template("curriculum_analysis")
  standards_text <- paste(standards, collapse = "\n")
  items_text <- paste(items, collapse = "\n")
  prompt <- sprintf(template, standards_text, items_text)

  system_prompt <- "Sən kurikulum analizi mütəxəssisisən. Standartlar və qiymətləndirmə sualları
arasındakı uyğunluğu təhlil et. Webb DOK uyğunluq indeksini hesabla."

  result <- call_claude_api(prompt, system_prompt, max_tokens = 8192, temperature = 0.3)
  result
}

#' Claude ilə şagird rəyi generasiyası
#' @param student_data Şagird məlumatları
#' @return Fərdi rəy
generate_student_feedback_claude <- function(student_data) {
  template <- load_prompt_template("student_feedback")
  prompt <- sprintf(template,
    student_data$name,
    student_data$grade,
    student_data$avg_score,
    student_data$attendance_rate,
    paste(student_data$strengths, collapse = ", "),
    paste(student_data$weaknesses, collapse = ", ")
  )

  system_prompt <- "Sən şagirdlərə fərdi rəy verən təcrübəli pedaqoqsan.
Rəyi konstruktiv, həvəsləndirici və konkret tövsiyələrlə yaz. Azərbaycan dilində cavab ver."

  call_claude_api(prompt, system_prompt, temperature = 0.6)
}

#' Claude ilə söhbət (AI Köməkçi)
#' @param messages Söhbət tarixçəsi
#' @param context Əlavə kontekst
#' @return Söhbət cavabı
chat_with_claude <- function(messages, context = NULL) {
  system_prompt <- "Sən ARTI-2026 Təhsil İdarəetmə Sisteminin AI köməkçisisən.
Azərbaycan təhsil sistemi, qiymətləndirmə, kurikulum, IRT/CAT, və pedaqogika mövzularında kömək edirsən.
Həmişə Azərbaycan dilində, peşəkar və yardımsevər tərzdə cavab ver."

  if (!is.null(context)) {
    system_prompt <- paste(system_prompt, "\n\nƏlavə kontekst:", context)
  }

  # Son mesajı prompt kimi istifadə et
  last_msg <- messages[[length(messages)]]$content

  # Əvvəlki mesajları kontekst kimi əlavə et
  if (length(messages) > 1) {
    history <- sapply(messages[-length(messages)], function(m) {
      paste0(ifelse(m$role == "user", "İstifadəçi", "Köməkçi"), ": ", m$content)
    })
    last_msg <- paste(c("Söhbət tarixçəsi:", history, "", "İstifadəçi:", last_msg), collapse = "\n")
  }

  call_claude_api(last_msg, system_prompt, temperature = 0.7)
}
