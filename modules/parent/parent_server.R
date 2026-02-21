# =============================================
# ARTI-2026: Valideyn Əlaqə Modulu — Server Məntiqi
# =============================================

# === 1. Fərdi Məktub Server ===
parent_letter_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Reaktiv dəyişənlər
    current_letter <- reactiveVal(NULL)
    current_letter_id <- reactiveVal(NULL)

    # Məktəb siyahısı
    observe({
      choices <- get_school_choices_parent(db_pool)
      updateSelectInput(session, "school_filter", choices = choices)
    })

    # Şagird siyahısını filtrə görə yenilə
    observe({
      choices <- get_student_choices(db_pool, input$school_filter, input$grade_filter)
      updateSelectizeInput(session, "student_select", choices = choices)
    })

    # === Valideyn kontakt məlumatları ===
    output$parent_contact_ui <- renderUI({
      req(input$student_select)
      parent <- tryCatch(
        db_get_one(db_pool, "
          SELECT first_name, last_name, phone, email, parent_type
          FROM student_parents WHERE student_id = $1 AND is_primary_contact = TRUE LIMIT 1
        ", params = list(input$student_select)),
        error = function(e) NULL
      )

      if (is.null(parent)) {
        fluidRow(column(12, div(class = "alert alert-warning",
          icon("exclamation-triangle"), " Valideyn kontakt məlumatları tapılmadı. ",
          "Şagird qeydiyyatından valideyn məlumatlarını əlavə edin."
        )))
      } else {
        type_label <- switch(parent$parent_type %||% "", "ata" = "Ata", "ana" = "Ana", "qeyyum" = "Qəyyum", "Valideyn")
        fluidRow(column(12, div(class = "alert alert-info",
          icon("user"), sprintf(" %s: %s %s | ", type_label, parent$first_name %||% "", parent$last_name %||% ""),
          icon("phone"), sprintf(" %s | ", parent$phone %||% "Yoxdur"),
          icon("envelope"), sprintf(" %s", parent$email %||% "Yoxdur")
        )))
      }
    })

    # === AI Məktub Generasiyası ===
    observeEvent(input$btn_generate, {
      req(input$student_select)

      withProgress(message = "AI valideyn məktubu hazırlayır...", value = 0.3, {
        result <- tryCatch({
          generate_parent_letter(
            db_pool = db_pool,
            student_id = input$student_select,
            month = as.integer(input$report_month),
            year = as.integer(input$report_year),
            user_id = user_data()$id
          )
        }, error = function(e) {
          list(success = FALSE, error = e$message)
        })
        setProgress(1)
      })

      if (isTRUE(result$success)) {
        current_letter(result)
        current_letter_id(result$letter_id)
        # Redaktə sahəsinə mətni yüklə
        updateTextAreaInput(session, "teacher_edit_text",
                            value = result$data$full_letter_text %||% "")
        notify_success("Valideyn məktubu uğurla yaradıldı!")
      } else {
        notify_error(paste("Xəta:", result$error %||% "Naməlum xəta"))
      }
    })

    # === Status badge ===
    output$letter_status_badge <- renderUI({
      letter <- current_letter()
      if (is.null(letter)) return(NULL)

      # DB-dən status al
      if (!is.null(current_letter_id())) {
        detail <- tryCatch(
          db_get_one(db_pool, "SELECT status FROM parent_letters WHERE id = $1",
                     params = list(current_letter_id())),
          error = function(e) NULL
        )
        if (!is.null(detail)) {
          return(HTML(letter_status_badge(detail$status)))
        }
      }
      HTML(letter_status_badge("draft"))
    })

    # === Məktub önizləmə ===
    output$letter_preview <- renderUI({
      letter <- current_letter()
      if (is.null(letter)) {
        return(tags$div(class = "text-center text-muted", style = "padding: 50px;",
          icon("envelope-open", class = "fa-3x"), tags$br(), tags$br(),
          tags$p("Şagird seçib \"AI Məktub Yarat\" düyməsinə basın")
        ))
      }

      tags$div(style = "border: 1px solid #ddd; border-radius: 8px; padding: 0;",
        HTML(letter$html %||% "<p>Məktub HTML-i yaradılmadı</p>")
      )
    })

    # === Redaktəni saxla ===
    observeEvent(input$btn_save_edit, {
      req(current_letter_id(), input$teacher_edit_text)

      success <- save_teacher_edit(db_pool, current_letter_id(),
                                    input$teacher_edit_text, user_data()$id)
      if (success) {
        notify_success("Redaktə saxlanıldı!")
      } else {
        notify_error("Redaktə saxlanılmadı")
      }
    })

    # === Təsdiq et ===
    observeEvent(input$btn_approve, {
      req(current_letter_id())

      success <- approve_letter(db_pool, current_letter_id(), user_data()$id)
      if (success) {
        notify_success("Məktub təsdiq edildi!")
      } else {
        notify_error("Təsdiq uğursuz oldu")
      }
    })

    # === E-poçt göndər ===
    observeEvent(input$btn_send_email, {
      req(current_letter_id())

      result <- send_letter_email(db_pool, current_letter_id())
      if (isTRUE(result$success)) {
        notify_success("E-poçt uğurla göndərildi!")
      } else {
        notify_error(paste("E-poçt göndərilmədi:", result$error %||% ""))
      }
    })

    # === SMS göndər ===
    observeEvent(input$btn_send_sms, {
      req(current_letter_id())

      result <- send_letter_sms(db_pool, current_letter_id())
      if (isTRUE(result$success)) {
        notify_success("SMS uğurla göndərildi!")
      } else {
        notify_error(paste("SMS göndərilmədi:", result$error %||% ""))
      }
    })

    # === HTML yüklə ===
    output$btn_download_html <- downloadHandler(
      filename = function() {
        paste0("valideyn_mektub_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".html")
      },
      content = function(file) {
        letter <- current_letter()
        if (!is.null(letter) && !is.null(letter$html)) {
          writeLines(letter$html, file)
        }
      }
    )

    # === Məktub statistikası ===
    output$letter_stats <- renderUI({
      letter <- current_letter()
      if (is.null(letter)) return(tags$p(class = "text-muted", "Məktub yaradılmadıq"))

      parsed <- letter$data
      tone_color <- switch(parsed$overall_tone %||% "neutral",
        "positive" = "#27ae60", "concerned" = "#e74c3c", "#f39c12")
      tone_label <- switch(parsed$overall_tone %||% "neutral",
        "positive" = "Pozitiv", "concerned" = "Narahatedici", "Neytral")

      tagList(
        tags$div(style = sprintf("text-align:center; padding:10px; background:%s22; border-radius:5px;", tone_color),
          tags$small("Məktub tonu"),
          tags$h4(style = sprintf("color:%s", tone_color), tone_label)
        ),
        hr(),
        tags$small("Ümumi GPA: ", tags$strong(parsed$academic_section$overall_gpa %||% "N/A")),
        tags$br(),
        tags$small("Güclü tərəflər: ", tags$strong(length(parsed$strengths %||% list()))),
        tags$br(),
        tags$small("Tövsiyələr: ", tags$strong(length(parsed$recommendations %||% list()))),
        tags$br(),
        tags$small("Token: ", tags$strong(letter$usage$total_tokens %||% 0))
      )
    })
  })
}

