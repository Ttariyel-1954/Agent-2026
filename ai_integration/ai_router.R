# =============================================
# ARTI-2026: AI Router — Ağıllı Provayder Seçimi
# Tapşırığa görə Claude/GPT avtomatik seçimi,
# fallback mexanizmi, xərc optimallaşdırması
# =============================================

# === Tapşırıq-Provayder Xəritəsi ===
# Hər tapşırıq növü üçün əsas provayder, alternativ,
# model, temperature və max_tokens konfiqurasiyası
AI_TASK_ROUTING <- list(
  # Sual generasiyası — kreativ tapşırıq, Claude daha yaxşı
  question_generation = list(
    primary = "claude", fallback = "gpt",
    temperature = 0.8, max_tokens = 4096,
    priority = "quality", description = "Sual generasiyası"
  ),
  # Kurikulum analizi — analitik tapşırıq, Claude güclü
  curriculum_analysis = list(
    primary = "claude", fallback = "gpt",
    temperature = 0.3, max_tokens = 8192,
    priority = "quality", description = "Kurikulum analizi"
  ),
  # Şagird rəyi — kreativ + empatik, Claude güclü
  student_feedback = list(
    primary = "claude", fallback = "gpt",
    temperature = 0.6, max_tokens = 4096,
    priority = "quality", description = "Şagird rəyi"
  ),
  # Dərs planı — strukturlaşdırılmış, hər ikisi yaxşıdır
  lesson_plan = list(
    primary = "claude", fallback = "gpt",
    temperature = 0.6, max_tokens = 6144,
    priority = "balanced", description = "Dərs planı"
  ),
  # Hesabat xülasəsi — analitik, GPT sürətli
  report_summary = list(
    primary = "gpt", fallback = "claude",
    temperature = 0.4, max_tokens = 4096,
    priority = "speed", description = "Hesabat xülasəsi"
  ),
  # Tərcümə — dəqiqlik vacib, Claude güclü
  translation = list(
    primary = "claude", fallback = "gpt",
    temperature = 0.3, max_tokens = 8192,
    priority = "quality", description = "Tərcümə"
  ),
  # SWOT analiz — strateji təhlil
  strategy_analysis = list(
    primary = "claude", fallback = "gpt",
    temperature = 0.5, max_tokens = 8192,
    priority = "quality", description = "Strateji analiz"
  ),
  # What-if ssenari — kreativ düşüncə
  whatif_scenario = list(
    primary = "claude", fallback = "gpt",
    temperature = 0.6, max_tokens = 8192,
    priority = "quality", description = "What-if ssenari"
  ),
  # Valideyn məktubu — empatik yazı, Claude üstün
  parent_letter = list(
    primary = "claude", fallback = "gpt",
    temperature = 0.6, max_tokens = 4096,
    priority = "quality", description = "Valideyn məktubu"
  ),
  # Mentor tövsiyəsi
  teacher_mentor = list(
    primary = "claude", fallback = "gpt",
    temperature = 0.5, max_tokens = 6144,
    priority = "quality", description = "Müəllim mentoru"
  ),
  # Attestasiya planı
  teacher_attestation = list(
    primary = "claude", fallback = "gpt",
    temperature = 0.4, max_tokens = 6144,
    priority = "balanced", description = "Attestasiya planı"
  ),
  # Tədqiqat ədəbiyyatı
  research_literature = list(
    primary = "claude", fallback = "gpt",
    temperature = 0.4, max_tokens = 8192,
    priority = "quality", description = "Ədəbiyyat icmalı"
  ),
  # Tədqiqat metodologiyası
  research_methodology = list(
    primary = "claude", fallback = "gpt",
    temperature = 0.4, max_tokens = 6144,
    priority = "quality", description = "Metodologiya"
  ),
  # Statistik analiz planı
  analysis_plan = list(
    primary = "claude", fallback = "gpt",
    temperature = 0.3, max_tokens = 8192,
    priority = "quality", description = "Analiz planı"
  ),
  # Nəticə qaralama — uzun mətn
  results_draft = list(
    primary = "claude", fallback = "gpt",
    temperature = 0.5, max_tokens = 8192,
    priority = "quality", description = "Nəticə qaralama"
  ),
  # Ev tapşırığı generasiyası
  homework_generation = list(
    primary = "gpt", fallback = "claude",
    temperature = 0.7, max_tokens = 4096,
    priority = "speed", description = "Ev tapşırığı"
  ),
  # Rubrika yaratma
  rubric_creation = list(
    primary = "gpt", fallback = "claude",
    temperature = 0.4, max_tokens = 4096,
    priority = "speed", description = "Rubrika yaratma"
  ),
  # İmtahan analizi
  exam_analysis = list(
    primary = "claude", fallback = "gpt",
    temperature = 0.3, max_tokens = 6144,
    priority = "quality", description = "İmtahan analizi"
  ),
  # Ümumi söhbət — sürət əsas
  chat = list(
    primary = "claude", fallback = "gpt",
    temperature = 0.7, max_tokens = 4096,
    priority = "balanced", description = "AI söhbət"
  ),
  # Mətn analizi — GPT sürətli
  text_analysis = list(
    primary = "gpt", fallback = "claude",
    temperature = 0.3, max_tokens = 4096,
    priority = "speed", description = "Mətn analizi"
  )
)

