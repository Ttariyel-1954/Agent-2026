# =============================================
# ARTI-2026: AI Tutor — Şagird üçün AI Repetitor
# Gün 13: UI (şagird profili) + Gün 14: Server (kontekstli söhbət)
# =============================================

# =============================================
# UI (Gün 13)
# =============================================
ai_tutor_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(
      column(12,
        h2(icon("user-graduate"), "AI Repetitor"),
        tags$p(class = "text-muted",
          "Şagird profilinə əsasən fərdiləşdirilmiş AI repetitor — fənn üzrə sual soruş, izah al"),
        hr()
      )
    ),

    fluidRow(
      # Sol panel — Şagird Profili + Söhbət
      column(8,
        # Şagird seçimi
        box(
          title = tagList(icon("search"), " Şagird Seçimi"),
          status = "primary", solidHeader = TRUE, width = 12, collapsible = TRUE,
          fluidRow(
            column(5, selectInput(ns("tutor_student"), "Şagird:", choices = c("Seçin..." = ""))),
            column(3, selectInput(ns("tutor_subject"), "Fənn:", choices = c("Ümumi" = "", SUBJECTS))),
            column(2, selectInput(ns("tutor_mode"), "Rejim:",
                                  choices = c("Söhbət" = "chat", "İzah" = "explain",
                                              "Sual-Cavab" = "quiz", "Motivasiya" = "motivate"))),
            column(2, actionButton(ns("btn_tutor_load"), "Yüklə",
                                   icon = icon("download"), class = "btn-primary",
                                   style = "margin-top:25px; width:100%;"))
          )
        ),

        # Şagird profili kartı
        conditionalPanel(
          condition = paste0("output['", ns("tutor_has_student"), "'] == true"),
          box(
            title = tagList(icon("id-card"), " Şagird Profili"),
            status = "info", solidHeader = TRUE, width = 12, collapsible = TRUE, collapsed = TRUE,
            fluidRow(
              column(3,
                tags$div(style = "text-align:center;",
                  tags$div(style = "width:80px; height:80px; border-radius:50%; background:#3498db; color:#fff; font-size:28px; line-height:80px; margin:0 auto;",
                    textOutput(ns("tutor_initials"), inline = TRUE)),
                  tags$h4(textOutput(ns("tutor_student_name"))),
                  tags$p(class = "text-muted", textOutput(ns("tutor_student_class")))
                )
              ),
              column(3,
                valueBoxOutput(ns("tutor_gpa_box"), width = 12)
              ),
              column(3,
                valueBoxOutput(ns("tutor_attendance_box"), width = 12)
              ),
              column(3,
                valueBoxOutput(ns("tutor_risk_box"), width = 12)
              )
            ),
            # Fənn üzrə ballar
            uiOutput(ns("tutor_subject_scores"))
          )
        ),

        # Söhbət
        box(
          title = tagList(icon("comments"), " AI Söhbət"),
          status = "success", solidHeader = TRUE, width = 12,

          tags$div(
            id = ns("tutor_chat_area"),
            style = "height:450px; overflow-y:auto; border:1px solid #ddd; border-radius:8px; padding:12px; margin-bottom:12px; background:#fafafa;",
            uiOutput(ns("tutor_chat_messages"))
          ),

          tags$div(
            style = "display:flex; gap:8px; align-items:flex-end;",
            tags$div(style = "flex:1;",
              textAreaInput(ns("tutor_input"), label = NULL, rows = 2,
                            placeholder = "Sualını yaz... AI sənin profilinə uyğun cavab verəcək",
                            width = "100%")
            ),
            tags$div(style = "flex-shrink:0;",
              actionButton(ns("btn_tutor_send"), "", icon = icon("paper-plane"),
                           class = "btn-success btn-lg", style = "height:60px; width:60px;")
            )
          ),

          # Alt düymələr
          tags$div(
            style = "margin-top:10px; display:flex; gap:6px;",
            actionButton(ns("btn_tutor_clear"), "Təmizlə", icon = icon("eraser"),
                         class = "btn-default btn-sm"),
            downloadButton(ns("btn_tutor_export"), "Söhbəti Yüklə", class = "btn-info btn-sm"),
            actionButton(ns("btn_tutor_quiz"), "Sual Ver", icon = icon("question-circle"),
                         class = "btn-warning btn-sm"),
            actionButton(ns("btn_tutor_tip"), "Məsləhət Al", icon = icon("lightbulb"),
                         class = "btn-primary btn-sm")
          )
        )
      ),

      # Sağ panel — Yardımçı panellər
      column(4,
        # Sürətli başlatma
        box(
          title = tagList(icon("rocket"), " Sürətli Başlatma"),
          status = "warning", solidHeader = TRUE, width = 12,
          tags$div(style = "display:flex; flex-direction:column; gap:6px;",
            actionLink(ns("quick_explain"), tagList(icon("book"), " Bu mövzunu izah et"),
                       style = "display:block; padding:8px; background:#f8f9fa; border-radius:6px;"),
            actionLink(ns("quick_homework"), tagList(icon("pencil-alt"), " Ev tapşırığında kömək"),
                       style = "display:block; padding:8px; background:#f8f9fa; border-radius:6px;"),
            actionLink(ns("quick_exam"), tagList(icon("clipboard-check"), " İmtahana hazırlaş"),
                       style = "display:block; padding:8px; background:#f8f9fa; border-radius:6px;"),
            actionLink(ns("quick_weak"), tagList(icon("chart-line"), " Zəif tərəflərimi göstər"),
                       style = "display:block; padding:8px; background:#f8f9fa; border-radius:6px;"),
            actionLink(ns("quick_plan"), tagList(icon("calendar"), " Öyrənmə planı hazırla"),
                       style = "display:block; padding:8px; background:#f8f9fa; border-radius:6px;")
          )
        ),

        # Öyrənmə statistikası
        box(
          title = tagList(icon("chart-pie"), " Öyrənmə Analizi"),
          status = "info", solidHeader = TRUE, width = 12, collapsible = TRUE,
          plotlyOutput(ns("tutor_subject_chart"), height = "250px"),
          tags$hr(),
          uiOutput(ns("tutor_recommendations"))
        ),

        # Tarixçə
        box(
          title = tagList(icon("history"), " Son Söhbətlər"),
          status = "primary", solidHeader = TRUE, width = 12, collapsible = TRUE, collapsed = TRUE,
          DTOutput(ns("tutor_history_table"))
        )
      )
    )
  )
}

