# =============================================
# Sertifikasiya Modulu - Köməkçi Funksiyalar
# =============================================

#' İmtahan məlumatlarını yoxla
#' @param data İmtahan formu məlumatları
#' @return Xəta mesajları vektoru (boş = xəta yoxdur)
validate_exam_data <- function(data) {
  errors <- character(0)

  if (is_empty(data$title)) {
    errors <- c(errors, "İmtahan adı daxil edilməlidir")
  }

  if (is_empty(data$exam_type)) {
    errors <- c(errors, "İmtahan növü seçilməlidir")
  }

  if (!is.null(data$duration_minutes) && !is.na(data$duration_minutes)) {
    if (data$duration_minutes < 15 || data$duration_minutes > 480) {
      errors <- c(errors, "İmtahan müddəti 15-480 dəqiqə arasında olmalıdır")
    }
  }

  if (!is.null(data$passing_score) && !is.na(data$passing_score)) {
    if (data$passing_score < 0 || data$passing_score > 100) {
      errors <- c(errors, "Keçid balı 0-100 arasında olmalıdır")
    }
  }

  if (!is.null(data$exam_date) && !is.na(data$exam_date)) {
    if (as.Date(data$exam_date) < Sys.Date()) {
      errors <- c(errors, "İmtahan tarixi keçmiş ola bilməz")
    }
  }

  if (!is.null(data$max_participants) && !is.na(data$max_participants)) {
    if (data$max_participants < 1) {
      errors <- c(errors, "Maksimum iştirakçı sayı ən azı 1 olmalıdır")
    }
  }

  errors
}

#' Sual məlumatlarını yoxla
#' @param data Sual formu məlumatları
#' @return Xəta mesajları vektoru
validate_question_data <- function(data) {
  errors <- character(0)

  if (is_empty(data$question_text)) {
    errors <- c(errors, "Sual mətni daxil edilməlidir")
  }

  if (is_empty(data$correct_answer)) {
    errors <- c(errors, "Düzgün cavab seçilməlidir")
  }

  if (data$question_type == "mcq") {
    if (is_empty(data$option_a) || is_empty(data$option_b)) {
      errors <- c(errors, "Ən azı 2 variant daxil edilməlidir")
    }
  }

  errors
}

#' İmtahan nəticələrini hesabla
#' @param db_pool Verilənlər bazası pool
#' @param exam_id İmtahan ID
#' @return Nəticə statistikası data.frame
calculate_exam_results <- function(db_pool, exam_id) {
  results <- db_query(db_pool,
    "SELECT cr.*, ce.passing_score, ce.title AS exam_title,
            u.username, u.email
     FROM certification_results cr
     JOIN certification_exams ce ON cr.exam_id = ce.id
     JOIN users u ON cr.user_id = u.id
     WHERE cr.exam_id = $1
     ORDER BY cr.score DESC",
    params = list(exam_id))

  if (nrow(results) == 0) return(results)

  stats <- list(
    total_participants = nrow(results),
    passed_count = sum(results$passed, na.rm = TRUE),
    failed_count = sum(!results$passed, na.rm = TRUE),
    avg_score = round(mean(results$score, na.rm = TRUE), 1),
    max_score = max(results$score, na.rm = TRUE),
    min_score = min(results$score, na.rm = TRUE),
    pass_rate = round(sum(results$passed, na.rm = TRUE) / nrow(results) * 100, 1)
  )

  list(results = results, stats = stats)
}

#' Sertifikat nömrəsi yarat
#' @param exam_type İmtahan növü
#' @param user_id İstifadəçi ID
#' @return Sertifikat nömrəsi
generate_certificate <- function(exam_type, user_id) {
  prefix <- switch(exam_type,
    "ise_qebul" = "IQ",
    "sertifikasiya" = "SC",
    "CERT"
  )
  timestamp <- format(Sys.time(), "%Y%m%d")
  suffix <- substr(gsub("-", "", user_id), 1, 8)
  paste0(prefix, "-", timestamp, "-", toupper(suffix))
}

#' İmtahan statistikası hesabla
#' @param db_pool Verilənlər bazası pool
#' @param exam_id İmtahan ID
#' @return Sual səviyyəli statistika
calculate_question_stats <- function(db_pool, exam_id) {
  db_query(db_pool,
    "SELECT cq.id, cq.question_text, cq.difficulty,
            COUNT(cr.id) AS attempt_count,
            cq.points
     FROM certification_questions cq
     LEFT JOIN certification_results cr ON cr.exam_id = cq.exam_id
     WHERE cq.exam_id = $1
     GROUP BY cq.id, cq.question_text, cq.difficulty, cq.points
     ORDER BY cq.sort_order",
    params = list(exam_id))
}

#' İmtahanın avtomatik planlaşdırılması
#' @param db_pool Verilənlər bazası pool
#' @param exam_data İmtahan konfiqurasiyası
#' @return Yaradılmış imtahan ID
schedule_exam <- function(db_pool, exam_data) {
  db_execute(db_pool,
    "INSERT INTO certification_exams
     (title, exam_type, subject_id, description, duration_minutes,
      total_questions, passing_score, exam_date, start_time, location,
      max_participants, status, created_by)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, 'planned', $12)
     RETURNING id",
    params = list(
      exam_data$title, exam_data$exam_type, exam_data$subject_id,
      exam_data$description, exam_data$duration_minutes,
      exam_data$total_questions, exam_data$passing_score,
      exam_data$exam_date, exam_data$start_time, exam_data$location,
      exam_data$max_participants, exam_data$created_by
    ))
}
