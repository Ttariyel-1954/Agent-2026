# =============================================
# ARTI-2026: Müəllim Modulu - Server Məntiqi
# =============================================

teacher_list_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    teachers <- reactive({
      query <- "SELECT t.*, s.name as school_name FROM teachers t
                LEFT JOIN schools s ON t.school_id = s.id WHERE 1=1"
      params <- list(); i <- 1
      if (!is_empty(input$filter_category)) {
        query <- paste0(query, " AND t.category = $", i); params[[i]] <- input$filter_category; i <- i+1
      }
      if (!is_empty(input$filter_honorary)) {
        query <- paste0(query, " AND t.honorary_title = $", i); params[[i]] <- input$filter_honorary; i <- i+1
      }
      if (!is_empty(input$filter_ict)) {
        query <- paste0(query, " AND t.ict_competency_level = $", i); params[[i]] <- input$filter_ict; i <- i+1
      }
      if (!is_empty(input$search_text)) {
        query <- paste0(query, " AND (t.first_name ILIKE $", i, " OR t.last_name ILIKE $", i, ")")
        params[[i]] <- paste0("%", input$search_text, "%")
      }
      query <- paste0(query, " ORDER BY t.last_name")
      if (length(params) > 0) db_query(db_pool, query, params = params) else db_query(db_pool, query)
    })

    output$teacher_table <- renderDT({
      data <- teachers()
      if (nrow(data) == 0) return(datatable(data.frame()))
      display <- data %>% select(first_name, last_name, specialization, category, experience_years,
                                   school_name, ict_competency_level, certification_score, status)
      names(display) <- c("Ad", "Soyad", "İxtisas", "Kateqoriya", "Təcrübə", "Məktəb", "İKT", "Sert.bal", "Status")
      datatable(display, selection = "single", options = default_dt_options())
    })

    output$btn_export <- downloadHandler(
      filename = function() paste0("muellimlər_", format(Sys.Date(), "%Y%m%d"), ".xlsx"),
      content = function(file) export_to_excel(teachers(), file, "Müəllimlər")
    )
  })
}

teacher_workload_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    observe({
      teachers <- db_query(db_pool, "SELECT id, first_name || ' ' || last_name as name FROM teachers ORDER BY name")
      if (nrow(teachers) > 0) updateSelectInput(session, "selected_teacher", choices = setNames(teachers$id, teachers$name))
    })

    total_hours_val <- reactive({
      req(input$selected_teacher)
      result <- db_query(db_pool, "SELECT COUNT(*) as hours FROM teacher_schedule WHERE teacher_id = $1",
                         params = list(input$selected_teacher))
      if (nrow(result) > 0) as.integer(result$hours[1]) else 0L
    })

    output$total_hours <- renderText({
      as.character(total_hours_val())
    })

    output$workload_status <- renderUI({
      hours <- total_hours_val()
      if (hours < 18) tags$h2("Aşağı", class = "text-danger text-center")
      else if (hours <= 36) tags$h2("Normal", class = "text-success text-center")
      else tags$h2("Yüksək", class = "text-warning text-center")
    })

    output$schedule_grid <- renderUI({
      days <- WEEKDAYS_AZ
      periods <- 1:7
      tags$table(class = "table table-bordered table-sm",
        tags$thead(tags$tr(tags$th("Saat"), lapply(days, tags$th))),
        tags$tbody(lapply(periods, function(p) {
          tags$tr(tags$td(tags$strong(paste0(p, ". dərs"))),
            lapply(seq_along(days), function(d) tags$td(
              selectInput(session$ns(paste0("cell_", d, "_", p)), NULL,
                choices = c("-" = "", SUBJECTS), width = "100%")
            )))
        }))
      )
    })

    output$subject_chart <- renderPlotly({
      plot_ly(labels = ~c("Riyaziyyat", "Fizika", "Digər"), values = ~c(12, 8, 4),
              type = "pie", marker = list(colors = c("#3498db", "#e74c3c", "#2ecc71")))
    })

    output$daily_chart <- renderPlotly({
      plot_ly(x = ~WEEKDAYS_AZ, y = ~c(5, 6, 4, 5, 4), type = "bar",
              marker = list(color = "#3498db")) %>%
        layout(xaxis = list(title = ""), yaxis = list(title = "Saat"))
    })
  })
}

