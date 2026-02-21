# =============================================
# ARTI-2026: AI Müəllim Mentor API
# TALIS əsaslı zəif sahə aşkarlanması,
# həftəlik tövsiyələr, resurs tövsiyələri,
# irəliləyiş izləmə, attestasiya planı
# =============================================

#' TALIS göstəricilərinin OECD ekvivalentləri (radar chart üçün)
TALIS_AREAS <- list(
  self_efficacy        = list(field = "self_efficacy",        label = "Öz-effektivlik",     oecd = 7.2, max = 10),
  job_satisfaction     = list(field = "job_satisfaction",     label = "İş məmnuniyyəti",    oecd = 7.5, max = 10),
  classroom_management = list(field = "classroom_management", label = "Sinif idarəetməsi",  oecd = 7.0, max = 10),
  cpd_impact           = list(field = "cpd_impact_score",     label = "PKİ təsiri",         oecd = 6.5, max = 10),
  collaboration        = list(field = "collaboration_score",  label = "Əməkdaşlıq",        oecd = 6.8, max = 10),
  student_pass_rate    = list(field = "student_pass_rate",    label = "Şagird keçid faizi", oecd = 78,  max = 100),
  ict_usage            = list(field = "ict_usage_frequency",  label = "İKT istifadəsi",     oecd = 6.0, max = 10)
)

#' İKT tezliyi sədlərini rəqəmə çevir
ict_frequency_to_score <- function(freq) {
  switch(freq %||% "nadir",
    "hər_dərs" = 9, "her_ders" = 9,
    "həftəlik" = 7, "heftelik" = 7,
    "aylıq" = 4, "ayliq" = 4,
    "nadir" = 2, 2)
}

#' TALIS göstəricilərindən zəif sahələri müəyyən et
#' @param talis TALIS göstəriciləri (db_get_one nəticəsi)
#' @return data.frame: area, label, score, oecd, gap, priority
detect_weak_areas <- function(talis) {
  if (is.null(talis)) return(data.frame())

  results <- lapply(TALIS_AREAS, function(area) {
    raw_val <- talis[[area$field]]

    # İKT üçün xüsusi emal
    if (area$field == "ict_usage_frequency") {
      score <- ict_frequency_to_score(raw_val)
    } else {
      score <- as.numeric(raw_val %||% 0)
    }

    # Şagird keçid faizini 10-luq şkalaya normalize et (müqayisə üçün)
    if (area$field == "student_pass_rate") {
      gap <- score - area$oecd
      priority <- if (gap < -15) "high" else if (gap < -5) "medium" else "low"
    } else {
      gap <- score - area$oecd
      priority <- if (gap < -2) "high" else if (gap < -0.5) "medium" else "low"
    }

    data.frame(
      area = area$field,
      label = area$label,
      score = score,
      oecd = area$oecd,
      gap = round(gap, 2),
      priority = priority,
      stringsAsFactors = FALSE
    )
  })

  df <- do.call(rbind, results)
  # Yalnız OECD-dən aşağı olanları qaytaraq, ciddilik sırasına görə
  weak <- df[df$gap < 0, ]
  if (nrow(weak) == 0) return(weak)
  weak[order(weak$gap), ]
}

