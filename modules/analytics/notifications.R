# =============================================
# ARTI-2026: Avtomatik Bildiriş Sistemi
# Gün 18: Bildiriş idarəetmə, avtomatik alert, şablonlar
# =============================================

notifications_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(column(12, h2(icon("bell"), "Bildiriş Mərkəzi"),
      tags$p(class = "text-muted", "Avtomatik xəbərdarlıqlar, bildiriş idarəetmə və şablonlar"), hr())),

    # Statistika
    fluidRow(
      valueBoxOutput(ns("notif_total"), width = 3),
      valueBoxOutput(ns("notif_unread"), width = 3),
      valueBoxOutput(ns("notif_warnings"), width = 3),
      valueBoxOutput(ns("notif_today"), width = 3)
    ),

    fluidRow(
      # Sol - Bildiriş siyahısı (inbox style)
      column(8,
        box(title = tagList(icon("inbox"), " Bildirişlər"), status = "primary", solidHeader = TRUE, width = 12,
          fluidRow(
            column(3, selectInput(ns("notif_type_filter"), "Növ:", choices = c("Hamısı" = "", "Xəbərdarlıq" = "warning", "Məlumat" = "info", "Xəta" = "error", "Uğur" = "success"))),
            column(3, selectInput(ns("notif_read_filter"), "Status:", choices = c("Hamısı" = "", "Oxunmamış" = "unread", "Oxunmuş" = "read"))),
            column(3, dateRangeInput(ns("notif_dates"), "Tarix:", start = Sys.Date() - 30, end = Sys.Date())),
            column(3,
              actionButton(ns("btn_notif_refresh"), "Yenilə", icon = icon("sync"), class = "btn-default btn-sm", style = "margin-top:25px;"),
              actionButton(ns("btn_notif_read_all"), "Hamısını Oxu", icon = icon("check-double"), class = "btn-info btn-sm", style = "margin-top:25px;")
            )
          ),

          uiOutput(ns("notif_list")),

          tags$div(style = "margin-top:10px; display:flex; gap:6px;",
            actionButton(ns("btn_notif_delete_read"), "Oxunmuşları Sil", icon = icon("trash"), class = "btn-danger btn-sm"),
            downloadButton(ns("btn_notif_export"), "Excel Yüklə", class = "btn-success btn-sm")
          )
        ),

        # Bildiriş tarixçəsi cədvəli
        box(title = tagList(icon("history"), " Tarixçə Cədvəli"), status = "primary", solidHeader = TRUE, width = 12, collapsible = TRUE, collapsed = TRUE,
          DTOutput(ns("notif_history_table"))
        )
      ),

      # Sağ - Avtomatik alert və şablonlar
      column(4,
        # Avtomatik Alert Konfiqurasiyası
        box(title = tagList(icon("robot"), " Avtomatik Alertlər"), status = "danger", solidHeader = TRUE, width = 12,
          tags$p(class = "text-muted", "Sistem avtomatik olaraq risk şərtlərini yoxlayır"),

          checkboxInput(ns("auto_risk_alert"), "Risk xəbərdarlığı (risk > 65%)", value = TRUE),
          checkboxInput(ns("auto_attendance_alert"), "Davamiyyət xəbərdarlığı (< 80%)", value = TRUE),
          checkboxInput(ns("auto_grade_drop_alert"), "Qiymət düşüşü xəbərdarlığı (> -10 bal)", value = TRUE),
          checkboxInput(ns("auto_homework_alert"), "Ev tapşırığı xəbərdarlığı (< 50%)", value = FALSE),

          tags$hr(),
          actionButton(ns("btn_run_auto_check"), "İndi Yoxla", icon = icon("play"), class = "btn-warning btn-block"),
          tags$br(),
          textOutput(ns("last_auto_check"))
        ),

        # Yeni Bildiriş Göndər
        box(title = tagList(icon("paper-plane"), " Yeni Bildiriş"), status = "success", solidHeader = TRUE, width = 12, collapsible = TRUE,
          selectInput(ns("new_notif_target"), "Hədəf:", choices = c(
            "Bütün müəllimlər" = "all_teachers", "Bütün direktorlar" = "all_directors",
            "Fərdi istifadəçi" = "individual")),
          conditionalPanel(
            condition = sprintf("input['%s'] == 'individual'", ns("new_notif_target")),
            selectizeInput(ns("new_notif_user"), "İstifadəçi:", choices = NULL)
          ),
          selectInput(ns("new_notif_type"), "Növ:", choices = c("Məlumat" = "info", "Xəbərdarlıq" = "warning", "Uğur" = "success")),
          textInput(ns("new_notif_title"), "Başlıq:", placeholder = "Bildiriş başlığı"),
          textAreaInput(ns("new_notif_message"), "Mesaj:", rows = 4, placeholder = "Bildiriş mətni..."),
          actionButton(ns("btn_send_notif"), "Göndər", icon = icon("paper-plane"), class = "btn-primary btn-block")
        ),

        # Bildiriş Şablonları
        box(title = tagList(icon("file-alt"), " Şablonlar"), status = "info", solidHeader = TRUE, width = 12, collapsible = TRUE, collapsed = TRUE,
          tags$div(style = "display:flex; flex-direction:column; gap:6px;",
            actionLink(ns("tpl_risk"), tagList(icon("exclamation-triangle"), " Risk Xəbərdarlığı"), style = "display:block; padding:8px; background:#fadbd8; border-radius:6px;"),
            actionLink(ns("tpl_attendance"), tagList(icon("calendar-times"), " Davamiyyət Xəbərdarlığı"), style = "display:block; padding:8px; background:#fdebd0; border-radius:6px;"),
            actionLink(ns("tpl_grade_drop"), tagList(icon("chart-line"), " Qiymət Düşüşü"), style = "display:block; padding:8px; background:#d6eaf8; border-radius:6px;"),
            actionLink(ns("tpl_meeting"), tagList(icon("users"), " Görüş Bildirişi"), style = "display:block; padding:8px; background:#d5f5e3; border-radius:6px;"),
            actionLink(ns("tpl_general"), tagList(icon("info-circle"), " Ümumi Məlumat"), style = "display:block; padding:8px; background:#ebdef0; border-radius:6px;")
          )
        )
      )
    )
  )
}

