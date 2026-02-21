# =============================================
# ARTI-2026: Toplu Data İmport Modulu
# Şagird, müəllim və qiymət toplu yükləməsi
# =============================================

# === Data İmport UI ===
data_import_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(
      column(12, h2(icon("file-import"), "Toplu Data İmport"), hr())
    ),

    tabsetPanel(
      id = ns("import_tabs"),

      # Tab 1: Şagird İmportu
      tabPanel(
        title = icon("user-graduate"), value = "students",
        tags$span("Şagird İmportu"),
        br(), br(),
        fluidRow(
          column(4,
            wellPanel(
              h4("Fayl Yüklə"),
              fileInput(ns("student_file"), "Excel/CSV Faylı:",
                accept = c(".xlsx", ".xls", ".csv"),
                placeholder = "Fayl seçin..."
              ),
              tags$small(class = "text-muted",
                "Qəbul edilən formatlar: .xlsx, .xls, .csv"),
              tags$hr(),
              downloadButton(ns("student_template"), "Nümunə Şablon Yüklə",
                             class = "btn-info btn-block")
            )
          ),
          column(8,
            conditionalPanel(
              condition = paste0("output['", ns("student_preview_ready"), "']"),
              box(
                title = "Önizləmə və Validasiya",
                status = "primary",
                solidHeader = TRUE,
                width = 12,
                uiOutput(ns("student_validation_result")),
                DTOutput(ns("student_preview_table")),
                tags$hr(),
                actionButton(ns("btn_import_students"), "İmport Et",
                             icon = icon("upload"), class = "btn-success btn-lg")
              )
            )
          )
        )
      ),

      # Tab 2: Müəllim İmportu
      tabPanel(
        title = icon("chalkboard-teacher"), value = "teachers",
        tags$span("Müəllim İmportu"),
        br(), br(),
        fluidRow(
          column(4,
            wellPanel(
              h4("Fayl Yüklə"),
              fileInput(ns("teacher_file"), "Excel/CSV Faylı:",
                accept = c(".xlsx", ".xls", ".csv"),
                placeholder = "Fayl seçin..."
              ),
              tags$small(class = "text-muted",
                "Qəbul edilən formatlar: .xlsx, .xls, .csv"),
              tags$hr(),
              downloadButton(ns("teacher_template"), "Nümunə Şablon Yüklə",
                             class = "btn-info btn-block")
            )
          ),
          column(8,
            conditionalPanel(
              condition = paste0("output['", ns("teacher_preview_ready"), "']"),
              box(
                title = "Önizləmə və Validasiya",
                status = "primary",
                solidHeader = TRUE,
                width = 12,
                uiOutput(ns("teacher_validation_result")),
                DTOutput(ns("teacher_preview_table")),
                tags$hr(),
                actionButton(ns("btn_import_teachers"), "İmport Et",
                             icon = icon("upload"), class = "btn-success btn-lg")
              )
            )
          )
        )
      ),

      # Tab 3: Qiymət İmportu
      tabPanel(
        title = icon("star-half-alt"), value = "grades",
        tags$span("Qiymət İmportu"),
        br(), br(),
        fluidRow(
          column(4,
            wellPanel(
              h4("Parametrlər"),
              selectInput(ns("grade_subject"), "Fənn:",
                choices = c("Seçin..." = "")
              ),
              selectInput(ns("grade_class"), "Sinif:",
                choices = c("Hamısı" = "", 1:11)
              ),
              selectInput(ns("grade_semester"), "Yarımil:",
                choices = c("I yarımil" = "1", "II yarımil" = "2")
              ),
              tags$hr(),
              fileInput(ns("grade_file"), "Excel/CSV Faylı:",
                accept = c(".xlsx", ".xls", ".csv"),
                placeholder = "Fayl seçin..."
              ),
              downloadButton(ns("grade_template"), "Nümunə Şablon Yüklə",
                             class = "btn-info btn-block")
            )
          ),
          column(8,
            conditionalPanel(
              condition = paste0("output['", ns("grade_preview_ready"), "']"),
              box(
                title = "Önizləmə və Validasiya",
                status = "primary",
                solidHeader = TRUE,
                width = 12,
                uiOutput(ns("grade_validation_result")),
                DTOutput(ns("grade_preview_table")),
                tags$hr(),
                actionButton(ns("btn_import_grades"), "İmport Et",
                             icon = icon("upload"), class = "btn-success btn-lg")
              )
            )
          )
        )
      )
    )
  )
}

