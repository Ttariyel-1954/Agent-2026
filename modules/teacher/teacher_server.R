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

    # =============================================
    # AI MENTOR SİSTEMİ
    # =============================================
    mentor_result <- reactiveVal(NULL)
    att_plan_result <- reactiveVal(NULL)

    # --- Zəif Sahələr UI ---
    output$weak_areas_ui <- renderUI({
      req(input$selected_teacher)
      talis <- get_teacher_talis_profile(db_pool, input$selected_teacher)
      if (is.null(talis)) {
        return(tags$div(style = "text-align:center; color:#999; padding:20px;",
          icon("info-circle"), tags$p("Bu müəllim üçün TALIS məlumatı tapılmadı")))
      }

      weak <- detect_weak_areas(talis)
      if (nrow(weak) == 0) {
        return(tags$div(style = "text-align:center; color:#27ae60; padding:20px;",
          icon("check-circle", style = "font-size:2em;"), tags$br(),
          tags$p(tags$strong("Bütün sahələrdə OECD standartlarına çatılıb!"))))
      }

      items <- lapply(seq_len(nrow(weak)), function(i) {
        w <- weak[i, ]
        bar_color <- switch(w$priority, high = "#e74c3c", medium = "#f39c12", "#3498db")
        pct <- if (w$label == "Şagird keçid faizi") {
          min(100, max(0, w$score))
        } else {
          min(100, max(0, w$score / 10 * 100))
        }
        oecd_pct <- if (w$label == "Şagird keçid faizi") w$oecd else w$oecd / 10 * 100

        tags$div(style = "margin-bottom:8px;",
          tags$div(style = "display:flex; justify-content:space-between; font-size:0.85em;",
            tags$span(w$label),
            tags$span(style = paste0("color:", bar_color, "; font-weight:bold;"),
              paste0(w$score, " / ", w$oecd))
          ),
          tags$div(style = "background:#ecf0f1; border-radius:4px; height:8px; position:relative;",
            tags$div(style = paste0("background:", bar_color, "; width:", pct, "%;
                                     height:100%; border-radius:4px;")),
            tags$div(style = paste0("position:absolute; left:", oecd_pct, "%; top:-2px;
                                     width:2px; height:12px; background:#2c3e50;"))
          )
        )
      })

      tags$div(
        tags$div(style = "margin-bottom:10px;",
          tags$span(class = "label label-danger", paste(sum(weak$priority == "high"), "yüksək")),
          tags$span(class = "label label-warning", style = "margin-left:4px;",
            paste(sum(weak$priority == "medium"), "orta")),
          tags$span(class = "label label-info", style = "margin-left:4px;",
            paste(sum(weak$priority == "low"), "aşağı"))
        ),
        items,
        tags$small(class = "text-muted", "Qara xətt = OECD ortalaması")
      )
    })

    # --- Həftəlik Tövsiyə Generasiya ---
    observeEvent(input$btn_generate_mentor, {
      req(input$selected_teacher)

      withProgress(message = "AI Mentor tövsiyə hazırlayır...", value = 0.3, {
        result <- tryCatch(
          generate_mentor_recommendations(input$selected_teacher, db_pool, user_data()$id),
          error = function(e) list(success = FALSE, message = e$message)
        )
        setProgress(value = 1)
      })

      mentor_result(result)

      if (result$success) {
        notify_success("Həftəlik tövsiyələr hazırlandı!")
      } else {
        notify_error(paste("Mentor xətası:", result$message))
      }
    })

    # --- Həftəlik Fokus ---
    output$mentor_focus_ui <- renderUI({
      result <- mentor_result()
      if (is.null(result) || !result$success) return(NULL)

      tags$div(
        if (!is_empty(result$weekly_focus))
          tags$div(style = "background:#e8f4fd; padding:10px; border-radius:6px; margin-bottom:10px;",
            tags$strong(icon("bullseye"), " Bu həftənin fokus sahəsi: "),
            result$weekly_focus),
        if (!is_empty(result$motivation_note))
          tags$div(style = "background:#e8f5e9; padding:10px; border-radius:6px;",
            tags$em(icon("heart"), " ", result$motivation_note))
      )
    })

    # --- Tövsiyələr UI ---
    output$mentor_recommendations_ui <- renderUI({
      result <- mentor_result()
      if (is.null(result)) {
        return(tags$div(style = "text-align:center; color:#999; padding:40px;",
          icon("robot", style = "font-size:2.5em;"), tags$br(), tags$br(),
          tags$p("'Həftəlik Tövsiyə Al' düyməsini basın")))
      }
      if (!result$success) {
        return(tags$div(class = "alert alert-danger", icon("exclamation-triangle"), " ", result$message))
      }

      recs <- result$recommendations
      if (is.null(recs) || length(recs) == 0) {
        return(tags$div(class = "alert alert-success", icon("check"), " Tövsiyə yoxdur — əla nəticə!"))
      }

      # data.frame və ya list ola bilər
      if (is.data.frame(recs)) {
        rec_items <- lapply(seq_len(nrow(recs)), function(i) {
          render_recommendation_card(recs[i, ], ns)
        })
      } else {
        rec_items <- lapply(recs, function(rec) {
          render_recommendation_card(rec, ns)
        })
      }

      tags$div(style = "max-height:500px; overflow-y:auto;", rec_items)
    })

    # --- Resurslar Cədvəli ---
    output$mentor_resources_table <- renderDT({
      req(input$selected_teacher)
      data <- get_mentor_resources(input$selected_teacher, db_pool)
      if (nrow(data) == 0) {
        return(datatable(data.frame("Resurs" = "Tövsiyə generasiya edin"),
          options = list(dom = "t")))
      }
      display <- data %>%
        select(resource_type, title, source, estimated_minutes, is_viewed, weak_area)
      names(display) <- c("Növ", "Başlıq", "Mənbə", "Dəqiqə", "Baxılıb", "Sahə")
      display$Baxılıb <- ifelse(display$Baxılıb, "Bəli", "Xeyr")

      type_icons <- c(video = "Video", article = "Məqalə", course = "Kurs",
                       book = "Kitab", webinar = "Vebinar", tool = "Alət")
      display$Növ <- type_icons[display$Növ] %||% display$Növ

      datatable(display, selection = "single", options = list(pageLength = 5, dom = "tp",
        language = list(emptyTable = "Resurs tapılmadı")))
    })

    # Resursu baxıldı işarələ
    observeEvent(input$btn_mark_resource_viewed, {
      req(input$selected_teacher)
      sel <- input$mentor_resources_table_rows_selected
      if (is.null(sel) || length(sel) == 0) {
        notify_warning("Resurs seçin")
        return()
      }
      data <- get_mentor_resources(input$selected_teacher, db_pool)
      if (sel > nrow(data)) return()
      rating <- if (!is_empty(input$resource_rating)) as.integer(input$resource_rating) else NULL
      mark_resource_viewed(data[sel, "id"], rating, db_pool)
      notify_success("Resurs baxıldı olaraq işarələndi")
    })

    # --- Tövsiyə Tarixçəsi ---
    output$mentor_history_table <- renderDT({
      req(input$selected_teacher)
      input$btn_mark_completed
      input$btn_generate_mentor

      data <- get_mentor_history(input$selected_teacher, db_pool)
      if (nrow(data) == 0) {
        return(datatable(data.frame("Tarixçə" = "Hələ tövsiyə yoxdur"),
          options = list(dom = "t")))
      }
      display <- data %>%
        select(week_start, weak_area, priority, recommendation_text, is_completed, feedback_rating)
      names(display) <- c("Həftə", "Sahə", "Prioritet", "Tövsiyə", "Tamamlandı", "Reytinq")
      display$Tamamlandı <- ifelse(display$Tamamlandı, "Bəli", "Xeyr")
      display$Tövsiyə <- substr(display$Tövsiyə, 1, 80)

      datatable(display, selection = "single", options = list(pageLength = 10, dom = "tp",
        language = list(emptyTable = "Tarixçə boşdur")))
    })

    # Tövsiyəni tamamlandı işarələ
    observeEvent(input$btn_mark_completed, {
      req(input$selected_teacher)
      sel <- input$mentor_history_table_rows_selected
      if (is.null(sel) || length(sel) == 0) {
        notify_warning("Tövsiyə seçin")
        return()
      }
      data <- get_mentor_history(input$selected_teacher, db_pool)
      if (sel > nrow(data)) return()
      feedback <- input$rec_feedback %||% ""
      rating <- if (!is_empty(input$rec_rating)) as.integer(input$rec_rating) else NULL
      mark_recommendation_completed(data[sel, "id"], feedback, rating, db_pool)
      notify_success("Tövsiyə tamamlandı olaraq işarələndi")
    })

    # =============================================
    # İRƏLİLƏYİŞ İZLƏMƏ
    # =============================================
    output$progress_table <- renderDT({
      req(input$selected_teacher)
      progress <- track_teacher_progress(input$selected_teacher, db_pool)
      if (nrow(progress) == 0) {
        return(datatable(data.frame("Məlumat" = "TALIS göstəriciləri tapılmadı"),
          options = list(dom = "t")))
      }
      display <- progress %>%
        select(label, previous, current, target, change_pct)
      names(display) <- c("Sahə", "Əvvəlki", "Cari", "Hədəf (OECD)", "Dəyişim %")

      datatable(display, selection = "none", options = list(dom = "t", pageLength = 10)) %>%
        formatStyle("Dəyişim %",
          color = styleInterval(c(-0.1, 0.1), c("#e74c3c", "#f39c12", "#27ae60")),
          fontWeight = "bold")
    })

    output$progress_chart <- renderPlotly({
      req(input$selected_teacher)
      progress <- track_teacher_progress(input$selected_teacher, db_pool)
      if (nrow(progress) == 0) {
        return(plot_ly() %>% layout(title = "TALIS məlumatı yoxdur",
          xaxis = list(visible = FALSE), yaxis = list(visible = FALSE)))
      }

      plot_ly(data = progress) %>%
        add_trace(x = ~label, y = ~current, type = "bar", name = "Cari",
                  marker = list(color = "#3498db")) %>%
        add_trace(x = ~label, y = ~target, type = "scatter", mode = "markers+lines",
                  name = "OECD Hədəf", marker = list(color = "#e74c3c", size = 10),
                  line = list(color = "#e74c3c", dash = "dash")) %>%
        add_trace(x = ~label, y = ~previous, type = "bar", name = "Əvvəlki",
                  marker = list(color = "#bdc3c7"), visible = "legendonly") %>%
        layout(
          xaxis = list(title = "", tickangle = -30),
          yaxis = list(title = "Bal"),
          barmode = "group",
          legend = list(orientation = "h", y = -0.2)
        )
    })

    # =============================================
    # ATTESTASİYA HAZIRLIK PLANI
    # =============================================

    # Plan generasiya et
    observeEvent(input$btn_generate_att_plan, {
      req(input$selected_teacher, input$att_target)

      if (is_empty(input$att_target)) {
        notify_warning("Hədəf kateqoriya seçin")
        return()
      }

      withProgress(message = "Attestasiya planı yaradılır...", value = 0.3, {
        result <- tryCatch(
          generate_attestation_plan(
            teacher_id = input$selected_teacher,
            target_category = input$att_target,
            total_weeks = input$att_weeks %||% 12,
            db_pool = db_pool,
            user_id = user_data()$id
          ),
          error = function(e) list(success = FALSE, message = e$message)
        )
        setProgress(value = 1)
      })

      att_plan_result(result)

      if (result$success) {
        notify_success("Attestasiya planı yaradıldı!")
      } else {
        notify_error(paste("Plan xətası:", result$message))
      }
    })

    # Cari hazırlıq səviyyəsi
    output$att_readiness_ui <- renderUI({
      # Əvvəlcə DB-dəki aktiv planı yoxla, sonra yenisini
      result <- att_plan_result()
      if (is.null(result)) {
        req(input$selected_teacher)
        plan <- get_active_attestation_plan(input$selected_teacher, db_pool)
        if (!is.null(plan)) {
          readiness <- plan$current_readiness %||% 0
        } else {
          return(tags$p(style = "color:#999;", "Plan yaradılmayıb"))
        }
      } else if (!result$success) {
        return(NULL)
      } else {
        readiness <- result$current_readiness %||% 0
      }

      bar_color <- if (readiness >= 70) "#27ae60" else if (readiness >= 40) "#f39c12" else "#e74c3c"
      tags$div(
        tags$div(style = "text-align:center;",
          tags$h2(style = paste0("color:", bar_color, ";"), paste0(round(readiness), "%"))
        ),
        tags$div(style = "background:#ecf0f1; border-radius:6px; height:12px;",
          tags$div(style = paste0("background:", bar_color, "; width:", readiness,
                                   "%; height:100%; border-radius:6px;"))
        )
      )
    })

    # Boşluq analizi
    output$att_gap_ui <- renderUI({
      result <- att_plan_result()
      if (is.null(result) || !result$success) {
        req(input$selected_teacher)
        plan <- get_active_attestation_plan(input$selected_teacher, db_pool)
        if (!is.null(plan) && !is.null(plan$plan_data)) {
          gap <- plan$plan_data$gap_analysis
        } else return(NULL)
      } else {
        gap <- result$gap_analysis
      }
      if (is_empty(gap)) return(NULL)
      tags$div(style = "margin-top:10px; font-size:0.9em; color:#555;",
        tags$strong("Boşluq Analizi: "), tags$br(),
        tags$em(gap))
    })

    # Plan UI
    output$att_plan_ui <- renderUI({
      result <- att_plan_result()
      plan_data <- NULL

      if (!is.null(result) && result$success) {
        plan_data <- result$plan
      } else {
        req(input$selected_teacher)
        plan <- get_active_attestation_plan(input$selected_teacher, db_pool)
        if (!is.null(plan)) plan_data <- plan$plan_data
      }

      if (is.null(plan_data)) {
        return(tags$div(style = "text-align:center; color:#999; padding:40px;",
          icon("certificate", style = "font-size:2.5em;"), tags$br(), tags$br(),
          tags$p("Hədəf kateqoriya seçin və 'Plan Yarat' basın")))
      }

      weekly_plan <- plan_data$weekly_plan
      if (is.null(weekly_plan) || length(weekly_plan) == 0) {
        return(tags$p("Həftəlik plan tapılmadı"))
      }

      week_items <- lapply(weekly_plan, function(w) {
        week_num <- w$week %||% "?"
        theme <- w$theme %||% ""
        milestone <- w$milestone %||% ""
        tasks <- w$tasks

        task_items <- if (is.list(tasks) && length(tasks) > 0) {
          lapply(tasks, function(t) {
            task_text <- if (is.data.frame(t)) t$task[1] else t$task %||% ""
            task_type <- if (is.data.frame(t)) t$type[1] else t$type %||% ""
            task_hours <- if (is.data.frame(t)) t$hours[1] else t$hours %||% ""
            tags$li(style = "margin-bottom:4px;",
              tags$span(task_text),
              tags$small(style = "color:#888; margin-left:6px;",
                paste0("(", task_type, ", ", task_hours, " saat)")))
          })
        } else if (is.data.frame(tasks) && nrow(tasks) > 0) {
          lapply(seq_len(nrow(tasks)), function(j) {
            tags$li(style = "margin-bottom:4px;",
              tags$span(tasks$task[j]),
              tags$small(style = "color:#888; margin-left:6px;",
                paste0("(", tasks$type[j], ", ", tasks$hours[j], " saat)")))
          })
        } else list()

        tags$div(style = "border:1px solid #ddd; border-radius:8px; padding:12px; margin-bottom:10px;",
          tags$div(style = "display:flex; justify-content:space-between; align-items:center;",
            tags$strong(paste0("Həftə ", week_num, ": ", theme)),
            tags$span(class = "label label-primary", milestone)
          ),
          tags$ul(style = "margin-top:8px;", task_items)
        )
      })

      tags$div(style = "max-height:500px; overflow-y:auto;", week_items)
    })

    # Portfolio maddələri
    output$att_portfolio_ui <- renderUI({
      result <- att_plan_result()
      plan_data <- NULL
      if (!is.null(result) && result$success) {
        plan_data <- result$plan
      } else {
        req(input$selected_teacher)
        plan <- get_active_attestation_plan(input$selected_teacher, db_pool)
        if (!is.null(plan)) plan_data <- plan$plan_data
      }
      if (is.null(plan_data) || is.null(plan_data$portfolio_items)) return(NULL)
      items <- plan_data$portfolio_items
      tags$ul(lapply(items, function(item) tags$li(item)))
    })

    # Lazımi sənədlər
    output$att_documents_ui <- renderUI({
      result <- att_plan_result()
      plan_data <- NULL
      if (!is.null(result) && result$success) {
        plan_data <- result$plan
      } else {
        req(input$selected_teacher)
        plan <- get_active_attestation_plan(input$selected_teacher, db_pool)
        if (!is.null(plan)) plan_data <- plan$plan_data
      }
      if (is.null(plan_data) || is.null(plan_data$key_documents)) return(NULL)
      docs <- plan_data$key_documents
      tags$ul(lapply(docs, function(doc) tags$li(doc)))
    })
  })
}

#' Tövsiyə kartı render et (köməkçi funksiya)
render_recommendation_card <- function(rec, ns) {
  if (is.data.frame(rec)) {
    area <- rec$weak_area[1] %||% ""
    priority_val <- rec$priority[1] %||% "medium"
    rec_text <- rec$recommendation[1] %||% ""
    expected <- rec$expected_outcome[1] %||% ""
    strategy <- rec$strategy_type[1] %||% "general"
  } else {
    area <- rec$weak_area %||% ""
    priority_val <- rec$priority %||% "medium"
    rec_text <- rec$recommendation %||% ""
    expected <- rec$expected_outcome %||% ""
    strategy <- rec$strategy_type %||% "general"
  }

  priority_color <- switch(priority_val, high = "#e74c3c", medium = "#f39c12", "#3498db")
  priority_icon <- switch(priority_val,
    high = "exclamation-circle", medium = "info-circle", "check-circle")

  strategy_labels <- c(
    classroom_management = "Sinif idarəetməsi",
    teaching_method = "Tədris metodikası",
    ict_integration = "İKT inteqrasiyası",
    assessment = "Qiymətləndirmə",
    collaboration = "Əməkdaşlıq",
    professional_dev = "Peşəkar inkişaf",
    inclusive = "İnklüziv təhsil",
    general = "Ümumi"
  )
  strategy_label <- strategy_labels[strategy] %||% strategy

  tags$div(
    style = paste0("border:1px solid #ddd; border-radius:8px; padding:14px; margin-bottom:10px;
                     border-left:5px solid ", priority_color, ";"),
    tags$div(style = "display:flex; justify-content:space-between; align-items:center;",
      tags$h5(style = "margin:0;",
        icon(priority_icon, style = paste0("color:", priority_color)), " ", area),
      tags$span(class = "label label-default", style = "font-size:0.8em;", strategy_label)
    ),
    tags$p(style = "margin:8px 0; font-size:0.95em;", rec_text),
    if (!is_empty(expected))
      tags$div(style = "background:#f0fff4; padding:6px 10px; border-radius:4px; font-size:0.85em;",
        tags$strong("Gözlənilən nəticə: "), expected)
  )
}
