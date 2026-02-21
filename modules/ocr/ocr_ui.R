# =============================================
# ARTI-2026: OCR Modulu - UI Komponentləri
# Şəkil yükləmə → AI tanıma → Avtomatik emal
# =============================================

#' OCR əsas UI — Cavab Vərəqəsi Tanıma
ocr_answer_sheet_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(column(12, h2(icon("camera"), "OCR — Cavab Vərəqəsi Tanıma"), hr())),

    fluidRow(
      # Sol — Yükləmə və parametrlər
      column(5, wellPanel(
        h3(icon("upload"), "Şəkil Yüklə"),
        fileInput(ns("answer_image"), "Cavab vərəqəsi şəkli:",
          accept = c("image/jpeg", "image/png", "image/gif", "image/webp", "image/bmp"),
          placeholder = "Telefon kamerası və ya skaner..."),
        tags$small(class = "text-muted", "Maks: 20 MB | JPEG, PNG, BMP, WebP"),

        hr(),
        h4(icon("cog"), "Parametrlər"),
        fluidRow(
          column(6, selectInput(ns("as_subject"), "Fənn:", choices = c("Seçin..." = "", SUBJECTS))),
          column(6, selectInput(ns("as_grade"), "Sinif:", choices = c("Seçin..." = "", setNames(1:11, paste0(1:11, "-ci sinif")))))
        ),
        numericInput(ns("as_question_count"), "Sual sayı:", value = 20, min = 1, max = 100),
        textAreaInput(ns("as_answer_key"), "Cavab açarı:",
          placeholder = "1A, 2C, 3B, 4D, 5A, ...\n(hər sual üçün: nömrə + hərf)",
          rows = 3),
        selectInput(ns("as_ai_provider"), "AI Provayder:", choices = c(
          "GPT-4o Vision" = "gpt", "Claude Vision" = "claude"
        )),

        hr(),
        div(class = "btn-toolbar",
          actionButton(ns("btn_scan_answer"), "Tanı və Qiymətləndir", icon = icon("magic"), class = "btn-primary btn-lg"),
          actionButton(ns("btn_clear_answer"), "Təmizlə", icon = icon("eraser"), class = "btn-default")
        )
      )),

      # Sağ — Önbaxış və nəticə
      column(7,
        wellPanel(
          h3(icon("image"), "Şəkil Önbaxışı"),
          uiOutput(ns("answer_preview"))
        ),
        wellPanel(
          h3(icon("check-circle"), "Qiymətləndirmə Nəticəsi"),
          uiOutput(ns("answer_result_summary")),
          hr(),
          DTOutput(ns("answer_detail_table"))
        ),
        wellPanel(
          h4(icon("database"), "DB-yə Yaz"),
          fluidRow(
            column(4, selectizeInput(ns("as_student"), "Şagird:", choices = NULL, options = list(placeholder = "Axtar..."))),
            column(4, selectInput(ns("as_class"), "Sinif:", choices = c("Seçin..." = ""))),
            column(4, br(), actionButton(ns("btn_save_grade"), "Qiyməti Saxla", icon = icon("save"), class = "btn-success"))
          )
        )
      )
    ),

    # Toplu yükləmə
    fluidRow(column(12, wellPanel(
      h3(icon("layer-group"), "Toplu Tanıma"),
      tags$p("Bir neçə cavab vərəqəsini eyni anda yükləyin — hamısı avtomatik qiymətləndirilir."),
      fileInput(ns("batch_images"), "Çoxlu şəkil seçin:", multiple = TRUE,
        accept = c("image/jpeg", "image/png"),
        placeholder = "Bir neçə fayl seçin..."),
      actionButton(ns("btn_batch_scan"), "Hamısını Tanı", icon = icon("play"), class = "btn-warning"),
      br(), br(),
      DTOutput(ns("batch_results_table"))
    )))
  )
}

#' OCR — Şagird Sənədi Tanıma
ocr_student_doc_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(column(12, h2(icon("id-card"), "OCR — Şagird Sənədləri"), hr())),

    fluidRow(
      column(5, wellPanel(
        h3(icon("upload"), "Sənəd Yüklə"),
        fileInput(ns("student_doc_image"), "Sənəd şəkli:",
          accept = c("image/jpeg", "image/png", "image/bmp", "image/webp"),
          placeholder = "Şəxsiyyət vəsiqəsi, doğum şəhadətnaməsi..."),
        selectInput(ns("doc_type"), "Sənəd növü:", choices = c(
          "Doğum Haqqında Şəhadətnamə" = "birth_cert",
          "Şəxsiyyət Vəsiqəsi"        = "id_card",
          "Attestat / Qiymət Cədvəli"  = "transcript",
          "Tibbi Arayış"               = "medical",
          "Köçürmə Sənədi"            = "transfer"
        )),
        selectInput(ns("sd_ai_provider"), "AI Provayder:", choices = c(
          "GPT-4o Vision" = "gpt", "Claude Vision" = "claude"
        )),
        actionButton(ns("btn_scan_doc"), "Sənədi Tanı", icon = icon("search"), class = "btn-primary btn-lg")
      )),

      column(7,
        wellPanel(
          h3(icon("image"), "Sənəd Önbaxışı"),
          uiOutput(ns("doc_preview"))
        ),
        wellPanel(
          h3(icon("user-edit"), "Tanınmış Məlumatlar"),
          uiOutput(ns("doc_confidence_badge")),
          fluidRow(
            column(4, textInput(ns("ext_first_name"), "Ad:")),
            column(4, textInput(ns("ext_last_name"), "Soyad:")),
            column(4, textInput(ns("ext_father_name"), "Ata adı:"))
          ),
          fluidRow(
            column(4, dateInput(ns("ext_birth_date"), "Doğum tarixi:", value = NULL, format = "dd.mm.yyyy")),
            column(4, textInput(ns("ext_fin_code"), "FİN kod:")),
            column(4, selectInput(ns("ext_gender"), "Cinsi:", choices = c("Seçin..." = "", "Kişi" = "kişi", "Qadın" = "qadın")))
          ),
          textInput(ns("ext_address"), "Ünvan:", width = "100%"),
          textAreaInput(ns("ext_notes"), "Qeydlər:", rows = 2),
          hr(),
          div(class = "btn-toolbar",
            actionButton(ns("btn_apply_to_register"), "Qeydiyyat Formasına Köçür", icon = icon("arrow-right"), class = "btn-success"),
            actionButton(ns("btn_save_student_direct"), "Birbaşa Saxla", icon = icon("save"), class = "btn-info")
          )
        )
      )
    )
  )
}

