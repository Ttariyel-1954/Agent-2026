# =============================================
# ARTI-2026: Strategiya Modulu — Server Məntiqi
# =============================================

# === 1. SWOT Analiz Server ===
strategy_swot_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Məktəb siyahısını yüklə
    observe({
      choices <- get_school_choices(db_pool)
      updateSelectInput(session, "school_filter", choices = choices)
    })

    # Analiz nəticəsi
    analysis_result <- reactiveVal(NULL)

    # === Ümumi statistika ===
    summary_data <- reactive({
      get_district_summary(db_pool)
    })

    output$vb_schools <- renderValueBox({
      s <- summary_data()
      valueBox(s$total_schools, "Məktəb", icon = icon("school"), color = "purple")
    })

    output$vb_students <- renderValueBox({
      s <- summary_data()
      valueBox(format(s$total_students, big.mark = "."), "Şagird", icon = icon("user-graduate"), color = "aqua")
    })

    output$vb_teachers <- renderValueBox({
      s <- summary_data()
      valueBox(format(s$total_teachers, big.mark = "."), "Müəllim", icon = icon("chalkboard-teacher"), color = "green")
    })

    output$vb_avg_score <- renderValueBox({
      s <- summary_data()
      valueBox(paste0(s$avg_score, "%"), "Orta Bal", icon = icon("chart-line"), color = "yellow")
    })

    # === Məktəb müqayisə cədvəli ===
    output$schools_table <- renderDT({
      data <- get_schools_comparison_table(db_pool)
      datatable(data, options = default_dt_options(20), rownames = FALSE,
        colnames = c("Məktəb", "Növ", "Rayon", "Şagird", "Müəllim", "Nisbət", "Orta Bal")
      ) %>%
        formatStyle("avg_score", backgroundColor = styleInterval(
          c(50, 70, 85), c("#e74c3c33", "#f39c1233", "#2980b933", "#27ae6033")
        ))
    })

    # === AI Analiz Generasiyası ===
    observeEvent(input$btn_generate, {
      school_id <- if (input$school_filter == "") NULL else input$school_filter
      report_type <- input$report_type

      withProgress(message = "AI strateji analiz hazırlanır...", value = 0.3, {
        result <- tryCatch({
          switch(report_type,
            "swot" = generate_swot_analysis(db_pool, school_id, input$academic_year,
                                             user_data()$id),
            "resource_allocation" = generate_resource_recommendations(db_pool, input$academic_year,
                                                                      user_data()$id),
            "teacher_optimization" = generate_teacher_optimization(db_pool, input$academic_year,
                                                                    user_data()$id),
            generate_swot_analysis(db_pool, school_id, input$academic_year, user_data()$id)
          )
        }, error = function(e) {
          list(success = FALSE, error = e$message)
        })

        setProgress(1)
      })

      if (isTRUE(result$success)) {
        analysis_result(result$data)
        notify_success("Strateji analiz uğurla hazırlandı!")
      } else {
        notify_error(paste("Xəta:", result$error %||% "Naməlum xəta"))
      }
    })

    # === SWOT Nəticəsi ===
    output$swot_result_ui <- renderUI({
      res <- analysis_result()
      if (is.null(res)) return(NULL)

      strengths <- res$strengths
      weaknesses <- res$weaknesses
      opportunities <- res$opportunities
      threats <- res$threats

      if (is.null(strengths) && is.null(weaknesses)) return(NULL)

      tagList(
        fluidRow(column(12, hr(), h3(icon("th-large"), "SWOT Analiz Nəticəsi",
          tags$small(class = "text-muted", paste(" —", res$analysis_title %||% ""))))),
        fluidRow(
          # Güclü tərəflər
          column(6, wellPanel(style = paste0("border-left: 5px solid ", SWOT_COLORS$strengths),
            h4(icon("check-circle"), "Güclü Tərəflər", style = paste0("color:", SWOT_COLORS$strengths)),
            tags$ul(lapply(strengths, function(s) {
              tags$li(tags$strong(s$item %||% s), tags$br(),
                      tags$small(class = "text-muted", s$metric %||% ""))
            }))
          )),
          # Zəif tərəflər
          column(6, wellPanel(style = paste0("border-left: 5px solid ", SWOT_COLORS$weaknesses),
            h4(icon("times-circle"), "Zəif Tərəflər", style = paste0("color:", SWOT_COLORS$weaknesses)),
            tags$ul(lapply(weaknesses, function(w) {
              severity_badge <- switch(w$severity %||% "medium",
                "high" = tags$span(class = "label label-danger", "Yüksək"),
                "medium" = tags$span(class = "label label-warning", "Orta"),
                tags$span(class = "label label-info", "Aşağı"))
              tags$li(tags$strong(w$item %||% w), " ", severity_badge, tags$br(),
                      tags$small(class = "text-muted", w$metric %||% ""))
            }))
          ))
        ),
        fluidRow(
          # İmkanlar
          column(6, wellPanel(style = paste0("border-left: 5px solid ", SWOT_COLORS$opportunities),
            h4(icon("lightbulb"), "İmkanlar", style = paste0("color:", SWOT_COLORS$opportunities)),
            tags$ul(lapply(opportunities, function(o) {
              tags$li(tags$strong(o$item %||% o), tags$br(),
                      tags$small(class = "text-muted",
                        sprintf("Təsir: %s | Müddət: %s", o$potential_impact %||% "N/A", o$timeframe %||% "N/A")))
            }))
          )),
          # Təhdidlər
          column(6, wellPanel(style = paste0("border-left: 5px solid ", SWOT_COLORS$threats),
            h4(icon("exclamation-triangle"), "Təhdidlər", style = paste0("color:", SWOT_COLORS$threats)),
            tags$ul(lapply(threats, function(t) {
              risk_badge <- switch(t$risk_level %||% "medium",
                "high" = tags$span(class = "label label-danger", "Yüksək Risk"),
                "medium" = tags$span(class = "label label-warning", "Orta Risk"),
                tags$span(class = "label label-info", "Aşağı Risk"))
              tags$li(tags$strong(t$item %||% t), " ", risk_badge, tags$br(),
                      tags$small(class = "text-muted", t$mitigation %||% ""))
            }))
          ))
        ),
        # Ümumi bal və hərəkət planı
        if (!is.null(res$overall_score) || !is.null(res$key_actions)) {
          fluidRow(column(12, wellPanel(
            fluidRow(
              column(3,
                h4("Ümumi Qiymət"),
                tags$h1(class = "text-center", style = paste0("color:", get_grade_color(res$overall_score %||% 0)),
                        paste0(res$overall_score %||% 0, "/100"))
              ),
              column(9,
                h4(icon("tasks"), "Prioritet Hərəkətlər"),
                tags$ol(lapply(res$key_actions %||% list(), function(a) tags$li(a)))
              )
            )
          )))
        }
      )
    })

    # === Resurs Tövsiyələri ===
    output$resource_recommendations_ui <- renderUI({
      res <- analysis_result()
      if (is.null(res) || is.null(res$resource_recommendations)) return(NULL)

      recs <- res$resource_recommendations
      fluidRow(column(12, wellPanel(
        h4(icon("balance-scale"), "Resurs Bölgüsü Tövsiyələri"),
        tags$div(class = "table-responsive",
          tags$table(class = "table table-striped table-bordered",
            tags$thead(tags$tr(
              tags$th("Məktəb"), tags$th("Cari Vəziyyət"), tags$th("Tövsiyə"),
              tags$th("Prioritet"), tags$th("Gözlənilən Təsir")
            )),
            tags$tbody(lapply(recs, function(r) {
              priority_class <- switch(r$priority %||% "medium",
                "high" = "danger", "medium" = "warning", "info")
              tags$tr(
                tags$td(r$school %||% "N/A"),
                tags$td(r$current_status %||% "N/A"),
                tags$td(tags$strong(r$recommendation %||% "N/A")),
                tags$td(tags$span(class = paste0("label label-", priority_class),
                                  toupper(r$priority %||% "orta"))),
                tags$td(r$estimated_impact %||% "N/A")
              )
            }))
          )
        )
      )))
    })

    # === Müəllim Optimallaşdırma ===
    output$teacher_optimization_ui <- renderUI({
      res <- analysis_result()
      if (is.null(res) || is.null(res$teacher_optimization)) return(NULL)

      opts <- res$teacher_optimization
      fluidRow(column(12, wellPanel(
        h4(icon("exchange-alt"), "Müəllim Yerləşdirmə Optimallaşdırması"),
        tags$div(class = "table-responsive",
          tags$table(class = "table table-striped",
            tags$thead(tags$tr(
              tags$th("Əməliyyat"), tags$th("Haradan"), tags$th("Haraya"),
              tags$th("Fənn"), tags$th("Əsaslandırma")
            )),
            tags$tbody(lapply(opts, function(o) {
              tags$tr(
                tags$td(tags$strong(o$action %||% "N/A")),
                tags$td(o$from_school %||% "—"),
                tags$td(o$to_school %||% "—"),
                tags$td(o$subject %||% "N/A"),
                tags$td(tags$small(o$rationale %||% ""))
              )
            }))
          )
        )
      )))
    })

    # === Büdcə Prioritetləri ===
    output$budget_priorities_ui <- renderUI({
      res <- analysis_result()
      if (is.null(res) || is.null(res$budget_priorities)) return(NULL)

      bps <- res$budget_priorities
      fluidRow(column(12, wellPanel(
        h4(icon("money-bill-wave"), "Büdcə Prioritetləri"),
        tags$div(class = "table-responsive",
          tags$table(class = "table table-bordered",
            tags$thead(tags$tr(
              tags$th("#"), tags$th("Sahə"), tags$th("Cari %"), tags$th("Tövsiyə %"), tags$th("Əsas")
            )),
            tags$tbody(lapply(bps, function(b) {
              tags$tr(
                tags$td(tags$strong(b$rank %||% "")),
                tags$td(b$area %||% "N/A"),
                tags$td(b$current_allocation %||% "N/A"),
                tags$td(tags$strong(b$recommended %||% "N/A")),
                tags$td(tags$small(b$justification %||% ""))
              )
            }))
          )
        )
      )))
    })

    # === Excel ixracı ===
    output$btn_export <- downloadHandler(
      filename = function() {
        paste0("strategy_swot_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".xlsx")
      },
      content = function(file) {
        data <- get_schools_comparison_table(db_pool)
        export_to_excel(data, file, "SWOT Analiz")
      }
    )

    # === Keçmiş hesabatlar ===
    output$reports_history <- renderDT({
      data <- get_strategy_reports(db_pool)
      if (is.null(data) || nrow(data) == 0) {
        return(datatable(data.frame(Mesaj = "Hesabat yoxdur"), rownames = FALSE))
      }
      data$report_type <- sapply(data$report_type, function(t) REPORT_TYPE_LABELS[t] %||% t)
      data$created_at <- format_datetime_az(data$created_at)
      datatable(data[, c("title", "report_type", "school_name", "academic_year", "created_at")],
        options = default_dt_options(10), rownames = FALSE,
        colnames = c("Başlıq", "Növ", "Məktəb", "Tədris İli", "Tarix"))
    })
  })
}

