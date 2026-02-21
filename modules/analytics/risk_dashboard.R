# =============================================
# ARTI-2026: Risk Izleme Dashboard
# Gun 17: Genislendirilmis Risk Dashboard
# =============================================
# Modul: risk_dashboard_ui / risk_dashboard_server
# Asililiqlar: shinydashboard, plotly, DT, openxlsx
# Istifade: predictions.R-den extract_student_features(),
#           calculate_heuristic_risk(), plotly_empty()
# =============================================

# -----------------------------------------------
# UI
# -----------------------------------------------
risk_dashboard_ui <- function(id) {
  ns <- NS(id)

  tagList(
    # ---- Bashliq ----
    fluidRow(
      column(
        12,
        h2(icon("exclamation-triangle"), "Risk Izleme Dashboardu"),
        tags$p(
          class = "text-muted",
          "Real-vaxt risk monitorinqi, trend analiz, mekteb/sinif drill-down"
        ),
        hr()
      )
    ),

    # ---- Filtr paneli ----
    fluidRow(
      column(
        3,
        selectInput(
          ns("rd_school"),
          "Mekteb:",
          choices = c("Butun Mektebler" = "")
        )
      ),
      column(
        2,
        selectInput(
          ns("rd_grade"),
          "Sinif:",
          choices = c("Hamisi" = "", as.character(1:11))
        )
      ),
      column(
        2,
        sliderInput(
          ns("rd_threshold"),
          "Risk heddi:",
          min = 30,
          max = 80,
          value = 60,
          post = "%"
        )
      ),
      column(
        2,
        selectInput(
          ns("rd_target"),
          "Risk novu:",
          choices = c(
            "Terk Riski"   = "dropout",
            "Performans"   = "performance",
            "Davamiyyet"   = "attendance"
          )
        )
      ),
      column(
        3,
        actionButton(
          ns("btn_rd_analyze"),
          "Analiz Et",
          icon  = icon("search"),
          class = "btn-primary btn-lg",
          style = "margin-top:25px; width:100%;"
        )
      )
    ),

    # ---- Risk Xulase - 6 valueBox ----
    fluidRow(
      valueBoxOutput(ns("rd_total_students"),  width = 2),
      valueBoxOutput(ns("rd_high_risk"),       width = 2),
      valueBoxOutput(ns("rd_medium_risk"),     width = 2),
      valueBoxOutput(ns("rd_low_risk"),        width = 2),
      valueBoxOutput(ns("rd_risk_rate"),       width = 2),
      valueBoxOutput(ns("rd_trend_direction"), width = 2)
    ),

    # ---- Charts row 1 ----
    fluidRow(
      column(
        4,
        box(
          title       = tagList(icon("chart-pie"), " Risk Paylanmasi"),
          status      = "danger",
          solidHeader = TRUE,
          width       = 12,
          plotlyOutput(ns("rd_risk_pie"), height = "300px")
        )
      ),
      column(
        4,
        box(
          title       = tagList(icon("chart-line"), " Risk Trendi (Ayliq)"),
          status      = "warning",
          solidHeader = TRUE,
          width       = 12,
          plotlyOutput(ns("rd_risk_trend"), height = "300px")
        )
      ),
      column(
        4,
        box(
          title       = tagList(icon("chart-bar"), " Sinif Uzre Risk"),
          status      = "info",
          solidHeader = TRUE,
          width       = 12,
          plotlyOutput(ns("rd_grade_risk"), height = "300px")
        )
      )
    ),

    # ---- Charts row 2 ----
    fluidRow(
      column(
        6,
        box(
          title       = tagList(icon("th"), " Mekteb Risk Xeritesi"),
          status      = "primary",
          solidHeader = TRUE,
          width       = 12,
          plotlyOutput(ns("rd_school_heatmap"), height = "350px")
        )
      ),
      column(
        6,
        box(
          title       = tagList(icon("chart-area"), " Risk Faktor Analizi"),
          status      = "success",
          solidHeader = TRUE,
          width       = 12,
          plotlyOutput(ns("rd_factor_chart"), height = "350px")
        )
      )
    ),

    # ---- Gauge row ----
    fluidRow(
      column(
        4,
        box(
          title       = tagList(icon("tachometer-alt"), " Umumi Risk Gostericisi"),
          status      = "danger",
          solidHeader = TRUE,
          width       = 12,
          plotlyOutput(ns("rd_gauge_overall"), height = "220px")
        )
      ),
      column(
        4,
        box(
          title       = tagList(icon("tachometer-alt"), " Davamiyyet Riski"),
          status      = "warning",
          solidHeader = TRUE,
          width       = 12,
          plotlyOutput(ns("rd_gauge_attendance"), height = "220px")
        )
      ),
      column(
        4,
        box(
          title       = tagList(icon("tachometer-alt"), " Performans Riski"),
          status      = "info",
          solidHeader = TRUE,
          width       = 12,
          plotlyOutput(ns("rd_gauge_performance"), height = "220px")
        )
      )
    ),

    # ---- Risk distribution box-plot by grade ----
    fluidRow(
      column(
        12,
        box(
          title       = tagList(icon("box-open"), " Sinif Uzre Risk Paylanmasi (Box-plot)"),
          status      = "primary",
          solidHeader = TRUE,
          width       = 12,
          plotlyOutput(ns("rd_risk_boxplot"), height = "300px")
        )
      )
    ),

    # ---- Student risk table ----
    fluidRow(
      column(
        12,
        box(
          title       = tagList(icon("users"), " Risk Altinda Olan Sagirdler"),
          status      = "danger",
          solidHeader = TRUE,
          width       = 12,

          fluidRow(
            column(
              3,
              selectInput(
                ns("rd_filter_risk"),
                "Risk Kateqoriyasi:",
                choices = c(
                  "Hamisi"  = "",
                  "Yuksek"  = "yuksek",
                  "Orta"    = "orta",
                  "Asagi"   = "asagi"
                )
              )
            ),
            column(
              3,
              textInput(
                ns("rd_search"),
                "Axtar:",
                placeholder = "Ad, soyad..."
              )
            ),
            column(
              3,
              downloadButton(
                ns("btn_rd_export"),
                "Excel Yukle",
                class = "btn-success",
                style = "margin-top:25px;"
              )
            ),
            column(
              3,
              actionButton(
                ns("btn_rd_notify_all"),
                "Hamisina Bildiris",
                icon  = icon("bell"),
                class = "btn-danger",
                style = "margin-top:25px;"
              )
            )
          ),

          DTOutput(ns("rd_risk_table")),
          tags$br(),

          # Student detail panel (shown when a row is selected)
          conditionalPanel(
            condition = paste0(
              "typeof output['", ns("rd_student_selected"), "'] !== 'undefined' && ",
              "output['", ns("rd_student_selected"), "']"
            ),
            uiOutput(ns("rd_student_detail"))
          )
        )
      )
    )
  )
}

