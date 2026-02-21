# =============================================
# ARTI-2026: Strategiya AI API
# SWOT analiz, resurs bölgüsü, what-if scenari
# =============================================

# --- Bütün məktəblərin məlumatlarını topla ---
gather_district_data <- function(db_pool) {
  # Məktəb siyahısı və əsas statistika
  schools <- db_query(db_pool, "
    SELECT s.id, s.name, s.code, s.type, s.region, s.student_capacity,
           COUNT(DISTINCT st.id) AS student_count,
           COUNT(DISTINCT t.id) AS teacher_count
    FROM schools s
    LEFT JOIN students st ON st.school_id = s.id AND st.status = 'active'
    LEFT JOIN teachers t ON t.school_id = s.id AND t.status = 'active'
    WHERE s.status = 'active'
    GROUP BY s.id, s.name, s.code, s.type, s.region, s.student_capacity
    ORDER BY s.name
  ")

  # Fənn üzrə orta ballar (məktəb üzrə)
  subject_scores <- db_query(db_pool, "
    SELECT s.name AS school_name, sub.name AS subject,
           ROUND(AVG(g.score)::numeric, 1) AS avg_score,
           COUNT(g.id) AS grade_count
    FROM grades g
    JOIN students st ON st.id = g.student_id
    JOIN schools s ON s.id = st.school_id
    JOIN subjects sub ON sub.id = g.subject_id
    WHERE g.academic_year = $1
    GROUP BY s.name, sub.name
    ORDER BY s.name, sub.name
  ", params = list(get_academic_year()))

  # Müəllim kateqoriya paylanması
  teacher_cats <- db_query(db_pool, "
    SELECT s.name AS school_name, t.category,
           COUNT(t.id) AS cnt
    FROM teachers t
    JOIN schools s ON s.id = t.school_id
    WHERE t.status = 'active'
    GROUP BY s.name, t.category
    ORDER BY s.name
  ")

  # TALIS göstəriciləri (məktəb ortalaması)
  talis <- db_query(db_pool, "
    SELECT s.name AS school_name,
           ROUND(AVG(tti.self_efficacy)::numeric, 1) AS avg_self_efficacy,
           ROUND(AVG(tti.job_satisfaction)::numeric, 1) AS avg_job_satisfaction,
           ROUND(AVG(tti.classroom_management)::numeric, 1) AS avg_classroom_mgmt,
           ROUND(AVG(tti.cpd_hours)::numeric, 0) AS avg_cpd_hours,
           ROUND(AVG(tti.collaboration_score)::numeric, 1) AS avg_collaboration,
           ROUND(AVG(tti.student_pass_rate)::numeric, 1) AS avg_pass_rate
    FROM teacher_talis_indicators tti
    JOIN teachers t ON t.id = tti.teacher_id
    JOIN schools s ON s.id = t.school_id
    WHERE t.status = 'active'
    GROUP BY s.name
    ORDER BY s.name
  ")

  # Davamiyyət statistikası (məktəb üzrə)
  attendance <- db_query(db_pool, "
    SELECT s.name AS school_name,
           COUNT(CASE WHEN a.status = 'present' THEN 1 END) AS present_count,
           COUNT(CASE WHEN a.status = 'absent' THEN 1 END) AS absent_count,
           COUNT(a.id) AS total_records,
           CASE WHEN COUNT(a.id) > 0
             THEN ROUND(100.0 * COUNT(CASE WHEN a.status = 'present' THEN 1 END) / COUNT(a.id), 1)
             ELSE 0 END AS attendance_rate
    FROM attendance a
    JOIN students st ON st.id = a.student_id
    JOIN schools s ON s.id = st.school_id
    WHERE a.attendance_date >= (CURRENT_DATE - INTERVAL '6 months')
    GROUP BY s.name
    ORDER BY s.name
  ")

  list(
    schools = schools,
    subject_scores = subject_scores,
    teacher_categories = teacher_cats,
    talis = talis,
    attendance = attendance
  )
}

# --- Tək məktəb üçün metrikləri topla ---
gather_school_data <- function(db_pool, school_id) {
  school <- db_get_one(db_pool, "
    SELECT s.*, COUNT(DISTINCT st.id) AS student_count, COUNT(DISTINCT t.id) AS teacher_count
    FROM schools s
    LEFT JOIN students st ON st.school_id = s.id AND st.status = 'active'
    LEFT JOIN teachers t ON t.school_id = s.id AND t.status = 'active'
    WHERE s.id = $1
    GROUP BY s.id
  ", params = list(school_id))

  scores <- db_query(db_pool, "
    SELECT sub.name AS subject, ROUND(AVG(g.score)::numeric, 1) AS avg_score,
           COUNT(DISTINCT g.student_id) AS student_count
    FROM grades g
    JOIN students st ON st.id = g.student_id
    JOIN subjects sub ON sub.id = g.subject_id
    WHERE st.school_id = $1 AND g.academic_year = $2
    GROUP BY sub.name ORDER BY avg_score DESC
  ", params = list(school_id, get_academic_year()))

  teachers <- db_query(db_pool, "
    SELECT t.category, t.specialization, t.experience_years,
           t.ict_competency_level, t.certification_score
    FROM teachers t WHERE t.school_id = $1 AND t.status = 'active'
  ", params = list(school_id))

  talis <- db_query(db_pool, "
    SELECT tti.*
    FROM teacher_talis_indicators tti
    JOIN teachers t ON t.id = tti.teacher_id
    WHERE t.school_id = $1
  ", params = list(school_id))

  list(school = school, scores = scores, teachers = teachers, talis = talis)
}

# --- Məlumatları prompt üçün mətn formatına çevir ---
format_school_stats <- function(data) {
  if (is.null(data$schools) || nrow(data$schools) == 0) return("Məktəb datası yoxdur")
  lines <- sapply(seq_len(nrow(data$schools)), function(i) {
    s <- data$schools[i, ]
    sprintf("- %s (%s): %d şagird, %d müəllim, tutum: %s, nisbət: %.1f",
            s$name, s$type %||% "N/A", s$student_count, s$teacher_count,
            s$student_capacity %||% "N/A",
            ifelse(s$teacher_count > 0, s$student_count / s$teacher_count, 0))
  })
  paste(lines, collapse = "\n")
}

format_teacher_stats <- function(data) {
  if (is.null(data$teacher_categories) || nrow(data$teacher_categories) == 0) return("Müəllim datası yoxdur")
  lines <- sapply(seq_len(nrow(data$teacher_categories)), function(i) {
    r <- data$teacher_categories[i, ]
    sprintf("- %s: %s — %d nəfər", r$school_name, r$category, r$cnt)
  })
  paste(lines, collapse = "\n")
}

format_performance_stats <- function(data) {
  if (is.null(data$subject_scores) || nrow(data$subject_scores) == 0) return("Performans datası yoxdur")
  lines <- sapply(seq_len(nrow(data$subject_scores)), function(i) {
    r <- data$subject_scores[i, ]
    sprintf("- %s | %s: %.1f (n=%d)", r$school_name, r$subject, r$avg_score, r$grade_count)
  })
  paste(lines, collapse = "\n")
}

format_talis_stats <- function(data) {
  if (is.null(data$talis) || nrow(data$talis) == 0) return("TALIS datası yoxdur")
  lines <- sapply(seq_len(nrow(data$talis)), function(i) {
    r <- data$talis[i, ]
    sprintf("- %s: Effektivlik=%.1f, Məmnuniyyət=%.1f, Sinif İdarə=%.1f, PKİ=%s saat, Əməkdaşlıq=%.1f, Keçid=%.1f%%",
            r$school_name, r$avg_self_efficacy %||% 0, r$avg_job_satisfaction %||% 0,
            r$avg_classroom_mgmt %||% 0, r$avg_cpd_hours %||% 0,
            r$avg_collaboration %||% 0, r$avg_pass_rate %||% 0)
  })
  paste(lines, collapse = "\n")
}

format_resource_stats <- function(data) {
  if (is.null(data$attendance) || nrow(data$attendance) == 0) return("Resurs/davamiyyət datası yoxdur")
  lines <- sapply(seq_len(nrow(data$attendance)), function(i) {
    r <- data$attendance[i, ]
    sprintf("- %s: davamiyyət %.1f%% (%d/%d)",
            r$school_name, r$attendance_rate, r$present_count, r$total_records)
  })
  paste(lines, collapse = "\n")
}

format_oecd_benchmarks <- function() {
  lines <- sapply(names(TALIS_BENCHMARKS), function(key) {
    b <- TALIS_BENCHMARKS[[key]]
    sprintf("- %s: OECD orta = %.1f (aralıq: %s-%s)",
            b$label, b$oecd_avg, b$min, b$max)
  })
  paste(lines, collapse = "\n")
}

# --- SWOT Analiz Generasiyası ---
generate_swot_analysis <- function(db_pool, school_id = NULL, academic_year = NULL, user_id = NULL) {
  academic_year <- academic_year %||% get_academic_year()

  # Əgər tək məktəb seçilibsə
  if (!is.null(school_id) && school_id != "") {
    school_data <- gather_school_data(db_pool, school_id)
    school_label <- school_data$school$name %||% "Seçilmiş məktəb"
    school_stats <- sprintf("- %s: %d şagird, %d müəllim",
                            school_label, school_data$school$student_count, school_data$school$teacher_count)
    teacher_stats <- if (nrow(school_data$teachers) > 0) {
      cat_summary <- table(school_data$teachers$category)
      paste(sapply(names(cat_summary), function(c) sprintf("  %s: %d", c, cat_summary[c])), collapse = "\n")
    } else "Müəllim datası yoxdur"
    perf_stats <- if (nrow(school_data$scores) > 0) {
      paste(sapply(seq_len(nrow(school_data$scores)), function(i) {
        sprintf("- %s: %.1f", school_data$scores$subject[i], school_data$scores$avg_score[i])
      }), collapse = "\n")
    } else "Performans datası yoxdur"
    talis_stats <- if (nrow(school_data$talis) > 0) {
      paste("TALIS ortalamaları mövcuddur")
    } else "TALIS datası yoxdur"
    resource_stats <- "Tək məktəb rejimi"
  } else {
    # Bütün məktəblər
    data <- gather_district_data(db_pool)
    school_label <- sprintf("Bütün məktəblər (%d)", nrow(data$schools))
    school_stats <- format_school_stats(data)
    teacher_stats <- format_teacher_stats(data)
    perf_stats <- format_performance_stats(data)
    talis_stats <- format_talis_stats(data)
    resource_stats <- format_resource_stats(data)
  }

  # Prompt yarat
  template <- load_prompt_template("strategy_swot")
  prompt <- sprintf(template,
    "SWOT + Strateji Tövsiyələr",
    academic_year,
    school_label,
    school_stats,
    teacher_stats,
    perf_stats,
    resource_stats,
    format_oecd_benchmarks()
  )

  system_prompt <- "Sən təhsil idarəetməsi və strateji planlaşdırma üzrə ekspert AI-san. Məlumatları dərindən analiz edib, konkret, ölçülə bilən tövsiyələr verirsən. Cavabı yalnız JSON formatında qaytar."

  response <- call_claude_api(
    prompt = prompt,
    system_prompt = system_prompt,
    max_tokens = 8192,
    temperature = 0.5
  )

  if (!isTRUE(response$success)) {
    return(list(success = FALSE, error = response$message %||% "API xətası"))
  }

  parsed <- extract_json_from_response(response$message)
  if (is.null(parsed)) {
    return(list(success = FALSE, error = "JSON parse xətası"))
  }

  # DB-yə yaz
  report_id <- save_strategy_report(
    db_pool = db_pool,
    report_type = "swot",
    school_id = if (!is.null(school_id) && school_id != "") school_id else NA,
    academic_year = academic_year,
    title = parsed$analysis_title %||% "SWOT Analiz",
    report_json = parsed,
    summary = paste(parsed$key_actions, collapse = "; "),
    model = response$model,
    tokens = response$usage$total_tokens,
    user_id = user_id
  )

  list(
    success = TRUE,
    report_id = report_id,
    data = parsed,
    model = response$model,
    usage = response$usage
  )
}

# --- Resurs bölgüsü tövsiyəsi ---
generate_resource_recommendations <- function(db_pool, academic_year = NULL, user_id = NULL) {
  academic_year <- academic_year %||% get_academic_year()
  data <- gather_district_data(db_pool)

  template <- load_prompt_template("strategy_swot")
  prompt <- sprintf(template,
    "Resurs Bölgüsü Optimallaşdırması",
    academic_year,
    sprintf("Bütün məktəblər (%d)", nrow(data$schools)),
    format_school_stats(data),
    format_teacher_stats(data),
    format_performance_stats(data),
    format_resource_stats(data),
    format_oecd_benchmarks()
  )

  system_prompt <- "Sən təhsil resurslarının optimal bölüşdürülməsi üzrə ekspertsən. Hər məktəbin ehtiyaclarını qiymətləndirib, ədalətli və effektiv resurs bölgüsü tövsiyəsi ver. Cavabı yalnız JSON formatında qaytar."

  response <- call_claude_api(prompt = prompt, system_prompt = system_prompt,
                               max_tokens = 6144, temperature = 0.4)

  if (!isTRUE(response$success)) {
    return(list(success = FALSE, error = response$message %||% "API xətası"))
  }

  parsed <- extract_json_from_response(response$message)
  if (is.null(parsed)) return(list(success = FALSE, error = "JSON parse xətası"))

  save_strategy_report(db_pool, "resource_allocation", NA, academic_year,
                       "Resurs Bölgüsü Analizi", parsed, NULL,
                       response$model, response$usage$total_tokens, user_id)

  list(success = TRUE, data = parsed, model = response$model, usage = response$usage)
}

# --- Müəllim yerləşdirmə optimallaşdırması ---
generate_teacher_optimization <- function(db_pool, academic_year = NULL, user_id = NULL) {
  academic_year <- academic_year %||% get_academic_year()
  data <- gather_district_data(db_pool)

  # Əlavə müəllim-fənn təhlili
  teacher_subjects <- db_query(db_pool, "
    SELECT s.name AS school_name, t.specialization, t.category,
           t.experience_years, t.ict_competency_level,
           COUNT(DISTINCT c.id) AS class_count
    FROM teachers t
    JOIN schools s ON s.id = t.school_id
    LEFT JOIN classes c ON c.school_id = s.id
    WHERE t.status = 'active'
    GROUP BY s.name, t.specialization, t.category, t.experience_years, t.ict_competency_level
    ORDER BY s.name
  ")

  teacher_detail <- if (nrow(teacher_subjects) > 0) {
    paste(sapply(seq_len(nrow(teacher_subjects)), function(i) {
      r <- teacher_subjects[i, ]
      sprintf("- %s: %s (%s), %d il, İKT=%s",
              r$school_name, r$specialization %||% "N/A", r$category, r$experience_years %||% 0,
              r$ict_competency_level %||% "N/A")
    }), collapse = "\n")
  } else "Müəllim detallı datası yoxdur"

  template <- load_prompt_template("strategy_swot")
  prompt <- sprintf(template,
    "Müəllim Yerləşdirmə Optimallaşdırması",
    academic_year,
    sprintf("Bütün məktəblər (%d)", nrow(data$schools)),
    format_school_stats(data),
    teacher_detail,
    format_performance_stats(data),
    format_resource_stats(data),
    format_oecd_benchmarks()
  )

  system_prompt <- "Sən təhsil kadr siyasəti üzrə ekspertsən. Müəllimlərin məktəblər arasında optimal yerləşdirilməsi, fənn çatışmazlıqlarının aradan qaldırılması və mentorluq proqramları tövsiyə et. Cavabı yalnız JSON formatında qaytar."

  response <- call_claude_api(prompt = prompt, system_prompt = system_prompt,
                               max_tokens = 6144, temperature = 0.4)

  if (!isTRUE(response$success)) {
    return(list(success = FALSE, error = response$message %||% "API xətası"))
  }

  parsed <- extract_json_from_response(response$message)
  if (is.null(parsed)) return(list(success = FALSE, error = "JSON parse xətası"))

  save_strategy_report(db_pool, "teacher_optimization", NA, academic_year,
                       "Müəllim Optimallaşdırma", parsed, NULL,
                       response$model, response$usage$total_tokens, user_id)

  list(success = TRUE, data = parsed, model = response$model, usage = response$usage)
}

# --- What-If Scenari ---
run_whatif_scenario <- function(db_pool, scenario_type, scenario_desc, school_id = NULL,
                                parameters = list(), user_id = NULL) {
  data <- gather_district_data(db_pool)

  # Cari baseline
  baseline <- list(
    total_schools = nrow(data$schools),
    total_students = sum(data$schools$student_count, na.rm = TRUE),
    total_teachers = sum(data$schools$teacher_count, na.rm = TRUE),
    avg_ratio = if (sum(data$schools$teacher_count, na.rm = TRUE) > 0)
      round(sum(data$schools$student_count, na.rm = TRUE) / sum(data$schools$teacher_count, na.rm = TRUE), 1) else 0,
    avg_attendance = if (!is.null(data$attendance) && nrow(data$attendance) > 0)
      round(mean(data$attendance$attendance_rate, na.rm = TRUE), 1) else 0
  )

  school_label <- if (!is.null(school_id) && school_id != "") {
    s <- db_get_one(db_pool, "SELECT name FROM schools WHERE id = $1", params = list(school_id))
    s$name %||% "Seçilmiş məktəb"
  } else "Bütün məktəblər"

  params_text <- paste(sapply(names(parameters), function(k) {
    sprintf("- %s: %s", k, parameters[[k]])
  }), collapse = "\n")

  template <- load_prompt_template("strategy_whatif")
  prompt <- sprintf(template,
    scenario_type,
    scenario_desc,
    school_label,
    sprintf("Məktəblər: %d, Şagirdlər: %d, Müəllimlər: %d, Nisbət: %.1f, Davamiyyət: %.1f%%",
            baseline$total_schools, baseline$total_students, baseline$total_teachers,
            baseline$avg_ratio, baseline$avg_attendance),
    params_text,
    format_resource_stats(data)
  )

  system_prompt <- "Sən təhsil siyasəti modelləşdirmə ekspertisən. What-if scenariləri dərindən təhlil edirsən. Kəmiyyət göstəriciləri, risk qiymətləndirməsi və alternativ yanaşmalar təklif et. Cavabı yalnız JSON formatında qaytar."

  response <- call_claude_api(prompt = prompt, system_prompt = system_prompt,
                               max_tokens = 6144, temperature = 0.6)

  if (!isTRUE(response$success)) {
    return(list(success = FALSE, error = response$message %||% "API xətası"))
  }

  parsed <- extract_json_from_response(response$message)
  if (is.null(parsed)) return(list(success = FALSE, error = "JSON parse xətası"))

  # DB-yə yaz
  save_scenario(db_pool, scenario_type = scenario_type, scenario_name = parsed$scenario_name %||% scenario_desc,
                school_id = school_id, parameters = parameters, baseline = baseline,
                outcomes = parsed, impact_score = parsed$feasibility_score,
                risk_level = parsed$risk_level, model = response$model,
                tokens = response$usage$total_tokens, user_id = user_id)

  list(success = TRUE, data = parsed, baseline = baseline,
       model = response$model, usage = response$usage)
}

# --- DB yardımçı funksiyalar ---
save_strategy_report <- function(db_pool, report_type, school_id, academic_year,
                                  title, report_json, summary, model, tokens, user_id) {
  tryCatch({
    result <- db_get_one(db_pool, "
      INSERT INTO strategy_reports (report_type, school_id, academic_year, title, report_json,
                                     summary, ai_model, tokens_used, created_by)
      VALUES ($1, $2, $3, $4, $5::jsonb, $6, $7, $8, $9)
      RETURNING id
    ", params = list(
      report_type,
      if (is.na(school_id) || is.null(school_id)) NA else school_id,
      academic_year, title, jsonlite::toJSON(report_json, auto_unbox = TRUE),
      summary, model, tokens, user_id
    ))
    result$id
  }, error = function(e) {
    log_warn("Strateji hesabat DB xətası: {e$message}")
    NULL
  })
}

save_scenario <- function(db_pool, scenario_type, scenario_name, school_id,
                           parameters, baseline, outcomes, impact_score, risk_level,
                           model, tokens, user_id) {
  tryCatch({
    db_execute(db_pool, "
      INSERT INTO strategy_scenarios (scenario_name, scenario_type, school_id, parameters,
                                       baseline_data, predicted_outcomes, impact_score,
                                       risk_level, ai_model, tokens_used, created_by)
      VALUES ($1, $2, $3, $4::jsonb, $5::jsonb, $6::jsonb, $7, $8, $9, $10, $11)
    ", params = list(
      scenario_name, scenario_type,
      if (is.null(school_id) || school_id == "") NA else school_id,
      jsonlite::toJSON(parameters, auto_unbox = TRUE),
      jsonlite::toJSON(baseline, auto_unbox = TRUE),
      jsonlite::toJSON(outcomes, auto_unbox = TRUE),
      impact_score, risk_level, model, tokens, user_id
    ))
  }, error = function(e) {
    log_warn("Scenari DB xətası: {e$message}")
  })
}

# --- Keçmiş hesabatları al ---
get_strategy_reports <- function(db_pool, report_type = NULL, limit = 20) {
  if (!is.null(report_type) && report_type != "") {
    db_query(db_pool, "
      SELECT sr.id, sr.report_type, sr.title, sr.academic_year, sr.ai_model,
             sr.tokens_used, sr.created_at, s.name AS school_name
      FROM strategy_reports sr
      LEFT JOIN schools s ON s.id = sr.school_id
      WHERE sr.report_type = $1
      ORDER BY sr.created_at DESC LIMIT $2
    ", params = list(report_type, limit))
  } else {
    db_query(db_pool, "
      SELECT sr.id, sr.report_type, sr.title, sr.academic_year, sr.ai_model,
             sr.tokens_used, sr.created_at, s.name AS school_name
      FROM strategy_reports sr
      LEFT JOIN schools s ON s.id = sr.school_id
      ORDER BY sr.created_at DESC LIMIT $1
    ", params = list(limit))
  }
}

get_strategy_report_detail <- function(db_pool, report_id) {
  db_get_one(db_pool, "
    SELECT sr.*, s.name AS school_name
    FROM strategy_reports sr
    LEFT JOIN schools s ON s.id = sr.school_id
    WHERE sr.id = $1
  ", params = list(report_id))
}

get_scenario_history <- function(db_pool, limit = 20) {
  db_query(db_pool, "
    SELECT ss.id, ss.scenario_name, ss.scenario_type, ss.impact_score,
           ss.risk_level, ss.created_at, s.name AS school_name
    FROM strategy_scenarios ss
    LEFT JOIN schools s ON s.id = ss.school_id
    ORDER BY ss.created_at DESC LIMIT $1
  ", params = list(limit))
}

# --- Benchmark funksiyalar ---
get_benchmark_data <- function(db_pool, countries = NULL) {
  if (!is.null(countries) && length(countries) > 0) {
    placeholders <- paste0("$", seq_along(countries), collapse = ", ")
    query <- sprintf("
      SELECT country, indicator, indicator_category, value, year, source
      FROM strategy_benchmarks
      WHERE country IN (%s)
      ORDER BY country, indicator, year DESC
    ", placeholders)
    db_query(db_pool, query, params = as.list(countries))
  } else {
    db_query(db_pool, "
      SELECT country, indicator, indicator_category, value, year, source
      FROM strategy_benchmarks
      ORDER BY country, indicator, year DESC
    ")
  }
}

save_benchmark_entry <- function(db_pool, country, indicator, category, value, year, source, notes = NULL) {
  tryCatch({
    db_execute(db_pool, "
      INSERT INTO strategy_benchmarks (country, indicator, indicator_category, value, year, source, notes)
      VALUES ($1, $2, $3, $4, $5, $6, $7)
      ON CONFLICT (country, indicator, year) DO UPDATE
      SET value = EXCLUDED.value, source = EXCLUDED.source, notes = EXCLUDED.notes
    ", params = list(country, indicator, category, value, year, source, notes))
  }, error = function(e) {
    log_warn("Benchmark DB xətası: {e$message}")
  })
}