# === 2. Resurs Bölgüsü Server ===
strategy_resources_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {

    # === Müəllim-Şagird nisbəti ===
    output$ratio_chart <- renderPlotly({
      data <- get_schools_comparison_table(db_pool)
      if (is.null(data) || nrow(data) == 0) return(plotly_empty())

      plot_ly(data, x = ~reorder(school_name, -student_teacher_ratio),
              y = ~student_teacher_ratio, type = "bar",
              marker = list(color = ~ifelse(student_teacher_ratio > 20, "#e74c3c",
                                            ifelse(student_teacher_ratio > 15, "#f39c12", "#27ae60"))),
              text = ~paste0(school_name, "\nNisbət: ", student_teacher_ratio),
              hoverinfo = "text") %>%
        layout(
          xaxis = list(title = "", tickangle = -45),
          yaxis = list(title = "Şagird/Müəllim Nisbəti"),
          shapes = list(
            list(type = "line", x0 = -0.5, x1 = nrow(data) - 0.5,
                 y0 = 15, y1 = 15, line = list(color = "#3498db", dash = "dash", width = 2))
          ),
          annotations = list(
            list(x = nrow(data) - 1, y = 15.5, text = "OECD optimal (15:1)",
                 showarrow = FALSE, font = list(size = 10, color = "#3498db"))
          )
        )
    })

    # === Kateqoriya paylanması ===
    output$category_chart <- renderPlotly({
      data <- get_teacher_distribution(db_pool)
      if (is.null(data) || nrow(data) == 0) return(plotly_empty())

      cat_summary <- aggregate(teacher_count ~ school_name + category, data = data, FUN = sum)
      plot_ly(cat_summary, x = ~school_name, y = ~teacher_count, color = ~category,
              type = "bar", colors = c("#27ae60", "#2980b9", "#f39c12", "#e74c3c")) %>%
        layout(barmode = "stack",
               xaxis = list(title = "", tickangle = -45),
               yaxis = list(title = "Müəllim Sayı"),
               legend = list(orientation = "h", y = -0.3))
    })

    # === Fənn əhatə matrisi ===
    output$coverage_table <- renderDT({
      data <- get_subject_coverage(db_pool)
      if (is.null(data) || nrow(data) == 0) {
        return(datatable(data.frame(Mesaj = "Data yoxdur"), rownames = FALSE))
      }
      datatable(data, options = default_dt_options(20), rownames = FALSE,
        colnames = c("Məktəb", "Fənn", "Müəllim Sayı", "Sinif Sayı", "Əhatə Nisbəti")
      ) %>%
        formatStyle("coverage_ratio", backgroundColor = styleInterval(
          c(0.5, 0.8, 1.0), c("#e74c3c33", "#f39c1233", "#2ecc7133", "#27ae6033")
        ))
    })

    # === TALIS Heatmap ===
    output$talis_heatmap <- renderPlotly({
      data <- get_school_talis_averages(db_pool)
      if (is.null(data) || nrow(data) == 0) return(plotly_empty())

      indicators <- c("self_efficacy", "job_satisfaction", "classroom_management",
                       "cpd_impact", "collaboration")
      labels <- c("Effektivlik", "Məmnuniyyət", "Sinif İdarə", "PKİ Təsiri", "Əməkdaşlıq")

      values <- as.matrix(data[, indicators, drop = FALSE])
      rownames(values) <- data$school_name

      plot_ly(x = labels, y = data$school_name, z = values, type = "heatmap",
              colorscale = list(c(0, "#e74c3c"), c(0.5, "#f39c12"), c(1, "#27ae60")),
              text = round(values, 1), hoverinfo = "text+x+y") %>%
        layout(
          xaxis = list(title = ""),
          yaxis = list(title = "", autorange = "reversed"),
          margin = list(l = 150)
        )
    })

    # === Performans trendi ===
    output$trend_chart <- renderPlotly({
      data <- get_performance_trend_by_school(db_pool)
      if (is.null(data) || nrow(data) == 0) return(plotly_empty())

      plot_ly(data, x = ~month, y = ~avg_score, color = ~school_name,
              type = "scatter", mode = "lines+markers") %>%
        layout(
          xaxis = list(title = "Ay"),
          yaxis = list(title = "Orta Bal", range = c(0, 100)),
          legend = list(orientation = "h", y = -0.3)
        )
    })
  })
}