# === Data İmport Server ===
data_import_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # === Köməkçi: Fayl oxu ===
    read_import_file <- function(file_path) {
      ext <- tools::file_ext(file_path)
      tryCatch({
        if (ext %in% c("xlsx", "xls")) {
          openxlsx::read.xlsx(file_path, sheet = 1)
        } else if (ext == "csv") {
          read.csv(file_path, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
        } else {
          NULL
        }
      }, error = function(e) {
        notify_error(paste("Fayl oxuma xətası:", e$message))
        NULL
      })
    }

    # === Validasiya funksiyaları ===

    validate_student_import <- function(df) {
      errors <- c()
      warnings <- c()

      # Lazımi sütunlar
      required_cols <- c("ad", "soyad", "fin", "dogum_tarixi", "sinif")
      missing <- setdiff(required_cols, tolower(names(df)))
      if (length(missing) > 0) {
        errors <- c(errors, paste("Çatışmayan sütunlar:", paste(missing, collapse = ", ")))
        return(list(valid = FALSE, errors = errors, warnings = warnings))
      }

      names(df) <- tolower(names(df))

      # Sətir-sətir validasiya
      for (i in seq_len(nrow(df))) {
        if (is_empty(df$ad[i])) errors <- c(errors, paste0("Sətir ", i, ": Ad boşdur"))
        if (is_empty(df$soyad[i])) errors <- c(errors, paste0("Sətir ", i, ": Soyad boşdur"))

        if (!is_empty(df$fin[i]) && !validate_fin(df$fin[i])) {
          errors <- c(errors, paste0("Sətir ", i, ": FIN kod düzgün deyil (", df$fin[i], ")"))
        }

        if (!is_empty(df$email[i]) && !validate_email(df$email[i])) {
          warnings <- c(warnings, paste0("Sətir ", i, ": E-poçt düzgün deyil"))
        }

        if (!is.na(df$sinif[i])) {
          sinif <- as.integer(df$sinif[i])
          if (is.na(sinif) || sinif < 1 || sinif > 11) {
            errors <- c(errors, paste0("Sətir ", i, ": Sinif 1-11 aralığında olmalıdır"))
          }
        }
      }

      # Dublikat FIN yoxla
      if ("fin" %in% names(df)) {
        fins <- df$fin[!is_empty(df$fin)]
        dup_fins <- fins[duplicated(fins)]
        if (length(dup_fins) > 0) {
          errors <- c(errors, paste("Dublikat FIN kodları:", paste(unique(dup_fins), collapse = ", ")))
        }
      }

      list(
        valid = length(errors) == 0,
        errors = errors,
        warnings = warnings,
        row_count = nrow(df)
      )
    }

    validate_teacher_import <- function(df) {
      errors <- c()
      warnings <- c()

      required_cols <- c("ad", "soyad", "fenn", "email")
      missing <- setdiff(required_cols, tolower(names(df)))
      if (length(missing) > 0) {
        errors <- c(errors, paste("Çatışmayan sütunlar:", paste(missing, collapse = ", ")))
        return(list(valid = FALSE, errors = errors, warnings = warnings))
      }

      names(df) <- tolower(names(df))

      for (i in seq_len(nrow(df))) {
        if (is_empty(df$ad[i])) errors <- c(errors, paste0("Sətir ", i, ": Ad boşdur"))
        if (is_empty(df$soyad[i])) errors <- c(errors, paste0("Sətir ", i, ": Soyad boşdur"))
        if (is_empty(df$fenn[i])) errors <- c(errors, paste0("Sətir ", i, ": Fənn boşdur"))

        if (!is_empty(df$email[i]) && !validate_email(df$email[i])) {
          errors <- c(errors, paste0("Sətir ", i, ": E-poçt düzgün deyil"))
        }

        if ("telefon" %in% names(df) && !is_empty(df$telefon[i])) {
          if (!validate_phone_az(df$telefon[i])) {
            warnings <- c(warnings, paste0("Sətir ", i, ": Telefon formatı düzgün deyil"))
          }
        }
      }

      list(valid = length(errors) == 0, errors = errors,
           warnings = warnings, row_count = nrow(df))
    }

    validate_grades_import <- function(df, subject_id) {
      errors <- c()
      warnings <- c()

      required_cols <- c("sagird_kodu", "bal")
      missing <- setdiff(required_cols, tolower(names(df)))
      if (length(missing) > 0) {
        errors <- c(errors, paste("Çatışmayan sütunlar:", paste(missing, collapse = ", ")))
        return(list(valid = FALSE, errors = errors, warnings = warnings))
      }

      if (is_empty(subject_id)) {
        errors <- c(errors, "Fənn seçilməyib")
        return(list(valid = FALSE, errors = errors, warnings = warnings))
      }

      names(df) <- tolower(names(df))

      for (i in seq_len(nrow(df))) {
        if (is_empty(df$sagird_kodu[i])) {
          errors <- c(errors, paste0("Sətir ", i, ": Şagird kodu boşdur"))
        }

        bal <- as.numeric(df$bal[i])
        if (is.na(bal) || bal < 0 || bal > 100) {
          errors <- c(errors, paste0("Sətir ", i, ": Bal 0-100 aralığında olmalıdır"))
        }
      }

      list(valid = length(errors) == 0, errors = errors,
           warnings = warnings, row_count = nrow(df))
    }

    # === Validasiya nəticəsi UI ===
    render_validation_result <- function(result) {
      if (is.null(result)) return(NULL)

      tags$div(
        if (result$valid) {
          tags$div(class = "alert alert-success",
            icon("check-circle"),
            paste0(" Validasiya uğurlu! ", result$row_count, " sətir hazırdır."),
            if (length(result$warnings) > 0) {
              tags$div(
                tags$br(),
                tags$strong("Xəbərdarlıqlar:"),
                tags$ul(lapply(result$warnings[1:min(5, length(result$warnings))], tags$li))
              )
            }
          )
        } else {
          tags$div(class = "alert alert-danger",
            icon("exclamation-triangle"),
            paste0(" Validasiya uğursuz! ", length(result$errors), " xəta tapıldı."),
            tags$ul(lapply(result$errors[1:min(10, length(result$errors))], tags$li)),
            if (length(result$errors) > 10) {
              tags$p(tags$em(paste0("... və daha ", length(result$errors) - 10, " xəta")))
            }
          )
        }
      )
    }

    # === Şagird İmportu ===

    student_data <- reactiveVal(NULL)
    student_validation <- reactiveVal(NULL)

    output$student_preview_ready <- reactive({ !is.null(student_data()) })
    outputOptions(output, "student_preview_ready", suspendWhenHidden = FALSE)

    observeEvent(input$student_file, {
      req(input$student_file)
      df <- read_import_file(input$student_file$datapath)
      if (!is.null(df)) {
        student_data(df)
        result <- validate_student_import(df)
        student_validation(result)
      }
    })

    output$student_validation_result <- renderUI({
      render_validation_result(student_validation())
    })

    output$student_preview_table <- renderDT({
      req(student_data())
      datatable(head(student_data(), 20),
        options = list(pageLength = 10, scrollX = TRUE, dom = "t"),
        rownames = FALSE,
        caption = paste("Önizləmə (ilk 20 sətir,", nrow(student_data()), "ümumi)")
      )
    })

    observeEvent(input$btn_import_students, {
      req(student_data())
      validation <- student_validation()
      if (is.null(validation) || !validation$valid) {
        notify_error("Validasiya xətaları düzəldilməlidir"); return()
      }

      df <- student_data()
      names(df) <- tolower(names(df))
      success <- 0; failed <- 0

      showNotification("İmport edilir...", type = "message", duration = NULL, id = "import_progress")

      for (i in seq_len(nrow(df))) {
        tryCatch({
          # Dublikat FIN yoxla
          existing <- db_get_one(db_pool,
            "SELECT id FROM students WHERE fin_code = $1",
            params = list(toupper(df$fin[i]))
          )
          if (!is.null(existing)) {
            failed <- failed + 1
            next
          }

          db_execute(db_pool,
            "INSERT INTO students (id, first_name, last_name, fin_code, birth_date, grade_level, created_at)
             VALUES (gen_random_uuid(), $1, $2, $3, $4, $5, NOW())",
            params = list(
              trimws(df$ad[i]), trimws(df$soyad[i]),
              toupper(df$fin[i]), as.character(df$dogum_tarixi[i]),
              as.integer(df$sinif[i])
            )
          )
          success <- success + 1
        }, error = function(e) {
          failed <<- failed + 1
        })
      }

      removeNotification("import_progress")
      log_audit(db_pool, user_data()$id, "student_import",
                details = list(total = nrow(df), success = success, failed = failed))
      notify_success(paste0("İmport tamamlandı: ", success, " uğurlu, ", failed, " uğursuz"))
      student_data(NULL)
      student_validation(NULL)
    })

    # Şagird şablonu
    output$student_template <- downloadHandler(
      filename = function() "sagird_import_sablon.xlsx",
      content = function(file) {
        template <- data.frame(
          ad = c("Əli", "Fatimə"),
          soyad = c("Həsənov", "Məmmədova"),
          fin = c("ABC1234", "DEF5678"),
          dogum_tarixi = c("2010-05-15", "2011-03-22"),
          sinif = c(5, 4),
          email = c("ali@example.com", "fatime@example.com"),
          telefon = c("+994501234567", "+994551234567"),
          stringsAsFactors = FALSE
        )
        export_to_excel(template, file, "Şagirdlər")
      }
    )

    # === Müəllim İmportu ===

    teacher_data <- reactiveVal(NULL)
    teacher_validation <- reactiveVal(NULL)

    output$teacher_preview_ready <- reactive({ !is.null(teacher_data()) })
    outputOptions(output, "teacher_preview_ready", suspendWhenHidden = FALSE)

    observeEvent(input$teacher_file, {
      req(input$teacher_file)
      df <- read_import_file(input$teacher_file$datapath)
      if (!is.null(df)) {
        teacher_data(df)
        result <- validate_teacher_import(df)
        teacher_validation(result)
      }
    })

    output$teacher_validation_result <- renderUI({
      render_validation_result(teacher_validation())
    })

    output$teacher_preview_table <- renderDT({
      req(teacher_data())
      datatable(head(teacher_data(), 20),
        options = list(pageLength = 10, scrollX = TRUE, dom = "t"),
        rownames = FALSE,
        caption = paste("Önizləmə (ilk 20 sətir,", nrow(teacher_data()), "ümumi)")
      )
    })

    observeEvent(input$btn_import_teachers, {
      req(teacher_data())
      validation <- teacher_validation()
      if (is.null(validation) || !validation$valid) {
        notify_error("Validasiya xətaları düzəldilməlidir"); return()
      }

      df <- teacher_data()
      names(df) <- tolower(names(df))
      success <- 0; failed <- 0

      showNotification("İmport edilir...", type = "message", duration = NULL, id = "import_progress")

      for (i in seq_len(nrow(df))) {
        tryCatch({
          # İstifadəçi yarat
          username <- tolower(paste0(df$ad[i], ".", df$soyad[i]))
          username <- gsub("[^a-z.]", "", username)

          user_result <- create_user(db_pool,
            full_name = paste(df$ad[i], df$soyad[i]),
            email = df$email[i],
            username = username,
            password = paste0("Temp", sample(1000:9999, 1), "!"),
            role = "teacher"
          )

          if (user_result$success) {
            db_execute(db_pool,
              "INSERT INTO teachers (id, user_id, subject, phone, created_at)
               VALUES (gen_random_uuid(), $1, $2, $3, NOW())",
              params = list(
                user_result$user_id, trimws(df$fenn[i]),
                if ("telefon" %in% names(df)) df$telefon[i] else NULL
              )
            )
            success <- success + 1
          } else {
            failed <- failed + 1
          }
        }, error = function(e) {
          failed <<- failed + 1
        })
      }

      removeNotification("import_progress")
      log_audit(db_pool, user_data()$id, "teacher_import",
                details = list(total = nrow(df), success = success, failed = failed))
      notify_success(paste0("İmport tamamlandı: ", success, " uğurlu, ", failed, " uğursuz"))
      teacher_data(NULL)
      teacher_validation(NULL)
    })

    # Müəllim şablonu
    output$teacher_template <- downloadHandler(
      filename = function() "muellim_import_sablon.xlsx",
      content = function(file) {
        template <- data.frame(
          ad = c("Kamran", "Aynur"),
          soyad = c("Əliyev", "Hüseynova"),
          fenn = c("Riyaziyyat", "Fizika"),
          email = c("kamran@example.com", "aynur@example.com"),
          telefon = c("+994501234567", "+994551234567"),
          stringsAsFactors = FALSE
        )
        export_to_excel(template, file, "Müəllimlər")
      }
    )

    # === Qiymət İmportu ===

    # Fənn siyahısını doldur
    observe({
      subjects <- db_query(db_pool, "SELECT id, name FROM subjects ORDER BY name")
      if (nrow(subjects) > 0) {
        choices <- setNames(subjects$id, subjects$name)
        updateSelectInput(session, "grade_subject", choices = c("Seçin..." = "", choices))
      }
    }) |> bindEvent(TRUE, once = TRUE)

    grade_data <- reactiveVal(NULL)
    grade_validation <- reactiveVal(NULL)

    output$grade_preview_ready <- reactive({ !is.null(grade_data()) })
    outputOptions(output, "grade_preview_ready", suspendWhenHidden = FALSE)

    observeEvent(input$grade_file, {
      req(input$grade_file)
      df <- read_import_file(input$grade_file$datapath)
      if (!is.null(df)) {
        grade_data(df)
        result <- validate_grades_import(df, input$grade_subject)
        grade_validation(result)
      }
    })

    output$grade_validation_result <- renderUI({
      render_validation_result(grade_validation())
    })

    output$grade_preview_table <- renderDT({
      req(grade_data())
      datatable(head(grade_data(), 20),
        options = list(pageLength = 10, scrollX = TRUE, dom = "t"),
        rownames = FALSE,
        caption = paste("Önizləmə (ilk 20 sətir,", nrow(grade_data()), "ümumi)")
      )
    })

    observeEvent(input$btn_import_grades, {
      req(grade_data(), input$grade_subject)
      validation <- grade_validation()
      if (is.null(validation) || !validation$valid) {
        notify_error("Validasiya xətaları düzəldilməlidir"); return()
      }

      df <- grade_data()
      names(df) <- tolower(names(df))
      success <- 0; failed <- 0

      showNotification("Qiymətlər import edilir...", type = "message",
                       duration = NULL, id = "import_progress")

      for (i in seq_len(nrow(df))) {
        tryCatch({
          # Şagird yoxla
          student <- db_get_one(db_pool,
            "SELECT id FROM students WHERE fin_code = $1 OR id::text = $1",
            params = list(df$sagird_kodu[i])
          )
          if (is.null(student)) {
            failed <- failed + 1
            next
          }

          db_execute(db_pool,
            "INSERT INTO grades (id, student_id, subject_id, score, grade_date, academic_year, semester, created_at)
             VALUES (gen_random_uuid(), $1, $2, $3, CURRENT_DATE, $4, $5, NOW())",
            params = list(
              student$id, input$grade_subject,
              as.numeric(df$bal[i]),
              get_academic_year(),
              input$grade_semester
            )
          )
          success <- success + 1
        }, error = function(e) {
          failed <<- failed + 1
        })
      }

      removeNotification("import_progress")
      log_audit(db_pool, user_data()$id, "grade_import",
                details = list(subject_id = input$grade_subject,
                               total = nrow(df), success = success, failed = failed))
      notify_success(paste0("İmport tamamlandı: ", success, " uğurlu, ", failed, " uğursuz"))
      grade_data(NULL)
      grade_validation(NULL)
    })

    # Qiymət şablonu
    output$grade_template <- downloadHandler(
      filename = function() "qiymet_import_sablon.xlsx",
      content = function(file) {
        template <- data.frame(
          sagird_kodu = c("ABC1234", "DEF5678"),
          bal = c(85, 72),
          qeyd = c("Yaxşı nəticə", ""),
          stringsAsFactors = FALSE
        )
        export_to_excel(template, file, "Qiymətlər")
      }
    )
  })
}
