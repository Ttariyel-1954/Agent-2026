# =============================================
# ARTI-2026: GPT API İnteqrasiyası (Optimallaşdırılmış)
# Retry logic, rate limiting, response caching, error handling
# =============================================

# === Konfiqurasiya ===
gpt_config <- list(
  api_url = "https://api.openai.com/v1/chat/completions",
  model = "gpt-4o",
  max_tokens = 4096,
  # Retry
  max_retries = 3,
  initial_backoff_sec = 1,
  max_backoff_sec = 30,
  # Rate limiting
  rate_limit_rpm = 60,
  rate_limit_tpm = 150000,
  # Cache
  cache_enabled = TRUE,
  cache_ttl_sec = 3600
)

# === Rate Limiter ===
.gpt_rate_state <- new.env(parent = emptyenv())
.gpt_rate_state$request_times <- numeric(0)
.gpt_rate_state$token_counts <- numeric(0)

rate_limit_check_gpt <- function() {
  now <- as.numeric(Sys.time())
  window_start <- now - 60

  valid <- .gpt_rate_state$request_times > window_start
  .gpt_rate_state$request_times <- .gpt_rate_state$request_times[valid]
  .gpt_rate_state$token_counts <- .gpt_rate_state$token_counts[valid]

  if (length(.gpt_rate_state$request_times) >= gpt_config$rate_limit_rpm) {
    oldest <- min(.gpt_rate_state$request_times)
    wait_sec <- ceiling(oldest + 60 - now)
    if (wait_sec > 0) {
      log_info("GPT rate limit: {wait_sec} saniyə gözlənilir (RPM)")
      Sys.sleep(wait_sec)
    }
  }

  total_tokens <- sum(.gpt_rate_state$token_counts)
  if (total_tokens >= gpt_config$rate_limit_tpm) {
    oldest <- min(.gpt_rate_state$request_times)
    wait_sec <- ceiling(oldest + 60 - now)
    if (wait_sec > 0) {
      log_info("GPT rate limit: {wait_sec} saniyə gözlənilir (TPM)")
      Sys.sleep(wait_sec)
    }
  }
}

rate_limit_record_gpt <- function(tokens_used = 0) {
  .gpt_rate_state$request_times <- c(.gpt_rate_state$request_times, as.numeric(Sys.time()))
  .gpt_rate_state$token_counts <- c(.gpt_rate_state$token_counts, tokens_used)
}

# === Response Cache ===
.gpt_cache <- new.env(parent = emptyenv())

cache_get_gpt <- function(key) {
  if (!gpt_config$cache_enabled) return(NULL)
  if (!exists(key, envir = .gpt_cache)) return(NULL)
  entry <- get(key, envir = .gpt_cache)
  if (as.numeric(Sys.time()) - entry$timestamp > gpt_config$cache_ttl_sec) {
    rm(list = key, envir = .gpt_cache)
    return(NULL)
  }
  entry$data
}

cache_set_gpt <- function(key, data) {
  if (!gpt_config$cache_enabled) return(invisible(NULL))
  assign(key, list(data = data, timestamp = as.numeric(Sys.time())), envir = .gpt_cache)
}

cache_clear_gpt <- function() {
  rm(list = ls(.gpt_cache), envir = .gpt_cache)
  log_info("GPT cache təmizləndi")
}

cache_stats_gpt <- function() {
  keys <- ls(.gpt_cache)
  now <- as.numeric(Sys.time())
  valid <- 0
  expired <- 0
  for (k in keys) {
    entry <- get(k, envir = .gpt_cache)
    if (now - entry$timestamp <= gpt_config$cache_ttl_sec) valid <- valid + 1
    else expired <- expired + 1
  }
  list(total = length(keys), valid = valid, expired = expired)
}

