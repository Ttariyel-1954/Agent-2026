# =============================================
# Peşəkar İnkişaf Modulu - Server
# =============================================

# --- Müəllim Təlimləri Server ---
dev_training_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    trainings <- reactive({
      input$btn_train_refresh
      query <- "SELECT tp.*, u.username AS created_by_name
                FROM training_programs tp
                LEFT JOIN users u ON tp.created_by = u.id
                WHERE 1=1"
      params <- list()
      param_idx <- 1

      if (!is_empty(input$filter_train_type)) {
        query <- paste0(query, " AND tp.training_type = $", param_idx)
        params[[param_idx]] <- input$filter_train_type
        param_idx <- param_idx + 1
      }

      if (!is_empty(input$filter_train_status)) {
        query <- paste0(query, " AND tp.status = $", param_idx)
        params[[param_idx]] <- input$filter_train_status
        param_idx <- param_idx + 1
      }

      query <- paste0(query, " ORDER BY tp.start_date DESC")

      if (length(params) > 0) db_query(db_pool, query, params = params)
      else db_query(db_pool, query)
    })

    output$training_table <- renderDT({
      data <- trainings()
      if (nrow(data) == 0) return(datatable(data.frame("Məlumat yoxdur" = character(0))))

      display <- data %>%
        select(title, training_type, provider, start_date, end_date,
               duration_hours, is_online, status) %>%
        mutate(is_online = ifelse(is_online, "Onlayn", "Əyani")) %>%
        rename(
          "Təlim" = title, "Növ" = training_type, "Təşkilatçı" = provider,
          "Başlama" = start_date, "Bitmə" = end_date, "Saat" = duration_hours,
          "Format" = is_online, "Status" = status
        )

      datatable(display, selection = "single", options = default_dt_options())
    })

    # Statistika
    output$total_trainings_box <- renderValueBox({
      count <- get_total_count(db_pool, "training_programs")
      valueBox(count, "Ümumi Təlim", icon = icon("chalkboard"), color = "aqua")
    })

    output$total_hours_box <- renderValueBox({
      result <- db_get_one(db_pool,
        "SELECT COALESCE(SUM(duration_hours), 0) as total FROM training_programs
         WHERE status = 'completed'")
      valueBox(result$total, "Ümumi Saat", icon = icon("clock"), color = "green")
    })

    output$active_trainings_box <- renderValueBox({
      count <- get_total_count(db_pool, "training_programs", "status = 'active'")
      valueBox(count, "Aktiv Təlim", icon = icon("spinner"), color = "yellow")
    })

    output$cert_count_box <- renderValueBox({
      count <- get_total_count(db_pool, "training_programs",
        "certificate_provided = TRUE AND status = 'completed'")
      valueBox(count, "Sertifikatlı", icon = icon("certificate"), color = "purple")
    })

    # Yeni təlim
    observeEvent(input$btn_add_training, {
      showModal(modalDialog(
        title = "Yeni Təlim Proqramı", size = "l",
        textInput(ns("t_title"), "Təlim adı:"),
        selectInput(ns("t_type"), "Təlim növü:",
          choices = c("Müəllim Təlimi" = "muellim_telimi", "Seminar" = "seminar",
                      "Workshop" = "workshop", "Konfrans" = "konfrans")),
        textAreaInput(ns("t_desc"), "Təsvir:", rows = 3),
        textAreaInput(ns("t_objectives"), "Məqsədlər:", rows = 2),
        textInput(ns("t_audience"), "Hədəf auditoriya:"),
        textInput(ns("t_provider"), "Təşkilatçı:"),
        textInput(ns("t_trainer"), "Təlimçi:"),
        fluidRow(
          column(6, dateInput(ns("t_start"), "Başlama:", language = "az")),
          column(6, dateInput(ns("t_end"), "Bitmə:", language = "az"))
        ),
        numericInput(ns("t_hours"), "Müddət (saat):", value = 8, min = 1, max = 500),
        textInput(ns("t_location"), "Məkan:"),
        checkboxInput(ns("t_online"), "Onlayn təlim", value = FALSE),
        numericInput(ns("t_max"), "Maks. iştirakçı:", value = 30, min = 1),
        dateInput(ns("t_deadline"), "Qeydiyyat son tarixi:", language = "az"),
        checkboxInput(ns("t_cert"), "Sertifikat verilir", value = TRUE),
        footer = tagList(
          modalButton("Ləğv et"),
          actionButton(ns("btn_save_training"), "Saxla", class = "btn-primary")
        )
      ))
    })

    observeEvent(input$btn_save_training, {
      data <- list(
        title = input$t_title,
        training_type = input$t_type,
        start_date = input$t_start,
        end_date = input$t_end,
        duration_hours = input$t_hours,
        max_participants = input$t_max
      )

      errors <- validate_training(data)
      if (length(errors) > 0) {
        notify_error(paste(errors, collapse = "\n"))
        return()
      }

      tryCatch({
        db_execute(db_pool,
          "INSERT INTO training_programs
           (title, training_type, description, objectives, target_audience,
            provider, trainer_name, start_date, end_date, duration_hours,
            location, is_online, max_participants, registration_deadline,
            certificate_provided, status, created_by)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,'planned',$16)",
          params = list(
            input$t_title, input$t_type, input$t_desc, input$t_objectives,
            input$t_audience, input$t_provider, input$t_trainer,
            input$t_start, input$t_end, input$t_hours,
            input$t_location, input$t_online, input$t_max,
            input$t_deadline, input$t_cert, user_data()$sub
          ))
        removeModal()
        notify_success("Təlim proqramı yaradıldı")
      }, error = function(e) {
        log_error("Təlim yaratma xətası: {e$message}")
        notify_error("Xəta baş verdi")
      })
    })
  })
}

