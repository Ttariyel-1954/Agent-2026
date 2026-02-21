# =============================================
# ARTI-2026: Valideyn Əlaqə Modulu — UI Komponentləri
# =============================================

# === 1. Fərdi Məktub UI ===
parent_letter_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(column(12, h2(icon("envelope"), "Valideyn Məktubu"), hr())),

    # Parametrlər
    fluidRow(
      column(3, selectInput(ns("school_filter"), "Məktəb:", choices = c("Bütün məktəblər" = ""))),
      column(2, selectInput(ns("grade_filter"), "Sinif:", choices = c("Hamısı" = "", setNames(1:11, 1:11)))),
      column(3, selectizeInput(ns("student_select"), "Şagird:", choices = NULL,
                                options = list(placeholder = "Axtar..."))),
      column(2, selectInput(ns("report_month"), "Ay:", choices = setNames(1:12, c(
        "Yanvar", "Fevral", "Mart", "Aprel", "May", "İyun",
        "İyul", "Avqust", "Sentyabr", "Oktyabr", "Noyabr", "Dekabr"
      )), selected = as.integer(format(Sys.Date(), "%m")))),
      column(2, numericInput(ns("report_year"), "İl:", value = as.integer(format(Sys.Date(), "%Y")),
                              min = 2024, max = 2030))
    ),

    # Generasiya düyməsi
    fluidRow(column(12, div(class = "btn-toolbar",
      actionButton(ns("btn_generate"), "AI Məktub Yarat", icon = icon("magic"), class = "btn-success btn-lg"),
      actionButton(ns("btn_approve"), "Təsdiq Et", icon = icon("check"), class = "btn-warning"),
      actionButton(ns("btn_send_email"), "E-poçt Göndər", icon = icon("envelope"), class = "btn-primary"),
      actionButton(ns("btn_send_sms"), "SMS Göndər", icon = icon("sms"), class = "btn-info"),
      downloadButton(ns("btn_download_html"), "HTML Yüklə", class = "btn-default")
    ))),
    br(),

    # Valideyn kontakt məlumatları
    uiOutput(ns("parent_contact_ui")),

    # Məktub önizləmə + redaktə
    fluidRow(
      column(8, wellPanel(
        div(style = "display:flex; align-items:center; justify-content:space-between;",
          h4(icon("file-alt"), "Məktub Önizləmə"),
          uiOutput(ns("letter_status_badge"))
        ),
        uiOutput(ns("letter_preview"))
      )),
      column(4,
        wellPanel(
          h4(icon("edit"), "Müəllim Redaktəsi"),
          textAreaInput(ns("teacher_edit_text"), NULL, rows = 20, width = "100%",
                        placeholder = "AI məktubu yaratdıqdan sonra burada redaktə edə bilərsiniz..."),
          actionButton(ns("btn_save_edit"), "Redaktəni Saxla", icon = icon("save"), class = "btn-info btn-block")
        ),
        wellPanel(
          h4(icon("chart-pie"), "Məktub Statistikası"),
          uiOutput(ns("letter_stats"))
        )
      )
    )
  )
}

# === 2. Toplu Generasiya UI ===
parent_batch_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(column(12, h2(icon("mail-bulk"), "Toplu Məktub Generasiyası"), hr())),

    # Filtrər
    fluidRow(
      column(3, selectInput(ns("batch_school"), "Məktəb:", choices = c("Bütün məktəblər" = ""))),
      column(2, selectInput(ns("batch_grade"), "Sinif:", choices = c("Hamısı" = "", setNames(1:11, 1:11)))),
      column(2, selectInput(ns("batch_section"), "Bölmə:", choices = c("Hamısı" = ""))),
      column(2, selectInput(ns("batch_month"), "Ay:", choices = setNames(1:12, c(
        "Yanvar", "Fevral", "Mart", "Aprel", "May", "İyun",
        "İyul", "Avqust", "Sentyabr", "Oktyabr", "Noyabr", "Dekabr"
      )), selected = as.integer(format(Sys.Date(), "%m")))),
      column(1, numericInput(ns("batch_year"), "İl:", value = as.integer(format(Sys.Date(), "%Y")),
                              min = 2024, max = 2030)),
      column(2, div(style = "margin-top:25px",
        actionButton(ns("btn_batch_generate"), "Toplu Yarat", icon = icon("rocket"), class = "btn-success btn-lg")
      ))
    ),

    # Xəbərdarlıq
    fluidRow(column(12, uiOutput(ns("batch_info")))),

    # Progress
    fluidRow(column(12, uiOutput(ns("batch_progress")))),

    # Nəticələr cədvəli
    fluidRow(column(12, wellPanel(
      h4(icon("list"), "Generasiya Nəticələri"),
      DTOutput(ns("batch_results_table")),
      br(),
      div(class = "btn-toolbar",
        actionButton(ns("btn_batch_approve"), "Hamısını Təsdiq Et", icon = icon("check-double"), class = "btn-warning"),
        actionButton(ns("btn_batch_send_email"), "Hamısına E-poçt", icon = icon("paper-plane"), class = "btn-primary"),
        actionButton(ns("btn_batch_send_sms"), "Hamısına SMS", icon = icon("sms"), class = "btn-info")
      )
    )))
  )
}

# === 3. Tarixçə UI ===
parent_history_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(column(12, h2(icon("history"), "Məktub Tarixçəsi"), hr())),

    # Statistika kartları
    fluidRow(
      column(3, valueBoxOutput(ns("vb_total"), width = 12)),
      column(3, valueBoxOutput(ns("vb_approved"), width = 12)),
      column(3, valueBoxOutput(ns("vb_sent"), width = 12)),
      column(3, valueBoxOutput(ns("vb_failed"), width = 12))
    ),

    # Filtrlər
    fluidRow(
      column(3, selectInput(ns("hist_school"), "Məktəb:", choices = c("Bütün məktəblər" = ""))),
      column(2, selectInput(ns("hist_grade"), "Sinif:", choices = c("Hamısı" = "", setNames(1:11, 1:11)))),
      column(2, selectInput(ns("hist_month"), "Ay:", choices = c("Hamısı" = "", setNames(1:12, c(
        "Yanvar", "Fevral", "Mart", "Aprel", "May", "İyun",
        "İyul", "Avqust", "Sentyabr", "Oktyabr", "Noyabr", "Dekabr"
      ))))),
      column(2, selectInput(ns("hist_status"), "Status:", choices = c(
        "Hamısı" = "",
        "Qaralama" = "draft",
        "Redaktə edilib" = "edited",
        "Təsdiq edilib" = "approved",
        "Göndərilib" = "sent",
        "Uğursuz" = "failed"
      ))),
      column(3, div(style = "margin-top:25px",
        actionButton(ns("btn_refresh"), "Yenilə", icon = icon("sync"), class = "btn-info"),
        downloadButton(ns("btn_export"), "Excel", class = "btn-success")
      ))
    ),

    # Cədvəl
    fluidRow(column(12, wellPanel(
      DTOutput(ns("history_table"))
    ))),

    # Seçilmiş məktubun detalı
    fluidRow(column(12, uiOutput(ns("selected_letter_detail")))),

    # Göndərmə jurnalı
    fluidRow(column(12, wellPanel(
      h4(icon("clipboard-list"), "Göndərmə Jurnalı"),
      DTOutput(ns("delivery_log_table"))
    )))
  )
}
