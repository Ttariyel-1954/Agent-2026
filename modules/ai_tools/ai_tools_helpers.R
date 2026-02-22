# =============================================
# ARTI-2026: AI Alətləri — Köməkçi Funksiyalar
# Sual generatoru və Dərs planı generatoru üçün
# =============================================

# === Sual Tipi Seçimləri ===
QUESTION_TYPES <- c(
  "Çoxseçimli (4 variant)" = "multiple_choice_4",
  "Çoxseçimli (5 variant)" = "multiple_choice_5",
  "Doğru/Yanlış"           = "true_false",
  "Qısa Cavab"             = "short_answer",
  "Uyğunlaşdırma"          = "matching",
  "Sıralama"               = "ordering",
  "Boşluq Doldurma"        = "fill_blank"
)

# === DOK Səviyyələri ===
DOK_LEVELS <- c(
  "1 — Xatırlama"     = "1",
  "2 — Bacarıq/Anlam" = "2",
  "3 — Strateji Düşüncə" = "3",
  "4 — Genişləndirilmiş Düşüncə" = "4"
)

# === Dərs Planı Müddətləri ===
LESSON_DURATIONS <- c(
  "45 dəqiqə (1 dərs)"  = "45",
  "90 dəqiqə (2 dərs)"  = "90",
  "135 dəqiqə (3 dərs)" = "135"
)

# === Tədris Metodları ===
TEACHING_METHODS <- c(
  "İnteraktiv"           = "interactive",
  "Layihə əsaslı"        = "project_based",
  "Problem əsaslı"       = "problem_based",
  "Kooperativ öyrənmə"   = "cooperative",
  "Fərqləndirmə"         = "differentiated",
  "Flip sinif"           = "flipped",
  "Birbaşa təlim"        = "direct_instruction",
  "Kəşfiyyat əsaslı"    = "inquiry_based"
)

# === Dərs Planı Bölmələri ===
LESSON_SECTIONS <- c(
  "Giriş/Motivasiya",
  "Əsas Hissə",
  "Tətbiq/Təcrübə",
  "Qiymətləndirmə",
  "Yekunlaşdırma",
  "Ev Tapşırığı"
)

# === Çətinlik Badge-ləri ===
difficulty_badge <- function(level) {
  colors <- list(
    "Asan"   = "success",
    "Orta"   = "warning",
    "Çətin"  = "danger",
    "easy"   = "success",
    "medium" = "warning",
    "hard"   = "danger"
  )
  color <- colors[[level]] %||% "default"
  tags$span(class = paste0("label label-", color), level)
}

# === Bloom Badge-ləri ===
bloom_badge <- function(level) {
  colors <- list(
    "Bilmə"          = "#3498db",
    "Anlama"          = "#2ecc71",
    "Tətbiq"          = "#f39c12",
    "Təhlil"          = "#e67e22",
    "Sintez"          = "#9b59b6",
    "Qiymətləndirmə"  = "#e74c3c"
  )
  color <- colors[[level]] %||% "#95a5a6"
  tags$span(
    style = paste0("background:", color, "; color:white; padding:2px 8px; border-radius:4px; font-size:0.85em;"),
    level
  )
}

# === DOK Badge ===
dok_badge <- function(level) {
  colors <- c("1" = "#3498db", "2" = "#2ecc71", "3" = "#f39c12", "4" = "#e74c3c")
  labels <- c("1" = "DOK-1 Xatırlama", "2" = "DOK-2 Bacarıq", "3" = "DOK-3 Strateji", "4" = "DOK-4 Genişləndirilmiş")
  color <- colors[as.character(level)] %||% "#95a5a6"
  label <- labels[as.character(level)] %||% paste("DOK", level)
  tags$span(
    style = paste0("background:", color, "; color:white; padding:2px 8px; border-radius:4px; font-size:0.85em;"),
    label
  )
}

# === Sual JSON-u data.frame-ə çevir ===
questions_to_dataframe <- function(questions_json) {
  if (is.data.frame(questions_json)) return(questions_json)

  tryCatch({
    if (is.list(questions_json) && !is.data.frame(questions_json)) {
      rows <- lapply(questions_json, function(q) {
        data.frame(
          question_text   = q$question_text %||% q$text %||% "",
          option_a        = q$option_a %||% q$options$A %||% tryCatch(q$options[[1]], error = function(e) "") %||% "",
          option_b        = q$option_b %||% q$options$B %||% tryCatch(q$options[[2]], error = function(e) "") %||% "",
          option_c        = q$option_c %||% q$options$C %||% tryCatch(q$options[[3]], error = function(e) "") %||% "",
          option_d        = q$option_d %||% q$options$D %||% tryCatch(q$options[[4]], error = function(e) "") %||% "",
          option_e        = q$option_e %||% q$options$E %||% tryCatch(q$options[[5]], error = function(e) "") %||% "",
          correct_answer  = toupper(trimws(q$correct_answer %||% q$answer %||% "A")),
          explanation     = q$explanation %||% q$izah %||% "",
          bloom_level     = q$bloom_level %||% q$bloom %||% "",
          difficulty      = q$difficulty %||% q$difficulty_label %||% "",
          dok_level       = q$dok_level %||% q$dok %||% "",
          standard_code   = q$standard_code %||% "",
          estimated_time  = q$estimated_time %||% 0,
          stringsAsFactors = FALSE
        )
      })
      do.call(rbind, rows)
    } else {
      NULL
    }
  }, error = function(e) {
    log_error("questions_to_dataframe xətası: {e$message}")
    NULL
  })
}

