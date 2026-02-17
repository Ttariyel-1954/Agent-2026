# =============================================
# Sertifikasiya Modulu - Server
# =============================================

# --- İşə Qəbul İmtahanları Server ---
cert_recruitment_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Reaktiv data
    recruitment_exams <- reactive({
      input$btn_refresh
      query <- "SELECT ce.*, s.name AS subject_name,
                       COUNT(cr.id) AS participant_count
                FROM certification_exams ce
                LEFT JOIN subjects s ON ce.subject_id = s.id
                LEFT JOIN certification_results cr ON cr.exam_id = ce.id
                WHERE ce.exam_type = 'ise_qebul'"
      params <- list()
      param_idx <- 1

      if (!is_empty(input$filter_status)) {
        query <- paste0(query, " AND ce.status = $", param_idx)
        params[[param_idx]] <- input$filter_status
        param_idx <- param_idx + 1
      }

      query <- paste0(query, " GROUP BY ce.id, s.name ORDER BY ce.exam_date DESC")

      if (length(params) > 0) db_query(db_pool, query, params = params)
      else db_query(db_pool, query)
    })

    # Cədvəl
    output$recruitment_table <- renderDT({
      data <- recruitment_exams()
      if (nrow(data) == 0) return(datatable(data.frame("Məlumat yoxdur" = character(0))))

      display <- data %>%
        select(title, subject_name, exam_date, duration_minutes,
               participant_count, status) %>%
        rename(
          "İmtahan" = title, "Fənn" = subject_name, "Tarix" = exam_date,
          "Müddət (dəq)" = duration_minutes, "İştirakçı" = participant_count,
          "Status" = status
        )

      datatable(display, selection = "single", options = default_dt_options())
    })

    # Yeni imtahan əlavə et
    observeEvent(input$btn_add_exam, {
      showModal(modalDialog(
        title = "Yeni İşə Qəbul İmtahanı",
        textInput(ns("exam_title"), "İmtahan adı:"),
        selectInput(ns("exam_subject"), "Fənn:", choices = c("Seçin" = "", SUBJECTS)),
        textAreaInput(ns("exam_desc"), "Təsvir:", rows = 3),
        numericInput(ns("exam_duration"), "Müddət (dəq):", value = 120, min = 15, max = 480),
        numericInput(ns("exam_questions"), "Sual sayı:", value = 50, min = 10, max = 200),
        numericInput(ns("exam_passing"), "Keçid balı:", value = 50, min = 0, max = 100),
        dateInput(ns("exam_date_input"), "Tarix:", language = "az"),
        textInput(ns("exam_location"), "Məkan:"),
        numericInput(ns("exam_max_part"), "Maks. iştirakçı:", value = 100, min = 1),
        footer = tagList(
          modalButton("Ləğv et"),
          actionButton(ns("btn_save_exam"), "Saxla", class = "btn-primary")
        )
      ))
    })

    observeEvent(input$btn_save_exam, {
      exam_data <- list(
        title = input$exam_title,
        exam_type = "ise_qebul",
        subject_id = if (is_empty(input$exam_subject)) NULL else input$exam_subject,
        description = input$exam_desc,
        duration_minutes = input$exam_duration,
        total_questions = input$exam_questions,
        passing_score = input$exam_passing,
        exam_date = input$exam_date_input,
        start_time = NULL,
        location = input$exam_location,
        max_participants = input$exam_max_part,
        created_by = user_data()$sub
      )

      errors <- validate_exam_data(exam_data)
      if (length(errors) > 0) {
        notify_error(paste(errors, collapse = "\n"))
        return()
      }

      tryCatch({
        schedule_exam(db_pool, exam_data)
        removeModal()
        notify_success("İmtahan uğurla yaradıldı")
      }, error = function(e) {
        log_error("İmtahan yaratma xətası: {e$message}")
        notify_error("İmtahan yaradılarkən xəta baş verdi")
      })
    })
  })
}

