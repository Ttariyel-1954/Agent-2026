# =============================================
# ARTI-2026: Müəllim Modulu - UI Komponentləri
# =============================================

# --- Müəllim Siyahısı UI ---
teacher_list_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(column(12, h2(icon("chalkboard-teacher"), "Müəllim Siyahısı"), hr())),
    fluidRow(
      column(2, selectInput(ns("filter_subject"), "Fənn:", choices = c("Hamısı" = "", SUBJECTS))),
      column(2, selectInput(ns("filter_category"), "Kateqoriya:", choices = c("Hamısı" = "", TEACHER_CATEGORIES))),
      column(2, selectInput(ns("filter_school"), "Məktəb:", choices = c("Hamısı" = ""))),
      column(2, selectInput(ns("filter_honorary"), "Fəxri ad:", choices = c("Hamısı" = "", HONORARY_TITLES))),
      column(2, selectInput(ns("filter_ict"), "İKT səviyyəsi:", choices = c("Hamısı" = "", ICT_COMPETENCY_LEVELS))),
      column(2, textInput(ns("search_text"), "Axtar:", placeholder = "Ad, soyad..."))
    ),
    fluidRow(column(12, div(class = "btn-toolbar",
      actionButton(ns("btn_add"), "Yeni Müəllim", icon = icon("plus"), class = "btn-success"),
      actionButton(ns("btn_edit"), "Redaktə", icon = icon("edit"), class = "btn-primary"),
      actionButton(ns("btn_delete"), "Sil", icon = icon("trash"), class = "btn-danger"),
      downloadButton(ns("btn_export"), "Excel-ə İxrac", class = "btn-info")
    ))),
    br(),
    fluidRow(column(12, DTOutput(ns("teacher_table")))),
    uiOutput(ns("teacher_modal"))
  )
}

# --- Müəllim İş Yükü UI ---
teacher_workload_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(column(12, h2(icon("calendar-alt"), "Müəllim İş Yükü"), hr())),
    fluidRow(
      column(4, selectInput(ns("selected_teacher"), "Müəllim:", choices = NULL)),
      column(4, selectInput(ns("semester"), "Yarımil:", choices = c("I yarımil" = 1, "II yarımil" = 2))),
      column(4, selectInput(ns("year"), "Tədris ili:", choices = c("2025-2026", "2024-2025")))
    ),
    fluidRow(
      column(3, wellPanel(h4("Ümumi Saat"), h2(textOutput(ns("total_hours")), class = "text-center"), helpText("Həftəlik dərs saatı"))),
      column(3, wellPanel(h4("Minimum"), h2("18 saat", class = "text-center text-info"), helpText("Həftəlik minimum"))),
      column(3, wellPanel(h4("Maksimum"), h2("36 saat", class = "text-center text-warning"), helpText("Həftəlik maksimum"))),
      column(3, wellPanel(h4("Status"), uiOutput(ns("workload_status")), helpText("İş yükü vəziyyəti")))
    ),
    fluidRow(column(12, wellPanel(
      h4(icon("table"), "Həftəlik Dərs Cədvəli"),
      uiOutput(ns("schedule_grid")),
      actionButton(ns("btn_save"), "Yadda Saxla", icon = icon("save"), class = "btn-success"),
      actionButton(ns("btn_clear"), "Təmizlə", icon = icon("eraser"), class = "btn-warning")
    ))),
    fluidRow(
      column(6, wellPanel(h4("Fənn Bölgüsü"), plotlyOutput(ns("subject_chart"), height = "300px"))),
      column(6, wellPanel(h4("Günlər Üzrə"), plotlyOutput(ns("daily_chart"), height = "300px")))
    )
  )
}

