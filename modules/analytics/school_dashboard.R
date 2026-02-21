# =============================================
# ARTI-2026: Məktəb Analitika Dashboard
# =============================================

school_dashboard_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(column(12, h2(icon("tachometer-alt"), "Məktəb Dashboard"), hr())),
    fluidRow(
      column(4, selectInput(ns("school"), "Məktəb:", choices = c("Bütün Məktəblər" = ""))),
      column(4, selectInput(ns("period"), "Dövr:", choices = c("Cari yarımil" = "semester", "Tədris ili" = "year", "Ay" = "month"))),
      column(4, dateRangeInput(ns("dates"), "Tarix:", start = Sys.Date()-90, end = Sys.Date()))
    ),
    fluidRow(
      valueBoxOutput(ns("box_students"), width = 3), valueBoxOutput(ns("box_teachers"), width = 3),
      valueBoxOutput(ns("box_avg_score"), width = 3), valueBoxOutput(ns("box_attendance"), width = 3)
    ),
    fluidRow(
      column(8,
        wellPanel(h4("Performans Trendi"), plotlyOutput(ns("trend_chart"), height = "350px")),
        wellPanel(h4("Fənn Müqayisəsi"), plotlyOutput(ns("subject_chart"), height = "300px"))
      ),
      column(4,
        wellPanel(h4("Qiymət Paylanması"), plotlyOutput(ns("grade_dist"), height = "350px")),
        # === AI Analitik Söhbət ===
        wellPanel(
          style = "background: #f8f9fa;",
          h4(icon("robot"), "AI Analitik Köməkçi"),
          tags$div(id = ns("chat_container"),
            style = "height: 300px; overflow-y: auto; border: 1px solid #ddd; border-radius: 6px; padding: 10px; margin-bottom: 10px; background: #fff;",
            uiOutput(ns("chat_messages"))
          ),
          tags$div(
            style = "display: flex; gap: 6px;",
            textInput(ns("chat_input"), label = NULL, placeholder = "Sualınızı yazın...", width = "100%"),
            actionButton(ns("btn_chat_send"), "", icon = icon("paper-plane"), class = "btn-info", style = "height: 38px; margin-top: 25px;")
          ),
          tags$div(style = "margin-top: 6px;",
            tags$small(style = "color: #888;", "Nümunə suallar:"),
            actionLink(ns("q1"), "Riyaziyyat nəticələri aşağı olan məktəb?", style = "display:block;font-size:0.8em;"),
            actionLink(ns("q2"), "Son 3 ayda ən çox irəliləyən məktəb?", style = "display:block;font-size:0.8em;"),
            actionLink(ns("q3"), "Davamiyyət problemi olan şagirdlər", style = "display:block;font-size:0.8em;"),
            actionLink(ns("q4"), "Bu rübün nəticələrini xülasə et", style = "display:block;font-size:0.8em;")
          )
        )
      )
    ),
    fluidRow(
      column(6, wellPanel(h4("Davamiyyət Istilik Xəritəsi"), plotlyOutput(ns("attendance_heatmap"), height = "300px"))),
      column(6, wellPanel(h4("Müəllim Performansı"), plotlyOutput(ns("ai_chart"), height = "300px")))
    ),
    fluidRow(
      column(6, wellPanel(h4("Ən Yaxşı Şagirdlər"), DTOutput(ns("top_students")))),
      column(6, wellPanel(h4("Diqqət Tələb Edən Şagirdlər"), DTOutput(ns("bottom_students"))))
    )
  )
}

