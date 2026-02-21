# =============================================
# ARTI-2026: Genislendirilmis Hesabat Generatoru
# Gun 20: Word/PDF export + toplu hesabat + sablonlar
# =============================================

report_generator_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(column(12, h2(icon("file-export"), "Hesabat Generatoru"),
      tags$p(class = "text-muted", "Professional Word/PDF hesabatlar, toplu generasiya, xususi sablonlar"), hr())),

    # Statistika
    fluidRow(
      valueBoxOutput(ns("rg_stat_total"), width = 3),
      valueBoxOutput(ns("rg_stat_word"), width = 3),
      valueBoxOutput(ns("rg_stat_pdf"), width = 3),
      valueBoxOutput(ns("rg_stat_batch"), width = 3)
    ),

    fluidRow(
      # Sol panel -- Konfiqurasiya
      column(4,
        box(title = tagList(icon("cog"), " Hesabat Konfiqurasiyasi"), status = "primary", solidHeader = TRUE, width = 12,
          selectInput(ns("rg_type"), "Hesabat Novu:", choices = c(
            "Ferdi Sagird Hesabati" = "student_individual",
            "Sinif Hesabati" = "class_report",
            "Mekteb Hesabati" = "school_report",
            "Fenn Hesabati" = "subject_report",
            "Muellim Hesabati" = "teacher_report",
            "Risk Hesabati" = "risk_report"
          )),

          # Kontekst filtrler - conditional
          conditionalPanel(
            condition = sprintf("input['%s'] == 'student_individual'", ns("rg_type")),
            selectizeInput(ns("rg_student"), "Sagird:", choices = NULL, options = list(placeholder = "Axtar..."))
          ),
          conditionalPanel(
            condition = sprintf("input['%s'] == 'class_report'", ns("rg_type")),
            fluidRow(
              column(6, selectInput(ns("rg_class_grade"), "Sinif:", choices = c("Secin" = "", 1:11))),
              column(6, selectInput(ns("rg_class_section"), "Bolme:", choices = c("Secin" = "", LETTERS[1:6])))
            )
          ),
          conditionalPanel(
            condition = sprintf("input['%s'] == 'school_report' || input['%s'] == 'subject_report' || input['%s'] == 'risk_report'",
              ns("rg_type"), ns("rg_type"), ns("rg_type")),
            selectInput(ns("rg_school"), "Mekteb:", choices = c("Butun mektebler" = ""))
          ),
          conditionalPanel(
            condition = sprintf("input['%s'] == 'subject_report'", ns("rg_type")),
            selectInput(ns("rg_subject"), "Fenn:", choices = c("Butun fennler" = ""))
          ),
          conditionalPanel(
            condition = sprintf("input['%s'] == 'teacher_report'", ns("rg_type")),
            selectizeInput(ns("rg_teacher"), "Muellim:", choices = NULL, options = list(placeholder = "Axtar..."))
          ),

          selectInput(ns("rg_period"), "Dovr:", choices = c(
            "Cari ay" = "month",
            "Cari rub" = "quarter",
            "Yarimil" = "semester",
            "Illik" = "year"
          )),
          selectInput(ns("rg_year"), "Tedris ili:", choices = c("2025-2026", "2024-2025"), selected = "2025-2026"),

          tags$hr(),
          tags$h5("Daxil edilecek bolmeler"),
          checkboxInput(ns("rg_inc_summary"), "AI Xulase", value = TRUE),
          checkboxInput(ns("rg_inc_kpi"), "KPI Gostericileri", value = TRUE),
          checkboxInput(ns("rg_inc_charts"), "Qrafikler", value = TRUE),
          checkboxInput(ns("rg_inc_table"), "Detalli cedvel", value = TRUE),
          checkboxInput(ns("rg_inc_recommendations"), "AI Tovsiyeler", value = TRUE),
          checkboxInput(ns("rg_inc_attendance"), "Davamiyyet", value = TRUE),
          checkboxInput(ns("rg_inc_comparison"), "Muqayise", value = FALSE),

          tags$hr(),
          selectInput(ns("rg_format"), "Format:", choices = c(
            "Word (.docx)" = "docx",
            "PDF" = "pdf",
            "HTML" = "html",
            "Excel" = "xlsx"
          )),

          tags$div(style = "margin-top:10px;",
            actionButton(ns("btn_rg_preview"), "Onizleme", icon = icon("eye"), class = "btn-info btn-lg btn-block"),
            tags$br(),
            downloadButton(ns("btn_rg_download"), "Hesabati Yukle", class = "btn-success btn-lg btn-block"),
            tags$br(),
            actionButton(ns("btn_rg_batch"), "Toplu Generasiya", icon = icon("layer-group"), class = "btn-warning btn-block")
          )
        )
      ),

      # Sag panel -- Onizleme
      column(8,
        box(title = tagList(icon("eye"), " Hesabat Onizleme"), status = "success", solidHeader = TRUE, width = 12,
          uiOutput(ns("rg_preview_content"))
        ),

        # Toplu generasiya paneli
        box(title = tagList(icon("layer-group"), " Toplu Generasiya"), status = "warning", solidHeader = TRUE, width = 12,
          collapsible = TRUE, collapsed = TRUE,
          tags$p(class = "text-muted", "Birden cox sagird/mekteb ucun hesabat yaradin"),
          fluidRow(
            column(4, selectInput(ns("rg_batch_type"), "Toplu Nov:", choices = c(
              "Sinif uzre sagirdler" = "class_students",
              "Mekteb uzre sinifler" = "school_classes",
              "Butun mektebler" = "all_schools"
            ))),
            column(4, selectInput(ns("rg_batch_format"), "Format:", choices = c("Word" = "docx", "PDF" = "pdf"))),
            column(4, actionButton(ns("btn_rg_batch_start"), "Toplu Baslat", icon = icon("rocket"),
              class = "btn-danger", style = "margin-top:25px;"))
          ),
          uiOutput(ns("rg_batch_progress")),
          DTOutput(ns("rg_batch_results"))
        ),

        # Tarixce
        box(title = tagList(icon("history"), " Hesabat Tarixcesi"), status = "primary", solidHeader = TRUE, width = 12,
          collapsible = TRUE, collapsed = TRUE,
          DTOutput(ns("rg_history_table"))
        )
      )
    )
  )
}

