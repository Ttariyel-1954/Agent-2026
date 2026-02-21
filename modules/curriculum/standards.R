# =============================================
# ARTI-2026: Kurikulum Standartları
# =============================================

standards_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(column(12, h2(icon("book"), "Kurikulum Standartları"), hr())),
    fluidRow(
      column(3, selectInput(ns("filter_subject"), "Fənn:", choices = c("Hamısı" = "", SUBJECTS))),
      column(3, selectInput(ns("filter_grade"), "Sinif:", choices = c("Hamısı" = "", setNames(1:11, paste0(1:11, "-ci sinif"))))),
      column(3, selectInput(ns("filter_level"), "Təhsil pilləsi:", choices = c("Hamısı" = "", "İbtidai" = "primary", "Ümumi orta" = "lower_secondary", "Tam orta" = "upper_secondary"))),
      column(3, selectInput(ns("filter_bloom"), "Bloom:", choices = c("Hamısı" = "", BLOOM_LEVELS)))
    ),
    fluidRow(column(12, div(class = "btn-toolbar",
      actionButton(ns("btn_add"), "Yeni Standart", icon = icon("plus"), class = "btn-success"),
      actionButton(ns("btn_edit"), "Redaktə", icon = icon("edit"), class = "btn-primary"),
      downloadButton(ns("btn_export_excel"), "Excel", class = "btn-info"),
      downloadButton(ns("btn_export_csv"), "CSV", class = "btn-warning"),
      actionButton(ns("btn_ai_lesson"), "AI Dərs Planı", icon = icon("robot"), class = "btn-info")
    ))),
    br(),
    fluidRow(
      column(8, wellPanel(h4("Standartlar Cədvəli"), DTOutput(ns("standards_table")))),
      column(4,
        wellPanel(h4("Bloom Paylanması"), plotlyOutput(ns("bloom_chart"), height = "250px")),
        wellPanel(h4("Sinif Paylanması"), plotlyOutput(ns("grade_chart"), height = "250px"))
      )
    )
  )
}

