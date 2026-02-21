# =============================================
# ARTI-2026: Valideyn Əlaqə Modulu — Yardımçı Funksiyalar
# =============================================

# --- Şagird siyahısı (dropdown) ---
get_student_choices <- function(db_pool, school_id = NULL, class_grade = NULL) {
  where <- "s.status = 'active'"
  params <- list()
  p <- 0

  if (!is.null(school_id) && school_id != "") {
    p <- p + 1
    where <- paste(where, sprintf("AND s.school_id = $%d", p))
    params[[p]] <- school_id
  }
  if (!is.null(class_grade) && class_grade != "") {
    p <- p + 1
    where <- paste(where, sprintf("AND c.grade = $%d", p))
    params[[p]] <- as.integer(class_grade)
  }

  query <- sprintf("
    SELECT s.id, s.first_name || ' ' || s.last_name || ' (' || c.grade || '-' || c.section || ')' AS label
    FROM students s
    LEFT JOIN classes c ON c.id = s.class_id
    WHERE %s
    ORDER BY c.grade, c.section, s.last_name, s.first_name
  ", where)

  students <- if (length(params) > 0) db_query(db_pool, query, params = params) else db_query(db_pool, query)
  if (is.null(students) || nrow(students) == 0) return(c("Şagird yoxdur" = ""))
  choices <- setNames(students$id, students$label)
  c("Seçin..." = "", choices)
}

# --- Məktəb siyahısı ---
get_school_choices_parent <- function(db_pool) {
  schools <- db_query(db_pool, "
    SELECT id, name FROM schools WHERE status = 'active' ORDER BY name
  ")
  if (is.null(schools) || nrow(schools) == 0) return(c("Məktəb yoxdur" = ""))
  c("Bütün məktəblər" = "", setNames(schools$id, schools$name))
}

# --- Sinif üzrə şagird ID-ləri ---
get_students_by_class <- function(db_pool, school_id = NULL, class_grade = NULL, class_section = NULL) {
  where <- "s.status = 'active'"
  params <- list()
  p <- 0

  if (!is.null(school_id) && school_id != "") {
    p <- p + 1
    where <- paste(where, sprintf("AND s.school_id = $%d", p))
    params[[p]] <- school_id
  }
  if (!is.null(class_grade) && class_grade != "") {
    p <- p + 1
    where <- paste(where, sprintf("AND c.grade = $%d", p))
    params[[p]] <- as.integer(class_grade)
  }
  if (!is.null(class_section) && class_section != "") {
    p <- p + 1
    where <- paste(where, sprintf("AND c.section = $%d", p))
    params[[p]] <- class_section
  }

  query <- sprintf("
    SELECT s.id FROM students s
    LEFT JOIN classes c ON c.id = s.class_id
    WHERE %s ORDER BY s.last_name
  ", where)

  result <- if (length(params) > 0) db_query(db_pool, query, params = params) else db_query(db_pool, query)
  if (is.null(result) || nrow(result) == 0) return(character(0))
  result$id
}

# --- Statusların Azərbaycan etiketləri ---
LETTER_STATUS_LABELS <- c(
  draft = "Qaralama",
  edited = "Redaktə edilib",
  approved = "Təsdiq edilib",
  sent = "Göndərilib",
  failed = "Uğursuz"
)

LETTER_STATUS_COLORS <- c(
  draft = "default",
  edited = "info",
  approved = "warning",
  sent = "success",
  failed = "danger"
)

SEND_VIA_LABELS <- c(
  email = "E-poçt",
  sms = "SMS",
  both = "Hər ikisi",
  none = "Göndərilməyib"
)

# --- Status badge ---
letter_status_badge <- function(status) {
  label <- LETTER_STATUS_LABELS[status] %||% status
  color <- LETTER_STATUS_COLORS[status] %||% "default"
  sprintf('<span class="label label-%s">%s</span>', color, label)
}

# --- Göndərmə jurnalı ---
get_message_log <- function(db_pool, letter_id) {
  db_query(db_pool, "
    SELECT channel, recipient, status, sent_at, delivered_at, error_message
    FROM parent_message_log
    WHERE letter_id = $1
    ORDER BY created_at DESC
  ", params = list(letter_id))
}

# --- Sinif bölmələri ---
get_class_sections <- function(db_pool, school_id = NULL) {
  if (!is.null(school_id) && school_id != "") {
    db_query(db_pool, "
      SELECT DISTINCT grade, section FROM classes
      WHERE school_id = $1 AND academic_year = $2
      ORDER BY grade, section
    ", params = list(school_id, get_academic_year()))
  } else {
    db_query(db_pool, "
      SELECT DISTINCT grade, section FROM classes
      WHERE academic_year = $1
      ORDER BY grade, section
    ", params = list(get_academic_year()))
  }
}
