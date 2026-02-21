# =============================================
# ARTI-2026: Hesabat Generasiyası (Genişləndirilmiş)
# Aylıq, rüblük, illik, fərdi, məktəb, rayon hesabatları
# Claude AI xülasə + Plotly qrafiklər + Word/PDF/Excel
# =============================================

# ---- UI ----
reports_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(column(12, h2(icon("file-pdf"), "Hesabat Mərkəzi"), hr())),

    # --- 1. Parametrlər ---
    fluidRow(
      column(3, selectInput(ns("report_type"), "Hesabat növü:", choices = c(
        "Aylıq İcmal"           = "monthly",
        "Rüblük Hesabat"        = "quarterly",
        "İllik Hesabat"         = "annual",
        "Fərdi Şagird"          = "student",
        "Fərdi Müəllim"         = "teacher",
        "Məktəb Hesabatı"       = "school",
        "Rayon / Ümumi"         = "district"
      ))),
      column(2, selectInput(ns("period"), "Dövr:", choices = c(
        "I yarımil"  = "sem1",
        "II yarımil" = "sem2",
        "İllik"      = "year"
      ))),
      column(2, conditionalPanel(
        condition = sprintf("input['%s'] == 'monthly'", ns("report_type")),
        selectInput(ns("month_select"), "Ay:", choices = setNames(1:12, c(
          "Yanvar","Fevral","Mart","Aprel","May","İyun",
          "İyul","Avqust","Sentyabr","Oktyabr","Noyabr","Dekabr"
        )), selected = as.integer(format(Sys.Date(), "%m")))
      )),
      column(2, conditionalPanel(
        condition = sprintf("input['%s'] == 'quarterly'", ns("report_type")),
        selectInput(ns("quarter_select"), "Rüb:", choices = c(
          "I Rüb (Sen-Noy)"  = "Q1",
          "II Rüb (Dek-Fev)" = "Q2",
          "III Rüb (Mar-May)" = "Q3",
          "IV Rüb (İyn-Avq)" = "Q4"
        ))
      )),
      column(3, selectInput(ns("academic_year"), "Tədris ili:",
        choices = c("2025-2026", "2024-2025", "2023-2024"), selected = "2025-2026"))
    ),

    # --- Kontekst filtrləri ---
    fluidRow(
      column(3, conditionalPanel(
        condition = sprintf("input['%s'] == 'school' || input['%s'] == 'monthly' || input['%s'] == 'quarterly' || input['%s'] == 'annual'",
          ns("report_type"), ns("report_type"), ns("report_type"), ns("report_type")),
        selectInput(ns("school_select"), "Məktəb:", choices = c("Bütün məktəblər" = ""))
      )),
      column(3, conditionalPanel(
        condition = sprintf("input['%s'] == 'student'", ns("report_type")),
        selectizeInput(ns("student_select"), "Şagird:", choices = NULL, options = list(placeholder = "Axtar..."))
      )),
      column(3, conditionalPanel(
        condition = sprintf("input['%s'] == 'teacher'", ns("report_type")),
        selectizeInput(ns("teacher_select"), "Müəllim:", choices = NULL, options = list(placeholder = "Axtar..."))
      )),
      column(3, conditionalPanel(
        condition = sprintf("input['%s'] == 'district'", ns("report_type")),
        selectInput(ns("region_select"), "Rayon:", choices = c("Bütün rayonlar" = ""))
      ))
    ),

    # --- Əməliyyat düymələri ---
    fluidRow(column(12, div(class = "btn-toolbar",
      actionButton(ns("btn_generate"), "Hesabatı Yarat", icon = icon("magic"), class = "btn-primary btn-lg"),
      downloadButton(ns("btn_download_word"), "Word", class = "btn-info"),
      downloadButton(ns("btn_download_pdf"), "PDF", class = "btn-danger"),
      downloadButton(ns("btn_download_excel"), "Excel", class = "btn-success"),
      actionButton(ns("btn_email"), "E-poçtla Göndər", icon = icon("envelope"), class = "btn-default")
    ))),
    br(),

    # --- 2. AI Xülasə ---
    fluidRow(column(12, wellPanel(
      id = ns("summary_panel"),
      div(style = "display:flex; align-items:center; gap:10px;",
        h3(icon("robot"), "AI Xülasə"),
        uiOutput(ns("summary_badge"))
      ),
      uiOutput(ns("ai_summary")),
      tags$hr(),
      # --- KPI kartları ---
      uiOutput(ns("kpi_cards"))
    ))),

    # --- 3. Qrafiklər ---
    fluidRow(
      column(6, wellPanel(
        h4(icon("chart-bar"), "Performans Qrafiki"),
        plotlyOutput(ns("chart_performance"), height = "350px")
      )),
      column(6, wellPanel(
        h4(icon("chart-pie"), "Paylanma Qrafiki"),
        plotlyOutput(ns("chart_distribution"), height = "350px")
      ))
    ),
    fluidRow(
      column(6, wellPanel(
        h4(icon("chart-line"), "Trend Qrafiki"),
        plotlyOutput(ns("chart_trend"), height = "300px")
      )),
      column(6, wellPanel(
        h4(icon("chart-area"), "Müqayisə Qrafiki"),
        plotlyOutput(ns("chart_comparison"), height = "300px")
      ))
    ),

    # --- 4. Detallı Cədvəl ---
    fluidRow(column(12, wellPanel(
      h3(icon("table"), "Detallı Məlumatlar"),
      DTOutput(ns("detail_table"))
    ))),

    # --- 5. Planlanmış Hesabatlar ---
    fluidRow(column(12, wellPanel(
      h3(icon("clock"), "Planlanmış Hesabatlar"),
      fluidRow(
        column(3, selectInput(ns("sched_type"), "Növ:", choices = c(
          "Aylıq İcmal" = "monthly", "Rüblük" = "quarterly", "İllik" = "annual"
        ))),
        column(3, selectInput(ns("sched_format"), "Format:", choices = c("Word" = "docx", "PDF" = "pdf", "Excel" = "xlsx"))),
        column(3, textInput(ns("sched_email"), "E-poçt:", placeholder = "hesabat@mekteb.az")),
        column(3, br(), actionButton(ns("btn_schedule"), "Planla", icon = icon("plus"), class = "btn-warning"))
      ),
      DTOutput(ns("scheduled_reports"))
    )))
  )
}

