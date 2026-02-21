# =============================================
# ARTI-2026: Şagird Modulu - Köməkçi Funksiyalar
# =============================================

#' Şagird məlumatlarını doğrula
#' @param data list - Şagird form məlumatları
#' @return character vector - Xəta mesajları (boş = xəta yoxdur)
validate_student_data <- function(data) {
  errors <- character(0)

  if (is_empty(data$first_name)) errors <- c(errors, "Ad daxil edilməlidir")
  if (is_empty(data$last_name)) errors <- c(errors, "Soyad daxil edilməlidir")
  if (is_empty(data$father_name)) errors <- c(errors, "Ata adı daxil edilməlidir")

  if (is.null(data$birth_date) || is.na(data$birth_date)) {
    errors <- c(errors, "Doğum tarixi daxil edilməlidir")
  } else {
    age <- calculate_age(data$birth_date)
    if (!is.na(age) && (age < 5 || age > 20)) {
      errors <- c(errors, "Şagirdin yaşı 5-20 arasında olmalıdır")
    }
  }

  if (!is_empty(data$fin_code) && !validate_fin(data$fin_code)) {
    errors <- c(errors, "FİN kod düzgün formatda deyil (7 simvol)")
  }

  if (is_empty(data$address)) errors <- c(errors, "Ünvan daxil edilməlidir")
  if (is_empty(data$class_grade)) errors <- c(errors, "Sinif seçilməlidir")
  if (is_empty(data$class_section)) errors <- c(errors, "Bölmə seçilməlidir")
  if (is_empty(data$mother_name)) errors <- c(errors, "Ananın adı daxil edilməlidir")

  if (!is_empty(data$mother_phone) && !validate_phone_az(data$mother_phone)) {
    errors <- c(errors, "Ana telefon nömrəsi düzgün formatda deyil (+994...)")
  }

  errors
}

#' GPA hesabla (Azərbaycan qiymət sistemi)
#' @param db_pool Verilənlər bazası
#' @param student_id Şagird ID
#' @param academic_year Tədris ili
#' @return numeric - Orta bal (0-100)
calculate_gpa <- function(db_pool, student_id, academic_year = NULL) {
  if (is.null(academic_year)) academic_year <- get_academic_year()
  result <- db_query(db_pool,
    "SELECT AVG(score) as gpa
     FROM grades WHERE student_id = $1 AND academic_year = $2",
    params = list(student_id, academic_year))
  if (nrow(result) > 0 && !is.na(result$gpa[1])) round(result$gpa[1], 1) else 0
}

#' Şagird hesabatı generasiya et
#' @param db_pool Verilənlər bazası
#' @param student_id Şagird ID
#' @param semester Yarımil
#' @param academic_year Tədris ili
#' @return list - Hesabat məlumatları
generate_student_report <- function(db_pool, student_id, semester = NULL, academic_year = NULL) {
  if (is.null(academic_year)) academic_year <- get_academic_year()

  student <- db_get_one(db_pool, "SELECT * FROM students WHERE id = $1", params = list(student_id))
  if (is.null(student)) return(NULL)

  # Qiymətlər
  grades <- db_query(db_pool,
    "SELECT sub.name, AVG(g.score) as avg_score
     FROM grades g JOIN subjects sub ON g.subject_id = sub.id
     WHERE g.student_id = $1 AND g.academic_year = $2
     GROUP BY sub.name ORDER BY avg_score DESC",
    params = list(student_id, academic_year))

  # Davamiyyət
  attendance <- db_query(db_pool,
    "SELECT status, COUNT(*) as count FROM attendance
     WHERE student_id = $1 AND attendance_date >= $2
     GROUP BY status",
    params = list(student_id, paste0(substr(academic_year, 1, 4), "-09-01")))

  gpa <- calculate_gpa(db_pool, student_id, academic_year)

  list(
    student = student, grades = grades, attendance = attendance,
    gpa = gpa, grade_label = get_grade_label(gpa),
    academic_year = academic_year, generated_at = Sys.time()
  )
}

#' Risk altında olan şagirdləri müəyyənləşdir
#' @param db_pool Verilənlər bazası
#' @param threshold Risk həddi (default: 0.3)
#' @return data.frame - Risk şagirdləri
get_risk_students <- function(db_pool, threshold = 0.3) {
  query <- "SELECT s.id, s.first_name, s.last_name, c.grade, c.section,
                   AVG(g.score) as avg_score,
                   (SELECT COUNT(*) FROM attendance a
                    WHERE a.student_id = s.id AND a.status = 'absent'
                    AND a.attendance_date >= CURRENT_DATE - INTERVAL '30 days') as absences_30d
            FROM students s
            JOIN classes c ON s.class_id = c.id
            LEFT JOIN grades g ON g.student_id = s.id
            WHERE s.status = 'active'
            GROUP BY s.id, s.first_name, s.last_name, c.grade, c.section
            HAVING AVG(g.score) < 51
               OR (SELECT COUNT(*) FROM attendance a
                   WHERE a.student_id = s.id AND a.status = 'absent'
                   AND a.attendance_date >= CURRENT_DATE - INTERVAL '30 days') > 5
            ORDER BY avg_score ASC"
  db_query(db_pool, query)
}