#' AI Mentor tövsiyələri generasiya et
#' @param teacher_id Müəllim UUID
#' @param db_pool DB pool
#' @param user_id Sorğu edən istifadəçi
#' @return list(success, recommendations, weekly_focus, motivation_note, weak_areas)
generate_mentor_recommendations <- function(teacher_id, db_pool, user_id = NULL) {
  # 1. Müəllim məlumatları
  teacher <- db_get_one(db_pool,
    "SELECT first_name, last_name, specialization, category, experience_years,
            ict_competency_level, certification_score
     FROM teachers WHERE id = $1",
    params = list(teacher_id))

  if (is.null(teacher)) {
    return(list(success = FALSE, message = "Müəllim tapılmadı"))
  }

  # 2. TALIS göstəriciləri
  talis <- get_teacher_talis_profile(db_pool, teacher_id)
  if (is.null(talis)) {
    return(list(success = FALSE, message = "TALIS göstəriciləri tapılmadı"))
  }

  # 3. Zəif sahələri aşkarla
  weak_areas <- detect_weak_areas(talis)
  if (nrow(weak_areas) == 0) {
    return(list(
      success = TRUE,
      recommendations = list(),
      weak_areas = weak_areas,
      weekly_focus = "Bütün sahələrdə OECD standartlarına çatmısınız!",
      motivation_note = "Əla nəticə! İndi mentorluq rolunu götürməyi düşünün."
    ))
  }

  # 4. Prompt yarat
  template <- load_prompt_template("teacher_mentor")
  teacher_name <- paste(teacher$first_name, teacher$last_name)

  weak_areas_text <- paste(
    sprintf("- %s: %s (OECD: %s, Fərq: %s)",
      weak_areas$label, weak_areas$score, weak_areas$oecd, weak_areas$gap),
    collapse = "\n"
  )

  ict_score <- ict_frequency_to_score(talis$ict_usage_frequency)

  prompt <- sprintf(template,
    teacher_name,
    teacher$specialization %||% "",
    teacher$category %||% "Kateqoriyasız",
    teacher$experience_years %||% 0,
    teacher$ict_competency_level %||% "orta",
    talis$self_efficacy %||% 0,
    talis$job_satisfaction %||% 0,
    talis$classroom_management %||% 0,
    talis$cpd_hours %||% 0,
    talis$cpd_impact_score %||% 0,
    talis$collaboration_score %||% 0,
    talis$student_pass_rate %||% 0,
    ict_score,
    weak_areas_text
  )

  system_prompt <- paste0(
    "Sən Azərbaycan təhsil sistemində müəllim inkişafı üzrə AI mentorsan. ",
    "TALIS (OECD) göstəricilərinə əsasən fərdi tövsiyələr verirsən. ",
    "Tövsiyələrin praktik, konkret və bu həftə tətbiq oluna bilən olmalıdır. ",
    "Cavabı YALNIZ düzgün JSON formatında qaytar."
  )

  # 5. Claude API çağırışı
  result <- tryCatch(
    call_claude_api(prompt, system_prompt, max_tokens = 4096, temperature = 0.7),
    error = function(e) list(success = FALSE, message = e$message)
  )

  if (!result$success) {
    return(list(success = FALSE, message = result$message))
  }

  # 6. Cavabı emal et
  parsed <- extract_json_from_response(result$message)
  if (is.null(parsed)) {
    return(list(success = FALSE, message = "AI cavabı emal edilə bilmədi"))
  }

  tokens_total <- (result$usage$input_tokens %||% 0) + (result$usage$output_tokens %||% 0)
  log_token_usage("claude", result$usage)

  # 7. Tövsiyələri DB-yə yaz
  week_start <- as.Date(cut(Sys.Date(), "week"))
  recs <- parsed$recommendations

  if (is.data.frame(recs)) {
    for (i in seq_len(nrow(recs))) {
      save_mentor_recommendation(db_pool, teacher_id, week_start, recs[i, ], tokens_total, recs)
    }
  } else if (is.list(recs)) {
    for (rec in recs) {
      save_mentor_recommendation(db_pool, teacher_id, week_start, rec, tokens_total, recs)
    }
  }

  list(
    success = TRUE,
    recommendations = recs,
    weak_areas = weak_areas,
    weekly_focus = parsed$weekly_focus %||% "",
    motivation_note = parsed$motivation_note %||% "",
    usage = result$usage
  )
}