# =============================================
# SERVER (Gün 14)
# =============================================
ai_tutor_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # === Reactive ===
    student_data   <- reactiveVal(NULL)
    student_grades <- reactiveVal(NULL)
    chat_history   <- reactiveVal(list(
      list(role = "assistant",
           content = "Salam! Mən sənin AI repetitorunam. Şagirdi seçdikdən sonra fənlər üzrə suallarına cavab verəcəyəm. Hər bir cavab şagirdin profilinə uyğunlaşdırılacaq.",
           timestamp = format(Sys.time(), "%H:%M"))
    ))

    # === Has student flag ===
    output$tutor_has_student <- reactive({ !is.null(student_data()) })
    outputOptions(output, "tutor_has_student", suspendWhenHidden = FALSE)

    # === Şagird siyahısını yüklə ===
    observe({
      students <- tryCatch(
        db_query(db_pool,
          "SELECT s.id, s.first_name || ' ' || s.last_name || ' (' || COALESCE(c.grade::text || c.section, '?') || ')' as label
           FROM students s
           LEFT JOIN classes c ON s.class_id = c.id
           WHERE s.status = 'active'
           ORDER BY s.last_name, s.first_name
           LIMIT 500"),
        error = function(e) data.frame()
      )
      if (nrow(students) > 0) {
        updateSelectInput(session, "tutor_student",
          choices = c("Seçin..." = "", setNames(students$id, students$label)))
      }
    })

    # === Şagird yüklə ===
    observeEvent(input$btn_tutor_load, {
      req(input$tutor_student)

      # Şagird əsas info
      student <- tryCatch(
        db_get_one(db_pool,
          "SELECT s.id, s.first_name, s.last_name,
                  s.first_name || ' ' || s.last_name as full_name,
                  c.grade as class_grade, c.section as class_section
           FROM students s
           LEFT JOIN classes c ON s.class_id = c.id
           WHERE s.id = $1",
          params = list(input$tutor_student)),
        error = function(e) NULL
      )

      if (is.null(student)) {
        notify_error("Şagird tapılmadı")
        return()
      }

      student_data(student)

      # Qiymətlər
      grades <- tryCatch(
        db_query(db_pool,
          "SELECT sub.name as subject_name,
                  ROUND(AVG(g.score)::numeric, 1) as avg_score,
                  COUNT(g.id) as grade_count,
                  MIN(g.score) as min_score,
                  MAX(g.score) as max_score
           FROM grades g
           JOIN subjects sub ON g.subject_id = sub.id
           WHERE g.student_id = $1
           GROUP BY sub.name
           ORDER BY avg_score",
          params = list(input$tutor_student)),
        error = function(e) data.frame()
      )
      student_grades(grades)

      # Söhbəti sıfırla ilə ilkin mesaj
      chat_history(list(
        list(role = "assistant",
             content = paste0(
               "Salam, <strong>", htmltools::htmlEscape(student$full_name), "</strong>! ",
               "Mən sənin AI repetitorunam. ",
               if (nrow(grades) > 0) {
                 best <- grades$subject_name[which.max(grades$avg_score)]
                 weak <- grades$subject_name[which.min(grades$avg_score)]
                 paste0("Görürəm ki, <strong>", best, "</strong> fənnindən yaxşı nəticələrin var. ",
                        "<strong>", weak, "</strong> fənnində isə bir az daha çalışmaq lazımdır. ")
               } else "Hələ qiymət məlumatın yoxdur. ",
               "Hansı fəndə kömək istəyirsən?"
             ),
             timestamp = format(Sys.time(), "%H:%M"))
      ))

      notify_success(paste0(student$full_name, " yükləndi"))
    })

    # === Profil göstəriciləri ===
    output$tutor_initials <- renderText({
      s <- student_data()
      if (is.null(s)) return("")
      paste0(substr(s$first_name, 1, 1), substr(s$last_name, 1, 1))
    })

    output$tutor_student_name <- renderText({
      s <- student_data()
      if (is.null(s)) return("")
      s$full_name
    })

    output$tutor_student_class <- renderText({
      s <- student_data()
      if (is.null(s)) return("")
      paste0(s$class_grade, s$class_section, " sinif")
    })

    output$tutor_gpa_box <- renderValueBox({
      gpa <- tryCatch({
        grades <- student_grades()
        val <- if (!is.null(grades) && nrow(grades) > 0) round(mean(grades$avg_score, na.rm = TRUE), 1) else 0
        if (is.null(val) || is.na(val) || is.nan(val)) 0 else val
      }, error = function(e) 0)
      color <- if (gpa >= 86) "green" else if (gpa >= 71) "blue" else if (gpa >= 51) "yellow" else "red"
      valueBox(gpa, "Orta Bal", icon = icon("star"), color = color)
    })

    output$tutor_attendance_box <- renderValueBox({
      att <- tryCatch({
        s <- student_data()
        if (!is.null(s)) {
          r <- db_get_one(db_pool,
            "SELECT ROUND(
              COUNT(CASE WHEN status = 'present' THEN 1 END) * 100.0 / NULLIF(COUNT(*), 0), 1
            ) as rate FROM attendance WHERE student_id = $1 AND attendance_date >= CURRENT_DATE - INTERVAL '90 days'",
            params = list(s$id))
          val <- r$rate %||% 0
          if (is.null(val) || is.na(val)) 0 else val
        } else 0
      }, error = function(e) 0)
      valueBox(paste0(att, "%"), "Davamiyyət", icon = icon("calendar-check"), color = if (att >= 90) "green" else "red")
    })

    output$tutor_risk_box <- renderValueBox({
      gpa <- tryCatch({
        grades <- student_grades()
        val <- if (!is.null(grades) && nrow(grades) > 0) mean(grades$avg_score, na.rm = TRUE) else 0
        if (is.null(val) || is.na(val) || is.nan(val)) 0 else val
      }, error = function(e) 0)
      risk <- if (gpa >= 71) "Aşağı" else if (gpa >= 51) "Orta" else "Yüksək"
      color <- if (risk == "Aşağı") "green" else if (risk == "Orta") "yellow" else "red"
      valueBox(risk, "Risk Səviyyəsi", icon = icon("exclamation-triangle"), color = color)
    })

    # === Fənn balları ===
    output$tutor_subject_scores <- renderUI({
      grades <- student_grades()
      if (is.null(grades) || nrow(grades) == 0) return(tags$p(class = "text-muted", "Qiymət məlumatı yoxdur"))

      tags$div(
        style = "margin-top:10px;",
        lapply(seq_len(nrow(grades)), function(i) {
          g <- grades[i, ]
          pct <- min(max(g$avg_score, 0), 100)
          color <- if (pct >= 86) "#27ae60" else if (pct >= 71) "#3498db" else if (pct >= 51) "#f39c12" else "#e74c3c"
          tags$div(
            style = "margin-bottom:6px;",
            tags$div(style = "display:flex; justify-content:space-between; font-size:0.9em;",
              tags$span(g$subject_name),
              tags$span(style = paste0("color:", color, "; font-weight:bold;"), paste0(g$avg_score, "%"))
            ),
            tags$div(style = "background:#ecf0f1; border-radius:4px; height:8px;",
              tags$div(style = paste0("background:", color, "; width:", pct, "%; height:100%; border-radius:4px;"))
            )
          )
        })
      )
    })

    # === Fənn qrafiki ===
    output$tutor_subject_chart <- renderPlotly({
      grades <- student_grades()
      if (is.null(grades) || nrow(grades) == 0) {
        return(plot_ly() %>% layout(
          annotations = list(list(text = "Şagird seçin", showarrow = FALSE,
            font = list(size = 13, color = "#aaa"), x = 0.5, y = 0.5, xref = "paper", yref = "paper")),
          xaxis = list(visible = FALSE), yaxis = list(visible = FALSE)
        ))
      }

      colors <- ifelse(grades$avg_score >= 86, "#27ae60",
                ifelse(grades$avg_score >= 71, "#3498db",
                ifelse(grades$avg_score >= 51, "#f39c12", "#e74c3c")))

      plot_ly(grades, x = ~subject_name, y = ~avg_score, type = "bar",
              marker = list(color = colors)) %>%
        layout(xaxis = list(title = "", tickangle = -45),
               yaxis = list(title = "Orta Bal", range = c(0, 100)),
               margin = list(b = 80))
    })

    # === Tövsiyələr ===
    output$tutor_recommendations <- renderUI({
      grades <- student_grades()
      if (is.null(grades) || nrow(grades) == 0) return(NULL)

      weak_subjects <- grades[grades$avg_score < 60, ]
      if (nrow(weak_subjects) == 0) {
        return(tags$div(
          style = "color:#27ae60; padding:8px;",
          icon("check-circle"), " Bütün fənlərdə yaxşı nəticələr!"
        ))
      }

      tags$div(
        tags$h5(icon("exclamation-circle"), " Diqqət Tələb Edən Fənlər:"),
        lapply(seq_len(nrow(weak_subjects)), function(i) {
          tags$div(style = "padding:4px 0; font-size:0.9em;",
            tags$span(style = "color:#e74c3c;", icon("arrow-down")),
            tags$strong(weak_subjects$subject_name[i]),
            paste0(" — ", weak_subjects$avg_score[i], "%")
          )
        })
      )
    })

    # === Sürətli başlatma linklər ===
    observeEvent(input$quick_explain, {
      subj <- if (!is_empty(input$tutor_subject)) input$tutor_subject else "seçilmiş fənn"
      updateTextAreaInput(session, "tutor_input", value = paste0(subj, " fənnindəki son mövzunu izah et"))
    })
    observeEvent(input$quick_homework, {
      updateTextAreaInput(session, "tutor_input", value = "Ev tapşırığımda çətinlik çəkirəm, kömək edə bilərsən?")
    })
    observeEvent(input$quick_exam, {
      updateTextAreaInput(session, "tutor_input", value = "İmtahana hazırlaşmam üçün plan təklif et")
    })
    observeEvent(input$quick_weak, {
      updateTextAreaInput(session, "tutor_input", value = "Zəif tərəflərimi analiz et və nə etməliyəm de")
    })
    observeEvent(input$quick_plan, {
      updateTextAreaInput(session, "tutor_input", value = "1 həftəlik öyrənmə planı hazırla")
    })

    # === Sual Ver düyməsi ===
    observeEvent(input$btn_tutor_quiz, {
      subj <- if (!is_empty(input$tutor_subject)) input$tutor_subject else ""
      msg <- if (nchar(subj) > 0) {
        paste0(subj, " fənnindən məni yoxla — 3 sual ver")
      } else {
        "Zəif fənnlərimdən 3 sual ver"
      }
      updateTextAreaInput(session, "tutor_input", value = msg)
      shinyjs::click("btn_tutor_send")
    })

    # === Məsləhət Al düyməsi ===
    observeEvent(input$btn_tutor_tip, {
      updateTextAreaInput(session, "tutor_input", value = "Nəticələrimə əsasən öyrənmə məsləhəti ver")
      shinyjs::click("btn_tutor_send")
    })

    # === Mesajları render et ===
    output$tutor_chat_messages <- renderUI({
      msgs <- chat_history()
      tags$div(
        lapply(msgs, function(msg) {
          is_user <- msg$role == "user"
          tags$div(
            style = paste0(
              "margin-bottom:10px; padding:10px 14px; border-radius:12px; max-width:85%; ",
              "font-size:0.92em; line-height:1.5; ",
              if (is_user) "background:#2ecc71; color:#fff; margin-left:auto; text-align:right; border-bottom-right-radius:4px;"
              else "background:#ecf0f1; color:#2c3e50; border-bottom-left-radius:4px;"
            ),
            HTML(msg$content),
            if (!is.null(msg$timestamp))
              tags$div(style = paste0("font-size:0.75em; margin-top:4px; ",
                if (is_user) "color:rgba(255,255,255,0.7);" else "color:#999;"),
                msg$timestamp)
          )
        }),
        tags$script(sprintf("document.getElementById('%s').scrollTop = document.getElementById('%s').scrollHeight;",
                            ns("tutor_chat_area"), ns("tutor_chat_area")))
      )
    })

    # === Mesaj göndər ===
    observeEvent(input$btn_tutor_send, {
      req(input$tutor_input)
      user_msg <- trimws(input$tutor_input)
      if (nchar(user_msg) == 0) return()

      updateTextAreaInput(session, "tutor_input", value = "")

      # İstifadəçi mesajı
      history <- chat_history()
      history <- append(history, list(list(
        role = "user", content = htmltools::htmlEscape(user_msg),
        timestamp = format(Sys.time(), "%H:%M")
      )))
      history <- append(history, list(list(
        role = "assistant",
        content = "<em><i class='fa fa-spinner fa-spin'></i> Düşünürəm...</em>",
        timestamp = format(Sys.time(), "%H:%M")
      )))
      chat_history(history)

      # Şagird konteksti hazırla
      student <- student_data()
      grades <- student_grades()

      student_context <- ""
      if (!is.null(student)) {
        student_context <- paste0(
          "Şagird: ", student$full_name, ", ",
          student$class_grade, student$class_section, " sinif.\n"
        )
        if (!is.null(grades) && nrow(grades) > 0) {
          student_context <- paste0(student_context, "Fənn balları:\n",
            paste(sprintf("- %s: %s%% (min:%s, max:%s, n=%s)",
              grades$subject_name, grades$avg_score, grades$min_score,
              grades$max_score, grades$grade_count), collapse = "\n"), "\n",
            "Ümumi orta: ", round(mean(grades$avg_score, na.rm = TRUE), 1), "%\n",
            "Ən güclü fənn: ", grades$subject_name[which.max(grades$avg_score)], "\n",
            "Ən zəif fənn: ", grades$subject_name[which.min(grades$avg_score)], "\n"
          )
        }
      }

      # Seçilmiş fənn
      subject_focus <- if (!is_empty(input$tutor_subject))
        paste0("Fokus fənn: ", input$tutor_subject, "\n") else ""

      # Rejim
      mode_instruction <- switch(input$tutor_mode,
        "explain" = "Mövzuları sadə dildə, addım-addım izah et. Nümunələr ver.",
        "quiz" = "Sual-cavab rejimində ol. Suallar ver, cavabları yoxla, izah et.",
        "motivate" = "Motivasiya edici tərzdə yaz. Müvəffəqiyyətlərini vurğula, həvəsləndir.",
        "Həm izah et, həm sual ver, həm motivasiya et."
      )

      # Son söhbət konteksti
      recent <- tail(chat_history(), 8)
      conv_ctx <- paste(sapply(recent, function(m) {
        paste0(if (m$role == "user") "Şagird" else "Repetitor", ": ", gsub("<[^>]+>", "", m$content))
      }), collapse = "\n")

      system_prompt <- paste0(
        "Sən ARTI-2026 sisteminin AI repetitorusan. ",
        "Azərbaycan dilində, şagirdə uyğun səviyyədə cavab ver. ",
        mode_instruction, " ",
        "Şagirdin səviyyəsinə və qiymətlərinə uyğun danış. ",
        "Zəif fənlərdə daha çox kömək et. ",
        "Qısa və aydın yaz, markdown formatında. ",
        "Suallar verəndə düzgün cavabı sonra açıqla."
      )

      prompt <- paste0(
        student_context, subject_focus,
        "\nSöhbət tarixçəsi:\n", conv_ctx, "\n\n",
        "Şagird sualı: ", user_msg
      )

      # API çağırışı
      result <- tryCatch(
        route_ai_request(
          prompt = prompt,
          task_type = "chat",
          system_prompt = system_prompt,
          temperature = 0.7,
          max_tokens = 2048,
          save_to_db = TRUE,
          db_pool = db_pool,
          user_id = user_data()$id
        ),
        error = function(e) list(success = FALSE, message = e$message, content = e$message)
      )

      # "Düşünürəm..." sil
      history <- chat_history()
      history <- history[-length(history)]

      if (isTRUE(result$success)) {
        response_text <- result$content %||% result$message
        clean_html <- simple_md_to_html(response_text)

        history <- append(history, list(list(
          role = "assistant", content = clean_html,
          timestamp = format(Sys.time(), "%H:%M")
        )))
      } else {
        history <- append(history, list(list(
          role = "assistant",
          content = paste0("<span style='color:#e74c3c;'>Xəta: ",
                           htmltools::htmlEscape(result$message %||% "Naməlum"), "</span>"),
          timestamp = format(Sys.time(), "%H:%M")
        )))
      }

      chat_history(history)
    })

    # === Təmizlə ===
    observeEvent(input$btn_tutor_clear, {
      s <- student_data()
      name <- if (!is.null(s)) s$full_name else "dost"
      chat_history(list(
        list(role = "assistant",
             content = paste0("Söhbət təmizləndi. ", name, ", yeni sual verə bilərsən!"),
             timestamp = format(Sys.time(), "%H:%M"))
      ))
    })

    # === Export ===
    output$btn_tutor_export <- downloadHandler(
      filename = function() {
        s <- student_data()
        name <- if (!is.null(s)) gsub(" ", "_", s$full_name) else "sohbet"
        paste0("ai_tutor_", name, "_", format(Sys.Date(), "%Y%m%d"), ".txt")
      },
      content = function(file) {
        msgs <- chat_history()
        s <- student_data()
        lines <- c("ARTI-2026 AI Repetitor Söhbəti",
                    if (!is.null(s)) paste0("Şagird: ", s$full_name) else "",
                    paste0("Tarix: ", format(Sys.Date(), "%d.%m.%Y")),
                    paste(rep("=", 50), collapse = ""), "")
        for (msg in msgs) {
          role <- if (msg$role == "user") "ŞAGİRD" else "AI"
          text <- gsub("<[^>]+>", "", msg$content)
          lines <- c(lines, paste0("[", msg$timestamp %||% "", "] ", role, ": ", text), "")
        }
        writeLines(lines, file)
      }
    )

    # === Tarixçə ===
    output$tutor_history_table <- renderDT({
      data <- tryCatch(
        db_query(db_pool,
          "SELECT provider, LEFT(prompt_text, 80) as question, response_time_ms,
                  created_at
           FROM ai_responses
           WHERE task_type = 'chat' AND user_id = $1
           ORDER BY created_at DESC LIMIT 30",
          params = list(user_data()$id)),
        error = function(e) data.frame()
      )
      if (nrow(data) == 0) return(datatable(data.frame("Tarixçə boşdur" = character(0))))
      data$created_at <- format_date_az(data$created_at)
      data$response_time_ms <- paste0(round(data$response_time_ms / 1000, 1), "s")
      names(data) <- c("Provayder", "Sual", "Vaxt", "Tarix")
      datatable(data, selection = "none", options = list(pageLength = 5, dom = "tp"))
    })
  })
}
