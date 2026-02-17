# =============================================
# Tədris Resursları Modulu - Server
# =============================================

# --- Tədris Proqramları Server ---
resources_programs_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    programs <- reactive({
      input$btn_prog_refresh
      query <- "SELECT tr.*, s.name AS subject_name
                FROM teaching_resources tr
                LEFT JOIN subjects s ON tr.subject_id = s.id
                WHERE tr.resource_type = 'tedris_proqrami' AND tr.status = 'active'"
      params <- list()
      param_idx <- 1

      if (!is_empty(input$filter_prog_subject)) {
        query <- paste0(query, " AND s.name = $", param_idx)
        params[[param_idx]] <- input$filter_prog_subject
        param_idx <- param_idx + 1
      }

      if (!is_empty(input$filter_prog_grade)) {
        query <- paste0(query, " AND tr.grade_level = $", param_idx)
        params[[param_idx]] <- as.integer(input$filter_prog_grade)
        param_idx <- param_idx + 1
      }

      query <- paste0(query, " ORDER BY tr.created_at DESC")

      if (length(params) > 0) db_query(db_pool, query, params = params)
      else db_query(db_pool, query)
    })

    output$programs_table <- renderDT({
      data <- programs()
      if (nrow(data) == 0) return(datatable(data.frame("Məlumat yoxdur" = character(0))))

      display <- data %>%
        select(title, subject_name, grade_level, author, publish_year, download_count) %>%
        rename(
          "Proqram Adı" = title, "Fənn" = subject_name, "Sinif" = grade_level,
          "Müəllif" = author, "Nəşr İli" = publish_year, "Yükləmə" = download_count
        )

      datatable(display, selection = "single", options = default_dt_options())
    })

    observeEvent(input$btn_add_program, {
      showModal(modalDialog(
        title = "Yeni Tədris Proqramı",
        textInput(ns("prog_title"), "Proqram adı:"),
        selectInput(ns("prog_subject"), "Fənn:", choices = c("Seçin" = "", SUBJECTS)),
        selectInput(ns("prog_grade"), "Sinif:",
          choices = c("Seçin" = "", setNames(1:11, paste0(1:11, "-ci sinif")))),
        textAreaInput(ns("prog_desc"), "Təsvir:", rows = 3),
        textInput(ns("prog_author"), "Müəllif:"),
        numericInput(ns("prog_year"), "Nəşr ili:", value = as.integer(format(Sys.Date(), "%Y")),
                     min = 2000, max = 2030),
        fileInput(ns("prog_file"), "Fayl yüklə:", accept = c(".pdf", ".docx", ".doc")),
        footer = tagList(
          modalButton("Ləğv et"),
          actionButton(ns("btn_save_program"), "Saxla", class = "btn-primary")
        )
      ))
    })

    observeEvent(input$btn_save_program, {
      data <- list(
        title = input$prog_title,
        resource_type = "tedris_proqrami"
      )

      errors <- validate_resource(data)
      if (length(errors) > 0) {
        notify_error(paste(errors, collapse = "\n"))
        return()
      }

      tryCatch({
        file_path <- NULL
        file_size <- NULL
        file_type <- NULL

        if (!is.null(input$prog_file)) {
          file_path <- input$prog_file$datapath
          file_size <- input$prog_file$size
          file_type <- input$prog_file$type
        }

        db_execute(db_pool,
          "INSERT INTO teaching_resources
           (title, resource_type, subject_id, grade_level, description,
            author, publish_year, file_path, file_size, file_type, uploaded_by)
           VALUES ($1, 'tedris_proqrami', $2, $3, $4, $5, $6, $7, $8, $9, $10)",
          params = list(
            input$prog_title,
            if (is_empty(input$prog_subject)) NULL else input$prog_subject,
            if (is_empty(input$prog_grade)) NULL else as.integer(input$prog_grade),
            input$prog_desc, input$prog_author, input$prog_year,
            file_path, file_size, file_type, user_data()$sub
          ))
        removeModal()
        notify_success("Tədris proqramı əlavə edildi")
      }, error = function(e) {
        log_error("Proqram əlavə xətası: {e$message}")
        notify_error("Xəta baş verdi")
      })
    })
  })
}