#' Tək bir mentor tövsiyəsini DB-yə yaz
save_mentor_recommendation <- function(db_pool, teacher_id, week_start, rec, tokens_used, all_recs) {
  tryCatch({
    # Tövsiyəni yaz
    rec_id <- generate_uuid()
    weak_area <- if (is.data.frame(rec)) rec$weak_area[1] else rec$weak_area %||% "general"
    current_score <- if (is.data.frame(rec)) rec$current_score[1] else rec$current_score %||% 0
    oecd_bench <- if (is.data.frame(rec)) rec$oecd_benchmark[1] else rec$oecd_benchmark %||% 0
    priority_val <- if (is.data.frame(rec)) rec$priority[1] else rec$priority %||% "medium"
    strategy <- if (is.data.frame(rec)) rec$strategy_type[1] else rec$strategy_type %||% "general"
    rec_text <- if (is.data.frame(rec)) rec$recommendation[1] else rec$recommendation %||% ""

    db_execute(db_pool,
      "INSERT INTO teacher_mentor_recommendations
       (id, teacher_id, week_start, weak_area, weak_area_score, oecd_benchmark,
        recommendation_text, strategy_type, priority, tokens_used)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
       ON CONFLICT (teacher_id, week_start, weak_area) DO UPDATE
       SET recommendation_text = $7, priority = $9, tokens_used = $10",
      params = list(rec_id, teacher_id, week_start, weak_area,
                    as.numeric(current_score), as.numeric(oecd_bench),
                    rec_text, strategy, priority_val,
                    as.integer(tokens_used / max(1, length(all_recs)))))

    # Resursları yaz
    resources <- if (is.data.frame(rec)) NULL else rec$resources
    if (is.list(resources) && length(resources) > 0) {
      for (res in resources) {
        tryCatch(
          db_execute(db_pool,
            "INSERT INTO teacher_mentor_resources
             (recommendation_id, teacher_id, resource_type, title, description, url,
              source, estimated_minutes)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8)",
            params = list(rec_id, teacher_id,
                          res$type %||% "article", res$title %||% "",
                          res$description %||% "", res$url %||% "",
                          res$source %||% "", as.integer(res$estimated_minutes %||% 30))),
          error = function(e) NULL
        )
      }
    }
  }, error = function(e) {
    log_error("Mentor tövsiyə yazma xətası: {e$message}")
  })
}

#' Müəllimin irəliləyişini izlə (TALIS tarixçəsi əsasında)
#' @param teacher_id Müəllim UUID
#' @param db_pool DB pool
#' @return data.frame: area, label, previous, current, target, change_pct
track_teacher_progress <- function(teacher_id, db_pool) {
  # Cari TALIS
  current_talis <- get_teacher_talis_profile(db_pool, teacher_id)
  if (is.null(current_talis)) return(data.frame())

  current_year <- get_academic_year()

  # Əvvəlki il TALIS
  prev_year_parts <- strsplit(current_year, "-")[[1]]
  prev_year <- paste0(as.integer(prev_year_parts[1]) - 1, "-", prev_year_parts[1])
  prev_talis <- db_get_one(db_pool,
    "SELECT * FROM teacher_talis_indicators WHERE teacher_id = $1 AND assessment_year = $2",
    params = list(teacher_id, prev_year))

  results <- lapply(TALIS_AREAS, function(area) {
    if (area$field == "ict_usage_frequency") {
      current_val <- ict_frequency_to_score(current_talis[[area$field]])
      prev_val <- if (!is.null(prev_talis)) ict_frequency_to_score(prev_talis[[area$field]]) else current_val
    } else {
      current_val <- as.numeric(current_talis[[area$field]] %||% 0)
      prev_val <- if (!is.null(prev_talis)) as.numeric(prev_talis[[area$field]] %||% 0) else current_val
    }

    change <- if (prev_val > 0) round((current_val - prev_val) / prev_val * 100, 1) else 0

    data.frame(
      area = area$field,
      label = area$label,
      previous = prev_val,
      current = current_val,
      target = area$oecd,
      change_pct = change,
      stringsAsFactors = FALSE
    )
  })

  df <- do.call(rbind, results)

  # İrəliləyişi DB-yə yaz
  for (i in seq_len(nrow(df))) {
    tryCatch(
      db_execute(db_pool,
        "INSERT INTO teacher_progress_tracking
         (teacher_id, area, previous_score, current_score, target_score, change_pct, assessment_year)
         VALUES ($1, $2, $3, $4, $5, $6, $7)",
        params = list(teacher_id, df$area[i], df$previous[i], df$current[i],
                      df$target[i], df$change_pct[i], current_year)),
      error = function(e) NULL
    )
  }

  df
}