teacher_development_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    observe({
      teachers <- db_query(db_pool, "SELECT id, first_name || ' ' || last_name as name FROM teachers ORDER BY name")
      if (nrow(teachers) > 0) updateSelectInput(session, "selected_teacher", choices = setNames(teachers$id, teachers$name))
    })
    output$training_count <- renderText({ "12" })
    output$cert_count <- renderText({ "5" })
    output$training_hours <- renderText({ "180" })
    output$next_attestation <- renderText({ "2026-09" })

    output$training_table <- renderDT({
      req(input$selected_teacher)
      data <- db_query(db_pool,
        "SELECT title, training_type, provider, start_date, end_date, hours, status
         FROM teacher_trainings WHERE teacher_id = $1 ORDER BY start_date DESC",
        params = list(input$selected_teacher))
      if (nrow(data) == 0) data <- data.frame(title="Məlumat yoxdur", training_type="-", provider="-",
                                               start_date="-", end_date="-", hours=0, status="-")
      datatable(data, colnames = c("Başlıq", "Növ", "Təşkilatçı", "Başlama", "Bitmə", "Saat", "Status"))
    })

    output$cert_table <- renderDT({
      datatable(data.frame(Ad = c("Pedaqoji sertifikat", "ICT sertifikat"),
                           Tarix = c("2025-03", "2024-11"), Status = c("Aktiv", "Aktiv")))
    })
  })
}

