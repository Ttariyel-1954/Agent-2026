# =============================================
# ARTI-2026: Valideyn Əlaqə AI API
# Aylıq məktub generasiyası, SMS/E-poçt göndərmə
# =============================================

# --- Ayın adları (Azərbaycan) ---
MONTH_NAMES_AZ <- c(
  "Yanvar", "Fevral", "Mart", "Aprel", "May", "İyun",
  "İyul", "Avqust", "Sentyabr", "Oktyabr", "Noyabr", "Dekabr"
)

# --- Şagirdin aylıq məlumatlarını topla ---
collect_student_monthly_data <- function(db_pool, student_id, month, year, academic_year = NULL) {
  academic_year <- academic_year %||% get_academic_year()

  # Şagird əsas info
  student <- db_get_one(db_pool, "
    SELECT s.id, s.first_name, s.last_name,
           s.first_name || ' ' || s.last_name AS full_name,
           c.grade, c.section, sc.name AS school_name,
           sc.id AS school_id
    FROM students s
    LEFT JOIN classes c ON s.class_id = c.id
    LEFT JOIN schools sc ON s.school_id = sc.id
    WHERE s.id = $1
  ", params = list(student_id))

  if (is.null(student)) return(NULL)

  # Valideyn kontakt məlumatları
  parent <- tryCatch(
    db_get_one(db_pool, "
      SELECT first_name, last_name, phone, email, parent_type
      FROM student_parents
      WHERE student_id = $1 AND is_primary_contact = TRUE
      LIMIT 1
    ", params = list(student_id)),
    error = function(e) NULL
  )

  # Bu aydakı fənn üzrə qiymətlər
  grades <- tryCatch(
    db_query(db_pool, "
      SELECT sub.name AS subject, g.grade_type,
             ROUND(AVG(g.score)::numeric, 1) AS avg_score,
             COUNT(g.id) AS grade_count,
             MIN(g.score) AS min_score,
             MAX(g.score) AS max_score
      FROM grades g
      JOIN subjects sub ON sub.id = g.subject_id
      WHERE g.student_id = $1 AND g.academic_year = $2
            AND EXTRACT(MONTH FROM g.grade_date) = $3
            AND EXTRACT(YEAR FROM g.grade_date) = $4
      GROUP BY sub.name, g.grade_type
      ORDER BY sub.name
    ", params = list(student_id, academic_year, month, year)),
    error = function(e) data.frame()
  )

  # Ümumi fənn ortalamaları (bütün il)
  overall_grades <- tryCatch(
    db_query(db_pool, "
      SELECT sub.name AS subject,
             ROUND(AVG(g.score)::numeric, 1) AS avg_score
      FROM grades g
      JOIN subjects sub ON sub.id = g.subject_id
      WHERE g.student_id = $1 AND g.academic_year = $2
      GROUP BY sub.name ORDER BY sub.name
    ", params = list(student_id, academic_year)),
    error = function(e) data.frame()
  )

  # Davamiyyət (bu ay)
  attendance <- tryCatch(
    db_get_one(db_pool, "
      SELECT COUNT(*) AS total_days,
             SUM(CASE WHEN status = 'present' THEN 1 ELSE 0 END) AS present,
             SUM(CASE WHEN status = 'absent' THEN 1 ELSE 0 END) AS absent,
             SUM(CASE WHEN status = 'late' THEN 1 ELSE 0 END) AS late,
             SUM(CASE WHEN status = 'excused' THEN 1 ELSE 0 END) AS excused
      FROM attendance
      WHERE student_id = $1
            AND EXTRACT(MONTH FROM date) = $2
            AND EXTRACT(YEAR FROM date) = $3
    ", params = list(student_id, month, year)),
    error = function(e) list(total_days = 0, present = 0, absent = 0, late = 0, excused = 0)
  )

  # Ev tapşırığı statistikası (bu ay)
  homework <- tryCatch(
    db_get_one(db_pool, "
      SELECT COUNT(*) AS total,
             SUM(CASE WHEN g.score IS NOT NULL THEN 1 ELSE 0 END) AS submitted,
             ROUND(AVG(g.score)::numeric, 1) AS avg_score
      FROM grades g
      WHERE g.student_id = $1 AND g.grade_type = 'homework'
            AND g.academic_year = $2
            AND EXTRACT(MONTH FROM g.grade_date) = $3
            AND EXTRACT(YEAR FROM g.grade_date) = $4
    ", params = list(student_id, academic_year, month, year)),
    error = function(e) list(total = 0, submitted = 0, avg_score = 0)
  )

  # Sinif rəhbəri
  homeroom_teacher <- tryCatch(
    db_get_one(db_pool, "
      SELECT t.first_name || ' ' || t.last_name AS teacher_name
      FROM classes c
      JOIN teachers t ON t.id = c.homeroom_teacher_id
      WHERE c.id = (SELECT class_id FROM students WHERE id = $1)
    ", params = list(student_id)),
    error = function(e) list(teacher_name = "Sinif rəhbəri")
  )

  # Trend (bu ay vs əvvəlki ay)
  prev_month_avg <- tryCatch({
    pm <- if (month == 1) 12 else month - 1
    py <- if (month == 1) year - 1 else year
    r <- db_get_one(db_pool, "
      SELECT ROUND(AVG(g.score)::numeric, 1) AS avg
      FROM grades g WHERE g.student_id = $1 AND g.academic_year = $2
      AND EXTRACT(MONTH FROM g.grade_date) = $3 AND EXTRACT(YEAR FROM g.grade_date) = $4
    ", params = list(student_id, academic_year, pm, py))
    r$avg %||% 0
  }, error = function(e) 0)

  current_avg <- if (nrow(grades) > 0) round(mean(grades$avg_score, na.rm = TRUE), 1) else 0
  trend <- if (prev_month_avg > 0 && current_avg > 0) {
    diff <- current_avg - prev_month_avg
    if (diff > 2) "yüksəlir" else if (diff < -2) "düşür" else "sabit"
  } else "məlumat yoxdur"

  list(
    student = student,
    parent = parent,
    grades = grades,
    overall_grades = overall_grades,
    attendance = attendance,
    homework = homework,
    teacher = homeroom_teacher,
    current_avg = current_avg,
    trend = trend,
    prev_month_avg = prev_month_avg,
    month = month,
    year = year,
    academic_year = academic_year
  )
}

# --- Qiymətləri mətn formatına çevir ---
format_grades_for_prompt <- function(grades) {
  if (is.null(grades) || nrow(grades) == 0) return("Bu ay qiymət yoxdur")
  lines <- sapply(seq_len(nrow(grades)), function(i) {
    g <- grades[i, ]
    label <- get_grade_label(g$avg_score)
    sprintf("- %s: %.1f (%s), min=%s, max=%s, qiymət sayı=%d",
            g$subject, g$avg_score, label,
            g$min_score %||% "N/A", g$max_score %||% "N/A", g$grade_count)
  })
  paste(lines, collapse = "\n")
}

format_homework_for_prompt <- function(homework) {
  if (is.null(homework) || (homework$total %||% 0) == 0) return("Bu ay ev tapşırığı datası yoxdur")
  completion <- if (homework$total > 0) {
    round(100 * (homework$submitted %||% 0) / homework$total, 0)
  } else 0
  sprintf("Ümumi: %d, Təqdim edilən: %d, Tamamlanma: %d%%, Orta bal: %s",
          homework$total %||% 0, homework$submitted %||% 0, completion,
          homework$avg_score %||% "N/A")
}

# --- AI Məktub Generasiyası ---
generate_parent_letter <- function(db_pool, student_id, month, year,
                                    academic_year = NULL, user_id = NULL) {
  academic_year <- academic_year %||% get_academic_year()

  # Məlumat topla
  data <- collect_student_monthly_data(db_pool, student_id, month, year, academic_year)
  if (is.null(data) || is.null(data$student)) {
    return(list(success = FALSE, error = "Şagird tapılmadı"))
  }

  att <- data$attendance
  att_rate <- if ((att$total_days %||% 0) > 0) {
    round(100 * (att$present %||% 0) / att$total_days, 1)
  } else 0

  grade_label <- get_grade_label(data$current_avg)

  # Əlavə kontekst
  extra_context <- sprintf(
    "Valideyn: %s (%s)\nMüəllim: %s\nƏvvəlki ay ortası: %s\nSinif: %s-%s",
    if (!is.null(data$parent)) paste(data$parent$first_name, data$parent$last_name) else "Bilinmir",
    if (!is.null(data$parent)) data$parent$parent_type %||% "" else "",
    data$teacher$teacher_name %||% "Sinif rəhbəri",
    data$prev_month_avg,
    data$student$grade %||% "", data$student$section %||% ""
  )

  # Prompt yarat
  template <- load_prompt_template("parent_letter")
  prompt <- sprintf(template,
    data$student$full_name,
    paste0(data$student$grade, "-", data$student$section),
    data$student$school_name %||% "Məktəb",
    MONTH_NAMES_AZ[month],
    academic_year,
    format_grades_for_prompt(data$grades),
    att$total_days %||% 0,
    att$present %||% 0,
    att$absent %||% 0,
    att_rate,
    format_homework_for_prompt(data$homework),
    data$current_avg,
    grade_label,
    data$trend,
    extra_context
  )

  system_prompt <- paste(
    "Sən Azərbaycan məktəb müəllimisən. Valideynlərə aylıq hesabat məktubu yazırsan.",
    "Məktub hörmətcil, isti və professional üslubda olmalıdır.",
    "Azərbaycan dilinin qrammatik qaydalarına ciddi əməl et.",
    "Cavabı yalnız JSON formatında qaytar."
  )

  response <- call_claude_api(
    prompt = prompt,
    system_prompt = system_prompt,
    max_tokens = 4096,
    temperature = 0.6
  )

  if (!isTRUE(response$success)) {
    return(list(success = FALSE, error = response$message %||% "API xətası"))
  }

  parsed <- extract_json_from_response(response$message)
  if (is.null(parsed)) {
    return(list(success = FALSE, error = "JSON parse xətası"))
  }

  # HTML versiya yarat
  letter_html <- build_letter_html(parsed, data)

  # DB-yə yaz
  letter_id <- save_parent_letter(
    db_pool = db_pool,
    student_id = student_id,
    academic_year = academic_year,
    report_month = month,
    letter_json = parsed,
    letter_text = parsed$full_letter_text %||% "",
    letter_html = letter_html,
    recipient_name = if (!is.null(data$parent)) paste(data$parent$first_name, data$parent$last_name) else NULL,
    recipient_email = if (!is.null(data$parent)) data$parent$email else NULL,
    recipient_phone = if (!is.null(data$parent)) data$parent$phone else NULL,
    model = response$model,
    tokens = response$usage$total_tokens %||% 0,
    user_id = user_id
  )

  list(
    success = TRUE,
    letter_id = letter_id,
    data = parsed,
    html = letter_html,
    student = data$student,
    parent = data$parent,
    model = response$model,
    usage = response$usage
  )
}

# --- HTML məktub yarat ---
build_letter_html <- function(parsed, data) {
  student_name <- data$student$full_name %||% "Şagird"
  school_name <- data$student$school_name %||% "Məktəb"
  month_name <- MONTH_NAMES_AZ[data$month] %||% ""

  # Fənn cədvəli
  subjects_html <- ""
  if (!is.null(parsed$academic_section$subjects)) {
    rows <- sapply(parsed$academic_section$subjects, function(s) {
      color <- get_grade_color(s$score %||% 0)
      sprintf("<tr><td>%s</td><td style='text-align:center; color:%s; font-weight:bold;'>%s</td><td>%s</td><td>%s</td></tr>",
              s$name %||% "", color, s$score %||% "", s$grade %||% "", s$comment %||% "")
    })
    subjects_html <- paste(rows, collapse = "\n")
  }

  # Güclü tərəflər
  strengths_html <- paste(sapply(parsed$strengths %||% list(), function(s) {
    sprintf("<li style='color:#27ae60;'>%s</li>", s)
  }), collapse = "\n")

  # Zəif tərəflər
  weaknesses_html <- paste(sapply(parsed$weaknesses %||% list(), function(w) {
    if (is.list(w)) sprintf("<li><strong>%s:</strong> %s</li>", w$area %||% "", w$suggestion %||% "")
    else sprintf("<li>%s</li>", w)
  }), collapse = "\n")

  # Tövsiyələr
  recs_html <- paste(sapply(parsed$recommendations %||% list(), function(r) {
    sprintf("<li>%s</li>", r)
  }), collapse = "\n")

  sprintf('<!DOCTYPE html>
<html lang="az">
<head>
<meta charset="UTF-8">
<title>Valideyn Məktubu — %s</title>
<style>
  body { font-family: "Segoe UI", Arial, sans-serif; max-width: 700px; margin: 0 auto; padding: 20px; color: #333; line-height: 1.6; }
  .header { text-align: center; border-bottom: 3px solid #2c3e50; padding-bottom: 15px; margin-bottom: 20px; }
  .header h1 { color: #2c3e50; margin: 5px 0; font-size: 18px; }
  .header p { color: #666; margin: 3px 0; }
  .section { margin: 15px 0; }
  .section h3 { color: #2c3e50; border-bottom: 1px solid #eee; padding-bottom: 5px; }
  table { width: 100%%; border-collapse: collapse; margin: 10px 0; }
  th, td { padding: 8px 12px; border: 1px solid #ddd; text-align: left; }
  th { background: #2c3e50; color: white; }
  .strengths li { color: #27ae60; margin: 5px 0; }
  .weaknesses li { color: #e67e22; margin: 5px 0; }
  .recommendations { background: #f0f7ff; padding: 15px; border-radius: 8px; border-left: 4px solid #3498db; }
  .footer { margin-top: 30px; padding-top: 15px; border-top: 2px solid #2c3e50; }
  .signature { font-style: italic; color: #555; white-space: pre-line; }
</style>
</head>
<body>
<div class="header">
  <h1>%s</h1>
  <p>%s — %s %s</p>
  <p>Şagird: <strong>%s</strong> | Sinif: %s-%s</p>
</div>

<div class="section">
  <p>%s</p>
  <p>%s</p>
</div>

<div class="section">
  <h3>Akademik Nəticələr</h3>
  <p>%s</p>
  <table>
    <thead><tr><th>Fənn</th><th>Bal</th><th>Qiymət</th><th>Şərh</th></tr></thead>
    <tbody>%s</tbody>
  </table>
</div>

<div class="section">
  <h3>Davamiyyət</h3>
  <p>%s</p>
</div>

<div class="section">
  <h3>Ev Tapşırığı</h3>
  <p>%s</p>
</div>

<div class="section">
  <h3>Güclü Tərəflər</h3>
  <ul class="strengths">%s</ul>
</div>

<div class="section">
  <h3>İnkişaf Sahələri</h3>
  <ul class="weaknesses">%s</ul>
</div>

<div class="section recommendations">
  <h3 style="color:#2c3e50; border:none;">Valideyn üçün Tövsiyələr</h3>
  <ol>%s</ol>
</div>

<div class="section">
  <p>%s</p>
</div>

<div class="footer">
  <p class="signature">%s</p>
</div>
</body>
</html>',
    student_name,
    school_name, month_name, data$year, data$academic_year,
    student_name, data$student$grade %||% "", data$student$section %||% "",
    parsed$greeting %||% "Hörmətli valideyn,",
    parsed$opening_paragraph %||% "",
    parsed$academic_section$summary %||% "",
    subjects_html,
    parsed$attendance_section$summary %||% "",
    parsed$homework_section$summary %||% "",
    strengths_html,
    weaknesses_html,
    recs_html,
    parsed$closing_paragraph %||% "",
    parsed$signature %||% "Hörmətlə"
  )
}

# --- DB yardımçı funksiyalar ---
save_parent_letter <- function(db_pool, student_id, academic_year, report_month,
                                letter_json, letter_text, letter_html,
                                recipient_name, recipient_email, recipient_phone,
                                model, tokens, user_id) {
  tryCatch({
    result <- db_get_one(db_pool, "
      INSERT INTO parent_letters (student_id, academic_year, report_month,
                                   letter_json, letter_text, letter_html,
                                   recipient_name, recipient_email, recipient_phone,
                                   ai_model, tokens_used, created_by, status)
      VALUES ($1, $2, $3, $4::jsonb, $5, $6, $7, $8, $9, $10, $11, $12, 'draft')
      ON CONFLICT (student_id, academic_year, report_month)
      DO UPDATE SET letter_json = EXCLUDED.letter_json,
                    letter_text = EXCLUDED.letter_text,
                    letter_html = EXCLUDED.letter_html,
                    recipient_name = EXCLUDED.recipient_name,
                    recipient_email = EXCLUDED.recipient_email,
                    recipient_phone = EXCLUDED.recipient_phone,
                    ai_model = EXCLUDED.ai_model,
                    tokens_used = EXCLUDED.tokens_used,
                    status = 'draft',
                    teacher_edits = NULL,
                    approved_by = NULL,
                    approved_at = NULL
      RETURNING id
    ", params = list(
      student_id, academic_year, report_month,
      jsonlite::toJSON(letter_json, auto_unbox = TRUE),
      letter_text, letter_html,
      recipient_name, recipient_email, recipient_phone,
      model, tokens, user_id
    ))
    result$id
  }, error = function(e) {
    log_warn("Valideyn məktubu DB xətası: {e$message}")
    NULL
  })
}

# --- Müəllim redaktəsini saxla ---
save_teacher_edit <- function(db_pool, letter_id, edited_text, user_id) {
  tryCatch({
    db_execute(db_pool, "
      UPDATE parent_letters
      SET teacher_edits = $1, edited_at = CURRENT_TIMESTAMP,
          letter_text = $1, status = 'edited'
      WHERE id = $2
    ", params = list(edited_text, letter_id))
    TRUE
  }, error = function(e) {
    log_warn("Redaktə DB xətası: {e$message}")
    FALSE
  })
}

# --- Müəllim təsdiqi ---
approve_letter <- function(db_pool, letter_id, user_id) {
  tryCatch({
    db_execute(db_pool, "
      UPDATE parent_letters
      SET status = 'approved', approved_by = $1, approved_at = CURRENT_TIMESTAMP
      WHERE id = $2 AND status IN ('draft', 'edited')
    ", params = list(user_id, letter_id))
    TRUE
  }, error = function(e) FALSE)
}

# --- E-poçt ilə göndər ---
send_letter_email <- function(db_pool, letter_id) {
  letter <- db_get_one(db_pool, "
    SELECT pl.*, s.first_name || ' ' || s.last_name AS student_name
    FROM parent_letters pl
    JOIN students s ON s.id = pl.student_id
    WHERE pl.id = $1
  ", params = list(letter_id))

  if (is.null(letter) || is.null(letter$recipient_email) || letter$recipient_email == "") {
    return(list(success = FALSE, error = "E-poçt ünvanı yoxdur"))
  }

  # Göndərmə jurnalına yaz
  log_id <- tryCatch({
    r <- db_get_one(db_pool, "
      INSERT INTO parent_message_log (letter_id, channel, recipient, status)
      VALUES ($1, 'email', $2, 'pending') RETURNING id
    ", params = list(letter_id, letter$recipient_email))
    r$id
  }, error = function(e) NULL)

  # E-poçt göndərmə (SMTP konfiqurasiyası lazımdır)
  result <- tryCatch({
    # TODO: Gerçək SMTP inteqrasiyası — blat/mailR/emayili
    # Hal-hazırda simulasiya edir
    log_info("E-poçt göndərilir: {letter$recipient_email} — {letter$student_name}")

    # Uğurlu göndərmə simulasiyası
    if (!is.null(log_id)) {
      db_execute(db_pool, "
        UPDATE parent_message_log SET status = 'sent', sent_at = CURRENT_TIMESTAMP
        WHERE id = $1
      ", params = list(log_id))
    }

    db_execute(db_pool, "
      UPDATE parent_letters
      SET status = 'sent', sent_via = COALESCE(sent_via, 'email'),
          sent_at = COALESCE(sent_at, CURRENT_TIMESTAMP)
      WHERE id = $1
    ", params = list(letter_id))

    list(success = TRUE)
  }, error = function(e) {
    if (!is.null(log_id)) {
      db_execute(db_pool, "
        UPDATE parent_message_log SET status = 'failed', error_message = $1
        WHERE id = $2
      ", params = list(e$message, log_id))
    }
    list(success = FALSE, error = e$message)
  })

  result
}

# --- SMS ilə göndər ---
send_letter_sms <- function(db_pool, letter_id) {
  letter <- db_get_one(db_pool, "
    SELECT pl.*, s.first_name || ' ' || s.last_name AS student_name
    FROM parent_letters pl
    JOIN students s ON s.id = pl.student_id
    WHERE pl.id = $1
  ", params = list(letter_id))

  if (is.null(letter) || is.null(letter$recipient_phone) || letter$recipient_phone == "") {
    return(list(success = FALSE, error = "Telefon nömrəsi yoxdur"))
  }

  # SMS qısa versiya (160 simvol limiti üçün)
  parsed <- tryCatch(jsonlite::fromJSON(letter$letter_json), error = function(e) NULL)
  sms_text <- if (!is.null(parsed)) {
    sprintf("Hörmətli valideyn, %s şagirdinin %s ayı üçün hesabatı hazırdır. Orta bal: %s. Ətraflı: məktəbə müraciət edin.",
            letter$student_name, MONTH_NAMES_AZ[letter$report_month] %||% "",
            parsed$academic_section$overall_gpa %||% "")
  } else {
    sprintf("Hörmətli valideyn, %s üçün aylıq hesabat hazırdır. Ətraflı məlumat üçün məktəbə müraciət edin.",
            letter$student_name)
  }

  # SMS log
  log_id <- tryCatch({
    r <- db_get_one(db_pool, "
      INSERT INTO parent_message_log (letter_id, channel, recipient, status)
      VALUES ($1, 'sms', $2, 'pending') RETURNING id
    ", params = list(letter_id, letter$recipient_phone))
    r$id
  }, error = function(e) NULL)

  result <- tryCatch({
    # TODO: Gerçək SMS API inteqrasiyası (Twilio, local SMS gateway)
    log_info("SMS göndərilir: {letter$recipient_phone} — {sms_text}")

    if (!is.null(log_id)) {
      db_execute(db_pool, "
        UPDATE parent_message_log SET status = 'sent', sent_at = CURRENT_TIMESTAMP
        WHERE id = $1
      ", params = list(log_id))
    }

    db_execute(db_pool, "
      UPDATE parent_letters
      SET sent_via = CASE WHEN sent_via = 'email' THEN 'both' ELSE COALESCE(sent_via, 'sms') END,
          sent_at = COALESCE(sent_at, CURRENT_TIMESTAMP),
          status = 'sent'
      WHERE id = $1
    ", params = list(letter_id))

    list(success = TRUE, sms_text = sms_text)
  }, error = function(e) {
    if (!is.null(log_id)) {
      db_execute(db_pool, "
        UPDATE parent_message_log SET status = 'failed', error_message = $1
        WHERE id = $2
      ", params = list(e$message, log_id))
    }
    list(success = FALSE, error = e$message)
  })

  result
}

# --- Toplu generasiya ---
batch_generate_letters <- function(db_pool, student_ids, month, year,
                                    academic_year = NULL, user_id = NULL,
                                    progress_callback = NULL) {
  academic_year <- academic_year %||% get_academic_year()
  results <- list()

  for (i in seq_along(student_ids)) {
    if (!is.null(progress_callback)) {
      progress_callback(value = i / length(student_ids),
                        detail = sprintf("Şagird %d/%d...", i, length(student_ids)))
    }

    result <- tryCatch({
      generate_parent_letter(db_pool, student_ids[i], month, year, academic_year, user_id)
    }, error = function(e) {
      list(success = FALSE, error = e$message, student_id = student_ids[i])
    })

    results[[i]] <- list(
      student_id = student_ids[i],
      success = isTRUE(result$success),
      letter_id = result$letter_id,
      error = result$error
    )

    # Rate limiting
    Sys.sleep(0.5)
  }

  results
}

# --- Məktub tarixçəsini al ---
get_parent_letters <- function(db_pool, school_id = NULL, class_grade = NULL,
                                month = NULL, status = NULL, limit = 50) {
  where_clauses <- c("1=1")
  params <- list()
  p <- 0

  if (!is.null(school_id) && school_id != "") {
    p <- p + 1
    where_clauses <- c(where_clauses, sprintf("s.school_id = $%d", p))
    params[[p]] <- school_id
  }
  if (!is.null(class_grade) && class_grade != "") {
    p <- p + 1
    where_clauses <- c(where_clauses, sprintf("c.grade = $%d", p))
    params[[p]] <- as.integer(class_grade)
  }
  if (!is.null(month) && month != "") {
    p <- p + 1
    where_clauses <- c(where_clauses, sprintf("pl.report_month = $%d", p))
    params[[p]] <- as.integer(month)
  }
  if (!is.null(status) && status != "") {
    p <- p + 1
    where_clauses <- c(where_clauses, sprintf("pl.status = $%d", p))
    params[[p]] <- status
  }

  p <- p + 1
  query <- sprintf("
    SELECT pl.id, pl.report_month, pl.academic_year, pl.status,
           pl.sent_via, pl.sent_at, pl.created_at, pl.tokens_used,
           s.first_name || ' ' || s.last_name AS student_name,
           c.grade AS class_grade, c.section AS class_section,
           sc.name AS school_name,
           pl.recipient_name, pl.recipient_email, pl.recipient_phone
    FROM parent_letters pl
    JOIN students s ON s.id = pl.student_id
    LEFT JOIN classes c ON c.id = s.class_id
    LEFT JOIN schools sc ON sc.id = s.school_id
    WHERE %s
    ORDER BY pl.created_at DESC
    LIMIT $%d
  ", paste(where_clauses, collapse = " AND "), p)
  params[[p]] <- limit

  db_query(db_pool, query, params = params)
}

# --- Tək məktub detalı ---
get_letter_detail <- function(db_pool, letter_id) {
  db_get_one(db_pool, "
    SELECT pl.*, s.first_name || ' ' || s.last_name AS student_name,
           c.grade AS class_grade, c.section AS class_section,
           sc.name AS school_name
    FROM parent_letters pl
    JOIN students s ON s.id = pl.student_id
    LEFT JOIN classes c ON c.id = s.class_id
    LEFT JOIN schools sc ON sc.id = s.school_id
    WHERE pl.id = $1
  ", params = list(letter_id))
}

# --- Göndərmə statistikası ---
get_delivery_stats <- function(db_pool, academic_year = NULL) {
  academic_year <- academic_year %||% get_academic_year()
  db_get_one(db_pool, "
    SELECT COUNT(*) AS total,
           SUM(CASE WHEN status = 'draft' THEN 1 ELSE 0 END) AS draft_count,
           SUM(CASE WHEN status = 'approved' THEN 1 ELSE 0 END) AS approved_count,
           SUM(CASE WHEN status = 'sent' THEN 1 ELSE 0 END) AS sent_count,
           SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) AS failed_count
    FROM parent_letters
    WHERE academic_year = $1
  ", params = list(academic_year))
}