# === Dərs Planını HTML-ə çevir ===
lesson_plan_to_html <- function(plan) {
  if (is.null(plan)) return(tags$p(class = "text-muted", "Nəticə yoxdur"))

  sections <- list()

  if (!is.null(plan$title)) {
    sections <- c(sections, list(tags$h3(plan$title)))
  }

  info_items <- list()
  if (!is.null(plan$subject))  info_items <- c(info_items, list(tags$li(tags$strong("Fənn: "), plan$subject)))
  if (!is.null(plan$grade))    info_items <- c(info_items, list(tags$li(tags$strong("Sinif: "), plan$grade)))
  if (!is.null(plan$topic))    info_items <- c(info_items, list(tags$li(tags$strong("Mövzu: "), plan$topic)))
  if (!is.null(plan$duration)) info_items <- c(info_items, list(tags$li(tags$strong("Müddət: "), plan$duration, " dəq.")))
  if (!is.null(plan$method))   info_items <- c(info_items, list(tags$li(tags$strong("Metod: "), plan$method)))

  if (length(info_items) > 0) {
    sections <- c(sections, list(
      tags$div(
        style = "background:#f0f4f8; padding:12px; border-radius:8px; margin-bottom:15px;",
        tags$ul(style = "list-style:none; margin:0; padding:0;", info_items)
      )
    ))
  }

  if (!is.null(plan$learning_outcomes) && length(plan$learning_outcomes) > 0) {
    outcomes <- lapply(plan$learning_outcomes, function(o) tags$li(o))
    sections <- c(sections, list(
      tags$h4(icon("bullseye"), " Öyrənmə Nəticələri"),
      tags$ul(outcomes)
    ))
  }

  if (!is.null(plan$stages) && length(plan$stages) > 0) {
    stage_html <- lapply(seq_along(plan$stages), function(i) {
      s <- plan$stages[[i]]
      tags$div(
        style = "border-left:4px solid #3498db; padding:10px 15px; margin-bottom:12px; background:#fafafa;",
        tags$h5(style = "color:#2c3e50; margin-top:0;",
                paste0(i, ". ", s$name %||% s$stage_name %||% paste("Mərhələ", i)),
                if (!is.null(s$duration)) tags$small(style = "color:#888;", paste0(" (", s$duration, " dəq.)"))),
        if (!is.null(s$teacher_activity)) tags$p(tags$strong("Müəllim: "), s$teacher_activity),
        if (!is.null(s$student_activity)) tags$p(tags$strong("Şagird: "), s$student_activity),
        if (!is.null(s$resources)) tags$p(tags$strong("Resurslar: "),
          if (is.list(s$resources)) paste(unlist(s$resources), collapse = ", ") else s$resources),
        if (!is.null(s$assessment)) tags$p(tags$strong("Qiymətləndirmə: "), s$assessment),
        if (!is.null(s$description)) tags$p(s$description)
      )
    })
    sections <- c(sections, list(tags$h4(icon("list-ol"), " Dərs Mərhələləri")))
    sections <- c(sections, stage_html)
  }

  if (!is.null(plan$differentiation)) {
    diff <- plan$differentiation
    diff_html <- list()
    if (!is.null(diff$advanced)) diff_html <- c(diff_html, list(tags$li(tags$strong("Güclü şagirdlər: "), diff$advanced)))
    if (!is.null(diff$struggling)) diff_html <- c(diff_html, list(tags$li(tags$strong("Çətinlik çəkən: "), diff$struggling)))
    if (!is.null(diff$ell)) diff_html <- c(diff_html, list(tags$li(tags$strong("Dil dəstəyi: "), diff$ell)))

    if (length(diff_html) > 0) {
      sections <- c(sections, list(
        tags$h4(icon("users"), " Fərqləndirmə"),
        tags$ul(diff_html)
      ))
    }
  }

  if (!is.null(plan$homework)) {
    sections <- c(sections, list(
      tags$h4(icon("home"), " Ev Tapşırığı"),
      tags$p(if (is.list(plan$homework)) paste(unlist(plan$homework), collapse = "; ") else plan$homework)
    ))
  }

  if (!is.null(plan$materials) && length(plan$materials) > 0) {
    mat_items <- lapply(plan$materials, function(m) tags$li(m))
    sections <- c(sections, list(
      tags$h4(icon("toolbox"), " Lazım Olan Materiallar"),
      tags$ul(mat_items)
    ))
  }

  if (!is.null(plan$notes)) {
    sections <- c(sections, list(
      tags$h4(icon("sticky-note"), " Qeydlər"),
      tags$p(style = "color:#666;", plan$notes)
    ))
  }

  tags$div(class = "lesson-plan-output", style = "padding:10px;", sections)
}