# === Xəta Təsnifatı ===
classify_gpt_error <- function(status_code, error_body = NULL) {
  error_info <- list(
    status = status_code,
    retryable = FALSE,
    category = "unknown",
    message_az = "Naməlum xəta"
  )

  if (status_code == 400) {
    error_info$category <- "bad_request"
    error_info$message_az <- "Yanlış sorğu formatı"
  } else if (status_code == 401) {
    error_info$category <- "auth_error"
    error_info$message_az <- "API açarı yanlışdır"
  } else if (status_code == 403) {
    error_info$category <- "forbidden"
    error_info$message_az <- "Bu model üçün icazə yoxdur"
  } else if (status_code == 404) {
    error_info$category <- "not_found"
    error_info$message_az <- "Model və ya endpoint tapılmadı"
  } else if (status_code == 429) {
    error_info$category <- "rate_limited"
    error_info$message_az <- "Sorğu limiti aşılıb"
    error_info$retryable <- TRUE
  } else if (status_code >= 500) {
    error_info$category <- "server_error"
    error_info$message_az <- "OpenAI server xətası"
    error_info$retryable <- TRUE
  }

  if (!is.null(error_body)) {
    error_info$api_message <- error_body$error$message %||% ""
    error_info$error_type <- error_body$error$type %||% ""
  }

  error_info
}

# === Əsas API Çağırışı ===
call_gpt_api <- function(prompt, system_prompt = NULL, max_tokens = 4096,
                          temperature = 0.7, use_cache = TRUE) {
  api_key <- Sys.getenv("GPT_API_KEY")
  if (api_key == "") {
    log_error("GPT_API_KEY mühit dəyişəni təyin edilməyib")
    return(list(success = FALSE, message = "GPT_API_KEY təyin edilməyib. .env faylını yoxlayın.",
                content = "GPT_API_KEY təyin edilməyib. .env faylını yoxlayın."))
  }

  # Cache yoxla
  if (use_cache && temperature <= 0.3) {
    cache_key <- cache_key_generate(prompt, system_prompt, max_tokens, temperature)
    cached <- cache_get_gpt(cache_key)
    if (!is.null(cached)) {
      log_info("GPT cache hit")
      return(cached)
    }
  }

  # Mesajlar
  messages <- list()
  if (!is.null(system_prompt) && nchar(system_prompt) > 0) {
    messages <- c(messages, list(list(role = "system", content = system_prompt)))
  }
  messages <- c(messages, list(list(role = "user", content = prompt)))

  body <- list(
    model = gpt_config$model,
    messages = messages,
    max_tokens = max_tokens,
    temperature = temperature
  )

  body_json <- jsonlite::toJSON(body, auto_unbox = TRUE)

  # Retry loop
  last_error <- NULL
  for (attempt in seq_len(gpt_config$max_retries)) {
    rate_limit_check_gpt()

    response <- tryCatch({
      httr::POST(
        url = gpt_config$api_url,
        httr::add_headers(
          Authorization = paste("Bearer", api_key),
          `Content-Type` = "application/json"
        ),
        body = body_json,
        encode = "raw",
        httr::timeout(240)
      )
    }, error = function(e) {
      log_error("GPT API şəbəkə xətası (cəhd {attempt}/{gpt_config$max_retries}): {e$message}")
      last_error <<- e$message
      NULL
    })

    if (is.null(response)) {
      if (attempt < gpt_config$max_retries) {
        backoff <- min(gpt_config$initial_backoff_sec * (2 ^ (attempt - 1)), gpt_config$max_backoff_sec)
        log_info("GPT retry {attempt}: {backoff}s gözlənilir...")
        Sys.sleep(backoff)
        next
      }
      return(list(
        success = FALSE,
        message = paste("API ilə əlaqə qurmaq mümkün olmadı:", last_error %||% "timeout"),
        content = paste("API ilə əlaqə qurmaq mümkün olmadı:", last_error %||% "timeout"),
        provider = "gpt",
        error_category = "network_error"
      ))
    }

    status <- httr::status_code(response)
    content_raw <- httr::content(response, as = "text", encoding = "UTF-8")

    parsed <- tryCatch(
      jsonlite::fromJSON(content_raw, simplifyVector = FALSE),
      error = function(e) NULL
    )

    if (status == 200 && !is.null(parsed)) {
      text <- parsed$choices[[1]]$message$content
      prompt_tokens <- parsed$usage$prompt_tokens %||% 0
      completion_tokens <- parsed$usage$completion_tokens %||% 0
      total_tokens_val <- parsed$usage$total_tokens %||% (prompt_tokens + completion_tokens)

      rate_limit_record_gpt(total_tokens_val)

      result <- list(
        success = TRUE,
        message = text,
        content = text,
        model = parsed$model,
        provider = "gpt",
        usage = list(
          input_tokens = prompt_tokens,
          output_tokens = completion_tokens,
          prompt_tokens = prompt_tokens,
          completion_tokens = completion_tokens,
          total_tokens = total_tokens_val
        ),
        attempt = attempt,
        cached = FALSE
      )

      if (use_cache && temperature <= 0.3) {
        cache_set_gpt(cache_key, result)
      }

      return(result)
    }

    error_info <- classify_gpt_error(status, parsed)

    if (error_info$retryable && attempt < gpt_config$max_retries) {
      backoff <- min(gpt_config$initial_backoff_sec * (2 ^ (attempt - 1)), gpt_config$max_backoff_sec)
      if (status == 429) {
        retry_after <- httr::headers(response)$`retry-after`
        if (!is.null(retry_after)) backoff <- max(as.numeric(retry_after), backoff)
      }
      log_warning("GPT API xəta {status} (cəhd {attempt}): {error_info$message_az}. {backoff}s gözlənilir...")
      Sys.sleep(backoff)
      next
    }

    log_error("GPT API xəta {status}: {error_info$message_az} | {error_info$api_message %||% ''}")
    return(list(
      success = FALSE,
      message = paste("API xətası:", error_info$message_az),
      content = paste("API xətası:", error_info$message_az),
      provider = "gpt",
      error_category = error_info$category,
      status_code = status,
      attempts = attempt
    ))
  }
}

