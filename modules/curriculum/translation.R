# =============================================
# ARTI-2026: Tərcümə Modulu
# Kurikulum tərcüməsi, tədqiqat tərcüməsi,
# PISA lokalizasiya, terminologiya, tarixçə
# =============================================

# === Dil seçimləri ===
TRANSLATION_LANGUAGES <- c(
  "İngilis dili" = "en",
  "Azərbaycan dili" = "az",
  "Türk dili" = "tr",
  "Rus dili" = "ru"
)

TRANSLATION_DOMAINS <- c(
  "Kurikulum" = "curriculum",
  "Qiymətləndirmə" = "assessment",
  "PISA" = "pisa",
  "Pedaqogika" = "pedagogy",
  "IRT" = "irt",
  "Ümumi" = "general"
)

PISA_SUBJECTS <- c("Riyaziyyat", "Oxu savadlılığı", "Elm")

RESEARCH_AREAS <- c(
  "Təhsil" = "təhsil",
  "Pedaqogika" = "pedaqogika",
  "Qiymətləndirmə" = "qiymətləndirmə",
  "PISA/TIMSS" = "pisa",
  "IRT/CAT" = "irt",
  "Kurikulum" = "kurikulum"
)

# =============================================
# UI
# =============================================
translation_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(column(12, h2(icon("language"), "AI Tərcümə Modulu"), hr())),

    tabsetPanel(
      id = ns("translation_tabs"),

      # === TAB 1: Kurikulum Standartları ===
      tabPanel(
        title = tagList(icon("book"), "Kurikulum Standartları"),
        value = "tab_curriculum",
        br(),
        fluidRow(
          # Sol panel — parametrlər
          column(4, wellPanel(
            h4("Tərcümə Parametrləri"),
            fluidRow(
              column(6, selectInput(ns("cur_source_lang"), "Mənbə dili:",
                choices = TRANSLATION_LANGUAGES, selected = "en")),
              column(6, selectInput(ns("cur_target_lang"), "Hədəf dili:",
                choices = TRANSLATION_LANGUAGES, selected = "az"))
            ),
            selectInput(ns("cur_subject"), "Fənn:", choices = c("Seçin..." = "", SUBJECTS)),
            selectInput(ns("cur_grade"), "Sinif:",
              choices = c("Seçin..." = "", setNames(1:11, paste0(1:11, "-ci sinif")))),
            selectInput(ns("cur_bloom"), "Bloom səviyyəsi:",
              choices = c("Seçin..." = "",
                "Remembering" = "Remembering", "Understanding" = "Understanding",
                "Applying" = "Applying", "Analyzing" = "Analyzing",
                "Evaluating" = "Evaluating", "Creating" = "Creating")),
            selectInput(ns("cur_dok"), "DOK səviyyəsi:",
              choices = c("Seçin..." = "", "1" = "1", "2" = "2", "3" = "3", "4" = "4")),
            textAreaInput(ns("cur_text"), "Standart mətni:", rows = 5, width = "100%",
              placeholder = "Tərcümə ediləcək kurikulum standart mətnini daxil edin..."),
            fluidRow(
              column(6, actionButton(ns("btn_cur_translate"), "Tərcümə Et",
                icon = icon("language"), class = "btn-success btn-block")),
              column(6, actionButton(ns("btn_cur_load_db"), "DB-dən Yüklə",
                icon = icon("database"), class = "btn-info btn-block"))
            )
          )),

          # Sağ panel — nəticə
          column(8,
            wellPanel(
              h4("Tərcümə Nəticəsi"),
              uiOutput(ns("cur_result_ui"))
            ),
            wellPanel(
              h4("İstifadə Edilən Terminlər"),
              DTOutput(ns("cur_terms_table"))
            ),
            # Toplu tərcümə
            wellPanel(
              h4(icon("layer-group"), "Toplu Tərcümə"),
              fluidRow(
                column(4, selectInput(ns("batch_subject"), "Fənn:", choices = c("Seçin..." = "", SUBJECTS))),
                column(4, selectInput(ns("batch_grade"), "Sinif:",
                  choices = c("Seçin..." = "", setNames(1:11, paste0(1:11, "-ci sinif"))))),
                column(4, actionButton(ns("btn_batch_cur_translate"), "Toplu Tərcümə",
                  icon = icon("play"), class = "btn-warning", style = "margin-top:25px"))
              ),
              DTOutput(ns("batch_results_table"))
            )
          )
        )
      ),

      # === TAB 2: Tədqiqat Tərcüməsi ===
      tabPanel(
        title = tagList(icon("flask"), "Tədqiqat Tərcüməsi"),
        value = "tab_research",
        br(),
        fluidRow(
          # Sol panel
          column(6, wellPanel(
            h4("Tədqiqat Mətni"),
            fluidRow(
              column(6, selectInput(ns("res_source_lang"), "Mənbə dili:",
                choices = TRANSLATION_LANGUAGES, selected = "en")),
              column(6, selectInput(ns("res_area"), "Tədqiqat sahəsi:", choices = RESEARCH_AREAS))
            ),
            textAreaInput(ns("res_text"), "Tədqiqat mətni:", rows = 12, width = "100%",
              placeholder = "Tərcümə ediləcək tədqiqat mətnini yapışdırın..."),
            actionButton(ns("btn_res_translate"), "Tərcümə Et",
              icon = icon("language"), class = "btn-success btn-block")
          )),
          # Sağ panel
          column(6,
            wellPanel(
              h4("Tərcümə Nəticəsi"),
              uiOutput(ns("res_result_ui"))
            ),
            wellPanel(
              h4("Açar Terminlər"),
              DTOutput(ns("res_terms_table")),
              br(),
              actionButton(ns("btn_res_add_terms"), "Terminləri Lüğətə Əlavə Et",
                icon = icon("plus"), class = "btn-info")
            )
          )
        )
      ),

      # === TAB 3: PISA Lokalizasiya ===
      tabPanel(
        title = tagList(icon("globe-americas"), "PISA Lokalizasiya"),
        value = "tab_pisa",
        br(),
        fluidRow(
          # Sol panel
          column(6, wellPanel(
            h4("PISA Sual Məlumatları"),
            fluidRow(
              column(6, selectInput(ns("pisa_subject"), "PISA fənni:", choices = PISA_SUBJECTS)),
              column(6, selectInput(ns("pisa_grade"), "Sinif:",
                choices = setNames(1:11, paste0(1:11, "-ci sinif")), selected = "8"))
            ),
            textAreaInput(ns("pisa_text"), "Sual mətni:", rows = 6, width = "100%",
              placeholder = "PISA sualının ingilis mətni..."),
            fluidRow(
              column(6, textInput(ns("pisa_opt_a"), "A variantı:", placeholder = "Variant A")),
              column(6, textInput(ns("pisa_opt_b"), "B variantı:", placeholder = "Variant B"))
            ),
            fluidRow(
              column(6, textInput(ns("pisa_opt_c"), "C variantı:", placeholder = "Variant C")),
              column(6, textInput(ns("pisa_opt_d"), "D variantı:", placeholder = "Variant D"))
            ),
            selectInput(ns("pisa_correct"), "Düzgün cavab:", choices = c("A", "B", "C", "D")),
            actionButton(ns("btn_pisa_localize"), "Lokalizasiya Et",
              icon = icon("globe"), class = "btn-success btn-block")
          )),
          # Sağ panel
          column(6,
            wellPanel(
              h4("Lokalizasiya Nəticəsi"),
              uiOutput(ns("pisa_result_ui"))
            ),
            wellPanel(
              h4("Adaptasiya Qeydləri"),
              uiOutput(ns("pisa_notes_ui")),
              br(),
              actionButton(ns("btn_pisa_save_item"), "Sual Bankına Əlavə Et",
                icon = icon("save"), class = "btn-info")
            )
          )
        )
      ),

      # === TAB 4: Terminologiya ===
      tabPanel(
        title = tagList(icon("book-open"), "Terminologiya"),
        value = "tab_terminology",
        br(),
        fluidRow(
          # Sol panel — filtrlər və forma
          column(4,
            wellPanel(
              h4("Filtrlər"),
              selectInput(ns("term_domain"), "Sahə:",
                choices = c("Hamısı" = "", TRANSLATION_DOMAINS)),
              fluidRow(
                column(6, selectInput(ns("term_source_lang"), "Mənbə:", choices = TRANSLATION_LANGUAGES, selected = "en")),
                column(6, selectInput(ns("term_target_lang"), "Hədəf:", choices = TRANSLATION_LANGUAGES, selected = "az"))
              ),
              selectInput(ns("term_status"), "Status:",
                choices = c("Hamısı" = "", "Təsdiqlənmiş" = "verified", "Təsdiqlənməmiş" = "unverified")),
              textInput(ns("term_search"), "Axtar:", placeholder = "Termin axtar...")
            ),
            wellPanel(
              h4("Yeni Termin Əlavə Et"),
              textInput(ns("term_new_source"), "Mənbə termin:", placeholder = "assessment"),
              textInput(ns("term_new_target"), "Hədəf termin:", placeholder = "qiymətləndirmə"),
              selectInput(ns("term_new_domain"), "Sahə:", choices = TRANSLATION_DOMAINS),
              selectInput(ns("term_new_subject"), "Fənn:", choices = c("Ümumi" = "", SUBJECTS)),
              sliderInput(ns("term_new_confidence"), "Etibarlılıq:", min = 0, max = 1, value = 0.9, step = 0.05),
              textAreaInput(ns("term_new_notes"), "Qeydlər:", rows = 2),
              actionButton(ns("btn_term_add"), "Əlavə Et", icon = icon("plus"), class = "btn-success btn-block")
            )
          ),
          # Sağ panel — cədvəl
          column(8, wellPanel(
            h4("Terminologiya Lüğəti"),
            DTOutput(ns("term_table")),
            br(),
            fluidRow(
              column(3, actionButton(ns("btn_term_edit"), "Redaktə", icon = icon("edit"), class = "btn-primary btn-block")),
              column(3, actionButton(ns("btn_term_delete"), "Sil", icon = icon("trash"), class = "btn-danger btn-block")),
              column(3, actionButton(ns("btn_term_verify"), "Təsdiq", icon = icon("check"), class = "btn-success btn-block")),
              column(3, downloadButton(ns("btn_term_export"), "İxrac", class = "btn-info btn-block"))
            )
          ))
        )
      ),

      # === TAB 5: Tarixçə ===
      tabPanel(
        title = tagList(icon("history"), "Tarixçə"),
        value = "tab_history",
        br(),
        fluidRow(
          column(3, selectInput(ns("hist_type"), "Tərcümə növü:",
            choices = c("Hamısı" = "", "Kurikulum" = "curriculum", "Tədqiqat" = "research",
                        "PISA" = "pisa", "Ümumi" = "general"))),
          column(3, selectInput(ns("hist_status"), "Status:",
            choices = c("Hamısı" = "", "Təsdiqlənmiş" = "verified", "Təsdiqlənməmiş" = "unverified"))),
          column(3, dateInput(ns("hist_from"), "Başlanğıc:", value = Sys.Date() - 30)),
          column(3, dateInput(ns("hist_to"), "Son:", value = Sys.Date()))
        ),
        fluidRow(
          valueBoxOutput(ns("hist_total_box"), width = 3),
          valueBoxOutput(ns("hist_verified_box"), width = 3),
          valueBoxOutput(ns("hist_tokens_box"), width = 3),
          valueBoxOutput(ns("hist_quality_box"), width = 3)
        ),
        fluidRow(
          column(12, wellPanel(
            h4("Tərcümə Tarixçəsi"),
            DTOutput(ns("hist_table"))
          ))
        )
      )
    )
  )
}

