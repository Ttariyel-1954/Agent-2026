# =============================================
# ARTI-2026: Şagird Modulu - UI Komponentləri
# =============================================

# --- Şagird Siyahısı UI ---
student_list_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(
      column(12, h2(icon("user-graduate"), "Şagird Siyahısı"), hr())
    ),
    fluidRow(
      column(3, selectInput(ns("filter_school"), "Məktəb:", choices = c("Hamısı" = ""))),
      column(2, selectInput(ns("filter_grade"), "Sinif:", choices = c("Hamısı" = "", setNames(1:11, paste0(1:11, "-ci sinif"))))),
      column(2, selectInput(ns("filter_section"), "Bölmə:", choices = c("Hamısı" = "", LETTERS[1:4]))),
      column(2, selectInput(ns("filter_status"), "Status:", choices = c("Hamısı" = "", "Aktiv" = "active", "Deaktiv" = "inactive"))),
      column(3, textInput(ns("search_text"), "Axtar:", placeholder = "Ad, soyad və ya FIN..."))
    ),
    fluidRow(
      column(12, div(class = "btn-toolbar",
        actionButton(ns("btn_add"), "Yeni Şagird", icon = icon("plus"), class = "btn-success"),
        downloadButton(ns("btn_export_excel"), "Excel", class = "btn-info"),
        downloadButton(ns("btn_export_pdf"), "PDF", class = "btn-warning"),
        actionButton(ns("btn_refresh"), "Yenilə", icon = icon("refresh"), class = "btn-default")
      ))
    ),
    br(),
    fluidRow(column(12, DTOutput(ns("student_table")))),
    uiOutput(ns("student_modal"))
  )
}

# --- Şagird Qeydiyyatı UI ---
student_register_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(column(12, h2(icon("user-plus"), "Şagird Qeydiyyatı"), hr())),
    fluidRow(
      column(6, wellPanel(
        h3(icon("id-card"), "Şəxsi Məlumatlar"),
        textInput(ns("first_name"), "Ad *", placeholder = "Şagirdin adı"),
        textInput(ns("last_name"), "Soyad *", placeholder = "Şagirdin soyadı"),
        textInput(ns("father_name"), "Ata adı *", placeholder = "Atasının adı"),
        dateInput(ns("birth_date"), "Doğum tarixi *", value = NULL, format = "dd.mm.yyyy", language = "az"),
        radioButtons(ns("gender"), "Cinsi *", choices = c("Oğlan" = "M", "Qız" = "F"), inline = TRUE),
        textInput(ns("fin_code"), "FİN kod *", placeholder = "7 simvollu FİN kodu"),
        textAreaInput(ns("address"), "Ünvan *", placeholder = "Yaşayış ünvanı", rows = 2),
        textInput(ns("phone"), "Telefon", placeholder = "+994 XX XXX XX XX"),
        fileInput(ns("photo"), "Şəkil", accept = c("image/jpeg", "image/png"))
      )),
      column(6,
        wellPanel(
          h3(icon("graduation-cap"), "Sinif Məlumatları"),
          selectInput(ns("class_grade"), "Sinif *", choices = c("Seçin..." = "", paste0(1:11, "-ci sinif"))),
          selectInput(ns("class_section"), "Bölmə *", choices = c("Seçin..." = "", LETTERS[1:4])),
          dateInput(ns("enrollment_date"), "Qəbul tarixi *", value = Sys.Date(), format = "dd.mm.yyyy"),
          textInput(ns("prev_school"), "Əvvəlki məktəb", placeholder = "Əvvəlki təhsil müəssisəsi"),
          textAreaInput(ns("notes"), "Qeydlər", placeholder = "Əlavə qeydlər...", rows = 2)
        ),
        wellPanel(
          h3(icon("people-roof"), "Valideyn Məlumatları"),
          h4("Ana"), textInput(ns("mother_name"), "Adı soyadı *"), textInput(ns("mother_phone"), "Telefonu *"),
          hr(), h4("Ata"), textInput(ns("father_fullname"), "Adı soyadı *"), textInput(ns("father_phone"), "Telefonu *")
        )
      )
    ),
    fluidRow(column(12, div(class = "text-center",
      actionButton(ns("btn_register"), "Qeydiyyatı Tamamla", icon = icon("check"), class = "btn-success btn-lg"),
      actionButton(ns("btn_clear"), "Formanı Təmizlə", icon = icon("eraser"), class = "btn-default btn-lg")
    ))),
    fluidRow(column(12, uiOutput(ns("registration_errors"))))
  )
}