# === Sualları HTML kartlarına çevir ===
questions_to_html_cards <- function(df) {
  if (is.null(df) || nrow(df) == 0) return(tags$p(class = "text-muted", "Sual yoxdur"))

  cards <- lapply(seq_len(nrow(df)), function(i) {
    q <- df[i, ]
    correct <- toupper(trimws(q$correct_answer))

    option_style <- function(letter) {
      if (toupper(letter) == correct) "color:#27ae60; font-weight:bold;" else ""
    }

    options_html <- list(
      tags$div(style = option_style("A"), paste0("A) ", q$option_a))
    )
    if (!is.null(q$option_b) && nchar(q$option_b) > 0)
      options_html <- c(options_html, list(tags$div(style = option_style("B"), paste0("B) ", q$option_b))))
    if (!is.null(q$option_c) && nchar(q$option_c) > 0)
      options_html <- c(options_html, list(tags$div(style = option_style("C"), paste0("C) ", q$option_c))))
    if (!is.null(q$option_d) && nchar(q$option_d) > 0)
      options_html <- c(options_html, list(tags$div(style = option_style("D"), paste0("D) ", q$option_d))))
    if (!is.null(q$option_e) && nchar(q$option_e) > 0 && q$option_e != "")
      options_html <- c(options_html, list(tags$div(style = option_style("E"), paste0("E) ", q$option_e))))

    tags$div(
      style = "border:1px solid #ddd; border-radius:8px; padding:14px; margin-bottom:12px; background:#fff;",
      tags$div(
        style = "display:flex; justify-content:space-between; align-items:center; margin-bottom:8px;",
        tags$strong(paste0("Sual ", i)),
        tags$div(
          if (!is.null(q$bloom_level) && nchar(q$bloom_level) > 0) bloom_badge(q$bloom_level),
          if (!is.null(q$difficulty) && nchar(q$difficulty) > 0) difficulty_badge(q$difficulty),
          if (!is.null(q$dok_level) && nchar(q$dok_level) > 0 && q$dok_level != "") dok_badge(q$dok_level)
        )
      ),
      tags$p(style = "font-size:1.05em;", q$question_text),
      tags$div(style = "margin-left:20px; margin-top:6px;", options_html),
      if (!is.null(q$explanation) && nchar(q$explanation) > 0)
        tags$div(style = "margin-top:8px; padding:8px; background:#f0f9f0; border-radius:4px; font-size:0.9em;",
                 tags$em(icon("lightbulb"), " ", q$explanation)),
      if (!is.null(q$standard_code) && nchar(q$standard_code) > 0)
        tags$div(style = "margin-top:4px; font-size:0.85em; color:#888;",
                 paste0("Standart: ", q$standard_code))
    )
  })

  tags$div(cards)
}

# === Sualları Word/TXT formatına çevir ===
questions_to_text <- function(df, include_answers = TRUE) {
  if (is.null(df) || nrow(df) == 0) return("")

  lines <- c()
  for (i in seq_len(nrow(df))) {
    q <- df[i, ]
    lines <- c(lines,
      paste0(i, ". ", q$question_text),
      paste0("   A) ", q$option_a),
      paste0("   B) ", q$option_b)
    )
    if (!is.null(q$option_c) && nchar(q$option_c) > 0)
      lines <- c(lines, paste0("   C) ", q$option_c))
    if (!is.null(q$option_d) && nchar(q$option_d) > 0)
      lines <- c(lines, paste0("   D) ", q$option_d))
    if (!is.null(q$option_e) && nchar(q$option_e) > 0 && q$option_e != "")
      lines <- c(lines, paste0("   E) ", q$option_e))

    if (include_answers) {
      lines <- c(lines, paste0("   Düzgün cavab: ", q$correct_answer))
      if (!is.null(q$explanation) && nchar(q$explanation) > 0)
        lines <- c(lines, paste0("   İzah: ", q$explanation))
      if (!is.null(q$bloom_level) && nchar(q$bloom_level) > 0)
        lines <- c(lines, paste0("   Bloom: ", q$bloom_level))
    }
    lines <- c(lines, "")
  }
  paste(lines, collapse = "\n")
}