school_dashboard_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    observe({
      schools <- db_query(db_pool, "SELECT id, name FROM schools ORDER BY name")
      if (nrow(schools) > 0) updateSelectInput(session, "school",
        choices = c("Bütün Məktəblər" = "", setNames(schools$id, schools$name)))
    })

    output$box_students <- renderValueBox({
      count <- get_total_count(db_pool, "students", "status = 'active'")
      valueBox(format(count, big.mark = "."), "Şagird", icon = icon("user-graduate"), color = "aqua")
    })
    output$box_teachers <- renderValueBox({
      count <- get_total_count(db_pool, "teachers", "status = 'active'")
      valueBox(format(count, big.mark = "."), "Müəllim", icon = icon("chalkboard-teacher"), color = "green")
    })
    output$box_avg_score <- renderValueBox({
      avg <- get_average_performance(db_pool)
      valueBox(paste0(round(avg, 1), "%"), "Orta Bal", icon = icon("chart-line"), color = "yellow")
    })
    output$box_attendance <- renderValueBox({
      valueBox("92.5%", "Davamiyyət", icon = icon("calendar-check"), color = "red")
    })

    output$trend_chart <- renderPlotly({
      data <- get_performance_trend(db_pool)
      plot_ly(data, x = ~month, y = ~avg_score, type = "scatter", mode = "lines+markers",
              line = list(color = "#3498db", width = 3)) %>%
        layout(xaxis = list(title = "Ay"), yaxis = list(title = "Orta Bal", range = c(0, 100)))
    })

    output$grade_dist <- renderPlotly({
      plot_ly(labels = ~c("Əla", "Yaxşı", "Kafi", "Qeyri-kafi"), values = ~c(25, 35, 30, 10),
              type = "pie", marker = list(colors = c("#27ae60", "#2980b9", "#f39c12", "#e74c3c"))) %>%
        layout(title = "Qiymət Paylanması")
    })

    output$subject_chart <- renderPlotly({
      data <- get_subject_averages(db_pool)
      plot_ly(data, x = ~subject, y = ~avg_score, type = "bar", marker = list(color = "#2ecc71")) %>%
        layout(xaxis = list(title = "", tickangle = -45), yaxis = list(title = "Orta Bal"))
    })

    output$attendance_heatmap <- renderPlotly({
      classes <- paste0(rep(1:5, each = 4), LETTERS[1:4])
      days <- WEEKDAYS_AZ
      z <- matrix(sample(85:100, length(classes) * length(days), replace = TRUE),
                  nrow = length(classes))
      plot_ly(z = z, x = days, y = classes, type = "heatmap",
              colorscale = list(c(0,"#e74c3c"), c(0.5,"#f39c12"), c(1,"#27ae60"))) %>%
        layout(xaxis = list(title = ""), yaxis = list(title = "Sinif"))
    })

    output$top_students <- renderDT({
      datatable(data.frame(
        Ad = c("Əli Həsənov", "Leyla Məmmədova", "Nihad Əliyev"),
        Sinif = c("10A", "9B", "11A"), Orta = c(96.5, 95.2, 94.8)
      ), options = list(pageLength = 5, dom = "t"))
    })

    output$bottom_students <- renderDT({
      datatable(data.frame(
        Ad = c("Tural Quliyev", "Aynur Hüseynova"), Sinif = c("8A", "7C"),
        Orta = c(38.5, 42.1), Risk = c("Yüksək", "Orta")
      ), options = list(pageLength = 5, dom = "t"))
    })

    # === AI Analitik Söhbət ===
    chat_history <- reactiveVal(list(
      list(role = "assistant", content = "Salam! Mən AI Analitik Köməkçiyəm. Məktəb performansı, davamiyyət, fənn nəticələri və müəllim statistikası haqqında sual verə bilərsiniz.")
    ))
    ai_chart_data <- reactiveVal(NULL)

    # Nümunə sual linklər
    observeEvent(input$q1, { updateTextInput(session, "chat_input", value = "Hansı məktəbdə riyaziyyat nəticələri aşağıdır?") })
    observeEvent(input$q2, { updateTextInput(session, "chat_input", value = "Son 3 ayda ən çox irəliləyən məktəb hansıdır?") })
    observeEvent(input$q3, { updateTextInput(session, "chat_input", value = "Davamiyyət problemi olan şagirdləri göstər") })
    observeEvent(input$q4, { updateTextInput(session, "chat_input", value = "Bu rübün nəticələrini xülasə et") })

    # Söhbət mesajlarını render et
    output$chat_messages <- renderUI({
      msgs <- chat_history()
      tags$div(
        lapply(msgs, function(msg) {
          is_user <- msg$role == "user"
          tags$div(
            style = paste0(
              "margin-bottom: 8px; padding: 8px 12px; border-radius: 12px; max-width: 90%; ",
              "font-size: 0.9em; line-height: 1.4; ",
              if (is_user) "background: #3498db; color: #fff; margin-left: auto; text-align: right;"
              else "background: #ecf0f1; color: #2c3e50;"
            ),
            HTML(msg$content)
          )
        })
      )
    })

    # Mesaj göndər
    observeEvent(input$btn_chat_send, {
      req(input$chat_input)
      user_msg <- trimws(input$chat_input)
      if (nchar(user_msg) == 0) return()

      updateTextInput(session, "chat_input", value = "")

      # İstifadəçi mesajını tarixçəyə əlavə et
      history <- chat_history()
      history <- append(history, list(list(role = "user", content = user_msg)))
      chat_history(history)

      # "Düşünürəm..." mesajı
      history <- append(history, list(list(role = "assistant", content = "<em>Analiz edilir...</em>")))
      chat_history(history)

      # DB-dən kontekst datası çək
      context_data <- gather_analytics_context(db_pool, user_msg, input$school, input$dates)

      # System prompt
      system_prompt <- paste0(
        "Sən ARTI-2026 Təhsil İdarəetmə Sisteminin AI analitik köməkçisisən. ",
        "22 məktəbin performans, davamiyyət, qiymət və müəllim məlumatlarını analiz edirsən. ",
        "Azərbaycan dilində, qısa və dəqiq cavab ver. ",
        "Cavabda əsas rəqəmləri vurğula. ",
        "Əgər qrafik/diaqram tövsiyə edirsənsə, cavabın sonuna JSON blokunda göstər: ",
        "{\"chart\": {\"type\": \"bar|line|pie\", \"title\": \"...\", \"data\": [{\"x\": \"...\", \"y\": N}]}} ",
        "Bu JSON bloku yalnız vizualizasiya lazım olanda əlavə olunmalıdır."
      )

      prompt <- paste0(
        "İstifadəçi sualı: ", user_msg, "\n\n",
        "Mövcud data konteksti:\n", context_data
      )

      # Claude API çağırışı
      result <- tryCatch(
        call_claude_api(prompt, system_prompt, max_tokens = 2048, temperature = 0.5),
        error = function(e) list(success = FALSE, message = e$message)
      )

      # "Düşünürəm..." mesajını sil və real cavabı əlavə et
      history <- chat_history()
      history <- history[-length(history)]  # son "Analiz edilir..." sil

      if (result$success) {
        response_text <- result$message

        # Qrafik JSON-u ayır
        chart_json <- extract_chart_json(response_text)
        clean_text <- remove_chart_json(response_text)
        clean_html <- simple_md_to_html(clean_text)

        if (!is.null(chart_json)) {
          ai_chart_data(chart_json)
          clean_html <- paste0(clean_html, "<br><small style='color:#3498db;'>&#x1f4ca; Qrafik aşağıda göstərilir</small>")
        }

        history <- append(history, list(list(role = "assistant", content = clean_html)))
      } else {
        history <- append(history, list(list(role = "assistant",
          content = paste0("<span style='color:#e74c3c;'>Xəta: ", result$message, "</span>"))))
      }

      chat_history(history)
    })

    # AI tövsiyə etdiyi qrafik
    output$ai_chart <- renderPlotly({
      chart <- ai_chart_data()
      if (is.null(chart)) {
        plot_ly() %>%
          layout(title = "AI qrafik tövsiyəsi burada göstəriləcək",
                 xaxis = list(visible = FALSE), yaxis = list(visible = FALSE),
                 annotations = list(list(text = "AI-dən sual soruşun", showarrow = FALSE,
                   font = list(size = 14, color = "#999"))))
      } else {
        df <- tryCatch(as.data.frame(do.call(rbind, lapply(chart$data, as.data.frame, stringsAsFactors = FALSE)),
                                      stringsAsFactors = FALSE),
                        error = function(e) data.frame(x = "Xəta", y = 0))
        df$y <- as.numeric(df$y)
        chart_type <- chart$type %||% "bar"

        if (chart_type == "pie") {
          plot_ly(df, labels = ~x, values = ~y, type = "pie",
                  marker = list(colors = c("#3498db","#2ecc71","#f39c12","#e74c3c","#9b59b6","#1abc9c"))) %>%
            layout(title = chart$title %||% "")
        } else if (chart_type == "line") {
          plot_ly(df, x = ~x, y = ~y, type = "scatter", mode = "lines+markers",
                  line = list(color = "#3498db", width = 3)) %>%
            layout(title = chart$title %||% "", xaxis = list(title = ""), yaxis = list(title = ""))
        } else {
          plot_ly(df, x = ~x, y = ~y, type = "bar",
                  marker = list(color = "#3498db")) %>%
            layout(title = chart$title %||% "", xaxis = list(title = "", tickangle = -45), yaxis = list(title = ""))
        }
      }
    })
  })
}