# === 3. What-If Scenari Server ===
strategy_whatif_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Məktəb siyahısı
    observe({
      choices <- get_school_choices(db_pool)
      updateSelectInput(session, "scenario_school", choices = choices)
    })

    scenario_result <- reactiveVal(NULL)

    # === Scenarini işlət ===
    observeEvent(input$btn_run_scenario, {
      req(input$scenario_type)

      # Parametrləri topla
      params <- list()
      desc <- input$scenario_desc %||% ""

      if (input$scenario_type == "teacher_hire") {
        params$teacher_count <- input$param_teacher_count
        params$subject <- input$param_teacher_subject
        if (desc == "") desc <- sprintf("%d yeni %s müəllimi işə götürmək",
                                        params$teacher_count, params$subject %||% "müxtəlif fənn")
      } else if (input$scenario_type == "budget_change") {
        params$budget_pct <- input$param_budget_pct
        params$area <- input$param_budget_area
        if (desc == "") desc <- sprintf("Büdcəni %s sahəsində %+d%% dəyişdirmək",
                                        params$area, params$budget_pct)
      } else if (input$scenario_type == "class_restructure") {
        params$max_class_size <- input$param_max_class_size
        params$min_class_size <- input$param_min_class_size
        if (desc == "") desc <- sprintf("Sinif ölçüsünü %d-%d aralığına gətirmək",
                                        params$min_class_size, params$max_class_size)
      }

      if (desc == "") {
        notify_warning("Scenari təsviri daxil edin")
        return()
      }

      school_id <- if (input$scenario_school == "") NULL else input$scenario_school

      withProgress(message = "AI scenarini modelləşdirir...", value = 0.4, {
        result <- tryCatch({
          run_whatif_scenario(
            db_pool = db_pool,
            scenario_type = input$scenario_type,
            scenario_desc = desc,
            school_id = school_id,
            parameters = params,
            user_id = user_data()$id
          )
        }, error = function(e) {
          list(success = FALSE, error = e$message)
        })
        setProgress(1)
      })

      if (isTRUE(result$success)) {
        scenario_result(result$data)
        notify_success("Scenari analizi tamamlandı!")
      } else {
        notify_error(paste("Xəta:", result$error %||% "Naməlum xəta"))
      }
    })

    # === Scenari xülasəsi ===
    output$scenario_summary_ui <- renderUI({
      res <- scenario_result()
      if (is.null(res)) {
        return(wellPanel(
          h4(icon("info-circle"), "Scenari Nəticəsi"),
          tags$p(class = "text-muted", "Scenari parametrlərini seçib \"İşlət\" düyməsinə basın")
        ))
      }

      feasibility_color <- if ((res$feasibility_score %||% 0) >= 70) "#27ae60"
                           else if ((res$feasibility_score %||% 0) >= 40) "#f39c12" else "#e74c3c"
      risk_badge <- switch(res$risk_level %||% "medium",
        "low" = tags$span(class = "label label-success", "Aşağı Risk"),
        "medium" = tags$span(class = "label label-warning", "Orta Risk"),
        tags$span(class = "label label-danger", "Yüksək Risk"))

      wellPanel(
        h4(icon("chart-pie"), res$scenario_name %||% "Scenari Nəticəsi"),
        fluidRow(
          column(4, tags$div(class = "text-center",
            tags$h5("Reallıq Balı"),
            tags$h2(style = paste0("color:", feasibility_color),
                    paste0(res$feasibility_score %||% 0, "/100"))
          )),
          column(4, tags$div(class = "text-center",
            tags$h5("Risk Səviyyəsi"), tags$h2(risk_badge)
          )),
          column(4, tags$div(class = "text-center",
            tags$h5("Uğur Ehtimalı"),
            tags$h2(paste0(res$success_probability %||% 0, "%"))
          ))
        ),
        tags$p(tags$strong("Xülasə: "), res$scenario_summary %||% ""),
        tags$p(tags$strong("Son Tövsiyə: "), res$recommendation %||% "")
      )
    })

    # === Təsirlər ===
    output$scenario_impacts_ui <- renderUI({
      res <- scenario_result()
      if (is.null(res) || is.null(res$impacts)) return(NULL)

      render_impact_section <- function(impacts, title, icon_name) {
        if (is.null(impacts) || length(impacts) == 0) return(NULL)
        wellPanel(
          h5(icon(icon_name), title),
          tags$ul(lapply(impacts, function(imp) {
            conf_badge <- switch(imp$confidence %||% "medium",
              "high" = tags$span(class = "label label-success", "Yüksək"),
              "medium" = tags$span(class = "label label-warning", "Orta"),
              tags$span(class = "label label-info", "Aşağı"))
            tags$li(
              tags$strong(imp$area %||% "N/A"), ": ",
              tags$span(style = paste0("color:", ifelse(grepl("^\\+", imp$change %||% ""), "#27ae60", "#e74c3c")),
                        imp$change %||% "N/A"), " — ",
              imp$description %||% "", " ", conf_badge
            )
          }))
        )
      }

      tagList(
        render_impact_section(res$impacts$short_term, "Qısamüddətli Təsir (1 yarımil)", "clock"),
        render_impact_section(res$impacts$medium_term, "Ortamüddətli Təsir (1 il)", "calendar"),
        render_impact_section(res$impacts$long_term, "Uzunmüddətli Təsir (3 il)", "calendar-alt")
      )
    })

    # === Büdcə təsiri ===
    output$scenario_budget_ui <- renderUI({
      res <- scenario_result()
      if (is.null(res) || is.null(res$budget_impact)) return(NULL)

      bi <- res$budget_impact
      wellPanel(
        h5(icon("money-bill-wave"), "Büdcə Təsiri"),
        fluidRow(
          column(3, tags$div(class = "text-center",
            tags$small("Əlavə Xərc"), tags$h4(style = "color:#e74c3c", bi$additional_cost %||% "N/A"))),
          column(3, tags$div(class = "text-center",
            tags$small("Qənaət"), tags$h4(style = "color:#27ae60", bi$savings %||% "N/A"))),
          column(3, tags$div(class = "text-center",
            tags$small("Xalis Təsir"), tags$h4(bi$net_impact %||% "N/A"))),
          column(3, tags$div(class = "text-center",
            tags$small("ROI"), tags$h4(bi$roi_estimate %||% "N/A")))
        )
      )
    })

    # === Risklər ===
    output$scenario_risks_ui <- renderUI({
      res <- scenario_result()
      if (is.null(res) || is.null(res$risks)) return(NULL)

      wellPanel(
        h5(icon("exclamation-triangle"), "Risklər"),
        tags$div(class = "table-responsive",
          tags$table(class = "table table-striped",
            tags$thead(tags$tr(tags$th("Risk"), tags$th("Ehtimal"), tags$th("Təsir"), tags$th("Azaltma"))),
            tags$tbody(lapply(res$risks, function(r) {
              tags$tr(
                tags$td(r$risk %||% "N/A"),
                tags$td(tags$span(class = paste0("label label-",
                  switch(r$probability %||% "medium", "high" = "danger", "medium" = "warning", "info")),
                  r$probability %||% "N/A")),
                tags$td(tags$span(class = paste0("label label-",
                  switch(r$impact %||% "medium", "high" = "danger", "medium" = "warning", "info")),
                  r$impact %||% "N/A")),
                tags$td(tags$small(r$mitigation %||% ""))
              )
            }))
          )
        )
      )
    })

    # === Alternativlər ===
    output$scenario_alternatives_ui <- renderUI({
      res <- scenario_result()
      if (is.null(res) || is.null(res$alternatives)) return(NULL)

      wellPanel(
        h5(icon("code-branch"), "Alternativ Yanaşmalar"),
        lapply(res$alternatives, function(alt) {
          tags$div(class = "well well-sm",
            tags$h6(tags$strong(alt$option %||% "N/A")),
            fluidRow(
              column(6, tags$small(class = "text-success", icon("plus-circle"), " ", alt$pros %||% "")),
              column(6, tags$small(class = "text-danger", icon("minus-circle"), " ", alt$cons %||% ""))
            )
          )
        })
      )
    })

    # === Scenari tarixçəsi ===
    output$scenario_history <- renderDT({
      data <- get_scenario_history(db_pool)
      if (is.null(data) || nrow(data) == 0) {
        return(datatable(data.frame(Mesaj = "Scenari tarixçəsi yoxdur"), rownames = FALSE))
      }
      data$scenario_type <- sapply(data$scenario_type, function(t) SCENARIO_TYPES[t] %||% t)
      data$risk_level <- sapply(data$risk_level %||% rep("N/A", nrow(data)), function(r) {
        switch(r %||% "N/A", "low" = "Aşağı", "medium" = "Orta", "high" = "Yüksək", r)
      })
      data$created_at <- format_datetime_az(data$created_at)
      datatable(data[, c("scenario_name", "scenario_type", "school_name", "impact_score", "risk_level", "created_at")],
        options = default_dt_options(10), rownames = FALSE,
        colnames = c("Scenari", "Növ", "Məktəb", "Reallıq", "Risk", "Tarix"))
    })
  })
}