teacher_performance_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    observe({
      teachers <- db_query(db_pool, "SELECT id, first_name || ' ' || last_name as name FROM teachers ORDER BY name")
      if (nrow(teachers) > 0) updateSelectInput(session, "selected_teacher", choices = setNames(teachers$id, teachers$name))
    })

    kpis <- reactive({
      req(input$selected_teacher)
      get_teacher_kpis(db_pool, input$selected_teacher, input$period)
    })

    output$kpi_students <- renderText({ format_percent(kpis()$student_outcomes %||% 78) })
    output$kpi_attendance <- renderText({ format_percent(kpis()$attendance %||% 95) })
    output$kpi_development <- renderText({ format_percent(kpis()$development %||% 82) })
    output$kpi_overall <- renderText({ format_percent(kpis()$overall %||% 85) })

    output$outcomes_chart <- renderPlotly({
      plot_ly(x = ~c("Əla", "Yaxşı", "Kafi", "Qeyri-kafi"), y = ~c(15, 20, 8, 2),
              type = "bar", marker = list(color = c("#27ae60", "#2980b9", "#f39c12", "#e74c3c"))) %>%
        layout(title = "Şagird Nəticələri", xaxis = list(title = ""), yaxis = list(title = "Şagird sayı"))
    })

    output$trend_chart <- renderPlotly({
      months <- format(seq.Date(Sys.Date()-210, Sys.Date(), by = "month"), "%b %Y")
      scores <- c(78, 80, 82, 79, 85, 87, 84)
      n <- length(months)
      scores <- scores[seq_len(n)]
      plot_ly(x = months, y = scores, type = "scatter", mode = "lines+markers") %>%
        layout(title = "Performans Trendi", xaxis = list(title = ""), yaxis = list(title = "Bal"))
    })

    # TALIS radar chart
    output$talis_radar_chart <- renderPlotly({
      req(input$selected_teacher)
      talis <- get_teacher_talis_profile(db_pool, input$selected_teacher)
      if (is.null(talis)) return(plot_ly() %>% layout(title = "TALIS məlumatı yoxdur"))

      categories <- c("Öz-effektivlik", "İş məmnuniyyəti", "Sinif idarəetməsi",
                       "PKİ təsiri", "Əməkdaşlıq", "İKT")
      values <- c(talis$self_efficacy %||% 0, talis$job_satisfaction %||% 0,
                  talis$classroom_management %||% 0, talis$cpd_impact_score %||% 0,
                  talis$collaboration_score %||% 0,
                  switch(talis$ict_usage_frequency %||% "nadir",
                         "hər_dərs" = 9, "həftəlik" = 7, "aylıq" = 4, "nadir" = 2, 5))
      oecd <- c(7.2, 7.5, 7.0, 6.5, 6.8, 6.0)

      plot_ly(type = "scatterpolar", fill = "toself") %>%
        add_trace(r = c(values, values[1]), theta = c(categories, categories[1]),
                  name = "Müəllim", fillcolor = "rgba(52,152,219,0.3)",
                  line = list(color = "#3498db")) %>%
        add_trace(r = c(oecd, oecd[1]), theta = c(categories, categories[1]),
                  name = "OECD orta", fillcolor = "rgba(231,76,60,0.1)",
                  line = list(color = "#e74c3c", dash = "dash")) %>%
        layout(polar = list(radialaxis = list(visible = TRUE, range = c(0, 10))),
               title = "TALIS Profili")
    })

    # Həftəlik yük bölgüsü
    output$weekly_load_chart <- renderPlotly({
      req(input$selected_teacher)
      talis <- get_teacher_talis_profile(db_pool, input$selected_teacher)
      if (is.null(talis)) return(plot_ly())

      labels <- c("Tədris", "İnzibati", "Hazırlıq")
      vals <- c(talis$weekly_teaching_hours %||% 0, talis$weekly_admin_hours %||% 0,
                talis$weekly_preparation_hours %||% 0)
      plot_ly(labels = ~labels, values = ~vals, type = "pie",
              marker = list(colors = c("#3498db", "#f39c12", "#27ae60"))) %>%
        layout(showlegend = TRUE, margin = list(t = 10, b = 10))
    })

    # TALIS əlavə məlumatlar
    output$talis_extra_info <- renderUI({
      req(input$selected_teacher)
      talis <- get_teacher_talis_profile(db_pool, input$selected_teacher)
      if (is.null(talis)) return(tags$p("Məlumat yoxdur"))
      tags$div(
        tags$p(tags$strong("PKİ saatları: "), talis$cpd_hours %||% 0),
        tags$p(tags$strong("Şagird orta balı: "), round(talis$student_avg_score %||% 0, 1)),
        tags$p(tags$strong("Keçid faizi: "), paste0(round(talis$student_pass_rate %||% 0, 1), "%")),
        tags$p(tags$strong("Rəqəmsal kontent: "), talis$digital_content_count %||% 0),
        tags$p(tags$strong("İnklüziv təlim: "), ifelse(talis$inclusive_education_training %||% FALSE, "Bəli", "Xeyr"))
      )
    })

    # Mükafatlar cədvəli
    output$awards_table <- renderDT({
      req(input$selected_teacher)
      data <- get_teacher_awards(db_pool, input$selected_teacher)
      if (nrow(data) == 0) data <- data.frame(title = "Mükafat yoxdur", awarding_body = "-",
                                               award_type = "-", award_date = "-", description = "-")
      datatable(data, colnames = c("Mükafat", "Verən qurum", "Növ", "Tarix", "Təsvir"),
                options = list(pageLength = 5, dom = "tp"))
    })

    # Nəşrlər cədvəli
    output$publications_table <- renderDT({
      req(input$selected_teacher)
      data <- get_teacher_publications(db_pool, input$selected_teacher)
      if (nrow(data) == 0) data <- data.frame(title = "Nəşr yoxdur", publication_type = "-",
                                               journal_name = "-", publication_date = "-",
                                               doi = "-", is_peer_reviewed = "-")
      datatable(data, colnames = c("Başlıq", "Növ", "Jurnal", "Tarix", "DOI", "Resenziya"),
                options = list(pageLength = 5, dom = "tp"))
    })

    observeEvent(input$btn_save_eval, {
      req(input$selected_teacher)
      overall <- round(mean(c(input$eval_teaching, input$eval_classroom, input$eval_parent,
                               input$eval_professional, input$eval_innovation)), 1)
      db_execute(db_pool,
        "INSERT INTO teacher_evaluations (teacher_id, evaluator_id, evaluation_date, academic_year,
         teaching_quality, student_engagement, professional_development, communication, innovation,
         overall_score, comments)
         VALUES ($1, $2, CURRENT_DATE, $3, $4, $5, $6, $7, $8, $9, $10)",
        params = list(input$selected_teacher, user_data()$id, get_academic_year(),
                      input$eval_teaching, input$eval_classroom, input$eval_professional,
                      input$eval_parent, input$eval_innovation, overall, input$eval_notes))
      notify_success("Qiymətləndirmə yadda saxlandı!")
    })
  })
}