standards_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    standards_data <- reactive({
      query <- "SELECT cs.*, s.name as subject_name FROM curriculum_standards cs
                LEFT JOIN subjects s ON cs.subject_id = s.id WHERE 1=1"
      params <- list(); idx <- 1
      if (!is_empty(input$filter_subject)) {
        query <- paste0(query, " AND s.name = $", idx); params[[idx]] <- input$filter_subject; idx <- idx+1
      }
      if (!is_empty(input$filter_grade)) {
        query <- paste0(query, " AND cs.grade = $", idx); params[[idx]] <- as.integer(input$filter_grade); idx <- idx+1
      }
      if (!is_empty(input$filter_bloom)) {
        query <- paste0(query, " AND cs.bloom_level = $", idx); params[[idx]] <- input$filter_bloom
      }
      query <- paste0(query, " ORDER BY cs.code")
      if (length(params) > 0) db_query(db_pool, query, params = params) else db_query(db_pool, query)
    })

    output$standards_table <- renderDT({
      data <- standards_data()
      if (nrow(data) == 0) return(datatable(data.frame()))
      display <- data %>% select(code, subject_name, grade, description, bloom_level)
      names(display) <- c("Kod", "Fənn", "Sinif", "Təsvir", "Bloom")
      datatable(display, selection = "single", options = default_dt_options())
    })

    output$bloom_chart <- renderPlotly({
      data <- standards_data()
      if (nrow(data) == 0) return(plotly_empty())
      counts <- data %>% count(bloom_level)
      plot_ly(data = counts, x = ~bloom_level, y = ~n, type = "bar",
              marker = list(color = "#3498db")) %>%
        layout(xaxis = list(title = "", tickangle = -45), yaxis = list(title = "Say"))
    })

    output$grade_chart <- renderPlotly({
      data <- standards_data()
      if (nrow(data) == 0) return(plotly_empty())
      counts <- data %>% count(grade)
      plot_ly(data = counts, x = ~paste0(grade, "-ci sinif"), y = ~n, type = "bar",
              marker = list(color = "#27ae60")) %>%
        layout(xaxis = list(title = ""), yaxis = list(title = "Say"))
    })

    observeEvent(input$btn_add, {
      showModal(modalDialog(
        title = "Yeni Standart", size = "l",
        textInput(ns("std_code"), "Standart kodu:", placeholder = "AZ.RIY.5.1.1"),
        selectInput(ns("std_subject"), "Fənn:", choices = SUBJECTS),
        selectInput(ns("std_grade"), "Sinif:", choices = 1:11),
        textAreaInput(ns("std_desc"), "Təsvir:", rows = 3, width = "100%"),
        selectInput(ns("std_bloom"), "Bloom:", choices = BLOOM_LEVELS),
        footer = tagList(actionButton(ns("btn_save_std"), "Saxla", class = "btn-success"), modalButton("Ləğv"))
      ))
    })

    observeEvent(input$btn_save_std, {
      req(input$std_code, input$std_desc)
      result <- db_execute(db_pool,
        "INSERT INTO curriculum_standards (subject_id, grade, code, description, bloom_level)
         VALUES ((SELECT id FROM subjects WHERE name = $1), $2, $3, $4, $5)",
        params = list(input$std_subject, as.integer(input$std_grade), input$std_code, input$std_desc, input$std_bloom))
      if (result > 0) { removeModal(); notify_success("Standart əlavə edildi!") }
    })

    # === AI Dərs Planı Generatoru ===
    lesson_plan_data <- reactiveVal(NULL)

    # Parametr modalı
    observeEvent(input$btn_ai_lesson, {
      showModal(modalDialog(
        title = tagList(icon("robot"), "AI Dərs Planı Yaratma"),
        size = "m", easyClose = TRUE,
        fluidRow(
          column(6, selectInput(ns("lp_subject"), "Fənn:", choices = SUBJECTS)),
          column(6, selectInput(ns("lp_grade"), "Sinif:", choices = setNames(1:11, paste0(1:11, "-ci sinif"))))
        ),
        textInput(ns("lp_topic"), "Mövzu/Bölmə:", placeholder = "Məs: Tənliklər sistemi", width = "100%"),
        fluidRow(
          column(6, numericInput(ns("lp_weeks"), "Həftə sayı:", value = 4, min = 1, max = 36)),
          column(6, numericInput(ns("lp_hours"), "Həftəlik dərs saatı:", value = 3, min = 1, max = 7))
        ),
        checkboxInput(ns("lp_link_standards"), "Kurikulum standartları ilə əlaqələndir", value = TRUE),
        footer = tagList(
          actionButton(ns("btn_lp_run"), "Dərs Planı Yarat", icon = icon("robot"), class = "btn-info"),
          modalButton("Ləğv et")
        )
      ))
    })

    # Claude API çağırışı
    observeEvent(input$btn_lp_run, {
      req(input$lp_topic)
      removeModal()

      subject <- input$lp_subject
      grade <- input$lp_grade
      topic <- input$lp_topic
      weeks <- input$lp_weeks
      hours <- input$lp_hours
      link_standards <- input$lp_link_standards

      # Kurikulum standartlarını DB-dən çək
      standards_text <- ""
      if (link_standards) {
        stds <- tryCatch(
          db_query(db_pool,
            "SELECT code, description, bloom_level FROM curriculum_standards cs
             JOIN subjects s ON cs.subject_id = s.id
             WHERE s.name = $1 AND cs.grade = $2 ORDER BY cs.code",
            params = list(subject, as.integer(grade))),
          error = function(e) data.frame()
        )
        if (nrow(stds) > 0) {
          standards_text <- paste0(
            "\n\nBu fənn və sinif üçün mövcud kurikulum standartları:\n",
            paste(sprintf("- %s: %s (Bloom: %s)", stds$code, stds$description, stds$bloom_level),
                  collapse = "\n"),
            "\n\nHər dərsi uyğun standart kod(lar)ı ilə əlaqələndir."
          )
        }
      }

      prompt <- paste0(
        "Azərbaycan Kurikulum standartlarına uyğun ", subject, " fənni, ",
        grade, "-ci sinif, \"", topic, "\" mövzusu üzrə ",
        weeks, " həftəlik (həftədə ", hours, " saat) dərs planı hazırla.\n\n",
        "Hər dərs üçün aşağıdakıları daxil et:\n",
        "- Dərsin mövzusu\n",
        "- Məqsəd (öyrənmə nəticələri)\n",
        "- Dərs fəaliyyətləri (giriş, əsas hissə, yekunlaşdırma)\n",
        "- Resurslar və materiallar\n",
        "- Qiymətləndirmə üsulu\n",
        "- Ev tapşırığı\n",
        "- Vaxt bölgüsü (dəqiqə ilə, cəmi 45 dəq)\n",
        "- Əlaqəli kurikulum standart kodu (varsa)\n",
        standards_text, "\n\n",
        "Cavabı YALNIZ JSON formatında qaytar.\n",
        "Format: {\"title\": \"...\", \"subject\": \"...\", \"grade\": N, \"topic\": \"...\", ",
        "\"weeks\": N, \"hours_per_week\": N, \"lessons\": [",
        "{\"week\": N, \"lesson\": N, \"title\": \"...\", \"objectives\": [\"...\"], ",
        "\"activities\": {\"intro\": \"...\", \"main\": \"...\", \"closing\": \"...\"}, ",
        "\"resources\": [\"...\"], \"assessment\": \"...\", \"homework\": \"...\", ",
        "\"time_allocation\": {\"intro\": N, \"main\": N, \"closing\": N}, ",
        "\"standard_codes\": [\"...\"]}]}"
      )

      system_prompt <- paste0(
        "Sən Azərbaycan təhsil sistemi üçün dərs planları hazırlayan təcrübəli kurikulum mütəxəssisisən. ",
        "Dərs planlarını Azərbaycan Respublikasının Ümumi Təhsil Kurikulumuna uyğun hazırla. ",
        "Bloom taksonomiyasının müxtəlif səviyyələrini nəzərə al. ",
        "Cavabı YALNIZ düzgün JSON formatında qaytar, başqa heç nə yazma."
      )

      withProgress(message = "AI dərs planı yaradır...", value = 0.3, {
        result <- tryCatch(
          call_claude_api(prompt, system_prompt, max_tokens = 4096, temperature = 0.7),
          error = function(e) list(success = FALSE, message = e$message)
        )

        if (!result$success) {
          notify_error(paste("AI xətası:", result$message))
          return()
        }

        setProgress(value = 0.7, message = "Cavab emal edilir...")

        plan_data <- tryCatch(
          extract_json_from_response(result$message),
          error = function(e) NULL
        )

        if (is.null(plan_data)) {
          notify_error("AI cavabı emal edilə bilmədi. Yenidən cəhd edin.")
          return()
        }

        # lessons hissəsini data.frame-ə çevir
        if (!is.null(plan_data$lessons) && !is.data.frame(plan_data$lessons)) {
          plan_data$lessons <- tryCatch(
            as.data.frame(do.call(rbind, lapply(plan_data$lessons, function(l) {
              data.frame(
                week = l$week %||% NA,
                lesson = l$lesson %||% NA,
                title = l$title %||% "",
                objectives = paste(unlist(l$objectives), collapse = "; "),
                intro = l$activities$intro %||% "",
                main = l$activities$main %||% "",
                closing = l$activities$closing %||% "",
                resources = paste(unlist(l$resources), collapse = ", "),
                assessment = l$assessment %||% "",
                homework = l$homework %||% "",
                time_intro = l$time_allocation$intro %||% 5,
                time_main = l$time_allocation$main %||% 30,
                time_closing = l$time_allocation$closing %||% 10,
                standard_codes = paste(unlist(l$standard_codes), collapse = ", "),
                stringsAsFactors = FALSE
              )
            })), stringsAsFactors = FALSE),
            error = function(e) NULL
          )
        }

        if (is.null(plan_data$lessons) || nrow(plan_data$lessons) == 0) {
          notify_error("AI dərs planı yarada bilmədi.")
          return()
        }

        lesson_plan_data(plan_data)
        setProgress(value = 1)
      })

      # Nəzərdən keçirmə modalı
      req(lesson_plan_data())
      lp <- lesson_plan_data()
      lessons <- lp$lessons

      lesson_html <- lapply(seq_len(nrow(lessons)), function(i) {
        l <- lessons[i, ]
        tags$div(
          style = "border: 1px solid #ddd; border-radius: 8px; padding: 12px; margin-bottom: 10px;",
          tags$div(style = "display: flex; justify-content: space-between; align-items: center;",
            tags$strong(paste0("Həftə ", l$week, " / Dərs ", l$lesson, ": ", l$title)),
            if (nchar(l$standard_codes) > 0)
              tags$span(class = "label label-info", style = "font-size: 0.85em;", l$standard_codes)
          ),
          tags$div(style = "margin-top: 8px; font-size: 0.9em;",
            tags$div(tags$strong("Məqsəd: "), l$objectives),
            tags$div(style = "margin-top: 4px;",
              tags$strong("Fəaliyyətlər: "),
              tags$span(style = "color: #2980b9;", paste0("Giriş (", l$time_intro, "dəq): ")), l$intro, tags$br(),
              tags$span(style = "color: #27ae60;", paste0("Əsas (", l$time_main, "dəq): ")), l$main, tags$br(),
              tags$span(style = "color: #e67e22;", paste0("Yekun (", l$time_closing, "dəq): ")), l$closing
            ),
            tags$div(style = "margin-top: 4px;", tags$strong("Resurslar: "), l$resources),
            tags$div(tags$strong("Qiymətləndirmə: "), l$assessment),
            tags$div(tags$strong("Ev tapşırığı: "), l$homework)
          )
        )
      })

      showModal(modalDialog(
        title = tagList(icon("calendar-alt"),
          paste0("Dərs Planı: ", lp$subject %||% subject, " — ", lp$topic %||% topic)),
        size = "l", easyClose = FALSE,
        tags$div(style = "max-height: 500px; overflow-y: auto;", lesson_html),
        footer = tagList(
          downloadButton(ns("btn_lp_download_word"), "Word yüklə", class = "btn-success"),
          downloadButton(ns("btn_lp_download_html"), "HTML yüklə", class = "btn-info"),
          modalButton("Bağla")
        )
      ))
    })

    # Word (docx) yükləmə
    output$btn_lp_download_word <- downloadHandler(
      filename = function() {
        lp <- lesson_plan_data()
        paste0("ders_plani_", gsub("\\s+", "_", lp$topic %||% "plan"), "_", Sys.Date(), ".docx")
      },
      content = function(file) {
        lp <- lesson_plan_data()
        req(lp)

        # Rmarkdown mənbəyi yarat
        rmd_content <- generate_lesson_plan_rmd(lp)
        tmp_rmd <- tempfile(fileext = ".Rmd")
        writeLines(rmd_content, tmp_rmd, useBytes = TRUE)

        tryCatch({
          rmarkdown::render(tmp_rmd, output_format = rmarkdown::word_document(), output_file = file, quiet = TRUE)
        }, error = function(e) {
          # rmarkdown xətası olarsa, openxlsx ilə sadə Excel versiya yarat
          wb <- openxlsx::createWorkbook()
          openxlsx::addWorksheet(wb, "Dərs Planı")
          openxlsx::writeData(wb, "Dərs Planı", lp$lessons)
          header_style <- openxlsx::createStyle(fontColour = "#FFFFFF", fgFill = "#2c3e50",
                                                 halign = "center", textDecoration = "bold")
          openxlsx::addStyle(wb, "Dərs Planı", header_style, rows = 1, cols = 1:ncol(lp$lessons))
          openxlsx::setColWidths(wb, "Dərs Planı", cols = 1:ncol(lp$lessons), widths = "auto")
          out_xlsx <- sub("\\.docx$", ".xlsx", file)
          openxlsx::saveWorkbook(wb, out_xlsx, overwrite = TRUE)
          file.copy(out_xlsx, file, overwrite = TRUE)
        })
        unlink(tmp_rmd)
      }
    )

    # HTML yükləmə
    output$btn_lp_download_html <- downloadHandler(
      filename = function() {
        lp <- lesson_plan_data()
        paste0("ders_plani_", gsub("\\s+", "_", lp$topic %||% "plan"), "_", Sys.Date(), ".html")
      },
      content = function(file) {
        lp <- lesson_plan_data()
        req(lp)

        rmd_content <- generate_lesson_plan_rmd(lp)
        tmp_rmd <- tempfile(fileext = ".Rmd")
        writeLines(rmd_content, tmp_rmd, useBytes = TRUE)

        tryCatch(
          rmarkdown::render(tmp_rmd, output_format = rmarkdown::html_document(), output_file = file, quiet = TRUE),
          error = function(e) {
            # Fallback: birbaşa HTML yaz
            html <- generate_lesson_plan_html(lp)
            writeLines(html, file, useBytes = TRUE)
          }
        )
        unlink(tmp_rmd)
      }
    )

    output$btn_export_excel <- downloadHandler(
      filename = function() paste0("standartlar_", Sys.Date(), ".xlsx"),
      content = function(file) export_to_excel(standards_data(), file, "Standartlar")
    )
    output$btn_export_csv <- downloadHandler(
      filename = function() paste0("standartlar_", Sys.Date(), ".csv"),
      content = function(file) write.csv(standards_data(), file, row.names = FALSE)
    )
  })
}