# --- Sertifikasiya İmtahanları Server ---
cert_exams_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    cert_exams <- reactive({
      input$btn_cert_refresh
      query <- "SELECT ce.*, s.name AS subject_name,
                       COUNT(cr.id) AS participant_count,
                       AVG(cr.score) AS avg_score,
                       SUM(CASE WHEN cr.passed THEN 1 ELSE 0 END) AS passed_count
                FROM certification_exams ce
                LEFT JOIN subjects s ON ce.subject_id = s.id
                LEFT JOIN certification_results cr ON cr.exam_id = ce.id
                WHERE ce.exam_type = 'sertifikasiya'"
      params <- list()
      param_idx <- 1

      if (!is_empty(input$filter_cert_status)) {
        query <- paste0(query, " AND ce.status = $", param_idx)
        params[[param_idx]] <- input$filter_cert_status
        param_idx <- param_idx + 1
      }

      query <- paste0(query, " GROUP BY ce.id, s.name ORDER BY ce.exam_date DESC")

      if (length(params) > 0) db_query(db_pool, query, params = params)
      else db_query(db_pool, query)
    })

    output$cert_exams_table <- renderDT({
      data <- cert_exams()
      if (nrow(data) == 0) return(datatable(data.frame("Məlumat yoxdur" = character(0))))

      display <- data %>%
        mutate(pass_rate = ifelse(participant_count > 0,
          round(passed_count / participant_count * 100, 1), 0)) %>%
        select(title, subject_name, exam_date, participant_count, avg_score, pass_rate, status) %>%
        rename(
          "İmtahan" = title, "Fənn" = subject_name, "Tarix" = exam_date,
          "İştirakçı" = participant_count, "Orta Bal" = avg_score,
          "Keçid (%)" = pass_rate, "Status" = status
        )

      datatable(display, selection = "single", options = default_dt_options())
    })

    # Statistika qutuları
    output$total_participants_box <- renderValueBox({
      data <- cert_exams()
      total <- sum(data$participant_count, na.rm = TRUE)
      valueBox(total, "Ümumi İştirakçı", icon = icon("users"), color = "aqua")
    })

    output$pass_rate_box <- renderValueBox({
      data <- cert_exams()
      total_p <- sum(data$participant_count, na.rm = TRUE)
      total_passed <- sum(data$passed_count, na.rm = TRUE)
      rate <- if (total_p > 0) round(total_passed / total_p * 100, 1) else 0
      valueBox(paste0(rate, "%"), "Keçid Faizi", icon = icon("check-circle"), color = "green")
    })

    output$avg_score_box <- renderValueBox({
      data <- cert_exams()
      avg <- round(mean(data$avg_score, na.rm = TRUE), 1)
      valueBox(avg, "Orta Bal", icon = icon("chart-bar"), color = "yellow")
    })

    output$total_certs_box <- renderValueBox({
      count <- db_get_one(db_pool,
        "SELECT COUNT(*) as cnt FROM certification_results
         WHERE certificate_number IS NOT NULL")
      valueBox(count$cnt, "Verilmiş Sertifikat", icon = icon("certificate"), color = "purple")
    })

    # Yeni sertifikasiya əlavə et
    observeEvent(input$btn_add_cert, {
      showModal(modalDialog(
        title = "Yeni Sertifikasiya İmtahanı",
        textInput(ns("cert_title"), "İmtahan adı:"),
        selectInput(ns("cert_subject"), "Fənn:", choices = c("Seçin" = "", SUBJECTS)),
        selectInput(ns("cert_level"), "Səviyyə:", choices = CERTIFICATION_LEVELS),
        textAreaInput(ns("cert_desc"), "Təsvir:", rows = 3),
        numericInput(ns("cert_duration"), "Müddət (dəq):", value = 180, min = 30, max = 480),
        numericInput(ns("cert_passing"), "Keçid balı:", value = 60, min = 0, max = 100),
        dateInput(ns("cert_date_input"), "Tarix:", language = "az"),
        footer = tagList(
          modalButton("Ləğv et"),
          actionButton(ns("btn_save_cert"), "Saxla", class = "btn-success")
        )
      ))
    })

    observeEvent(input$btn_save_cert, {
      exam_data <- list(
        title = input$cert_title,
        exam_type = "sertifikasiya",
        subject_id = if (is_empty(input$cert_subject)) NULL else input$cert_subject,
        description = input$cert_desc,
        duration_minutes = input$cert_duration,
        total_questions = 0,
        passing_score = input$cert_passing,
        exam_date = input$cert_date_input,
        start_time = NULL,
        location = NULL,
        max_participants = NULL,
        created_by = user_data()$sub
      )

      errors <- validate_exam_data(exam_data)
      if (length(errors) > 0) {
        notify_error(paste(errors, collapse = "\n"))
        return()
      }

      tryCatch({
        schedule_exam(db_pool, exam_data)
        removeModal()
        notify_success("Sertifikasiya imtahanı yaradıldı")
      }, error = function(e) {
        log_error("Sertifikasiya yaratma xətası: {e$message}")
        notify_error("Xəta baş verdi")
      })
    })
  })
}