# ---- SERVER ----
reports_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Reaktiv dəyərlər
    report_data    <- reactiveVal(NULL)
    ai_summary_val <- reactiveVal(NULL)
    chart_data     <- reactiveVal(NULL)

    # --- Dropdown-ları doldur ---
    observe({
      # Məktəblər
      schools <- db_query(db_pool, "SELECT id, name FROM schools WHERE status = 'active' ORDER BY name")
      if (nrow(schools) > 0) {
        choices <- c("Bütün məktəblər" = "", setNames(schools$id, schools$name))
        updateSelectInput(session, "school_select", choices = choices)
      }
      # Şagirdlər
      students <- db_query(db_pool,
        "SELECT s.id, s.first_name || ' ' || s.last_name || ' (' || c.grade || '-' || c.section || ')' as name
         FROM students s LEFT JOIN classes c ON s.class_id = c.id WHERE s.status = 'active' ORDER BY s.last_name")
      if (nrow(students) > 0) updateSelectizeInput(session, "student_select", choices = setNames(students$id, students$name), server = TRUE)
      # Müəllimlər
      teachers <- db_query(db_pool,
        "SELECT t.id, t.first_name || ' ' || t.last_name || ' — ' || COALESCE(sub.name, '') as name
         FROM teachers t LEFT JOIN teacher_subjects ts ON ts.teacher_id = t.id AND ts.is_primary = TRUE
         LEFT JOIN subjects sub ON ts.subject_id = sub.id WHERE t.status = 'active' ORDER BY t.last_name")
      if (nrow(teachers) > 0) updateSelectizeInput(session, "teacher_select", choices = setNames(teachers$id, teachers$name), server = TRUE)
      # Rayonlar
      regions <- db_query(db_pool, "SELECT DISTINCT region FROM schools WHERE region IS NOT NULL ORDER BY region")
      if (nrow(regions) > 0) {
        updateSelectInput(session, "region_select", choices = c("Bütün rayonlar" = "", setNames(regions$region, regions$region)))
      }
    })

    # =============================================
    # HESABAT YARATMA
    # =============================================
    observeEvent(input$btn_generate, {
      rtype <- input$report_type

      # Validasiya
      if (rtype == "student" && is_empty(input$student_select)) {
        notify_warning("Şagird seçin."); return()
      }
      if (rtype == "teacher" && is_empty(input$teacher_select)) {
        notify_warning("Müəllim seçin."); return()
      }

      withProgress(message = "Hesabat yaradılır...", value = 0.1, {
        # 1) DB-dən data çək
        setProgress(0.2, detail = "Məlumatlar toplanır...")
        data <- collect_report_data(db_pool, rtype, input)
        report_data(data)

        # 2) Claude AI xülasə yaz
        setProgress(0.5, detail = "AI xülasə hazırlanır...")
        summary <- generate_ai_summary(data, rtype, input)
        ai_summary_val(summary)

        # 3) Qrafik datası
        setProgress(0.8, detail = "Qrafiklər yaradılır...")
        chart_data(data)

        setProgress(1.0, detail = "Tamamlandı!")
      })

      notify_success("Hesabat uğurla yaradıldı!")
    })

    # =============================================
    # AI XÜLASƏ RENDERİ
    # =============================================
    output$summary_badge <- renderUI({
      sm <- ai_summary_val()
      if (is.null(sm)) return(NULL)
      tags$span(class = "badge", style = "background:#3498db; color:#fff; font-size:12px;",
        paste("AI |", format(Sys.time(), "%d.%m.%Y %H:%M")))
    })

    output$ai_summary <- renderUI({
      sm <- ai_summary_val()
      if (is.null(sm)) {
        return(tags$p(style = "color:#888;", "Hesabat yaratmaq üçün yuxarıdakı \"Hesabatı Yarat\" düyməsini basın."))
      }
      tags$div(
        style = "background: linear-gradient(135deg, #f8f9fa, #e9ecef); padding:16px; border-radius:10px; border-left:4px solid #3498db;",
        HTML(sm$summary_html)
      )
    })

    # =============================================
    # KPI KARTLARI
    # =============================================
    output$kpi_cards <- renderUI({
      sm <- ai_summary_val()
      if (is.null(sm) || is.null(sm$kpis)) return(NULL)
      kpis <- sm$kpis
      make_kpi <- function(label, value, icon_name, color) {
        column(3, div(style = sprintf("text-align:center; padding:12px; background:%s15; border-radius:10px; border:1px solid %s30;", color, color),
          icon(icon_name, style = sprintf("font-size:24px; color:%s;", color)),
          h2(style = sprintf("color:%s; margin:4px 0;", color), value),
          tags$small(label)
        ))
      }
      fluidRow(
        make_kpi(kpis$kpi1_label %||% "Orta Bal",      kpis$kpi1_value %||% "—", "chart-line",     "#2980b9"),
        make_kpi(kpis$kpi2_label %||% "Davamiyyət",     kpis$kpi2_value %||% "—", "calendar-check", "#27ae60"),
        make_kpi(kpis$kpi3_label %||% "Şagird Sayı",    kpis$kpi3_value %||% "—", "users",          "#8e44ad"),
        make_kpi(kpis$kpi4_label %||% "Hədəf Faizi",    kpis$kpi4_value %||% "—", "bullseye",       "#e67e22")
      )
    })

    # =============================================
    # QRAFİKLƏR
    # =============================================
    output$chart_performance <- renderPlotly({
      d <- chart_data()
      if (is.null(d) || is.null(d$performance)) return(plotly_empty() %>% layout(title = "Data yoxdur"))
      perf <- d$performance
      plot_ly(perf, x = ~label, y = ~value, type = "bar",
              marker = list(color = ~ifelse(value >= 71, "#27ae60", ifelse(value >= 51, "#f39c12", "#e74c3c")))) %>%
        layout(title = "Performans", xaxis = list(title = ""), yaxis = list(title = "Orta bal", range = c(0, 100)),
               plot_bgcolor = "rgba(0,0,0,0)", paper_bgcolor = "rgba(0,0,0,0)")
    })

    output$chart_distribution <- renderPlotly({
      d <- chart_data()
      if (is.null(d) || is.null(d$distribution)) return(plotly_empty() %>% layout(title = "Data yoxdur"))
      dist <- d$distribution
      colors <- c("#27ae60", "#2980b9", "#f39c12", "#e74c3c")
      plot_ly(dist, labels = ~label, values = ~count, type = "pie",
              marker = list(colors = colors[1:nrow(dist)])) %>%
        layout(title = "Qiymət Paylanması")
    })

    output$chart_trend <- renderPlotly({
      d <- chart_data()
      if (is.null(d) || is.null(d$trend)) return(plotly_empty() %>% layout(title = "Data yoxdur"))
      tr <- d$trend
      plot_ly(tr, x = ~period, y = ~value, type = "scatter", mode = "lines+markers",
              line = list(color = "#3498db", width = 3), marker = list(size = 8)) %>%
        layout(title = "Trend", xaxis = list(title = ""), yaxis = list(title = "Orta bal"),
               plot_bgcolor = "rgba(0,0,0,0)", paper_bgcolor = "rgba(0,0,0,0)")
    })

    output$chart_comparison <- renderPlotly({
      d <- chart_data()
      if (is.null(d) || is.null(d$comparison)) return(plotly_empty() %>% layout(title = "Data yoxdur"))
      cmp <- d$comparison
      plot_ly(cmp, x = ~label, y = ~value1, name = "Cari dövr", type = "bar",
              marker = list(color = "#3498db")) %>%
        add_trace(y = ~value2, name = "Əvvəlki dövr", marker = list(color = "#95a5a6")) %>%
        layout(title = "Müqayisə", barmode = "group",
               xaxis = list(title = ""), yaxis = list(title = "Bal"),
               plot_bgcolor = "rgba(0,0,0,0)", paper_bgcolor = "rgba(0,0,0,0)")
    })

    # =============================================
    # DETALLI CƏDVƏL
    # =============================================
    output$detail_table <- renderDT({
      d <- report_data()
      if (is.null(d) || is.null(d$detail_table)) {
        return(datatable(data.frame(Mesaj = "Hesabat yaradılmayıb"), options = list(dom = "t")))
      }
      datatable(d$detail_table, options = default_dt_options(25), rownames = FALSE,
                escape = FALSE, class = "display compact") %>%
        formatStyle(columns = names(d$detail_table), fontSize = "13px")
    })

    # =============================================
    # WORD YÜKLƏ
    # =============================================
    output$btn_download_word <- downloadHandler(
      filename = function() {
        paste0("ARTI_", input$report_type, "_", format(Sys.Date(), "%Y%m%d"), ".docx")
      },
      content = function(file) {
        d  <- report_data()
        sm <- ai_summary_val()
        if (is.null(d)) { notify_warning("Əvvəlcə hesabat yaradın."); return() }

        tryCatch({
          rmd_content <- build_report_rmd(d, sm, input, format = "word")
          tmp_rmd <- tempfile(fileext = ".Rmd")
          writeLines(rmd_content, tmp_rmd, useBytes = TRUE)

          # Plotly qrafiklər PNG kimi
          chart_files <- save_charts_as_png(d)

          rmarkdown::render(tmp_rmd, output_format = rmarkdown::word_document(
            toc = TRUE, toc_depth = 2
          ), output_file = file, envir = new.env(parent = globalenv()), quiet = TRUE)

          # Temp fayl təmizliyi
          unlink(tmp_rmd)
          unlink(chart_files)
        }, error = function(e) {
          # Fallback: openxlsx
          logger::log_warn("Word xətası: {e$message}, Excel fallback")
          generate_excel_report(d, sm, file)
        })
      }
    )

    # =============================================
    # PDF YÜKLƏ
    # =============================================
    output$btn_download_pdf <- downloadHandler(
      filename = function() {
        paste0("ARTI_", input$report_type, "_", format(Sys.Date(), "%Y%m%d"), ".pdf")
      },
      content = function(file) {
        d  <- report_data()
        sm <- ai_summary_val()
        if (is.null(d)) { notify_warning("Əvvəlcə hesabat yaradın."); return() }

        tryCatch({
          rmd_content <- build_report_rmd(d, sm, input, format = "pdf")
          tmp_rmd <- tempfile(fileext = ".Rmd")
          writeLines(rmd_content, tmp_rmd, useBytes = TRUE)
          chart_files <- save_charts_as_png(d)

          rmarkdown::render(tmp_rmd, output_format = rmarkdown::pdf_document(
            toc = TRUE, toc_depth = 2, latex_engine = "xelatex"
          ), output_file = file, envir = new.env(parent = globalenv()), quiet = TRUE)

          unlink(tmp_rmd)
          unlink(chart_files)
        }, error = function(e) {
          # Fallback: HTML
          logger::log_warn("PDF xətası: {e$message}, HTML fallback")
          html_content <- build_report_html(d, sm, input)
          writeLines(html_content, file)
        })
      }
    )

    # =============================================
    # EXCEL YÜKLƏ
    # =============================================
    output$btn_download_excel <- downloadHandler(
      filename = function() {
        paste0("ARTI_", input$report_type, "_", format(Sys.Date(), "%Y%m%d"), ".xlsx")
      },
      content = function(file) {
        d  <- report_data()
        sm <- ai_summary_val()
        if (is.null(d)) { notify_warning("Əvvəlcə hesabat yaradın."); return() }
        generate_excel_report(d, sm, file)
      }
    )

    # =============================================
    # PLANLANMIŞ HESABATLAR
    # =============================================
    scheduled <- reactiveVal(data.frame(
      Hesabat = character(), Format = character(), Tezlik = character(),
      Epoct = character(), Novbeti = character(), stringsAsFactors = FALSE
    ))

    observeEvent(input$btn_schedule, {
      if (is_empty(input$sched_email) || !validate_email(input$sched_email)) {
        notify_warning("Düzgün e-poçt ünvanı daxil edin."); return()
      }
      type_labels <- c(monthly = "Aylıq İcmal", quarterly = "Rüblük", annual = "İllik")
      format_labels <- c(docx = "Word", pdf = "PDF", xlsx = "Excel")
      freq_labels <- c(monthly = "Aylıq", quarterly = "Rüblük", annual = "İllik")

      new_row <- data.frame(
        Hesabat  = type_labels[input$sched_type],
        Format   = format_labels[input$sched_format],
        Tezlik   = freq_labels[input$sched_type],
        Epoct    = input$sched_email,
        Novbeti  = format(Sys.Date() + 30, "%d.%m.%Y"),
        stringsAsFactors = FALSE
      )
      scheduled(rbind(scheduled(), new_row))
      notify_success("Hesabat planlandı!")
    })

    output$scheduled_reports <- renderDT({
      datatable(scheduled(), options = list(pageLength = 5, dom = "t", language = list(
        emptyTable = "Planlanmış hesabat yoxdur"
      )), rownames = FALSE)
    })

  }) # moduleServer
}