# === Dərs Planı Rmarkdown Generatoru ===
generate_lesson_plan_rmd <- function(lp) {
  lessons <- lp$lessons
  header <- paste0(
    "---\n",
    "title: \"Dərs Planı: ", lp$topic %||% "", "\"\n",
    "subtitle: \"", lp$subject %||% "", " | ", lp$grade %||% "", "-ci sinif\"\n",
    "date: \"", format(Sys.Date(), "%d.%m.%Y"), "\"\n",
    "output:\n",
    "  word_document: default\n",
    "  html_document:\n",
    "    theme: flatly\n",
    "---\n\n",
    "**Fənn:** ", lp$subject %||% "", "  \n",
    "**Sinif:** ", lp$grade %||% "", "-ci sinif  \n",
    "**Mövzu:** ", lp$topic %||% "", "  \n",
    "**Müddət:** ", lp$weeks %||% "", " həftə (həftədə ", lp$hours_per_week %||% "", " saat)  \n",
    "**Yaradılma tarixi:** ", format(Sys.Date(), "%d.%m.%Y"), "  \n",
    "**Hazırlanıb:** ARTI-2026 AI Dərs Planı Generatoru  \n\n",
    "---\n\n"
  )

  lesson_blocks <- vapply(seq_len(nrow(lessons)), function(i) {
    l <- lessons[i, ]
    std_line <- if (nchar(l$standard_codes) > 0) {
      paste0("**Standart:** ", l$standard_codes, "  \n")
    } else ""

    paste0(
      "## Həftə ", l$week, " / Dərs ", l$lesson, ": ", l$title, "\n\n",
      std_line,
      "**Məqsəd:** ", l$objectives, "  \n\n",
      "### Fəaliyyətlər\n\n",
      "| Mərhələ | Vaxt | Təsvir |\n",
      "|---------|------|--------|\n",
      "| Giriş | ", l$time_intro, " dəq | ", gsub("\\|", "/", l$intro), " |\n",
      "| Əsas hissə | ", l$time_main, " dəq | ", gsub("\\|", "/", l$main), " |\n",
      "| Yekunlaşdırma | ", l$time_closing, " dəq | ", gsub("\\|", "/", l$closing), " |\n\n",
      "**Resurslar:** ", l$resources, "  \n",
      "**Qiymətləndirmə:** ", l$assessment, "  \n",
      "**Ev tapşırığı:** ", l$homework, "  \n\n",
      "---\n\n"
    )
  }, character(1))

  paste0(header, paste(lesson_blocks, collapse = ""))
}