# =============================================
# SERVER
# =============================================
translation_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Reaktiv dəyərlər
    cur_translation_result <- reactiveVal(NULL)
    res_translation_result <- reactiveVal(NULL)
    pisa_localization_result <- reactiveVal(NULL)

    # =============================================
    # TAB 1: Kurikulum Standartları
    # =============================================

    # Tərcümə et
    observeEvent(input$btn_cur_translate, {
      req(input$cur_text)

      withProgress(message = "Kurikulum standartı tərcümə edilir...", value = 0.3, {
        result <- tryCatch(
          translate_curriculum_standard(
            standard_text = input$cur_text,
            subject = input$cur_subject,
            grade = input$cur_grade,
            source_lang = input$cur_source_lang,
            target_lang = input$cur_target_lang,
            bloom_level = if (is_empty(input$cur_bloom)) NULL else input$cur_bloom,
            dok_level = if (is_empty(input$cur_dok)) NULL else input$cur_dok,
            db_pool = db_pool,
            user_id = user_data()$id
          ),
          error = function(e) list(success = FALSE, message = e$message)
        )
        setProgress(value = 1)
      })

      cur_translation_result(result)

      if (result$success) {
        notify_success("Tərcümə uğurla tamamlandı!")
      } else {
        notify_error(paste("Tərcümə xətası:", result$message))
      }
    })

    # Kurikulum nəticə UI
    output$cur_result_ui <- renderUI({
      result <- cur_translation_result()
      if (is.null(result)) {
        return(tags$div(style = "text-align:center; color:#999; padding:40px;",
          icon("language", style = "font-size:2.5em;"), tags$br(), tags$br(),
          tags$p("Standart mətnini daxil edib 'Tərcümə Et' düyməsini basın")))
      }

      if (!result$success) {
        return(tags$div(class = "alert alert-danger", icon("exclamation-triangle"), " ", result$message))
      }

      tags$div(
        tags$div(style = "border-left:4px solid #27ae60; padding:12px; background:#f0fff4; border-radius:4px;",
          tags$p(style = "font-size:1.05em;", result$translated_text)
        ),
        if (!is_empty(result$bloom_az)) tags$div(style = "margin-top:8px;",
          tags$span(class = "label label-info", paste("Bloom (AZ):", result$bloom_az)),
          if (!is.null(result$dok_level))
            tags$span(class = "label label-warning", style = "margin-left:5px;",
              paste("DOK:", result$dok_level))
        ),
        if (!is_empty(result$notes)) tags$div(style = "margin-top:8px; font-size:0.85em; color:#888;",
          tags$em(result$notes)),
        tags$div(style = "margin-top:10px;",
          actionButton(ns("btn_cur_verify"), "Təsdiq Et", icon = icon("check"), class = "btn-success btn-sm"),
          actionButton(ns("btn_cur_reject"), "Rədd Et", icon = icon("times"), class = "btn-danger btn-sm",
            style = "margin-left:5px;")
        )
      )
    })

    # Təsdiq/Rədd
    observeEvent(input$btn_cur_verify, {
      result <- cur_translation_result()
      if (!is.null(result) && !is.null(result$history_id)) {
        db_execute(db_pool,
          "UPDATE translation_history SET is_verified = TRUE, verified_by = $1, verified_at = NOW()
           WHERE id = $2",
          params = list(user_data()$id, result$history_id))
        notify_success("Tərcümə təsdiqləndi!")
      }
    })

    observeEvent(input$btn_cur_reject, {
      result <- cur_translation_result()
      if (!is.null(result) && !is.null(result$history_id)) {
        db_execute(db_pool,
          "UPDATE translation_history SET is_verified = FALSE, reviewer_notes = 'Rədd edildi',
           verified_by = $1, verified_at = NOW() WHERE id = $2",
          params = list(user_data()$id, result$history_id))
        notify_warning("Tərcümə rədd edildi")
      }
    })

    # İstifadə edilən terminlər
    output$cur_terms_table <- renderDT({
      result <- cur_translation_result()
      if (is.null(result) || !result$success) {
        return(datatable(data.frame("Termin" = character(0), "Tərcümə" = character(0)),
          options = list(dom = "t", language = list(emptyTable = "Tərcümə nəticəsi gözlənilir"))))
      }
      terms <- result$terms_used
      if (is.data.frame(terms) && nrow(terms) > 0) {
        names(terms) <- c("Mənbə", "Hədəf")
        datatable(terms, selection = "none", options = list(dom = "t", pageLength = 20))
      } else if (is.list(terms) && length(terms) > 0) {
        df <- tryCatch(
          as.data.frame(do.call(rbind, lapply(terms, function(t) {
            data.frame(source = t$source %||% "", target = t$target %||% "",
                       stringsAsFactors = FALSE)
          })), stringsAsFactors = FALSE),
          error = function(e) data.frame()
        )
        if (nrow(df) > 0) {
          names(df) <- c("Mənbə", "Hədəf")
          datatable(df, selection = "none", options = list(dom = "t", pageLength = 20))
        } else {
          datatable(data.frame("Termin" = "Termin tapılmadı"), options = list(dom = "t"))
        }
      } else {
        datatable(data.frame("Termin" = "Termin tapılmadı"), options = list(dom = "t"))
      }
    })

    # DB-dən standart yüklə
    observeEvent(input$btn_cur_load_db, {
      showModal(modalDialog(
        title = "Kurikulum Standartını Seçin",
        size = "l",
        fluidRow(
          column(6, selectInput(ns("load_subject"), "Fənn:", choices = c("Hamısı" = "", SUBJECTS))),
          column(6, selectInput(ns("load_grade"), "Sinif:",
            choices = c("Hamısı" = "", setNames(1:11, paste0(1:11, "-ci sinif")))))
        ),
        DTOutput(ns("load_standards_table")),
        footer = tagList(
          actionButton(ns("btn_load_select"), "Seç", class = "btn-primary"),
          modalButton("Ləğv")
        )
      ))
    })

    output$load_standards_table <- renderDT({
      query <- "SELECT cs.code, s.name as subject_name, cs.grade, cs.description, cs.bloom_level
                FROM curriculum_standards cs
                LEFT JOIN subjects s ON cs.subject_id = s.id WHERE 1=1"
      params <- list(); idx <- 1
      if (!is_empty(input$load_subject)) {
        query <- paste0(query, " AND s.name = $", idx); params[[idx]] <- input$load_subject; idx <- idx + 1
      }
      if (!is_empty(input$load_grade)) {
        query <- paste0(query, " AND cs.grade = $", idx); params[[idx]] <- as.integer(input$load_grade)
      }
      query <- paste0(query, " ORDER BY cs.code LIMIT 100")
      data <- if (length(params) > 0) db_query(db_pool, query, params = params) else db_query(db_pool, query)
      if (nrow(data) == 0) return(datatable(data.frame()))
      names(data) <- c("Kod", "Fənn", "Sinif", "Təsvir", "Bloom")
      datatable(data, selection = "single", options = list(pageLength = 10,
        language = list(search = "Axtar:", emptyTable = "Standart tapılmadı")))
    })

    observeEvent(input$btn_load_select, {
      sel <- input$load_standards_table_rows_selected
      if (is.null(sel) || length(sel) == 0) {
        notify_warning("Standart seçin")
        return()
      }
      query <- "SELECT cs.description, s.name, cs.grade, cs.bloom_level
                FROM curriculum_standards cs
                LEFT JOIN subjects s ON cs.subject_id = s.id
                ORDER BY cs.code LIMIT 100"
      data <- db_query(db_pool, query)
      if (nrow(data) > 0 && sel <= nrow(data)) {
        row <- data[sel, ]
        updateTextAreaInput(session, "cur_text", value = row$description)
        updateSelectInput(session, "cur_subject", selected = row$name)
        updateSelectInput(session, "cur_grade", selected = as.character(row$grade))
        if (!is.null(row$bloom_level) && !is.na(row$bloom_level)) {
          updateSelectInput(session, "cur_bloom", selected = row$bloom_level)
        }
        removeModal()
        notify_success("Standart yükləndi!")
      }
    })

    # Toplu tərcümə
    observeEvent(input$btn_batch_cur_translate, {
      req(input$batch_subject, input$batch_grade)

      standards <- db_query(db_pool,
        "SELECT cs.description FROM curriculum_standards cs
         JOIN subjects s ON cs.subject_id = s.id
         WHERE s.name = $1 AND cs.grade = $2 ORDER BY cs.code",
        params = list(input$batch_subject, as.integer(input$batch_grade))
      )

      if (nrow(standards) == 0) {
        notify_warning("Bu fənn və sinif üçün standart tapılmadı")
        return()
      }

      withProgress(message = "Toplu tərcümə aparılır...", value = 0, {
        results <- batch_translate(
          texts = standards$description,
          source_lang = "az",
          target_lang = "en",
          domain = "curriculum",
          db_pool = db_pool,
          user_id = user_data()$id,
          progress_callback = function(value, message) setProgress(value = value, message = message)
        )
      })

      notify_success(paste(length(results), "standart tərcümə edildi"))
    })

    output$batch_results_table <- renderDT({
      datatable(data.frame("Status" = "Toplu tərcümə üçün fənn və sinif seçin"),
        options = list(dom = "t"))
    })

    # =============================================
    # TAB 2: Tədqiqat Tərcüməsi
    # =============================================
    observeEvent(input$btn_res_translate, {
      req(input$res_text)

      withProgress(message = "Tədqiqat mətni tərcümə edilir...", value = 0.3, {
        result <- tryCatch(
          translate_research_text(
            text = input$res_text,
            subject_area = input$res_area,
            source_lang = input$res_source_lang,
            db_pool = db_pool,
            user_id = user_data()$id
          ),
          error = function(e) list(success = FALSE, message = e$message)
        )
        setProgress(value = 1)
      })

      res_translation_result(result)

      if (result$success) {
        notify_success("Tədqiqat mətni tərcümə edildi!")
      } else {
        notify_error(paste("Tərcümə xətası:", result$message))
      }
    })

    output$res_result_ui <- renderUI({
      result <- res_translation_result()
      if (is.null(result)) {
        return(tags$div(style = "text-align:center; color:#999; padding:40px;",
          icon("flask", style = "font-size:2.5em;"), tags$br(), tags$br(),
          tags$p("Tədqiqat mətnini daxil edib 'Tərcümə Et' düyməsini basın")))
      }
      if (!result$success) {
        return(tags$div(class = "alert alert-danger", icon("exclamation-triangle"), " ", result$message))
      }
      tags$div(
        tags$div(style = "border-left:4px solid #3498db; padding:12px; background:#f0f7ff; border-radius:4px;
                          max-height:400px; overflow-y:auto; white-space:pre-wrap;",
          result$translated_text
        ),
        if (!is_empty(result$notes)) tags$div(style = "margin-top:8px; font-size:0.85em; color:#888;",
          tags$em(result$notes))
      )
    })

    output$res_terms_table <- renderDT({
      result <- res_translation_result()
      if (is.null(result) || !result$success) {
        return(datatable(data.frame("Termin" = character(0)),
          options = list(dom = "t", language = list(emptyTable = "Tərcümə nəticəsi gözlənilir"))))
      }
      terms <- result$key_terms
      if (is.data.frame(terms) && nrow(terms) > 0) {
        datatable(terms, selection = "multiple", options = list(dom = "t", pageLength = 20))
      } else if (is.list(terms) && length(terms) > 0) {
        df <- tryCatch(
          as.data.frame(do.call(rbind, lapply(terms, function(t) {
            data.frame(source = t$source %||% "", target = t$target %||% "",
                       domain = t$domain %||% "general", stringsAsFactors = FALSE)
          })), stringsAsFactors = FALSE),
          error = function(e) data.frame()
        )
        if (nrow(df) > 0) {
          names(df) <- c("Mənbə", "Hədəf", "Sahə")
          datatable(df, selection = "multiple", options = list(dom = "t", pageLength = 20))
        } else {
          datatable(data.frame("Termin" = "Termin tapılmadı"), options = list(dom = "t"))
        }
      } else {
        datatable(data.frame("Termin" = "Termin tapılmadı"), options = list(dom = "t"))
      }
    })

    # Terminləri lüğətə əlavə et
    observeEvent(input$btn_res_add_terms, {
      result <- res_translation_result()
      if (is.null(result) || !result$success) {
        notify_warning("Əvvəlcə tərcümə aparın")
        return()
      }

      terms <- result$key_terms
      added <- 0

      if (is.data.frame(terms) && nrow(terms) > 0) {
        for (i in seq_len(nrow(terms))) {
          tryCatch({
            db_execute(db_pool,
              "INSERT INTO translation_terminology (source_term, target_term, domain, created_by)
               VALUES ($1, $2, $3, $4)
               ON CONFLICT (source_term, target_term, source_lang, target_lang, domain) DO NOTHING",
              params = list(terms$source[i], terms$target[i],
                            terms$domain[i] %||% "general", user_data()$id))
            added <- added + 1
          }, error = function(e) NULL)
        }
      } else if (is.list(terms) && length(terms) > 0) {
        for (t in terms) {
          tryCatch({
            db_execute(db_pool,
              "INSERT INTO translation_terminology (source_term, target_term, domain, created_by)
               VALUES ($1, $2, $3, $4)
               ON CONFLICT (source_term, target_term, source_lang, target_lang, domain) DO NOTHING",
              params = list(t$source %||% "", t$target %||% "",
                            t$domain %||% "general", user_data()$id))
            added <- added + 1
          }, error = function(e) NULL)
        }
      }

      if (added > 0) {
        notify_success(paste(added, "termin lüğətə əlavə edildi"))
      } else {
        notify_warning("Əlavə ediləcək termin tapılmadı")
      }
    })

    # =============================================
    # TAB 3: PISA Lokalizasiya
    # =============================================
    observeEvent(input$btn_pisa_localize, {
      req(input$pisa_text)

      withProgress(message = "PISA sualı lokalizasiya edilir...", value = 0.3, {
        result <- tryCatch(
          localize_pisa_item(
            item_text = input$pisa_text,
            options = list(input$pisa_opt_a, input$pisa_opt_b, input$pisa_opt_c, input$pisa_opt_d),
            correct_answer = input$pisa_correct,
            subject = input$pisa_subject,
            grade = input$pisa_grade,
            db_pool = db_pool,
            user_id = user_data()$id
          ),
          error = function(e) list(success = FALSE, message = e$message)
        )
        setProgress(value = 1)
      })

      pisa_localization_result(result)

      if (result$success) {
        notify_success("PISA sualı lokalizasiya edildi!")
      } else {
        notify_error(paste("Lokalizasiya xətası:", result$message))
      }
    })

    output$pisa_result_ui <- renderUI({
      result <- pisa_localization_result()
      if (is.null(result)) {
        return(tags$div(style = "text-align:center; color:#999; padding:40px;",
          icon("globe-americas", style = "font-size:2.5em;"), tags$br(), tags$br(),
          tags$p("PISA sualını daxil edib 'Lokalizasiya Et' düyməsini basın")))
      }
      if (!result$success) {
        return(tags$div(class = "alert alert-danger", icon("exclamation-triangle"), " ", result$message))
      }

      opts <- result$localized_options
      correct <- result$correct_answer %||% "A"

      tags$div(
        tags$div(style = "border-left:4px solid #9b59b6; padding:12px; background:#f5f0ff; border-radius:4px;",
          tags$p(style = "font-size:1.05em; font-weight:bold;", result$localized_text %||% result$translated_text)
        ),
        tags$div(style = "margin-top:12px;",
          lapply(c("A", "B", "C", "D"), function(letter) {
            opt_text <- opts[[letter]] %||% ""
            is_correct <- letter == correct
            style <- if (is_correct) {
              "padding:8px; margin:4px 0; border-radius:4px; background:#e8f5e9; border-left:3px solid #27ae60;"
            } else {
              "padding:8px; margin:4px 0; border-radius:4px; background:#fafafa; border-left:3px solid #ddd;"
            }
            tags$div(style = style,
              tags$strong(paste0(letter, ") ")),
              opt_text,
              if (is_correct) tags$span(class = "label label-success", style = "margin-left:8px;", "Düzgün")
            )
          })
        ),
        if (isTRUE(result$difficulty_preserved))
          tags$div(style = "margin-top:8px;",
            tags$span(class = "label label-info", icon("check"), " Çətinlik səviyyəsi qorunub"))
      )
    })

    output$pisa_notes_ui <- renderUI({
      result <- pisa_localization_result()
      if (is.null(result) || !result$success) {
        return(tags$p(style = "color:#999;", "Lokalizasiya nəticəsi gözlənilir"))
      }
      notes <- result$adaptation_notes
      if (is.null(notes) || length(notes) == 0) {
        return(tags$p("Adaptasiya qeydi yoxdur"))
      }
      tags$ul(lapply(notes, function(n) tags$li(style = "margin-bottom:4px;", n)))
    })

    # Sual bankına əlavə et
    observeEvent(input$btn_pisa_save_item, {
      result <- pisa_localization_result()
      if (is.null(result) || !result$success) {
        notify_warning("Əvvəlcə lokalizasiya aparın")
        return()
      }

      opts <- result$localized_options
      correct <- result$correct_answer %||% "A"

      tryCatch({
        db_execute(db_pool,
          "INSERT INTO items (question_text, option_a, option_b, option_c, option_d,
           correct_answer, difficulty, bloom_level, created_by)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)",
          params = list(
            result$localized_text %||% result$translated_text,
            opts[["A"]] %||% "", opts[["B"]] %||% "",
            opts[["C"]] %||% "", opts[["D"]] %||% "",
            correct, "orta", "Tətbiq", user_data()$id
          )
        )
        notify_success("Sual bankına əlavə edildi!")
      }, error = function(e) {
        notify_error(paste("Saxlama xətası:", e$message))
      })
    })

    # =============================================
    # TAB 4: Terminologiya CRUD
    # =============================================

    # Terminologiya data
    term_data <- reactive({
      input$btn_term_add
      input$btn_term_delete
      input$btn_term_verify

      query <- "SELECT t.id, t.source_term, t.target_term, t.source_lang, t.target_lang,
                       t.domain, t.confidence, t.is_verified, t.notes,
                       s.name as subject_name
                FROM translation_terminology t
                LEFT JOIN subjects s ON t.subject_id = s.id
                WHERE 1=1"
      params <- list(); idx <- 1

      if (!is_empty(input$term_domain)) {
        query <- paste0(query, " AND t.domain = $", idx); params[[idx]] <- input$term_domain; idx <- idx + 1
      }
      if (!is_empty(input$term_source_lang)) {
        query <- paste0(query, " AND t.source_lang = $", idx); params[[idx]] <- input$term_source_lang; idx <- idx + 1
      }
      if (!is_empty(input$term_target_lang)) {
        query <- paste0(query, " AND t.target_lang = $", idx); params[[idx]] <- input$term_target_lang; idx <- idx + 1
      }
      if (!is_empty(input$term_status)) {
        verified <- input$term_status == "verified"
        query <- paste0(query, " AND t.is_verified = $", idx); params[[idx]] <- verified; idx <- idx + 1
      }
      if (!is_empty(input$term_search)) {
        query <- paste0(query, " AND (t.source_term ILIKE $", idx, " OR t.target_term ILIKE $", idx, ")")
        params[[idx]] <- paste0("%", input$term_search, "%")
      }

      query <- paste0(query, " ORDER BY t.is_verified DESC, t.confidence DESC, t.source_term")

      if (length(params) > 0) db_query(db_pool, query, params = params) else db_query(db_pool, query)
    })

    output$term_table <- renderDT({
      data <- term_data()
      if (nrow(data) == 0) {
        return(datatable(data.frame(), options = list(
          language = list(emptyTable = "Termin tapılmadı"))))
      }
      display <- data %>% select(source_term, target_term, domain, subject_name, confidence, is_verified)
      names(display) <- c("Mənbə", "Hədəf", "Sahə", "Fənn", "Etibarlılıq", "Təsdiqlənmiş")
      display$Təsdiqlənmiş <- ifelse(display$Təsdiqlənmiş, "Bəli", "Xeyr")
      datatable(display, selection = "single", options = default_dt_options(25))
    })

    # Termin əlavə et
    observeEvent(input$btn_term_add, {
      req(input$term_new_source, input$term_new_target)

      subject_id <- NULL
      if (!is_empty(input$term_new_subject)) {
        subj <- db_get_one(db_pool, "SELECT id FROM subjects WHERE name = $1",
          params = list(input$term_new_subject))
        subject_id <- subj$id
      }

      result <- db_execute(db_pool,
        "INSERT INTO translation_terminology
         (source_term, target_term, source_lang, target_lang, domain, subject_id,
          confidence, notes, created_by)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)",
        params = list(
          input$term_new_source, input$term_new_target,
          input$term_source_lang, input$term_target_lang,
          input$term_new_domain, subject_id,
          input$term_new_confidence, input$term_new_notes, user_data()$id
        )
      )

      if (result > 0) {
        notify_success("Termin əlavə edildi!")
        updateTextInput(session, "term_new_source", value = "")
        updateTextInput(session, "term_new_target", value = "")
        updateTextAreaInput(session, "term_new_notes", value = "")
      } else {
        notify_error("Termin əlavə edilə bilmədi (dublikat ola bilər)")
      }
    })

    # Termin redaktə
    observeEvent(input$btn_term_edit, {
      sel <- input$term_table_rows_selected
      if (is.null(sel) || length(sel) == 0) {
        notify_warning("Redaktə etmək üçün termin seçin")
        return()
      }

      data <- term_data()
      row <- data[sel, ]

      showModal(modalDialog(
        title = "Termini Redaktə Et",
        textInput(ns("edit_source"), "Mənbə termin:", value = row$source_term),
        textInput(ns("edit_target"), "Hədəf termin:", value = row$target_term),
        selectInput(ns("edit_domain"), "Sahə:", choices = TRANSLATION_DOMAINS, selected = row$domain),
        sliderInput(ns("edit_confidence"), "Etibarlılıq:", min = 0, max = 1,
          value = row$confidence, step = 0.05),
        textAreaInput(ns("edit_notes"), "Qeydlər:", value = row$notes %||% "", rows = 2),
        footer = tagList(
          actionButton(ns("btn_edit_save"), "Saxla", class = "btn-success"),
          modalButton("Ləğv")
        )
      ))
    })

    observeEvent(input$btn_edit_save, {
      sel <- input$term_table_rows_selected
      data <- term_data()
      if (is.null(sel) || sel > nrow(data)) return()

      term_id <- data[sel, "id"]
      db_execute(db_pool,
        "UPDATE translation_terminology
         SET source_term = $1, target_term = $2, domain = $3, confidence = $4,
             notes = $5, updated_at = NOW()
         WHERE id = $6",
        params = list(input$edit_source, input$edit_target, input$edit_domain,
                      input$edit_confidence, input$edit_notes, term_id))
      removeModal()
      notify_success("Termin yeniləndi!")
    })

    # Termin sil
    observeEvent(input$btn_term_delete, {
      sel <- input$term_table_rows_selected
      if (is.null(sel) || length(sel) == 0) {
        notify_warning("Silmək üçün termin seçin")
        return()
      }
      data <- term_data()
      term_id <- data[sel, "id"]
      db_execute(db_pool, "DELETE FROM translation_terminology WHERE id = $1",
        params = list(term_id))
      notify_success("Termin silindi!")
    })

    # Termin təsdiq
    observeEvent(input$btn_term_verify, {
      sel <- input$term_table_rows_selected
      if (is.null(sel) || length(sel) == 0) {
        notify_warning("Təsdiq etmək üçün termin seçin")
        return()
      }
      data <- term_data()
      term_id <- data[sel, "id"]
      db_execute(db_pool,
        "UPDATE translation_terminology SET is_verified = TRUE, updated_at = NOW() WHERE id = $1",
        params = list(term_id))
      notify_success("Termin təsdiqləndi!")
    })

    # Termin ixrac
    output$btn_term_export <- downloadHandler(
      filename = function() paste0("terminologiya_", Sys.Date(), ".xlsx"),
      content = function(file) {
        data <- term_data()
        if (nrow(data) > 0) {
          export <- data %>% select(source_term, target_term, source_lang, target_lang,
                                    domain, confidence, is_verified, notes)
          names(export) <- c("Mənbə", "Hədəf", "Mənbə Dili", "Hədəf Dili",
                             "Sahə", "Etibarlılıq", "Təsdiqlənmiş", "Qeydlər")
          export_to_excel(export, file, "Terminologiya")
        }
      }
    )

    # =============================================
    # TAB 5: Tarixçə
    # =============================================

    hist_data <- reactive({
      query <- "SELECT h.id, h.translation_type, h.source_lang, h.target_lang,
                       h.tokens_used, h.quality_score, h.is_verified, h.created_at,
                       LEFT(h.source_text, 80) as source_preview,
                       LEFT(h.translated_text, 80) as target_preview
                FROM translation_history h WHERE 1=1"
      params <- list(); idx <- 1

      if (!is_empty(input$hist_type)) {
        query <- paste0(query, " AND h.translation_type = $", idx)
        params[[idx]] <- input$hist_type; idx <- idx + 1
      }
      if (!is_empty(input$hist_status)) {
        verified <- input$hist_status == "verified"
        query <- paste0(query, " AND h.is_verified = $", idx)
        params[[idx]] <- verified; idx <- idx + 1
      }
      if (!is.null(input$hist_from)) {
        query <- paste0(query, " AND h.created_at >= $", idx)
        params[[idx]] <- as.character(input$hist_from); idx <- idx + 1
      }
      if (!is.null(input$hist_to)) {
        query <- paste0(query, " AND h.created_at <= $", idx, " + INTERVAL '1 day'")
        params[[idx]] <- as.character(input$hist_to)
      }

      query <- paste0(query, " ORDER BY h.created_at DESC LIMIT 500")

      if (length(params) > 0) db_query(db_pool, query, params = params) else db_query(db_pool, query)
    })

    output$hist_table <- renderDT({
      data <- hist_data()
      if (nrow(data) == 0) {
        return(datatable(data.frame(), options = list(
          language = list(emptyTable = "Tərcümə tarixçəsi boşdur"))))
      }
      display <- data %>% select(translation_type, source_lang, target_lang, source_preview,
                                  tokens_used, quality_score, is_verified, created_at)
      names(display) <- c("Növ", "Mənbə", "Hədəf", "Mətn", "Token", "Keyfiyyət", "Təsdiq", "Tarix")
      display$Təsdiq <- ifelse(display$Təsdiq, "Bəli", "Xeyr")
      display$Tarix <- format_datetime_az(display$Tarix)
      datatable(display, selection = "single", options = default_dt_options(25))
    })

    # Tarixçə ValueBox-lar
    output$hist_total_box <- renderValueBox({
      result <- db_get_one(db_pool,
        "SELECT COUNT(*) as cnt FROM translation_history
         WHERE created_at >= $1 AND created_at <= $2 + INTERVAL '1 day'",
        params = list(as.character(input$hist_from), as.character(input$hist_to)))
      valueBox(result$cnt %||% 0, "Ümumi Tərcümə", icon = icon("language"), color = "aqua")
    })

    output$hist_verified_box <- renderValueBox({
      result <- db_get_one(db_pool,
        "SELECT COUNT(*) as cnt FROM translation_history
         WHERE is_verified = TRUE AND created_at >= $1 AND created_at <= $2 + INTERVAL '1 day'",
        params = list(as.character(input$hist_from), as.character(input$hist_to)))
      valueBox(result$cnt %||% 0, "Təsdiqlənmiş", icon = icon("check-circle"), color = "green")
    })

    output$hist_tokens_box <- renderValueBox({
      result <- db_get_one(db_pool,
        "SELECT COALESCE(SUM(tokens_used), 0) as total FROM translation_history
         WHERE created_at >= $1 AND created_at <= $2 + INTERVAL '1 day'",
        params = list(as.character(input$hist_from), as.character(input$hist_to)))
      total <- result$total %||% 0
      display <- if (total > 1000) paste0(format_number_az(total / 1000, 1), "K") else total
      valueBox(display, "Token İstifadəsi", icon = icon("coins"), color = "yellow")
    })

    output$hist_quality_box <- renderValueBox({
      result <- db_get_one(db_pool,
        "SELECT COALESCE(AVG(quality_score), 0) as avg_q FROM translation_history
         WHERE quality_score IS NOT NULL AND created_at >= $1 AND created_at <= $2 + INTERVAL '1 day'",
        params = list(as.character(input$hist_from), as.character(input$hist_to)))
      avg_q <- round(result$avg_q %||% 0, 1)
      valueBox(paste0(avg_q, "/5"), "Orta Keyfiyyət", icon = icon("star"), color = "purple")
    })
  })
}