# === Dərs Planını TXT formatına çevir ===
lesson_plan_to_text <- function(plan) {
  if (is.null(plan)) return("")

  lines <- c()

  if (!is.null(plan$title)) lines <- c(lines, plan$title, paste(rep("=", nchar(plan$title)), collapse = ""), "")

  if (!is.null(plan$subject))  lines <- c(lines, paste0("Fənn: ", plan$subject))
  if (!is.null(plan$grade))    lines <- c(lines, paste0("Sinif: ", plan$grade))
  if (!is.null(plan$topic))    lines <- c(lines, paste0("Mövzu: ", plan$topic))
  if (!is.null(plan$duration)) lines <- c(lines, paste0("Müddət: ", plan$duration, " dəqiqə"))
  if (!is.null(plan$method))   lines <- c(lines, paste0("Metod: ", plan$method))
  lines <- c(lines, "")

  if (!is.null(plan$learning_outcomes) && length(plan$learning_outcomes) > 0) {
    lines <- c(lines, "ÖYRƏNMƏ NƏTİCƏLƏRİ:", "---")
    for (i in seq_along(plan$learning_outcomes)) {
      lines <- c(lines, paste0("  ", i, ". ", plan$learning_outcomes[[i]]))
    }
    lines <- c(lines, "")
  }

  if (!is.null(plan$stages) && length(plan$stages) > 0) {
    lines <- c(lines, "DƏRS MƏRHƏLƏLƏRİ:", "---")
    for (i in seq_along(plan$stages)) {
      s <- plan$stages[[i]]
      name <- s$name %||% s$stage_name %||% paste("Mərhələ", i)
      dur <- if (!is.null(s$duration)) paste0(" (", s$duration, " dəq.)") else ""
      lines <- c(lines, paste0("  ", i, ". ", name, dur))
      if (!is.null(s$teacher_activity)) lines <- c(lines, paste0("     Müəllim: ", s$teacher_activity))
      if (!is.null(s$student_activity)) lines <- c(lines, paste0("     Şagird: ", s$student_activity))
      if (!is.null(s$resources)) lines <- c(lines, paste0("     Resurslar: ",
        if (is.list(s$resources)) paste(unlist(s$resources), collapse = ", ") else s$resources))
      if (!is.null(s$assessment)) lines <- c(lines, paste0("     Qiymətləndirmə: ", s$assessment))
      if (!is.null(s$description)) lines <- c(lines, paste0("     ", s$description))
      lines <- c(lines, "")
    }
  }

  if (!is.null(plan$differentiation)) {
    d <- plan$differentiation
    lines <- c(lines, "FƏRQLƏNDİRMƏ:", "---")
    if (!is.null(d$advanced)) lines <- c(lines, paste0("  Güclü şagirdlər: ", d$advanced))
    if (!is.null(d$struggling)) lines <- c(lines, paste0("  Çətinlik çəkən: ", d$struggling))
    if (!is.null(d$ell)) lines <- c(lines, paste0("  Dil dəstəyi: ", d$ell))
    lines <- c(lines, "")
  }

  if (!is.null(plan$homework)) {
    lines <- c(lines, "EV TAPŞIRIĞI:", "---")
    lines <- c(lines, paste0("  ", if (is.list(plan$homework)) paste(unlist(plan$homework), collapse = "; ") else plan$homework))
    lines <- c(lines, "")
  }

  if (!is.null(plan$materials) && length(plan$materials) > 0) {
    lines <- c(lines, "LAZIM OLAN MATERİALLAR:", "---")
    for (m in plan$materials) {
      lines <- c(lines, paste0("  - ", m))
    }
    lines <- c(lines, "")
  }

  paste(lines, collapse = "\n")
}

# === AI Generator statistikalarını al ===
get_ai_generation_stats <- function(db_pool, task_type = NULL, days = 30) {
  where_clause <- "WHERE created_at >= NOW() - INTERVAL '30 days'"
  params <- list()
  idx <- 1

  if (!is.null(task_type)) {
    where_clause <- paste0(where_clause, " AND task_type = $", idx)
    params[[idx]] <- task_type
  }

  query <- paste0(
    "SELECT
       COUNT(*) as total_requests,
       SUM(CASE WHEN status = 'success' THEN 1 ELSE 0 END) as success_count,
       SUM(input_tokens + output_tokens) as total_tokens,
       SUM(estimated_cost) as total_cost,
       AVG(response_time_ms) as avg_response_ms
     FROM ai_responses ", where_clause
  )

  tryCatch(
    db_get_one(db_pool, query, params = if (length(params) > 0) params else NULL),
    error = function(e) {
      list(total_requests = 0, success_count = 0, total_tokens = 0, total_cost = 0, avg_response_ms = 0)
    }
  )
}
