# =============================================
# ARTI-2026: Müəllim Modulu - Köməkçi Funksiyalar
# =============================================

#' Müəllim məlumatlarını doğrula
validate_teacher_data <- function(data) {
  errors <- character(0)
  if (is_empty(data$first_name)) errors <- c(errors, "Ad tələb olunur")
  if (is_empty(data$last_name)) errors <- c(errors, "Soyad tələb olunur")
  if (is_empty(data$specialty)) errors <- c(errors, "İxtisas tələb olunur")
  if (!is_empty(data$category) && !data$category %in% TEACHER_CATEGORIES)
    errors <- c(errors, "Yanlış kateqoriya seçildi")
  if (!is.null(data$experience_years) && (data$experience_years < 0 || data$experience_years > 50))
    errors <- c(errors, "Təcrübə ili 0-50 arasında olmalıdır")
  errors
}

#' İş yükü statistikasını hesabla
calculate_workload_stats <- function(db_pool, teacher_id, academic_year = NULL) {
  if (is.null(academic_year)) academic_year <- get_academic_year()
  schedule <- db_query(db_pool,
    "SELECT day_of_week, COUNT(*) as hours FROM teacher_schedule
     WHERE teacher_id = $1 AND academic_year = $2 GROUP BY day_of_week",
    params = list(teacher_id, academic_year))

  total <- sum(schedule$hours, na.rm = TRUE)
  list(
    total_hours = total,
    daily_hours = schedule,
    is_below_min = total < SYSTEM_LIMITS$min_weekly_hours_teacher,
    is_above_max = total > SYSTEM_LIMITS$max_weekly_hours_teacher,
    status = if (total < 18) "Aşağı" else if (total <= 36) "Normal" else "Yüksək"
  )
}

#' Müəllim hesabatı generasiya et
generate_teacher_report <- function(db_pool, teacher_id, period = "current") {
  teacher <- db_get_one(db_pool, "SELECT * FROM teachers WHERE id = $1", params = list(teacher_id))
  if (is.null(teacher)) return(NULL)

  kpis <- get_teacher_kpis(db_pool, teacher_id, period)
  workload <- calculate_workload_stats(db_pool, teacher_id)

  trainings <- db_query(db_pool,
    "SELECT * FROM teacher_trainings WHERE teacher_id = $1 ORDER BY start_date DESC",
    params = list(teacher_id))

  list(teacher = teacher, kpis = kpis, workload = workload, trainings = trainings, generated_at = Sys.time())
}

#' KPI göstəricilərini hesabla
get_teacher_kpis <- function(db_pool, teacher_id, period = "current") {
  # Şagird nəticələri - müəllimin tədris etdiyi siniflərdə orta bal
  student_result <- db_query(db_pool,
    "SELECT AVG(g.score) as avg
     FROM grades g WHERE g.teacher_id = $1 AND g.academic_year = $2",
    params = list(teacher_id, get_academic_year()))
  student_outcomes <- if (nrow(student_result) > 0 && !is.na(student_result$avg[1])) student_result$avg[1] else 75

  # Davamiyyət - müəllimin dərs davamiyyəti
  attendance <- 95  # default

  # Peşəkar inkişaf
  dev_result <- db_query(db_pool,
    "SELECT COUNT(*) as count, COALESCE(SUM(hours), 0) as total_hours FROM teacher_trainings
     WHERE teacher_id = $1 AND status = 'completed'",
    params = list(teacher_id))
  development <- min(100, (dev_result$total_hours[1] %||% 0) / 2)

  overall <- mean(c(student_outcomes, attendance, development))

  list(student_outcomes = student_outcomes, attendance = attendance,
       development = development, overall = overall)
}

#' Cədvəl məlumatlarını format et
format_schedule_data <- function(schedule) {
  if (is.null(schedule) || nrow(schedule) == 0) return(data.frame())
  schedule %>%
    mutate(day_label = WEEKDAYS_AZ[day_of_week],
           period_label = paste0(period, ". dərs"))
}

#' TALIS profilini əldə et
get_teacher_talis_profile <- function(db_pool, teacher_id, assessment_year = NULL) {
  if (is.null(assessment_year)) assessment_year <- get_academic_year()
  talis <- db_get_one(db_pool,
    "SELECT * FROM teacher_talis_indicators
     WHERE teacher_id = $1 AND assessment_year = $2",
    params = list(teacher_id, assessment_year))
  if (is.null(talis)) return(NULL)
  talis
}

#' Müəllimin mükafatlarını əldə et
get_teacher_awards <- function(db_pool, teacher_id) {
  db_query(db_pool,
    "SELECT title, awarding_body, award_type, award_date, description
     FROM teacher_awards WHERE teacher_id = $1 ORDER BY award_date DESC",
    params = list(teacher_id))
}

#' Müəllimin nəşrlərini əldə et
get_teacher_publications <- function(db_pool, teacher_id) {
  db_query(db_pool,
    "SELECT title, publication_type, journal_name, publication_date, doi, is_peer_reviewed
     FROM teacher_publications WHERE teacher_id = $1 ORDER BY publication_date DESC",
    params = list(teacher_id))
}

#' Kompozit performans balını hesabla (TALIS əsaslı)
calculate_teacher_composite_score <- function(db_pool, teacher_id) {
  talis <- get_teacher_talis_profile(db_pool, teacher_id)
  if (is.null(talis)) return(list(score = NA, components = list()))

  teacher <- db_get_one(db_pool,
    "SELECT category, certification_score, experience_years FROM teachers WHERE id = $1",
    params = list(teacher_id))

  # Komponent balları (0-100 şkalası)
  teaching_quality <- min(100, ((talis$self_efficacy %||% 5) +
                                 (talis$classroom_management %||% 5)) / 2 * 10)
  student_outcomes <- talis$student_pass_rate %||% 70
  professional_dev <- min(100, (talis$cpd_hours %||% 0) / 1.5)
  collaboration    <- min(100, (talis$collaboration_score %||% 5) * 10)
  ict_integration  <- min(100, (talis$digital_content_count %||% 0) * 5 +
                           ifelse(talis$ict_usage_frequency %in% c("hər_dərs", "həftəlik"), 30, 0))
  cert_score       <- teacher$certification_score %||% 50

  # Çəkili orta
  composite <- (teaching_quality * 0.25 + student_outcomes * 0.25 +
                professional_dev * 0.15 + collaboration * 0.10 +
                ict_integration * 0.10 + cert_score * 0.15)

  list(
    score = round(composite, 1),
    components = list(
      teaching_quality = round(teaching_quality, 1),
      student_outcomes = round(student_outcomes, 1),
      professional_dev = round(professional_dev, 1),
      collaboration    = round(collaboration, 1),
      ict_integration  = round(ict_integration, 1),
      certification    = round(cert_score, 1)
    )
  )
}