# --- Sual Bazası Server ---
cert_questions_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # İmtahan siyahısını yenilə
    observe({
      exams <- db_query(db_pool,
        "SELECT id, title FROM certification_exams ORDER BY created_at DESC")
      choices <- c("Hamısı" = "")
      if (nrow(exams) > 0) {
        exam_choices <- setNames(exams$id, exams$title)
        choices <- c(choices, exam_choices)
      }
      updateSelectInput(session, "filter_q_exam", choices = choices)
    })

    questions <- reactive({
      query <- "SELECT cq.*, ce.title AS exam_title
                FROM certification_questions cq
                JOIN certification_exams ce ON cq.exam_id = ce.id
                WHERE cq.is_active = TRUE"
      params <- list()
      param_idx <- 1

      if (!is_empty(input$filter_q_exam)) {
        query <- paste0(query, " AND cq.exam_id = $", param_idx)
        params[[param_idx]] <- input$filter_q_exam
        param_idx <- param_idx + 1
      }

      if (!is_empty(input$filter_q_difficulty)) {
        query <- paste0(query, " AND cq.difficulty = $", param_idx)
        params[[param_idx]] <- input$filter_q_difficulty
        param_idx <- param_idx + 1
      }

      if (!is_empty(input$filter_q_type)) {
        query <- paste0(query, " AND cq.question_type = $", param_idx)
        params[[param_idx]] <- input$filter_q_type
        param_idx <- param_idx + 1
      }

      query <- paste0(query, " ORDER BY cq.sort_order, cq.created_at DESC")

      if (length(params) > 0) db_query(db_pool, query, params = params)
      else db_query(db_pool, query)
    })

    output$questions_table <- renderDT({
      data <- questions()
      if (nrow(data) == 0) return(datatable(data.frame("Məlumat yoxdur" = character(0))))

      display <- data %>%
        select(exam_title, question_text, question_type, difficulty, points) %>%
        mutate(question_text = substr(question_text, 1, 100)) %>%
        rename(
          "İmtahan" = exam_title, "Sual" = question_text, "Növ" = question_type,
          "Çətinlik" = difficulty, "Bal" = points
        )

      datatable(display, selection = "single", options = default_dt_options())
    })

    # Yeni sual əlavə et
    observeEvent(input$btn_add_question, {
      exams <- db_query(db_pool, "SELECT id, title FROM certification_exams ORDER BY title")
      exam_choices <- setNames(exams$id, exams$title)

      showModal(modalDialog(
        title = "Yeni Sual", size = "l",
        selectInput(ns("q_exam"), "İmtahan:", choices = exam_choices),
        textAreaInput(ns("q_text"), "Sual mətni:", rows = 4),
        selectInput(ns("q_type"), "Sual növü:",
          choices = c("Çoxseçimli" = "mcq", "Doğru/Yanlış" = "true_false", "Qısa Cavab" = "short_answer")),
        textInput(ns("q_option_a"), "Variant A:"),
        textInput(ns("q_option_b"), "Variant B:"),
        textInput(ns("q_option_c"), "Variant C:"),
        textInput(ns("q_option_d"), "Variant D:"),
        selectInput(ns("q_correct"), "Düzgün cavab:", choices = c("A", "B", "C", "D")),
        selectInput(ns("q_difficulty"), "Çətinlik:", choices = DIFFICULTY_LEVELS),
        selectInput(ns("q_bloom"), "Bloom səviyyəsi:", choices = BLOOM_LEVELS),
        numericInput(ns("q_points"), "Bal:", value = 1, min = 0.5, max = 10, step = 0.5),
        footer = tagList(
          modalButton("Ləğv et"),
          actionButton(ns("btn_save_question"), "Saxla", class = "btn-primary")
        )
      ))
    })

    observeEvent(input$btn_save_question, {
      q_data <- list(
        question_text = input$q_text,
        correct_answer = input$q_correct,
        question_type = input$q_type,
        option_a = input$q_option_a,
        option_b = input$q_option_b
      )

      errors <- validate_question_data(q_data)
      if (length(errors) > 0) {
        notify_error(paste(errors, collapse = "\n"))
        return()
      }

      tryCatch({
        db_execute(db_pool,
          "INSERT INTO certification_questions
           (exam_id, question_text, question_type, option_a, option_b, option_c, option_d,
            correct_answer, difficulty, bloom_level, points)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)",
          params = list(
            input$q_exam, input$q_text, input$q_type,
            input$q_option_a, input$q_option_b, input$q_option_c, input$q_option_d,
            input$q_correct, input$q_difficulty, input$q_bloom, input$q_points
          ))
        removeModal()
        notify_success("Sual əlavə edildi")
      }, error = function(e) {
        log_error("Sual əlavə xətası: {e$message}")
        notify_error("Xəta baş verdi")
      })
    })

    # İxrac
    output$btn_export_questions <- downloadHandler(
      filename = function() paste0("suallar_", format(Sys.Date(), "%Y%m%d"), ".xlsx"),
      content = function(file) {
        export_to_excel(questions(), file, "Suallar")
      }
    )
  })
}

