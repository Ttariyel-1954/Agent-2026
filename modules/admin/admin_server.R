# =============================================
# ARTI-2026: Admin Paneli Server
# İstifadəçi CRUD, parametrlər, audit loglar
# =============================================

# === İstifadəçi İdarəetməsi Server ===
admin_users_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Yeniləmə trigeri
    refresh_trigger <- reactiveVal(0)

    # İstifadəçi siyahısı
    users <- reactive({
      refresh_trigger()
      input$btn_refresh
      get_all_users(db_pool,
        search = input$search,
        role = input$filter_role,
        status = input$filter_status
      )
    })

    # Statistika
    output$total_users_box <- renderValueBox({
      all_users <- db_query(db_pool, "SELECT COUNT(*) as n FROM users")
      valueBox(all_users$n[1], "Ümumi İstifadəçi", icon = icon("users"), color = "blue")
    })

    output$active_users_box <- renderValueBox({
      active <- db_query(db_pool, "SELECT COUNT(*) as n FROM users WHERE is_active = TRUE")
      valueBox(active$n[1], "Aktiv", icon = icon("check-circle"), color = "green")
    })

    output$admin_count_box <- renderValueBox({
      admins <- db_query(db_pool, "SELECT COUNT(*) as n FROM users WHERE role = 'admin'")
      valueBox(admins$n[1], "Admin", icon = icon("user-shield"), color = "red")
    })

    output$teacher_count_box <- renderValueBox({
      teachers <- db_query(db_pool, "SELECT COUNT(*) as n FROM users WHERE role = 'teacher'")
      valueBox(teachers$n[1], "Müəllim", icon = icon("chalkboard-teacher"), color = "yellow")
    })

    # Cədvəl
    output$users_table <- renderDT({
      df <- users()
      if (nrow(df) == 0) return(datatable(data.frame(Mesaj = "İstifadəçi tapılmadı")))

      df$full_name <- paste(df$first_name, df$last_name)
      df$status_badge <- ifelse(df$is_active,
        '<span class="badge" style="background:#27ae60;">Aktiv</span>',
        '<span class="badge" style="background:#e74c3c;">Deaktiv</span>'
      )
      df$role_label <- sapply(df$role, function(r) {
        switch(r,
          "admin" = "Admin", "teacher" = "Müəllim", "student" = "Şagird",
          "parent" = "Valideyn", "inspector" = "Müfəttiş", r)
      })
      df$last_login_fmt <- sapply(df$last_login, function(d) {
        if (is.na(d) || is.null(d)) "Heç vaxt" else format_datetime_az(d)
      })

      display_df <- df[, c("full_name", "username", "email", "role_label",
                            "status_badge", "last_login_fmt", "created_at")]
      names(display_df) <- c("Ad Soyad", "İst. Adı", "E-poçt", "Rol",
                             "Status", "Son Giriş", "Yaradılma")

      datatable(display_df,
        escape = FALSE,
        selection = "single",
        options = default_dt_options(25),
        rownames = FALSE
      )
    })

    # Yeni istifadəçi modal
    observeEvent(input$btn_add, {
      showModal(modalDialog(
        title = "Yeni İstifadəçi",
        size = "m",
        textInput(ns("new_fullname"), "Ad Soyad:", placeholder = "Ad Soyad"),
        textInput(ns("new_email"), "E-poçt:", placeholder = "email@example.com"),
        textInput(ns("new_username"), "İstifadəçi Adı:", placeholder = "username"),
        passwordInput(ns("new_password"), "Şifrə:"),
        selectInput(ns("new_role"), "Rol:",
          choices = c("Müəllim" = "teacher", "Şagird" = "student",
                      "Valideyn" = "parent", "Admin" = "admin", "Müfəttiş" = "inspector")
        ),
        footer = tagList(
          modalButton("Ləğv et"),
          actionButton(ns("btn_save_user"), "Yadda Saxla",
                       class = "btn-success", icon = icon("save"))
        )
      ))
    })

    # Yeni istifadəçi saxla
    observeEvent(input$btn_save_user, {
      # Validasiya
      if (is_empty(input$new_fullname)) {
        notify_error("Ad soyad daxil edin"); return()
      }
      if (!validate_email(input$new_email)) {
        notify_error("Düzgün e-poçt daxil edin"); return()
      }
      if (is_empty(input$new_username) || nchar(input$new_username) < 3) {
        notify_error("İstifadəçi adı ən azı 3 simvol olmalıdır"); return()
      }
      if (is_empty(input$new_password) || nchar(input$new_password) < 8) {
        notify_error("Şifrə ən azı 8 simvol olmalıdır"); return()
      }

      result <- create_user(db_pool,
        full_name = input$new_fullname,
        email = input$new_email,
        username = input$new_username,
        password = input$new_password,
        role = input$new_role
      )

      if (result$success) {
        log_audit(db_pool, user_data()$id, "user_create",
                  details = list(username = input$new_username, role = input$new_role))
        notify_success("İstifadəçi uğurla yaradıldı")
        removeModal()
        refresh_trigger(refresh_trigger() + 1)
      } else {
        notify_error(result$error)
      }
    })

    # Redaktə — cədvəldən seçim
    observeEvent(input$users_table_rows_selected, {
      row <- input$users_table_rows_selected
      if (is.null(row)) return()

      df <- users()
      user <- df[row, ]

      showModal(modalDialog(
        title = "İstifadəçi Redaktəsi",
        size = "m",
        textInput(ns("edit_firstname"), "Ad:", value = user$first_name),
        textInput(ns("edit_lastname"), "Soyad:", value = user$last_name),
        textInput(ns("edit_email"), "E-poçt:", value = user$email),
        textInput(ns("edit_phone"), "Telefon:", value = user$phone %||% ""),
        selectInput(ns("edit_role"), "Rol:",
          choices = c("Müəllim" = "teacher", "Şagird" = "student",
                      "Valideyn" = "parent", "Admin" = "admin", "Müfəttiş" = "inspector"),
          selected = user$role
        ),
        tags$hr(),
        fluidRow(
          column(6,
            if (user$is_active) {
              actionButton(ns("btn_deactivate"), "Deaktiv Et",
                           class = "btn-danger btn-block", icon = icon("ban"))
            } else {
              actionButton(ns("btn_activate"), "Aktiv Et",
                           class = "btn-success btn-block", icon = icon("check"))
            }
          ),
          column(6,
            actionButton(ns("btn_reset_pass"), "Şifrə Sıfırla",
                         class = "btn-warning btn-block", icon = icon("key"))
          )
        ),
        footer = tagList(
          modalButton("Ləğv et"),
          actionButton(ns("btn_update_user"), "Yenilə",
                       class = "btn-primary", icon = icon("save"))
        )
      ))
    })

    # Seçilmiş istifadəçi ID-si
    selected_user_id <- reactive({
      row <- input$users_table_rows_selected
      if (is.null(row)) return(NULL)
      users()[row, "id"]
    })

    # Yenilə
    observeEvent(input$btn_update_user, {
      uid <- selected_user_id()
      if (is.null(uid)) return()

      result <- update_user(db_pool, uid,
        first_name = input$edit_firstname,
        last_name = input$edit_lastname,
        email = input$edit_email,
        role = input$edit_role,
        phone = if (is_empty(input$edit_phone)) NULL else input$edit_phone
      )

      if (result$success) {
        log_audit(db_pool, user_data()$id, "user_update",
                  entity_type = "user", entity_id = uid)
        notify_success("İstifadəçi yeniləndi")
        removeModal()
        refresh_trigger(refresh_trigger() + 1)
      } else {
        notify_error("Yeniləmə uğursuz oldu")
      }
    })

    # Deaktiv et
    observeEvent(input$btn_deactivate, {
      uid <- selected_user_id()
      if (is.null(uid)) return()
      result <- deactivate_user(db_pool, uid)
      if (result$success) {
        log_audit(db_pool, user_data()$id, "user_deactivate",
                  entity_type = "user", entity_id = uid)
        notify_success("İstifadəçi deaktiv edildi")
        removeModal()
        refresh_trigger(refresh_trigger() + 1)
      }
    })

    # Aktiv et
    observeEvent(input$btn_activate, {
      uid <- selected_user_id()
      if (is.null(uid)) return()
      result <- activate_user(db_pool, uid)
      if (result$success) {
        log_audit(db_pool, user_data()$id, "user_activate",
                  entity_type = "user", entity_id = uid)
        notify_success("İstifadəçi aktiv edildi")
        removeModal()
        refresh_trigger(refresh_trigger() + 1)
      }
    })

    # Şifrə sıfırla
    observeEvent(input$btn_reset_pass, {
      uid <- selected_user_id()
      if (is.null(uid)) return()

      showModal(modalDialog(
        title = "Şifrə Sıfırlama",
        passwordInput(ns("reset_new_pass"), "Yeni Şifrə:"),
        passwordInput(ns("reset_confirm_pass"), "Şifrəni Təsdiqlə:"),
        footer = tagList(
          modalButton("Ləğv et"),
          actionButton(ns("btn_confirm_reset"), "Sıfırla",
                       class = "btn-warning", icon = icon("key"))
        )
      ))
    })

    observeEvent(input$btn_confirm_reset, {
      uid <- selected_user_id()
      if (is.null(uid)) return()
      if (input$reset_new_pass != input$reset_confirm_pass) {
        notify_error("Şifrələr uyğun gəlmir"); return()
      }
      if (nchar(input$reset_new_pass) < 8) {
        notify_error("Şifrə ən azı 8 simvol olmalıdır"); return()
      }

      result <- reset_user_password(db_pool, uid, input$reset_new_pass)
      if (result$success) {
        log_audit(db_pool, user_data()$id, "password_reset",
                  entity_type = "user", entity_id = uid)
        notify_success("Şifrə sıfırlandı")
        removeModal()
      }
    })

    # İxrac
    output$btn_export <- downloadHandler(
      filename = function() {
        paste0("istifadeciler_", format(Sys.Date(), "%Y%m%d"), ".xlsx")
      },
      content = function(file) {
        df <- users()
        df$full_name <- paste(df$first_name, df$last_name)
        export_df <- df[, c("full_name", "username", "email", "role", "is_active", "created_at")]
        names(export_df) <- c("Ad Soyad", "İst. Adı", "E-poçt", "Rol", "Aktiv", "Yaradılma")
        export_to_excel(export_df, file, "İstifadəçilər")
      }
    )
  })
}