# === Sual Generasiyası ===
generate_questions_gpt <- function(subject, grade, topic, difficulty = "orta", count = 5) {
  template <- load_prompt_template("question_generation")
  prompt <- sprintf(template, subject, grade, topic, difficulty, count)

  system_prompt <- "Sən Azərbaycan təhsil sistemi üçün sual hazırlayan ekspert müəllimsən.
Sualları Azərbaycan dilində, Bloom taksonomiyasına və DOK səviyyələrinə uyğun hazırla.
Cavabları JSON formatında qaytar."

  result <- call_gpt_api(prompt, system_prompt, temperature = 0.8)

  if (result$success) {
    questions <- tryCatch(
      extract_json_from_response(result$message),
      error = function(e) NULL
    )
    if (!is.null(questions)) {
      return(list(success = TRUE, questions = questions, usage = result$usage))
    }
  }

  list(success = FALSE, message = result$message)
}

# === Mətn Analizi ===
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

# === AI Söhbət ===
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

# === Diagnostika ===
gpt_health_check <- function() {
  tryCatch({
    result <- call_gpt_api("Salam, 1+1 nədir?", max_tokens = 50, temperature = 0, use_cache = FALSE)
    list(
      status = if (result$success) "healthy" else "unhealthy",
      provider = "gpt",
      model = gpt_config$model,
      message = if (result$success) "GPT API əlçatandır" else result$message,
      cache_stats = cache_stats_gpt(),
      rate_state = list(
        recent_requests = length(.gpt_rate_state$request_times),
        recent_tokens = sum(.gpt_rate_state$token_counts)
      )
    )
  }, error = function(e) {
    list(status = "unhealthy", provider = "gpt", message = e$message)
  })
}
