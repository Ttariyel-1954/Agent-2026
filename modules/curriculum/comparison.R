# =============================================
# ARTI-2026: Beynəlxalq Müqayisə
# =============================================

comparison_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(column(12, h2(icon("globe"), "Beynəlxalq Müqayisə"), hr())),
    fluidRow(
      column(6, checkboxGroupInput(ns("countries"), "Ölkələr:", choices = COMPARISON_COUNTRIES[-1],
                                    selected = c("Finlandiya", "Sinqapur", "Estoniya"), inline = TRUE)),
      column(3, selectInput(ns("assessment_type"), "Qiymətləndirmə:", choices = c("PISA" = "pisa", "TIMSS" = "timss", "PIRLS" = "pirls"))),
      column(3, actionButton(ns("btn_compare"), "Müqayisə Et", icon = icon("balance-scale"), class = "btn-primary", style = "margin-top:25px"))
    ),
    fluidRow(
      column(6, wellPanel(h4("Radar Diaqram"), plotlyOutput(ns("radar_chart"), height = "400px"))),
      column(6, wellPanel(h4("Bal Müqayisəsi"), plotlyOutput(ns("score_chart"), height = "400px")))
    ),
    fluidRow(
      column(6, wellPanel(h4("PISA Balları"), DTOutput(ns("pisa_table")))),
      column(6, wellPanel(h4("Güclü/Zəif Tərəflər"), uiOutput(ns("strengths_weaknesses"))))
    ),
    # === AI Standart Analizi Bölməsi ===
    fluidRow(column(12, hr(), h3(icon("robot"), "AI Standart Analizi — Beynəlxalq Çərçivələrlə Müqayisə"))),
    fluidRow(
      column(3, selectInput(ns("ai_subject"), "Fənn:", choices = SUBJECTS)),
      column(2, selectInput(ns("ai_grade"), "Sinif:", choices = setNames(1:11, paste0(1:11, "-ci sinif")))),
      column(3, selectInput(ns("ai_framework"), "Beynəlxalq çərçivə:",
        choices = c("PISA 2022" = "pisa", "TIMSS 2023" = "timss", "PIRLS 2021" = "pirls",
                    "OECD Öyrənmə Kompası 2030" = "oecd2030"))),
      column(2, selectInput(ns("ai_ref_country"), "Referans ölkə:",
        choices = COMPARISON_COUNTRIES[-1], selected = "Finlandiya")),
      column(2, actionButton(ns("btn_ai_analyze"), "AI Analiz", icon = icon("robot"),
        class = "btn-info", style = "margin-top:25px"))
    ),
    # Standart seçimi
    fluidRow(column(12,
      wellPanel(
        h4("Kurikulum Standartını Seçin"),
        DTOutput(ns("standards_select_table")),
        tags$small(style = "color: #888;", "Cədvəldən standart(lar) seçin, sonra 'AI Analiz' düyməsini basın. Seçim olmadıqda bütün fənn standartları analiz olunur.")
      )
    )),
    # AI Nəticə
    fluidRow(
      column(7, wellPanel(
        h4(icon("search-plus"), "Boşluq Analizi (Gap Analysis)"),
        uiOutput(ns("ai_gap_analysis"))
      )),
      column(5, wellPanel(
        h4(icon("map"), "Vizual Müqayisə Xəritəsi"),
        plotlyOutput(ns("ai_gap_map"), height = "400px")
      ))
    ),
    fluidRow(
      column(12, wellPanel(
        h4(icon("lightbulb"), "AI Tövsiyələr"),
        uiOutput(ns("ai_recommendations"))
      ))
    ),
    fluidRow(column(12, wellPanel(
      h4("Ətraflı Müqayisə Hesabatı"),
      downloadButton(ns("btn_report"), "Hesabatı Yüklə", class = "btn-info")
    )))
  )
}