# === Sistem Parametrləri Server ===
admin_settings_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Parametrləri yüklə
    observe({
      settings <- get_system_settings(db_pool)
      if (nrow(settings) > 0) {
        for (i in seq_len(nrow(settings))) {
          key <- settings$key[i]
          val <- settings$value[i]
          tryCatch({
            input_id <- key
            if (input_id %in% c("maintenance_mode", "require_2fa")) {
              updateCheckboxInput(session, input_id, value = as.logical(val))
            } else if (input_id %in% c("max_login_attempts", "session_timeout",
                                        "password_min_length", "ai_daily_limit", "ai_max_tokens")) {
              updateNumericInput(session, input_id, value = as.numeric(val))
            } else if (input_id %in% names(input)) {
              updateTextInput(session, input_id, value = val)
            }
          }, error = function(e) NULL)
        }
      }
    }) |> bindEvent(TRUE, once = TRUE)

    # Yadda saxla
    observeEvent(input$btn_save, {
      settings_to_save <- list(
        app_name = input$app_name,
        default_language = input$default_language,
        academic_year = input$academic_year,
        grading_system = input$grading_system,
        max_login_attempts = as.character(input$max_login_attempts),
        session_timeout = as.character(input$session_timeout),
        password_min_length = as.character(input$password_min_length),
        require_2fa = as.character(input$require_2fa),
        ai_daily_limit = as.character(input$ai_daily_limit),
        ai_default_model = input$ai_default_model,
        ai_max_tokens = as.character(input$ai_max_tokens),
        maintenance_mode = as.character(input$maintenance_mode),
        maintenance_message = input$maintenance_message
      )

      success_count <- 0
      for (key in names(settings_to_save)) {
        result <- update_system_setting(db_pool, key, settings_to_save[[key]],
                                        updated_by = user_data()$id)
        if (result$success) success_count <- success_count + 1
      }

      log_audit(db_pool, user_data()$id, "settings_update",
                details = list(updated_keys = names(settings_to_save)))

      notify_success(paste0(success_count, " parametr yadda saxlanıldı"))
    })

    # Sıfırla
    observeEvent(input$btn_reset, {
      updateTextInput(session, "app_name", value = "ARTI-2026")
      updateSelectInput(session, "default_language", selected = "az")
      updateTextInput(session, "academic_year", value = get_academic_year())
      updateSelectInput(session, "grading_system", selected = "100")
      updateNumericInput(session, "max_login_attempts", value = 5)
      updateNumericInput(session, "session_timeout", value = 30)
      updateNumericInput(session, "password_min_length", value = 8)
      updateCheckboxInput(session, "require_2fa", value = FALSE)
      updateNumericInput(session, "ai_daily_limit", value = 50)
      updateSelectInput(session, "ai_default_model", selected = "claude")
      updateNumericInput(session, "ai_max_tokens", value = 2000)
      updateCheckboxInput(session, "maintenance_mode", value = FALSE)
      notify_success("Parametrlər sıfırlandı")
    })
  })
}