# --- Onlayn Kurslar Server ---
dev_courses_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    courses <- reactive({
      query <- "SELECT oc.*, u.username AS instructor_name
                FROM online_courses oc
                LEFT JOIN users u ON oc.instructor_id = u.id
                WHERE 1=1"
      params <- list()
      param_idx <- 1

      if (!is_empty(input$search_course)) {
        query <- paste0(query, " AND oc.title ILIKE $", param_idx)
        params[[param_idx]] <- paste0("%", input$search_course, "%")
        param_idx <- param_idx + 1
      }

      if (!is_empty(input$filter_course_status)) {
        query <- paste0(query, " AND oc.status = $", param_idx)
        params[[param_idx]] <- input$filter_course_status
        param_idx <- param_idx + 1
      }

      if (!is_empty(input$filter_course_level)) {
        query <- paste0(query, " AND oc.difficulty_level = $", param_idx)
        params[[param_idx]] <- input$filter_course_level
        param_idx <- param_idx + 1
      }

      query <- paste0(query, " ORDER BY oc.created_at DESC")

      if (length(params) > 0) db_query(db_pool, query, params = params)
      else db_query(db_pool, query)
    })

    output$courses_table <- renderDT({
      data <- courses()
      if (nrow(data) == 0) return(datatable(data.frame("Məlumat yoxdur" = character(0))))

      display <- data %>%
        select(title, instructor_name, duration_hours, difficulty_level,
               enrollment_count, rating, status) %>%
        rename(
          "Kurs" = title, "Müəllim" = instructor_name, "Saat" = duration_hours,
          "Səviyyə" = difficulty_level, "Qeydiyyat" = enrollment_count,
          "Reytinq" = rating, "Status" = status
        )

      datatable(display, selection = "single", options = default_dt_options())
    })

    # Qeydiyyatlar
    output$enrollments_table <- renderDT({
      enrollments <- db_query(db_pool,
        "SELECT ce.*, oc.title AS course_title, u.username
         FROM course_enrollments ce
         JOIN online_courses oc ON ce.course_id = oc.id
         JOIN users u ON ce.user_id = u.id
         ORDER BY ce.enrolled_at DESC
         LIMIT 100")

      if (nrow(enrollments) == 0) return(datatable(data.frame("Məlumat yoxdur" = character(0))))

      display <- enrollments %>%
        select(username, course_title, enrolled_at, progress, score, status) %>%
        rename(
          "İstifadəçi" = username, "Kurs" = course_title, "Qeydiyyat" = enrolled_at,
          "İrəliləyiş (%)" = progress, "Bal" = score, "Status" = status
        )

      datatable(display, selection = "single", options = default_dt_options())
    })

    # Yeni kurs
    observeEvent(input$btn_add_course, {
      showModal(modalDialog(
        title = "Yeni Onlayn Kurs", size = "l",
        textInput(ns("c_title"), "Kurs adı:"),
        textAreaInput(ns("c_desc"), "Təsvir:", rows = 3),
        textInput(ns("c_subject"), "Fənn sahəsi:"),
        numericInput(ns("c_hours"), "Müddət (saat):", value = 10, min = 1),
        numericInput(ns("c_modules"), "Modul sayı:", value = 5, min = 1),
        selectInput(ns("c_level"), "Çətinlik:", choices = DIFFICULTY_LEVELS),
        selectInput(ns("c_lang"), "Dil:",
          choices = c("Azərbaycan" = "az", "İngilis" = "en", "Rus" = "ru")),
        checkboxInput(ns("c_free"), "Pulsuz", value = TRUE),
        numericInput(ns("c_price"), "Qiymət (AZN):", value = 0, min = 0),
        checkboxInput(ns("c_cert"), "Sertifikat verilir", value = TRUE),
        footer = tagList(
          modalButton("Ləğv et"),
          actionButton(ns("btn_save_course"), "Saxla", class = "btn-success")
        )
      ))
    })

    observeEvent(input$btn_save_course, {
      data <- list(
        title = input$c_title,
        duration_hours = input$c_hours,
        price = input$c_price
      )

      errors <- validate_course(data)
      if (length(errors) > 0) {
        notify_error(paste(errors, collapse = "\n"))
        return()
      }

      tryCatch({
        db_execute(db_pool,
          "INSERT INTO online_courses
           (title, description, subject_area, instructor_id, duration_hours,
            total_modules, difficulty_level, language, is_free, price,
            certificate_provided, status)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,'draft')",
          params = list(
            input$c_title, input$c_desc, input$c_subject, user_data()$sub,
            input$c_hours, input$c_modules, input$c_level, input$c_lang,
            input$c_free, input$c_price, input$c_cert
          ))
        removeModal()
        notify_success("Kurs yaradıldı")
      }, error = function(e) {
        log_error("Kurs yaratma xətası: {e$message}")
        notify_error("Xəta baş verdi")
      })
    })
  })
}

