# =============================================
# Tədqiqat Modulu - Server
# =============================================

# --- Tədqiqat Layihələri Server ---
research_projects_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    projects <- reactive({
      input$btn_r_refresh
      query <- "SELECT rp.*, u.username AS lead_researcher
                FROM research_projects rp
                LEFT JOIN users u ON rp.lead_researcher_id = u.id
                WHERE 1=1"
      params <- list()
      param_idx <- 1

      if (!is_empty(input$filter_r_status)) {
        query <- paste0(query, " AND rp.status = $", param_idx)
        params[[param_idx]] <- input$filter_r_status
        param_idx <- param_idx + 1
      }

      query <- paste0(query, " ORDER BY rp.created_at DESC")

      if (length(params) > 0) db_query(db_pool, query, params = params)
      else db_query(db_pool, query)
    })

    output$research_table <- renderDT({
      data <- projects()
      if (nrow(data) == 0) return(datatable(data.frame("Məlumat yoxdur" = character(0))))

      display <- data %>%
        select(title, research_type, lead_researcher, start_date, end_date, progress, status) %>%
        rename(
          "Layihə" = title, "Növ" = research_type, "Rəhbər" = lead_researcher,
          "Başlama" = start_date, "Bitmə" = end_date, "İrəliləyiş (%)" = progress,
          "Status" = status
        )

      datatable(display, selection = "single", options = default_dt_options())
    })

    # Metrikalar
    metrics <- reactive({
      calculate_research_metrics(db_pool)
    })

    output$total_projects_box <- renderValueBox({
      m <- metrics()
      valueBox(m$total_projects, "Ümumi Layihə", icon = icon("flask"), color = "aqua")
    })

    output$active_projects_box <- renderValueBox({
      m <- metrics()
      valueBox(m$active_projects, "Aktiv Layihə", icon = icon("spinner"), color = "green")
    })

    output$total_publications_box <- renderValueBox({
      m <- metrics()
      valueBox(m$total_publications, "Nəşrlər", icon = icon("file-alt"), color = "yellow")
    })

    output$total_citations_box <- renderValueBox({
      m <- metrics()
      valueBox(m$total_citations, "İstinadlar", icon = icon("quote-right"), color = "purple")
    })

    # Yeni tədqiqat
    observeEvent(input$btn_add_research, {
      showModal(modalDialog(
        title = "Yeni Tədqiqat Layihəsi", size = "l",
        textInput(ns("r_title"), "Layihə adı:"),
        selectInput(ns("r_type"), "Tədqiqat növü:",
          choices = c("Fundamental" = "fundamental", "Tətbiqi" = "tetbiqi",
                      "Siyasət Analizi" = "siyaset_analizi")),
        textAreaInput(ns("r_desc"), "Təsvir:", rows = 3),
        textAreaInput(ns("r_objectives"), "Məqsədlər:", rows = 2),
        textAreaInput(ns("r_methodology"), "Metodologiya:", rows = 2),
        textInput(ns("r_department"), "Şöbə:"),
        fluidRow(
          column(6, dateInput(ns("r_start"), "Başlama tarixi:", language = "az")),
          column(6, dateInput(ns("r_end"), "Bitmə tarixi:", language = "az"))
        ),
        numericInput(ns("r_budget"), "Büdcə (AZN):", value = 0, min = 0),
        textInput(ns("r_funding"), "Maliyyə mənbəyi:"),
        footer = tagList(
          modalButton("Ləğv et"),
          actionButton(ns("btn_save_research"), "Saxla", class = "btn-primary")
        )
      ))
    })

    observeEvent(input$btn_save_research, {
      data <- list(
        title = input$r_title,
        research_type = input$r_type,
        start_date = input$r_start,
        end_date = input$r_end,
        budget = input$r_budget,
        progress = 0
      )

      errors <- validate_research_data(data)
      if (length(errors) > 0) {
        notify_error(paste(errors, collapse = "\n"))
        return()
      }

      tryCatch({
        db_execute(db_pool,
          "INSERT INTO research_projects
           (title, research_type, description, objectives, methodology,
            lead_researcher_id, department, start_date, end_date, budget, funding_source, status)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, 'planned')",
          params = list(
            input$r_title, input$r_type, input$r_desc, input$r_objectives,
            input$r_methodology, user_data()$sub, input$r_department,
            input$r_start, input$r_end, input$r_budget, input$r_funding
          ))
        removeModal()
        notify_success("Tədqiqat layihəsi yaradıldı")
      }, error = function(e) {
        log_error("Tədqiqat yaratma xətası: {e$message}")
        notify_error("Xəta baş verdi")
      })
    })
  })
}