# === Provayder Statusu ===
.provider_status <- new.env(parent = emptyenv())
.provider_status$claude <- list(available = TRUE, last_error = NULL, error_count = 0, last_check = 0)
.provider_status$gpt <- list(available = TRUE, last_error = NULL, error_count = 0, last_check = 0)

update_provider_status <- function(provider, success, error_msg = NULL) {
  current <- .provider_status[[provider]]
  if (success) {
    current$available <- TRUE
    current$error_count <- 0
    current$last_error <- NULL
  } else {
    current$error_count <- current$error_count + 1
    current$last_error <- error_msg
    # 3 ardıcıl xəta — provayderanı müvəqqəti deaktiv et
    if (current$error_count >= 3) {
      current$available <- FALSE
      log_warning("AI provayder {provider} müvəqqəti deaktiv edildi ({current$error_count} xəta)")
    }
  }
  current$last_check <- as.numeric(Sys.time())
  .provider_status[[provider]] <- current
}

is_provider_available <- function(provider) {
  status <- .provider_status[[provider]]
  if (!status$available) {
    # 5 dəqiqədən sonra yenidən yoxla
    if (as.numeric(Sys.time()) - status$last_check > 300) {
      status$available <- TRUE
      status$error_count <- 0
      .provider_status[[provider]] <- status
      return(TRUE)
    }
    return(FALSE)
  }
  TRUE
}

reset_provider_status <- function(provider = NULL) {
  reset <- list(available = TRUE, last_error = NULL, error_count = 0, last_check = 0)
  if (is.null(provider)) {
    .provider_status$claude <- reset
    .provider_status$gpt <- reset
  } else {
    .provider_status[[provider]] <- reset
  }
}