#' Həftəlik tövsiyə tarixçəsini əldə et
#' @param teacher_id Müəllim UUID
#' @param db_pool DB pool
#' @param limit Limit
#' @return data.frame
get_mentor_history <- function(teacher_id, db_pool, limit = 20) {
  db_query(db_pool,
    "SELECT id, week_start, weak_area, weak_area_score, oecd_benchmark,
            recommendation_text, strategy_type, priority, is_completed,
            teacher_feedback, feedback_rating, created_at
     FROM teacher_mentor_recommendations
     WHERE teacher_id = $1
     ORDER BY week_start DESC, priority ASC
     LIMIT $2",
    params = list(teacher_id, limit))
}

#' Resurs tövsiyələrini əldə et
#' @param teacher_id Müəllim UUID
#' @param db_pool DB pool
#' @return data.frame
get_mentor_resources <- function(teacher_id, db_pool) {
  db_query(db_pool,
    "SELECT r.id, r.resource_type, r.title, r.description, r.url, r.source,
            r.estimated_minutes, r.is_viewed, r.rating,
            mr.weak_area, mr.week_start
     FROM teacher_mentor_resources r
     LEFT JOIN teacher_mentor_recommendations mr ON r.recommendation_id = mr.id
     WHERE r.teacher_id = $1
     ORDER BY r.created_at DESC
     LIMIT 50",
    params = list(teacher_id))
}