# --- Siyasət Analizi Server ---
research_policy_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    policy_projects <- reactive({
      input$btn_policy_refresh
      query <- "SELECT rp.*, u.username AS lead_researcher
                FROM research_projects rp
                LEFT JOIN users u ON rp.lead_researcher_id = u.id
                WHERE rp.research_type = 'siyaset_analizi'"
      params <- list()
      param_idx <- 1

      if (!is_empty(input$filter_policy_status)) {
        query <- paste0(query, " AND rp.status = $", param_idx)
        params[[param_idx]] <- input$filter_policy_status
        param_idx <- param_idx + 1
      }

      query <- paste0(query, " ORDER BY rp.created_at DESC")

      if (length(params) > 0) db_query(db_pool, query, params = params)
      else db_query(db_pool, query)
    })

    output$policy_table <- renderDT({
      data <- policy_projects()
      if (nrow(data) == 0) return(datatable(data.frame("Məlumat yoxdur" = character(0))))

      display <- data %>%
        select(title, lead_researcher, start_date, progress, status) %>%
        rename(
          "Analiz" = title, "Rəhbər" = lead_researcher,
          "Başlama" = start_date, "İrəliləyiş (%)" = progress, "Status" = status
        )

      datatable(display, selection = "single", options = default_dt_options())
    })

    # Nəşrlər
    publications <- reactive({
      db_query(db_pool,
        "SELECT rp.* FROM research_publications rp
         JOIN research_projects rj ON rp.project_id = rj.id
         WHERE rj.research_type = 'siyaset_analizi'
         ORDER BY rp.publish_date DESC")
    })

    output$publications_table <- renderDT({
      data <- publications()
      if (nrow(data) == 0) return(datatable(data.frame("Məlumat yoxdur" = character(0))))

      display <- data %>%
        select(title, authors, journal, publish_date, citation_count) %>%
        rename(
          "Nəşr" = title, "Müəlliflər" = authors, "Jurnal" = journal,
          "Tarix" = publish_date, "İstinad" = citation_count
        )

      datatable(display, selection = "single", options = default_dt_options())
    })

    # Yeni nəşr
    observeEvent(input$btn_add_publication, {
      projects <- db_query(db_pool,
        "SELECT id, title FROM research_projects ORDER BY title")
      project_choices <- c("Seçin" = "")
      if (nrow(projects) > 0) {
        project_choices <- c(project_choices, setNames(projects$id, projects$title))
      }

      showModal(modalDialog(
        title = "Yeni Nəşr", size = "l",
        selectInput(ns("pub_project"), "Layihə:", choices = project_choices),
        textInput(ns("pub_title"), "Nəşr adı:"),
        textInput(ns("pub_authors"), "Müəlliflər:"),
        textInput(ns("pub_journal"), "Jurnal:"),
        fluidRow(
          column(4, textInput(ns("pub_volume"), "Cild:")),
          column(4, textInput(ns("pub_issue"), "Buraxılış:")),
          column(4, textInput(ns("pub_pages"), "Səhifələr:"))
        ),
        dateInput(ns("pub_date"), "Nəşr tarixi:", language = "az"),
        textInput(ns("pub_doi"), "DOI:"),
        textAreaInput(ns("pub_abstract"), "Xülasə:", rows = 3),
        textInput(ns("pub_keywords"), "Açar sözlər:"),
        selectInput(ns("pub_type"), "Nəşr növü:",
          choices = c("Məqalə" = "article", "Konfrans" = "conference",
                      "Kitab fəsli" = "book_chapter", "Hesabat" = "report")),
        footer = tagList(
          modalButton("Ləğv et"),
          actionButton(ns("btn_save_publication"), "Saxla", class = "btn-info")
        )
      ))
    })

    observeEvent(input$btn_save_publication, {
      data <- list(title = input$pub_title, authors = input$pub_authors, doi = input$pub_doi)

      errors <- validate_publication_data(data)
      if (length(errors) > 0) {
        notify_error(paste(errors, collapse = "\n"))
        return()
      }

      tryCatch({
        db_execute(db_pool,
          "INSERT INTO research_publications
           (project_id, title, authors, journal, volume, issue, pages,
            publish_date, doi, abstract, keywords, publication_type)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)",
          params = list(
            if (is_empty(input$pub_project)) NULL else input$pub_project,
            input$pub_title, input$pub_authors, input$pub_journal,
            input$pub_volume, input$pub_issue, input$pub_pages,
            input$pub_date, input$pub_doi, input$pub_abstract,
            input$pub_keywords, input$pub_type
          ))
        removeModal()
        notify_success("Nəşr əlavə edildi")
      }, error = function(e) {
        log_error("Nəşr əlavə xətası: {e$message}")
        notify_error("Xəta baş verdi")
      })
    })
  })
}

