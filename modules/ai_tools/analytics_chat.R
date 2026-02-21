# =============================================
# ARTI-2026: Analitik Chatbox — UI + Server
# Gün 11: UI + Gün 12: Server (DB data + Claude)
# =============================================

# =============================================
# UI (Gün 11)
# =============================================
analytics_chat_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(
      column(12,
        h2(icon("comments"), "AI Analitik Söhbət"),
        tags$p(class = "text-muted",
          "Məktəb performansı, davamiyyət, fənn nəticələri haqqında AI ilə söhbət edin"),
        hr()
      )
    ),

    fluidRow(
      # Sol panel — Söhbət
      column(8,
        box(
          title = tagList(icon("robot"), " AI Analitik Köməkçi"),
          status = "primary", solidHeader = TRUE, width = 12,

          # Filtrlər
          fluidRow(
            column(4, selectInput(ns("ac_school"), "Məktəb:", choices = c("Bütün Məktəblər" = ""))),
            column(4, dateRangeInput(ns("ac_dates"), "Tarix:", start = Sys.Date() - 90, end = Sys.Date())),
            column(4, selectInput(ns("ac_focus"), "Fokus Sahəsi:",
                                  choices = c("Ümumi" = "general", "Fənn Nəticələri" = "scores",
                                              "Davamiyyət" = "attendance", "Müəllim Perf." = "teachers",
                                              "Trend Analiz" = "trends", "Risk Şagirdlər" = "risk")))
          ),

          # Söhbət konteyner
          tags$div(
            id = ns("chat_area"),
            style = "height:500px; overflow-y:auto; border:1px solid #ddd; border-radius:8px; padding:12px; margin-bottom:12px; background:#fafafa;",
            uiOutput(ns("ac_chat_messages"))
          ),

          # Giriş sahəsi
          tags$div(
            style = "display:flex; gap:8px; align-items:flex-end;",
            tags$div(style = "flex:1;",
              textAreaInput(ns("ac_chat_input"), label = NULL, rows = 2,
                            placeholder = "Sualınızı yazın... (Enter+Shift ilə yeni sətir, düymə ilə göndər)",
                            width = "100%")
            ),
            tags$div(style = "flex-shrink:0;",
              actionButton(ns("btn_ac_send"), "", icon = icon("paper-plane"),
                           class = "btn-info btn-lg", style = "height:60px; width:60px;")
            )
          ),

          # Nümunə suallar
          tags$div(
            style = "margin-top:10px; padding:10px; background:#f0f4f8; border-radius:6px;",
            tags$small(style = "color:#666; font-weight:bold;", icon("lightbulb"), " Nümunə suallar:"),
            tags$div(style = "display:flex; flex-wrap:wrap; gap:6px; margin-top:6px;",
              actionLink(ns("sq1"), "Riyaziyyat nəticələri aşağı olan məktəblər?",
                         class = "label label-default", style = "font-size:0.85em;"),
              actionLink(ns("sq2"), "Son 3 ayda irəliləyiş göstərən məktəb?",
                         class = "label label-default", style = "font-size:0.85em;"),
              actionLink(ns("sq3"), "Davamiyyət problemi olan şagirdlər",
                         class = "label label-default", style = "font-size:0.85em;"),
              actionLink(ns("sq4"), "Bu rübün nəticələrini xülasə et",
                         class = "label label-default", style = "font-size:0.85em;"),
              actionLink(ns("sq5"), "Hansı fənlərdə ən çox uğursuzluq var?",
                         class = "label label-default", style = "font-size:0.85em;"),
              actionLink(ns("sq6"), "Müəllim performans müqayisəsi",
                         class = "label label-default", style = "font-size:0.85em;")
            )
          ),

          # Alt əməliyyat düymələri
          tags$div(
            style = "margin-top:10px; display:flex; gap:6px;",
            actionButton(ns("btn_ac_clear"), "Söhbəti Təmizlə", icon = icon("eraser"),
                         class = "btn-default btn-sm"),
            downloadButton(ns("btn_ac_export"), "Söhbəti Yüklə", class = "btn-info btn-sm"),
            actionButton(ns("btn_ac_save_session"), "Sessiyanı Saxla", icon = icon("save"),
                         class = "btn-success btn-sm")
          )
        )
      ),

      # Sağ panel — Vizualizasiya + Statistika
      column(4,
        # AI yaratdığı qrafik
        box(
          title = tagList(icon("chart-bar"), " AI Vizualizasiya"),
          status = "success", solidHeader = TRUE, width = 12,
          plotlyOutput(ns("ac_ai_chart"), height = "300px")
        ),

        # Sürətli statistika
        box(
          title = tagList(icon("tachometer-alt"), " Sürətli Statistika"),
          status = "info", solidHeader = TRUE, width = 12, collapsible = TRUE,
          valueBoxOutput(ns("ac_stat_students"), width = 12),
          valueBoxOutput(ns("ac_stat_teachers"), width = 12),
          valueBoxOutput(ns("ac_stat_avg"), width = 12),
          valueBoxOutput(ns("ac_stat_attendance"), width = 12)
        ),

        # Söhbət tarixçəsi
        box(
          title = tagList(icon("history"), " Keçmiş Sessiyalar"),
          status = "warning", solidHeader = TRUE, width = 12, collapsible = TRUE, collapsed = TRUE,
          DTOutput(ns("ac_sessions_table"))
        )
      )
    )
  )
}

