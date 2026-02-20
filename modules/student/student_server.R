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

    # =============================================
    # AI TUTOR
    # =============================================
    tutor_chat <- reactiveVal(list())

    # Nümunə suallar
    observeEvent(input$tq1, { updateTextInput(session, "tutor_input", value = "Kəsr ədədləri necə toplayım?") })
    observeEvent(input$tq2, { updateTextInput(session, "tutor_input", value = "Üçbucağın sahəsini necə tapım?") })
    observeEvent(input$tq3, { updateTextInput(session, "tutor_input", value = "Fotosentez nədir?") })
    observeEvent(input$tq4, { updateTextInput(session, "tutor_input", value = "Mənə test sualı ver") })

    # Şagird seçiləndə söhbət tarixçəsini yüklə
    observeEvent(input$selected_student, {
      req(input$selected_student)
      history <- tryCatch(
        db_query(db_pool,
          "SELECT role, content FROM ai_tutor_chats
           WHERE student_id = $1 ORDER BY created_at DESC LIMIT 50",
          params = list(input$selected_student)),
        error = function(e) data.frame()
      )
      if (nrow(history) > 0) {
        msgs <- rev(lapply(seq_len(nrow(history)), function(i) {
          list(role = history$role[i], content = history$content[i])
        }))
        tutor_chat(msgs)
      } else {
        tutor_chat(list())
      }
    })

    # Söhbət mesajlarını render et
    output$tutor_messages <- renderUI({
      msgs <- tutor_chat()
      if (length(msgs) == 0) {
        return(tags$div(style = "text-align: center; color: #999; padding: 40px;",
          icon("robot", style = "font-size: 3em; color: #3498db;"), tags$br(), tags$br(),
          tags$p("Salam! Mən sənin AI Tutor köməkçinəm."),
          tags$p("İstənilən fənn üzrə sual verə bilərsən."),
          tags$p(style = "font-size: 0.85em;", "Sualını yaz və ya aşağıdakı nümunələrdən birini seç.")
        ))
      }
      tags$div(
        lapply(msgs, function(msg) {
          is_user <- msg$role == "user"
          tags$div(
            style = paste0(
              "margin-bottom: 10px; padding: 10px 14px; border-radius: 14px; max-width: 85%; ",
              "font-size: 0.92em; line-height: 1.5; ",
              if (is_user) "background: #3498db; color: #fff; margin-left: auto; text-align: right;"
              else "background: #f0f2f5; color: #2c3e50;"
            ),
            if (!is_user) tags$div(style = "margin-bottom: 4px;",
              tags$strong(style = "color: #3498db;", icon("robot"), " AI Tutor")),
            HTML(msg$content)
          )
        })
      )
    })

    # Mesaj göndər
    observeEvent(input$btn_tutor_send, {
      req(input$tutor_input, input$selected_student)
      user_msg <- trimws(input$tutor_input)
      if (nchar(user_msg) == 0) return()
      updateTextInput(session, "tutor_input", value = "")

      student_id <- input$selected_student
      subject <- input$tutor_subject

      # İstifadəçi mesajını əlavə et
      msgs <- tutor_chat()
      msgs <- append(msgs, list(list(role = "user", content = htmltools::htmlEscape(user_msg))))
      tutor_chat(msgs)

      # DB-yə yaz
      tryCatch(
        db_execute(db_pool,
          "INSERT INTO ai_tutor_chats (student_id, role, content, subject) VALUES ($1, 'user', $2, $3)",
          params = list(student_id, user_msg, subject)),
        error = function(e) NULL
      )

      # "Düşünürəm..." göstər
      msgs <- append(msgs, list(list(role = "assistant", content = "<em>Düşünürəm...</em>")))
      tutor_chat(msgs)

      # Şagird kontekstini topla
      student_context <- build_tutor_context(db_pool, student_id, subject, input$academic_year)

      # Son 6 söhbət mesajını kontekst kimi ver
      recent_msgs <- tail(tutor_chat(), 7)  # son 6 + düşünürəm
      recent_msgs <- recent_msgs[sapply(recent_msgs, function(m) m$content != "<em>Düşünürəm...</em>")]
      chat_context <- paste(sapply(tail(recent_msgs, 6), function(m) {
        paste0(if (m$role == "user") "Şagird" else "Tutor", ": ", m$content)
      }), collapse = "\n")

      system_prompt <- paste0(
        "Sən ", student_context$grade, "-ci sinif şagirdinə kömək edən Azərbaycan dilində danışan müəllim assistentisən. ",
        "Şagirdin adı: ", student_context$name, ". ",
        "Hal-hazırda ", subject, " fənni üzrə kömək edirsən. ",
        if (nchar(student_context$strengths) > 0)
          paste0("Şagirdin güclü tərəfləri: ", student_context$strengths, ". ") else "",
        if (nchar(student_context$weaknesses) > 0)
          paste0("Şagirdin zəif tərəfləri: ", student_context$weaknesses, ". ") else "",
        "\n\nQaydalar:\n",
        "1. Addım-addım izah et, hər addımı aydın göstər\n",
        "2. Konkret nümunələr ver\n",
        "3. İzahdan sonra bir test sualı ver (cavabını gizlət)\n",
        "4. Həvəsləndirici və səbirli ol\n",
        "5. Şagirdin səviyyəsinə uyğun dildə danış\n",
        "6. Azərbaycan dilində cavab ver"
      )

      prompt <- paste0(
        if (nchar(chat_context) > 0) paste0("Əvvəlki söhbət:\n", chat_context, "\n\n") else "",
        "Şagirdin sualı: ", user_msg
      )

      # Claude API çağır
      result <- tryCatch(
        call_claude_api(prompt, system_prompt, max_tokens = 2048, temperature = 0.6),
        error = function(e) list(success = FALSE, message = e$message)
      )

      # "Düşünürəm..." sil
      msgs <- tutor_chat()
      msgs <- msgs[-length(msgs)]

      if (result$success) {
        ai_response <- result$message
        ai_html <- tutor_md_to_html(ai_response)
        msgs <- append(msgs, list(list(role = "assistant", content = ai_html)))

        # DB-yə yaz
        tokens <- (result$usage$input_tokens %||% 0) + (result$usage$output_tokens %||% 0)
        tryCatch(
          db_execute(db_pool,
            "INSERT INTO ai_tutor_chats (student_id, role, content, subject, tokens_used) VALUES ($1, 'assistant', $2, $3, $4)",
            params = list(student_id, ai_response, subject, tokens)),
          error = function(e) NULL
        )
      } else {
        msgs <- append(msgs, list(list(role = "assistant",
          content = paste0("<span style='color:#e74c3c;'>Xəta baş verdi: ", result$message, "</span>"))))
      }

      tutor_chat(msgs)
    })

    # Söhbəti təmizlə
    observeEvent(input$btn_tutor_clear, {
      tutor_chat(list())
    })

    # Söhbət tarixçəsi siyahısı (sağ panel)
    output$tutor_history_list <- renderUI({
      req(input$selected_student)
      sessions <- tryCatch(
        db_query(db_pool,
          "SELECT subject, DATE(created_at) as chat_date, COUNT(*) as msg_count
           FROM ai_tutor_chats WHERE student_id = $1
           GROUP BY subject, DATE(created_at) ORDER BY chat_date DESC LIMIT 10",
          params = list(input$selected_student)),
        error = function(e) data.frame()
      )
      if (nrow(sessions) == 0) return(tags$p(style = "color: #999;", "Hələ söhbət yoxdur"))
      tags$div(style = "max-height: 200px; overflow-y: auto;",
        lapply(seq_len(nrow(sessions)), function(i) {
          s <- sessions[i, ]
          tags$div(style = "padding: 6px 0; border-bottom: 1px solid #eee; font-size: 0.85em;",
            tags$strong(s$subject), tags$br(),
            tags$small(style = "color: #888;", format(s$chat_date, "%d.%m.%Y"), " — ", s$msg_count, " mesaj")
          )
        })
      )
    })

    # AI Tutor statistikası
    output$tutor_stats <- renderUI({
      req(input$selected_student)
      stats <- tryCatch(
        db_query(db_pool,
          "SELECT COUNT(*) as total_msgs,
                  COUNT(DISTINCT DATE(created_at)) as active_days,
                  COUNT(DISTINCT subject) as subjects_asked,
                  SUM(tokens_used) as total_tokens
           FROM ai_tutor_chats WHERE student_id = $1",
          params = list(input$selected_student)),
        error = function(e) data.frame(total_msgs = 0, active_days = 0, subjects_asked = 0, total_tokens = 0)
      )
      if (nrow(stats) == 0) stats <- data.frame(total_msgs = 0, active_days = 0, subjects_asked = 0, total_tokens = 0)
      tags$div(
        tags$p(icon("comments"), " Cəmi mesaj: ", tags$strong(stats$total_msgs[1])),
        tags$p(icon("calendar"), " Aktiv gün: ", tags$strong(stats$active_days[1])),
        tags$p(icon("book"), " Fənn sayı: ", tags$strong(stats$subjects_asked[1]))
      )
    })

    # =============================================
    # MÜƏLLİM BAXIŞI — Şagirdin AI söhbətləri
    # =============================================
    output$tv_chat_table <- renderDT({
      req(input$selected_student)
      input$btn_tv_load  # trigger

      query <- "SELECT ac.id, ac.subject, ac.role, SUBSTRING(ac.content, 1, 100) as preview,
                       ac.created_at
                FROM ai_tutor_chats ac
                WHERE ac.student_id = $1 AND ac.created_at >= $2 AND ac.created_at <= ($3::date + 1)"
      params <- list(input$selected_student, input$tv_dates[1], input$tv_dates[2])

      if (!is_empty(input$tv_subject_filter)) {
        query <- paste0(query, " AND ac.subject = $4")
        params[[4]] <- input$tv_subject_filter
      }

      query <- paste0(query, " ORDER BY ac.created_at DESC")
      data <- tryCatch(db_query(db_pool, query, params = params), error = function(e) data.frame())

      if (nrow(data) == 0) return(datatable(data.frame("Söhbət tapılmadı" = character(0))))
      display <- data %>% select(subject, role, preview, created_at)
      display$role <- ifelse(display$role == "user", "Şagird", "AI Tutor")
      names(display) <- c("Fənn", "Kim", "Məzmun", "Tarix")
      datatable(display, selection = "single", options = default_dt_options(20))
    })

    # Seçilmiş söhbəti göstər
    output$tv_chat_detail <- renderUI({
      req(input$selected_student)
      sel <- input$tv_chat_table_rows_selected
      if (is.null(sel) || length(sel) == 0) {
        return(tags$p(style = "color: #999;", "Söhbət seçin"))
      }

      # Seçilmiş sətirin tarixini əsas götür, o günün bütün söhbətini göstər
      query <- "SELECT ac.subject, ac.role, ac.content, ac.created_at
                FROM ai_tutor_chats ac
                WHERE ac.student_id = $1 AND ac.created_at >= $2 AND ac.created_at <= ($3::date + 1)"
      params <- list(input$selected_student, input$tv_dates[1], input$tv_dates[2])
      if (!is_empty(input$tv_subject_filter)) {
        query <- paste0(query, " AND ac.subject = $4")
        params[[4]] <- input$tv_subject_filter
      }
      query <- paste0(query, " ORDER BY ac.created_at DESC")
      all_data <- tryCatch(db_query(db_pool, query, params = params), error = function(e) data.frame())
      if (nrow(all_data) == 0) return(tags$p("Məlumat yoxdur"))

      # Seçilmiş mesajın tarixindən eyni gün + fənn söhbətini göstər
      selected_row <- all_data[sel, ]
      selected_date <- as.Date(selected_row$created_at)
      selected_subject <- selected_row$subject

      day_chat <- tryCatch(
        db_query(db_pool,
          "SELECT role, content, created_at FROM ai_tutor_chats
           WHERE student_id = $1 AND subject = $2
           AND DATE(created_at) = $3
           ORDER BY created_at",
          params = list(input$selected_student, selected_subject, selected_date)),
        error = function(e) data.frame()
      )

      if (nrow(day_chat) == 0) return(tags$p("Söhbət tapılmadı"))

      tags$div(style = "max-height: 400px; overflow-y: auto; border: 1px solid #ddd; border-radius: 8px; padding: 12px; background: #fafafa;",
        tags$h5(paste0(selected_subject, " — ", format(selected_date, "%d.%m.%Y"))),
        lapply(seq_len(nrow(day_chat)), function(i) {
          msg <- day_chat[i, ]
          is_user <- msg$role == "user"
          tags$div(
            style = paste0(
              "margin-bottom: 8px; padding: 8px 12px; border-radius: 12px; max-width: 90%; font-size: 0.9em; ",
              if (is_user) "background: #3498db; color: #fff; margin-left: auto; text-align: right;"
              else "background: #e8e8e8; color: #333;"
            ),
            if (!is_user) tags$small(style = "color: #666;", "AI Tutor — ", format(msg$created_at, "%H:%M")),
            if (is_user) tags$small(style = "color: #cce5ff;", "Şagird — ", format(msg$created_at, "%H:%M")),
            tags$br(),
            HTML(if (is_user) htmltools::htmlEscape(msg$content) else tutor_md_to_html(msg$content))
          )
        })
      )
    })
  })
}

# --- Fərdi İnkişaf Planı Server ---
# student_idp_ui və student_idp_server modules/student/student_idp.R faylına köçürülüb