# =============================================
# DATA TOPLAMA FUNKSİYALARI
# =============================================

#' Hesabat üçün DB-dən data topla
#' @param db_pool DB pool
#' @param rtype Hesabat növü
#' @param input Shiny input
#' @return list — report data
collect_report_data <- function(db_pool, rtype, input) {
  ay <- input$academic_year %||% "2025-2026"
  date_range <- get_report_date_range(rtype, input)

  switch(rtype,
    "monthly"   = collect_monthly_data(db_pool, date_range, ay, input$school_select),
    "quarterly" = collect_quarterly_data(db_pool, date_range, ay, input$school_select),
    "annual"    = collect_annual_data(db_pool, ay, input$school_select),
    "student"   = collect_student_data(db_pool, input$student_select, ay),
    "teacher"   = collect_teacher_data(db_pool, input$teacher_select, ay),
    "school"    = collect_school_data(db_pool, input$school_select, ay),
    "district"  = collect_district_data(db_pool, input$region_select, ay),
    list(title = "Naməlum hesabat növü", detail_table = data.frame())
  )
}

#' Tarix aralığı hesabla
get_report_date_range <- function(rtype, input) {
  year <- as.integer(substr(input$academic_year %||% "2025-2026", 1, 4))
  if (rtype == "monthly") {
    m <- as.integer(input$month_select %||% format(Sys.Date(), "%m"))
    y <- if (m >= 9) year else year + 1
    start <- as.Date(sprintf("%d-%02d-01", y, m))
    end <- as.Date(paste0(format(start + 31, "%Y-%m"), "-01")) - 1
    list(start = start, end = end)
  } else if (rtype == "quarterly") {
    q <- input$quarter_select %||% "Q1"
    quarters <- list(
      Q1 = list(start = as.Date(sprintf("%d-09-01", year)),     end = as.Date(sprintf("%d-11-30", year))),
      Q2 = list(start = as.Date(sprintf("%d-12-01", year)),     end = as.Date(sprintf("%d-02-28", year + 1))),
      Q3 = list(start = as.Date(sprintf("%d-03-01", year + 1)), end = as.Date(sprintf("%d-05-31", year + 1))),
      Q4 = list(start = as.Date(sprintf("%d-06-01", year + 1)), end = as.Date(sprintf("%d-08-31", year + 1)))
    )
    quarters[[q]]
  } else {
    list(start = as.Date(sprintf("%d-09-01", year)), end = as.Date(sprintf("%d-08-31", year + 1)))
  }
}

