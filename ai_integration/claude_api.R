# =============================================
# ARTI-2026: Claude API İnteqrasiyası (Optimallaşdırılmış v2)
# Retry logic (3x + jitter), rate limiting (10 RPM),
# response caching (24 saat TTL), strukturlaşdırılmış logging
# =============================================

# === Konfiqurasiya ===
claude_config <- list(
  api_url = "https://api.anthropic.com/v1/messages",
  model = "claude-sonnet-4-5-20250929",
  max_tokens = 4096,
  api_version = "2023-06-01",
  # Retry parametrləri
  max_retries = 3,
  initial_backoff_sec = 1,
  max_backoff_sec = 30,
  # Rate limiting (dəqiqədə max 10 sorğu)
  rate_limit_rpm = 10,
  rate_limit_tpm = 100000,
  # Cache (24 saat = 86400 saniyə)
  cache_enabled = TRUE,
  cache_ttl_sec = 86400
)

# === Rate Limiter ===
.claude_rate_state <- new.env(parent = emptyenv())
.claude_rate_state$request_times <- numeric(0)
.claude_rate_state$token_counts <- numeric(0)

rate_limit_check_claude <- function() {
  now <- as.numeric(Sys.time())
  window_start <- now - 60

  # Köhnə qeydləri təmizlə
  valid <- .claude_rate_state$request_times > window_start
  .claude_rate_state$request_times <- .claude_rate_state$request_times[valid]
  .claude_rate_state$token_counts <- .claude_rate_state$token_counts[valid]

  # RPM yoxla
  if (length(.claude_rate_state$request_times) >= claude_config$rate_limit_rpm) {
    oldest <- min(.claude_rate_state$request_times)
    wait_sec <- ceiling(oldest + 60 - now)
    if (wait_sec > 0) {
      log_info("Claude rate limit: {wait_sec} saniyə gözlənilir (RPM)")
      Sys.sleep(wait_sec)
    }
  }

  # TPM yoxla
  total_tokens <- sum(.claude_rate_state$token_counts)
  if (total_tokens >= claude_config$rate_limit_tpm) {
    oldest <- min(.claude_rate_state$request_times)
    wait_sec <- ceiling(oldest + 60 - now)
    if (wait_sec > 0) {
      log_info("Claude rate limit: {wait_sec} saniyə gözlənilir (TPM)")
      Sys.sleep(wait_sec)
    }
  }
}

rate_limit_record_claude <- function(tokens_used = 0) {
  .claude_rate_state$request_times <- c(.claude_rate_state$request_times, as.numeric(Sys.time()))
  .claude_rate_state$token_counts <- c(.claude_rate_state$token_counts, tokens_used)
}

# Cari rate limit vəziyyəti (monitorinq üçün)
rate_limit_status_claude <- function() {
  now <- as.numeric(Sys.time())
  valid <- .claude_rate_state$request_times > (now - 60)
  list(
    requests_last_minute = sum(valid),
    tokens_last_minute = sum(.claude_rate_state$token_counts[valid]),
    rpm_limit = claude_config$rate_limit_rpm,
    remaining = max(0, claude_config$rate_limit_rpm - sum(valid))
  )
}

# === Response Cache ===
.claude_cache <- new.env(parent = emptyenv())

cache_key_generate <- function(prompt, system_prompt, max_tokens, temperature) {
  input <- paste(prompt, system_prompt %||% "", max_tokens, temperature, sep = "|")
  digest::digest(input, algo = "md5")
}

cache_get_claude <- function(key) {
  if (!claude_config$cache_enabled) return(NULL)
  if (!exists(key, envir = .claude_cache)) return(NULL)
  entry <- get(key, envir = .claude_cache)
  # TTL yoxla
  if (as.numeric(Sys.time()) - entry$timestamp > claude_config$cache_ttl_sec) {
    rm(list = key, envir = .claude_cache)
    return(NULL)
  }
  entry$data
}

cache_set_claude <- function(key, data) {
  if (!claude_config$cache_enabled) return(invisible(NULL))
  # Cache həddini yoxla (max 500 giriş), köhnələri təmizlə
  keys <- ls(.claude_cache)
  if (length(keys) >= 500) {
    now <- as.numeric(Sys.time())
    expired <- vapply(keys, function(k) {
      entry <- get(k, envir = .claude_cache)
      (now - entry$timestamp) > claude_config$cache_ttl_sec
    }, logical(1))
    if (any(expired)) {
      rm(list = keys[expired], envir = .claude_cache)
    } else {
      # Ən köhnə 100 girişi sil
      ages <- vapply(keys, function(k) get(k, envir = .claude_cache)$timestamp, numeric(1))
      oldest <- names(sort(ages))[1:100]
      rm(list = oldest, envir = .claude_cache)
    }
  }
  assign(key, list(data = data, timestamp = as.numeric(Sys.time())), envir = .claude_cache)
}