# --- Rəqəmsal Kontent Server ---
resources_digital_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    digital_content <- reactive({
      search_resources(db_pool,
        search_term = input$search_digital,
        resource_type = if (is_empty(input$filter_dig_type)) "reqemsal_kontent" else NULL,
        subject_id = if (is_empty(input$filter_dig_subject)) NULL else input$filter_dig_subject
      )
    })

    output$digital_table <- renderDT({
      data <- digital_content()
      if (nrow(data) == 0) return(datatable(data.frame("Məlumat yoxdur" = character(0))))

      display <- data %>%
        select(title, subject_name, file_type, author, download_count, view_count, rating) %>%
        rename(
          "Kontent" = title, "Fənn" = subject_name, "Format" = file_type,
          "Müəllif" = author, "Yükləmə" = download_count, "Baxış" = view_count,
          "Reytinq" = rating
        )

      datatable(display, selection = "single", options = default_dt_options())
    })

    # Statistika
    output$total_content_box <- renderValueBox({
      count <- get_total_count(db_pool, "teaching_resources", "resource_type = 'reqemsal_kontent'")
      valueBox(count, "Ümumi Kontent", icon = icon("file"), color = "aqua")
    })

    output$total_downloads_box <- renderValueBox({
      result <- db_get_one(db_pool,
        "SELECT COALESCE(SUM(download_count), 0) as total FROM teaching_resources")
      valueBox(format(result$total, big.mark = "."), "Ümumi Yükləmə", icon = icon("download"), color = "green")
    })

    output$total_views_box <- renderValueBox({
      result <- db_get_one(db_pool,
        "SELECT COALESCE(SUM(view_count), 0) as total FROM teaching_resources")
      valueBox(format(result$total, big.mark = "."), "Ümumi Baxış", icon = icon("eye"), color = "yellow")
    })

    output$avg_rating_box <- renderValueBox({
      result <- db_get_one(db_pool,
        "SELECT COALESCE(AVG(rating), 0) as avg_r FROM teaching_resources WHERE rating > 0")
      valueBox(round(result$avg_r, 1), "Orta Reytinq", icon = icon("star"), color = "purple")
    })

    # Kontent yüklə
    observeEvent(input$btn_upload_content, {
      showModal(modalDialog(
        title = "Rəqəmsal Kontent Yüklə",
        textInput(ns("dig_title"), "Kontent adı:"),
        selectInput(ns("dig_subject"), "Fənn:", choices = c("Seçin" = "", SUBJECTS)),
        textAreaInput(ns("dig_desc"), "Təsvir:", rows = 3),
        textInput(ns("dig_author"), "Müəllif:"),
        textInput(ns("dig_url"), "URL (əgər onlayn):", placeholder = "https://..."),
        fileInput(ns("dig_file"), "Fayl yüklə:"),
        footer = tagList(
          modalButton("Ləğv et"),
          actionButton(ns("btn_save_digital"), "Saxla", class = "btn-success")
        )
      ))
    })

    observeEvent(input$btn_save_digital, {
      data <- list(title = input$dig_title, resource_type = "reqemsal_kontent", url = input$dig_url)

      errors <- validate_resource(data)
      if (length(errors) > 0) {
        notify_error(paste(errors, collapse = "\n"))
        return()
      }

      tryCatch({
        db_execute(db_pool,
          "INSERT INTO teaching_resources
           (title, resource_type, subject_id, description, author, url, uploaded_by)
           VALUES ($1, 'reqemsal_kontent', $2, $3, $4, $5, $6)",
          params = list(
            input$dig_title,
            if (is_empty(input$dig_subject)) NULL else input$dig_subject,
            input$dig_desc, input$dig_author, input$dig_url, user_data()$sub
          ))
        removeModal()
        notify_success("Kontent əlavə edildi")
      }, error = function(e) {
        log_error("Kontent əlavə xətası: {e$message}")
        notify_error("Xəta baş verdi")
      })
    })
  })
}

