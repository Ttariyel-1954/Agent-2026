# =============================================
# ARTI-2026: Şagird Modulu - Server Məntiqi
# =============================================

# --- Şagird Siyahısı Server ---
student_list_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Reaktiv şagird siyahısı
    students <- reactive({
      input$btn_refresh  # Yeniləmə trigger
      query <- "SELECT s.*, c.grade, c.section, sc.name as school_name
                FROM students s
                LEFT JOIN classes c ON s.class_id = c.id
                LEFT JOIN schools sc ON s.school_id = sc.id WHERE 1=1"
      params <- list()
      i <- 1

      if (!is_empty(input$filter_grade)) {
        query <- paste0(query, " AND c.grade = $", i)
        params[[i]] <- as.integer(gsub("-ci sinif", "", input$filter_grade))
        i <- i + 1
      }
      if (!is_empty(input$filter_section)) {
        query <- paste0(query, " AND c.section = $", i)
        params[[i]] <- input$filter_section
        i <- i + 1
      }
      if (!is_empty(input$search_text)) {
        query <- paste0(query, " AND (s.first_name ILIKE $", i, " OR s.last_name ILIKE $", i, ")")
        params[[i]] <- paste0("%", input$search_text, "%")
      }
      query <- paste0(query, " ORDER BY s.last_name, s.first_name")
      if (length(params) > 0) db_query(db_pool, query, params = params)
      else db_query(db_pool, query)
    })

    # DataTable
    output$student_table <- renderDT({
      data <- students()
      if (nrow(data) == 0) return(datatable(data.frame("Məlumat tapılmadı" = character(0))))
      display <- data %>% select(first_name, last_name, father_name, birth_date, gender, school_name, grade, section, status)
      names(display) <- c("Ad", "Soyad", "Ata adı", "Doğum tarixi", "Cins", "Məktəb", "Sinif", "Bölmə", "Status")
      datatable(display, selection = "single", options = default_dt_options())
    })

    # Excel ixracı
    output$btn_export_excel <- downloadHandler(
      filename = function() paste0("sagirdler_", format(Sys.Date(), "%Y%m%d"), ".xlsx"),
      content = function(file) export_to_excel(students(), file, "Şagirdlər")
    )
  })
}

# --- Şagird Qeydiyyatı Server ---
student_register_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    observeEvent(input$btn_register, {
      # Validasiya
      errors <- validate_student_data(list(
        first_name = input$first_name, last_name = input$last_name,
        father_name = input$father_name, birth_date = input$birth_date,
        gender = input$gender, fin_code = input$fin_code,
        address = input$address, class_grade = input$class_grade,
        class_section = input$class_section, mother_name = input$mother_name,
        mother_phone = input$mother_phone
      ))

      if (length(errors) > 0) {
        output$registration_errors <- renderUI({
          tags$div(class = "alert alert-danger", lapply(errors, function(e) tags$p(icon("exclamation-triangle"), e)))
        })
        return()
      }

      # Verilənlər bazasına əlavə et
      result <- db_execute(db_pool,
        "INSERT INTO students (first_name, last_name, father_name, birth_date, gender, address, phone,
         parent_name, parent_phone, enrollment_date, status)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, 'active')",
        params = list(input$first_name, input$last_name, input$father_name,
                      input$birth_date, input$gender, input$address, input$phone,
                      input$mother_name, input$mother_phone, input$enrollment_date))

      if (result > 0) {
        notify_success("Şagird uğurla qeydiyyatdan keçirildi!")
        log_action(db_pool, user_data()$id, "student_register", "student", NULL,
                   list(name = paste(input$first_name, input$last_name)))
      } else {
        notify_error("Qeydiyyat zamanı xəta baş verdi!")
      }
    })

    # Formanı təmizlə
    observeEvent(input$btn_clear, {
      updateTextInput(session, "first_name", value = "")
      updateTextInput(session, "last_name", value = "")
      updateTextInput(session, "father_name", value = "")
      updateTextInput(session, "fin_code", value = "")
      updateTextInput(session, "address", value = "")
    })
  })
}

# --- Davamiyyət Server ---
student_attendance_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    attendance_data <- reactiveVal(data.frame())

    observeEvent(input$btn_load, {
      req(input$att_grade, input$att_section)
      grade_num <- as.integer(gsub("-ci sinif", "", input$att_grade))
      data <- db_query(db_pool,
        "SELECT s.id, s.first_name, s.last_name,
                COALESCE(a.status, 'present') as status
         FROM students s
         JOIN classes c ON s.class_id = c.id
         LEFT JOIN attendance a ON a.student_id = s.id AND a.date = $1
         WHERE c.grade = $2 AND c.section = $3
         ORDER BY s.last_name",
        params = list(input$att_date, grade_num, input$att_section))
      attendance_data(data)
    })

    output$attendance_table <- renderDT({
      data <- attendance_data()
      if (nrow(data) == 0) return(datatable(data.frame()))
      datatable(data %>% select(first_name, last_name, status),
                colnames = c("Ad", "Soyad", "Status"), selection = "none",
                editable = list(target = "cell", disable = list(columns = c(0, 1))))
    })

    # Yadda saxla
    observeEvent(input$btn_save_att, {
      data <- attendance_data()
      req(nrow(data) > 0)
      for (i in seq_len(nrow(data))) {
        db_execute(db_pool,
          "INSERT INTO attendance (student_id, date, status) VALUES ($1, $2, $3)
           ON CONFLICT (student_id, date) DO UPDATE SET status = $3",
          params = list(data$id[i], input$att_date, data$status[i]))
      }
      notify_success("Davamiyyət yadda saxlandı!")
    })

    # Günlük statistika
    output$daily_stats <- renderUI({
      data <- attendance_data()
      if (nrow(data) == 0) return(tags$p("Məlumat yoxdur"))
      present <- sum(data$status == "present")
      absent <- sum(data$status == "absent")
      late <- sum(data$status == "late")
      total <- nrow(data)
      tags$div(
        tags$p(icon("check-circle", style="color:#27ae60"), sprintf("İştirak: %d (%s)", present, format_percent(present/total*100))),
        tags$p(icon("times-circle", style="color:#e74c3c"), sprintf("Qayıb: %d (%s)", absent, format_percent(absent/total*100))),
        tags$p(icon("clock", style="color:#f39c12"), sprintf("Gecikmiş: %d", late))
      )
    })

    output$monthly_chart <- renderPlotly({
      plot_ly(x = ~c("İştirak", "Qayıb", "Gecikmiş"), y = ~c(85, 10, 5),
              type = "bar", marker = list(color = c("#27ae60", "#e74c3c", "#f39c12"))) %>%
        layout(xaxis = list(title = ""), yaxis = list(title = "Faiz"))
    })
  })
}