#' Attestasiya hazırlıq planı yarat (AI ilə)
#' @param teacher_id Müəllim UUID
#' @param target_category Hədəf kateqoriya
#' @param total_weeks Plan müddəti (həftə)
#' @param db_pool DB pool
#' @param user_id İstifadəçi
#' @return list(success, plan, current_readiness)
generate_attestation_plan <- function(teacher_id, target_category, total_weeks = 12,
                                       db_pool, user_id = NULL) {
  # 1. Müəllim məlumatları
  teacher <- db_get_one(db_pool,
    "SELECT first_name, last_name, specialization, category, experience_years,
            ict_competency_level, certification_score
     FROM teachers WHERE id = $1",
    params = list(teacher_id))

  if (is.null(teacher)) {
    return(list(success = FALSE, message = "Müəllim tapılmadı"))
  }

  # 2. TALIS göstəriciləri
  talis <- get_teacher_talis_profile(db_pool, teacher_id)
  talis_text <- if (!is.null(talis)) {
    paste(
      sprintf("- Öz-effektivlik: %s", talis$self_efficacy %||% "?"),
      sprintf("- İş məmnuniyyəti: %s", talis$job_satisfaction %||% "?"),
      sprintf("- Sinif idarəetməsi: %s", talis$classroom_management %||% "?"),
      sprintf("- PKİ saatları: %s", talis$cpd_hours %||% "?"),
      sprintf("- Şagird keçid faizi: %s%%", talis$student_pass_rate %||% "?"),
      sprintf("- Əməkdaşlıq: %s", talis$collaboration_score %||% "?"),
      sep = "\n"
    )
  } else {
    "TALIS göstəriciləri mövcud deyil"
  }

  # 3. Prompt yarat
  template <- load_prompt_template("teacher_attestation")
  teacher_name <- paste(teacher$first_name, teacher$last_name)

  prompt <- sprintf(template,
    teacher_name,
    teacher$specialization %||% "",
    teacher$category %||% "Kateqoriyasız",
    target_category,
    teacher$experience_years %||% 0,
    teacher$certification_score %||% 0,
    teacher$ict_competency_level %||% "orta",
    talis_text,
    total_weeks
  )

  system_prompt <- paste0(
    "Sən Azərbaycan təhsil sistemində müəllim attestasiyası üzrə ekspertsən. ",
    "Realist, addım-addım hazırlıq planı yaradırsan. ",
    "Hər həftənin tapşırıqları konkret və icra edilə bilən olmalıdır. ",
    "Cavabı YALNIZ düzgün JSON formatında qaytar."
  )

  # 4. Claude API çağırışı
  result <- tryCatch(
    call_claude_api(prompt, system_prompt, max_tokens = 8192, temperature = 0.6),
    error = function(e) list(success = FALSE, message = e$message)
  )

  if (!result$success) {
    return(list(success = FALSE, message = result$message))
  }

  # 5. Cavabı emal et
  parsed <- extract_json_from_response(result$message)
  if (is.null(parsed)) {
    return(list(success = FALSE, message = "AI cavabı emal edilə bilmədi"))
  }

  tokens_total <- (result$usage$input_tokens %||% 0) + (result$usage$output_tokens %||% 0)
  log_token_usage("claude", result$usage)

  # 6. Planı DB-yə yaz
  plan_id <- generate_uuid()
  tryCatch(
    db_execute(db_pool,
      "INSERT INTO teacher_attestation_plans
       (id, teacher_id, target_category, current_category, plan_json, total_weeks,
        target_date, current_readiness, tokens_used, created_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)",
      params = list(
        plan_id, teacher_id, target_category,
        teacher$category %||% "Kateqoriyasız",
        jsonlite::toJSON(parsed, auto_unbox = TRUE),
        total_weeks,
        Sys.Date() + (total_weeks * 7),
        parsed$current_readiness %||% 0,
        tokens_total,
        user_id
      )),
    error = function(e) log_error("Attestasiya planı yazma xətası: {e$message}")
  )

  list(
    success = TRUE,
    plan_id = plan_id,
    plan = parsed,
    current_readiness = parsed$current_readiness %||% 0,
    gap_analysis = parsed$gap_analysis %||% "",
    usage = result$usage
  )
}

#' Mövcud attestasiya planını əldə et
#' @param teacher_id Müəllim UUID
#' @param db_pool DB pool
#' @return Plan siyahısı və ya NULL
get_active_attestation_plan <- function(teacher_id, db_pool) {
  plan <- db_get_one(db_pool,
    "SELECT * FROM teacher_attestation_plans
     WHERE teacher_id = $1 AND status = 'active'
     ORDER BY created_at DESC LIMIT 1",
    params = list(teacher_id))

  if (is.null(plan)) return(NULL)

  plan$plan_data <- tryCatch(
    jsonlite::fromJSON(plan$plan_json, simplifyVector = FALSE),
    error = function(e) NULL
  )
  plan
}

#' Tövsiyəni tamamlandı olaraq işarələ
mark_recommendation_completed <- function(rec_id, feedback, rating, db_pool) {
  db_execute(db_pool,
    "UPDATE teacher_mentor_recommendations
     SET is_completed = TRUE, completed_at = NOW(),
         teacher_feedback = $1, feedback_rating = $2
     WHERE id = $3",
    params = list(feedback, as.integer(rating), rec_id))
}

#' Resursu baxıldı olaraq işarələ
mark_resource_viewed <- function(resource_id, rating, db_pool) {
  db_execute(db_pool,
    "UPDATE teacher_mentor_resources
     SET is_viewed = TRUE, viewed_at = NOW(), rating = $1
     WHERE id = $2",
    params = list(as.integer(rating), resource_id))
}