# -----------------------------------------------
# SERVER
# -----------------------------------------------
risk_dashboard_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Reactive store for full risk data
    risk_data <- reactiveVal(data.frame())

    # --------------------------------------------------
    # Load schools into dropdown
    # --------------------------------------------------
    observe({
      schools <- tryCatch(
        db_query(
          db_pool,
          "SELECT id, name FROM schools WHERE status = 'active' ORDER BY name"
        ),
        error = function(e) data.frame(id = character(0), name = character(0))
      )
      if (nrow(schools) > 0) {
        updateSelectInput(
          session,
          "rd_school",
          choices = c(
            "Butun Mektebler" = "",
            setNames(schools$id, schools$name)
          )
        )
      }
    })

    # --------------------------------------------------
    # ANALYZE button
    # --------------------------------------------------
    observeEvent(input$btn_rd_analyze, {
      withProgress(message = "Risk analizi aparilir...", value = 0.2, {

        features <- tryCatch(
          extract_student_features(input$rd_school),
          error = function(e) data.frame()
        )

        if (is_empty(features) || nrow(features) == 0) {
          notify_warning("Data tapilmadi.")
          risk_data(data.frame())
          return()
        }

        setProgress(0.5, detail = "Risk hesablanir...")

        # Base heuristic risk
        features$risk_score <- calculate_heuristic_risk(features)

        # Target-specific adjustments
        target <- input$rd_target %||% "dropout"
        if (target == "performance") {
          features$risk_score <- pmin(
            100,
            features$risk_score * 0.6 +
              pmax(0, 70 - features$avg_score) * 1.5
          )
        } else if (target == "attendance") {
          features$risk_score <- pmin(
            100,
            features$risk_score * 0.4 +
              pmax(0, 90 - features$attendance_pct) * 2.0
          )
        }

        # Categorise
        threshold <- input$rd_threshold %||% 60
        features$risk_category <- cut(
          features$risk_score,
          breaks = c(-1, 40, threshold, 101),
          labels = c("asagi", "orta", "yuksek")
        )

        # Grade filter
        if (!is_empty(input$rd_grade) && nchar(input$rd_grade) > 0) {
          features <- features[features$grade == as.integer(input$rd_grade), ]
        }

        risk_data(features)
        setProgress(1, detail = "Hazir!")
      })
    })

    # --------------------------------------------------
    # VALUE BOXES
    # --------------------------------------------------
    output$rd_total_students <- renderValueBox({
      d <- risk_data()
      n <- if (nrow(d) > 0) nrow(d) else 0
      valueBox(
        format(n, big.mark = "."),
        "Umumi Sagird",
        icon  = icon("users"),
        color = "blue"
      )
    })

    output$rd_high_risk <- renderValueBox({
      d <- risk_data()
      n <- if (nrow(d) > 0) sum(d$risk_category == "yuksek", na.rm = TRUE) else 0
      valueBox(n, "Yuksek Risk", icon = icon("exclamation-circle"), color = "red")
    })

    output$rd_medium_risk <- renderValueBox({
      d <- risk_data()
      n <- if (nrow(d) > 0) sum(d$risk_category == "orta", na.rm = TRUE) else 0
      valueBox(n, "Orta Risk", icon = icon("exclamation-triangle"), color = "yellow")
    })

    output$rd_low_risk <- renderValueBox({
      d <- risk_data()
      n <- if (nrow(d) > 0) sum(d$risk_category == "asagi", na.rm = TRUE) else 0
      valueBox(n, "Asagi Risk", icon = icon("check-circle"), color = "green")
    })

    output$rd_risk_rate <- renderValueBox({
      d <- risk_data()
      rate <- if (nrow(d) > 0) {
        round(sum(d$risk_category == "yuksek", na.rm = TRUE) / nrow(d) * 100, 1)
      } else {
        0
      }
      valueBox(
        paste0(rate, "%"),
        "Risk Nisbeti",
        icon  = icon("percent"),
        color = if (rate > 15) "red" else "green"
      )
    })

    output$rd_trend_direction <- renderValueBox({
      d <- risk_data()
      if (nrow(d) > 0) {
        avg_risk  <- round(mean(d$risk_score, na.rm = TRUE), 1)
        label     <- if (avg_risk > 50) "Artir" else if (avg_risk > 30) "Sabit" else "Azalir"
        icon_name <- if (avg_risk > 50) "arrow-up" else if (avg_risk > 30) "arrows-alt-h" else "arrow-down"
        color     <- if (avg_risk > 50) "red" else if (avg_risk > 30) "yellow" else "green"
      } else {
        label     <- "\u2014"
        icon_name <- "question"
        color     <- "blue"
      }
      valueBox(label, "Trend", icon = icon(icon_name), color = color)
    })

    # --------------------------------------------------
    # GAUGE - Overall risk
    # --------------------------------------------------
    output$rd_gauge_overall <- renderPlotly({
      d <- risk_data()
      val <- if (nrow(d) > 0) round(mean(d$risk_score, na.rm = TRUE), 1) else 0
      plot_ly(
        type = "indicator",
        mode = "gauge+number",
        value = val,
        title = list(text = "Orta Risk Bali"),
        gauge = list(
          axis = list(range = list(0, 100)),
          bar  = list(color = "#e74c3c"),
          steps = list(
            list(range = c(0, 40),  color = "#d5f5e3"),
            list(range = c(40, 65), color = "#fdebd0"),
            list(range = c(65, 100), color = "#fadbd8")
          ),
          threshold = list(
            line  = list(color = "black", width = 4),
            thickness = 0.75,
            value = val
          )
        )
      ) %>% layout(margin = list(t = 40, b = 10))
    })

    # GAUGE - Attendance risk
    output$rd_gauge_attendance <- renderPlotly({
      d <- risk_data()
      val <- if (nrow(d) > 0) {
        round(100 - mean(d$attendance_pct, na.rm = TRUE), 1)
      } else {
        0
      }
      plot_ly(
        type = "indicator",
        mode = "gauge+number",
        value = val,
        title = list(text = "Davamiyyet Risk"),
        gauge = list(
          axis = list(range = list(0, 100)),
          bar  = list(color = "#f39c12"),
          steps = list(
            list(range = c(0, 15),  color = "#d5f5e3"),
            list(range = c(15, 35), color = "#fdebd0"),
            list(range = c(35, 100), color = "#fadbd8")
          )
        )
      ) %>% layout(margin = list(t = 40, b = 10))
    })

    # GAUGE - Performance risk
    output$rd_gauge_performance <- renderPlotly({
      d <- risk_data()
      val <- if (nrow(d) > 0) {
        round(100 - mean(d$avg_score, na.rm = TRUE), 1)
      } else {
        0
      }
      plot_ly(
        type = "indicator",
        mode = "gauge+number",
        value = val,
        title = list(text = "Performans Risk"),
        gauge = list(
          axis = list(range = list(0, 100)),
          bar  = list(color = "#3498db"),
          steps = list(
            list(range = c(0, 30),  color = "#d5f5e3"),
            list(range = c(30, 50), color = "#fdebd0"),
            list(range = c(50, 100), color = "#fadbd8")
          )
        )
      ) %>% layout(margin = list(t = 40, b = 10))
    })

    # --------------------------------------------------
    # PIE CHART
    # --------------------------------------------------
    output$rd_risk_pie <- renderPlotly({
      d <- risk_data()
      if (nrow(d) == 0) return(plotly_empty("Analiz et"))

      counts <- table(d$risk_category)
      df <- data.frame(
        category = names(counts),
        count    = as.integer(counts),
        stringsAsFactors = FALSE
      )

      color_map <- c("asagi" = "#27ae60", "orta" = "#f39c12", "yuksek" = "#e74c3c")
      label_map <- c("asagi" = "Asagi", "orta" = "Orta", "yuksek" = "Yuksek")
      df$label <- label_map[df$category]
      df$color <- color_map[df$category]

      plot_ly(
        df,
        labels   = ~label,
        values   = ~count,
        type     = "pie",
        marker   = list(colors = df$color),
        textinfo = "label+value+percent"
      ) %>%
        layout(showlegend = TRUE)
    })

    # --------------------------------------------------
    # RISK TREND (monthly) from grades table
    # --------------------------------------------------
    output$rd_risk_trend <- renderPlotly({
      school_filter <- if (!is_empty(input$rd_school) && nchar(input$rd_school) > 0) {
        paste0("AND s.school_id = '", input$rd_school, "'")
      } else {
        ""
      }

      trend_sql <- sprintf(
        "SELECT DATE_TRUNC('month', g.grade_date)::date AS month,
                100 - ROUND(AVG(g.score)::numeric, 1) AS risk_proxy,
                COUNT(DISTINCT g.student_id) AS students
         FROM grades g
         JOIN students s ON g.student_id = s.id
         WHERE g.grade_date >= CURRENT_DATE - INTERVAL '12 months'
           AND s.status = 'active' %s
         GROUP BY 1
         ORDER BY 1",
        school_filter
      )

      trend <- tryCatch(
        db_query(db_pool, trend_sql),
        error = function(e) data.frame()
      )

      if (nrow(trend) == 0) return(plotly_empty("Trend datasi yoxdur"))

      plot_ly(
        trend,
        x    = ~month,
        y    = ~risk_proxy,
        type = "scatter",
        mode = "lines+markers",
        line   = list(color = "#e74c3c", width = 3),
        marker = list(size = 8),
        text = ~paste0(
          "Ay: ", format(month, "%b %Y"),
          "<br>Risk: ", risk_proxy, "%",
          "<br>Sagird: ", students
        ),
        hoverinfo = "text"
      ) %>%
        layout(
          xaxis = list(title = ""),
          yaxis = list(title = "Risk indeksi", range = c(0, 100)),
          shapes = list(
            list(
              type = "line",
              x0   = min(trend$month),
              x1   = max(trend$month),
              y0   = 40, y1 = 40,
              line = list(color = "#f39c12", dash = "dash")
            )
          )
        )
    })

    # --------------------------------------------------
    # GRADE RISK BAR
    # --------------------------------------------------
    output$rd_grade_risk <- renderPlotly({
      d <- risk_data()
      if (nrow(d) == 0) return(plotly_empty("Analiz et"))

      agg <- aggregate(risk_score ~ grade, data = d, FUN = mean)
      agg$risk_score <- round(agg$risk_score, 1)

      colors <- ifelse(
        agg$risk_score > 60, "#e74c3c",
        ifelse(agg$risk_score > 40, "#f39c12", "#27ae60")
      )

      plot_ly(
        agg,
        x      = ~paste0(grade, "-ci sinif"),
        y      = ~risk_score,
        type   = "bar",
        marker = list(color = colors),
        text   = ~paste0(risk_score, "%"),
        textposition = "outside"
      ) %>%
        layout(
          xaxis = list(title = ""),
          yaxis = list(title = "Orta Risk Bali", range = c(0, 100))
        )
    })

    # --------------------------------------------------
    # SCHOOL HEATMAP
    # --------------------------------------------------
    output$rd_school_heatmap <- renderPlotly({
      d <- risk_data()
      if (nrow(d) == 0 || !("school_name" %in% names(d))) {
        return(plotly_empty("Analiz et"))
      }

      agg <- tryCatch({
        t <- table(d$school_name, d$risk_category)
        as.data.frame(t, stringsAsFactors = FALSE)
      }, error = function(e) data.frame())

      if (nrow(agg) == 0) return(plotly_empty("Mekteb datasi yoxdur"))

      names(agg) <- c("school", "category", "count")

      schools    <- unique(agg$school)
      categories <- c("asagi", "orta", "yuksek")
      z_mat      <- matrix(0, nrow = length(schools), ncol = length(categories))

      for (i in seq_along(schools)) {
        for (j in seq_along(categories)) {
          val <- agg$count[agg$school == schools[i] & agg$category == categories[j]]
          if (length(val) > 0) z_mat[i, j] <- val
        }
      }

      plot_ly(
        z = z_mat,
        x = c("Asagi", "Orta", "Yuksek"),
        y = as.character(schools),
        type = "heatmap",
        colorscale = list(
          c(0,   "#d5f5e3"),
          c(0.5, "#fdebd0"),
          c(1,   "#fadbd8")
        ),
        text         = z_mat,
        texttemplate = "%{text}",
        showscale    = TRUE
      ) %>%
        layout(
          xaxis  = list(title = "Risk Kateqoriyasi"),
          yaxis  = list(title = ""),
          margin = list(l = 200)
        )
    })

    # --------------------------------------------------
    # RISK FACTOR ANALYSIS
    # --------------------------------------------------
    output$rd_factor_chart <- renderPlotly({
      d <- risk_data()
      if (nrow(d) == 0) return(plotly_empty("Faktor analizi"))

      # Use high-risk students; fall back to all if none
      high <- d[d$risk_category == "yuksek", ]
      if (nrow(high) == 0) high <- d

      factors <- data.frame(
        factor = c(
          "Asagi Orta Bal",
          "Zeif Davamiyyet",
          "Menfi Trend",
          "Ev Taps. Boslugu",
          "Yuksek Qayib"
        ),
        value = c(
          mean(pmax(0, 60 - high$avg_score),      na.rm = TRUE),
          mean(pmax(0, 85 - high$attendance_pct),  na.rm = TRUE),
          mean(pmax(0, -high$score_trend),         na.rm = TRUE),
          mean(pmax(0, 70 - high$hw_completion),   na.rm = TRUE),
          mean(high$absent_count,                  na.rm = TRUE)
        ),
        stringsAsFactors = FALSE
      )
      factors$value <- round(factors$value, 1)

      plot_ly(
        factors,
        x      = ~reorder(factor, value),
        y      = ~value,
        type   = "bar",
        marker = list(
          color = c("#e74c3c", "#f39c12", "#9b59b6", "#3498db", "#e67e22")
        )
      ) %>%
        layout(
          xaxis = list(title = ""),
          yaxis = list(title = "Orta Tesir Bali")
        )
    })

    # --------------------------------------------------
    # RISK BOX-PLOT by grade
    # --------------------------------------------------
    output$rd_risk_boxplot <- renderPlotly({
      d <- risk_data()
      if (nrow(d) == 0) return(plotly_empty("Analiz et"))

      d$grade_label <- paste0(d$grade, "-ci sinif")
      plot_ly(
        d,
        x    = ~grade_label,
        y    = ~risk_score,
        type = "box",
        marker = list(color = "#e74c3c"),
        line   = list(color = "#c0392b"),
        fillcolor = "rgba(231,76,60,0.3)"
      ) %>%
        layout(
          xaxis = list(title = ""),
          yaxis = list(title = "Risk Bali", range = c(0, 100))
        )
    })

    # --------------------------------------------------
    # RISK TABLE
    # --------------------------------------------------
    output$rd_risk_table <- renderDT({
      d <- risk_data()
      if (nrow(d) == 0) {
        return(
          datatable(
            data.frame(Mesaj = "Analiz aparilmayib"),
            options  = list(dom = "t", language = list(emptyTable = "Data yoxdur")),
            rownames = FALSE
          )
        )
      }

      display_cols <- c(
        "first_name", "last_name", "school_name", "grade", "section",
        "avg_score", "attendance_pct", "score_trend", "hw_completion",
        "risk_score", "risk_category"
      )
      display <- d[, intersect(display_cols, names(d)), drop = FALSE]
      names(display) <- c(
        "Ad", "Soyad", "Mekteb", "Sinif", "Bolme",
        "Orta Bal", "Davamiyyet%", "Trend", "Ev Taps%",
        "Risk Bali", "Risk"
      )[seq_len(ncol(display))]

      # Category filter
      if (!is_empty(input$rd_filter_risk) && nchar(input$rd_filter_risk) > 0) {
        display <- display[display$Risk == input$rd_filter_risk, ]
      }

      # Text search
      if (!is_empty(input$rd_search) && nchar(input$rd_search) > 0) {
        search_term <- tolower(input$rd_search)
        display <- display[
          grepl(search_term, tolower(paste(display$Ad, display$Soyad))),
        ]
      }

      # Sort by risk descending
      display <- display[order(-display$`Risk Bali`), ]

      datatable(
        display,
        options   = default_dt_options(20),
        selection = "single",
        rownames  = FALSE
      ) %>%
        formatRound(
          c("Orta Bal", "Davamiyyet%", "Trend", "Ev Taps%", "Risk Bali"), 1
        ) %>%
        formatStyle(
          "Risk Bali",
          backgroundColor = styleInterval(
            c(40, 65),
            c("#d5f5e3", "#fdebd0", "#fadbd8")
          ),
          fontWeight = "bold"
        ) %>%
        formatStyle(
          "Risk",
          color = styleEqual(
            c("yuksek", "orta", "asagi"),
            c("#e74c3c", "#f39c12", "#27ae60")
          ),
          fontWeight = "bold"
        )
    })

    # --------------------------------------------------
    # STUDENT DETAIL (selected row)
    # --------------------------------------------------
    output$rd_student_selected <- reactive({
      !is.null(input$rd_risk_table_rows_selected)
    })
    outputOptions(output, "rd_student_selected", suspendWhenHidden = FALSE)

    output$rd_student_detail <- renderUI({
      sel <- input$rd_risk_table_rows_selected
      d   <- risk_data()
      if (is.null(sel) || nrow(d) == 0) return(NULL)

      sorted_d <- d[order(-d$risk_score), ]
      if (sel > nrow(sorted_d)) return(NULL)
      s <- sorted_d[sel, ]

      risk_color <- if (s$risk_score > 65) {
        "#e74c3c"
      } else if (s$risk_score > 40) {
        "#f39c12"
      } else {
        "#27ae60"
      }

      # Subject-level grades for this student
      grades_df <- tryCatch(
        db_query(
          db_pool,
          "SELECT sub.name, ROUND(AVG(g.score)::numeric, 1) AS avg
           FROM grades g
           JOIN subjects sub ON g.subject_id = sub.id
           WHERE g.student_id = $1
             AND g.grade_date >= CURRENT_DATE - INTERVAL '6 months'
           GROUP BY sub.name
           ORDER BY avg",
          params = list(s$student_id)
        ),
        error = function(e) data.frame()
      )

      wellPanel(
        style = paste0("border-left: 5px solid ", risk_color, ";"),
        fluidRow(
          # Column 1 - Identity & risk score
          column(
            4,
            tags$h4(paste(s$first_name, s$last_name)),
            tags$p(paste0(s$grade, s$section, " sinif | ", s$school_name)),
            tags$h2(
              style = paste0("color:", risk_color),
              paste0("Risk: ", round(s$risk_score, 1), "%")
            )
          ),
          # Column 2 - Key metrics
          column(
            4,
            tags$div(
              style = "display:grid; grid-template-columns:1fr 1fr; gap:8px;",
              tags$div(
                tags$strong("Orta bal:"),
                tags$span(round(s$avg_score, 1))
              ),
              tags$div(
                tags$strong("Davamiyyet:"),
                tags$span(paste0(round(s$attendance_pct, 1), "%"))
              ),
              tags$div(
                tags$strong("Trend:"),
                tags$span(
                  style = paste0(
                    "color:",
                    if (s$score_trend < 0) "#e74c3c" else "#27ae60"
                  ),
                  paste0(
                    ifelse(s$score_trend > 0, "+", ""),
                    round(s$score_trend, 1)
                  )
                )
              ),
              tags$div(
                tags$strong("Ev tapsirigi:"),
                tags$span(paste0(round(s$hw_completion, 1), "%"))
              )
            )
          ),
          # Column 3 - Subject breakdown
          column(
            4,
            if (nrow(grades_df) > 0) {
              tags$div(
                tags$strong("Fenn ballari:"),
                lapply(seq_len(min(nrow(grades_df), 6)), function(i) {
                  g <- grades_df[i, ]
                  color <- if (g$avg >= 71) {
                    "#27ae60"
                  } else if (g$avg >= 51) {
                    "#f39c12"
                  } else {
                    "#e74c3c"
                  }
                  tags$div(
                    style = "display:flex; justify-content:space-between; font-size:0.85em; padding:2px 0;",
                    tags$span(g$name),
                    tags$span(
                      style = paste0("color:", color, "; font-weight:bold;"),
                      g$avg
                    )
                  )
                })
              )
            } else {
              tags$p(class = "text-muted", "Fenn datasi yoxdur")
            }
          )
        ),

        # Risk factor decomposition for this student
        tags$hr(),
        tags$h5(icon("puzzle-piece"), " Risk Faktor Parcalanmasi"),
        fluidRow(
          column(12,
            tags$div(
              style = "display:grid; grid-template-columns:repeat(5,1fr); gap:10px; text-align:center;",
              .build_factor_card(
                "Orta Bal",
                round(s$avg_score, 1),
                pmin(100, pmax(0, round(60 - s$avg_score))),
                "#e74c3c"
              ),
              .build_factor_card(
                "Davamiyyet",
                paste0(round(s$attendance_pct, 1), "%"),
                pmin(100, pmax(0, round(85 - s$attendance_pct))),
                "#f39c12"
              ),
              .build_factor_card(
                "Trend",
                round(s$score_trend, 1),
                pmin(100, pmax(0, round(-s$score_trend * 2))),
                "#9b59b6"
              ),
              .build_factor_card(
                "Ev Tapsirigi",
                paste0(round(s$hw_completion, 1), "%"),
                pmin(100, pmax(0, round(70 - s$hw_completion))),
                "#3498db"
              ),
              .build_factor_card(
                "Qayib Gun",
                round(s$absent_count),
                pmin(100, round(s$absent_count * 5)),
                "#e67e22"
              )
            )
          )
        ),

        tags$hr(),
        # Action buttons
        fluidRow(
          column(
            12,
            actionButton(
              ns("btn_rd_notify_student"),
              "Muellime Bildiris",
              icon  = icon("bell"),
              class = "btn-warning btn-sm"
            ),
            actionButton(
              ns("btn_rd_student_plan"),
              "Mudaxile Plani",
              icon  = icon("clipboard-list"),
              class = "btn-info btn-sm"
            )
          )
        )
      )
    })

    # --------------------------------------------------
    # NOTIFY ALL HIGH RISK
    # --------------------------------------------------
    observeEvent(input$btn_rd_notify_all, {
      d    <- risk_data()
      high <- d[d$risk_category == "yuksek", ]

      if (nrow(high) == 0) {
        notify_warning("Yuksek riskli sagird yoxdur.")
        return()
      }

      sent <- 0
      withProgress(message = "Bildirisler gonderilir...", value = 0, {
        for (i in seq_len(nrow(high))) {
          s <- high[i, ]
          teachers <- tryCatch(
            db_query(
              db_pool,
              "SELECT DISTINCT t.user_id
               FROM teachers t
               JOIN grades g ON g.teacher_id = t.id
               WHERE g.student_id = $1
                 AND g.grade_date >= CURRENT_DATE - INTERVAL '3 months'",
              params = list(s$student_id)
            ),
            error = function(e) data.frame()
          )

          if (nrow(teachers) > 0) {
            for (j in seq_len(nrow(teachers))) {
              tryCatch(
                db_execute(
                  db_pool,
                  "INSERT INTO notifications (user_id, title, message, type, is_read, created_at)
                   VALUES ($1, $2, $3, 'warning', false, NOW())",
                  params = list(
                    teachers$user_id[j],
                    paste0("Risk Xebardarligi: ", s$first_name, " ", s$last_name),
                    paste0(
                      s$first_name, " ", s$last_name,
                      " (", s$grade, s$section, ") risk bali: ",
                      round(s$risk_score, 1), "%. Orta bal: ",
                      round(s$avg_score, 1), ", Davamiyyet: ",
                      round(s$attendance_pct, 1), "%."
                    )
                  )
                ),
                error = function(e) NULL
              )
            }
            sent <- sent + 1
          }
          setProgress(value = i / nrow(high))
        }
      })
      notify_success(paste0(sent, " sagird ucun bildiris gonderildi!"))
    })

    # --------------------------------------------------
    # NOTIFY for selected student
    # --------------------------------------------------
    observeEvent(input$btn_rd_notify_student, {
      sel <- input$rd_risk_table_rows_selected
      d   <- risk_data()
      if (is.null(sel) || nrow(d) == 0) return()

      sorted_d <- d[order(-d$risk_score), ]
      if (sel > nrow(sorted_d)) return()
      s <- sorted_d[sel, ]

      teachers <- tryCatch(
        db_query(
          db_pool,
          "SELECT DISTINCT t.user_id,
                  t.first_name || ' ' || t.last_name AS name
           FROM teachers t
           JOIN grades g ON g.teacher_id = t.id
           WHERE g.student_id = $1
             AND g.grade_date >= CURRENT_DATE - INTERVAL '3 months'",
          params = list(s$student_id)
        ),
        error = function(e) data.frame()
      )

      if (nrow(teachers) == 0) {
        notify_warning("Muellim tapilmadi.")
        return()
      }

      for (j in seq_len(nrow(teachers))) {
        tryCatch(
          db_execute(
            db_pool,
            "INSERT INTO notifications (user_id, title, message, type, is_read, created_at)
             VALUES ($1, $2, $3, 'warning', false, NOW())",
            params = list(
              teachers$user_id[j],
              paste0("Risk: ", s$first_name, " ", s$last_name),
              paste0(
                "Sagird: ", s$first_name, " ", s$last_name,
                " (", s$grade, s$section, "). Risk: ",
                round(s$risk_score, 1), "%, Orta bal: ",
                round(s$avg_score, 1), ", Davamiyyet: ",
                round(s$attendance_pct, 1), "%, Trend: ",
                round(s$score_trend, 1)
              )
            )
          ),
          error = function(e) NULL
        )
      }
      notify_success(paste0(nrow(teachers), " muellime bildiris gonderildi!"))
    })

    # --------------------------------------------------
    # Intervention plan placeholder
    # --------------------------------------------------
    observeEvent(input$btn_rd_student_plan, {
      notify_warning("Mudaxile plani funksiyasi tezlikle elave olunacaq.")
    })

    # --------------------------------------------------
    # EXPORT to Excel
    # --------------------------------------------------
    output$btn_rd_export <- downloadHandler(
      filename = function() {
        paste0("risk_hesabat_", format(Sys.Date(), "%Y%m%d"), ".xlsx")
      },
      content = function(file) {
        d <- risk_data()
        if (nrow(d) == 0) {
          notify_warning("Data yoxdur.")
          return()
        }

        export_cols <- c(
          "first_name", "last_name", "school_name", "grade", "section",
          "avg_score", "attendance_pct", "score_trend", "hw_completion",
          "risk_score", "risk_category"
        )
        export_df <- d[order(-d$risk_score), intersect(export_cols, names(d)), drop = FALSE]
        names(export_df) <- c(
          "Ad", "Soyad", "Mekteb", "Sinif", "Bolme",
          "Orta Bal", "Davamiyyet%", "Trend", "Ev Taps%",
          "Risk Bali", "Risk"
        )[seq_len(ncol(export_df))]

        export_to_excel(export_df, file, "Risk Hesabati")
      }
    )
  })
}

# -----------------------------------------------
# HELPER: Build a factor card for the detail panel
# -----------------------------------------------
.build_factor_card <- function(label, display_value, risk_contribution, color) {
  # risk_contribution: 0-100 how much this factor contributes
  contribution <- max(0, min(100, risk_contribution))
  bar_width    <- paste0(contribution, "%")

  tags$div(
    style = paste0(
      "background:#f8f9fa; border-radius:8px; padding:10px;",
      "border-top:3px solid ", color, ";"
    ),
    tags$div(
      style = "font-size:0.8em; color:#7f8c8d;",
      label
    ),
    tags$div(
      style = "font-size:1.3em; font-weight:bold;",
      display_value
    ),
    tags$div(
      style = "margin-top:5px; background:#ecf0f1; border-radius:4px; height:8px; overflow:hidden;",
      tags$div(
        style = paste0(
          "width:", bar_width, "; height:100%; background:", color,
          "; border-radius:4px; transition:width 0.5s ease;"
        )
      )
    ),
    tags$div(
      style = "font-size:0.7em; color:#95a5a6; margin-top:2px;",
      paste0("Tesir: ", contribution, "%")
    )
  )
}