# --- Davamiyyət UI ---
student_attendance_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(column(12, h2(icon("calendar-check"), "Davamiyyət İzləmə"), hr())),
    fluidRow(
      column(3, dateInput(ns("att_date"), "Tarix:", value = Sys.Date(), format = "dd.mm.yyyy")),
      column(3, selectInput(ns("att_grade"), "Sinif:", choices = c("Seçin..." = "", paste0(1:11, "-ci sinif")))),
      column(3, selectInput(ns("att_section"), "Bölmə:", choices = c("Seçin..." = "", LETTERS[1:4]))),
      column(3, actionButton(ns("btn_load"), "Yüklə", icon = icon("search"), class = "btn-primary", style = "margin-top:25px"))
    ),
    fluidRow(
      column(8, wellPanel(
        h3("Davamiyyət Cədvəli"),
        div(class = "btn-toolbar",
          actionButton(ns("btn_all_present"), "Hamısı İştirak", icon = icon("check-double"), class = "btn-success btn-sm"),
          actionButton(ns("btn_save_att"), "Yadda Saxla", icon = icon("save"), class = "btn-primary btn-sm")
        ),
        DTOutput(ns("attendance_table"))
      )),
      column(4,
        wellPanel(h3(icon("chart-pie"), "Günün Statistikası"), uiOutput(ns("daily_stats"))),
        wellPanel(h3(icon("calendar"), "Aylıq İcmal"), plotlyOutput(ns("monthly_chart"), height = "250px"))
      )
    ),
    fluidRow(column(12, wellPanel(
      h3(icon("file-alt"), "Davamiyyət Hesabatı"),
      fluidRow(
        column(4, dateRangeInput(ns("report_dates"), "Tarix aralığı:", start = Sys.Date()-30, end = Sys.Date(), format = "dd.mm.yyyy")),
        column(4, selectInput(ns("report_type"), "Hesabat növü:", choices = c("Sinif" = "class", "Şagird" = "student", "Fənn" = "subject"))),
        column(4, br(), downloadButton(ns("btn_download_report"), "Hesabatı Yüklə", class = "btn-info"))
      ),
      DTOutput(ns("report_table"))
    )))
  )
}

