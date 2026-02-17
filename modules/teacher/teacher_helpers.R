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
    "SELECT * FROM professional_development WHERE teacher_id = $1 ORDER BY date_start DESC",
    params = list(teacher_id))

  list(teacher = teacher, kpis = kpis, workload = workload, trainings = trainings, generated_at = Sys.time())
}

#' KPI göstəricilərini hesabla
get_teacher_kpis <- function(db_pool, teacher_id, period = "current") {
  # Şagird nəticələri - müəllimin tədris etdiyi siniflərdə orta bal
  student_result <- db_query(db_pool,
    "SELECT AVG(g.score * 100.0 / NULLIF(g.max_score, 0)) as avg
     FROM grades g WHERE g.teacher_id = $1 AND g.academic_year = $2",
    params = list(teacher_id, get_academic_year()))
  student_outcomes <- if (nrow(student_result) > 0 && !is.na(student_result$avg[1])) student_result$avg[1] else 75

  # Davamiyyət - müəllimin dərs davamiyyəti
  attendance <- 95  # default

  # Peşəkar inkişaf
  dev_result <- db_query(db_pool,
    "SELECT COUNT(*) as count, SUM(hours) as total_hours FROM professional_development
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
