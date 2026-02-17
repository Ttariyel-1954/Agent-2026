# =============================================
# Beynəlxalq Əməkdaşlıq Modulu - Server
# =============================================

# --- Olimpiadalar Server ---
intl_olympiads_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    olympiads <- reactive({
      query <- "SELECT o.*, COUNT(op.id) AS participant_count,
                       COUNT(op.medal) FILTER (WHERE op.medal IS NOT NULL) AS medal_count
                FROM olympiads o
                LEFT JOIN olympiad_participants op ON op.olympiad_id = o.id
                WHERE 1=1"
      params <- list()
      param_idx <- 1

      if (!is_empty(input$filter_oly_subject)) {
        query <- paste0(query, " AND o.subject = $", param_idx)
        params[[param_idx]] <- input$filter_oly_subject
        param_idx <- param_idx + 1
      }

      if (!is_empty(input$filter_oly_level)) {
        query <- paste0(query, " AND o.olympiad_level = $", param_idx)
        params[[param_idx]] <- input$filter_oly_level
        param_idx <- param_idx + 1
      }

      if (!is_empty(input$filter_oly_status)) {
        query <- paste0(query, " AND o.status = $", param_idx)
        params[[param_idx]] <- input$filter_oly_status
        param_idx <- param_idx + 1
      }

      query <- paste0(query, " GROUP BY o.id ORDER BY o.event_date DESC")

      if (length(params) > 0) db_query(db_pool, query, params = params)
      else db_query(db_pool, query)
    })

    output$olympiads_table <- renderDT({
      data <- olympiads()
      if (nrow(data) == 0) return(datatable(data.frame("Məlumat yoxdur" = character(0))))

      display <- data %>%
        select(name, subject, olympiad_level, event_date, location,
               participant_count, medal_count, status) %>%
        rename(
          "Olimpiada" = name, "Fənn" = subject, "Səviyyə" = olympiad_level,
          "Tarix" = event_date, "Məkan" = location, "İştirakçı" = participant_count,
          "Medal" = medal_count, "Status" = status
        )

      datatable(display, selection = "single", options = default_dt_options())
    })

    # Medal statistikası
    stats <- reactive({
      calculate_competition_stats(db_pool)
    })

    output$gold_box <- renderValueBox({
      s <- stats()
      valueBox(s$gold_medals, "Qızıl Medal", icon = icon("medal"),
               color = "yellow")
    })

    output$silver_box <- renderValueBox({
      s <- stats()
      valueBox(s$silver_medals, "Gümüş Medal", icon = icon("medal"),
               color = "light-blue")
    })

    output$bronze_box <- renderValueBox({
      s <- stats()
      valueBox(s$bronze_medals, "Bürünc Medal", icon = icon("medal"),
               color = "orange")
    })

    output$total_participants_box <- renderValueBox({
      s <- stats()
      valueBox(s$total_participants, "Ümumi İştirakçı", icon = icon("users"),
               color = "aqua")
    })

    output$medals_chart <- renderPlotly({
      by_subject <- get_olympiad_by_subject(db_pool)
      if (nrow(by_subject) == 0) return(plotly_empty())

      plot_ly(by_subject, x = ~subject, y = ~medal_count, type = "bar",
              name = "Medal", marker = list(color = "#f1c40f")) %>%
        add_trace(y = ~participant_count, name = "İştirakçı",
                  marker = list(color = "#3498db")) %>%
        layout(
          xaxis = list(title = "", tickangle = -45),
          yaxis = list(title = "Say"),
          barmode = "group"
        )
    })

    # İştirakçılar
    participants <- reactive({
      db_query(db_pool,
        "SELECT op.*, o.name AS olympiad_name, o.subject,
                s.first_name || ' ' || s.last_name AS student_name,
                sc.name AS school_name
         FROM olympiad_participants op
         JOIN olympiads o ON op.olympiad_id = o.id
         JOIN students s ON op.student_id = s.id
         LEFT JOIN schools sc ON op.school_id = sc.id
         ORDER BY op.registered_at DESC
         LIMIT 200")
    })

    output$participants_table <- renderDT({
      data <- participants()
      if (nrow(data) == 0) return(datatable(data.frame("Məlumat yoxdur" = character(0))))

      display <- data %>%
        select(student_name, olympiad_name, subject, school_name, score, rank, medal, status) %>%
        rename(
          "Şagird" = student_name, "Olimpiada" = olympiad_name, "Fənn" = subject,
          "Məktəb" = school_name, "Bal" = score, "Yer" = rank,
          "Medal" = medal, "Status" = status
        )

      datatable(display, selection = "single", options = default_dt_options())
    })

    # Yeni olimpiada
    observeEvent(input$btn_add_olympiad, {
      showModal(modalDialog(
        title = "Yeni Olimpiada", size = "l",
        textInput(ns("o_name"), "Olimpiada adı:"),
        selectInput(ns("o_subject"), "Fənn:", choices = c("Seçin" = "", OLYMPIAD_SUBJECTS)),
        selectInput(ns("o_level"), "Səviyyə:",
          choices = c("Məktəb" = "mekteb", "Rayon" = "rayon",
                      "Respublika" = "respublika", "Beynəlxalq" = "beynelxalq")),
        textAreaInput(ns("o_desc"), "Təsvir:", rows = 3),
        textInput(ns("o_organizer"), "Təşkilatçı:"),
        dateInput(ns("o_date"), "Keçirilmə tarixi:", language = "az"),
        fluidRow(
          column(6, dateInput(ns("o_reg_start"), "Qeydiyyat başlama:", language = "az")),
          column(6, dateInput(ns("o_reg_end"), "Qeydiyyat bitmə:", language = "az"))
        ),
        textInput(ns("o_location"), "Məkan:"),
        textInput(ns("o_country"), "Ölkə:", value = "Azərbaycan"),
        numericInput(ns("o_max"), "Maks. iştirakçı:", value = 100, min = 1),
        fluidRow(
          column(6, numericInput(ns("o_age_min"), "Min. yaş:", value = 10, min = 5)),
          column(6, numericInput(ns("o_age_max"), "Maks. yaş:", value = 18, min = 5))
        ),
        footer = tagList(
          modalButton("Ləğv et"),
          actionButton(ns("btn_save_olympiad"), "Saxla", class = "btn-primary")
        )
      ))
    })

    observeEvent(input$btn_save_olympiad, {
      data <- list(
        name = input$o_name,
        subject = input$o_subject,
        olympiad_level = input$o_level,
        event_date = input$o_date,
        registration_start = input$o_reg_start,
        registration_end = input$o_reg_end,
        age_min = input$o_age_min,
        age_max = input$o_age_max
      )

      errors <- validate_olympiad_data(data)
      if (length(errors) > 0) {
        notify_error(paste(errors, collapse = "\n"))
        return()
      }

      tryCatch({
        db_execute(db_pool,
          "INSERT INTO olympiads
           (name, subject, olympiad_level, description, organizer,
            event_date, registration_start, registration_end,
            location, country, max_participants, age_min, age_max, status)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,'planned')",
          params = list(
            input$o_name, input$o_subject, input$o_level, input$o_desc,
            input$o_organizer, input$o_date, input$o_reg_start, input$o_reg_end,
            input$o_location, input$o_country, input$o_max,
            input$o_age_min, input$o_age_max
          ))
        removeModal()
        notify_success("Olimpiada yaradıldı")
      }, error = function(e) {
        log_error("Olimpiada yaratma xətası: {e$message}")
        notify_error("Xəta baş verdi")
      })
    })

    # İştirakçı əlavə et
    observeEvent(input$btn_add_participant, {
      olympiad_list <- db_query(db_pool,
        "SELECT id, name FROM olympiads WHERE status IN ('planned', 'registration') ORDER BY event_date")
      oly_choices <- c("Seçin" = "")
      if (nrow(olympiad_list) > 0) {
        oly_choices <- c(oly_choices, setNames(olympiad_list$id, olympiad_list$name))
      }

      showModal(modalDialog(
        title = "İştirakçı Əlavə Et",
        selectInput(ns("p_olympiad"), "Olimpiada:", choices = oly_choices),
        textInput(ns("p_student_fin"), "Şagird FİN:"),
        footer = tagList(
          modalButton("Ləğv et"),
          actionButton(ns("btn_save_participant"), "Qeydiyyat", class = "btn-info")
        )
      ))
    })

    observeEvent(input$btn_save_participant, {
      req(input$p_olympiad, input$p_student_fin)

      student <- db_get_one(db_pool,
        "SELECT id, school_id FROM students WHERE fin = $1",
        params = list(input$p_student_fin))

      if (is.null(student) || nrow(student) == 0) {
        notify_error("Şagird tapılmadı")
        return()
      }

      tryCatch({
        db_execute(db_pool,
          "INSERT INTO olympiad_participants (olympiad_id, student_id, school_id, status)
           VALUES ($1, $2, $3, 'registered')",
          params = list(input$p_olympiad, student$id, student$school_id))
        removeModal()
        notify_success("İştirakçı qeydiyyatdan keçdi")
      }, error = function(e) {
        if (grepl("unique", tolower(e$message))) {
          notify_warning("Bu şagird artıq qeydiyyatdan keçib")
        } else {
          log_error("İştirakçı qeydiyyat xətası: {e$message}")
          notify_error("Xəta baş verdi")
        }
      })
    })
  })
}

