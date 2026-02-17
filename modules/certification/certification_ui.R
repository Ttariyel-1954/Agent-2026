# =============================================
# Sertifikasiya Modulu - UI
# =============================================

# --- İşə Qəbul İmtahanları ---
cert_recruitment_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(
      column(12, h2(icon("file-contract"), "İşə Qəbul İmtahanları"), hr())
    ),
    fluidRow(
      column(3,
        selectInput(ns("filter_status"), "Status:",
          choices = c("Hamısı" = "", "Planlaşdırılmış" = "planned",
                      "Aktiv" = "active", "Tamamlanmış" = "completed",
                      "Ləğv edilmiş" = "cancelled"))
      ),
      column(3,
        dateInput(ns("filter_date"), "Tarix:", value = NULL, language = "az")
      ),
      column(3,
        actionButton(ns("btn_refresh"), "Yenilə", icon = icon("refresh"), class = "btn-default",
                     style = "margin-top: 25px;")
      ),
      column(3,
        actionButton(ns("btn_add_exam"), "Yeni İmtahan", icon = icon("plus"), class = "btn-primary",
                     style = "margin-top: 25px;")
      )
    ),
    fluidRow(
      column(12, DTOutput(ns("recruitment_table")))
    ),
    uiOutput(ns("recruitment_modal"))
  )
}

# --- Sertifikasiya İmtahanları ---
cert_exams_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(
      column(12, h2(icon("certificate"), "Sertifikasiya İmtahanları"), hr())
    ),
    fluidRow(
      column(3,
        selectInput(ns("filter_cert_status"), "Status:",
          choices = c("Hamısı" = "", "Planlaşdırılmış" = "planned",
                      "Aktiv" = "active", "Tamamlanmış" = "completed"))
      ),
      column(3,
        selectInput(ns("filter_cert_level"), "Səviyyə:",
          choices = c("Hamısı" = "", CERTIFICATION_LEVELS))
      ),
      column(3,
        actionButton(ns("btn_cert_refresh"), "Yenilə", icon = icon("refresh"), class = "btn-default",
                     style = "margin-top: 25px;")
      ),
      column(3,
        actionButton(ns("btn_add_cert"), "Yeni Sertifikasiya", icon = icon("plus"), class = "btn-success",
                     style = "margin-top: 25px;")
      )
    ),
    fluidRow(
      column(12, DTOutput(ns("cert_exams_table")))
    ),
    fluidRow(
      column(12,
        box(
          title = "Nəticə Statistikası", status = "info", solidHeader = TRUE, width = 12,
          collapsible = TRUE, collapsed = TRUE,
          fluidRow(
            valueBoxOutput(ns("total_participants_box"), width = 3),
            valueBoxOutput(ns("pass_rate_box"), width = 3),
            valueBoxOutput(ns("avg_score_box"), width = 3),
            valueBoxOutput(ns("total_certs_box"), width = 3)
          )
        )
      )
    ),
    uiOutput(ns("cert_modal"))
  )
}

# --- Sual Bazası ---
cert_questions_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(
      column(12, h2(icon("question-circle"), "Sertifikasiya Sual Bazası"), hr())
    ),
    fluidRow(
      column(3,
        selectInput(ns("filter_q_exam"), "İmtahan:", choices = c("Hamısı" = ""))
      ),
      column(3,
        selectInput(ns("filter_q_difficulty"), "Çətinlik:",
          choices = c("Hamısı" = "", DIFFICULTY_LEVELS))
      ),
      column(3,
        selectInput(ns("filter_q_type"), "Sual Növü:",
          choices = c("Hamısı" = "", "Çoxseçimli" = "mcq",
                      "Doğru/Yanlış" = "true_false", "Qısa Cavab" = "short_answer"))
      ),
      column(3,
        actionButton(ns("btn_add_question"), "Yeni Sual", icon = icon("plus"), class = "btn-primary",
                     style = "margin-top: 25px;")
      )
    ),
    fluidRow(
      column(12, DTOutput(ns("questions_table")))
    ),
    fluidRow(
      column(6,
        actionButton(ns("btn_import_questions"), "İdxal et", icon = icon("upload"), class = "btn-info")
      ),
      column(6,
        downloadButton(ns("btn_export_questions"), "İxrac et", class = "btn-warning")
      )
    ),
    uiOutput(ns("question_modal"))
  )
}

# --- Avtomatlaşdırma ---
cert_automation_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(
      column(12, h2(icon("robot"), "İmtahan Avtomatlaşdırma"), hr())
    ),
    fluidRow(
      box(
        title = "Avtomatik Planlaşdırma", status = "primary", solidHeader = TRUE, width = 6,
        selectInput(ns("auto_exam_type"), "İmtahan Növü:", choices = EXAM_TYPES),
        selectInput(ns("auto_subject"), "Fənn:", choices = c("Seçin" = "", SUBJECTS)),
        numericInput(ns("auto_question_count"), "Sual Sayı:", value = 50, min = 10, max = 200),
        numericInput(ns("auto_duration"), "Müddət (dəq):", value = 120, min = 15, max = 480),
        dateInput(ns("auto_date"), "Tarix:", language = "az"),
        actionButton(ns("btn_auto_schedule"), "Planlaşdır", icon = icon("calendar-check"),
                     class = "btn-success btn-block")
      ),
      box(
        title = "Avtomatik Nəticə Qiymətləndirmə", status = "success", solidHeader = TRUE, width = 6,
        selectInput(ns("eval_exam"), "İmtahan Seçin:", choices = c("Seçin" = "")),
        tags$hr(),
        actionButton(ns("btn_auto_evaluate"), "Qiymətləndir", icon = icon("check-double"),
                     class = "btn-primary btn-block"),
        tags$hr(),
        uiOutput(ns("evaluation_summary"))
      )
    )
  )
}