# --- Doktorantura Server ---
research_doctoral_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Proqram siyahısını yenilə
    observe({
      programs <- db_query(db_pool,
        "SELECT id, program_name FROM doctoral_programs WHERE status = 'active' ORDER BY program_name")
      choices <- c("Hamısı" = "")
      if (nrow(programs) > 0) {
        choices <- c(choices, setNames(programs$id, programs$program_name))
      }
      updateSelectInput(session, "filter_doc_program", choices = choices)
    })

    # Proqramlar cədvəli
    doctoral_programs <- reactive({
      db_query(db_pool,
        "SELECT dp.*, u.username AS coordinator,
                COUNT(ds.id) AS student_count
         FROM doctoral_programs dp
         LEFT JOIN users u ON dp.coordinator_id = u.id
         LEFT JOIN doctoral_students ds ON ds.program_id = dp.id AND ds.status = 'active'
         GROUP BY dp.id, u.username
         ORDER BY dp.program_name")
    })

    output$doctoral_programs_table <- renderDT({
      data <- doctoral_programs()
      if (nrow(data) == 0) return(datatable(data.frame("Məlumat yoxdur" = character(0))))

      display <- data %>%
        select(program_name, department, duration_years, student_count, max_students, status) %>%
        rename(
          "Proqram" = program_name, "Şöbə" = department,
          "Müddət (il)" = duration_years, "Doktorant" = student_count,
          "Maks." = max_students, "Status" = status
        )

      datatable(display, selection = "single", options = default_dt_options())
    })

    # Doktorantlar cədvəli
    doctoral_students <- reactive({
      query <- "SELECT ds.*, dp.program_name, u.username AS student_name,
                       su.username AS supervisor_name
                FROM doctoral_students ds
                JOIN doctoral_programs dp ON ds.program_id = dp.id
                JOIN users u ON ds.user_id = u.id
                LEFT JOIN users su ON ds.supervisor_id = su.id
                WHERE 1=1"
      params <- list()
      param_idx <- 1

      if (!is_empty(input$filter_doc_program)) {
        query <- paste0(query, " AND ds.program_id = $", param_idx)
        params[[param_idx]] <- input$filter_doc_program
        param_idx <- param_idx + 1
      }

      if (!is_empty(input$filter_doc_status)) {
        query <- paste0(query, " AND ds.status = $", param_idx)
        params[[param_idx]] <- input$filter_doc_status
        param_idx <- param_idx + 1
      }

      query <- paste0(query, " ORDER BY ds.admission_date DESC")

      if (length(params) > 0) db_query(db_pool, query, params = params)
      else db_query(db_pool, query)
    })

    output$doctoral_students_table <- renderDT({
      data <- doctoral_students()
      if (nrow(data) == 0) return(datatable(data.frame("Məlumat yoxdur" = character(0))))

      display <- data %>%
        select(student_name, program_name, supervisor_name, dissertation_title,
               admission_date, progress, status) %>%
        rename(
          "Doktorant" = student_name, "Proqram" = program_name,
          "Elmi Rəhbər" = supervisor_name, "Dissertasiya" = dissertation_title,
          "Qəbul" = admission_date, "İrəliləyiş (%)" = progress, "Status" = status
        )

      datatable(display, selection = "single", options = default_dt_options())
    })

    # Yeni proqram
    observeEvent(input$btn_add_program, {
      showModal(modalDialog(
        title = "Yeni Doktorantura Proqramı",
        textInput(ns("dp_name"), "Proqram adı:"),
        textInput(ns("dp_department"), "Şöbə:"),
        textInput(ns("dp_code"), "İxtisas kodu:"),
        textAreaInput(ns("dp_desc"), "Təsvir:", rows = 3),
        numericInput(ns("dp_duration"), "Müddət (il):", value = 4, min = 2, max = 7),
        numericInput(ns("dp_max"), "Maks. doktorant:", value = 10, min = 1),
        textAreaInput(ns("dp_requirements"), "Qəbul tələbləri:", rows = 3),
        footer = tagList(
          modalButton("Ləğv et"),
          actionButton(ns("btn_save_program"), "Saxla", class = "btn-primary")
        )
      ))
    })

    observeEvent(input$btn_save_program, {
      if (is_empty(input$dp_name)) {
        notify_error("Proqram adı daxil edilməlidir")
        return()
      }

      tryCatch({
        db_execute(db_pool,
          "INSERT INTO doctoral_programs
           (program_name, department, specialization_code, description,
            duration_years, max_students, coordinator_id, admission_requirements)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8)",
          params = list(
            input$dp_name, input$dp_department, input$dp_code, input$dp_desc,
            input$dp_duration, input$dp_max, user_data()$sub, input$dp_requirements
          ))
        removeModal()
        notify_success("Doktorantura proqramı yaradıldı")
      }, error = function(e) {
        log_error("Proqram yaratma xətası: {e$message}")
        notify_error("Xəta baş verdi")
      })
    })

    # Yeni doktorant
    observeEvent(input$btn_add_doctoral, {
      programs <- db_query(db_pool,
        "SELECT id, program_name FROM doctoral_programs WHERE status = 'active'")
      prog_choices <- setNames(programs$id, programs$program_name)

      showModal(modalDialog(
        title = "Yeni Doktorant",
        selectInput(ns("ds_program"), "Proqram:", choices = prog_choices),
        textInput(ns("ds_dissertation"), "Dissertasiya mövzusu:"),
        textInput(ns("ds_area"), "Tədqiqat sahəsi:"),
        dateInput(ns("ds_admission"), "Qəbul tarixi:", language = "az"),
        dateInput(ns("ds_expected"), "Gözlənilən bitmə:", language = "az"),
        footer = tagList(
          modalButton("Ləğv et"),
          actionButton(ns("btn_save_doctoral"), "Saxla", class = "btn-primary")
        )
      ))
    })

    observeEvent(input$btn_save_doctoral, {
      data <- list(
        program_id = input$ds_program,
        user_id = user_data()$sub,
        dissertation_title = input$ds_dissertation
      )

      errors <- validate_doctoral_data(data)
      if (length(errors) > 0) {
        notify_error(paste(errors, collapse = "\n"))
        return()
      }

      tryCatch({
        db_execute(db_pool,
          "INSERT INTO doctoral_students
           (program_id, user_id, dissertation_title, research_area,
            admission_date, expected_completion, status)
           VALUES ($1, $2, $3, $4, $5, $6, 'active')",
          params = list(
            input$ds_program, user_data()$sub, input$ds_dissertation,
            input$ds_area, input$ds_admission, input$ds_expected
          ))
        removeModal()
        notify_success("Doktorant əlavə edildi")
      }, error = function(e) {
        log_error("Doktorant əlavə xətası: {e$message}")
        notify_error("Xəta baş verdi")
      })
    })
  })
}