# --- Dərsliklər Server ---
resources_textbooks_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    textbooks <- reactive({
      query <- "SELECT t.*, s.name AS subject_name
                FROM textbooks t
                LEFT JOIN subjects s ON t.subject_id = s.id
                WHERE t.status = 'active'"
      params <- list()
      param_idx <- 1

      if (!is_empty(input$filter_tb_subject)) {
        query <- paste0(query, " AND s.name = $", param_idx)
        params[[param_idx]] <- input$filter_tb_subject
        param_idx <- param_idx + 1
      }

      if (!is_empty(input$filter_tb_grade)) {
        query <- paste0(query, " AND t.grade_level = $", param_idx)
        params[[param_idx]] <- as.integer(input$filter_tb_grade)
        param_idx <- param_idx + 1
      }

      query <- paste0(query, " ORDER BY t.grade_level, s.name")

      if (length(params) > 0) db_query(db_pool, query, params = params)
      else db_query(db_pool, query)
    })

    output$textbooks_table <- renderDT({
      data <- textbooks()
      if (nrow(data) == 0) return(datatable(data.frame("Məlumat yoxdur" = character(0))))

      display <- data %>%
        select(title, subject_name, grade_level, author, publisher, isbn, publish_year, is_approved) %>%
        mutate(is_approved = ifelse(is_approved, "Bəli", "Xeyr")) %>%
        rename(
          "Dərslik" = title, "Fənn" = subject_name, "Sinif" = grade_level,
          "Müəllif" = author, "Nəşriyyat" = publisher, "ISBN" = isbn,
          "İl" = publish_year, "Təsdiqlənmiş" = is_approved
        )

      datatable(display, selection = "single", options = default_dt_options())
    })

    observeEvent(input$btn_add_textbook, {
      showModal(modalDialog(
        title = "Yeni Dərslik", size = "l",
        textInput(ns("tb_title"), "Dərslik adı:"),
        selectInput(ns("tb_subject"), "Fənn:", choices = c("Seçin" = "", SUBJECTS)),
        selectInput(ns("tb_grade"), "Sinif:",
          choices = c("Seçin" = "", setNames(1:11, paste0(1:11, "-ci sinif")))),
        textInput(ns("tb_author"), "Müəllif:"),
        textInput(ns("tb_publisher"), "Nəşriyyat:"),
        textInput(ns("tb_isbn"), "ISBN:"),
        numericInput(ns("tb_year"), "Nəşr ili:", value = as.integer(format(Sys.Date(), "%Y")),
                     min = 2000, max = 2030),
        textInput(ns("tb_edition"), "Nəşr:"),
        numericInput(ns("tb_pages"), "Səhifə sayı:", value = 100, min = 1),
        textAreaInput(ns("tb_desc"), "Təsvir:", rows = 3),
        fileInput(ns("tb_file"), "Fayl yüklə:", accept = c(".pdf")),
        footer = tagList(
          modalButton("Ləğv et"),
          actionButton(ns("btn_save_textbook"), "Saxla", class = "btn-primary")
        )
      ))
    })

    observeEvent(input$btn_save_textbook, {
      data <- list(title = input$tb_title, author = input$tb_author, isbn = input$tb_isbn)

      errors <- validate_textbook(data)
      if (length(errors) > 0) {
        notify_error(paste(errors, collapse = "\n"))
        return()
      }

      tryCatch({
        db_execute(db_pool,
          "INSERT INTO textbooks
           (title, subject_id, grade_level, author, publisher, isbn,
            publish_year, edition, page_count, description)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)",
          params = list(
            input$tb_title,
            if (is_empty(input$tb_subject)) NULL else input$tb_subject,
            if (is_empty(input$tb_grade)) NULL else as.integer(input$tb_grade),
            input$tb_author, input$tb_publisher, input$tb_isbn,
            input$tb_year, input$tb_edition, input$tb_pages, input$tb_desc
          ))
        removeModal()
        notify_success("Dərslik əlavə edildi")
      }, error = function(e) {
        log_error("Dərslik əlavə xətası: {e$message}")
        notify_error("Xəta baş verdi")
      })
    })

    # Kataloq ixracı
    output$btn_export_catalog <- downloadHandler(
      filename = function() paste0("derslik_kataloqu_", format(Sys.Date(), "%Y%m%d"), ".xlsx"),
      content = function(file) {
        export_to_excel(textbooks(), file, "Dərsliklər")
      }
    )
  })
}