cache_clear_claude <- function() {
  rm(list = ls(.claude_cache), envir = .claude_cache)
  log_info("Claude cache təmizləndi")
}

cache_stats_claude <- function() {
  keys <- ls(.claude_cache)
  now <- as.numeric(Sys.time())
  valid <- 0
  expired <- 0
  for (k in keys) {
    entry <- get(k, envir = .claude_cache)
    if (now - entry$timestamp <= claude_config$cache_ttl_sec) {
      valid <- valid + 1
    } else {
      expired <- expired + 1
    }
  }
  list(total = length(keys), valid = valid, expired = expired)
}

# === Xəta təsnifatı ===
classify_api_error <- function(status_code, error_body = NULL) {
  error_info <- list(
    status = status_code,
    retryable = FALSE,
    category = "unknown",
    message_az = "Naməlum xəta"
  )

  if (status_code == 400) {
    error_info$category <- "bad_request"
    error_info$message_az <- "Yanlış sorğu formatı"
    error_info$retryable <- FALSE
  } else if (status_code == 401) {
    error_info$category <- "auth_error"
    error_info$message_az <- "API açarı yanlışdır və ya müddəti bitib"
    error_info$retryable <- FALSE
  } else if (status_code == 403) {
    error_info$category <- "forbidden"
    error_info$message_az <- "Bu əməliyyat üçün icazə yoxdur"
    error_info$retryable <- FALSE
  } else if (status_code == 404) {
    error_info$category <- "not_found"
    error_info$message_az <- "API endpoint tapılmadı"
    error_info$retryable <- FALSE
  } else if (status_code == 429) {
    error_info$category <- "rate_limited"
    error_info$message_az <- "Sorğu limiti aşılıb, bir az gözləyin"
    error_info$retryable <- TRUE
  } else if (status_code == 500) {
    error_info$category <- "server_error"
    error_info$message_az <- "Anthropic server xətası"
    error_info$retryable <- TRUE
  } else if (status_code == 502 || status_code == 503) {
    error_info$category <- "service_unavailable"
    error_info$message_az <- "Anthropic xidməti müvəqqəti əlçatan deyil"
    error_info$retryable <- TRUE
  } else if (status_code == 529) {
    error_info$category <- "overloaded"
    error_info$message_az <- "Anthropic API həddən artıq yüklənib"
    error_info$retryable <- TRUE
  }

  if (!is.null(error_body)) {
    error_info$api_message <- error_body$error$message %||% ""
    error_info$error_type <- error_body$error$type %||% ""
  }

  error_info
}