# === 2. Toplu Generasiya Server ===
parent_batch_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    batch_results <- reactiveVal(NULL)

    # Məktəb siyahısı
    observe({
      choices <- get_school_choices_parent(db_pool)
      updateSelectInput(session, "batch_school", choices = choices)
    })

    # Bölmə siyahısı
    observe({
      sections <- get_class_sections(db_pool, input$batch_school)
      if (nrow(sections) > 0) {
        section_choices <- c("Hamısı" = "", unique(sections$section))
      } else {
        section_choices <- c("Hamısı" = "")
      }
      updateSelectInput(session, "batch_section", choices = section_choices)
    })

    # Məlumat paneli
    output$batch_info <- renderUI({
      student_ids <- get_students_by_class(db_pool, input$batch_school,
                                            input$batch_grade, input$batch_section)
      count <- length(student_ids)

      if (count == 0) {
        div(class = "alert alert-warning",
          icon("exclamation-triangle"), " Seçilmiş filtrlərə uyğun şagird tapılmadı")
      } else {
        div(class = "alert alert-info",
          icon("info-circle"), sprintf(" %d şagird üçün məktub yaradılacaq. ", count),
          sprintf("Təxmini vaxt: %d dəqiqə.", ceiling(count * 0.8 / 60) + 1))
      }
    })

    # === Toplu generasiya ===
    observeEvent(input$btn_batch_generate, {
      student_ids <- get_students_by_class(db_pool, input$batch_school,
                                            input$batch_grade, input$batch_section)
      if (length(student_ids) == 0) {
        notify_warning("Şagird tapılmadı")
        return()
      }

      if (length(student_ids) > 100) {
        notify_warning("Bir dəfədə maksimum 100 şagird seçilə bilər")
        return()
      }

      withProgress(message = "Toplu məktub yaradılır...", value = 0, {
        results <- batch_generate_letters(
          db_pool = db_pool,
          student_ids = student_ids,
          month = as.integer(input$batch_month),
          year = as.integer(input$batch_year),
          user_id = user_data()$id,
          progress_callback = function(value, detail) {
            setProgress(value = value, detail = detail)
          }
        )
      })

      batch_results(results)

      success_count <- sum(sapply(results, function(r) isTRUE(r$success)))
      fail_count <- length(results) - success_count
      notify_success(sprintf("Tamamlandı: %d uğurlu, %d uğursuz", success_count, fail_count))
    })

    # === Nəticələr cədvəli ===
    output$batch_results_table <- renderDT({
      results <- batch_results()
      if (is.null(results) || length(results) == 0) {
        return(datatable(data.frame(Mesaj = "Nəticə yoxdur"), rownames = FALSE))
      }

      # Şagird adlarını al
      ids <- sapply(results, function(r) r$student_id)
      names_df <- tryCatch(
        db_query(db_pool, sprintf(
          "SELECT id, first_name || ' ' || last_name AS name FROM students WHERE id IN (%s)",
          paste0("'", ids, "'", collapse = ",")
        )),
        error = function(e) data.frame(id = ids, name = rep("N/A", length(ids)))
      )

      df <- data.frame(
        student = sapply(results, function(r) {
          match_row <- names_df[names_df$id == r$student_id, ]
          if (nrow(match_row) > 0) match_row$name[1] else "N/A"
        }),
        status = sapply(results, function(r) if (isTRUE(r$success)) "Uğurlu" else "Uğursuz"),
        error = sapply(results, function(r) r$error %||% ""),
        stringsAsFactors = FALSE
      )

      datatable(df, options = default_dt_options(20), rownames = FALSE,
        colnames = c("Şagird", "Status", "Xəta")) %>%
        formatStyle("status", color = styleEqual(c("Uğurlu", "Uğursuz"), c("#27ae60", "#e74c3c")))
    })

    # === Toplu təsdiq ===
    observeEvent(input$btn_batch_approve, {
      results <- batch_results()
      if (is.null(results)) return()

      count <- 0
      for (r in results) {
        if (isTRUE(r$success) && !is.null(r$letter_id)) {
          approve_letter(db_pool, r$letter_id, user_data()$id)
          count <- count + 1
        }
      }
      notify_success(sprintf("%d məktub təsdiq edildi", count))
    })

    # === Toplu e-poçt ===
    observeEvent(input$btn_batch_send_email, {
      results <- batch_results()
      if (is.null(results)) return()

      success <- 0
      for (r in results) {
        if (isTRUE(r$success) && !is.null(r$letter_id)) {
          res <- send_letter_email(db_pool, r$letter_id)
          if (isTRUE(res$success)) success <- success + 1
        }
      }
      notify_success(sprintf("%d e-poçt göndərildi", success))
    })

    # === Toplu SMS ===
    observeEvent(input$btn_batch_send_sms, {
      results <- batch_results()
      if (is.null(results)) return()

      success <- 0
      for (r in results) {
        if (isTRUE(r$success) && !is.null(r$letter_id)) {
          res <- send_letter_sms(db_pool, r$letter_id)
          if (isTRUE(res$success)) success <- success + 1
        }
      }
      notify_success(sprintf("%d SMS göndərildi", success))
    })
  })
}