notifications_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    notifications_data <- reactiveVal(data.frame())
    auto_check_time <- reactiveVal(NULL)

    # Load users for individual notification
    observe({
      users <- tryCatch(db_query(db_pool,
        "SELECT id, full_name || ' (' || role || ')' as label FROM users WHERE is_active = true ORDER BY full_name"),
        error = function(e) data.frame())
      if (nrow(users) > 0) {
        updateSelectizeInput(session, "new_notif_user", choices = setNames(users$id, users$label), server = TRUE)
      }
    })

    # ---- LOAD NOTIFICATIONS ----
    load_notifications <- function() {
      uid <- tryCatch(user_data()$id, error = function(e) NULL)
      req(uid)
      type_filter <- if (!is_empty(input$notif_type_filter)) {
        paste0("AND n.type = '", input$notif_type_filter, "'")
      } else {
        ""
      }
      read_filter <- if (input$notif_read_filter == "unread") {
        "AND n.is_read = FALSE"
      } else if (input$notif_read_filter == "read") {
        "AND n.is_read = TRUE"
      } else {
        ""
      }

      date_from <- input$notif_dates[1]
      date_to <- input$notif_dates[2]
      req(date_from, date_to)

      data <- tryCatch(db_query(db_pool, sprintf(
        "SELECT n.id, n.title, n.message, n.type, n.is_read, n.link, n.created_at
         FROM notifications n
         WHERE n.user_id = $1 AND n.created_at BETWEEN $2::timestamp AND $3::timestamp + INTERVAL '1 day'
         %s %s
         ORDER BY n.created_at DESC LIMIT 100",
        type_filter, read_filter),
        params = list(uid, as.character(date_from), as.character(date_to))),
        error = function(e) data.frame())

      notifications_data(data)
    }

    observe({ load_notifications() })
    observeEvent(input$btn_notif_refresh, { load_notifications() })

    # ---- STATISTICS ----
    output$notif_total <- renderValueBox({
      uid <- user_data()$id
      count <- tryCatch(
        db_get_one(db_pool,
          "SELECT COUNT(*) as n FROM notifications WHERE user_id = $1",
          params = list(uid))$n %||% 0,
        error = function(e) 0)
      valueBox(count, "Ümumi Bildiriş", icon = icon("bell"), color = "blue")
    })

    output$notif_unread <- renderValueBox({
      uid <- user_data()$id
      count <- tryCatch(
        db_get_one(db_pool,
          "SELECT COUNT(*) as n FROM notifications WHERE user_id = $1 AND is_read = FALSE",
          params = list(uid))$n %||% 0,
        error = function(e) 0)
      valueBox(count, "Oxunmamış", icon = icon("envelope"), color = "red")
    })

    output$notif_warnings <- renderValueBox({
      uid <- user_data()$id
      count <- tryCatch(
        db_get_one(db_pool,
          "SELECT COUNT(*) as n FROM notifications WHERE user_id = $1 AND type = 'warning' AND created_at >= CURRENT_DATE - INTERVAL '7 days'",
          params = list(uid))$n %||% 0,
        error = function(e) 0)
      valueBox(count, "Xəbərdarlıq (7 gün)", icon = icon("exclamation-triangle"), color = "yellow")
    })

    output$notif_today <- renderValueBox({
      uid <- user_data()$id
      count <- tryCatch(
        db_get_one(db_pool,
          "SELECT COUNT(*) as n FROM notifications WHERE user_id = $1 AND created_at >= CURRENT_DATE",
          params = list(uid))$n %||% 0,
        error = function(e) 0)
      valueBox(count, "Bugünkü", icon = icon("calendar-day"), color = "green")
    })

    # ---- NOTIFICATION LIST (inbox) ----
    output$notif_list <- renderUI({
      data <- notifications_data()
      if (nrow(data) == 0) {
        return(tags$p(style = "text-align:center; color:#999; padding:30px;", icon("inbox"), " Bildiriş yoxdur"))
      }

      type_icons <- c(warning = "exclamation-triangle", info = "info-circle", error = "times-circle", success = "check-circle")
      type_colors <- c(warning = "#f39c12", info = "#3498db", error = "#e74c3c", success = "#27ae60")

      tags$div(style = "max-height:500px; overflow-y:auto;",
        lapply(seq_len(min(nrow(data), 50)), function(i) {
          n <- data[i, ]
          icon_name <- type_icons[n$type] %||% "bell"
          color <- type_colors[n$type] %||% "#95a5a6"
          bg <- if (isTRUE(n$is_read)) "#fff" else "#f0f7ff"
          font_weight <- if (isTRUE(n$is_read)) "normal" else "bold"

          tags$div(
            style = sprintf("display:flex; gap:12px; padding:12px; border-bottom:1px solid #ecf0f1; background:%s; cursor:pointer;", bg),
            onclick = sprintf("Shiny.setInputValue('%s', '%s', {priority: 'event'})", ns("notif_click"), n$id),

            tags$div(
              style = sprintf("flex-shrink:0; width:40px; height:40px; border-radius:50%%; background:%s20; display:flex; align-items:center; justify-content:center;", color),
              icon(icon_name, style = sprintf("color:%s; font-size:18px;", color))
            ),

            tags$div(style = "flex:1; min-width:0;",
              tags$div(style = sprintf("font-weight:%s; color:#2c3e50; font-size:0.95em;", font_weight), n$title),
              tags$div(style = "color:#7f8c8d; font-size:0.85em; white-space:nowrap; overflow:hidden; text-overflow:ellipsis;",
                substr(n$message %||% "", 1, 120)),
              tags$div(style = "color:#bdc3c7; font-size:0.75em; margin-top:2px;", format_datetime_az(n$created_at))
            ),

            if (!isTRUE(n$is_read)) {
              tags$div(style = "flex-shrink:0; width:8px; height:8px; border-radius:50%; background:#3498db; margin-top:6px;")
            }
          )
        })
      )
    })

    # ---- MARK AS READ on click ----
    observeEvent(input$notif_click, {
      notif_id <- input$notif_click
      tryCatch(
        db_execute(db_pool, "UPDATE notifications SET is_read = TRUE WHERE id = $1", params = list(notif_id)),
        error = function(e) NULL
      )
      load_notifications()
    })

    # ---- MARK ALL AS READ ----
    observeEvent(input$btn_notif_read_all, {
      uid <- user_data()$id
      tryCatch({
        db_execute(db_pool,
          "UPDATE notifications SET is_read = TRUE WHERE user_id = $1 AND is_read = FALSE",
          params = list(uid))
        notify_success("Bütün bildirişlər oxunmuş kimi işarələndi.")
        load_notifications()
      }, error = function(e) notify_error(e$message))
    })

    # ---- DELETE READ ----
    observeEvent(input$btn_notif_delete_read, {
      uid <- user_data()$id
      tryCatch({
        result <- db_execute(db_pool,
          "DELETE FROM notifications WHERE user_id = $1 AND is_read = TRUE",
          params = list(uid))
        notify_success("Oxunmuş bildirişlər silindi.")
        load_notifications()
      }, error = function(e) notify_error(e$message))
    })

    # ---- SEND NEW NOTIFICATION ----
    observeEvent(input$btn_send_notif, {
      if (is_empty(input$new_notif_title)) {
        notify_warning("Başlıq daxil edin.")
        return()
      }
      if (is_empty(input$new_notif_message)) {
        notify_warning("Mesaj daxil edin.")
        return()
      }

      target <- input$new_notif_target
      type <- input$new_notif_type
      title <- input$new_notif_title
      message <- input$new_notif_message

      if (target == "individual") {
        if (is_empty(input$new_notif_user)) {
          notify_warning("İstifadəçi seçin.")
          return()
        }
        tryCatch({
          db_execute(db_pool,
            "INSERT INTO notifications (user_id, title, message, type, created_at) VALUES ($1, $2, $3, $4, NOW())",
            params = list(input$new_notif_user, title, message, type))
          notify_success("Bildiriş göndərildi!")
        }, error = function(e) notify_error(e$message))
      } else {
        role_filter <- if (target == "all_teachers") "role = 'teacher'" else "role = 'director'"
        users <- tryCatch(
          db_query(db_pool, sprintf("SELECT id FROM users WHERE %s AND is_active = true", role_filter)),
          error = function(e) data.frame()
        )

        if (nrow(users) == 0) {
          notify_warning("Hədəf istifadəçi tapılmadı.")
          return()
        }

        sent <- 0
        for (i in seq_len(nrow(users))) {
          tryCatch({
            db_execute(db_pool,
              "INSERT INTO notifications (user_id, title, message, type, created_at) VALUES ($1, $2, $3, $4, NOW())",
              params = list(users$id[i], title, message, type))
            sent <- sent + 1
          }, error = function(e) NULL)
        }
        notify_success(paste0(sent, " istifadəçiyə bildiriş göndərildi!"))
      }

      # Clear form
      updateTextInput(session, "new_notif_title", value = "")
      updateTextAreaInput(session, "new_notif_message", value = "")
    })

    # ---- TEMPLATES ----
    observeEvent(input$tpl_risk, {
      updateTextInput(session, "new_notif_title", value = "Risk Xəbərdarlığı")
      updateTextAreaInput(session, "new_notif_message", value = "Hörmətli müəllim, aşağıdakı şagirdlər yüksək risk qrupunda qeydə alınmışdır. Xahiş edirik əlavə dəstək tədbirləri görəsiniz.")
      updateSelectInput(session, "new_notif_type", selected = "warning")
    })

    observeEvent(input$tpl_attendance, {
      updateTextInput(session, "new_notif_title", value = "Davamiyyət Xəbərdarlığı")
      updateTextAreaInput(session, "new_notif_message", value = "Son 30 gün ərzində davamiyyəti 80%-dən aşağı olan şagirdlər aşkar edilmişdir. Valideynlərlə əlaqə saxlanılması tövsiyə olunur.")
      updateSelectInput(session, "new_notif_type", selected = "warning")
    })

    observeEvent(input$tpl_grade_drop, {
      updateTextInput(session, "new_notif_title", value = "Qiymət Düşüşü Bildirişi")
      updateTextAreaInput(session, "new_notif_message", value = "Bəzi şagirdlərin son 3 aydakı orta balı əvvəlki dövrlə müqayisədə 10 baldan çox aşağı düşmüşdür.")
      updateSelectInput(session, "new_notif_type", selected = "info")
    })

    observeEvent(input$tpl_meeting, {
      updateTextInput(session, "new_notif_title", value = "Görüş Bildirişi")
      updateTextAreaInput(session, "new_notif_message", value = "Hörmətli həmkarlar, pedaqoji şura iclası keçiriləcəkdir. Tarix və saat tezliklə bildiriləcək.")
      updateSelectInput(session, "new_notif_type", selected = "info")
    })

    observeEvent(input$tpl_general, {
      updateTextInput(session, "new_notif_title", value = "Ümumi Məlumat")
      updateTextAreaInput(session, "new_notif_message", value = "")
      updateSelectInput(session, "new_notif_type", selected = "info")
    })

    # ---- AUTO CHECK ----
    observeEvent(input$btn_run_auto_check, {
      withProgress(message = "Avtomatik yoxlama aparılır...", value = 0.1, {
        alerts_sent <- 0

        if (isTRUE(input$auto_risk_alert)) {
          setProgress(0.3, detail = "Risk yoxlanılır...")
          # Find students with high risk scores (low average)
          risk_students <- tryCatch(db_query(db_pool,
            "SELECT s.id, s.first_name, s.last_name, c.grade, c.section,
                    ROUND(AVG(g.score)::numeric, 1) as avg_score
             FROM students s
             LEFT JOIN classes c ON s.class_id = c.id
             LEFT JOIN grades g ON g.student_id = s.id AND g.grade_date >= CURRENT_DATE - INTERVAL '3 months'
             WHERE s.status = 'active'
             GROUP BY s.id, s.first_name, s.last_name, c.grade, c.section
             HAVING AVG(g.score) < 51"), error = function(e) data.frame())

          if (nrow(risk_students) > 0) {
            alerts_sent <- alerts_sent + send_auto_alerts(db_pool, risk_students, "risk", user_data()$id)
          }
        }

        if (isTRUE(input$auto_attendance_alert)) {
          setProgress(0.5, detail = "Davamiyyət yoxlanılır...")
          low_att <- tryCatch(db_query(db_pool,
            "SELECT s.id, s.first_name, s.last_name, c.grade, c.section,
                    ROUND(COUNT(CASE WHEN a.status = 'present' THEN 1 END)::numeric * 100 / NULLIF(COUNT(a.id), 0), 1) as att_pct
             FROM students s
             LEFT JOIN classes c ON s.class_id = c.id
             LEFT JOIN attendance a ON a.student_id = s.id AND a.attendance_date >= CURRENT_DATE - INTERVAL '30 days'
             WHERE s.status = 'active'
             GROUP BY s.id, s.first_name, s.last_name, c.grade, c.section
             HAVING COUNT(CASE WHEN a.status = 'present' THEN 1 END)::numeric * 100 / NULLIF(COUNT(a.id), 0) < 80"),
            error = function(e) data.frame())

          if (nrow(low_att) > 0) {
            alerts_sent <- alerts_sent + send_auto_alerts(db_pool, low_att, "attendance", user_data()$id)
          }
        }

        if (isTRUE(input$auto_grade_drop_alert)) {
          setProgress(0.7, detail = "Qiymət düşüşü yoxlanılır...")
          grade_drop <- tryCatch(db_query(db_pool,
            "SELECT s.id, s.first_name, s.last_name, c.grade, c.section,
                    AVG(CASE WHEN g.grade_date >= CURRENT_DATE - INTERVAL '3 months' THEN g.score END) -
                    AVG(CASE WHEN g.grade_date < CURRENT_DATE - INTERVAL '3 months' AND g.grade_date >= CURRENT_DATE - INTERVAL '6 months' THEN g.score END) as trend
             FROM students s
             LEFT JOIN classes c ON s.class_id = c.id
             LEFT JOIN grades g ON g.student_id = s.id AND g.grade_date >= CURRENT_DATE - INTERVAL '6 months'
             WHERE s.status = 'active'
             GROUP BY s.id, s.first_name, s.last_name, c.grade, c.section
             HAVING AVG(CASE WHEN g.grade_date >= CURRENT_DATE - INTERVAL '3 months' THEN g.score END) -
                    AVG(CASE WHEN g.grade_date < CURRENT_DATE - INTERVAL '3 months' AND g.grade_date >= CURRENT_DATE - INTERVAL '6 months' THEN g.score END) < -10"),
            error = function(e) data.frame())

          if (nrow(grade_drop) > 0) {
            alerts_sent <- alerts_sent + send_auto_alerts(db_pool, grade_drop, "grade_drop", user_data()$id)
          }
        }

        if (isTRUE(input$auto_homework_alert)) {
          setProgress(0.9, detail = "Ev tapşırığı yoxlanılır...")
          hw_low <- tryCatch(db_query(db_pool,
            "SELECT s.id, s.first_name, s.last_name, c.grade, c.section,
                    ROUND(AVG(CASE WHEN g.category = 'homework' THEN g.score END)::numeric, 1) as hw_avg
             FROM students s
             LEFT JOIN classes c ON s.class_id = c.id
             LEFT JOIN grades g ON g.student_id = s.id AND g.grade_date >= CURRENT_DATE - INTERVAL '2 months'
             WHERE s.status = 'active'
             GROUP BY s.id, s.first_name, s.last_name, c.grade, c.section
             HAVING AVG(CASE WHEN g.category = 'homework' THEN g.score END) < 50"),
            error = function(e) data.frame())

          if (nrow(hw_low) > 0) {
            alerts_sent <- alerts_sent + send_auto_alerts(db_pool, hw_low, "homework", user_data()$id)
          }
        }

        auto_check_time(Sys.time())
        setProgress(1)
      })
      notify_success(paste0("Avtomatik yoxlama tamamlandı. ", alerts_sent, " yeni alert yaradıldı."))
      load_notifications()
    })

    output$last_auto_check <- renderText({
      t <- auto_check_time()
      if (is.null(t)) {
        "Son yoxlama: aparılmayıb"
      } else {
        paste0("Son yoxlama: ", format(t, "%d.%m.%Y %H:%M"))
      }
    })

    # ---- HISTORY TABLE ----
    output$notif_history_table <- renderDT({
      data <- notifications_data()
      if (nrow(data) == 0) {
        return(datatable(data.frame("Bildiriş yoxdur" = character(0))))
      }

      display <- data[, c("title", "type", "is_read", "created_at")]
      display$type <- sapply(display$type, function(t) {
        switch(t,
          warning = "Xəbərdarlıq",
          info = "Məlumat",
          error = "Xəta",
          success = "Uğur",
          t
        )
      })
      display$is_read <- ifelse(display$is_read, "Oxunmuş", "Oxunmamış")
      display$created_at <- format_datetime_az(display$created_at)
      names(display) <- c("Başlıq", "Növ", "Status", "Tarix")

      datatable(display, options = default_dt_options(15), rownames = FALSE) %>%
        formatStyle("Status",
          color = styleEqual(c("Oxunmuş", "Oxunmamış"), c("#27ae60", "#e74c3c")),
          fontWeight = "bold"
        )
    })

    # ---- EXPORT ----
    output$btn_notif_export <- downloadHandler(
      filename = function() {
        paste0("bildirislər_", format(Sys.Date(), "%Y%m%d"), ".xlsx")
      },
      content = function(file) {
        data <- notifications_data()
        if (nrow(data) == 0) return()
        export_df <- data[, c("title", "message", "type", "is_read", "created_at")]
        names(export_df) <- c("Başlıq", "Mesaj", "Növ", "Oxunub", "Tarix")
        export_to_excel(export_df, file, "Bildirişlər")
      }
    )
  })
}

# =============================================
# KÖMƏKÇI: Avtomatik alert göndər
# =============================================
send_auto_alerts <- function(db_pool, students_df, alert_type, sender_id) {
  sent <- 0

  titles <- c(
    risk = "Avtomatik Risk Xəbərdarlığı",
    attendance = "Avtomatik Davamiyyət Xəbərdarlığı",
    grade_drop = "Avtomatik Qiymət Düşüşü Xəbərdarlığı",
    homework = "Avtomatik Ev Tapşırığı Xəbərdarlığı"
  )

  for (i in seq_len(min(nrow(students_df), 50))) {
    s <- students_df[i, ]

    msg <- switch(alert_type,
      risk = paste0(
        s$first_name, " ", s$last_name, " (", s$grade, s$section, ") - orta bal: ",
        round(s$avg_score, 1), ". Aşağı performans risk altındadır."
      ),
      attendance = paste0(
        s$first_name, " ", s$last_name, " (", s$grade, s$section, ") - davamiyyət: ",
        round(s$att_pct, 1), "%. 80%-dən aşağıdır."
      ),
      grade_drop = paste0(
        s$first_name, " ", s$last_name, " (", s$grade, s$section, ") - qiymət trendi: ",
        round(s$trend, 1), " bal. Ciddi düşüş qeydə alınıb."
      ),
      homework = paste0(
        s$first_name, " ", s$last_name, " (", s$grade, s$section, ") - ev tapşırığı ortalaması: ",
        round(s$hw_avg, 1), ". 50%-dən aşağıdır."
      ),
      ""
    )

    # Find teachers for this student
    teachers <- tryCatch(db_query(db_pool,
      "SELECT DISTINCT t.user_id FROM teachers t
       JOIN grades g ON g.teacher_id = t.id
       WHERE g.student_id = $1 AND g.grade_date >= CURRENT_DATE - INTERVAL '3 months'",
      params = list(s$id)), error = function(e) data.frame())

    if (nrow(teachers) > 0) {
      for (j in seq_len(nrow(teachers))) {
        # Check if similar notification already sent today
        existing <- tryCatch(
          db_get_one(db_pool,
            "SELECT COUNT(*) as n FROM notifications
             WHERE user_id = $1 AND title = $2 AND created_at >= CURRENT_DATE",
            params = list(teachers$user_id[j], titles[alert_type]))$n %||% 0,
          error = function(e) 0
        )

        if (existing == 0) {
          tryCatch({
            db_execute(db_pool,
              "INSERT INTO notifications (user_id, title, message, type, created_at) VALUES ($1, $2, $3, 'warning', NOW())",
              params = list(teachers$user_id[j], titles[alert_type], msg))
            sent <- sent + 1
          }, error = function(e) NULL)
        }
      }
    }
  }

  sent
}
