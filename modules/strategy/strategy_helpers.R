# =============================================
# ARTI-2026: Strategiya Modulu — Yardımçı Funksiyalar
# =============================================

# --- Məktəb siyahısını al (dropdown üçün) ---
get_school_choices <- function(db_pool) {
  schools <- db_query(db_pool, "
    SELECT id, name FROM schools WHERE status = 'active' ORDER BY name
  ")
  if (is.null(schools) || nrow(schools) == 0) return(c("Məktəb yoxdur" = ""))
  choices <- setNames(schools$id, schools$name)
  c("Bütün məktəblər" = "", choices)
}

# --- Məktəblərarası müqayisə cədvəli ---
get_schools_comparison_table <- function(db_pool) {
  db_query(db_pool, "
    SELECT s.name AS school_name, s.type AS school_type, s.region,
           COUNT(DISTINCT st.id) AS student_count,
           COUNT(DISTINCT t.id) AS teacher_count,
           CASE WHEN COUNT(DISTINCT t.id) > 0
             THEN ROUND(COUNT(DISTINCT st.id)::numeric / COUNT(DISTINCT t.id), 1)
             ELSE 0 END AS student_teacher_ratio,
           COALESCE(ROUND(AVG(g.score)::numeric, 1), 0) AS avg_score
    FROM schools s
    LEFT JOIN students st ON st.school_id = s.id AND st.status = 'active'
    LEFT JOIN teachers t ON t.school_id = s.id AND t.status = 'active'
    LEFT JOIN grades g ON g.student_id = st.id AND g.academic_year = $1
    WHERE s.status = 'active'
    GROUP BY s.id, s.name, s.type, s.region
    ORDER BY avg_score DESC
  ", params = list(get_academic_year()))
}

# --- Müəllim paylanması (kateqoriya × məktəb) ---
get_teacher_distribution <- function(db_pool) {
  db_query(db_pool, "
    SELECT s.name AS school_name, t.category,
           t.specialization AS subject,
           COUNT(t.id) AS teacher_count,
           ROUND(AVG(t.experience_years)::numeric, 1) AS avg_experience
    FROM teachers t
    JOIN schools s ON s.id = t.school_id
    WHERE t.status = 'active'
    GROUP BY s.name, t.category, t.specialization
    ORDER BY s.name, t.category
  ")
}

# --- Fənn çatışmazlıq analizi ---
get_subject_coverage <- function(db_pool) {
  db_query(db_pool, "
    SELECT s.name AS school_name, sub.name AS subject,
           COUNT(DISTINCT t.id) AS teacher_count,
           COUNT(DISTINCT c.id) AS class_count,
           CASE WHEN COUNT(DISTINCT c.id) > 0
             THEN ROUND(COUNT(DISTINCT t.id)::numeric / COUNT(DISTINCT c.id), 2)
             ELSE 0 END AS coverage_ratio
    FROM schools s
    CROSS JOIN subjects sub
    LEFT JOIN teachers t ON t.school_id = s.id AND t.specialization = sub.name AND t.status = 'active'
    LEFT JOIN classes c ON c.school_id = s.id
    WHERE s.status = 'active'
    GROUP BY s.name, sub.name
    ORDER BY coverage_ratio ASC
  ")
}

# --- TALIS göstəriciləri (məktəb ortalaması) ---
get_school_talis_averages <- function(db_pool) {
  db_query(db_pool, "
    SELECT s.name AS school_name,
           ROUND(AVG(tti.self_efficacy)::numeric, 1) AS self_efficacy,
           ROUND(AVG(tti.job_satisfaction)::numeric, 1) AS job_satisfaction,
           ROUND(AVG(tti.classroom_management)::numeric, 1) AS classroom_management,
           ROUND(AVG(tti.cpd_hours)::numeric, 0) AS cpd_hours,
           ROUND(AVG(tti.cpd_impact_score)::numeric, 1) AS cpd_impact,
           ROUND(AVG(tti.collaboration_score)::numeric, 1) AS collaboration,
           ROUND(AVG(tti.student_pass_rate)::numeric, 1) AS pass_rate
    FROM teacher_talis_indicators tti
    JOIN teachers t ON t.id = tti.teacher_id
    JOIN schools s ON s.id = t.school_id
    WHERE t.status = 'active'
    GROUP BY s.name
    ORDER BY s.name
  ")
}

# --- Performans trendi (son 6 ay) ---
get_performance_trend_by_school <- function(db_pool) {
  db_query(db_pool, "
    SELECT s.name AS school_name,
           DATE_TRUNC('month', g.grade_date) AS month,
           ROUND(AVG(g.score)::numeric, 1) AS avg_score
    FROM grades g
    JOIN students st ON st.id = g.student_id
    JOIN schools s ON s.id = st.school_id
    WHERE g.grade_date >= (CURRENT_DATE - INTERVAL '6 months')
    GROUP BY s.name, DATE_TRUNC('month', g.grade_date)
    ORDER BY s.name, month
  ")
}

# --- Ümumi statistika kartları ---
get_district_summary <- function(db_pool) {
  list(
    total_schools = get_total_count(db_pool, "schools", "status = 'active'"),
    total_students = get_total_count(db_pool, "students", "status = 'active'"),
    total_teachers = get_total_count(db_pool, "teachers", "status = 'active'"),
    avg_score = tryCatch({
      r <- db_get_one(db_pool, "SELECT ROUND(AVG(score)::numeric, 1) AS avg FROM grades WHERE academic_year = $1",
                      params = list(get_academic_year()))
      r$avg %||% 0
    }, error = function(e) 0),
    avg_attendance = tryCatch({
      r <- db_get_one(db_pool, "
        SELECT ROUND(100.0 * COUNT(CASE WHEN status = 'present' THEN 1 END)::numeric / NULLIF(COUNT(*), 0), 1) AS rate
        FROM attendance WHERE attendance_date >= (CURRENT_DATE - INTERVAL '3 months')
      ")
      r$rate %||% 0
    }, error = function(e) 0)
  )
}

# --- Benchmark cədvəli (PISA) ---
PISA_BENCHMARK_DATA <- list(
  list(country = "Azərbaycan", math = 420, reading = 389, science = 398, year = 2022),
  list(country = "Finlandiya",  math = 484, reading = 490, science = 511, year = 2022),
  list(country = "Sinqapur",    math = 575, reading = 543, science = 561, year = 2022),
  list(country = "Cənubi Koreya", math = 527, reading = 515, science = 528, year = 2022),
  list(country = "Estoniya",    math = 510, reading = 511, science = 530, year = 2022),
  list(country = "Yaponiya",    math = 536, reading = 516, science = 547, year = 2022),
  list(country = "Türkiyə",     math = 453, reading = 456, science = 476, year = 2022),
  list(country = "OECD Orta",   math = 472, reading = 476, science = 485, year = 2022)
)

get_pisa_comparison_df <- function() {
  do.call(rbind, lapply(PISA_BENCHMARK_DATA, function(x) {
    data.frame(
      country = x$country,
      math = x$math,
      reading = x$reading,
      science = x$science,
      year = x$year,
      stringsAsFactors = FALSE
    )
  }))
}

# --- TALIS benchmark cədvəli ---
TALIS_COUNTRY_DATA <- list(
  list(country = "Azərbaycan", self_efficacy = 6.8, job_satisfaction = 7.2, classroom_mgmt = 6.5,
       cpd_hours = 45, collaboration = 6.0, ict_usage = 5.5),
  list(country = "Finlandiya", self_efficacy = 7.8, job_satisfaction = 7.9, classroom_mgmt = 7.5,
       cpd_hours = 70, collaboration = 7.2, ict_usage = 7.0),
  list(country = "Sinqapur", self_efficacy = 7.5, job_satisfaction = 7.6, classroom_mgmt = 7.8,
       cpd_hours = 100, collaboration = 7.5, ict_usage = 8.0),
  list(country = "Estoniya", self_efficacy = 7.3, job_satisfaction = 7.4, classroom_mgmt = 7.2,
       cpd_hours = 55, collaboration = 6.9, ict_usage = 6.8),
  list(country = "Yaponiya", self_efficacy = 6.5, job_satisfaction = 6.8, classroom_mgmt = 7.3,
       cpd_hours = 40, collaboration = 7.0, ict_usage = 5.8),
  list(country = "Türkiyə", self_efficacy = 7.0, job_satisfaction = 7.1, classroom_mgmt = 6.8,
       cpd_hours = 50, collaboration = 6.3, ict_usage = 6.2),
  list(country = "OECD Orta", self_efficacy = 7.2, job_satisfaction = 7.5, classroom_mgmt = 7.0,
       cpd_hours = 60, collaboration = 6.8, ict_usage = 6.0)
)

get_talis_comparison_df <- function() {
  do.call(rbind, lapply(TALIS_COUNTRY_DATA, function(x) {
    data.frame(
      country = x$country,
      self_efficacy = x$self_efficacy,
      job_satisfaction = x$job_satisfaction,
      classroom_mgmt = x$classroom_mgmt,
      cpd_hours = x$cpd_hours,
      collaboration = x$collaboration,
      ict_usage = x$ict_usage,
      stringsAsFactors = FALSE
    )
  }))
}

# --- Scenari növü etiketləri ---
SCENARIO_TYPES <- c(
  teacher_hire = "Müəllim İşə Qəbulu",
  budget_change = "Büdcə Dəyişikliyi",
  class_restructure = "Sinif Yenidənqurma",
  resource_realloc = "Resurs Yenidən Bölgüsü",
  policy_change = "Siyasət Dəyişikliyi",
  custom = "Xüsusi Scenari"
)

# --- SWOT rəng sxemi ---
SWOT_COLORS <- list(
  strengths = "#27ae60",
  weaknesses = "#e74c3c",
  opportunities = "#3498db",
  threats = "#f39c12"
)

# --- Hesabat növü etiketləri ---
REPORT_TYPE_LABELS <- c(
  swot = "SWOT Analiz",
  resource_allocation = "Resurs Bölgüsü",
  teacher_optimization = "Müəllim Optimallaşdırma",
  budget_priority = "Büdcə Prioritetləri",
  comprehensive = "Hərtərəfli Hesabat"
)