# --- Akademik Profil UI ---
student_profile_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(column(12, h2(icon("user-graduate"), "Şagird Profili"), hr())),
    fluidRow(
      column(6, selectizeInput(ns("selected_student"), "Şagird seçin:", choices = NULL, options = list(placeholder = "Axtar..."))),
      column(6, selectInput(ns("academic_year"), "Tədris ili:", choices = c("2025-2026", "2024-2025")))
    ),
    fluidRow(column(12, uiOutput(ns("student_card")))),
    fluidRow(
      column(3, wellPanel(class = "text-center", h4("Ortalama"), h2(textOutput(ns("gpa"))), textOutput(ns("gpa_label")))),
      column(3, wellPanel(class = "text-center", h4("Davamiyyət"), h2(textOutput(ns("att_percent"))), textOutput(ns("missed_days")))),
      column(3, wellPanel(class = "text-center", h4("Fənn Sayı"), h2(textOutput(ns("subject_count"))))),
      column(3, wellPanel(class = "text-center", h4("Sinifdəki Yeri"), h2(textOutput(ns("class_rank")))))
    ),
    # Tabset: Qiymətlər + AI Tutor
    tabsetPanel(id = ns("profile_tabs"),
      tabPanel("Qiymətlər", icon = icon("chart-bar"),
        br(),
        fluidRow(
          column(7, wellPanel(h3("Fənlər Üzrə Qiymətlər"), DTOutput(ns("grades_table")))),
          column(5, wellPanel(h3("Qiymət Qrafiki"), plotlyOutput(ns("grades_chart"), height = "300px")),
                 wellPanel(h3("Tərəqqi"), plotlyOutput(ns("progress_chart"), height = "250px")))
        )
      ),
      tabPanel("AI Tutor", icon = icon("robot"),
        br(),
        fluidRow(
          column(8,
            wellPanel(
              style = "background: #f8f9fa;",
              h3(icon("robot"), "AI Tutor — Fərdi Öyrənmə Köməkçisi"),
              tags$div(id = ns("tutor_chat_box"),
                style = "height: 420px; overflow-y: auto; border: 1px solid #ddd; border-radius: 8px; padding: 12px; background: #fff; margin-bottom: 12px;",
                uiOutput(ns("tutor_messages"))
              ),
              fluidRow(
                column(9, textInput(ns("tutor_input"), label = NULL,
                  placeholder = "Sualını yaz... (Məs: Kəsr ədədləri necə toplayım?)", width = "100%")),
                column(3,
                  tags$div(style = "display: flex; gap: 6px; margin-top: 25px;",
                    actionButton(ns("btn_tutor_send"), "Göndər", icon = icon("paper-plane"), class = "btn-info"),
                    actionButton(ns("btn_tutor_clear"), "", icon = icon("trash-alt"), class = "btn-default", title = "Söhbəti təmizlə")
                  )
                )
              ),
              tags$div(style = "margin-top: 8px;",
                tags$small(style = "color: #888;", "Nümunə suallar:"),
                tags$div(style = "display: flex; flex-wrap: wrap; gap: 6px; margin-top: 4px;",
                  actionLink(ns("tq1"), "Kəsr ədədləri necə toplayım?", class = "btn btn-outline-secondary btn-sm"),
                  actionLink(ns("tq2"), "Üçbucağın sahəsini necə tapım?", class = "btn btn-outline-secondary btn-sm"),
                  actionLink(ns("tq3"), "Fotosentez nədir?", class = "btn btn-outline-secondary btn-sm"),
                  actionLink(ns("tq4"), "Mənə test sualı ver", class = "btn btn-outline-secondary btn-sm")
                )
              )
            )
          ),
          column(4,
            wellPanel(
              h4(icon("info-circle"), "Fənn Seçimi"),
              selectInput(ns("tutor_subject"), "Fənn:", choices = SUBJECTS),
              hr(),
              h4(icon("history"), "Söhbət Tarixçəsi"),
              tags$small("Son söhbətlər burada göstərilir"),
              uiOutput(ns("tutor_history_list"))
            ),
            wellPanel(
              h4(icon("chart-pie"), "AI Tutor Statistikası"),
              uiOutput(ns("tutor_stats"))
            )
          )
        )
      ),
      tabPanel("Müəllim Baxışı", icon = icon("eye"), value = "teacher_view",
        br(),
        fluidRow(
          column(12, wellPanel(
            h3(icon("comments"), "Şagirdin AI Söhbət Tarixçəsi"),
            fluidRow(
              column(4, selectInput(ns("tv_subject_filter"), "Fənn filteri:", choices = c("Hamısı" = "", SUBJECTS))),
              column(4, dateRangeInput(ns("tv_dates"), "Tarix:", start = Sys.Date()-30, end = Sys.Date())),
              column(4, br(), actionButton(ns("btn_tv_load"), "Yüklə", icon = icon("search"), class = "btn-primary"))
            ),
            DTOutput(ns("tv_chat_table")),
            hr(),
            h4("Seçilmiş Söhbət"),
            uiOutput(ns("tv_chat_detail"))
          ))
        )
      )
    )
  )
}

# --- Fərdi İnkişaf Planı UI ---
# student_idp_ui və student_idp_server modules/student/student_idp.R faylına köçürülüb