#' OCR — Müəllim Sertifikatı Tanıma
ocr_certificate_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(column(12, h2(icon("certificate"), "OCR — Müəllim Sertifikatları"), hr())),

    fluidRow(
      column(5, wellPanel(
        h3(icon("upload"), "Sertifikat Yüklə"),
        fileInput(ns("cert_image"), "Sertifikat/diplom şəkli:",
          accept = c("image/jpeg", "image/png", "image/bmp", "image/webp"),
          placeholder = "Sertifikat, diplom, təlim sənədi..."),
        selectInput(ns("cert_ai_provider"), "AI Provayder:", choices = c(
          "GPT-4o Vision" = "gpt", "Claude Vision" = "claude"
        )),
        actionButton(ns("btn_scan_cert"), "Sertifikatı Tanı", icon = icon("search"), class = "btn-primary btn-lg")
      )),

      column(7,
        wellPanel(
          h3(icon("image"), "Sertifikat Önbaxışı"),
          uiOutput(ns("cert_preview"))
        ),
        wellPanel(
          h3(icon("edit"), "Tanınmış Məlumatlar"),
          uiOutput(ns("cert_confidence_badge")),
          fluidRow(
            column(6, textInput(ns("cert_title"), "Sertifikat/Təlim adı:", width = "100%")),
            column(6, textInput(ns("cert_provider"), "Təşkilatçı:", width = "100%"))
          ),
          fluidRow(
            column(3, selectInput(ns("cert_type"), "Növ:", choices = c(
              "Kurs" = "kurs", "Seminar" = "seminar", "Konfrans" = "konfrans",
              "Sertifikat" = "sertifikat", "Magistratura" = "magistratura"
            ))),
            column(3, dateInput(ns("cert_start"), "Başlanğıc:", value = NULL, format = "dd.mm.yyyy")),
            column(3, dateInput(ns("cert_end"), "Bitmə:", value = NULL, format = "dd.mm.yyyy")),
            column(3, numericInput(ns("cert_hours"), "Saat:", value = 0, min = 0))
          ),
          textInput(ns("cert_number"), "Sertifikat nömrəsi:"),
          hr(),
          fluidRow(
            column(6, selectizeInput(ns("cert_teacher"), "Müəllim:", choices = NULL, options = list(placeholder = "Axtar..."))),
            column(6, br(), actionButton(ns("btn_save_cert"), "Peşəkar İnkişafa Əlavə Et", icon = icon("save"), class = "btn-success"))
          )
        )
      )
    ),

    # Toplu sertifikat
    fluidRow(column(12, wellPanel(
      h3(icon("layer-group"), "Toplu Sertifikat Tanıma"),
      fileInput(ns("batch_certs"), "Çoxlu sertifikat:", multiple = TRUE,
        accept = c("image/jpeg", "image/png")),
      actionButton(ns("btn_batch_cert"), "Hamısını Tanı", icon = icon("play"), class = "btn-warning"),
      br(), br(),
      DTOutput(ns("batch_cert_table"))
    )))
  )
}

#' OCR — Tarixçə / Log
ocr_history_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(column(12, h2(icon("history"), "OCR Tarixçəsi"), hr())),
    fluidRow(
      column(3, dateRangeInput(ns("hist_dates"), "Tarix:", start = Sys.Date() - 30, end = Sys.Date(), format = "dd.mm.yyyy")),
      column(3, selectInput(ns("hist_type"), "Növ:", choices = c("Hamısı" = "", "Cavab Vərəqəsi" = "answer_sheet",
        "Şagird Sənədi" = "student_doc", "Sertifikat" = "certificate"))),
      column(3, selectInput(ns("hist_provider"), "AI:", choices = c("Hamısı" = "", "GPT-4o" = "gpt", "Claude" = "claude"))),
      column(3, br(), actionButton(ns("btn_hist_load"), "Yüklə", icon = icon("search"), class = "btn-primary"))
    ),
    fluidRow(column(12, wellPanel(
      DTOutput(ns("history_table")),
      hr(),
      tags$small(class = "text-muted", "OCR əməliyyatlarının tam tarixçəsi burada göstərilir.")
    )))
  )
}