# === Dərs Planı HTML Fallback ===
generate_lesson_plan_html <- function(lp) {
  lessons <- lp$lessons

  rows_html <- vapply(seq_len(nrow(lessons)), function(i) {
    l <- lessons[i, ]
    paste0(
      "<div style='border:1px solid #ccc;border-radius:8px;padding:14px;margin-bottom:12px;'>",
      "<h3 style='margin-top:0;color:#2c3e50;'>H\u0259ft\u0259 ", l$week, " / D\u0259rs ", l$lesson, ": ", l$title, "</h3>",
      if (nchar(l$standard_codes) > 0) paste0("<span style='background:#3498db;color:#fff;padding:2px 8px;border-radius:4px;font-size:0.85em;'>", l$standard_codes, "</span>") else "",
      "<p><strong>M\u0259qs\u0259d:</strong> ", l$objectives, "</p>",
      "<table style='width:100%;border-collapse:collapse;margin:8px 0;'>",
      "<tr style='background:#2c3e50;color:#fff;'><th style='padding:6px;'>M\u0259rh\u0259l\u0259</th><th>Vaxt</th><th>T\u0259svir</th></tr>",
      "<tr><td style='padding:6px;'>Giri\u015f</td><td>", l$time_intro, " d\u0259q</td><td>", l$intro, "</td></tr>",
      "<tr style='background:#f9f9f9;'><td style='padding:6px;'>\u018Esas hiss\u0259</td><td>", l$time_main, " d\u0259q</td><td>", l$main, "</td></tr>",
      "<tr><td style='padding:6px;'>Yekunla\u015fd\u0131rma</td><td>", l$time_closing, " d\u0259q</td><td>", l$closing, "</td></tr>",
      "</table>",
      "<p><strong>Resurslar:</strong> ", l$resources, "</p>",
      "<p><strong>Qiym\u0259tl\u0259ndirm\u0259:</strong> ", l$assessment, "</p>",
      "<p><strong>Ev tap\u015f\u0131r\u0131\u011f\u0131:</strong> ", l$homework, "</p>",
      "</div>"
    )
  }, character(1))

  paste0(
    "<!DOCTYPE html><html><head><meta charset='utf-8'>",
    "<title>D\u0259rs Plan\u0131</title>",
    "<style>body{font-family:Arial,sans-serif;max-width:900px;margin:0 auto;padding:20px;}</style>",
    "</head><body>",
    "<h1 style='color:#2c3e50;'>D\u0259rs Plan\u0131: ", lp$topic %||% "", "</h1>",
    "<p><strong>F\u0259nn:</strong> ", lp$subject %||% "", " | ",
    "<strong>Sinif:</strong> ", lp$grade %||% "", "-ci | ",
    "<strong>M\u00fcdd\u0259t:</strong> ", lp$weeks %||% "", " h\u0259ft\u0259</p><hr>",
    paste(rows_html, collapse = ""),
    "<footer style='margin-top:20px;color:#999;font-size:0.85em;'>",
    "ARTI-2026 AI D\u0259rs Plan\u0131 Generatoru | ", format(Sys.Date(), "%d.%m.%Y"),
    "</footer></body></html>"
  )
}