# === 3. Tarixçə Server ===
parent_history_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    selected_letter_id <- reactiveVal(NULL)

    # Məktəb siyahısı
    observe({
      choices <- get_school_choices_parent(db_pool)
      updateSelectInput(session, "hist_school", choices = choices)
    })

    # === Statistika kartları ===
    stats <- reactive({
      input$btn_refresh  # reaktivlik
      get_delivery_stats(db_pool)
    })

    output$vb_total <- renderValueBox({
      s <- stats()
      valueBox(s$total %||% 0, "Ümumi Məktub", icon = icon("envelope"), color = "purple")
    })

    output$vb_approved <- renderValueBox({
      s <- stats()
      valueBox(s$approved_count %||% 0, "Təsdiq Edilib", icon = icon("check"), color = "yellow")
    })

    output$vb_sent <- renderValueBox({
      s <- stats()
      valueBox(s$sent_count %||% 0, "Göndərilib", icon = icon("paper-plane"), color = "green")
    })

    output$vb_failed <- renderValueBox({
      s <- stats()
      valueBox(s$failed_count %||% 0, "Uğursuz", icon = icon("times"), color = "red")
    })

    # === Tarixçə cədvəli ===
    output$history_table <- renderDT({
      input$btn_refresh  # reaktivlik

      data <- get_parent_letters(
        db_pool,
        school_id = input$hist_school,
        class_grade = input$hist_grade,
        month = input$hist_month,
        status = input$hist_status
      )

      if (is.null(data) || nrow(data) == 0) {
        return(datatable(data.frame(Mesaj = "Məktub tapılmadı"), rownames = FALSE))
      }

      data$month_name <- sapply(data$report_month, function(m) MONTH_NAMES_AZ[m] %||% m)
      data$status_label <- sapply(data$status, function(s) LETTER_STATUS_LABELS[s] %||% s)
      data$sent_via_label <- sapply(data$sent_via %||% rep("none", nrow(data)), function(v) {
        SEND_VIA_LABELS[v %||% "none"] %||% "—"
      })
      data$created_at <- format_datetime_az(data$created_at)
      data$class_label <- paste0(data$class_grade, "-", data$class_section)

      datatable(
        data[, c("student_name", "class_label", "month_name", "status_label",
                  "sent_via_label", "recipient_email", "created_at")],
        options = default_dt_options(20),
        rownames = FALSE, selection = "single",
        colnames = c("Şagird", "Sinif", "Ay", "Status", "Göndərilmə", "E-poçt", "Tarix")
      ) %>%
        formatStyle("status_label", color = styleEqual(
          c("Qaralama", "Redaktə edilib", "Təsdiq edilib", "Göndərilib", "Uğursuz"),
          c("#777", "#3498db", "#f39c12", "#27ae60", "#e74c3c")
        ))
    })

    # === Seçilmiş məktub detalı ===
    observeEvent(input$history_table_rows_selected, {
      idx <- input$history_table_rows_selected
      if (length(idx) == 0) return()

      data <- get_parent_letters(db_pool, school_id = input$hist_school,
                                  class_grade = input$hist_grade,
                                  month = input$hist_month, status = input$hist_status)
      if (idx <= nrow(data)) {
        selected_letter_id(data$id[idx])
      }
    })

    output$selected_letter_detail <- renderUI({
      lid <- selected_letter_id()
      if (is.null(lid)) return(NULL)

      letter <- get_letter_detail(db_pool, lid)
      if (is.null(letter)) return(NULL)

      wellPanel(
        h4(icon("file-alt"), sprintf("Məktub Detalı — %s", letter$student_name)),
        fluidRow(
          column(4, tags$small("Status: "), HTML(letter_status_badge(letter$status))),
          column(4, tags$small("Göndərilmə: "), tags$strong(SEND_VIA_LABELS[letter$sent_via %||% "none"] %||% "—")),
          column(4, tags$small("Alıcı: "), tags$strong(letter$recipient_name %||% "N/A"))
        ),
        hr(),
        if (!is.null(letter$letter_html)) {
          tags$div(style = "border:1px solid #ddd; border-radius:8px; max-height:500px; overflow-y:auto;",
            HTML(letter$letter_html))
        } else if (!is.null(letter$letter_text)) {
          tags$pre(style = "white-space: pre-wrap;", letter$letter_text)
        } else {
          tags$p(class = "text-muted", "Məktub məzmunu yoxdur")
        },
        hr(),
        div(class = "btn-toolbar",
          actionButton(ns("btn_resend_email"), "Yenidən E-poçt", icon = icon("envelope"), class = "btn-primary btn-sm"),
          actionButton(ns("btn_resend_sms"), "Yenidən SMS", icon = icon("sms"), class = "btn-info btn-sm")
        )
      )
    })

    # Yenidən göndər
    observeEvent(input$btn_resend_email, {
      req(selected_letter_id())
      result <- send_letter_email(db_pool, selected_letter_id())
      if (isTRUE(result$success)) notify_success("E-poçt yenidən göndərildi!")
      else notify_error(paste("Xəta:", result$error %||% ""))
    })

    observeEvent(input$btn_resend_sms, {
      req(selected_letter_id())
      result <- send_letter_sms(db_pool, selected_letter_id())
      if (isTRUE(result$success)) notify_success("SMS yenidən göndərildi!")
      else notify_error(paste("Xəta:", result$error %||% ""))
    })

    # === Göndərmə jurnalı ===
    output$delivery_log_table <- renderDT({
      lid <- selected_letter_id()
      if (is.null(lid)) {
        return(datatable(data.frame(Mesaj = "Məktub seçin"), rownames = FALSE))
      }

      log_data <- get_message_log(db_pool, lid)
      if (is.null(log_data) || nrow(log_data) == 0) {
        return(datatable(data.frame(Mesaj = "Göndərmə qeydi yoxdur"), rownames = FALSE))
      }

      log_data$channel <- sapply(log_data$channel, function(c) {
        switch(c, "email" = "E-poçt", "sms" = "SMS", c)
      })
      log_data$status <- sapply(log_data$status, function(s) {
        switch(s, "pending" = "Gözləyir", "sent" = "Göndərilib",
               "delivered" = "Çatdırılıb", "failed" = "Uğursuz", "bounced" = "Geri qayıdıb", s)
      })
      log_data$sent_at <- format_datetime_az(log_data$sent_at)

      datatable(log_data[, c("channel", "recipient", "status", "sent_at", "error_message")],
        options = default_dt_options(10), rownames = FALSE,
        colnames = c("Kanal", "Alıcı", "Status", "Göndərilmə", "Xəta"))
    })

    # === Excel ixracı ===
    output$btn_export <- downloadHandler(
      filename = function() {
        paste0("valideyn_mektublari_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".xlsx")
      },
      content = function(file) {
        data <- get_parent_letters(db_pool, school_id = input$hist_school,
                                    class_grade = input$hist_grade,
                                    month = input$hist_month, status = input$hist_status, limit = 1000)
        export_to_excel(data, file, "Valideyn Məktubları")
      }
    )
  })
}
