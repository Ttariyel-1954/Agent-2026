# =============================================
# ARTI-2026: Akademik Təqvim Server
# Aylıq grid render, hadisə CRUD
# =============================================

calendar_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Cari ay/il
    current_month <- reactiveVal(as.integer(format(Sys.Date(), "%m")))
    current_year <- reactiveVal(as.integer(format(Sys.Date(), "%Y")))

    # Yeniləmə trigeri
    refresh_trigger <- reactiveVal(0)

    # Ay adları (Azərbaycan)
    month_names <- c("Yanvar", "Fevral", "Mart", "Aprel", "May", "İyun",
                     "İyul", "Avqust", "Sentyabr", "Oktyabr", "Noyabr", "Dekabr")
    day_names <- c("B.e.", "Ç.a.", "Ç.", "C.a.", "C.", "Ş.", "B.")

    # Ay etiketi
    output$current_month_label <- renderText({
      paste(month_names[current_month()], current_year())
    })

    # Navigasiya
    observeEvent(input$btn_prev_month, {
      m <- current_month()
      y <- current_year()
      if (m == 1) { current_month(12); current_year(y - 1) }
      else current_month(m - 1)
    })

    observeEvent(input$btn_next_month, {
      m <- current_month()
      y <- current_year()
      if (m == 12) { current_month(1); current_year(y + 1) }
      else current_month(m + 1)
    })

    observeEvent(input$btn_today, {
      current_month(as.integer(format(Sys.Date(), "%m")))
      current_year(as.integer(format(Sys.Date(), "%Y")))
    })

    # Hadisələr
    events <- reactive({
      refresh_trigger()
      get_calendar_events(db_pool,
        month = current_month(),
        year = current_year(),
        event_type = if (is_empty(input$filter_type)) NULL else input$filter_type,
        school_id = user_data()$school_id
      )
    })

    # === Aylıq Grid Render ===
    output$calendar_grid <- renderUI({
      m <- current_month()
      y <- current_year()

      # Ayın ilk və son günü
      first_day <- as.Date(paste(y, m, 1, sep = "-"))
      days_in_month <- as.integer(format(as.Date(paste(y, m + 1, 1, sep = "-")) - 1, "%d"))
      if (m == 12) days_in_month <- 31

      # Həftənin hansı günü başlayır (1=Bazar ertəsi)
      first_wday <- as.integer(format(first_day, "%u"))

      # Hadisələr
      ev <- events()
      event_map <- list()
      if (nrow(ev) > 0) {
        for (i in seq_len(nrow(ev))) {
          day <- as.integer(format(as.Date(ev$start_date[i]), "%d"))
          key <- as.character(day)
          if (is.null(event_map[[key]])) event_map[[key]] <- list()
          event_map[[key]] <- c(event_map[[key]], list(ev[i, ]))
        }
      }

      today <- Sys.Date()
      today_day <- if (as.integer(format(today, "%m")) == m && as.integer(format(today, "%Y")) == y) {
        as.integer(format(today, "%d"))
      } else NULL

      # Header sətri
      header_cells <- lapply(day_names, function(d) {
        tags$th(style = "text-align:center;padding:8px;background:#2c3e50;color:white;", d)
      })

      # Günlər
      rows <- list()
      day_counter <- 1
      cell_counter <- 1

      for (week in 1:6) {
        if (day_counter > days_in_month) break

        cells <- list()
        for (dow in 1:7) {
          if ((week == 1 && dow < first_wday) || day_counter > days_in_month) {
            cells[[dow]] <- tags$td(
              style = "height:90px;background:#f9f9f9;border:1px solid #ddd;vertical-align:top;padding:4px;",
              ""
            )
          } else {
            day_num <- day_counter
            is_today <- !is.null(today_day) && day_num == today_day
            is_weekend <- dow >= 6

            bg_color <- if (is_today) "#ebf5fb" else if (is_weekend) "#fef9e7" else "white"

            # Bu günün hadisələri
            day_events <- event_map[[as.character(day_num)]]
            event_tags <- if (!is.null(day_events) && length(day_events) > 0) {
              lapply(day_events, function(e) {
                evt_color <- if (!is.null(e$color)) e$color else get_event_type_color(e$event_type)
                tags$div(
                  style = paste0("font-size:10px;padding:1px 4px;margin:1px 0;border-radius:2px;",
                                "color:white;background:", evt_color, ";overflow:hidden;",
                                "white-space:nowrap;text-overflow:ellipsis;cursor:pointer;"),
                  title = paste0(e$title, " (", get_event_type_label(e$event_type), ")"),
                  safe_html(substr(e$title, 1, 15))
                )
              })
            } else {
              list()
            }

            cells[[dow]] <- tags$td(
              style = paste0("height:90px;background:", bg_color,
                            ";border:1px solid #ddd;vertical-align:top;padding:4px;width:14.28%;"),
              tags$div(
                style = paste0("font-weight:", if (is_today) "bold" else "normal",
                              ";color:", if (is_today) "#2980b9" else "#333", ";"),
                day_num
              ),
              tagList(event_tags)
            )

            day_counter <- day_counter + 1
          }
        }
        rows[[week]] <- tags$tr(cells)
      }

      tags$table(
        class = "table",
        style = "table-layout:fixed;width:100%;",
        tags$thead(tags$tr(header_cells)),
        tags$tbody(rows)
      )
    })

    # === Gələcək Hadisələr ===
    output$upcoming_events_list <- renderUI({
      upcoming <- get_upcoming_events(db_pool, days = 14, school_id = user_data()$school_id)

      if (nrow(upcoming) == 0) {
        return(tags$p(class = "text-muted", "Gələcək hadisə yoxdur"))
      }

      tags$div(
        lapply(seq_len(min(10, nrow(upcoming))), function(i) {
          ev <- upcoming[i, ]
          evt_color <- if (!is.null(ev$color)) ev$color else get_event_type_color(ev$event_type)
          tags$div(
            style = "padding:8px 0;border-bottom:1px solid #eee;",
            tags$div(
              tags$span(
                style = paste0("display:inline-block;width:8px;height:8px;border-radius:50%;",
                              "background:", evt_color, ";margin-right:6px;vertical-align:middle;")
              ),
              tags$strong(safe_html(ev$title))
            ),
            tags$small(class = "text-muted",
              format_date_az(ev$start_date),
              if (!is.null(ev$location) && nchar(ev$location) > 0) {
                paste0(" | ", safe_html(ev$location))
              }
            )
          )
        })
      )
    })

    # === Hadisə Cədvəli ===
    output$events_table <- renderDT({
      ev <- events()
      if (nrow(ev) == 0) {
        return(datatable(data.frame(Mesaj = "Bu ayda hadisə yoxdur")))
      }

      display_df <- data.frame(
        Tarix = sapply(ev$start_date, format_date_az),
        Baslik = ev$title,
        Nov = sapply(ev$event_type, get_event_type_label),
        Mekan = ev$location %||% "",
        Fenn = ev$subject_name %||% "",
        stringsAsFactors = FALSE
      )
      names(display_df) <- c("Tarix", "Başlıq", "Növ", "Məkan", "Fənn")

      datatable(display_df,
        selection = "single",
        options = default_dt_options(25),
        rownames = FALSE
      )
    })

    # === Yeni Hadisə Modal ===
    observeEvent(input$btn_add_event, {
      # Fənn siyahısı
      subjects <- db_query(db_pool, "SELECT id, name FROM subjects ORDER BY name")
      subject_choices <- c("Heç biri" = "")
      if (nrow(subjects) > 0) {
        subject_choices <- c(subject_choices, setNames(subjects$id, subjects$name))
      }

      showModal(modalDialog(
        title = "Yeni Hadisə",
        size = "m",
        textInput(ns("event_title"), "Başlıq:", placeholder = "Hadisə adı"),
        selectInput(ns("event_type"), "Növ:",
          choices = c("İmtahan" = "exam", "Tətil" = "holiday", "İclas" = "meeting",
                      "Son Tarix" = "deadline", "Təlim" = "training", "Digər" = "other")
        ),
        fluidRow(
          column(6, dateInput(ns("event_start"), "Başlanğıc Tarixi:",
                              value = Sys.Date(), language = "az")),
          column(6, dateInput(ns("event_end"), "Son Tarix:",
                              value = Sys.Date(), language = "az"))
        ),
        checkboxInput(ns("event_all_day"), "Bütün gün", value = TRUE),
        conditionalPanel(
          condition = paste0("!input['", ns("event_all_day"), "']"),
          fluidRow(
            column(6, textInput(ns("event_start_time"), "Başlama Saatı:", placeholder = "09:00")),
            column(6, textInput(ns("event_end_time"), "Bitmə Saatı:", placeholder = "17:00"))
          )
        ),
        textInput(ns("event_location"), "Məkan:", placeholder = "Otaq/Bina"),
        textAreaInput(ns("event_description"), "Təsvir:", rows = 3),
        selectInput(ns("event_subject"), "Fənn:", choices = subject_choices),
        selectInput(ns("event_grade"), "Sinif:",
          choices = c("Hamısı" = "", 1:11)
        ),
        colourpicker::colourInput(ns("event_color"), "Rəng:", value = "#3498db",
                                  showColour = "background"),
        footer = tagList(
          modalButton("Ləğv et"),
          actionButton(ns("btn_save_event"), "Yadda Saxla",
                       class = "btn-success", icon = icon("save"))
        )
      ))
    })

    # Hadisəni saxla
    observeEvent(input$btn_save_event, {
      if (is_empty(input$event_title)) {
        notify_error("Başlıq daxil edin"); return()
      }

      result <- create_event(db_pool,
        title = input$event_title,
        event_type = input$event_type,
        start_date = input$event_start,
        end_date = input$event_end,
        start_time = if (!input$event_all_day && !is_empty(input$event_start_time)) input$event_start_time else NULL,
        end_time = if (!input$event_all_day && !is_empty(input$event_end_time)) input$event_end_time else NULL,
        is_all_day = input$event_all_day,
        description = input$event_description,
        location = input$event_location,
        subject_id = if (is_empty(input$event_subject)) NULL else input$event_subject,
        grade_level = if (is_empty(input$event_grade)) NULL else as.integer(input$event_grade),
        created_by = user_data()$id,
        school_id = user_data()$school_id,
        color = input$event_color
      )

      if (result$success) {
        log_audit(db_pool, user_data()$id, "event_create",
                  entity_type = "calendar_event", entity_id = result$event_id,
                  details = list(title = input$event_title, type = input$event_type))
        notify_success("Hadisə yaradıldı")
        removeModal()
        refresh_trigger(refresh_trigger() + 1)
      } else {
        notify_error(result$error %||% "Hadisə yaradıla bilmədi")
      }
    })

    # Hadisə seçimi — silmə/redaktə
    observeEvent(input$events_table_rows_selected, {
      row <- input$events_table_rows_selected
      if (is.null(row)) return()

      ev <- events()
      event <- ev[row, ]

      showModal(modalDialog(
        title = paste("Hadisə:", safe_html(event$title)),
        size = "m",
        tags$div(
          tags$p(tags$strong("Növ: "), get_event_type_label(event$event_type)),
          tags$p(tags$strong("Tarix: "), format_date_az(event$start_date),
                 if (!is.null(event$end_date) && event$end_date != event$start_date) {
                   paste(" -", format_date_az(event$end_date))
                 }),
          if (!is.null(event$location) && nchar(event$location) > 0) {
            tags$p(tags$strong("Məkan: "), safe_html(event$location))
          },
          if (!is.null(event$description) && nchar(event$description) > 0) {
            tags$p(tags$strong("Təsvir: "), safe_html(event$description))
          }
        ),
        footer = tagList(
          modalButton("Bağla"),
          actionButton(ns("btn_delete_event"), "Sil",
                       class = "btn-danger", icon = icon("trash"))
        )
      ))
    })

    # Seçilmiş hadisə ID-si
    selected_event_id <- reactive({
      row <- input$events_table_rows_selected
      if (is.null(row)) return(NULL)
      events()[row, "id"]
    })

    # Hadisə sil
    observeEvent(input$btn_delete_event, {
      eid <- selected_event_id()
      if (is.null(eid)) return()

      result <- delete_event(db_pool, eid)
      if (result$success) {
        log_audit(db_pool, user_data()$id, "event_delete",
                  entity_type = "calendar_event", entity_id = eid)
        notify_success("Hadisə silindi")
        removeModal()
        refresh_trigger(refresh_trigger() + 1)
      } else {
        notify_error("Hadisə silinə bilmədi")
      }
    })

    # === İxrac ===
    output$btn_export <- downloadHandler(
      filename = function() {
        paste0("teqvim_", month_names[current_month()], "_", current_year(), ".xlsx")
      },
      content = function(file) {
        ev <- events()
        if (nrow(ev) > 0) {
          export_df <- data.frame(
            Tarix = sapply(ev$start_date, format_date_az),
            Baslik = ev$title,
            Nov = sapply(ev$event_type, get_event_type_label),
            Mekan = ev$location %||% "",
            Tesvir = ev$description %||% "",
            stringsAsFactors = FALSE
          )
          names(export_df) <- c("Tarix", "Başlıq", "Növ", "Məkan", "Təsvir")
          export_to_excel(export_df, file, "Təqvim")
        } else {
          export_to_excel(data.frame(Mesaj = "Hadisə yoxdur"), file, "Təqvim")
        }
      }
    )
  })
}