comparison_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    comparison_data <- reactive({
      req(input$countries)
      compare_curricula(c("Azərbaycan", input$countries))
    })

    output$radar_chart <- renderPlotly({
      data <- comparison_data()
      dimensions <- c("STEM Fokus", "Rəqəmsal Savadlılıq", "Tənqidi Düşüncə",
                       "Yaradıcılıq", "Sosial Bacarıqlar", "Praktik Tətbiq")
      p <- plot_ly(type = "scatterpolar", fill = "toself")
      colors <- c("#e74c3c", "#3498db", "#2ecc71", "#f39c12", "#9b59b6", "#1abc9c")
      for (i in seq_along(data$countries)) {
        p <- add_trace(p, r = data$scores[[i]], theta = dimensions,
                       name = data$countries[i], line = list(color = colors[i]))
      }
      p %>% layout(polar = list(radialaxis = list(range = c(0, 100))), title = "Kurikulum Müqayisəsi")
    })

    output$score_chart <- renderPlotly({
      countries <- c("Azərbaycan", input$countries)
      scores <- c(420, sample(480:550, length(input$countries)))
      plot_ly(x = countries, y = scores, type = "bar",
              marker = list(color = ifelse(countries == "Azərbaycan", "#e74c3c", "#3498db"))) %>%
        layout(xaxis = list(title = ""), yaxis = list(title = "PISA Balı"), title = "PISA Bal Müqayisəsi")
    })

    output$pisa_table <- renderDT({
      datatable(data.frame(
        Ölkə = c("Azərbaycan", "Finlandiya", "Sinqapur", "Estoniya"),
        Riyaziyyat = c(420, 507, 569, 523), Oxu = c(389, 520, 549, 523),
        Elm = c(398, 522, 551, 530), Orta = c(402, 516, 556, 525)
      ), options = list(pageLength = 10, dom = "t"))
    })

    output$strengths_weaknesses <- renderUI({
      tags$div(
        tags$h5(icon("check", style="color:green"), "Güclü tərəflər:"),
        tags$ul(tags$li("Riyaziyyat kurrikulumunun strukturu"), tags$li("Əzbərçilik bacarığı")),
        tags$h5(icon("times", style="color:red"), "Zəif tərəflər:"),
        tags$ul(tags$li("Tənqidi düşüncə vurğusu az"), tags$li("Rəqəmsal savadlılıq aşağı"), tags$li("Praktik tətbiq imkanları məhdud"))
      )
    })

    output$btn_report <- downloadHandler(
      filename = function() paste0("beynelxalq_muqayise_", Sys.Date(), ".pdf"),
      content = function(file) { file.copy("docs/sample_comparison.pdf", file) }
    )

    # =============================================
    # AI STANDART ANALİZİ
    # =============================================
    ai_analysis <- reactiveVal(NULL)

    # Seçilmiş fənn+sinif üçün standartları göstər
    standards_for_analysis <- reactive({
      req(input$ai_subject, input$ai_grade)
      tryCatch(
        db_query(db_pool,
          "SELECT cs.id, cs.code, cs.description, cs.bloom_level, cs.dok_level
           FROM curriculum_standards cs
           JOIN subjects s ON cs.subject_id = s.id
           WHERE s.name = $1 AND cs.grade = $2
           ORDER BY cs.code",
          params = list(input$ai_subject, as.integer(input$ai_grade))),
        error = function(e) data.frame()
      )
    })

    output$standards_select_table <- renderDT({
      data <- standards_for_analysis()
      if (nrow(data) == 0) return(datatable(data.frame("Bu fənn/sinif üçün standart tapılmadı" = character(0))))
      display <- data %>% select(code, description, bloom_level, dok_level)
      names(display) <- c("Kod", "Təsvir", "Bloom", "DOK")
      datatable(display, selection = "multiple", options = list(pageLength = 10,
        language = list(search = "Axtar:", emptyTable = "Standart tapılmadı")))
    })

    # AI Analiz düyməsi
    observeEvent(input$btn_ai_analyze, {
      req(input$ai_subject, input$ai_grade, input$ai_framework, input$ai_ref_country)

      all_stds <- standards_for_analysis()
      selected_rows <- input$standards_select_table_rows_selected

      # Seçilmiş və ya bütün standartlar
      if (!is.null(selected_rows) && length(selected_rows) > 0) {
        stds <- all_stds[selected_rows, ]
      } else {
        stds <- all_stds
      }

      if (nrow(stds) == 0) {
        notify_warning("Analiz üçün standart tapılmadı. Əvvəlcə standart əlavə edin.")
        return()
      }

      standards_text <- paste(sprintf("- %s: %s (Bloom: %s, DOK: %s)",
        stds$code, stds$description, stds$bloom_level %||% "?", stds$dok_level %||% "?"),
        collapse = "\n")

      framework_name <- switch(input$ai_framework,
        pisa = "PISA 2022",
        timss = "TIMSS 2023",
        pirls = "PIRLS 2021",
        oecd2030 = "OECD Öyrənmə Kompası 2030")

      prompt <- paste0(
        "Aşağıdakı Azərbaycan kurikulum standartlarını ", framework_name,
        " beynəlxalq qiymətləndirmə çərçivəsi ilə müqayisə et.\n\n",
        "Fənn: ", input$ai_subject, "\n",
        "Sinif: ", input$ai_grade, "-ci sinif\n",
        "Referans ölkə: ", input$ai_ref_country, "\n\n",
        "Azərbaycan standartları:\n", standards_text, "\n\n",
        "Analiz aşağıdakıları əhatə etməlidir:\n",
        "1. Hər standart üçün ", framework_name, " çərçivəsindəki uyğunluq səviyyəsi (0-100)\n",
        "2. Boşluqlar (gaps) — Azərbaycan standartlarında çatışmayanlar\n",
        "3. ", input$ai_ref_country, " modelindən konkret tövsiyələr\n",
        "4. Bloom/DOK səviyyə müqayisəsi\n\n",
        "Cavabı YALNIZ JSON formatında qaytar:\n",
        "{\n",
        "  \"framework\": \"...\",\n",
        "  \"overall_alignment\": 0-100,\n",
        "  \"dimensions\": [\n",
        "    {\"name\": \"dimension_adi\", \"az_score\": 0-100, \"intl_score\": 0-100, \"gap\": -100-0}\n",
        "  ],\n",
        "  \"standard_alignments\": [\n",
        "    {\"code\": \"...\", \"alignment\": 0-100, \"matching_framework_area\": \"...\", \"note\": \"...\"}\n",
        "  ],\n",
        "  \"gaps\": [\n",
        "    {\"area\": \"...\", \"severity\": \"yüksək|orta|aşağı\", \"description\": \"...\"}\n",
        "  ],\n",
        "  \"recommendations\": [\n",
        "    {\"title\": \"...\", \"description\": \"...\", \"reference_country\": \"...\", \"priority\": \"yüksək|orta|aşağı\"}\n",
        "  ],\n",
        "  \"bloom_comparison\": {\"az_dominant\": \"...\", \"intl_dominant\": \"...\", \"note\": \"...\"},\n",
        "  \"summary\": \"...\"\n",
        "}"
      )

      system_prompt <- paste0(
        "Sən kurikulum müqayisəsi və beynəlxalq qiymətləndirmə çərçivələri (PISA, TIMSS, PIRLS, OECD) üzrə ekspertsən. ",
        "Azərbaycan təhsil standartlarını beynəlxalq çərçivələrlə dəqiq müqayisə edirsən. ",
        "Webb DOK, Bloom taksonomiyası və kompetensiya əsaslı təhlil aparırsan. ",
        "Cavabı YALNIZ düzgün JSON formatında qaytar."
      )

      withProgress(message = "AI analiz aparır...", value = 0.4, {
        result <- tryCatch(
          call_claude_api(prompt, system_prompt, max_tokens = 4096, temperature = 0.4),
          error = function(e) list(success = FALSE, message = e$message)
        )

        if (!result$success) {
          notify_error(paste("AI xətası:", result$message))
          return()
        }

        setProgress(value = 0.8, message = "Nəticə emal edilir...")

        parsed <- tryCatch(
          extract_json_from_response(result$message),
          error = function(e) NULL
        )

        if (is.null(parsed)) {
          notify_error("AI cavabı emal edilə bilmədi. Yenidən cəhd edin.")
          return()
        }

        ai_analysis(parsed)
        setProgress(value = 1)
      })
    })

    # Boşluq Analizi UI
    output$ai_gap_analysis <- renderUI({
      analysis <- ai_analysis()
      if (is.null(analysis)) {
        return(tags$div(style = "text-align: center; color: #999; padding: 30px;",
          icon("search-plus", style = "font-size: 2.5em;"), tags$br(), tags$br(),
          tags$p("Standart seçin və 'AI Analiz' düyməsini basın")
        ))
      }

      # Ümumi uyğunluq
      overall <- analysis$overall_alignment %||% 0
      overall_color <- if (overall >= 70) "#27ae60" else if (overall >= 50) "#f39c12" else "#e74c3c"

      # Boşluqlar
      gaps <- analysis$gaps
      if (is.data.frame(gaps)) {
        gap_items <- lapply(seq_len(nrow(gaps)), function(i) {
          g <- gaps[i, ]
          sev_color <- switch(as.character(g$severity),
            "yüksək" = "#e74c3c", "orta" = "#f39c12", "aşağı" = "#3498db", "#999")
          tags$div(style = "padding: 8px; margin-bottom: 6px; border-left: 4px solid; border-radius: 4px;",
            style = paste0("border-left-color: ", sev_color, "; background: #fafafa;"),
            tags$div(style = "display: flex; justify-content: space-between;",
              tags$strong(g$area),
              tags$span(style = paste0("color:", sev_color, ";font-size:0.85em;font-weight:bold;"),
                toupper(g$severity))
            ),
            tags$p(style = "margin: 4px 0 0; font-size: 0.9em; color: #555;", g$description)
          )
        })
      } else gap_items <- list(tags$p("Boşluq tapılmadı"))

      # Standart uyğunluq cədvəli
      std_align <- analysis$standard_alignments
      std_items <- if (is.data.frame(std_align) && nrow(std_align) > 0) {
        lapply(seq_len(nrow(std_align)), function(i) {
          s <- std_align[i, ]
          pct <- s$alignment %||% 0
          bar_color <- if (pct >= 70) "#27ae60" else if (pct >= 50) "#f39c12" else "#e74c3c"
          tags$div(style = "margin-bottom: 6px;",
            tags$div(style = "display: flex; justify-content: space-between; font-size: 0.85em;",
              tags$strong(s$code), tags$span(paste0(pct, "%"))
            ),
            tags$div(style = "background: #ecf0f1; border-radius: 4px; height: 8px;",
              tags$div(style = paste0("background:", bar_color, ";width:", pct, "%;height:100%;border-radius:4px;"))
            ),
            tags$small(style = "color: #888;", s$matching_framework_area %||% "")
          )
        })
      } else list()

      # Bloom müqayisəsi
      bloom <- analysis$bloom_comparison
      bloom_html <- if (!is.null(bloom)) {
        tags$div(style = "background: #f0f7ff; padding: 10px; border-radius: 6px; margin-top: 10px;",
          tags$strong("Bloom Müqayisəsi: "),
          tags$span(paste0("AZ dominantı: ", bloom$az_dominant %||% "?",
            " | Beynəlxalq: ", bloom$intl_dominant %||% "?")),
          if (!is.null(bloom$note)) tags$p(style = "font-size: 0.85em; color: #555; margin-top: 4px;", bloom$note)
        )
      } else NULL

      tags$div(
        # Ümumi uyğunluq göstəricisi
        tags$div(style = "text-align: center; margin-bottom: 16px;",
          tags$h2(style = paste0("color:", overall_color, ";"), paste0(overall, "%")),
          tags$p("Ümumi Beynəlxalq Uyğunluq Səviyyəsi")
        ),
        # Xülasə
        if (!is.null(analysis$summary))
          tags$div(style = "background: #fafafa; padding: 10px; border-radius: 6px; margin-bottom: 12px; font-size: 0.9em;",
            tags$em(analysis$summary)),
        # Standart uyğunluqları
        if (length(std_items) > 0) tags$div(
          tags$h5("Standart Uyğunluqları:"),
          tags$div(style = "max-height: 250px; overflow-y: auto;", std_items)
        ),
        bloom_html,
        tags$hr(),
        # Boşluqlar
        tags$h5(icon("exclamation-triangle"), "Aşkar Edilən Boşluqlar:"),
        tags$div(gap_items)
      )
    })

    # Vizual Müqayisə Xəritəsi
    output$ai_gap_map <- renderPlotly({
      analysis <- ai_analysis()
      if (is.null(analysis) || is.null(analysis$dimensions)) {
        return(
          plot_ly() %>% layout(
            title = "AI analiz nəticəsi gözlənilir",
            xaxis = list(visible = FALSE), yaxis = list(visible = FALSE),
            annotations = list(list(text = "Standart seçib analiz edin", showarrow = FALSE,
              font = list(size = 14, color = "#999"))))
        )
      }

      dims <- analysis$dimensions
      if (!is.data.frame(dims)) {
        dims <- tryCatch(
          as.data.frame(do.call(rbind, lapply(dims, as.data.frame, stringsAsFactors = FALSE)),
                        stringsAsFactors = FALSE),
          error = function(e) data.frame(name = "?", az_score = 50, intl_score = 80, gap = -30)
        )
      }
      dims$az_score <- as.numeric(dims$az_score)
      dims$intl_score <- as.numeric(dims$intl_score)

      # Radar chart — AZ vs Beynəlxalq
      plot_ly(type = "scatterpolar", fill = "toself") %>%
        add_trace(
          r = c(dims$az_score, dims$az_score[1]),
          theta = c(dims$name, dims$name[1]),
          name = "Azərbaycan", line = list(color = "#e74c3c", width = 2),
          fillcolor = "rgba(231,76,60,0.15)") %>%
        add_trace(
          r = c(dims$intl_score, dims$intl_score[1]),
          theta = c(dims$name, dims$name[1]),
          name = "Beynəlxalq standart", line = list(color = "#3498db", width = 2),
          fillcolor = "rgba(52,152,219,0.15)") %>%
        layout(
          polar = list(radialaxis = list(range = c(0, 100), ticksuffix = "%")),
          title = "Boşluq Xəritəsi",
          legend = list(orientation = "h", y = -0.15)
        )
    })

    # AI Tövsiyələr
    output$ai_recommendations <- renderUI({
      analysis <- ai_analysis()
      if (is.null(analysis) || is.null(analysis$recommendations)) {
        return(tags$div(style = "text-align: center; color: #999; padding: 20px;",
          tags$p("AI analiz tamamlandıqdan sonra tövsiyələr burada göstəriləcək")))
      }

      recs <- analysis$recommendations
      if (!is.data.frame(recs)) {
        recs <- tryCatch(
          as.data.frame(do.call(rbind, lapply(recs, as.data.frame, stringsAsFactors = FALSE)),
                        stringsAsFactors = FALSE),
          error = function(e) data.frame(title = "?", description = "", reference_country = "", priority = "orta")
        )
      }

      rec_items <- lapply(seq_len(nrow(recs)), function(i) {
        r <- recs[i, ]
        priority_color <- switch(as.character(r$priority %||% "orta"),
          "yüksək" = "#e74c3c", "orta" = "#f39c12", "aşağı" = "#3498db", "#999")
        priority_icon <- switch(as.character(r$priority %||% "orta"),
          "yüksək" = "exclamation-circle", "orta" = "info-circle", "aşağı" = "check-circle", "question-circle")

        tags$div(
          style = paste0("border: 1px solid #ddd; border-radius: 8px; padding: 14px; margin-bottom: 10px; ",
            "border-left: 5px solid ", priority_color, ";"),
          tags$div(style = "display: flex; justify-content: space-between; align-items: center;",
            tags$h5(style = "margin: 0;", icon(priority_icon, style = paste0("color:", priority_color)), " ", r$title),
            if (!is.null(r$reference_country) && nchar(r$reference_country) > 0)
              tags$span(class = "label label-primary", style = "font-size: 0.8em;",
                icon("globe"), " ", r$reference_country)
          ),
          tags$p(style = "margin: 8px 0 0; font-size: 0.9em; color: #555;", r$description)
        )
      })

      tags$div(
        fluidRow(
          column(4, tags$div(style = "text-align: center; padding: 8px;",
            tags$span(style = "color: #e74c3c; font-size: 1.2em; font-weight: bold;",
              sum(recs$priority == "yüksək", na.rm = TRUE)),
            tags$br(), tags$small("Yüksək prioritet")
          )),
          column(4, tags$div(style = "text-align: center; padding: 8px;",
            tags$span(style = "color: #f39c12; font-size: 1.2em; font-weight: bold;",
              sum(recs$priority == "orta", na.rm = TRUE)),
            tags$br(), tags$small("Orta prioritet")
          )),
          column(4, tags$div(style = "text-align: center; padding: 8px;",
            tags$span(style = "color: #3498db; font-size: 1.2em; font-weight: bold;",
              sum(recs$priority == "aşağı", na.rm = TRUE)),
            tags$br(), tags$small("Aşağı prioritet")
          ))
        ),
        hr(),
        tags$div(rec_items)
      )
    })
  })
}

#' Kurikulumları müqayisə et
compare_curricula <- function(countries) {
  dimensions <- c("STEM Fokus", "Rəqəmsal Savadlılıq", "Tənqidi Düşüncə",
                   "Yaradıcılıq", "Sosial Bacarıqlar", "Praktik Tətbiq")
  scores <- lapply(countries, function(c) {
    base <- switch(c,
      "Azərbaycan" = c(60, 45, 40, 35, 50, 40),
      "Finlandiya" = c(75, 80, 90, 85, 88, 82),
      "Sinqapur" = c(95, 85, 80, 70, 65, 75),
      "Cənubi Koreya" = c(90, 80, 75, 65, 60, 70),
      "Estoniya" = c(80, 82, 85, 75, 78, 80),
      "Yaponiya" = c(88, 78, 72, 68, 62, 75),
      "Türkiyə" = c(65, 55, 50, 45, 55, 50),
      sample(40:80, 6))
  })
  list(countries = countries, dimensions = dimensions, scores = scores)
}