# === Əsas API Çağırışı (retry 3x + jitter, rate limit 10 RPM, cache 24h, logging) ===
call_claude_api <- function(prompt, system_prompt = NULL, max_tokens = 4096,
                             temperature = 0.7, use_cache = TRUE,
                             task_type = "general", db_pool = NULL, user_id = NULL) {
  call_start <- proc.time()["elapsed"]
  call_id <- substr(digest::digest(paste(Sys.time(), sample(1e6, 1)), algo = "md5"), 1, 8)
  prompt_preview <- substr(prompt, 1, 80)

  log_info("[{call_id}] Claude API çağırışı başladı | task={task_type} | temp={temperature} | max_tokens={max_tokens} | prompt=\"{prompt_preview}...\"")

  api_key <- Sys.getenv("CLAUDE_API_KEY")
  if (api_key == "") {
    log_error("[{call_id}] CLAUDE_API_KEY mühit dəyişəni təyin edilməyib")
    return(list(success = FALSE, message = "CLAUDE_API_KEY təyin edilməyib. .env faylını yoxlayın.",
                content = "CLAUDE_API_KEY təyin edilməyib. .env faylını yoxlayın."))
  }

  # Cache yoxla (bütün sorğular üçün — eyni prompt+system+params = eyni cavab)
  cache_key <- NULL
  if (use_cache && claude_config$cache_enabled) {
    cache_key <- cache_key_generate(prompt, system_prompt, max_tokens, temperature)
    cached <- cache_get_claude(cache_key)
    if (!is.null(cached)) {
      elapsed_ms <- round((proc.time()["elapsed"] - call_start) * 1000)
      log_info("[{call_id}] Cache HIT | sürmüşdür={elapsed_ms}ms | key={substr(cache_key, 1, 12)}")
      cached$cached <- TRUE
      # DB-yə cache hit-i logla
      .log_to_db(db_pool, "claude", claude_config$model, task_type, prompt, system_prompt,
                 cached$content, cached$usage$input_tokens %||% 0, cached$usage$output_tokens %||% 0,
                 elapsed_ms, "success", NULL, user_id, TRUE)
      return(cached)
    }
    log_info("[{call_id}] Cache MISS | key={substr(cache_key, 1, 12)}")
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

  if (!is.null(system_prompt) && nchar(system_prompt) > 0) {
    body$system <- system_prompt
  }

  body_json <- jsonlite::toJSON(body, auto_unbox = TRUE)

  # Retry loop (3 cəhd, eksponensial backoff + jitter)
  last_error <- NULL
  for (attempt in seq_len(claude_config$max_retries)) {
    # Rate limit yoxla (dəqiqədə max 10 sorğu)
    rate_limit_check_claude()

    attempt_start <- proc.time()["elapsed"]
    log_info("[{call_id}] Cəhd {attempt}/{claude_config$max_retries} göndərilir...")

    response <- tryCatch({
      httr::POST(
        url = claude_config$api_url,
        httr::add_headers(
          `x-api-key` = api_key,
          `anthropic-version` = claude_config$api_version,
          `content-type` = "application/json"
        ),
        body = body_json,
        encode = "raw",
        httr::timeout(240)
      )
    }, error = function(e) {
      log_error("[{call_id}] Şəbəkə xətası (cəhd {attempt}): {e$message}")
      last_error <<- e$message
      NULL
    })

    attempt_ms <- round((proc.time()["elapsed"] - attempt_start) * 1000)

    # Şəbəkə xətası — retry ilə
    if (is.null(response)) {
      if (attempt < claude_config$max_retries) {
        backoff <- .calculate_backoff(attempt)
        log_info("[{call_id}] Retry {attempt}: {round(backoff, 1)}s gözlənilir (şəbəkə xətası)...")
        Sys.sleep(backoff)
        next
      }
      elapsed_ms <- round((proc.time()["elapsed"] - call_start) * 1000)
      log_error("[{call_id}] Bütün cəhdlər tükəndi | cəmi={elapsed_ms}ms | xəta={last_error %||% 'timeout'}")
      fail_result <- list(
        success = FALSE,
        message = paste("API ilə əlaqə qurmaq mümkün olmadı:", last_error %||% "timeout"),
        content = paste("API ilə əlaqə qurmaq mümkün olmadı:", last_error %||% "timeout"),
        provider = "claude",
        error_category = "network_error",
        attempts = attempt
      )
      .log_to_db(db_pool, "claude", claude_config$model, task_type, prompt, system_prompt,
                 NULL, 0, 0, elapsed_ms, "error", last_error %||% "timeout", user_id, FALSE)
      return(fail_result)
    }

    status <- httr::status_code(response)
    content_raw <- httr::content(response, as = "text", encoding = "UTF-8")

    parsed <- tryCatch(
      jsonlite::fromJSON(content_raw, simplifyVector = FALSE),
      error = function(e) NULL
    )

    # Uğurlu cavab
    if (status == 200 && !is.null(parsed)) {
      text <- parsed$content[[1]]$text
      input_tokens <- parsed$usage$input_tokens %||% 0
      output_tokens <- parsed$usage$output_tokens %||% 0
      total_tokens <- input_tokens + output_tokens
      elapsed_ms <- round((proc.time()["elapsed"] - call_start) * 1000)

      # Rate limit qeydiyyat
      rate_limit_record_claude(total_tokens)

      log_info("[{call_id}] UĞURLU | cəhd={attempt} | status=200 | tokens={total_tokens} (in={input_tokens}, out={output_tokens}) | sürmüşdür={elapsed_ms}ms | model={parsed$model}")

      result <- list(
        success = TRUE,
        message = text,
        content = text,
        model = parsed$model,
        provider = "claude",
        usage = list(
          input_tokens = input_tokens,
          output_tokens = output_tokens,
          total_tokens = total_tokens
        ),
        attempt = attempt,
        cached = FALSE,
        response_time_ms = elapsed_ms
      )

      # Cache saxla (eyni sorğu 24 saat ərzində cache-dən)
      if (use_cache && !is.null(cache_key)) {
        cache_set_claude(cache_key, result)
        log_info("[{call_id}] Cache-ə yazıldı | key={substr(cache_key, 1, 12)} | TTL={claude_config$cache_ttl_sec}s")
      }

      # DB-yə logla
      .log_to_db(db_pool, "claude", parsed$model, task_type, prompt, system_prompt,
                 text, input_tokens, output_tokens, elapsed_ms, "success", NULL, user_id, FALSE)

      return(result)
    }

    # Xəta analizi
    error_info <- classify_api_error(status, parsed)
    log_warning("[{call_id}] HTTP {status} | category={error_info$category} | retryable={error_info$retryable} | msg={error_info$message_az} | cəhd_vaxtı={attempt_ms}ms")

    if (error_info$retryable && attempt < claude_config$max_retries) {
      backoff <- .calculate_backoff(attempt)
      # 429 üçün Retry-After header yoxla
      if (status == 429) {
        retry_after <- httr::headers(response)$`retry-after`
        if (!is.null(retry_after)) {
          backoff <- max(as.numeric(retry_after), backoff)
        }
      }
      log_info("[{call_id}] Retry {attempt}: {round(backoff, 1)}s gözlənilir (HTTP {status})...")
      Sys.sleep(backoff)
      next
    }

    # Retry tükəndi və ya retryable deyil
    elapsed_ms <- round((proc.time()["elapsed"] - call_start) * 1000)
    log_error("[{call_id}] UĞURSUZ | HTTP {status} | {error_info$message_az} | api_msg={error_info$api_message %||% ''} | cəmi={elapsed_ms}ms | cəhdlər={attempt}")

    fail_result <- list(
      success = FALSE,
      message = paste("API xətası:", error_info$message_az),
      content = paste("API xətası:", error_info$message_az),
      provider = "claude",
      error_category = error_info$category,
      status_code = status,
      attempts = attempt,
      response_time_ms = elapsed_ms
    )

    .log_to_db(db_pool, "claude", claude_config$model, task_type, prompt, system_prompt,
               NULL, 0, 0, elapsed_ms, "error", error_info$message_az, user_id, FALSE)

    return(fail_result)
  }
}

# === Backoff hesablama (eksponensial + jitter) ===
.calculate_backoff <- function(attempt) {
  base <- min(claude_config$initial_backoff_sec * (2 ^ (attempt - 1)), claude_config$max_backoff_sec)
  jitter <- runif(1, 0, base * 0.3)
  base + jitter
}

# === DB Loglama (hər çağırış üçün, uğursuzluq API-ni bloklamır) ===
.log_to_db <- function(db_pool, provider, model, task_type, prompt, system_prompt,
                       response_text, input_tokens, output_tokens, response_time_ms,
                       status, error_message, user_id, cached) {
  if (is.null(db_pool)) return(invisible(NULL))
  # Cache hit-ləri DB-yə yazmırıq (lazımsız yükdür)
  if (isTRUE(cached)) return(invisible(NULL))
  tryCatch(
    save_ai_response(
      db_pool = db_pool, model = model, task_type = task_type,
      prompt = prompt, system_prompt = system_prompt,
      response_text = response_text, input_tokens = input_tokens,
      output_tokens = output_tokens, response_time_ms = response_time_ms,
      status = status, error_message = error_message, user_id = user_id
    ),
    error = function(e) log_warning("DB loglama uğursuz: {e$message}")
  )
}

# === Sual Generasiyası ===
generate_questions_claude <- function(subject, grade, topic, difficulty = "orta", count = 5) {
  template <- load_prompt_template("question_generation")
  prompt <- sprintf(template, subject, grade, topic, difficulty, count)

  system_prompt <- "Sən Azərbaycan təhsil sistemi üçün sual hazırlayan ekspert müəllimsən.
Sualları Azərbaycan dilində, Bloom taksonomiyasına və DOK səviyyələrinə uyğun hazırla.
Cavabları JSON formatında qaytar."

  result <- call_claude_api(prompt, system_prompt, temperature = 0.8)

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

# === Kurikulum Analizi ===
analyze_curriculum_claude <- function(standards, items) {
  template <- load_prompt_template("curriculum_analysis")
  standards_text <- paste(standards, collapse = "\n")
  items_text <- paste(items, collapse = "\n")
  prompt <- sprintf(template, standards_text, items_text)

  system_prompt <- "Sən kurikulum analizi mütəxəssisisən. Standartlar və qiymətləndirmə sualları
arasındakı uyğunluğu təhlil et. Webb DOK uyğunluq indeksini hesabla."

  call_claude_api(prompt, system_prompt, max_tokens = 8192, temperature = 0.3)
}

# === Şagird Rəyi ===
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

# === AI Söhbət ===
chat_with_claude <- function(messages, context = NULL) {
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

  call_claude_api(last_msg, system_prompt, temperature = 0.7)
}

# === Diagnostika ===
claude_health_check <- function() {
  tryCatch({
    result <- call_claude_api("Salam, 1+1 nədir?", max_tokens = 50, temperature = 0,
                               use_cache = FALSE, task_type = "health_check")
    list(
      status = if (result$success) "healthy" else "unhealthy",
      provider = "claude",
      model = claude_config$model,
      message = if (result$success) "Claude API əlçatandır" else result$message,
      response_time_ms = result$response_time_ms %||% NA,
      cache_stats = cache_stats_claude(),
      rate_state = rate_limit_status_claude()
    )
  }, error = function(e) {
    list(status = "unhealthy", provider = "claude", message = e$message)
  })
}