#' Davamiyyət məlumatlarını format et
#' @param data data.frame - Davamiyyət raw data
#' @return data.frame - Formatlanmış data
format_attendance_data <- function(data) {
  if (is.null(data) || nrow(data) == 0) return(data.frame())

  data %>%
    mutate(
      status_label = case_when(
        status == "present" ~ "İştirak",
        status == "absent"  ~ "Qayıb",
        status == "late"    ~ "Gecikmiş",
        status == "excused" ~ "Üzrlü",
        TRUE ~ status
      ),
      status_icon = case_when(
        status == "present" ~ '<i class="fa fa-check-circle" style="color:#27ae60"></i>',
        status == "absent"  ~ '<i class="fa fa-times-circle" style="color:#e74c3c"></i>',
        status == "late"    ~ '<i class="fa fa-clock" style="color:#f39c12"></i>',
        status == "excused" ~ '<i class="fa fa-info-circle" style="color:#3498db"></i>',
        TRUE ~ ""
      ),
      date_formatted = format_date_az(date)
    )
}

# =============================================
# AI Tutor Köməkçi Funksiyalar
# =============================================

#' Şagird kontekstini AI Tutor üçün topla
#' @param db_pool DB pool
#' @param student_id Şagird ID
#' @param subject Cari fənn
#' @param academic_year Tədris ili
#' @return list - kontekst məlumatları
build_tutor_context <- function(db_pool, student_id, subject, academic_year = NULL) {
  if (is.null(academic_year)) academic_year <- get_academic_year()

  # Şagird əsas məlumatları
  student <- tryCatch(
    db_get_one(db_pool,
      "SELECT s.first_name, s.last_name, c.grade, c.section
       FROM students s LEFT JOIN classes c ON s.class_id = c.id
       WHERE s.id = $1",
      params = list(student_id)),
    error = function(e) list(first_name = "Şagird", last_name = "", grade = 8, section = "A")
  )

  name <- paste(student$first_name %||% "Şagird", student$last_name %||% "")
  grade <- student$grade %||% 8

  # Fənn üzrə qiymətlər — güclü/zəif tərəflər
  grades <- tryCatch(
    db_query(db_pool,
      "SELECT sub.name as subject, ROUND(AVG(g.score)::numeric, 1) as avg_score
       FROM grades g JOIN subjects sub ON g.subject_id = sub.id
       WHERE g.student_id = $1 AND g.academic_year = $2
       GROUP BY sub.name ORDER BY avg_score DESC",
      params = list(student_id, academic_year)),
    error = function(e) data.frame()
  )

  strengths <- ""
  weaknesses <- ""
  if (nrow(grades) > 0) {
    strong <- grades[grades$avg_score >= 71, ]
    weak <- grades[grades$avg_score < 51, ]
    if (nrow(strong) > 0) strengths <- paste(sprintf("%s (%s)", strong$subject, strong$avg_score), collapse = ", ")
    if (nrow(weak) > 0) weaknesses <- paste(sprintf("%s (%s)", weak$subject, weak$avg_score), collapse = ", ")
  }

  list(
    name = trimws(name),
    grade = grade,
    section = student$section %||% "",
    strengths = strengths,
    weaknesses = weaknesses
  )
}

#' Tutor cavabını markdown-dan HTML-ə çevir
#' @param text Markdown mətni
#' @return HTML mətni
tutor_md_to_html <- function(text) {
  if (is.null(text) || nchar(text) == 0) return("")
  html <- text
  # Kod bloku
  html <- gsub("```([^`]+)```", "<pre style='background:#f5f5f5;padding:8px;border-radius:6px;font-size:0.9em;'>\\1</pre>", html)
  html <- gsub("`([^`]+)`", "<code style='background:#f0f0f0;padding:1px 4px;border-radius:3px;'>\\1</code>", html)
  # Başlıqlar
  html <- gsub("### (.+)", "<h5 style='color:#2c3e50;margin:8px 0 4px;'>\\1</h5>", html)
  html <- gsub("## (.+)", "<h4 style='color:#2c3e50;margin:8px 0 4px;'>\\1</h4>", html)
  # Qalın + kursiv
  html <- gsub("\\*\\*(.+?)\\*\\*", "<strong>\\1</strong>", html)
  html <- gsub("\\*(.+?)\\*", "<em>\\1</em>", html)
  # Nömrəli siyahı
  html <- gsub("^(\\d+)\\. (.+)", "<div style='margin-left:12px;'><strong>\\1.</strong> \\2</div>", html)
  # Siyahı
  html <- gsub("^- (.+)", "<li style='margin-left:12px;'>\\1</li>", html)
  # Abzas
  html <- gsub("\n\n", "</p><p>", html)
  html <- gsub("\n", "<br>", html)
  html
}
