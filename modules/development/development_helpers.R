# =============================================
# Peşəkar İnkişaf Modulu - Köməkçi Funksiyalar
# =============================================

#' Təlim məlumatlarını yoxla
#' @param data Təlim formu məlumatları
#' @return Xəta mesajları vektoru
validate_training <- function(data) {
  errors <- character(0)

  if (is_empty(data$title)) {
    errors <- c(errors, "Təlim adı daxil edilməlidir")
  }

  if (is_empty(data$training_type)) {
    errors <- c(errors, "Təlim növü seçilməlidir")
  }

  if (!is.null(data$start_date) && !is.null(data$end_date)) {
    if (!is.na(data$start_date) && !is.na(data$end_date)) {
      if (as.Date(data$end_date) < as.Date(data$start_date)) {
        errors <- c(errors, "Bitmə tarixi başlama tarixindən sonra olmalıdır")
      }
    }
  }

  if (!is.null(data$duration_hours) && !is.na(data$duration_hours)) {
    if (data$duration_hours < 1 || data$duration_hours > 500) {
      errors <- c(errors, "Təlim müddəti 1-500 saat arasında olmalıdır")
    }
  }

  if (!is.null(data$max_participants) && !is.na(data$max_participants)) {
    if (data$max_participants < 1) {
      errors <- c(errors, "İştirakçı sayı ən azı 1 olmalıdır")
    }
  }

  errors
}

#' Kurs məlumatlarını yoxla
#' @param data Kurs formu məlumatları
#' @return Xəta mesajları vektoru
validate_course <- function(data) {
  errors <- character(0)

  if (is_empty(data$title)) {
    errors <- c(errors, "Kurs adı daxil edilməlidir")
  }

  if (!is.null(data$duration_hours) && !is.na(data$duration_hours)) {
    if (data$duration_hours < 1) {
      errors <- c(errors, "Kurs müddəti ən azı 1 saat olmalıdır")
    }
  }

  if (!is.null(data$price) && !is.na(data$price)) {
    if (data$price < 0) {
      errors <- c(errors, "Qiymət mənfi ola bilməz")
    }
  }

  errors
}

#' Peşəkar inkişaf balını hesabla
#' @param db_pool Verilənlər bazası pool
#' @param user_id İstifadəçi ID
#' @return İnkişaf bali (0-100)
calculate_development_score <- function(db_pool, user_id) {
  # Tamamlanmış təlim saatları
  training_hours <- db_get_one(db_pool,
    "SELECT COALESCE(SUM(tp.duration_hours), 0) as total
     FROM training_programs tp
     JOIN teacher_trainings tt ON tt.title = tp.title
     WHERE tt.teacher_id = $1 AND tt.status = 'completed'",
    params = list(user_id))

  # Tamamlanmış onlayn kurslar
  completed_courses <- db_get_one(db_pool,
    "SELECT COUNT(*) as cnt FROM course_enrollments
     WHERE user_id = $1 AND status = 'completed'",
    params = list(user_id))

  # Mentorluq təcrübəsi
  mentorship_count <- db_get_one(db_pool,
    "SELECT COUNT(*) as cnt FROM mentorship_pairs
     WHERE (mentor_id = $1 OR mentee_id = $1) AND status IN ('active', 'completed')",
    params = list(user_id))

  # Bal hesabla (çəkili orta)
  hours_score <- min(training_hours$total / 100 * 40, 40)  # Maks 40 bal
  course_score <- min(completed_courses$cnt * 10, 30)       # Maks 30 bal
  mentor_score <- min(mentorship_count$cnt * 10, 30)        # Maks 30 bal

  round(hours_score + course_score + mentor_score, 1)
}

#' Mentor-mentee uyğunlaşdırma
#' @param db_pool Verilənlər bazası pool
#' @param mentee_id Mentee ID
#' @param subject_area Fənn sahəsi (optional)
#' @return Uyğun mentorlar siyahısı
match_mentor <- function(db_pool, mentee_id, subject_area = NULL) {
  query <- "SELECT u.id, u.username, u.email, t.category,
                   COUNT(mp.id) AS active_mentees
            FROM users u
            JOIN teachers t ON t.user_id = u.id
            LEFT JOIN mentorship_pairs mp ON mp.mentor_id = u.id AND mp.status = 'active'
            WHERE u.role = 'teacher'
              AND u.id != $1
              AND t.category IN ('Ali kateqoriya', 'I kateqoriya')"
  params <- list(mentee_id)
  param_idx <- 2

  if (!is.null(subject_area) && !is_empty(subject_area)) {
    query <- paste0(query, " AND EXISTS (
      SELECT 1 FROM teacher_subjects ts
      JOIN subjects s ON ts.subject_id = s.id
      WHERE ts.teacher_id = t.id AND s.name = $", param_idx, ")")
    params[[param_idx]] <- subject_area
    param_idx <- param_idx + 1
  }

  query <- paste0(query, " GROUP BY u.id, u.username, u.email, t.category
                           HAVING COUNT(mp.id) < 3
                           ORDER BY t.category, active_mentees ASC
                           LIMIT 10")

  db_query(db_pool, query, params = params)
}

#' Kurs tamamlanma faizini hesabla
#' @param db_pool Verilənlər bazası pool
#' @param course_id Kurs ID
#' @return Tamamlanma statistikası
get_course_completion_stats <- function(db_pool, course_id) {
  db_get_one(db_pool,
    "SELECT COUNT(*) as total_enrolled,
            COUNT(*) FILTER (WHERE status = 'completed') as completed,
            COUNT(*) FILTER (WHERE status = 'active') as active,
            COUNT(*) FILTER (WHERE status = 'dropped') as dropped,
            COALESCE(AVG(progress), 0) as avg_progress,
            COALESCE(AVG(score) FILTER (WHERE status = 'completed'), 0) as avg_score
     FROM course_enrollments
     WHERE course_id = $1",
    params = list(course_id))
}