# --- STEAM Layihələri Server ---
intl_steam_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    steam_projects <- reactive({
      input$btn_steam_refresh
      query <- "SELECT sp.*, u.username AS lead_teacher,
                       sc.name AS school_name
                FROM steam_projects sp
                LEFT JOIN users u ON sp.lead_teacher_id = u.id
                LEFT JOIN schools sc ON sp.school_id = sc.id
                WHERE 1=1"
      params <- list()
      param_idx <- 1

      if (!is_empty(input$filter_steam_type)) {
        query <- paste0(query, " AND sp.project_type = $", param_idx)
        params[[param_idx]] <- input$filter_steam_type
        param_idx <- param_idx + 1
      }

      if (!is_empty(input$filter_steam_status)) {
        query <- paste0(query, " AND sp.status = $", param_idx)
        params[[param_idx]] <- input$filter_steam_status
        param_idx <- param_idx + 1
      }

      query <- paste0(query, " ORDER BY sp.created_at DESC")

      if (length(params) > 0) db_query(db_pool, query, params = params)
      else db_query(db_pool, query)
    })

    output$steam_table <- renderDT({
      data <- steam_projects()
      if (nrow(data) == 0) return(datatable(data.frame("Məlumat yoxdur" = character(0))))

      display <- data %>%
        select(title, project_type, lead_teacher, school_name,
               start_date, participants_count, status) %>%
        rename(
          "Layihə" = title, "Növ" = project_type, "Rəhbər" = lead_teacher,
          "Məktəb" = school_name, "Başlama" = start_date,
          "İştirakçı" = participants_count, "Status" = status
        )

      datatable(display, selection = "single", options = default_dt_options())
    })

    # Yeni STEAM layihə
    observeEvent(input$btn_add_steam, {
      showModal(modalDialog(
        title = "Yeni STEAM Layihəsi", size = "l",
        textInput(ns("s_title"), "Layihə adı:"),
        selectInput(ns("s_type"), "Layihə növü:",
          choices = c("Elm" = "science", "Texnologiya" = "technology",
                      "Mühəndislik" = "engineering", "Sənət" = "arts",
                      "Riyaziyyat" = "mathematics")),
        textAreaInput(ns("s_desc"), "Təsvir:", rows = 3),
        textAreaInput(ns("s_objectives"), "Məqsədlər:", rows = 2),
        fluidRow(
          column(6, dateInput(ns("s_start"), "Başlama:", language = "az")),
          column(6, dateInput(ns("s_end"), "Bitmə:", language = "az"))
        ),
        numericInput(ns("s_budget"), "Büdcə (AZN):", value = 0, min = 0),
        textInput(ns("s_partner"), "Partnyor təşkilat:"),
        footer = tagList(
          modalButton("Ləğv et"),
          actionButton(ns("btn_save_steam"), "Saxla", class = "btn-success")
        )
      ))
    })

    observeEvent(input$btn_save_steam, {
      data <- list(
        title = input$s_title,
        project_type = input$s_type,
        start_date = input$s_start,
        end_date = input$s_end,
        budget = input$s_budget
      )

      errors <- validate_steam_project(data)
      if (length(errors) > 0) {
        notify_error(paste(errors, collapse = "\n"))
        return()
      }

      tryCatch({
        db_execute(db_pool,
          "INSERT INTO steam_projects
           (title, description, project_type, lead_teacher_id,
            start_date, end_date, budget, objectives,
            partner_organization, status)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,'planned')",
          params = list(
            input$s_title, input$s_desc, input$s_type, user_data()$sub,
            input$s_start, input$s_end, input$s_budget,
            input$s_objectives, input$s_partner
          ))
        removeModal()
        notify_success("STEAM layihəsi yaradıldı")
      }, error = function(e) {
        log_error("STEAM layihə xətası: {e$message}")
        notify_error("Xəta baş verdi")
      })
    })
  })
}