# === Əsas Router Funksiyası ===
route_ai_request <- function(prompt, task_type = "chat", system_prompt = NULL,
                              temperature = NULL, max_tokens = NULL,
                              force_provider = NULL, use_cache = TRUE,
                              save_to_db = TRUE, db_pool = NULL, user_id = NULL) {

  # Tapşırıq konfiqurasiyasını al
  task_config <- AI_TASK_ROUTING[[task_type]]
  if (is.null(task_config)) {
    task_config <- AI_TASK_ROUTING$chat
    log_warning("Naməlum tapşırıq növü: {task_type}, 'chat' istifadə edilir")
  }

  # Parametrləri override et (istifadəçi dəyərləri üstünlük daşıyır)
  temp <- temperature %||% task_config$temperature
  tokens <- max_tokens %||% task_config$max_tokens

  # Provayder seçimi
  if (!is.null(force_provider)) {
    providers <- c(force_provider)
  } else {
    primary <- task_config$primary
    fallback_prov <- task_config$fallback
    providers <- c(primary, fallback_prov)
  }

  # Hər provayderi sına
  for (provider in providers) {
    if (!is_provider_available(provider)) {
      log_info("AI Router: {provider} əlçatan deyil, növbəti provayder sınanır")
      next
    }

    start_time <- Sys.time()

    result <- tryCatch({
      if (provider == "claude") {
        call_claude_api(prompt, system_prompt, max_tokens = tokens,
                        temperature = temp, use_cache = use_cache)
      } else if (provider == "gpt") {
        call_gpt_api(prompt, system_prompt, max_tokens = tokens,
                     temperature = temp, use_cache = use_cache)
      } else {
        list(success = FALSE, message = paste("Naməlum provayder:", provider))
      }
    }, error = function(e) {
      list(success = FALSE, message = e$message, content = e$message)
    })

    elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

    if (isTRUE(result$success)) {
      update_provider_status(provider, TRUE)

      # Routing meta əlavə et
      result$task_type <- task_type
      result$routed_provider <- provider
      result$response_time_sec <- round(elapsed, 2)
      result$priority <- task_config$priority

      # DB-yə saxla
      if (save_to_db && !is.null(db_pool)) {
        tryCatch({
          save_ai_response(
            db_pool = db_pool,
            provider = provider,
            model = result$model %||% "",
            task_type = task_type,
            prompt = prompt,
            system_prompt = system_prompt,
            response_text = result$content %||% result$message,
            input_tokens = result$usage$input_tokens %||% 0,
            output_tokens = result$usage$output_tokens %||% 0,
            response_time_ms = round(elapsed * 1000),
            status = "success",
            user_id = user_id,
            cached = result$cached %||% FALSE
          )
        }, error = function(e) {
          log_error("AI cavab saxlama xətası: {e$message}")
        })
      }

      return(result)
    }

    # Xəta — status yenilə
    update_provider_status(provider, FALSE, result$message)
    log_warning("AI Router: {provider} uğursuz ({task_type}): {result$message}. Fallback sınanır...")

    # Uğursuz DB qeydiyyat
    if (save_to_db && !is.null(db_pool)) {
      tryCatch({
        save_ai_response(
          db_pool = db_pool,
          provider = provider,
          model = "",
          task_type = task_type,
          prompt = prompt,
          system_prompt = system_prompt,
          response_text = result$message %||% "Xəta",
          input_tokens = 0, output_tokens = 0,
          response_time_ms = round(elapsed * 1000),
          status = "error",
          error_message = result$message,
          user_id = user_id,
          cached = FALSE
        )
      }, error = function(e) NULL)
    }
  }

  # Bütün provayerlər uğursuz
  log_error("AI Router: bütün provayerlər uğursuz oldu ({task_type})")
  list(
    success = FALSE,
    message = "Bütün AI provayderlər əlçatan deyil. Zəhmət olmasa bir az sonra yenidən cəhd edin.",
    content = "Bütün AI provayderlər əlçatan deyil. Zəhmət olmasa bir az sonra yenidən cəhd edin.",
    task_type = task_type,
    provider = "none"
  )
}

# === Tapşırıq Növlərini Al ===
get_available_task_types <- function() {
  sapply(names(AI_TASK_ROUTING), function(name) {
    AI_TASK_ROUTING[[name]]$description
  })
}

# === Provayder Status Hesabatı ===
get_provider_status_report <- function() {
  list(
    claude = list(
      available = .provider_status$claude$available,
      error_count = .provider_status$claude$error_count,
      last_error = .provider_status$claude$last_error,
      cache_stats = cache_stats_claude(),
      rate_state = list(
        recent_requests = length(.claude_rate_state$request_times),
        recent_tokens = sum(.claude_rate_state$token_counts)
      )
    ),
    gpt = list(
      available = .provider_status$gpt$available,
      error_count = .provider_status$gpt$error_count,
      last_error = .provider_status$gpt$last_error,
      cache_stats = cache_stats_gpt(),
      rate_state = list(
        recent_requests = length(.gpt_rate_state$request_times),
        recent_tokens = sum(.gpt_rate_state$token_counts)
      )
    )
  )
}

# === Xərc Hesabatı ===
# Claude: $3/M input, $15/M output (Sonnet)
# GPT-4o: $2.50/M input, $10/M output
estimate_cost <- function(provider, input_tokens, output_tokens) {
  if (provider == "claude") {
    input_cost <- (input_tokens / 1e6) * 3.0
    output_cost <- (output_tokens / 1e6) * 15.0
  } else if (provider == "gpt") {
    input_cost <- (input_tokens / 1e6) * 2.5
    output_cost <- (output_tokens / 1e6) * 10.0
  } else {
    return(0)
  }
  round(input_cost + output_cost, 6)
}

# === Cache Təmizlə (hər iki provayder) ===
clear_all_caches <- function() {
  cache_clear_claude()
  cache_clear_gpt()
  log_info("Bütün AI cache-lər təmizləndi")
}