report_generator_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    report_data <- reactiveVal(NULL)
    report_count <- reactiveVal(0)
    batch_results <- reactiveVal(data.frame())

    # Load dropdowns
    observe({
      # Students
      students <- tryCatch(db_query(db_pool,
        "SELECT s.id, s.first_name || ' ' || s.last_name || ' (' || c.grade || '-' || c.section || ')' as label
         FROM students s LEFT JOIN classes c ON s.class_id = c.id
         WHERE s.status = 'active' ORDER BY s.last_name LIMIT 500"),
        error = function(e) data.frame())
      if (nrow(students) > 0) {
        updateSelectizeInput(session, "rg_student",
          choices = setNames(students$id, students$label), server = TRUE)
      }

      # Teachers
      teachers <- tryCatch(db_query(db_pool,
        "SELECT t.id, t.first_name || ' ' || t.last_name as label
         FROM teachers t WHERE t.status = 'active' ORDER BY t.last_name"),
        error = function(e) data.frame())
      if (nrow(teachers) > 0) {
        updateSelectizeInput(session, "rg_teacher",
          choices = setNames(teachers$id, teachers$label), server = TRUE)
      }

      # Schools
      schools <- tryCatch(db_query(db_pool,
        "SELECT id, name FROM schools WHERE status = 'active' ORDER BY name"),
        error = function(e) data.frame())
      if (nrow(schools) > 0) {
        updateSelectInput(session, "rg_school",
          choices = c("Butun mektebler" = "", setNames(schools$id, schools$name)))
      }

      # Subjects
      subjects <- tryCatch(db_query(db_pool,
        "SELECT DISTINCT name FROM subjects ORDER BY name"),
        error = function(e) data.frame())
      if (nrow(subjects) > 0) {
        updateSelectInput(session, "rg_subject",
          choices = c("Butun fennler" = "", setNames(subjects$name, subjects$name)))
      }
    })

    # ---- STATISTICS ----
    output$rg_stat_total <- renderValueBox({
      valueBox(report_count(), "Yaradilmis Hesabat", icon = icon("file"), color = "blue")
    })
    output$rg_stat_word <- renderValueBox({
      valueBox("Word", "En cox istifade", icon = icon("file-word"), color = "aqua")
    })
    output$rg_stat_pdf <- renderValueBox({
      valueBox("PDF", "Professional", icon = icon("file-pdf"), color = "red")
    })
    output$rg_stat_batch <- renderValueBox({
      n <- nrow(batch_results())
      valueBox(n, "Toplu Hesabat", icon = icon("layer-group"), color = "yellow")
    })

    # ---- COLLECT DATA for report ----
    collect_rg_data <- function() {
      rtype <- input$rg_type
      ay <- input$rg_year

      # Date range based on period
      date_range <- get_period_dates(input$rg_period, ay)

      if (rtype == "student_individual") {
        if (is_empty(input$rg_student)) { notify_warning("Sagird secin."); return(NULL) }
        collect_student_report(db_pool, input$rg_student, ay, date_range)
      } else if (rtype == "class_report") {
        if (is_empty(input$rg_class_grade)) { notify_warning("Sinif secin."); return(NULL) }
        collect_class_report(db_pool, input$rg_class_grade, input$rg_class_section, ay, date_range, input$rg_school)
      } else if (rtype == "school_report") {
        collect_school_rg_report(db_pool, input$rg_school, ay, date_range)
      } else if (rtype == "subject_report") {
        collect_subject_report(db_pool, input$rg_subject, ay, date_range, input$rg_school)
      } else if (rtype == "teacher_report") {
        if (is_empty(input$rg_teacher)) { notify_warning("Muellim secin."); return(NULL) }
        collect_teacher_rg_report(db_pool, input$rg_teacher, ay, date_range)
      } else if (rtype == "risk_report") {
        collect_risk_rg_report(db_pool, ay, date_range, input$rg_school)
      } else {
        NULL
      }
    }

    # ---- PREVIEW ----
    observeEvent(input$btn_rg_preview, {
      withProgress(message = "Hesabat hazirlanir...", value = 0.2, {
        data <- collect_rg_data()
        if (is.null(data)) return()

        # AI summary if enabled
        if (isTRUE(input$rg_inc_summary)) {
          setProgress(0.5, detail = "AI xulase...")
          data$ai_summary <- tryCatch(
            generate_report_summary(data),
            error = function(e) NULL
          )
        }

        # AI recommendations if enabled
        if (isTRUE(input$rg_inc_recommendations)) {
          setProgress(0.7, detail = "AI tovsiyeler...")
          data$ai_recommendations <- tryCatch(
            generate_report_recommendations(data),
            error = function(e) NULL
          )
        }

        report_data(data)
        setProgress(1)
      })
    })

    output$rg_preview_content <- renderUI({
      data <- report_data()
      if (is.null(data)) {
        return(tags$div(
          style = "text-align:center; padding:60px; color:#999;",
          icon("file-alt", style = "font-size:48px;"),
          tags$br(), tags$br(),
          "Hesabat parametrlerini secin ve \"Onizleme\" basin"
        ))
      }

      render_report_preview(data, input)
    })

    # ---- DOWNLOAD ----
    output$btn_rg_download <- downloadHandler(
      filename = function() {
        ext <- input$rg_format
        paste0("ARTI_hesabat_", input$rg_type, "_", format(Sys.Date(), "%Y%m%d"), ".", ext)
      },
      content = function(file) {
        withProgress(message = "Hesabat yaradilir...", value = 0.3, {
          data <- report_data()
          if (is.null(data)) {
            data <- collect_rg_data()
            if (is.null(data)) { notify_warning("Data yoxdur."); return() }
            if (isTRUE(input$rg_inc_summary)) {
              data$ai_summary <- tryCatch(generate_report_summary(data), error = function(e) NULL)
            }
            if (isTRUE(input$rg_inc_recommendations)) {
              data$ai_recommendations <- tryCatch(generate_report_recommendations(data), error = function(e) NULL)
            }
          }

          setProgress(0.6, detail = "Fayl yaradilir...")

          if (input$rg_format == "docx") {
            generate_word_report(data, file, input)
          } else if (input$rg_format == "pdf") {
            generate_pdf_report(data, file, input)
          } else if (input$rg_format == "html") {
            generate_html_report(data, file, input)
          } else {
            generate_excel_rg_report(data, file)
          }

          report_count(report_count() + 1)

          # Log to history
          tryCatch(db_execute(db_pool,
            "INSERT INTO ai_responses (user_id, task_type, prompt_text, response_time_ms, created_at)
             VALUES ($1, $2, $3, $4, NOW())",
            params = list(
              user_data()$id,
              paste0("report_", input$rg_format),
              paste0(data$title, " | ", input$rg_format),
              0
            )), error = function(e) NULL)

          setProgress(1)
          notify_success("Hesabat ugurla yaradildi!")
        })
      }
    )

    # ---- BATCH ----
    observeEvent(input$btn_rg_batch_start, {
      batch_type <- input$rg_batch_type
      batch_fmt <- input$rg_batch_format
      results <- data.frame(
        Ad = character(0), Format = character(0),
        Status = character(0), Tarix = character(0),
        stringsAsFactors = FALSE
      )

      withProgress(message = "Toplu hesabat generasiyasi...", value = 0, {
        targets <- get_batch_targets(db_pool, batch_type, input)

        if (length(targets) == 0) {
          notify_warning("Toplu generasiya ucun hedef tapilmadi.")
          return()
        }

        total <- length(targets)
        output_dir <- file.path(tempdir(), paste0("batch_", format(Sys.time(), "%Y%m%d_%H%M%S")))
        dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

        for (i in seq_along(targets)) {
          setProgress(i / total, detail = paste0(i, "/", total, " - ", targets[[i]]$label))

          gen_result <- tryCatch({
            tdata <- targets[[i]]$collect_fn()
            if (!is.null(tdata)) {
              fname <- paste0("ARTI_", gsub("[^a-zA-Z0-9]", "_", targets[[i]]$label), ".", batch_fmt)
              fpath <- file.path(output_dir, fname)

              if (batch_fmt == "docx") {
                generate_word_report(tdata, fpath, input)
              } else {
                generate_pdf_report(tdata, fpath, input)
              }
              "Ugurlu"
            } else {
              "Data yoxdur"
            }
          }, error = function(e) paste0("Xeta: ", e$message))

          results <- rbind(results, data.frame(
            Ad = targets[[i]]$label,
            Format = toupper(batch_fmt),
            Status = gen_result,
            Tarix = format(Sys.time(), "%H:%M:%S"),
            stringsAsFactors = FALSE
          ))
        }
      })

      batch_results(results)
      report_count(report_count() + nrow(results[results$Status == "Ugurlu", ]))
      notify_success(paste0("Toplu hesabat generasiyasi tamamlandi! ", sum(results$Status == "Ugurlu"), "/", nrow(results), " ugurlu."))
    })

    output$rg_batch_progress <- renderUI({
      br <- batch_results()
      if (nrow(br) == 0) return(NULL)

      success_n <- sum(br$Status == "Ugurlu")
      total_n <- nrow(br)
      pct <- round(success_n / total_n * 100)

      tags$div(style = "margin:10px 0;",
        tags$div(class = "progress",
          tags$div(class = "progress-bar progress-bar-success", role = "progressbar",
            style = paste0("width:", pct, "%;"),
            paste0(success_n, "/", total_n, " ugurlu (", pct, "%)")
          )
        )
      )
    })

    output$rg_batch_results <- renderDT({
      br <- batch_results()
      if (nrow(br) == 0) return(datatable(data.frame("Toplu hesabat yoxdur" = character(0))))
      datatable(br, options = list(dom = "t", pageLength = 20), rownames = FALSE)
    })

    # ---- HISTORY ----
    output$rg_history_table <- renderDT({
      data <- tryCatch(db_query(db_pool,
        "SELECT task_type as type, LEFT(prompt_text, 60) as description,
                response_time_ms, created_at
         FROM ai_responses WHERE task_type LIKE 'report_%' AND user_id = $1
         ORDER BY created_at DESC LIMIT 30",
        params = list(user_data()$id)), error = function(e) data.frame())

      if (nrow(data) == 0) return(datatable(data.frame("Tarixce bosdur" = character(0))))
      data$created_at <- format_date_az(data$created_at)
      names(data) <- c("Nov", "Tesvir", "Vaxt (ms)", "Tarix")
      datatable(data, options = list(dom = "tp", pageLength = 10), rownames = FALSE)
    })
  })
}


