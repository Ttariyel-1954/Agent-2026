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
      display <- data %>% select(first_name, last_name, specialty, category, experience_years, school_name, status)
      names(display) <- c("Ad", "Soyad", "İxtisas", "Kateqoriya", "Təcrübə", "Məktəb", "Status")
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

    output$total_hours <- renderText({
      req(input$selected_teacher)
      result <- db_query(db_pool, "SELECT COUNT(*) as hours FROM teacher_schedule WHERE teacher_id = $1",
                         params = list(input$selected_teacher))
      if (nrow(result) > 0) as.character(result$hours[1]) else "0"
    })

    output$workload_status <- renderUI({
      hours <- as.integer(isolate(output$total_hours) %||% 0)
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
        "SELECT title, type, provider, date_start, date_end, hours, status
         FROM professional_development WHERE teacher_id = $1 ORDER BY date_start DESC",
        params = list(input$selected_teacher))
      if (nrow(data) == 0) data <- data.frame(title="Məlumat yoxdur", type="-", provider="-",
                                               date_start="-", date_end="-", hours=0, status="-")
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
      months <- format(seq.Date(Sys.Date()-180, Sys.Date(), by = "month"), "%b %Y")
      plot_ly(x = ~months, y = ~c(78, 80, 82, 79, 85, 87, 84), type = "scatter", mode = "lines+markers") %>%
        layout(title = "Performans Trendi", xaxis = list(title = ""), yaxis = list(title = "Bal"))
    })

    observeEvent(input$btn_save_eval, {
      req(input$selected_teacher)
      scores <- jsonlite::toJSON(list(
        teaching = input$eval_teaching, classroom = input$eval_classroom, parent = input$eval_parent,
        professional = input$eval_professional, innovation = input$eval_innovation, teamwork = input$eval_teamwork
      ), auto_unbox = TRUE)
      db_execute(db_pool,
        "INSERT INTO teacher_evaluations (teacher_id, evaluator_id, period, score, category_scores_json, comments, date)
         VALUES ($1, $2, $3, $4, $5, $6, CURRENT_DATE)",
        params = list(input$selected_teacher, user_data()$id, input$period,
                      mean(c(input$eval_teaching, input$eval_classroom, input$eval_parent,
                             input$eval_professional, input$eval_innovation, input$eval_teamwork)),
                      scores, input$eval_notes))
      notify_success("Qiymətləndirmə yadda saxlandı!")
    })
  })
}