# --- Partnyor Proqramları Server ---
intl_partners_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    partners <- reactive({
      input$btn_partner_refresh
      query <- "SELECT * FROM partner_programs WHERE 1=1"
      params <- list()
      param_idx <- 1

      if (!is_empty(input$filter_partner_type)) {
        query <- paste0(query, " AND partner_type = $", param_idx)
        params[[param_idx]] <- input$filter_partner_type
        param_idx <- param_idx + 1
      }

      if (!is_empty(input$filter_partner_status)) {
        query <- paste0(query, " AND status = $", param_idx)
        params[[param_idx]] <- input$filter_partner_status
        param_idx <- param_idx + 1
      }

      query <- paste0(query, " ORDER BY created_at DESC")

      if (length(params) > 0) db_query(db_pool, query, params = params)
      else db_query(db_pool, query)
    })

    output$partners_table <- renderDT({
      data <- partners()
      if (nrow(data) == 0) return(datatable(data.frame("Məlumat yoxdur" = character(0))))

      display <- data %>%
        select(program_name, partner_name, partner_country, partner_type,
               start_date, end_date, status) %>%
        rename(
          "Proqram" = program_name, "Partnyor" = partner_name,
          "Ölkə" = partner_country, "Növ" = partner_type,
          "Başlama" = start_date, "Bitmə" = end_date, "Status" = status
        )

      datatable(display, selection = "single", options = default_dt_options())
    })

    # Ölkə üzrə partnyorlar
    output$partner_countries_chart <- renderPlotly({
      country_data <- db_query(db_pool,
        "SELECT partner_country, COUNT(*) as cnt
         FROM partner_programs
         WHERE partner_country IS NOT NULL
         GROUP BY partner_country
         ORDER BY cnt DESC")

      if (nrow(country_data) == 0) return(plotly_empty())

      plot_ly(country_data, x = ~partner_country, y = ~cnt, type = "bar",
              marker = list(color = "#3498db")) %>%
        layout(
          xaxis = list(title = "Ölkə", tickangle = -45),
          yaxis = list(title = "Proqram Sayı")
        )
    })

    # Yeni partnyor proqram
    observeEvent(input$btn_add_partner, {
      showModal(modalDialog(
        title = "Yeni Partnyor Proqramı", size = "l",
        textInput(ns("pp_name"), "Proqram adı:"),
        textInput(ns("pp_partner"), "Partnyor adı:"),
        textInput(ns("pp_country"), "Ölkə:"),
        selectInput(ns("pp_type"), "Partnyor növü:",
          choices = c("Universitet" = "university", "Təşkilat" = "organization",
                      "Hökumət" = "government", "QHT" = "ngo")),
        textAreaInput(ns("pp_desc"), "Təsvir:", rows = 3),
        textAreaInput(ns("pp_objectives"), "Məqsədlər:", rows = 2),
        fluidRow(
          column(6, dateInput(ns("pp_start"), "Başlama:", language = "az")),
          column(6, dateInput(ns("pp_end"), "Bitmə:", language = "az"))
        ),
        textInput(ns("pp_contact"), "Əlaqə şəxsi:"),
        textInput(ns("pp_email"), "E-poçt:"),
        textInput(ns("pp_website"), "Veb sayt:"),
        textInput(ns("pp_agreement"), "Müqavilə nömrəsi:"),
        footer = tagList(
          modalButton("Ləğv et"),
          actionButton(ns("btn_save_partner"), "Saxla", class = "btn-primary")
        )
      ))
    })

    observeEvent(input$btn_save_partner, {
      data <- list(
        program_name = input$pp_name,
        partner_name = input$pp_partner,
        contact_email = input$pp_email
      )

      errors <- validate_partner_program(data)
      if (length(errors) > 0) {
        notify_error(paste(errors, collapse = "\n"))
        return()
      }

      tryCatch({
        db_execute(db_pool,
          "INSERT INTO partner_programs
           (program_name, partner_name, partner_country, partner_type,
            description, objectives, start_date, end_date,
            contact_person, contact_email, website, agreement_number, status)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,'active')",
          params = list(
            input$pp_name, input$pp_partner, input$pp_country, input$pp_type,
            input$pp_desc, input$pp_objectives, input$pp_start, input$pp_end,
            input$pp_contact, input$pp_email, input$pp_website, input$pp_agreement
          ))
        removeModal()
        notify_success("Partnyor proqramı yaradıldı")
      }, error = function(e) {
        log_error("Partnyor proqramı xətası: {e$message}")
        notify_error("Xəta baş verdi")
      })
    })
  })
}