# --- Avtomatlaşdırma Server ---
cert_automation_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # İmtahan siyahısını yenilə
    observe({
      exams <- db_query(db_pool,
        "SELECT id, title FROM certification_exams
         WHERE status IN ('active', 'completed') ORDER BY exam_date DESC")
      choices <- c("Seçin" = "")
      if (nrow(exams) > 0) {
        choices <- c(choices, setNames(exams$id, exams$title))
      }
      updateSelectInput(session, "eval_exam", choices = choices)
    })

    # Avtomatik planlaşdırma
    observeEvent(input$btn_auto_schedule, {
      exam_data <- list(
        title = paste0("Avtomatik - ", input$auto_exam_type, " - ",
                       format(input$auto_date, "%d.%m.%Y")),
        exam_type = input$auto_exam_type,
        subject_id = if (is_empty(input$auto_subject)) NULL else input$auto_subject,
        description = "Avtomatik planlaşdırılmış imtahan",
        duration_minutes = input$auto_duration,
        total_questions = input$auto_question_count,
        passing_score = 50,
        exam_date = input$auto_date,
        start_time = NULL,
        location = NULL,
        max_participants = NULL,
        created_by = user_data()$sub
      )

      tryCatch({
        schedule_exam(db_pool, exam_data)
        notify_success("İmtahan avtomatik planlaşdırıldı")
      }, error = function(e) {
        log_error("Avtomatik planlaşdırma xətası: {e$message}")
        notify_error("Planlaşdırma zamanı xəta baş verdi")
      })
    })

    # Avtomatik qiymətləndirmə
    observeEvent(input$btn_auto_evaluate, {
      req(input$eval_exam)

      tryCatch({
        result <- calculate_exam_results(db_pool, input$eval_exam)

        output$evaluation_summary <- renderUI({
          if (is.null(result) || length(result$stats) == 0) {
            return(tags$p(class = "text-muted", "Nəticə tapılmadı"))
          }
          s <- result$stats
          tags$div(
            tags$p(tags$strong("İştirakçı sayı: "), s$total_participants),
            tags$p(tags$strong("Keçənlər: "), s$passed_count),
            tags$p(tags$strong("Kəsilənlər: "), s$failed_count),
            tags$p(tags$strong("Orta bal: "), s$avg_score),
            tags$p(tags$strong("Keçid faizi: "), paste0(s$pass_rate, "%"))
          )
        })

        notify_success("Qiymətləndirmə tamamlandı")
      }, error = function(e) {
        log_error("Qiymətləndirmə xətası: {e$message}")
        notify_error("Qiymətləndirmə zamanı xəta baş verdi")
      })
    })
  })
}