# =============================================
# DATA TOPLAMA FUNKSIYALARI
# =============================================

get_period_dates <- function(period, academic_year) {
  year <- as.integer(substr(academic_year, 1, 4))
  today <- Sys.Date()

  switch(period,
    month = list(
      start = as.Date(format(today - 30, "%Y-%m-01")),
      end = today
    ),
    quarter = {
      m <- as.integer(format(today, "%m"))
      q_start <- as.Date(sprintf("%d-%02d-01", as.integer(format(today, "%Y")), ((m - 1) %/% 3) * 3 + 1))
      list(start = q_start, end = today)
    },
    semester = list(
      start = as.Date(sprintf("%d-09-01", year)),
      end = as.Date(sprintf("%d-01-31", year + 1))
    ),
    year = list(
      start = as.Date(sprintf("%d-09-01", year)),
      end = as.Date(sprintf("%d-08-31", year + 1))
    )
  )
}

collect_student_report <- function(db_pool, student_id, ay, date_range) {
  student <- tryCatch(db_get_one(db_pool,
    "SELECT s.first_name, s.last_name, s.birth_date, c.grade, c.section, sch.name as school_name
     FROM students s LEFT JOIN classes c ON s.class_id = c.id LEFT JOIN schools sch ON s.school_id = sch.id
     WHERE s.id = $1", params = list(student_id)), error = function(e) NULL)

  grades <- tryCatch(db_query(db_pool,
    "SELECT sub.name as subject, g.grade_type, g.score, g.grade_date
     FROM grades g JOIN subjects sub ON g.subject_id = sub.id
     WHERE g.student_id = $1 AND g.grade_date BETWEEN $2 AND $3
     ORDER BY g.grade_date DESC",
    params = list(student_id, date_range$start, date_range$end)),
    error = function(e) data.frame())

  subject_avg <- tryCatch(db_query(db_pool,
    "SELECT sub.name as label, ROUND(AVG(g.score)::numeric, 1) as value
     FROM grades g JOIN subjects sub ON g.subject_id = sub.id
     WHERE g.student_id = $1 AND g.grade_date BETWEEN $2 AND $3
     GROUP BY sub.name ORDER BY value DESC",
    params = list(student_id, date_range$start, date_range$end)),
    error = function(e) data.frame())

  attendance <- tryCatch(db_query(db_pool,
    "SELECT status, COUNT(*) as count FROM attendance
     WHERE student_id = $1 AND attendance_date BETWEEN $2 AND $3
     GROUP BY status",
    params = list(student_id, date_range$start, date_range$end)),
    error = function(e) data.frame())

  name <- if (!is.null(student)) paste(student$first_name, student$last_name) else "Namelum"
  avg_score <- if (nrow(subject_avg) > 0) round(mean(subject_avg$value, na.rm = TRUE), 1) else 0

  list(
    title = paste0("Ferdi Sagird Hesabati -- ", name),
    report_type = "student_individual",
    student = student,
    date_range = date_range,
    stats = data.frame(student_count = 1, avg_score = avg_score),
    performance = subject_avg,
    attendance = attendance,
    detail_table = grades,
    distribution = data.frame()
  )
}

collect_class_report <- function(db_pool, grade, section, ay, date_range, school_id) {
  school_filter <- if (!is_empty(school_id)) "AND c.school_id = $4" else ""
  params <- list(as.integer(grade), section %||% "A", date_range$start)
  if (!is_empty(school_id)) params <- c(params, list(school_id))

  students <- tryCatch(db_query(db_pool, sprintf(
    "SELECT s.id, s.first_name || ' ' || s.last_name as name,
            ROUND(AVG(g.score)::numeric, 1) as avg_score,
            COUNT(g.id) as grade_count
     FROM students s
     JOIN classes c ON s.class_id = c.id
     LEFT JOIN grades g ON g.student_id = s.id AND g.grade_date >= $3
     WHERE c.grade = $1 AND c.section = $2 AND s.status = 'active' %s
     GROUP BY s.id, s.first_name, s.last_name
     ORDER BY avg_score DESC", school_filter), params = params),
    error = function(e) data.frame())

  avg_all <- if (nrow(students) > 0) round(mean(students$avg_score, na.rm = TRUE), 1) else 0

  list(
    title = paste0("Sinif Hesabati -- ", grade, "-", section %||% "A"),
    report_type = "class_report",
    date_range = date_range,
    stats = data.frame(student_count = nrow(students), avg_score = avg_all),
    performance = if (nrow(students) > 0) data.frame(label = students$name, value = students$avg_score) else data.frame(),
    detail_table = students,
    distribution = data.frame(),
    attendance = data.frame()
  )
}

collect_school_rg_report <- function(db_pool, school_id, ay, date_range) {
  school_filter <- if (!is_empty(school_id)) "AND s.school_id = $3" else ""
  params <- list(date_range$start, date_range$end)
  if (!is_empty(school_id)) params <- c(params, list(school_id))

  stats <- tryCatch(db_query(db_pool, sprintf(
    "SELECT COUNT(DISTINCT s.id) as student_count, ROUND(AVG(g.score)::numeric, 1) as avg_score
     FROM students s LEFT JOIN grades g ON g.student_id = s.id AND g.grade_date BETWEEN $1 AND $2
     WHERE s.status = 'active' %s", school_filter), params = params),
    error = function(e) data.frame(student_count = 0, avg_score = 0))

  subjects <- tryCatch(db_query(db_pool, sprintf(
    "SELECT sub.name as label, ROUND(AVG(g.score)::numeric, 1) as value
     FROM grades g JOIN subjects sub ON g.subject_id = sub.id JOIN students s ON g.student_id = s.id
     WHERE g.grade_date BETWEEN $1 AND $2 AND s.status = 'active' %s
     GROUP BY sub.name ORDER BY value DESC", school_filter), params = params),
    error = function(e) data.frame())

  classes <- tryCatch(db_query(db_pool, sprintf(
    "SELECT c.grade || '-' || c.section as label, ROUND(AVG(g.score)::numeric, 1) as value
     FROM grades g JOIN students s ON g.student_id = s.id JOIN classes c ON s.class_id = c.id
     WHERE g.grade_date BETWEEN $1 AND $2 AND s.status = 'active' %s
     GROUP BY c.grade, c.section ORDER BY c.grade, c.section", school_filter), params = params),
    error = function(e) data.frame())

  list(
    title = "Mekteb Hesabati",
    report_type = "school_report",
    date_range = date_range,
    stats = stats,
    performance = subjects,
    class_performance = classes,
    detail_table = data.frame(),
    distribution = data.frame(),
    attendance = data.frame()
  )
}

collect_subject_report <- function(db_pool, subject, ay, date_range, school_id) {
  subject_filter <- if (!is_empty(subject)) "AND sub.name = $3" else ""
  school_filter_idx <- if (!is_empty(subject)) 4 else 3
  school_filter <- if (!is_empty(school_id)) paste0("AND s.school_id = $", school_filter_idx) else ""
  params <- list(date_range$start, date_range$end)
  if (!is_empty(subject)) params <- c(params, list(subject))
  if (!is_empty(school_id)) params <- c(params, list(school_id))

  data <- tryCatch(db_query(db_pool, sprintf(
    "SELECT sub.name as subject, c.grade || '-' || c.section as class,
            ROUND(AVG(g.score)::numeric, 1) as avg_score, COUNT(DISTINCT g.student_id) as students
     FROM grades g JOIN subjects sub ON g.subject_id = sub.id
     JOIN students s ON g.student_id = s.id JOIN classes c ON s.class_id = c.id
     WHERE g.grade_date BETWEEN $1 AND $2 %s %s
     GROUP BY sub.name, c.grade, c.section ORDER BY sub.name, c.grade",
    subject_filter, school_filter), params = params),
    error = function(e) data.frame())

  avg_all <- if (nrow(data) > 0) round(mean(data$avg_score, na.rm = TRUE), 1) else 0
  total_students <- if (nrow(data) > 0) sum(data$students) else 0

  list(
    title = paste0("Fenn Hesabati", if (!is_empty(subject)) paste0(" -- ", subject) else ""),
    report_type = "subject_report",
    date_range = date_range,
    stats = data.frame(student_count = total_students, avg_score = avg_all),
    performance = if (nrow(data) > 0) {
      data.frame(label = paste(data$subject, data$class), value = data$avg_score)
    } else {
      data.frame()
    },
    detail_table = data,
    distribution = data.frame(),
    attendance = data.frame()
  )
}

collect_teacher_rg_report <- function(db_pool, teacher_id, ay, date_range) {
  teacher <- tryCatch(db_get_one(db_pool,
    "SELECT first_name, last_name, category FROM teachers WHERE id = $1",
    params = list(teacher_id)), error = function(e) NULL)

  classes <- tryCatch(db_query(db_pool,
    "SELECT c.grade || '-' || c.section as label, ROUND(AVG(g.score)::numeric, 1) as value,
            COUNT(DISTINCT s.id) as students
     FROM grades g JOIN students s ON g.student_id = s.id JOIN classes c ON s.class_id = c.id
     WHERE g.teacher_id = $1 AND g.grade_date BETWEEN $2 AND $3
     GROUP BY c.grade, c.section ORDER BY c.grade",
    params = list(teacher_id, date_range$start, date_range$end)),
    error = function(e) data.frame())

  name <- if (!is.null(teacher)) paste(teacher$first_name, teacher$last_name) else "Namelum"
  avg_all <- if (nrow(classes) > 0) round(mean(classes$value, na.rm = TRUE), 1) else 0
  total_students <- if (nrow(classes) > 0) sum(classes$students) else 0

  list(
    title = paste0("Muellim Hesabati -- ", name),
    report_type = "teacher_report",
    teacher = teacher,
    date_range = date_range,
    stats = data.frame(student_count = total_students, avg_score = avg_all),
    performance = classes,
    detail_table = data.frame(),
    distribution = data.frame(),
    attendance = data.frame()
  )
}

collect_risk_rg_report <- function(db_pool, ay, date_range, school_id) {
  school_filter <- if (!is_empty(school_id)) "AND s.school_id = $3" else ""
  params <- list(date_range$start, date_range$end)
  if (!is_empty(school_id)) params <- c(params, list(school_id))

  risk_data <- tryCatch(db_query(db_pool, sprintf(
    "SELECT s.first_name || ' ' || s.last_name as name, c.grade, c.section, sch.name as school,
            ROUND(AVG(g.score)::numeric, 1) as avg_score,
            ROUND(
              COUNT(CASE WHEN a.status = 'present' THEN 1 END)::numeric * 100.0
              / NULLIF(COUNT(a.id), 0), 1
            ) as attendance_pct
     FROM students s
     LEFT JOIN classes c ON s.class_id = c.id
     LEFT JOIN schools sch ON s.school_id = sch.id
     LEFT JOIN grades g ON g.student_id = s.id AND g.grade_date BETWEEN $1 AND $2
     LEFT JOIN attendance a ON a.student_id = s.id AND a.attendance_date BETWEEN $1 AND $2
     WHERE s.status = 'active' %s
     GROUP BY s.first_name, s.last_name, c.grade, c.section, sch.name
     HAVING AVG(g.score) < 51
        OR COUNT(CASE WHEN a.status = 'present' THEN 1 END)::numeric * 100.0
           / NULLIF(COUNT(a.id), 0) < 80
     ORDER BY AVG(g.score) NULLS FIRST", school_filter), params = params),
    error = function(e) data.frame())

  avg_all <- if (nrow(risk_data) > 0) round(mean(risk_data$avg_score, na.rm = TRUE), 1) else 0

  list(
    title = "Risk Hesabati",
    report_type = "risk_report",
    date_range = date_range,
    stats = data.frame(student_count = nrow(risk_data), avg_score = avg_all),
    performance = data.frame(),
    detail_table = risk_data,
    distribution = data.frame(),
    attendance = data.frame()
  )
}


# =============================================
# BATCH HEDEFLERI
# =============================================

get_batch_targets <- function(db_pool, batch_type, input) {
  targets <- list()

  if (batch_type == "class_students") {
    grade <- input$rg_class_grade
    section <- input$rg_class_section
    if (is_empty(grade)) return(list())

    students <- tryCatch(db_query(db_pool,
      "SELECT s.id, s.first_name || ' ' || s.last_name as name
       FROM students s JOIN classes c ON s.class_id = c.id
       WHERE c.grade = $1 AND c.section = $2 AND s.status = 'active'
       ORDER BY s.last_name",
      params = list(as.integer(grade), section %||% "A")),
      error = function(e) data.frame())

    if (nrow(students) > 0) {
      ay <- input$rg_year
      date_range <- get_period_dates(input$rg_period, ay)
      for (i in seq_len(nrow(students))) {
        sid <- students$id[i]
        sname <- students$name[i]
        targets[[length(targets) + 1]] <- list(
          label = sname,
          collect_fn = local({
            local_sid <- sid
            local_ay <- ay
            local_dr <- date_range
            function() collect_student_report(db_pool, local_sid, local_ay, local_dr)
          })
        )
      }
    }

  } else if (batch_type == "school_classes") {
    school_id <- input$rg_school
    school_filter <- if (!is_empty(school_id)) "AND c.school_id = $1" else ""
    params <- if (!is_empty(school_id)) list(school_id) else list()

    classes <- tryCatch(db_query(db_pool, sprintf(
      "SELECT DISTINCT c.grade, c.section FROM classes c WHERE 1=1 %s ORDER BY c.grade, c.section",
      school_filter), params = params),
      error = function(e) data.frame())

    if (nrow(classes) > 0) {
      ay <- input$rg_year
      date_range <- get_period_dates(input$rg_period, ay)
      for (i in seq_len(nrow(classes))) {
        g <- classes$grade[i]
        s <- classes$section[i]
        targets[[length(targets) + 1]] <- list(
          label = paste0("Sinif ", g, "-", s),
          collect_fn = local({
            local_g <- g; local_s <- s; local_ay <- ay; local_dr <- date_range; local_sid <- school_id
            function() collect_class_report(db_pool, local_g, local_s, local_ay, local_dr, local_sid)
          })
        )
      }
    }

  } else if (batch_type == "all_schools") {
    schools <- tryCatch(db_query(db_pool,
      "SELECT id, name FROM schools WHERE status = 'active' ORDER BY name"),
      error = function(e) data.frame())

    if (nrow(schools) > 0) {
      ay <- input$rg_year
      date_range <- get_period_dates(input$rg_period, ay)
      for (i in seq_len(nrow(schools))) {
        sch_id <- schools$id[i]
        sch_name <- schools$name[i]
        targets[[length(targets) + 1]] <- list(
          label = sch_name,
          collect_fn = local({
            local_id <- sch_id; local_ay <- ay; local_dr <- date_range
            function() collect_school_rg_report(db_pool, local_id, local_ay, local_dr)
          })
        )
      }
    }
  }

  targets
}


# =============================================
# AI XULASE
# =============================================

generate_report_summary <- function(data) {
  context <- paste0("Hesabat: ", data$title, "\n")
  if (!is.null(data$stats) && nrow(data$stats) > 0) {
    context <- paste0(context,
      "Sagird sayi: ", data$stats$student_count[1],
      ", Orta bal: ", data$stats$avg_score[1], "\n")
  }
  if (!is.null(data$performance) && nrow(data$performance) > 0) {
    top_items <- head(data$performance, 5)
    context <- paste0(context,
      "Performans: ", paste(top_items$label, "=", top_items$value, collapse = ", "), "\n")
  }
  if (!is.null(data$attendance) && nrow(data$attendance) > 0) {
    context <- paste0(context,
      "Davamiyyet: ", paste(data$attendance$status, "=", data$attendance$count, collapse = ", "), "\n")
  }

  result <- tryCatch(
    call_claude_api(
      paste0(
        "Bu tehsil hesabati ucun 3-4 cumle xulase yaz, guclu/zeif terefler, ",
        "tovsiyeler daxil et:\n\n", context
      ),
      system_prompt = "Sen tehsil analitikisisen. Azerbaijan dilinde, qisa ve deqiq xulase yaz.",
      max_tokens = 1024,
      temperature = 0.5
    ),
    error = function(e) list(success = FALSE, message = e$message)
  )

  if (isTRUE(result$success)) {
    result$content %||% result$message
  } else {
    generate_fallback_summary(data)
  }
}

generate_report_recommendations <- function(data) {
  context <- paste0("Hesabat: ", data$title, "\n")
  if (!is.null(data$stats) && nrow(data$stats) > 0) {
    context <- paste0(context,
      "Sagird sayi: ", data$stats$student_count[1],
      ", Orta bal: ", data$stats$avg_score[1], "\n")
  }
  if (!is.null(data$performance) && nrow(data$performance) > 0) {
    low_perf <- data$performance[data$performance$value < 51, ]
    if (nrow(low_perf) > 0) {
      context <- paste0(context, "Asagi performans: ",
        paste(head(low_perf$label, 5), "=", head(low_perf$value, 5), collapse = ", "), "\n")
    }
  }

  result <- tryCatch(
    call_claude_api(
      paste0(
        "Bu tehsil hesabati esasinda 3-5 konkret tovsiye ver. ",
        "Her tovsiye qisa ve emeliydir:\n\n", context
      ),
      system_prompt = "Sen tehsil musavirisen. Azerbaijan dilinde, numerelendirilmis tovsiyeler ver.",
      max_tokens = 1024,
      temperature = 0.5
    ),
    error = function(e) list(success = FALSE, message = e$message)
  )

  if (isTRUE(result$success)) {
    result$content %||% result$message
  } else {
    NULL
  }
}


# =============================================
# RENDER PREVIEW
# =============================================

render_report_preview <- function(data, input) {
  sections <- list()

  # Header
  sections <- c(sections, list(
    tags$div(
      style = "text-align:center; padding:20px; background:linear-gradient(135deg, #2c3e50, #3498db); color:#fff; border-radius:10px; margin-bottom:20px;",
      tags$h2(style = "margin:0;", "ARTI-2026"),
      tags$p(data$title),
      tags$small(paste0(
        "Tarix: ", format(Sys.Date(), "%d.%m.%Y"),
        " | Dovr: ", format(data$date_range$start, "%d.%m"),
        " -- ", format(data$date_range$end, "%d.%m.%Y")
      ))
    )
  ))

  # KPIs
  if (isTRUE(input$rg_inc_kpi) && !is.null(data$stats) && nrow(data$stats) > 0) {
    s <- data$stats[1, ]
    sc <- s$student_count %||% 0
    av <- s$avg_score %||% 0
    sections <- c(sections, list(
      fluidRow(
        column(6, tags$div(
          style = "text-align:center; padding:15px; background:#eaf2f8; border-radius:8px;",
          tags$h3(style = "color:#2980b9; margin:0;", sc),
          tags$small("Sagird Sayi")
        )),
        column(6, tags$div(
          style = "text-align:center; padding:15px; background:#eafaf1; border-radius:8px;",
          tags$h3(style = paste0("color:", get_grade_color(av), "; margin:0;"), av),
          tags$small(paste0("Orta Bal (", get_grade_label(av), ")"))
        ))
      ),
      tags$br()
    ))
  }

  # AI Summary
  if (isTRUE(input$rg_inc_summary) && !is.null(data$ai_summary)) {
    sections <- c(sections, list(
      tags$div(
        style = "background:#f0f7ff; padding:16px; border-radius:8px; border-left:4px solid #3498db; margin-bottom:15px;",
        tags$h4(icon("robot"), " AI Xulase"),
        tags$p(data$ai_summary)
      )
    ))
  }

  # AI Recommendations
  if (isTRUE(input$rg_inc_recommendations) && !is.null(data$ai_recommendations)) {
    sections <- c(sections, list(
      tags$div(
        style = "background:#fef9e7; padding:16px; border-radius:8px; border-left:4px solid #f39c12; margin-bottom:15px;",
        tags$h4(icon("lightbulb"), " AI Tovsiyeler"),
        tags$p(style = "white-space:pre-wrap;", data$ai_recommendations)
      )
    ))
  }

  # Performance bars
  if (isTRUE(input$rg_inc_charts) && !is.null(data$performance) && nrow(data$performance) > 0) {
    sections <- c(sections, list(
      tags$h4(icon("chart-bar"), " Performans"),
      tags$div(
        lapply(seq_len(min(nrow(data$performance), 15)), function(i) {
          p <- data$performance[i, ]
          pct <- min(max(as.numeric(p$value), 0), 100)
          color <- get_grade_color(pct)
          tags$div(style = "margin-bottom:6px;",
            tags$div(
              style = "display:flex; justify-content:space-between; font-size:0.9em;",
              tags$span(p$label),
              tags$span(style = paste0("color:", color, "; font-weight:bold;"),
                paste0(p$value, "%"))
            ),
            tags$div(
              style = "background:#ecf0f1; border-radius:4px; height:8px;",
              tags$div(style = paste0(
                "background:", color, "; width:", pct, "%; height:100%; border-radius:4px;"
              ))
            )
          )
        })
      ),
      tags$br()
    ))
  }

  # Attendance
  if (isTRUE(input$rg_inc_attendance) && !is.null(data$attendance) && nrow(data$attendance) > 0) {
    att <- data$attendance
    total_att <- sum(att$count, na.rm = TRUE)
    sections <- c(sections, list(
      tags$h4(icon("calendar-check"), " Davamiyyet"),
      tags$div(style = "margin-bottom:15px;",
        lapply(seq_len(nrow(att)), function(i) {
          status_label <- switch(att$status[i],
            "present" = "Istirak",
            "absent" = "Qayib",
            "late" = "Gecikme",
            "excused" = "Uzurlu",
            att$status[i]
          )
          pct <- if (total_att > 0) round(att$count[i] / total_att * 100, 1) else 0
          status_color <- switch(att$status[i],
            "present" = "#27ae60",
            "absent" = "#e74c3c",
            "late" = "#f39c12",
            "excused" = "#3498db",
            "#95a5a6"
          )
          tags$div(style = "margin-bottom:4px;",
            tags$span(style = paste0("color:", status_color, "; font-weight:bold;"), status_label),
            tags$span(paste0(": ", att$count[i], " (", pct, "%)"))
          )
        })
      )
    ))
  }

  # Detail table
  if (isTRUE(input$rg_inc_table) && !is.null(data$detail_table) && nrow(data$detail_table) > 0) {
    sections <- c(sections, list(
      tags$h4(icon("table"), " Detalli Melumatlar"),
      tags$div(style = "max-height:300px; overflow-y:auto;",
        renderDT({
          datatable(head(data$detail_table, 50),
            options = list(dom = "t", pageLength = 50), rownames = FALSE)
        })
      )
    ))
  }

  tags$div(class = "report-preview", style = "padding:15px;", sections)
}


# =============================================
# WORD HESABAT (officer + flextable)
# =============================================

generate_word_report <- function(data, file, input) {
  tryCatch({
    doc <- officer::read_docx()

    # Title page
    doc <- officer::body_add_par(doc, "ARTI-2026 Tehsil Idareetme Sistemi", style = "heading 1")
    doc <- officer::body_add_par(doc, data$title, style = "heading 2")
    doc <- officer::body_add_par(doc, paste0("Tarix: ", format(Sys.Date(), "%d.%m.%Y")))
    doc <- officer::body_add_par(doc, paste0(
      "Dovr: ", format(data$date_range$start, "%d.%m.%Y"),
      " -- ", format(data$date_range$end, "%d.%m.%Y")
    ))
    doc <- officer::body_add_par(doc, "")

    # Stats section
    if (isTRUE(input$rg_inc_kpi) && !is.null(data$stats) && nrow(data$stats) > 0) {
      s <- data$stats[1, ]
      doc <- officer::body_add_par(doc, "Esas Gostericiler", style = "heading 2")

      kpi_df <- data.frame(
        Gosterici = c("Sagird sayi", "Orta bal", "Qiymet"),
        Deyer = c(
          as.character(s$student_count %||% 0),
          as.character(s$avg_score %||% 0),
          get_grade_label(s$avg_score %||% 0)
        ),
        stringsAsFactors = FALSE
      )
      ft <- flextable::flextable(kpi_df)
      ft <- flextable::theme_box(ft)
      ft <- flextable::autofit(ft)
      ft <- flextable::bold(ft, part = "header")
      ft <- flextable::bg(ft, part = "header", bg = "#2c3e50")
      ft <- flextable::color(ft, part = "header", color = "#FFFFFF")
      doc <- flextable::body_add_flextable(doc, ft)
      doc <- officer::body_add_par(doc, "")
    }

    # AI Summary
    if (isTRUE(input$rg_inc_summary) && !is.null(data$ai_summary)) {
      doc <- officer::body_add_par(doc, "AI Xulase", style = "heading 2")
      doc <- officer::body_add_par(doc, data$ai_summary)
      doc <- officer::body_add_par(doc, "")
    }

    # AI Recommendations
    if (isTRUE(input$rg_inc_recommendations) && !is.null(data$ai_recommendations)) {
      doc <- officer::body_add_par(doc, "AI Tovsiyeler", style = "heading 2")
      doc <- officer::body_add_par(doc, data$ai_recommendations)
      doc <- officer::body_add_par(doc, "")
    }

    # Performance table
    if (isTRUE(input$rg_inc_charts) && !is.null(data$performance) && nrow(data$performance) > 0) {
      doc <- officer::body_add_par(doc, "Performans", style = "heading 2")
      perf <- data$performance
      names(perf) <- c("Kateqoriya", "Orta Bal")
      perf[["Qiymet"]] <- sapply(perf[["Orta Bal"]], get_grade_label)
      ft <- flextable::flextable(perf)
      ft <- flextable::theme_box(ft)
      ft <- flextable::autofit(ft)
      ft <- flextable::bold(ft, part = "header")
      ft <- flextable::bg(ft, part = "header", bg = "#2c3e50")
      ft <- flextable::color(ft, part = "header", color = "#FFFFFF")
      doc <- flextable::body_add_flextable(doc, ft)
      doc <- officer::body_add_par(doc, "")
    }

    # Attendance
    if (isTRUE(input$rg_inc_attendance) && !is.null(data$attendance) && nrow(data$attendance) > 0) {
      doc <- officer::body_add_par(doc, "Davamiyyet", style = "heading 2")
      att <- data$attendance
      att$status <- sapply(att$status, function(s) {
        switch(s,
          "present" = "Istirak",
          "absent" = "Qayib",
          "late" = "Gecikme",
          "excused" = "Uzurlu",
          s
        )
      })
      names(att) <- c("Status", "Say")
      ft <- flextable::flextable(att)
      ft <- flextable::theme_box(ft)
      ft <- flextable::autofit(ft)
      doc <- flextable::body_add_flextable(doc, ft)
      doc <- officer::body_add_par(doc, "")
    }

    # Detail table
    if (isTRUE(input$rg_inc_table) && !is.null(data$detail_table) && nrow(data$detail_table) > 0) {
      doc <- officer::body_add_par(doc, "Detalli Melumatlar", style = "heading 2")
      detail <- head(data$detail_table, 100)
      ft <- flextable::flextable(detail)
      ft <- flextable::theme_box(ft)
      ft <- flextable::autofit(ft)
      ft <- flextable::fontsize(ft, size = 9)
      ft <- flextable::bold(ft, part = "header")
      ft <- flextable::bg(ft, part = "header", bg = "#34495e")
      ft <- flextable::color(ft, part = "header", color = "#FFFFFF")
      doc <- flextable::body_add_flextable(doc, ft)
    }

    # Footer
    doc <- officer::body_add_par(doc, "")
    doc <- officer::body_add_par(doc, paste0(
      "Bu hesabat ARTI-2026 terefinden avtomatik yaradilmisdir. Tarix: ",
      format(Sys.time(), "%d.%m.%Y %H:%M")
    ))

    print(doc, target = file)

  }, error = function(e) {
    # Fallback to plain text
    lines <- c(
      data$title,
      paste(rep("=", 50), collapse = ""),
      "",
      paste0("Tarix: ", format(Sys.Date(), "%d.%m.%Y")),
      paste0("Dovr: ", format(data$date_range$start, "%d.%m.%Y"), " -- ", format(data$date_range$end, "%d.%m.%Y")),
      ""
    )
    if (!is.null(data$stats) && nrow(data$stats) > 0) {
      s <- data$stats[1, ]
      lines <- c(lines, "ESAS GOSTERICILER:", paste0("  Sagird sayi: ", s$student_count %||% 0),
        paste0("  Orta bal: ", s$avg_score %||% 0), "")
    }
    if (!is.null(data$ai_summary)) {
      lines <- c(lines, "XULASE:", data$ai_summary, "")
    }
    if (!is.null(data$ai_recommendations)) {
      lines <- c(lines, "TOVSIYELER:", data$ai_recommendations, "")
    }
    if (!is.null(data$performance) && nrow(data$performance) > 0) {
      lines <- c(lines, "PERFORMANS:")
      for (i in seq_len(nrow(data$performance))) {
        lines <- c(lines, paste0("  ", data$performance$label[i], ": ", data$performance$value[i]))
      }
      lines <- c(lines, "")
    }
    if (!is.null(data$detail_table) && nrow(data$detail_table) > 0) {
      lines <- c(lines, "DETALLI MELUMATLAR:")
      lines <- c(lines, paste(names(data$detail_table), collapse = "\t"))
      for (i in seq_len(min(nrow(data$detail_table), 50))) {
        lines <- c(lines, paste(data$detail_table[i, ], collapse = "\t"))
      }
    }
    lines <- c(lines, "", paste0("ARTI-2026 | ", format(Sys.time(), "%d.%m.%Y %H:%M")))
    writeLines(lines, file)
  })
}


# =============================================
# PDF HESABAT
# =============================================

generate_pdf_report <- function(data, file, input) {
  # Generate HTML first, then convert to PDF
  html_file <- tempfile(fileext = ".html")
  generate_html_report(data, html_file, input)

  # Try pagedown/chrome_print for proper PDF conversion
  converted <- tryCatch({
    if (requireNamespace("pagedown", quietly = TRUE)) {
      pagedown::chrome_print(html_file, file, wait = 15)
      TRUE
    } else {
      FALSE
    }
  }, error = function(e) FALSE)

  # Fallback: try rmarkdown with weasyprint or wkhtmltopdf
  if (!converted) {
    converted <- tryCatch({
      if (Sys.which("wkhtmltopdf") != "") {
        system2("wkhtmltopdf", args = c("--quiet", html_file, file), stdout = FALSE, stderr = FALSE)
        file.exists(file)
      } else {
        FALSE
      }
    }, error = function(e) FALSE)
  }

  # Final fallback: copy HTML (user can print to PDF from browser)
  if (!converted) {
    file.copy(html_file, file, overwrite = TRUE)
    notify_warning("PDF cevirici tapilmadi. HTML fayl olaraq saxlanildi. Brauzerde PDF olaraq cap edin.")
  }

  unlink(html_file)
}


# =============================================
# HTML HESABAT
# =============================================

generate_html_report <- function(data, file, input) {
  css <- '
  body{font-family:"Segoe UI",Arial,sans-serif;max-width:900px;margin:0 auto;padding:20px;color:#2c3e50}
  h1{color:#2c3e50;border-bottom:3px solid #3498db;padding-bottom:8px}
  h2{color:#34495e;border-bottom:1px solid #bdc3c7;padding-bottom:4px}
  .header{text-align:center;padding:30px;background:linear-gradient(135deg,#2c3e50,#3498db);color:#fff;border-radius:10px;margin-bottom:20px}
  .header h1{color:#fff;border:none;margin:0}
  .kpi-row{display:flex;justify-content:center;gap:20px;margin:20px 0}
  .kpi{text-align:center;padding:20px 40px;background:#f8f9fa;border-radius:10px;border:1px solid #ecf0f1}
  .kpi h3{margin:0;color:#2980b9;font-size:28px}
  .kpi small{color:#7f8c8d}
  .summary-box{background:#f0f7ff;padding:16px;border-radius:8px;border-left:4px solid #3498db;margin:15px 0}
  .rec-box{background:#fef9e7;padding:16px;border-radius:8px;border-left:4px solid #f39c12;margin:15px 0}
  table{width:100%%;border-collapse:collapse;margin:16px 0}
  th{background:#2c3e50;color:#fff;padding:10px 12px;text-align:left}
  td{padding:8px 12px;border-bottom:1px solid #ecf0f1}
  tr:nth-child(even){background:#f8f9fa}
  .bar-container{background:#ecf0f1;border-radius:4px;height:10px;margin-top:2px}
  .bar-fill{height:100%%;border-radius:4px}
  .footer{text-align:center;margin-top:40px;padding-top:16px;border-top:2px solid #bdc3c7;color:#95a5a6;font-size:12px}
  @media print{body{max-width:100%%} .header{-webkit-print-color-adjust:exact;print-color-adjust:exact}}
  '

  html <- sprintf('<!DOCTYPE html><html lang="az"><head><meta charset="UTF-8"><title>%s</title><style>%s</style></head><body>',
    htmltools::htmlEscape(data$title), css)

  # Header
  html <- paste0(html, sprintf(
    '<div class="header"><h1>ARTI-2026</h1><p>%s</p><small>Tarix: %s | Dovr: %s -- %s</small></div>',
    htmltools::htmlEscape(data$title),
    format(Sys.Date(), "%d.%m.%Y"),
    format(data$date_range$start, "%d.%m.%Y"),
    format(data$date_range$end, "%d.%m.%Y")
  ))

  # KPIs
  if (isTRUE(input$rg_inc_kpi) && !is.null(data$stats) && nrow(data$stats) > 0) {
    s <- data$stats[1, ]
    sc <- s$student_count %||% 0
    av <- s$avg_score %||% 0
    html <- paste0(html, sprintf(
      '<div class="kpi-row"><div class="kpi"><h3>%s</h3><small>Sagird</small></div><div class="kpi"><h3>%s</h3><small>Orta Bal (%s)</small></div></div>',
      sc, av, htmltools::htmlEscape(get_grade_label(av))
    ))
  }

  # AI Summary
  if (isTRUE(input$rg_inc_summary) && !is.null(data$ai_summary)) {
    html <- paste0(html, sprintf(
      '<div class="summary-box"><h2>AI Xulase</h2><p>%s</p></div>',
      htmltools::htmlEscape(data$ai_summary)
    ))
  }

  # AI Recommendations
  if (isTRUE(input$rg_inc_recommendations) && !is.null(data$ai_recommendations)) {
    html <- paste0(html, sprintf(
      '<div class="rec-box"><h2>AI Tovsiyeler</h2><p style="white-space:pre-wrap;">%s</p></div>',
      htmltools::htmlEscape(data$ai_recommendations)
    ))
  }

  # Performance
  if (isTRUE(input$rg_inc_charts) && !is.null(data$performance) && nrow(data$performance) > 0) {
    html <- paste0(html, '<h2>Performans</h2><table><tr><th>Kateqoriya</th><th>Orta Bal</th><th>Qiymet</th><th>Vizual</th></tr>')
    for (i in seq_len(min(nrow(data$performance), 30))) {
      p <- data$performance[i, ]
      val <- as.numeric(p$value)
      pct <- min(max(val, 0), 100)
      color <- get_grade_color(val)
      html <- paste0(html, sprintf(
        '<tr><td>%s</td><td style="font-weight:bold;color:%s">%s</td><td>%s</td><td><div class="bar-container"><div class="bar-fill" style="background:%s;width:%s%%"></div></div></td></tr>',
        htmltools::htmlEscape(as.character(p$label)), color, val,
        htmltools::htmlEscape(get_grade_label(val)), color, pct
      ))
    }
    html <- paste0(html, '</table>')
  }

  # Attendance
  if (isTRUE(input$rg_inc_attendance) && !is.null(data$attendance) && nrow(data$attendance) > 0) {
    html <- paste0(html, '<h2>Davamiyyet</h2><table><tr><th>Status</th><th>Say</th><th>Faiz</th></tr>')
    att <- data$attendance
    total_att <- sum(att$count, na.rm = TRUE)
    for (i in seq_len(nrow(att))) {
      status_label <- switch(att$status[i],
        "present" = "Istirak", "absent" = "Qayib",
        "late" = "Gecikme", "excused" = "Uzurlu", att$status[i])
      pct <- if (total_att > 0) round(att$count[i] / total_att * 100, 1) else 0
      html <- paste0(html, sprintf('<tr><td>%s</td><td>%s</td><td>%s%%</td></tr>',
        htmltools::htmlEscape(status_label), att$count[i], pct))
    }
    html <- paste0(html, '</table>')
  }

  # Detail table
  if (isTRUE(input$rg_inc_table) && !is.null(data$detail_table) && nrow(data$detail_table) > 0) {
    html <- paste0(html, '<h2>Detalli Melumatlar</h2><table><tr>')
    for (col in names(data$detail_table)) {
      html <- paste0(html, sprintf('<th>%s</th>', htmltools::htmlEscape(col)))
    }
    html <- paste0(html, '</tr>')
    for (i in seq_len(min(nrow(data$detail_table), 100))) {
      html <- paste0(html, '<tr>')
      for (j in seq_along(data$detail_table)) {
        val <- data$detail_table[i, j]
        display_val <- if (is.na(val)) "---" else htmltools::htmlEscape(as.character(val))
        html <- paste0(html, sprintf('<td>%s</td>', display_val))
      }
      html <- paste0(html, '</tr>')
    }
    html <- paste0(html, '</table>')
  }

  # Footer
  html <- paste0(html, sprintf(
    '<div class="footer"><p>ARTI-2026 Tehsil Idareetme Sistemi -- Avtomatik Hesabat</p><p>%s</p></div></body></html>',
    format(Sys.time(), "%d.%m.%Y %H:%M")
  ))

  writeLines(html, file, useBytes = TRUE)
}


# =============================================
# EXCEL HESABAT
# =============================================

generate_excel_rg_report <- function(data, file) {
  wb <- openxlsx::createWorkbook()

  header_style <- openxlsx::createStyle(
    fontColour = "#FFFFFF", fgFill = "#2c3e50",
    halign = "center", textDecoration = "bold",
    border = "TopBottomLeftRight"
  )
  data_style <- openxlsx::createStyle(border = "TopBottomLeftRight")
  title_style <- openxlsx::createStyle(fontSize = 16, textDecoration = "bold", fontColour = "#2c3e50")
  subtitle_style <- openxlsx::createStyle(fontSize = 12, fontColour = "#7f8c8d")

  # Xulase sheet
  openxlsx::addWorksheet(wb, "Xulase")
  openxlsx::writeData(wb, "Xulase", x = data$title, startRow = 1, startCol = 1)
  openxlsx::addStyle(wb, "Xulase", title_style, rows = 1, cols = 1)

  openxlsx::writeData(wb, "Xulase", x = paste0(
    "Dovr: ", format(data$date_range$start, "%d.%m.%Y"),
    " -- ", format(data$date_range$end, "%d.%m.%Y")
  ), startRow = 2, startCol = 1)
  openxlsx::addStyle(wb, "Xulase", subtitle_style, rows = 2, cols = 1)

  if (!is.null(data$stats) && nrow(data$stats) > 0) {
    s <- data$stats[1, ]
    kpi_df <- data.frame(
      Gosterici = c("Sagird sayi", "Orta bal", "Qiymet"),
      Deyer = c(as.character(s$student_count %||% 0), as.character(s$avg_score %||% 0), get_grade_label(s$avg_score %||% 0)),
      stringsAsFactors = FALSE
    )
    openxlsx::writeData(wb, "Xulase", kpi_df, startRow = 4, headerStyle = header_style)
    openxlsx::addStyle(wb, "Xulase", data_style, rows = 5:7, cols = 1:2, gridExpand = TRUE)
  }

  if (!is.null(data$ai_summary)) {
    openxlsx::writeData(wb, "Xulase", x = "AI Xulase:", startRow = 9, startCol = 1)
    openxlsx::addStyle(wb, "Xulase", openxlsx::createStyle(textDecoration = "bold"), rows = 9, cols = 1)
    openxlsx::writeData(wb, "Xulase", x = data$ai_summary, startRow = 10, startCol = 1)
  }

  if (!is.null(data$ai_recommendations)) {
    openxlsx::writeData(wb, "Xulase", x = "AI Tovsiyeler:", startRow = 12, startCol = 1)
    openxlsx::addStyle(wb, "Xulase", openxlsx::createStyle(textDecoration = "bold"), rows = 12, cols = 1)
    openxlsx::writeData(wb, "Xulase", x = data$ai_recommendations, startRow = 13, startCol = 1)
  }

  openxlsx::setColWidths(wb, "Xulase", cols = 1:2, widths = c(40, 30))

  # Performans sheet
  if (!is.null(data$performance) && nrow(data$performance) > 0) {
    openxlsx::addWorksheet(wb, "Performans")
    perf <- data$performance
    names(perf) <- c("Kateqoriya", "Orta Bal")
    perf[["Qiymet"]] <- sapply(perf[["Orta Bal"]], get_grade_label)
    openxlsx::writeData(wb, "Performans", perf, headerStyle = header_style)
    openxlsx::addStyle(wb, "Performans", data_style,
      rows = 2:(nrow(perf) + 1), cols = 1:3, gridExpand = TRUE)
    openxlsx::setColWidths(wb, "Performans", cols = 1:3, widths = c(30, 15, 15))
  }

  # Detalli sheet
  if (!is.null(data$detail_table) && nrow(data$detail_table) > 0) {
    openxlsx::addWorksheet(wb, "Detalli")
    openxlsx::writeData(wb, "Detalli", data$detail_table, headerStyle = header_style)
    nc <- ncol(data$detail_table)
    nr <- nrow(data$detail_table)
    if (nc > 0 && nr > 0) {
      openxlsx::addStyle(wb, "Detalli", data_style, rows = 2:(nr + 1), cols = 1:nc, gridExpand = TRUE)
      openxlsx::setColWidths(wb, "Detalli", cols = 1:nc, widths = "auto")
    }
  }

  # Davamiyyet sheet
  if (!is.null(data$attendance) && nrow(data$attendance) > 0) {
    openxlsx::addWorksheet(wb, "Davamiyyet")
    att <- data$attendance
    att$status <- sapply(att$status, function(s) {
      switch(s, "present" = "Istirak", "absent" = "Qayib",
        "late" = "Gecikme", "excused" = "Uzurlu", s)
    })
    names(att) <- c("Status", "Say")
    openxlsx::writeData(wb, "Davamiyyet", att, headerStyle = header_style)
    openxlsx::setColWidths(wb, "Davamiyyet", cols = 1:2, widths = c(20, 15))
  }

  openxlsx::saveWorkbook(wb, file, overwrite = TRUE)
}