# --- Peşəkar İnkişaf UI ---
teacher_development_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(column(12, h2(icon("graduation-cap"), "Peşəkar İnkişaf"), hr())),
    fluidRow(
      column(6, selectInput(ns("selected_teacher"), "Müəllim:", choices = NULL)),
      column(6, dateRangeInput(ns("date_range"), "Tarix:", start = Sys.Date()-365, end = Sys.Date(), separator = " - "))
    ),
    fluidRow(
      column(3, wellPanel(h4("Təlimlər"), h2(textOutput(ns("training_count")), class = "text-center text-primary"))),
      column(3, wellPanel(h4("Sertifikatlar"), h2(textOutput(ns("cert_count")), class = "text-center text-success"))),
      column(3, wellPanel(h4("Təlim Saatları"), h2(textOutput(ns("training_hours")), class = "text-center text-info"))),
      column(3, wellPanel(h4("Attestasiya"), h2(textOutput(ns("next_attestation")), class = "text-center text-warning")))
    ),
    fluidRow(column(12,
      h4("Təlim Tarixçəsi"),
      actionButton(ns("btn_add_training"), "Yeni Təlim", icon = icon("plus"), class = "btn-success"),
      br(), br(), DTOutput(ns("training_table"))
    )),
    fluidRow(column(12,
      h4("Sertifikatlar"),
      actionButton(ns("btn_add_cert"), "Yeni Sertifikat", icon = icon("plus"), class = "btn-success"),
      br(), br(), DTOutput(ns("cert_table"))
    ))
  )
}

# --- Performans UI ---
teacher_performance_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(column(12, h2(icon("chart-line"), "Performans Qiymətləndirməsi"), hr())),
    fluidRow(
      column(4, selectInput(ns("selected_teacher"), "Müəllim:", choices = NULL)),
      column(4, selectInput(ns("period"), "Dövr:", choices = c("Cari yarımil" = "current", "Tam il" = "full_year"))),
      column(4, div(style = "margin-top:25px", downloadButton(ns("btn_report"), "Hesabat Yarat", class = "btn-primary")))
    ),
    fluidRow(
      column(3, wellPanel(h4(icon("users"), "Şagird Nəticələri"), h2(textOutput(ns("kpi_students")), class = "text-center"))),
      column(3, wellPanel(h4(icon("clock"), "Davamiyyət"), h2(textOutput(ns("kpi_attendance")), class = "text-center"))),
      column(3, wellPanel(h4(icon("award"), "İnkişaf"), h2(textOutput(ns("kpi_development")), class = "text-center"))),
      column(3, wellPanel(h4(icon("star"), "Ümumi"), h2(textOutput(ns("kpi_overall")), class = "text-center")))
    ),
    fluidRow(
      column(6, wellPanel(plotlyOutput(ns("outcomes_chart"), height = "300px"))),
      column(6, wellPanel(plotlyOutput(ns("trend_chart"), height = "300px")))
    ),
    fluidRow(column(12, wellPanel(
      h4(icon("bullseye"), "TALIS Göstəriciləri"),
      fluidRow(
        column(6, plotlyOutput(ns("talis_radar_chart"), height = "350px")),
        column(6,
          h5("Həftəlik Yük Bölgüsü"),
          plotlyOutput(ns("weekly_load_chart"), height = "150px"),
          hr(),
          h5("Əlavə Göstəricilər"),
          uiOutput(ns("talis_extra_info"))
        )
      )
    ))),
    fluidRow(
      column(6, wellPanel(
        h4(icon("trophy"), "Mükafatlar"),
        DTOutput(ns("awards_table"))
      )),
      column(6, wellPanel(
        h4(icon("book"), "Nəşrlər"),
        DTOutput(ns("publications_table"))
      ))
    ),
    fluidRow(column(12, wellPanel(
      h4("Qiymətləndirmə Formu"),
      fluidRow(
        column(4, sliderInput(ns("eval_teaching"), "Tədris keyfiyyəti", 1, 5, 3, step = 0.5)),
        column(4, sliderInput(ns("eval_classroom"), "Şagird cəlbi", 1, 5, 3, step = 0.5)),
        column(4, sliderInput(ns("eval_parent"), "Ünsiyyət", 1, 5, 3, step = 0.5))
      ),
      fluidRow(
        column(4, sliderInput(ns("eval_professional"), "Peşəkar inkişaf", 1, 5, 3, step = 0.5)),
        column(4, sliderInput(ns("eval_innovation"), "İnnovasiya", 1, 5, 3, step = 0.5)),
        column(4)
      ),
      textAreaInput(ns("eval_notes"), "Qeydlər:", rows = 3, width = "100%"),
      actionButton(ns("btn_save_eval"), "Yadda Saxla", icon = icon("save"), class = "btn-success")
    )))
  )
}