# --- Akademik Profil Server ---
student_profile_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Şagird siyahısını yüklə
    observe({
      students <- db_query(db_pool,
        "SELECT id, first_name || ' ' || last_name as name FROM students WHERE status = 'active' ORDER BY name")
      if (nrow(students) > 0) {
        updateSelectizeInput(session, "selected_student", choices = setNames(students$id, students$name))
      }
    })

    # Şagird məlumatları
    student_info <- reactive({
      req(input$selected_student)
      db_get_one(db_pool, "SELECT * FROM students WHERE id = $1", params = list(input$selected_student))
    })

    output$gpa <- renderText({
      req(input$selected_student)
      gpa <- calculate_gpa(db_pool, input$selected_student, input$academic_year)
      format_number_az(gpa, 1)
    })

    output$gpa_label <- renderText({
      req(input$selected_student)
      gpa <- calculate_gpa(db_pool, input$selected_student, input$academic_year)
      get_grade_label(gpa)
    })

    output$att_percent <- renderText({ "92.5%" })
    output$missed_days <- renderText({ "8 gün buraxılıb" })
    output$subject_count <- renderText({ "15" })
    output$class_rank <- renderText({ "5/32" })

    output$grades_table <- renderDT({
      req(input$selected_student)
      data <- db_query(db_pool,
        "SELECT sub.name as subject, AVG(g.score) as avg_score,
                MAX(g.score) as max_score, MIN(g.score) as min_score
         FROM grades g JOIN subjects sub ON g.subject_id = sub.id
         WHERE g.student_id = $1 AND g.academic_year = $2
         GROUP BY sub.name ORDER BY avg_score DESC",
        params = list(input$selected_student, input$academic_year))
      if (nrow(data) == 0) data <- data.frame(subject="Məlumat yoxdur", avg_score=NA, max_score=NA, min_score=NA)
      datatable(data, colnames = c("Fənn", "Orta", "Maks", "Min"), options = list(pageLength = 15, dom = "t"))
    })

    output$grades_chart <- renderPlotly({
      plot_ly(x = ~SUBJECTS[1:8], y = ~sample(50:95, 8), type = "bar",
              marker = list(color = "#3498db")) %>%
        layout(xaxis = list(title = "", tickangle = -45), yaxis = list(title = "Bal", range = c(0, 100)))
    })

    output$progress_chart <- renderPlotly({
      months <- seq.Date(Sys.Date()-180, Sys.Date(), by = "month")
      plot_ly(x = ~months, y = ~cumsum(rnorm(length(months), 2, 1)) + 70,
              type = "scatter", mode = "lines+markers") %>%
        layout(xaxis = list(title = ""), yaxis = list(title = "Orta Bal"))
    })
  })
}

# --- Fərdi İnkişaf Planı Server ---
student_idp_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    observe({
      students <- db_query(db_pool,
        "SELECT id, first_name || ' ' || last_name as name FROM students WHERE status = 'active' ORDER BY name")
      if (nrow(students) > 0) {
        updateSelectizeInput(session, "idp_student", choices = setNames(students$id, students$name))
      }
    })

    output$idp_list <- renderDT({
      req(input$idp_student)
      data <- db_query(db_pool,
        "SELECT id, goals_json->>'title' as goal, status, start_date, review_date
         FROM student_idp WHERE student_id = $1 ORDER BY start_date DESC",
        params = list(input$idp_student))
      if (nrow(data) == 0) data <- data.frame(goal="FİP tapılmadı", status="-", start_date="-", review_date="-")
      datatable(data, colnames = c("ID", "Hədəf", "Status", "Başlama", "Nəzərdən keçirmə"), options = list(pageLength = 10))
    })

    output$idp_progress <- renderUI({
      tags$div(
        tags$div(class = "progress", tags$div(class = "progress-bar bg-success", style = "width:65%", "65%")),
        tags$p("3 hədəfdən 2-si tamamlanıb")
      )
    })

    output$idp_stats_chart <- renderPlotly({
      plot_ly(labels = ~c("Tamamlanmış", "Davam edən", "Gözləyən"),
              values = ~c(5, 3, 2), type = "pie",
              marker = list(colors = c("#27ae60", "#3498db", "#f39c12")))
    })

    output$idp_history <- renderDT({
      datatable(data.frame(
        Tarix = c("01.02.2026", "15.01.2026"), Qeyd = c("Riyaziyyatda irəliləyiş var", "Plan təsdiq edildi"),
        Tərəqqi = c("Yaxşı", "Əla")
      ), options = list(pageLength = 10, dom = "t"))
    })
  })
}