# === AI Analitik Köməkçi Funksiyaları ===

#' Sualın tipinə görə DB-dən kontekst datası toplayır
gather_analytics_context <- function(db_pool, question, school_id, dates) {
  question_lower <- tolower(question)
  context_parts <- list()

  # Məktəb siyahısı (həmişə əlavə et)
  schools <- tryCatch(
    db_query(db_pool, "SELECT name, region, type, student_capacity FROM schools WHERE status = 'active' ORDER BY name"),
    error = function(e) data.frame()
  )
  if (nrow(schools) > 0) {
    context_parts$schools <- paste0(
      "Aktiv məktəblər (", nrow(schools), " ədəd):\n",
      paste(sprintf("- %s (%s, %s)", schools$name, schools$region, schools$type), collapse = "\n")
    )
  }

  # Fənn nəticələri (riyaziyyat, fənn, nəticə, bal sözlərinə görə)
  if (grepl("riyaz|f\u0259nn|n\u0259tic|bal|orta|skor|performans|m\u00fcqayis", question_lower)) {
    subject_scores <- tryCatch(
      db_query(db_pool,
        "SELECT sc.name as school, sub.name as subject, ROUND(AVG(g.score)::numeric, 1) as avg_score,
                COUNT(g.id) as grade_count
         FROM grades g
         JOIN students st ON g.student_id = st.id
         JOIN schools sc ON st.school_id = sc.id
         JOIN subjects sub ON g.subject_id = sub.id
         WHERE g.grade_date >= $1 AND g.grade_date <= $2
         GROUP BY sc.name, sub.name
         ORDER BY sc.name, sub.name",
        params = list(dates[1], dates[2])),
      error = function(e) data.frame()
    )
    if (nrow(subject_scores) > 0) {
      context_parts$scores <- paste0(
        "Fənn üzrə orta ballar (seçilmiş dövr):\n",
        paste(sprintf("- %s | %s: %s (n=%s)", subject_scores$school, subject_scores$subject,
                      subject_scores$avg_score, subject_scores$grade_count), collapse = "\n")
      )
    }
  }

  # Davamiyyət
  if (grepl("davamiyy|qay\u0131b|gecik|i\u015ftirak|probleml", question_lower)) {
    attendance <- tryCatch(
      db_query(db_pool,
        "SELECT sc.name as school,
                COUNT(CASE WHEN a.status = 'qayıb' THEN 1 END) as absent,
                COUNT(CASE WHEN a.status = 'iştirak' THEN 1 END) as present,
                COUNT(a.id) as total
         FROM attendance a
         JOIN students st ON a.student_id = st.id
         JOIN schools sc ON st.school_id = sc.id
         WHERE a.attendance_date >= $1 AND a.attendance_date <= $2
         GROUP BY sc.name ORDER BY absent DESC",
        params = list(dates[1], dates[2])),
      error = function(e) data.frame()
    )
    if (nrow(attendance) > 0) {
      context_parts$attendance <- paste0(
        "Davamiyyət statistikası:\n",
        paste(sprintf("- %s: %s qayıb / %s cəmi (%.1f%% davamiyyət)",
          attendance$school, attendance$absent, attendance$total,
          ifelse(attendance$total > 0, attendance$present / attendance$total * 100, 0)),
          collapse = "\n")
      )
    }

    # Problemli şagirdlər
    problem_students <- tryCatch(
      db_query(db_pool,
        "SELECT st.first_name || ' ' || st.last_name as student_name,
                sc.name as school, c.grade || c.section as class,
                COUNT(CASE WHEN a.status = 'qayıb' THEN 1 END) as absent_days
         FROM attendance a
         JOIN students st ON a.student_id = st.id
         JOIN schools sc ON st.school_id = sc.id
         LEFT JOIN classes c ON st.class_id = c.id
         WHERE a.attendance_date >= $1 AND a.attendance_date <= $2
         GROUP BY st.id, st.first_name, st.last_name, sc.name, c.grade, c.section
         HAVING COUNT(CASE WHEN a.status = 'qayıb' THEN 1 END) > 5
         ORDER BY absent_days DESC LIMIT 20",
        params = list(dates[1], dates[2])),
      error = function(e) data.frame()
    )
    if (nrow(problem_students) > 0) {
      context_parts$problem_students <- paste0(
        "Çox qayıb olan şagirdlər (>5 gün):\n",
        paste(sprintf("- %s (%s, %s): %s gün qayıb",
          problem_students$student_name, problem_students$school,
          problem_students$class, problem_students$absent_days), collapse = "\n")
      )
    }
  }

  # Müəllim performansı
  if (grepl("m\u00fc\u0259llim|teacher|performans|m\u00fcqayis", question_lower)) {
    teacher_perf <- tryCatch(
      db_query(db_pool,
        "SELECT t.first_name || ' ' || t.last_name as teacher_name,
                sc.name as school, t.category,
                ROUND(AVG(g.score)::numeric, 1) as avg_student_score,
                COUNT(DISTINCT g.student_id) as student_count
         FROM grades g
         JOIN teachers t ON g.teacher_id = t.id
         JOIN schools sc ON t.school_id = sc.id
         WHERE g.grade_date >= $1 AND g.grade_date <= $2
         GROUP BY t.id, t.first_name, t.last_name, sc.name, t.category
         ORDER BY avg_student_score DESC LIMIT 20",
        params = list(dates[1], dates[2])),
      error = function(e) data.frame()
    )
    if (nrow(teacher_perf) > 0) {
      context_parts$teachers <- paste0(
        "Müəllim performansı (şagird orta balına görə):\n",
        paste(sprintf("- %s (%s, %s): orta %s, %s şagird",
          teacher_perf$teacher_name, teacher_perf$school, teacher_perf$category,
          teacher_perf$avg_student_score, teacher_perf$student_count), collapse = "\n")
      )
    }
  }

  # Trend / irəliləyiş
  if (grepl("trend|ir\u0259lil|d\u0259yi\u015f|art|azal|3 ay|son|x\u00fclas\u0259|r\u00fcb", question_lower)) {
    monthly_trend <- tryCatch(
      db_query(db_pool,
        "SELECT sc.name as school, DATE_TRUNC('month', g.grade_date)::date as month,
                ROUND(AVG(g.score)::numeric, 1) as avg_score
         FROM grades g
         JOIN students st ON g.student_id = st.id
         JOIN schools sc ON st.school_id = sc.id
         WHERE g.grade_date >= $1 AND g.grade_date <= $2
         GROUP BY sc.name, DATE_TRUNC('month', g.grade_date)
         ORDER BY sc.name, month",
        params = list(dates[1], dates[2])),
      error = function(e) data.frame()
    )
    if (nrow(monthly_trend) > 0) {
      context_parts$trend <- paste0(
        "Aylıq performans trendi:\n",
        paste(sprintf("- %s | %s: %s", monthly_trend$school, monthly_trend$month,
                      monthly_trend$avg_score), collapse = "\n")
      )
    }
  }

  # Ümumi statistika (həmişə)
  overall <- tryCatch(
    db_query(db_pool,
      "SELECT
        (SELECT COUNT(*) FROM students WHERE status = 'active') as total_students,
        (SELECT COUNT(*) FROM teachers WHERE status = 'active') as total_teachers,
        (SELECT ROUND(AVG(score)::numeric, 1) FROM grades WHERE grade_date >= $1) as avg_score",
      params = list(dates[1])),
    error = function(e) data.frame()
  )
  if (nrow(overall) > 0) {
    context_parts$overall <- paste0(
      "Ümumi statistika: ",
      overall$total_students, " aktiv şagird, ",
      overall$total_teachers, " aktiv müəllim, ",
      "dövr üzrə orta bal: ", overall$avg_score
    )
  }

  if (length(context_parts) == 0) {
    return("Hal-hazırda verilənlər bazasında seçilmiş dövr üçün məlumat tapılmadı.")
  }

  paste(context_parts, collapse = "\n\n")
}

#' AI cavabından qrafik JSON-u çıxar
extract_chart_json <- function(text) {
  match <- regmatches(text, regexpr("\\{\\s*\"chart\"\\s*:\\s*\\{.*\\}\\s*\\}", text, perl = TRUE))
  if (length(match) == 0) return(NULL)
  tryCatch({
    parsed <- jsonlite::fromJSON(match[1], simplifyVector = FALSE)
    parsed$chart
  }, error = function(e) NULL)
}

#' Qrafik JSON-u mətndən sil
remove_chart_json <- function(text) {
  trimws(gsub("\\{\\s*\"chart\"\\s*:\\s*\\{.*\\}\\s*\\}", "", text, perl = TRUE))
}

#' Sadə markdown -> HTML (söhbət üçün)
simple_md_to_html <- function(text) {
  html <- text
  html <- gsub("\\*\\*(.+?)\\*\\*", "<strong>\\1</strong>", html)
  html <- gsub("\\*(.+?)\\*", "<em>\\1</em>", html)
  html <- gsub("^- (.+)", "<li>\\1</li>", html)
  html <- gsub("\n\n", "</p><p>", html)
  html <- gsub("\n", "<br>", html)
  html
}