# --- Mentorluq Server ---
dev_mentorship_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Proqramlar
    mentor_programs <- reactive({
      input$btn_mentor_refresh
      query <- "SELECT mp.*, u.username AS created_by_name,
                       COUNT(mpa.id) AS pair_count
                FROM mentorship_programs mp
                LEFT JOIN users u ON mp.created_by = u.id
                LEFT JOIN mentorship_pairs mpa ON mpa.program_id = mp.id
                WHERE 1=1"
      params <- list()
      param_idx <- 1

      if (!is_empty(input$filter_mentor_status)) {
        query <- paste0(query, " AND mp.status = $", param_idx)
        params[[param_idx]] <- input$filter_mentor_status
        param_idx <- param_idx + 1
      }

      query <- paste0(query, " GROUP BY mp.id, u.username ORDER BY mp.created_at DESC")

      if (length(params) > 0) db_query(db_pool, query, params = params)
      else db_query(db_pool, query)
    })

    output$mentor_programs_table <- renderDT({
      data <- mentor_programs()
      if (nrow(data) == 0) return(datatable(data.frame("Məlumat yoxdur" = character(0))))

      display <- data %>%
        select(title, start_date, end_date, pair_count, max_pairs, status) %>%
        rename(
          "Proqram" = title, "Başlama" = start_date, "Bitmə" = end_date,
          "Cüt Sayı" = pair_count, "Maks." = max_pairs, "Status" = status
        )

      datatable(display, selection = "single", options = default_dt_options())
    })

    # Cütlər
    mentor_pairs <- reactive({
      db_query(db_pool,
        "SELECT mpa.*, mp.title AS program_title,
                m.username AS mentor_name, me.username AS mentee_name
         FROM mentorship_pairs mpa
         JOIN mentorship_programs mp ON mpa.program_id = mp.id
         JOIN users m ON mpa.mentor_id = m.id
         JOIN users me ON mpa.mentee_id = me.id
         ORDER BY mpa.created_at DESC")
    })

    output$mentor_pairs_table <- renderDT({
      data <- mentor_pairs()
      if (nrow(data) == 0) return(datatable(data.frame("Məlumat yoxdur" = character(0))))

      display <- data %>%
        select(program_title, mentor_name, mentee_name, meeting_frequency, status) %>%
        rename(
          "Proqram" = program_title, "Mentor" = mentor_name,
          "Mentee" = mentee_name, "Görüş Tezliyi" = meeting_frequency,
          "Status" = status
        )

      datatable(display, selection = "single", options = default_dt_options())
    })

    # Yeni proqram
    observeEvent(input$btn_add_mentor_program, {
      showModal(modalDialog(
        title = "Yeni Mentorluq Proqramı",
        textInput(ns("mp_title"), "Proqram adı:"),
        textAreaInput(ns("mp_desc"), "Təsvir:", rows = 3),
        textAreaInput(ns("mp_objectives"), "Məqsədlər:", rows = 2),
        fluidRow(
          column(6, dateInput(ns("mp_start"), "Başlama:", language = "az")),
          column(6, dateInput(ns("mp_end"), "Bitmə:", language = "az"))
        ),
        numericInput(ns("mp_max"), "Maks. cüt sayı:", value = 10, min = 1),
        footer = tagList(
          modalButton("Ləğv et"),
          actionButton(ns("btn_save_mentor_program"), "Saxla", class = "btn-primary")
        )
      ))
    })

    observeEvent(input$btn_save_mentor_program, {
      if (is_empty(input$mp_title)) {
        notify_error("Proqram adı daxil edilməlidir")
        return()
      }

      tryCatch({
        db_execute(db_pool,
          "INSERT INTO mentorship_programs
           (title, description, objectives, start_date, end_date, max_pairs, created_by)
           VALUES ($1, $2, $3, $4, $5, $6, $7)",
          params = list(
            input$mp_title, input$mp_desc, input$mp_objectives,
            input$mp_start, input$mp_end, input$mp_max, user_data()$sub
          ))
        removeModal()
        notify_success("Mentorluq proqramı yaradıldı")
      }, error = function(e) {
        log_error("Mentorluq proqramı xətası: {e$message}")
        notify_error("Xəta baş verdi")
      })
    })

    # Avtomatik uyğunlaşdırma
    observeEvent(input$btn_auto_match, {
      tryCatch({
        mentors <- match_mentor(db_pool, user_data()$sub)
        if (nrow(mentors) == 0) {
          notify_warning("Uyğun mentor tapılmadı")
          return()
        }

        showModal(modalDialog(
          title = "Tövsiyə Olunan Mentorlar",
          DTOutput(ns("suggested_mentors")),
          footer = modalButton("Bağla")
        ))

        output$suggested_mentors <- renderDT({
          datatable(mentors %>%
            select(username, category, active_mentees) %>%
            rename("Mentor" = username, "Kateqoriya" = category, "Aktiv Mentee" = active_mentees),
            selection = "single", options = list(pageLength = 5))
        })
      }, error = function(e) {
        log_error("Mentor uyğunlaşdırma xətası: {e$message}")
        notify_error("Xəta baş verdi")
      })
    })
  })
}