# === Audit Log Server ===
admin_logs_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Filtr seçimlərini doldur
    observe({
      # Əməliyyat növləri
      actions <- get_audit_action_types(db_pool)
      updateSelectInput(session, "filter_action",
        choices = c("Hamısı" = "", actions))

      # İstifadəçilər
      users_df <- db_query(db_pool,
        "SELECT id, first_name || ' ' || last_name as name FROM users ORDER BY first_name")
      if (nrow(users_df) > 0) {
        user_choices <- setNames(users_df$id, users_df$name)
        updateSelectInput(session, "filter_user",
          choices = c("Hamısı" = "", user_choices))
      }
    }) |> bindEvent(TRUE, once = TRUE)

    # Log datası
    logs_data <- reactive({
      input$btn_filter
      isolate({
        get_audit_logs(db_pool,
          limit = 500,
          user_id = if (is_empty(input$filter_user)) NULL else input$filter_user,
          action = if (is_empty(input$filter_action)) NULL else input$filter_action,
          date_from = input$date_from,
          date_to = input$date_to
        )
      })
    })

    # Statistika
    output$total_logs_box <- renderValueBox({
      df <- logs_data()
      valueBox(nrow(df), "Ümumi Log", icon = icon("list"), color = "blue")
    })

    output$today_logs_box <- renderValueBox({
      today_count <- db_query(db_pool,
        "SELECT COUNT(*) as n FROM audit_logs WHERE created_at::date = CURRENT_DATE")
      valueBox(today_count$n[1], "Bugünkü", icon = icon("calendar-day"), color = "green")
    })

    output$unique_users_box <- renderValueBox({
      df <- logs_data()
      n <- if (nrow(df) > 0) length(unique(df$user_id)) else 0
      valueBox(n, "Unikal İstifadəçi", icon = icon("user"), color = "yellow")
    })

    # Cədvəl
    output$logs_table <- renderDT({
      df <- logs_data()
      if (nrow(df) == 0) {
        return(datatable(data.frame(Mesaj = "Log tapılmadı")))
      }

      display_df <- data.frame(
        Tarix = sapply(df$created_at, format_datetime_az),
        Istifadeci = df$user_name %||% "Naməlum",
        Emeliyyat = df$action,
        Tip = df$entity_type %||% "",
        IP = df$ip_address %||% "",
        stringsAsFactors = FALSE
      )
      names(display_df) <- c("Tarix", "İstifadəçi", "Əməliyyat", "Obyekt Tipi", "IP")

      datatable(display_df,
        selection = "none",
        options = default_dt_options(50),
        rownames = FALSE
      )
    })

    # CSV ixrac
    output$btn_export <- downloadHandler(
      filename = function() {
        paste0("audit_logs_", format(Sys.Date(), "%Y%m%d"), ".csv")
      },
      content = function(file) {
        df <- logs_data()
        write.csv(df, file, row.names = FALSE, fileEncoding = "UTF-8")
      }
    )
  })
}