# ---- AYLIK ----
collect_monthly_data <- function(db_pool, date_range, ay, school_id) {
  school_filter <- if (!is_empty(school_id)) "AND s.school_id = $3" else ""
  params_base <- list(date_range$start, date_range$end)
  if (!is_empty(school_id)) params_base <- c(params_base, list(school_id))

  # Ümumi statistika
  stats <- db_query(db_pool, sprintf(
    "SELECT COUNT(DISTINCT s.id) as student_count,
            COALESCE(AVG(g.score), 0) as avg_score,
            COALESCE(MIN(g.score), 0) as min_score,
            COALESCE(MAX(g.score), 0) as max_score
     FROM students s
     LEFT JOIN grades g ON g.student_id = s.id AND g.grade_date BETWEEN $1 AND $2
     WHERE s.status = 'active' %s", school_filter), params = params_base)

  # Fənn üzrə ortalama
  subjects <- db_query(db_pool, sprintf(
    "SELECT sub.name as label, ROUND(AVG(g.score)::numeric, 1) as value
     FROM grades g JOIN subjects sub ON g.subject_id = sub.id
     JOIN students s ON g.student_id = s.id
     WHERE g.grade_date BETWEEN $1 AND $2 %s
     GROUP BY sub.name ORDER BY value DESC", school_filter), params = params_base)

  # Davamiyyət
  att <- db_query(db_pool, sprintf(
    "SELECT a.status, COUNT(*) as count
     FROM attendance a JOIN students s ON a.student_id = s.id
     WHERE a.attendance_date BETWEEN $1 AND $2 AND s.status = 'active' %s
     GROUP BY a.status", school_filter), params = params_base)

  # Qiymət paylanması
  dist <- db_query(db_pool, sprintf(
    "SELECT CASE WHEN g.score >= 86 THEN 'Əla'
                 WHEN g.score >= 71 THEN 'Yaxşı'
                 WHEN g.score >= 51 THEN 'Kafi'
                 ELSE 'Qeyri-kafi' END as label,
            COUNT(*) as count
     FROM grades g JOIN students s ON g.student_id = s.id
     WHERE g.grade_date BETWEEN $1 AND $2 %s
     GROUP BY 1 ORDER BY MIN(g.score) DESC", school_filter), params = params_base)

  # Həftəlik trend
  trend <- db_query(db_pool, sprintf(
    "SELECT DATE_TRUNC('week', g.grade_date)::date as period, ROUND(AVG(g.score)::numeric, 1) as value
     FROM grades g JOIN students s ON g.student_id = s.id
     WHERE g.grade_date BETWEEN $1 AND $2 %s
     GROUP BY 1 ORDER BY 1", school_filter), params = params_base)

  # Detallı cədvəl: sinif üzrə icmal
  detail <- db_query(db_pool, sprintf(
    "SELECT c.grade || '-' || c.section as \"Sinif\",
            COUNT(DISTINCT s.id) as \"Şagird sayı\",
            ROUND(AVG(g.score)::numeric, 1) as \"Orta bal\",
            ROUND(MIN(g.score)::numeric, 1) as \"Min bal\",
            ROUND(MAX(g.score)::numeric, 1) as \"Maks bal\"
     FROM classes c
     JOIN students s ON s.class_id = c.id AND s.status = 'active'
     LEFT JOIN grades g ON g.student_id = s.id AND g.grade_date BETWEEN $1 AND $2
     WHERE c.academic_year = '%s' %s
     GROUP BY c.grade, c.section ORDER BY c.grade, c.section",
    ay, gsub("s\\.school_id", "c.school_id", school_filter)), params = params_base)

  # Əvvəlki ayın datası — müqayisə üçün
  prev_start <- as.Date(format(date_range$start - 15, "%Y-%m-01"))
  prev_end   <- date_range$start - 1
  prev_params <- list(prev_start, prev_end)
  if (!is_empty(school_id)) prev_params <- c(prev_params, list(school_id))

  prev_subjects <- db_query(db_pool, sprintf(
    "SELECT sub.name as label, ROUND(AVG(g.score)::numeric, 1) as value
     FROM grades g JOIN subjects sub ON g.subject_id = sub.id
     JOIN students s ON g.student_id = s.id
     WHERE g.grade_date BETWEEN $1 AND $2 %s
     GROUP BY sub.name", school_filter), params = prev_params)

  # Müqayisə data
  comparison <- if (nrow(subjects) > 0 && nrow(prev_subjects) > 0) {
    merged <- merge(subjects, prev_subjects, by = "label", all.x = TRUE, suffixes = c("1", "2"))
    names(merged) <- c("label", "value1", "value2")
    merged$value2[is.na(merged$value2)] <- 0
    merged
  } else {
    data.frame(label = character(), value1 = numeric(), value2 = numeric())
  }

  list(
    title = sprintf("Aylıq İcmal Hesabatı — %s", format(date_range$start, "%B %Y")),
    report_type = "monthly",
    date_range = date_range,
    stats = stats,
    attendance = att,
    performance = subjects,
    distribution = dist,
    trend = trend,
    comparison = comparison,
    detail_table = detail
  )
}

# ---- RÜBLÜK ----
collect_quarterly_data <- function(db_pool, date_range, ay, school_id) {
  # Aylıq ilə eyni strukturda, amma rüb aralığında
  data <- collect_monthly_data(db_pool, date_range, ay, school_id)
  data$title <- sprintf("Rüblük Hesabat — %s / %s", format(date_range$start, "%d.%m.%Y"), format(date_range$end, "%d.%m.%Y"))
  data$report_type <- "quarterly"

  # Aylıq trend
  trend <- db_query(db_pool, sprintf(
    "SELECT DATE_TRUNC('month', g.grade_date)::date as period, ROUND(AVG(g.score)::numeric, 1) as value
     FROM grades g JOIN students s ON g.student_id = s.id
     WHERE g.grade_date BETWEEN $1 AND $2 AND s.status = 'active'
     GROUP BY 1 ORDER BY 1"), params = list(date_range$start, date_range$end))
  if (nrow(trend) > 0) data$trend <- trend

  data
}

# ---- İLLİK ----
collect_annual_data <- function(db_pool, ay, school_id) {
  school_filter <- if (!is_empty(school_id)) "AND s.school_id = $2" else ""
  params <- list(ay)
  if (!is_empty(school_id)) params <- c(params, list(school_id))

  stats <- db_query(db_pool, sprintf(
    "SELECT COUNT(DISTINCT s.id) as student_count,
            COALESCE(ROUND(AVG(g.score)::numeric, 1), 0) as avg_score,
            COUNT(DISTINCT t.id) as teacher_count,
            COUNT(DISTINCT sch.id) as school_count
     FROM students s
     LEFT JOIN grades g ON g.student_id = s.id AND g.academic_year = $1
     LEFT JOIN classes c ON s.class_id = c.id AND c.academic_year = $1
     LEFT JOIN schools sch ON s.school_id = sch.id
     LEFT JOIN teachers t ON t.school_id = sch.id AND t.status = 'active'
     WHERE s.status = 'active' %s", school_filter), params = params)

  # Fənn performans
  subjects <- db_query(db_pool, sprintf(
    "SELECT sub.name as label, ROUND(AVG(g.score)::numeric, 1) as value
     FROM grades g JOIN subjects sub ON g.subject_id = sub.id
     JOIN students s ON g.student_id = s.id
     WHERE g.academic_year = $1 AND s.status = 'active' %s
     GROUP BY sub.name ORDER BY value DESC", school_filter), params = params)

  # Qiymət paylanması
  dist <- db_query(db_pool, sprintf(
    "SELECT CASE WHEN g.score >= 86 THEN 'Əla' WHEN g.score >= 71 THEN 'Yaxşı'
                 WHEN g.score >= 51 THEN 'Kafi' ELSE 'Qeyri-kafi' END as label,
            COUNT(*) as count
     FROM grades g JOIN students s ON g.student_id = s.id
     WHERE g.academic_year = $1 AND s.status = 'active' %s
     GROUP BY 1 ORDER BY MIN(g.score) DESC", school_filter), params = params)

  # Aylıq trend
  year <- as.integer(substr(ay, 1, 4))
  trend <- db_query(db_pool, sprintf(
    "SELECT DATE_TRUNC('month', g.grade_date)::date as period, ROUND(AVG(g.score)::numeric, 1) as value
     FROM grades g JOIN students s ON g.student_id = s.id
     WHERE g.academic_year = $1 AND s.status = 'active' %s
     GROUP BY 1 ORDER BY 1", school_filter), params = params)

  # Əvvəlki il müqayisə
  prev_ay <- paste0(year - 1, "-", year)
  prev_params <- list(prev_ay)
  if (!is_empty(school_id)) prev_params <- c(prev_params, list(school_id))
  prev_subjects <- db_query(db_pool, sprintf(
    "SELECT sub.name as label, ROUND(AVG(g.score)::numeric, 1) as value
     FROM grades g JOIN subjects sub ON g.subject_id = sub.id
     JOIN students s ON g.student_id = s.id
     WHERE g.academic_year = $1 AND s.status = 'active' %s
     GROUP BY sub.name", school_filter), params = prev_params)

  comparison <- if (nrow(subjects) > 0 && nrow(prev_subjects) > 0) {
    merged <- merge(subjects, prev_subjects, by = "label", all.x = TRUE, suffixes = c("1", "2"))
    names(merged) <- c("label", "value1", "value2")
    merged$value2[is.na(merged$value2)] <- 0
    merged
  } else {
    data.frame(label = character(), value1 = numeric(), value2 = numeric())
  }

  # Detallı cədvəl: məktəb icmalı
  detail <- db_query(db_pool, sprintf(
    "SELECT sch.name as \"Məktəb\",
            COUNT(DISTINCT s.id) as \"Şagird\",
            COUNT(DISTINCT t.id) as \"Müəllim\",
            ROUND(AVG(g.score)::numeric, 1) as \"Orta bal\",
            ROUND((SUM(CASE WHEN g.score >= 51 THEN 1 ELSE 0 END)::numeric / NULLIF(COUNT(g.id), 0) * 100)::numeric, 1) as \"Keçid %%\"
     FROM schools sch
     LEFT JOIN students s ON s.school_id = sch.id AND s.status = 'active'
     LEFT JOIN teachers t ON t.school_id = sch.id AND t.status = 'active'
     LEFT JOIN grades g ON g.student_id = s.id AND g.academic_year = $1
     WHERE sch.status = 'active' %s
     GROUP BY sch.name ORDER BY \"Orta bal\" DESC NULLS LAST",
    gsub("s\\.school_id", "sch.id", school_filter)), params = params)

  list(
    title = sprintf("İllik Hesabat — %s", ay), report_type = "annual",
    stats = stats, performance = subjects, distribution = dist,
    trend = trend, comparison = comparison, detail_table = detail
  )
}

# ---- FƏRDİ ŞAGİRD ----
collect_student_data <- function(db_pool, student_id, ay) {
  # Şagird məlumatları
  student <- db_get_one(db_pool,
    "SELECT s.first_name, s.last_name, s.father_name, s.birth_date,
            c.grade, c.section, sch.name as school_name
     FROM students s
     LEFT JOIN classes c ON s.class_id = c.id
     LEFT JOIN schools sch ON s.school_id = sch.id
     WHERE s.id = $1", params = list(student_id))

  # Fənn qiymətləri
  subjects <- db_query(db_pool,
    "SELECT sub.name as label, ROUND(AVG(g.score)::numeric, 1) as value
     FROM grades g JOIN subjects sub ON g.subject_id = sub.id
     WHERE g.student_id = $1 AND g.academic_year = $2
     GROUP BY sub.name ORDER BY value DESC",
    params = list(student_id, ay))

  # Davamiyyət
  att <- db_query(db_pool,
    "SELECT a.status, COUNT(*) as count FROM attendance a
     WHERE a.student_id = $1
     AND a.attendance_date >= (SELECT MIN(g.grade_date) FROM grades g WHERE g.academic_year = $2)
     GROUP BY a.status", params = list(student_id, ay))

  # Qiymət paylanması
  dist <- db_query(db_pool,
    "SELECT CASE WHEN g.score >= 86 THEN 'Əla' WHEN g.score >= 71 THEN 'Yaxşı'
                 WHEN g.score >= 51 THEN 'Kafi' ELSE 'Qeyri-kafi' END as label,
            COUNT(*) as count
     FROM grades g WHERE g.student_id = $1 AND g.academic_year = $2
     GROUP BY 1 ORDER BY MIN(g.score) DESC",
    params = list(student_id, ay))

  # Aylıq trend
  trend <- db_query(db_pool,
    "SELECT DATE_TRUNC('month', g.grade_date)::date as period, ROUND(AVG(g.score)::numeric, 1) as value
     FROM grades g WHERE g.student_id = $1 AND g.academic_year = $2
     GROUP BY 1 ORDER BY 1", params = list(student_id, ay))

  # Sinif ortası ilə müqayisə
  class_avg <- if (!is.null(student)) {
    db_query(db_pool,
      "SELECT sub.name as label,
              ROUND(AVG(CASE WHEN g.student_id = $1 THEN g.score END)::numeric, 1) as value1,
              ROUND(AVG(g.score)::numeric, 1) as value2
       FROM grades g JOIN subjects sub ON g.subject_id = sub.id
       JOIN students s ON g.student_id = s.id
       JOIN classes c ON s.class_id = c.id
       WHERE c.grade = $3 AND c.section = $4 AND g.academic_year = $2
       GROUP BY sub.name",
      params = list(student_id, ay, student$grade %||% 1, student$section %||% "A"))
  } else data.frame()

  # Detallı qiymət cədvəli
  detail <- db_query(db_pool,
    "SELECT sub.name as \"Fənn\", g.grade_type as \"Növ\",
            g.score as \"Bal\", g.grade_date as \"Tarix\",
            COALESCE(g.comments, '') as \"Qeyd\"
     FROM grades g JOIN subjects sub ON g.subject_id = sub.id
     WHERE g.student_id = $1 AND g.academic_year = $2
     ORDER BY g.grade_date DESC",
    params = list(student_id, ay))

  name <- if (!is.null(student)) paste(student$first_name, student$last_name) else "Naməlum"

  list(
    title = sprintf("Fərdi Şagird Hesabatı — %s", name),
    report_type = "student", student = student,
    stats = data.frame(student_count = 1,
      avg_score = if (nrow(subjects) > 0) round(mean(subjects$value, na.rm = TRUE), 1) else 0),
    performance = subjects, distribution = dist, trend = trend,
    comparison = if (nrow(class_avg) > 0) class_avg else data.frame(label = character(), value1 = numeric(), value2 = numeric()),
    attendance = att, detail_table = detail
  )
}

# ---- FƏRDİ MÜƏLLİM ----
collect_teacher_data <- function(db_pool, teacher_id, ay) {
  teacher <- db_get_one(db_pool,
    "SELECT t.first_name, t.last_name, t.category, t.experience_years,
            sch.name as school_name
     FROM teachers t LEFT JOIN schools sch ON t.school_id = sch.id
     WHERE t.id = $1", params = list(teacher_id))

  # Tədris etdiyi siniflərin performansı
  classes <- db_query(db_pool,
    "SELECT c.grade || '-' || c.section as label,
            ROUND(AVG(g.score)::numeric, 1) as value
     FROM grades g JOIN classes c ON g.class_id = c.id
     WHERE g.teacher_id = $1 AND g.academic_year = $2
     GROUP BY c.grade, c.section ORDER BY c.grade, c.section",
    params = list(teacher_id, ay))

  # Fənn üzrə orta
  subjects <- db_query(db_pool,
    "SELECT sub.name as label, ROUND(AVG(g.score)::numeric, 1) as value
     FROM grades g JOIN subjects sub ON g.subject_id = sub.id
     WHERE g.teacher_id = $1 AND g.academic_year = $2
     GROUP BY sub.name ORDER BY value DESC",
    params = list(teacher_id, ay))

  # Qiymət paylanması
  dist <- db_query(db_pool,
    "SELECT CASE WHEN g.score >= 86 THEN 'Əla' WHEN g.score >= 71 THEN 'Yaxşı'
                 WHEN g.score >= 51 THEN 'Kafi' ELSE 'Qeyri-kafi' END as label,
            COUNT(*) as count
     FROM grades g WHERE g.teacher_id = $1 AND g.academic_year = $2
     GROUP BY 1 ORDER BY MIN(g.score) DESC",
    params = list(teacher_id, ay))

  # Aylıq trend
  trend <- db_query(db_pool,
    "SELECT DATE_TRUNC('month', g.grade_date)::date as period, ROUND(AVG(g.score)::numeric, 1) as value
     FROM grades g WHERE g.teacher_id = $1 AND g.academic_year = $2
     GROUP BY 1 ORDER BY 1", params = list(teacher_id, ay))

  # Müəllimin qiymətləndirmə balları
  eval_data <- db_query(db_pool,
    "SELECT evaluation_date, overall_score, teaching_quality, student_engagement
     FROM teacher_evaluations WHERE teacher_id = $1
     ORDER BY evaluation_date DESC LIMIT 5", params = list(teacher_id))

  name <- if (!is.null(teacher)) paste(teacher$first_name, teacher$last_name) else "Naməlum"

  # Detallı cədvəl
  detail <- db_query(db_pool,
    "SELECT c.grade || '-' || c.section as \"Sinif\", sub.name as \"Fənn\",
            COUNT(DISTINCT s.id) as \"Şagird\",
            ROUND(AVG(g.score)::numeric, 1) as \"Orta bal\",
            ROUND((SUM(CASE WHEN g.score >= 51 THEN 1 ELSE 0 END)::numeric / NULLIF(COUNT(g.id), 0) * 100)::numeric, 1) as \"Keçid %%\"
     FROM grades g JOIN classes c ON g.class_id = c.id
     JOIN subjects sub ON g.subject_id = sub.id
     JOIN students s ON g.student_id = s.id
     WHERE g.teacher_id = $1 AND g.academic_year = $2
     GROUP BY c.grade, c.section, sub.name
     ORDER BY c.grade, c.section",
    params = list(teacher_id, ay))

  list(
    title = sprintf("Müəllim Hesabatı — %s", name),
    report_type = "teacher", teacher = teacher,
    stats = data.frame(
      student_count = if (nrow(detail) > 0) sum(detail[["Şagird"]], na.rm = TRUE) else 0,
      avg_score = if (nrow(subjects) > 0) round(mean(subjects$value, na.rm = TRUE), 1) else 0),
    performance = if (nrow(classes) > 0) classes else subjects,
    distribution = dist, trend = trend,
    comparison = data.frame(label = character(), value1 = numeric(), value2 = numeric()),
    evaluations = eval_data, detail_table = detail
  )
}

# ---- MƏKTƏB ----
collect_school_data <- function(db_pool, school_id, ay) {
  if (is_empty(school_id)) {
    return(collect_annual_data(db_pool, ay, school_id = ""))
  }

  school <- db_get_one(db_pool, "SELECT * FROM schools WHERE id = $1", params = list(school_id))

  stats <- db_query(db_pool,
    "SELECT COUNT(DISTINCT s.id) as student_count,
            COALESCE(ROUND(AVG(g.score)::numeric, 1), 0) as avg_score,
            COUNT(DISTINCT t.id) as teacher_count
     FROM students s
     LEFT JOIN grades g ON g.student_id = s.id AND g.academic_year = $2
     LEFT JOIN teachers t ON t.school_id = $1 AND t.status = 'active'
     WHERE s.school_id = $1 AND s.status = 'active'",
    params = list(school_id, ay))

  subjects <- db_query(db_pool,
    "SELECT sub.name as label, ROUND(AVG(g.score)::numeric, 1) as value
     FROM grades g JOIN subjects sub ON g.subject_id = sub.id
     JOIN students s ON g.student_id = s.id
     WHERE s.school_id = $1 AND g.academic_year = $2
     GROUP BY sub.name ORDER BY value DESC",
    params = list(school_id, ay))

  dist <- db_query(db_pool,
    "SELECT CASE WHEN g.score >= 86 THEN 'Əla' WHEN g.score >= 71 THEN 'Yaxşı'
                 WHEN g.score >= 51 THEN 'Kafi' ELSE 'Qeyri-kafi' END as label,
            COUNT(*) as count
     FROM grades g JOIN students s ON g.student_id = s.id
     WHERE s.school_id = $1 AND g.academic_year = $2
     GROUP BY 1 ORDER BY MIN(g.score) DESC",
    params = list(school_id, ay))

  trend <- db_query(db_pool,
    "SELECT DATE_TRUNC('month', g.grade_date)::date as period, ROUND(AVG(g.score)::numeric, 1) as value
     FROM grades g JOIN students s ON g.student_id = s.id
     WHERE s.school_id = $1 AND g.academic_year = $2
     GROUP BY 1 ORDER BY 1", params = list(school_id, ay))

  # Sinif üzrə detallı
  detail <- db_query(db_pool,
    "SELECT c.grade || '-' || c.section as \"Sinif\",
            COUNT(DISTINCT s.id) as \"Şagird\",
            ROUND(AVG(g.score)::numeric, 1) as \"Orta bal\",
            ROUND((SUM(CASE WHEN g.score >= 51 THEN 1 ELSE 0 END)::numeric / NULLIF(COUNT(g.id), 0) * 100)::numeric, 1) as \"Keçid %%\"
     FROM classes c
     JOIN students s ON s.class_id = c.id AND s.status = 'active'
     LEFT JOIN grades g ON g.student_id = s.id AND g.academic_year = $2
     WHERE c.school_id = $1 AND c.academic_year = $2
     GROUP BY c.grade, c.section ORDER BY c.grade, c.section",
    params = list(school_id, ay))

  list(
    title = sprintf("Məktəb Hesabatı — %s", school$name %||% "Seçilmiş Məktəb"),
    report_type = "school", school = school,
    stats = stats, performance = subjects, distribution = dist,
    trend = trend,
    comparison = data.frame(label = character(), value1 = numeric(), value2 = numeric()),
    detail_table = detail
  )
}

# ---- RAYON ----
collect_district_data <- function(db_pool, region, ay) {
  region_filter <- if (!is_empty(region)) "AND sch.region = $2" else ""
  params <- list(ay)
  if (!is_empty(region)) params <- c(params, list(region))

  stats <- db_query(db_pool, sprintf(
    "SELECT COUNT(DISTINCT sch.id) as school_count,
            COUNT(DISTINCT s.id) as student_count,
            COUNT(DISTINCT t.id) as teacher_count,
            COALESCE(ROUND(AVG(g.score)::numeric, 1), 0) as avg_score
     FROM schools sch
     LEFT JOIN students s ON s.school_id = sch.id AND s.status = 'active'
     LEFT JOIN teachers t ON t.school_id = sch.id AND t.status = 'active'
     LEFT JOIN grades g ON g.student_id = s.id AND g.academic_year = $1
     WHERE sch.status = 'active' %s", region_filter), params = params)

  # Məktəblər üzrə performans
  schools_perf <- db_query(db_pool, sprintf(
    "SELECT sch.name as label, ROUND(AVG(g.score)::numeric, 1) as value
     FROM schools sch
     JOIN students s ON s.school_id = sch.id AND s.status = 'active'
     JOIN grades g ON g.student_id = s.id AND g.academic_year = $1
     WHERE sch.status = 'active' %s
     GROUP BY sch.name ORDER BY value DESC", region_filter), params = params)

  # Aylıq trend
  trend <- db_query(db_pool, sprintf(
    "SELECT DATE_TRUNC('month', g.grade_date)::date as period, ROUND(AVG(g.score)::numeric, 1) as value
     FROM grades g JOIN students s ON g.student_id = s.id
     JOIN schools sch ON s.school_id = sch.id
     WHERE g.academic_year = $1 AND sch.status = 'active' %s
     GROUP BY 1 ORDER BY 1", region_filter), params = params)

  dist <- db_query(db_pool, sprintf(
    "SELECT CASE WHEN g.score >= 86 THEN 'Əla' WHEN g.score >= 71 THEN 'Yaxşı'
                 WHEN g.score >= 51 THEN 'Kafi' ELSE 'Qeyri-kafi' END as label,
            COUNT(*) as count
     FROM grades g JOIN students s ON g.student_id = s.id
     JOIN schools sch ON s.school_id = sch.id
     WHERE g.academic_year = $1 AND sch.status = 'active' %s
     GROUP BY 1 ORDER BY MIN(g.score) DESC", region_filter), params = params)

  # Detallı cədvəl: məktəb üzrə
  detail <- db_query(db_pool, sprintf(
    "SELECT sch.name as \"Məktəb\", sch.region as \"Rayon\",
            COUNT(DISTINCT s.id) as \"Şagird\",
            COUNT(DISTINCT t.id) as \"Müəllim\",
            ROUND(AVG(g.score)::numeric, 1) as \"Orta bal\",
            ROUND((SUM(CASE WHEN g.score >= 51 THEN 1 ELSE 0 END)::numeric / NULLIF(COUNT(g.id), 0) * 100)::numeric, 1) as \"Keçid %%\"
     FROM schools sch
     LEFT JOIN students s ON s.school_id = sch.id AND s.status = 'active'
     LEFT JOIN teachers t ON t.school_id = sch.id AND t.status = 'active'
     LEFT JOIN grades g ON g.student_id = s.id AND g.academic_year = $1
     WHERE sch.status = 'active' %s
     GROUP BY sch.name, sch.region ORDER BY \"Orta bal\" DESC NULLS LAST", region_filter), params = params)

  list(
    title = sprintf("Rayon Hesabatı — %s (%s)", if (is_empty(region)) "Bütün Rayonlar" else region, ay),
    report_type = "district",
    stats = stats, performance = schools_perf, distribution = dist,
    trend = trend,
    comparison = data.frame(label = character(), value1 = numeric(), value2 = numeric()),
    detail_table = detail
  )
}

# =============================================
# AI XÜLASƏ GENERASİYASI
# =============================================

#' Claude AI ilə hesabat xülasəsi yarat
generate_ai_summary <- function(data, rtype, input) {
  if (is.null(data)) return(NULL)

  # Kontekst hazırla
  context_parts <- c()
  context_parts <- c(context_parts, sprintf("Hesabat növü: %s", data$title))

  if (!is.null(data$stats) && nrow(data$stats) > 0) {
    s <- data$stats[1, ]
    if ("student_count" %in% names(s)) context_parts <- c(context_parts, sprintf("Şagird sayı: %s", s$student_count))
    if ("avg_score" %in% names(s))     context_parts <- c(context_parts, sprintf("Ümumi orta bal: %s", s$avg_score))
    if ("school_count" %in% names(s))  context_parts <- c(context_parts, sprintf("Məktəb sayı: %s", s$school_count))
    if ("teacher_count" %in% names(s)) context_parts <- c(context_parts, sprintf("Müəllim sayı: %s", s$teacher_count))
  }

  if (!is.null(data$performance) && nrow(data$performance) > 0) {
    top3 <- head(data$performance, 3)
    bot3 <- tail(data$performance, 3)
    context_parts <- c(context_parts,
      sprintf("Ən yaxşı fənnlər/kateqoriyalar: %s", paste(sprintf("%s (%s)", top3$label, top3$value), collapse = ", ")),
      sprintf("Ən zəif fənnlər/kateqoriyalar: %s", paste(sprintf("%s (%s)", bot3$label, bot3$value), collapse = ", "))
    )
  }

  if (!is.null(data$distribution) && nrow(data$distribution) > 0) {
    context_parts <- c(context_parts,
      sprintf("Qiymət paylanması: %s", paste(sprintf("%s: %s", data$distribution$label, data$distribution$count), collapse = ", "))
    )
  }

  if (!is.null(data$attendance) && nrow(data$attendance) > 0) {
    context_parts <- c(context_parts,
      sprintf("Davamiyyət: %s", paste(sprintf("%s: %s", data$attendance$status, data$attendance$count), collapse = ", "))
    )
  }

  if (!is.null(data$trend) && nrow(data$trend) > 0) {
    first_val <- data$trend$value[1]
    last_val  <- data$trend$value[nrow(data$trend)]
    diff_pct  <- round((last_val - first_val) / max(first_val, 1) * 100, 1)
    context_parts <- c(context_parts, sprintf("Trend: %s → %s (%s%%)", first_val, last_val, ifelse(diff_pct > 0, paste0("+", diff_pct), diff_pct)))
  }

  if (!is.null(data$detail_table) && nrow(data$detail_table) > 0) {
    context_parts <- c(context_parts, sprintf("Detallı sətir sayı: %d", nrow(data$detail_table)))
    # İlk 10 sətri göndər
    sample_rows <- utils::capture.output(print(head(data$detail_table, 10)))
    context_parts <- c(context_parts, "Detallı nümunə:", paste(sample_rows, collapse = "\n"))
  }

  context <- paste(context_parts, collapse = "\n")

  system_prompt <- "Sən ARTI-2026 Təhsil İdarəetmə Sisteminin hesabat analitikisisən.
Azərbaycan dilində, rəsmi hesabat üslubunda, konkret rəqəmlərlə xülasə hazırla.
Cavabını JSON formatında qaytar:
{
  \"summary_html\": \"<p>HTML formatında 3-5 abzaslıq xülasə (güclü tərəflər, problemlər, tövsiyələr)</p>\",
  \"kpis\": {
    \"kpi1_label\": \"...\", \"kpi1_value\": \"...\",
    \"kpi2_label\": \"...\", \"kpi2_value\": \"...\",
    \"kpi3_label\": \"...\", \"kpi3_value\": \"...\",
    \"kpi4_label\": \"...\", \"kpi4_value\": \"...\"
  },
  \"key_findings\": [\"tapıntı 1\", \"tapıntı 2\", \"tapıntı 3\"],
  \"recommendations\": [\"tövsiyə 1\", \"tövsiyə 2\", \"tövsiyə 3\"]
}"

  prompt <- sprintf(
    "Aşağıdakı təhsil hesabatı üçün ətraflı xülasə hazırla.\n\n%s\n\nKonkret rəqəmlər istifadə et. Hədəf: performans 71+, davamiyyət 90%%+, keçid faizi 85%%+.",
    context)

  result <- tryCatch(
    call_claude_api(prompt, system_prompt, max_tokens = 4096, temperature = 0.5),
    error = function(e) list(success = FALSE, message = e$message)
  )

  if (result$success) {
    parsed <- extract_json_from_response(result$message)
    if (!is.null(parsed)) {
      return(list(
        summary_html     = parsed$summary_html %||% result$message,
        kpis             = parsed$kpis,
        key_findings     = parsed$key_findings %||% list(),
        recommendations  = parsed$recommendations %||% list(),
        raw              = result$message
      ))
    }
    # JSON parse uğursuz — raw mətni HTML kimi göstər
    return(list(
      summary_html = gsub("\n", "<br>", result$message),
      kpis = NULL, key_findings = list(), recommendations = list(),
      raw = result$message
    ))
  }

  # API xətası — fallback xülasə
  fallback_summary <- generate_fallback_summary(data)
  list(
    summary_html = fallback_summary$html,
    kpis = fallback_summary$kpis,
    key_findings = list(), recommendations = list(), raw = ""
  )
}

#' AI əlçatan olmadıqda fallback xülasə
generate_fallback_summary <- function(data) {
  avg <- if (!is.null(data$stats) && "avg_score" %in% names(data$stats)) data$stats$avg_score[1] else 0
  count <- if (!is.null(data$stats) && "student_count" %in% names(data$stats)) data$stats$student_count[1] else 0
  label <- get_grade_label(avg)

  html <- sprintf(
    "<p><strong>%s</strong></p>
     <p>Hesabata <strong>%s</strong> şagird daxildir. Ümumi orta bal <strong>%s</strong> (%s) təşkil edir.</p>
     <p><em>Ətraflı AI xülasə üçün internet bağlantısını yoxlayın.</em></p>",
    data$title, format_number_az(count), round(avg, 1), label)

  kpis <- list(
    kpi1_label = "Orta Bal", kpi1_value = round(avg, 1),
    kpi2_label = "Şagird Sayı", kpi2_value = format_number_az(count),
    kpi3_label = "Qiymət", kpi3_value = label,
    kpi4_label = "Status", kpi4_value = if (avg >= 51) "Normal" else "Diqqət!"
  )

  list(html = html, kpis = kpis)
}

# =============================================
# QRAFİKLƏRİ PNG KIMI SAXLA (Word/PDF üçün)
# =============================================

#' Plotly qrafiklərini PNG kimi saxla
save_charts_as_png <- function(data) {
  files <- character()
  if (is.null(data)) return(files)

  tryCatch({
    if (!is.null(data$performance) && nrow(data$performance) > 0) {
      p <- ggplot2::ggplot(data$performance, ggplot2::aes(x = reorder(label, value), y = value)) +
        ggplot2::geom_col(fill = ifelse(data$performance$value >= 71, "#27ae60",
          ifelse(data$performance$value >= 51, "#f39c12", "#e74c3c"))) +
        ggplot2::coord_flip() + ggplot2::theme_minimal() +
        ggplot2::labs(title = "Performans", x = "", y = "Orta bal") +
        ggplot2::ylim(0, 100)
      f <- tempfile(pattern = "perf_", fileext = ".png")
      ggplot2::ggsave(f, p, width = 8, height = 5, dpi = 150)
      files <- c(files, f)
    }

    if (!is.null(data$distribution) && nrow(data$distribution) > 0) {
      p <- ggplot2::ggplot(data$distribution, ggplot2::aes(x = "", y = count, fill = label)) +
        ggplot2::geom_col(width = 1) + ggplot2::coord_polar("y") +
        ggplot2::scale_fill_manual(values = c("Əla" = "#27ae60", "Yaxşı" = "#2980b9", "Kafi" = "#f39c12", "Qeyri-kafi" = "#e74c3c")) +
        ggplot2::theme_void() + ggplot2::labs(title = "Qiymət Paylanması", fill = "")
      f <- tempfile(pattern = "dist_", fileext = ".png")
      ggplot2::ggsave(f, p, width = 6, height = 5, dpi = 150)
      files <- c(files, f)
    }
  }, error = function(e) {
    logger::log_warn("Qrafik PNG xətası: {e$message}")
  })

  files
}

# =============================================
# WORD HESABAT GENERASİYASI (Rmarkdown)
# =============================================

#' Rmarkdown mətni qur
build_report_rmd <- function(data, summary, input, format = "word") {
  title <- data$title %||% "ARTI-2026 Hesabat"
  date  <- format(Sys.time(), "%d.%m.%Y %H:%M")
  ay    <- input$academic_year %||% "2025-2026"

  # YAML header
  rmd <- sprintf('---
title: "%s"
subtitle: "ARTI-2026 Təhsil İdarəetmə Sistemi"
date: "%s"
output:
  %s:
    toc: true
    toc_depth: 2
---

', title, date, if (format == "word") "word_document" else "pdf_document")

  # Xülasə
  rmd <- paste0(rmd, "# Xülasə\n\n")
  if (!is.null(summary) && !is.null(summary$raw) && nchar(summary$raw) > 0) {
    # Markdown-a çevir (HTML teqlərini təmizlə)
    clean_summary <- gsub("<[^>]+>", "", summary$summary_html %||% summary$raw)
    clean_summary <- gsub("&nbsp;", " ", clean_summary)
    rmd <- paste0(rmd, clean_summary, "\n\n")
  }

  # KPI-lar
  if (!is.null(summary$kpis)) {
    k <- summary$kpis
    rmd <- paste0(rmd, "## Əsas Göstəricilər\n\n")
    rmd <- paste0(rmd, sprintf("| Göstərici | Dəyər |\n|---|---|\n| %s | %s |\n| %s | %s |\n| %s | %s |\n| %s | %s |\n\n",
      k$kpi1_label %||% "—", k$kpi1_value %||% "—",
      k$kpi2_label %||% "—", k$kpi2_value %||% "—",
      k$kpi3_label %||% "—", k$kpi3_value %||% "—",
      k$kpi4_label %||% "—", k$kpi4_value %||% "—"))
  }

  # Tapıntılar
  if (!is.null(summary$key_findings) && length(summary$key_findings) > 0) {
    rmd <- paste0(rmd, "## Əsas Tapıntılar\n\n")
    for (f in summary$key_findings) rmd <- paste0(rmd, "- ", f, "\n")
    rmd <- paste0(rmd, "\n")
  }

  # Tövsiyələr
  if (!is.null(summary$recommendations) && length(summary$recommendations) > 0) {
    rmd <- paste0(rmd, "## Tövsiyələr\n\n")
    for (r in summary$recommendations) rmd <- paste0(rmd, "- ", r, "\n")
    rmd <- paste0(rmd, "\n")
  }

  # Performans cədvəli
  if (!is.null(data$performance) && nrow(data$performance) > 0) {
    rmd <- paste0(rmd, "# Performans\n\n")
    perf <- data$performance
    rmd <- paste0(rmd, "| Kateqoriya | Orta Bal | Qiymət |\n|---|---|---|\n")
    for (i in seq_len(nrow(perf))) {
      rmd <- paste0(rmd, sprintf("| %s | %s | %s |\n", perf$label[i], perf$value[i], get_grade_label(perf$value[i])))
    }
    rmd <- paste0(rmd, "\n")
  }

  # Paylanma
  if (!is.null(data$distribution) && nrow(data$distribution) > 0) {
    rmd <- paste0(rmd, "# Qiymət Paylanması\n\n")
    rmd <- paste0(rmd, "| Kateqoriya | Say |\n|---|---|\n")
    for (i in seq_len(nrow(data$distribution))) {
      rmd <- paste0(rmd, sprintf("| %s | %s |\n", data$distribution$label[i], data$distribution$count[i]))
    }
    rmd <- paste0(rmd, "\n")
  }

  # Detallı cədvəl
  if (!is.null(data$detail_table) && nrow(data$detail_table) > 0) {
    rmd <- paste0(rmd, "# Detallı Məlumatlar\n\n")
    cols <- names(data$detail_table)
    rmd <- paste0(rmd, "| ", paste(cols, collapse = " | "), " |\n")
    rmd <- paste0(rmd, "|", paste(rep("---", length(cols)), collapse = "|"), "|\n")
    for (i in seq_len(min(nrow(data$detail_table), 50))) {
      row_vals <- sapply(data$detail_table[i, ], function(v) if (is.na(v)) "—" else as.character(v))
      rmd <- paste0(rmd, "| ", paste(row_vals, collapse = " | "), " |\n")
    }
    rmd <- paste0(rmd, "\n")
  }

  # Alt bilgi
  rmd <- paste0(rmd, "\n---\n\n*Bu hesabat ARTI-2026 Təhsil İdarəetmə Sistemi tərəfindən avtomatik yaradılmışdır.*\n")
  rmd <- paste0(rmd, sprintf("\n*Tarix: %s | Tədris ili: %s*\n", date, ay))

  rmd
}

# =============================================
# HTML HESABAT (PDF fallback)
# =============================================

#' Standalone HTML hesabat yarat
build_report_html <- function(data, summary, input) {
  title <- data$title %||% "ARTI-2026 Hesabat"
  date  <- format(Sys.time(), "%d.%m.%Y %H:%M")

  html <- sprintf('<!DOCTYPE html>
<html lang="az">
<head>
<meta charset="UTF-8">
<title>%s</title>
<style>
  body { font-family: "Segoe UI", Arial, sans-serif; max-width: 900px; margin: 0 auto; padding: 20px; color: #2c3e50; }
  h1 { color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 8px; }
  h2 { color: #34495e; border-bottom: 1px solid #bdc3c7; padding-bottom: 4px; }
  .header { text-align: center; margin-bottom: 30px; }
  .logo { font-size: 28px; font-weight: bold; color: #2c3e50; }
  .kpi-row { display: flex; gap: 16px; margin: 20px 0; }
  .kpi { flex: 1; text-align: center; padding: 16px; border-radius: 10px; background: #f8f9fa; border: 1px solid #dee2e6; }
  .kpi h3 { margin: 0; font-size: 28px; color: #2980b9; }
  .kpi small { color: #7f8c8d; }
  .summary { background: linear-gradient(135deg, #f8f9fa, #e9ecef); padding: 20px; border-radius: 10px; border-left: 4px solid #3498db; margin: 20px 0; }
  table { width: 100%%; border-collapse: collapse; margin: 16px 0; }
  th { background: #2c3e50; color: white; padding: 10px; text-align: left; }
  td { padding: 8px 10px; border-bottom: 1px solid #ecf0f1; }
  tr:nth-child(even) { background: #f8f9fa; }
  .footer { text-align: center; margin-top: 40px; padding-top: 16px; border-top: 2px solid #bdc3c7; color: #95a5a6; font-size: 12px; }
  .finding { padding: 8px 12px; margin: 4px 0; background: #eaf2f8; border-left: 3px solid #3498db; border-radius: 4px; }
  .rec { padding: 8px 12px; margin: 4px 0; background: #eafaf1; border-left: 3px solid #27ae60; border-radius: 4px; }
</style>
</head>
<body>
<div class="header">
  <div class="logo">ARTI-2026</div>
  <p>Təhsil İdarəetmə Sistemi</p>
  <h1>%s</h1>
  <p>Tarix: %s</p>
</div>', title, title, date)

  # Xülasə
  if (!is.null(summary)) {
    html <- paste0(html, '<div class="summary">', summary$summary_html %||% "", '</div>')

    # KPI
    if (!is.null(summary$kpis)) {
      k <- summary$kpis
      html <- paste0(html, '<div class="kpi-row">',
        sprintf('<div class="kpi"><h3>%s</h3><small>%s</small></div>', k$kpi1_value %||% "—", k$kpi1_label %||% ""),
        sprintf('<div class="kpi"><h3>%s</h3><small>%s</small></div>', k$kpi2_value %||% "—", k$kpi2_label %||% ""),
        sprintf('<div class="kpi"><h3>%s</h3><small>%s</small></div>', k$kpi3_value %||% "—", k$kpi3_label %||% ""),
        sprintf('<div class="kpi"><h3>%s</h3><small>%s</small></div>', k$kpi4_value %||% "—", k$kpi4_label %||% ""),
        '</div>')
    }

    # Tapıntılar
    if (length(summary$key_findings) > 0) {
      html <- paste0(html, '<h2>Əsas Tapıntılar</h2>')
      for (f in summary$key_findings) html <- paste0(html, sprintf('<div class="finding">%s</div>', f))
    }

    # Tövsiyələr
    if (length(summary$recommendations) > 0) {
      html <- paste0(html, '<h2>Tövsiyələr</h2>')
      for (r in summary$recommendations) html <- paste0(html, sprintf('<div class="rec">%s</div>', r))
    }
  }

  # Performans cədvəl
  if (!is.null(data$performance) && nrow(data$performance) > 0) {
    html <- paste0(html, '<h2>Performans</h2><table><tr><th>Kateqoriya</th><th>Orta Bal</th><th>Qiymət</th></tr>')
    for (i in seq_len(nrow(data$performance))) {
      color <- get_grade_color(data$performance$value[i])
      html <- paste0(html, sprintf('<tr><td>%s</td><td style="font-weight:bold; color:%s">%s</td><td>%s</td></tr>',
        data$performance$label[i], color, data$performance$value[i], get_grade_label(data$performance$value[i])))
    }
    html <- paste0(html, '</table>')
  }

  # Detallı cədvəl
  if (!is.null(data$detail_table) && nrow(data$detail_table) > 0) {
    html <- paste0(html, '<h2>Detallı Məlumatlar</h2><table><tr>')
    for (col in names(data$detail_table)) html <- paste0(html, sprintf('<th>%s</th>', col))
    html <- paste0(html, '</tr>')
    for (i in seq_len(min(nrow(data$detail_table), 100))) {
      html <- paste0(html, '<tr>')
      for (j in seq_along(data$detail_table)) {
        val <- data$detail_table[i, j]
        html <- paste0(html, sprintf('<td>%s</td>', if (is.na(val)) "—" else val))
      }
      html <- paste0(html, '</tr>')
    }
    html <- paste0(html, '</table>')
  }

  # Footer
  html <- paste0(html, sprintf(
    '<div class="footer">
       <p>Bu hesabat ARTI-2026 Təhsil İdarəetmə Sistemi tərəfindən avtomatik yaradılmışdır.</p>
       <p>Tədris ili: %s | Yaradılma: %s</p>
     </div></body></html>',
    input$academic_year %||% "2025-2026", date))

  html
}

# =============================================
# EXCEL HESABAT GENERASİYASI
# =============================================

#' Ətraflı Excel hesabat yarat
generate_excel_report <- function(data, summary, file) {
  wb <- openxlsx::createWorkbook()

  # Stillər
  header_style <- openxlsx::createStyle(
    fontColour = "#FFFFFF", fgFill = "#2c3e50", halign = "center",
    textDecoration = "bold", fontSize = 12, border = "TopBottomLeftRight")
  title_style <- openxlsx::createStyle(
    fontSize = 16, textDecoration = "bold", fontColour = "#2c3e50")
  good_style <- openxlsx::createStyle(fontColour = "#27ae60", textDecoration = "bold")
  warn_style <- openxlsx::createStyle(fontColour = "#f39c12", textDecoration = "bold")
  bad_style  <- openxlsx::createStyle(fontColour = "#e74c3c", textDecoration = "bold")

  # == 1. Xülasə vərəqi ==
  openxlsx::addWorksheet(wb, "Xülasə")
  openxlsx::writeData(wb, "Xülasə", data.frame(x = "ARTI-2026 HESABAT"), startRow = 1)
  openxlsx::addStyle(wb, "Xülasə", title_style, rows = 1, cols = 1)
  openxlsx::writeData(wb, "Xülasə", data.frame(x = data$title %||% ""), startRow = 2)
  openxlsx::writeData(wb, "Xülasə", data.frame(x = paste("Tarix:", format(Sys.time(), "%d.%m.%Y %H:%M"))), startRow = 3)

  row <- 5
  if (!is.null(summary)) {
    clean <- gsub("<[^>]+>", "", summary$summary_html %||% "")
    clean <- gsub("&nbsp;", " ", clean)
    # Xülasəni paraqraflara böl
    paragraphs <- strsplit(clean, "\n+")[[1]]
    for (p in paragraphs) {
      if (nchar(trimws(p)) > 0) {
        openxlsx::writeData(wb, "Xülasə", data.frame(x = trimws(p)), startRow = row)
        row <- row + 1
      }
    }

    if (!is.null(summary$kpis)) {
      row <- row + 1
      k <- summary$kpis
      kpi_df <- data.frame(
        Gosterici = c(k$kpi1_label %||% "", k$kpi2_label %||% "", k$kpi3_label %||% "", k$kpi4_label %||% ""),
        Deyer = c(k$kpi1_value %||% "", k$kpi2_value %||% "", k$kpi3_value %||% "", k$kpi4_value %||% "")
      )
      openxlsx::writeData(wb, "Xülasə", kpi_df, startRow = row, headerStyle = header_style)
      row <- row + nrow(kpi_df) + 2
    }

    if (length(summary$key_findings) > 0) {
      openxlsx::writeData(wb, "Xülasə", data.frame(x = "ƏSAS TAPINTILAR"), startRow = row)
      openxlsx::addStyle(wb, "Xülasə", openxlsx::createStyle(textDecoration = "bold"), rows = row, cols = 1)
      row <- row + 1
      for (f in summary$key_findings) {
        openxlsx::writeData(wb, "Xülasə", data.frame(x = paste("•", f)), startRow = row)
        row <- row + 1
      }
      row <- row + 1
    }

    if (length(summary$recommendations) > 0) {
      openxlsx::writeData(wb, "Xülasə", data.frame(x = "TÖVSİYƏLƏR"), startRow = row)
      openxlsx::addStyle(wb, "Xülasə", openxlsx::createStyle(textDecoration = "bold"), rows = row, cols = 1)
      row <- row + 1
      for (r in summary$recommendations) {
        openxlsx::writeData(wb, "Xülasə", data.frame(x = paste("•", r)), startRow = row)
        row <- row + 1
      }
    }
  }

  openxlsx::setColWidths(wb, "Xülasə", cols = 1:2, widths = c(60, 30))

  # == 2. Performans vərəqi ==
  if (!is.null(data$performance) && nrow(data$performance) > 0) {
    openxlsx::addWorksheet(wb, "Performans")
    perf <- data$performance
    names(perf) <- c("Kateqoriya", "Orta Bal")
    perf[["Qiymət"]] <- sapply(perf[["Orta Bal"]], get_grade_label)
    openxlsx::writeData(wb, "Performans", perf, headerStyle = header_style)
    openxlsx::setColWidths(wb, "Performans", cols = 1:3, widths = c(25, 15, 15))
    # Rəng kodlaması
    for (i in seq_len(nrow(perf))) {
      style <- if (perf[["Orta Bal"]][i] >= 71) good_style else if (perf[["Orta Bal"]][i] >= 51) warn_style else bad_style
      openxlsx::addStyle(wb, "Performans", style, rows = i + 1, cols = 2)
    }
  }

  # == 3. Paylanma vərəqi ==
  if (!is.null(data$distribution) && nrow(data$distribution) > 0) {
    openxlsx::addWorksheet(wb, "Paylanma")
    dist <- data$distribution
    names(dist) <- c("Kateqoriya", "Say")
    openxlsx::writeData(wb, "Paylanma", dist, headerStyle = header_style)
    openxlsx::setColWidths(wb, "Paylanma", cols = 1:2, widths = c(20, 15))
  }

  # == 4. Detallı Data vərəqi ==
  if (!is.null(data$detail_table) && nrow(data$detail_table) > 0) {
    openxlsx::addWorksheet(wb, "Detallı")
    openxlsx::writeData(wb, "Detallı", data$detail_table, headerStyle = header_style)
    openxlsx::setColWidths(wb, "Detallı", cols = seq_along(data$detail_table), widths = "auto")
  }

  # == 5. Trend vərəqi ==
  if (!is.null(data$trend) && nrow(data$trend) > 0) {
    openxlsx::addWorksheet(wb, "Trend")
    tr <- data$trend
    names(tr) <- c("Dövr", "Orta Bal")
    openxlsx::writeData(wb, "Trend", tr, headerStyle = header_style)
    openxlsx::setColWidths(wb, "Trend", cols = 1:2, widths = c(20, 15))
  }

  openxlsx::saveWorkbook(wb, file, overwrite = TRUE)
}