# === 4. Beynəlxalq Benchmark Server ===
strategy_benchmark_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # === PISA Bar Chart ===
    output$pisa_bar_chart <- renderPlotly({
      selected <- input$selected_countries
      pisa <- get_pisa_comparison_df()
      pisa <- pisa[pisa$country %in% c(selected, "OECD Orta"), ]

      if (nrow(pisa) == 0) return(plotly_empty())

      pisa_long <- tidyr::pivot_longer(pisa, cols = c("math", "reading", "science"),
                                        names_to = "subject", values_to = "score")
      pisa_long$subject <- recode(pisa_long$subject,
        math = "Riyaziyyat", reading = "Oxu", science = "Elm")

      plot_ly(pisa_long, x = ~country, y = ~score, color = ~subject,
              type = "bar", colors = c("#e74c3c", "#3498db", "#27ae60")) %>%
        layout(barmode = "group",
               xaxis = list(title = "", tickangle = -30),
               yaxis = list(title = "PISA Balı", range = c(300, 600)),
               legend = list(orientation = "h", y = -0.25))
    })

    # === PISA Radar ===
    output$pisa_radar_chart <- renderPlotly({
      selected <- input$selected_countries
      pisa <- get_pisa_comparison_df()
      pisa <- pisa[pisa$country %in% c(selected, "OECD Orta"), ]

      if (nrow(pisa) == 0) return(plotly_empty())

      categories <- c("Riyaziyyat", "Oxu", "Elm")

      p <- plot_ly(type = "scatterpolar", fill = "toself")
      for (i in seq_len(nrow(pisa))) {
        p <- p %>% add_trace(
          r = c(pisa$math[i], pisa$reading[i], pisa$science[i], pisa$math[i]),
          theta = c(categories, categories[1]),
          name = pisa$country[i],
          opacity = 0.6
        )
      }

      p %>% layout(
        polar = list(
          radialaxis = list(visible = TRUE, range = c(300, 600))
        ),
        legend = list(orientation = "h", y = -0.2)
      )
    })

    # === PISA Cədvəl ===
    output$pisa_table <- renderDT({
      pisa <- get_pisa_comparison_df()
      selected <- input$selected_countries
      pisa <- pisa[pisa$country %in% c(selected, "OECD Orta"), ]

      datatable(pisa, options = default_dt_options(10), rownames = FALSE,
        colnames = c("Ölkə", "Riyaziyyat", "Oxu", "Elm", "İl")
      ) %>%
        formatStyle("math", backgroundColor = styleInterval(c(450, 500), c("#f39c1233", "#3498db33", "#27ae6033"))) %>%
        formatStyle("reading", backgroundColor = styleInterval(c(450, 500), c("#f39c1233", "#3498db33", "#27ae6033"))) %>%
        formatStyle("science", backgroundColor = styleInterval(c(450, 500), c("#f39c1233", "#3498db33", "#27ae6033")))
    })

    # === TALIS Bar ===
    output$talis_bar_chart <- renderPlotly({
      selected <- input$selected_countries
      talis <- get_talis_comparison_df()
      talis <- talis[talis$country %in% c(selected, "OECD Orta"), ]

      if (nrow(talis) == 0) return(plotly_empty())

      talis_long <- tidyr::pivot_longer(talis,
        cols = c("self_efficacy", "job_satisfaction", "classroom_mgmt", "collaboration", "ict_usage"),
        names_to = "indicator", values_to = "value")
      talis_long$indicator <- recode(talis_long$indicator,
        self_efficacy = "Effektivlik", job_satisfaction = "Məmnuniyyət",
        classroom_mgmt = "Sinif İdarə", collaboration = "Əməkdaşlıq", ict_usage = "İKT")

      plot_ly(talis_long, x = ~country, y = ~value, color = ~indicator,
              type = "bar", colors = c("#2c3e50", "#2980b9", "#27ae60", "#f39c12", "#e74c3c")) %>%
        layout(barmode = "group",
               xaxis = list(title = "", tickangle = -30),
               yaxis = list(title = "Bal (1-10)", range = c(0, 10)),
               legend = list(orientation = "h", y = -0.25))
    })

    # === TALIS Radar ===
    output$talis_radar_chart <- renderPlotly({
      selected <- input$selected_countries
      talis <- get_talis_comparison_df()
      talis <- talis[talis$country %in% c(selected, "OECD Orta"), ]

      if (nrow(talis) == 0) return(plotly_empty())

      categories <- c("Effektivlik", "Məmnuniyyət", "Sinif İdarə", "Əməkdaşlıq", "İKT")

      p <- plot_ly(type = "scatterpolar", fill = "toself")
      for (i in seq_len(nrow(talis))) {
        vals <- c(talis$self_efficacy[i], talis$job_satisfaction[i], talis$classroom_mgmt[i],
                  talis$collaboration[i], talis$ict_usage[i])
        p <- p %>% add_trace(
          r = c(vals, vals[1]), theta = c(categories, categories[1]),
          name = talis$country[i], opacity = 0.6)
      }

      p %>% layout(
        polar = list(radialaxis = list(visible = TRUE, range = c(0, 10))),
        legend = list(orientation = "h", y = -0.2)
      )
    })

    # === TALIS Cədvəl ===
    output$talis_table <- renderDT({
      talis <- get_talis_comparison_df()
      selected <- input$selected_countries
      talis <- talis[talis$country %in% c(selected, "OECD Orta"), ]

      datatable(talis, options = default_dt_options(10), rownames = FALSE,
        colnames = c("Ölkə", "Effektivlik", "Məmnuniyyət", "Sinif İdarə", "PKİ Saatları", "Əməkdaşlıq", "İKT")
      )
    })

    # === OECD Boşluq Analizi ===
    output$gap_chart <- renderPlotly({
      talis <- get_talis_comparison_df()
      az <- talis[talis$country == "Azərbaycan", ]
      oecd <- talis[talis$country == "OECD Orta", ]

      if (nrow(az) == 0 || nrow(oecd) == 0) return(plotly_empty())

      indicators <- c("Effektivlik", "Məmnuniyyət", "Sinif İdarə", "Əməkdaşlıq", "İKT")
      az_vals <- c(az$self_efficacy, az$job_satisfaction, az$classroom_mgmt, az$collaboration, az$ict_usage)
      oecd_vals <- c(oecd$self_efficacy, oecd$job_satisfaction, oecd$classroom_mgmt, oecd$collaboration, oecd$ict_usage)
      gaps <- az_vals - oecd_vals

      colors <- ifelse(gaps >= 0, "#27ae60", "#e74c3c")

      plot_ly(x = indicators, y = gaps, type = "bar",
              marker = list(color = colors),
              text = sprintf("%+.1f", gaps), textposition = "outside") %>%
        layout(
          xaxis = list(title = ""),
          yaxis = list(title = "OECD Fərqi", zeroline = TRUE),
          shapes = list(
            list(type = "line", x0 = -0.5, x1 = length(indicators) - 0.5,
                 y0 = 0, y1 = 0, line = list(color = "#333", width = 2))
          )
        )
    })

    # === Benchmark datası əlavə et ===
    observeEvent(input$btn_add_benchmark, {
      req(input$bm_country, input$bm_indicator, input$bm_value)

      save_benchmark_entry(db_pool,
        country = input$bm_country,
        indicator = input$bm_indicator,
        category = input$bm_category,
        value = input$bm_value,
        year = input$bm_year,
        source = input$bm_source
      )
      notify_success("Benchmark datası əlavə edildi")
    })

    # === Benchmark DB cədvəli ===
    output$benchmark_db_table <- renderDT({
      input$btn_add_benchmark  # reaktivlik
      data <- get_benchmark_data(db_pool)
      if (is.null(data) || nrow(data) == 0) {
        return(datatable(data.frame(Mesaj = "Benchmark datası yoxdur"), rownames = FALSE))
      }
      datatable(data, options = default_dt_options(10), rownames = FALSE,
        colnames = c("Ölkə", "Göstərici", "Kateqoriya", "Dəyər", "İl", "Mənbə"))
    })
  })
}