# =============================================
# SERVER (Gün 12)
# =============================================
analytics_chat_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # === Reactive ===
    chat_history <- reactiveVal(list(
      list(role = "assistant", content = "Salam! Mən AI Analitik Köməkçiyəm. Məktəb performansı, davamiyyət, fənn nəticələri və müəllim statistikası haqqında sual verə bilərsiniz. Hansı məlumatı analiz etmək istəyirsiniz?",
           timestamp = format(Sys.time(), "%H:%M"))
    ))
    ai_chart_data <- reactiveVal(NULL)

    # Məktəb siyahısını yüklə
    observe({
      schools <- tryCatch(
        db_query(db_pool, "SELECT id, name FROM schools WHERE status = 'active' ORDER BY name"),
        error = function(e) data.frame()
      )
      if (nrow(schools) > 0) {
        updateSelectInput(session, "ac_school",
          choices = c("Bütün Məktəblər" = "", setNames(schools$id, schools$name)))
      }
    })

    # === Nümunə suallar ===
    observeEvent(input$sq1, { updateTextAreaInput(session, "ac_chat_input", value = "Hansı məktəblərdə riyaziyyat nəticələri aşağıdır?") })
    observeEvent(input$sq2, { updateTextAreaInput(session, "ac_chat_input", value = "Son 3 ayda ən çox irəliləyiş göstərən məktəb hansıdır?") })
    observeEvent(input$sq3, { updateTextAreaInput(session, "ac_chat_input", value = "Davamiyyət problemi olan şagirdləri göstər") })
    observeEvent(input$sq4, { updateTextAreaInput(session, "ac_chat_input", value = "Bu rübün nəticələrini xülasə et") })
    observeEvent(input$sq5, { updateTextAreaInput(session, "ac_chat_input", value = "Hansı fənlərdə ən çox uğursuzluq var?") })
    observeEvent(input$sq6, { updateTextAreaInput(session, "ac_chat_input", value = "Müəllim performansını müqayisə et") })

    # === Mesajları render et ===
    output$ac_chat_messages <- renderUI({
      msgs <- chat_history()
      tags$div(
        lapply(msgs, function(msg) {
          is_user <- msg$role == "user"
          tags$div(
            style = paste0(
              "margin-bottom:10px; padding:10px 14px; border-radius:12px; max-width:85%; ",
              "font-size:0.92em; line-height:1.5; position:relative; ",
              if (is_user) "background:#3498db; color:#fff; margin-left:auto; text-align:right; border-bottom-right-radius:4px;"
              else "background:#ecf0f1; color:#2c3e50; border-bottom-left-radius:4px;"
            ),
            HTML(msg$content),
            if (!is.null(msg$timestamp))
              tags$div(style = paste0("font-size:0.75em; margin-top:4px; ",
                if (is_user) "color:rgba(255,255,255,0.7);" else "color:#999;"),
                msg$timestamp)
          )
        }),
        # Avtomatik aşağı sürüşmə
        tags$script(sprintf("document.getElementById('%s').scrollTop = document.getElementById('%s').scrollHeight;",
                            ns("chat_area"), ns("chat_area")))
      )
    })

    # === Mesaj göndər ===
    observeEvent(input$btn_ac_send, {
      req(input$ac_chat_input)
      user_msg <- trimws(input$ac_chat_input)
      if (nchar(user_msg) == 0) return()

      updateTextAreaInput(session, "ac_chat_input", value = "")

      # İstifadəçi mesajı
      history <- chat_history()
      history <- append(history, list(list(
        role = "user", content = htmltools::htmlEscape(user_msg),
        timestamp = format(Sys.time(), "%H:%M")
      )))

      # "Analiz edilir..." mesajı
      history <- append(history, list(list(
        role = "assistant",
        content = "<em><i class='fa fa-spinner fa-spin'></i> Analiz edilir...</em>",
        timestamp = format(Sys.time(), "%H:%M")
      )))
      chat_history(history)

      # DB-dən kontekst datası çək
      context_data <- gather_analytics_context(db_pool, user_msg, input$ac_school, input$ac_dates)

      # Fokus sahəsinə əsasən əlavə kontekst
      focus_context <- switch(input$ac_focus,
        "scores" = "\nFokus: Fənn nəticələri və orta ballar.",
        "attendance" = "\nFokus: Davamiyyət statistikası.",
        "teachers" = "\nFokus: Müəllim performansı.",
        "trends" = "\nFokus: Zaman trendi və irəliləyiş.",
        "risk" = "\nFokus: Risk altında olan şagirdlər.",
        ""
      )

      # Söhbət tarixçəsi konteksti (son 5 mesaj)
      recent_msgs <- tail(chat_history(), 10)
      conversation_ctx <- paste(sapply(recent_msgs, function(m) {
        paste0(if (m$role == "user") "İstifadəçi" else "Köməkçi", ": ", gsub("<[^>]+>", "", m$content))
      }), collapse = "\n")

      system_prompt <- paste0(
        "Sən ARTI-2026 Təhsil İdarəetmə Sisteminin AI analitik köməkçisisən. ",
        "Azərbaycan məktəblərinin performans, davamiyyət, qiymət və müəllim məlumatlarını analiz edirsən. ",
        "Azərbaycan dilində, qısa və dəqiq cavab ver. ",
        "Cavabda əsas rəqəmləri **qalın** ilə vurğula. ",
        "Siyahı istifadə et, qısa cümlələrlə yaz. ",
        "Əgər vizual qrafik lazımdırsa, cavabın sonuna JSON blokunda göstər: ",
        "{\"chart\": {\"type\": \"bar|line|pie\", \"title\": \"...\", \"data\": [{\"x\": \"...\", \"y\": N}]}} ",
        "Bu JSON bloku yalnız vizualizasiya lazım olanda əlavə olunmalıdır.",
        focus_context
      )

      prompt <- paste0(
        "Söhbət tarixçəsi:\n", conversation_ctx, "\n\n",
        "İstifadəçi sualı: ", user_msg, "\n\n",
        "Mövcud data konteksti:\n", context_data
      )

      # API çağırışı
      result <- tryCatch(
        route_ai_request(
          prompt = prompt,
          task_type = "chat",
          system_prompt = system_prompt,
          temperature = 0.5,
          max_tokens = 2048,
          save_to_db = TRUE,
          db_pool = db_pool,
          user_id = user_data()$id
        ),
        error = function(e) list(success = FALSE, message = e$message, content = e$message)
      )

      # "Analiz edilir..." sil
      history <- chat_history()
      history <- history[-length(history)]

      if (isTRUE(result$success)) {
        response_text <- result$content %||% result$message

        # Qrafik JSON-u ayır
        chart_json <- extract_chart_json(response_text)
        clean_text <- remove_chart_json(response_text)
        clean_html <- simple_md_to_html(clean_text)

        if (!is.null(chart_json)) {
          ai_chart_data(chart_json)
          clean_html <- paste0(clean_html,
            "<br><small style='color:#3498db;'><i class='fa fa-chart-bar'></i> Qrafik sağda göstərilir</small>")
        }

        history <- append(history, list(list(
          role = "assistant", content = clean_html,
          timestamp = format(Sys.time(), "%H:%M")
        )))
      } else {
        history <- append(history, list(list(
          role = "assistant",
          content = paste0("<span style='color:#e74c3c;'><i class='fa fa-exclamation-triangle'></i> Xəta: ",
                           htmltools::htmlEscape(result$message %||% "Naməlum xəta"), "</span>"),
          timestamp = format(Sys.time(), "%H:%M")
        )))
      }

      chat_history(history)
    })

    # === AI Qrafik ===
    output$ac_ai_chart <- renderPlotly({
      chart <- ai_chart_data()
      if (is.null(chart)) {
        plot_ly() %>%
          layout(
            annotations = list(list(
              text = "AI-dən sual soruşun — qrafik burada göstəriləcək",
              showarrow = FALSE, font = list(size = 13, color = "#aaa"),
              x = 0.5, y = 0.5, xref = "paper", yref = "paper"
            )),
            xaxis = list(visible = FALSE), yaxis = list(visible = FALSE)
          )
      } else {
        df <- tryCatch(
          as.data.frame(do.call(rbind, lapply(chart$data, as.data.frame, stringsAsFactors = FALSE)),
                        stringsAsFactors = FALSE),
          error = function(e) data.frame(x = "Xəta", y = 0)
        )
        df$y <- as.numeric(df$y)
        chart_type <- chart$type %||% "bar"
        chart_colors <- c("#3498db", "#2ecc71", "#f39c12", "#e74c3c", "#9b59b6", "#1abc9c",
                          "#e67e22", "#34495e", "#16a085", "#c0392b")

        if (chart_type == "pie") {
          plot_ly(df, labels = ~x, values = ~y, type = "pie",
                  marker = list(colors = chart_colors[seq_len(nrow(df))])) %>%
            layout(title = list(text = chart$title %||% "", font = list(size = 13)))
        } else if (chart_type == "line") {
          plot_ly(df, x = ~x, y = ~y, type = "scatter", mode = "lines+markers",
                  line = list(color = "#3498db", width = 3),
                  marker = list(size = 8)) %>%
            layout(title = list(text = chart$title %||% "", font = list(size = 13)),
                   xaxis = list(title = ""), yaxis = list(title = ""))
        } else {
          plot_ly(df, x = ~x, y = ~y, type = "bar",
                  marker = list(color = chart_colors[seq_len(nrow(df))])) %>%
            layout(title = list(text = chart$title %||% "", font = list(size = 13)),
                   xaxis = list(title = "", tickangle = -45), yaxis = list(title = ""))
        }
      }
    })

    # === Sürətli Statistikalar ===
    output$ac_stat_students <- renderValueBox({
      count <- tryCatch(get_total_count(db_pool, "students", "status = 'active'"), error = function(e) 0)
      if (is.null(count) || is.na(count)) count <- 0
      valueBox(format(count, big.mark = ","), "Aktiv Şagird", icon = icon("user-graduate"), color = "aqua")
    })

    output$ac_stat_teachers <- renderValueBox({
      count <- tryCatch(get_total_count(db_pool, "teachers", "status = 'active'"), error = function(e) 0)
      if (is.null(count) || is.na(count)) count <- 0
      valueBox(format(count, big.mark = ","), "Aktiv Müəllim", icon = icon("chalkboard-teacher"), color = "green")
    })

    output$ac_stat_avg <- renderValueBox({
      avg <- tryCatch(get_average_performance(db_pool), error = function(e) 0)
      if (is.null(avg) || is.na(avg) || is.nan(avg)) avg <- 0
      valueBox(paste0(round(avg, 1), "%"), "Orta Performans", icon = icon("chart-line"), color = "yellow")
    })

    output$ac_stat_attendance <- renderValueBox({
      att <- tryCatch({
        r <- db_get_one(db_pool,
          "SELECT ROUND(
            COUNT(CASE WHEN status = 'present' THEN 1 END) * 100.0 / NULLIF(COUNT(*), 0), 1
          ) as rate FROM attendance WHERE attendance_date >= CURRENT_DATE - INTERVAL '30 days'")
        val <- r$rate %||% 0
        if (is.null(val) || is.na(val)) 0 else val
      }, error = function(e) 0)
      valueBox(paste0(att, "%"), "Davamiyyət (30 gün)", icon = icon("calendar-check"), color = "red")
    })

    # === Söhbəti təmizlə ===
    observeEvent(input$btn_ac_clear, {
      chat_history(list(
        list(role = "assistant",
             content = "Söhbət təmizləndi. Yeni sual verə bilərsiniz.",
             timestamp = format(Sys.time(), "%H:%M"))
      ))
      ai_chart_data(NULL)
    })

    # === Söhbəti yüklə ===
    output$btn_ac_export <- downloadHandler(
      filename = function() paste0("analitik_sohbet_", format(Sys.Date(), "%Y%m%d"), ".txt"),
      content = function(file) {
        msgs <- chat_history()
        lines <- c("ARTI-2026 AI Analitik Söhbət",
                    paste0("Tarix: ", format(Sys.Date(), "%d.%m.%Y")),
                    paste(rep("=", 50), collapse = ""), "")
        for (msg in msgs) {
          role <- if (msg$role == "user") "SİZ" else "AI"
          text <- gsub("<[^>]+>", "", msg$content)
          time <- msg$timestamp %||% ""
          lines <- c(lines, paste0("[", time, "] ", role, ": ", text), "")
        }
        writeLines(lines, file)
      }
    )

    # === Sessiyanı saxla ===
    observeEvent(input$btn_ac_save_session, {
      msgs <- chat_history()
      if (length(msgs) <= 1) {
        notify_warning("Saxlanılacaq söhbət yoxdur.")
        return()
      }

      session_json <- jsonlite::toJSON(msgs, auto_unbox = TRUE)
      tryCatch({
        db_execute(db_pool,
          "INSERT INTO ai_responses (provider, model, task_type, prompt_text, response_text,
           status, user_id, created_at)
           VALUES ('system', '', 'analytics_chat_session', 'session', $1, 'success', $2, NOW())",
          params = list(as.character(session_json), user_data()$id))
        notify_success("Sessiya saxlanıldı!")
      }, error = function(e) notify_error(paste("Saxlama xətası:", e$message)))
    })

    # === Keçmiş sessiyalar ===
    output$ac_sessions_table <- renderDT({
      data <- tryCatch(
        db_query(db_pool,
          "SELECT id, created_at, LEFT(response_text, 100) as preview
           FROM ai_responses
           WHERE task_type = 'analytics_chat_session' AND user_id = $1
           ORDER BY created_at DESC LIMIT 20",
          params = list(user_data()$id)),
        error = function(e) data.frame()
      )
      if (nrow(data) == 0) return(datatable(data.frame("Sessiya yoxdur" = character(0))))
      data$created_at <- format_date_az(data$created_at)
      names(data) <- c("ID", "Tarix", "Önizləmə")
      datatable(data, selection = "single", options = list(pageLength = 5, dom = "tp"))
    })
  })
}
