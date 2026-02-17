# =============================================
# Peşəkar İnkişaf Modulu - UI
# =============================================

# --- Müəllim Təlimləri ---
dev_training_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(
      column(12, h2(icon("chalkboard"), "Müəllim Təlimləri"), hr())
    ),
    fluidRow(
      column(3,
        selectInput(ns("filter_train_type"), "Təlim Növü:",
          choices = c("Hamısı" = "", "Müəllim Təlimi" = "muellim_telimi",
                      "Seminar" = "seminar", "Workshop" = "workshop",
                      "Konfrans" = "konfrans"))
      ),
      column(3,
        selectInput(ns("filter_train_status"), "Status:",
          choices = c("Hamısı" = "", "Planlaşdırılmış" = "planned",
                      "Aktiv" = "active", "Tamamlanmış" = "completed",
                      "Ləğv edilmiş" = "cancelled"))
      ),
      column(3,
        actionButton(ns("btn_train_refresh"), "Yenilə", icon = icon("refresh"),
                     class = "btn-default", style = "margin-top: 25px;")
      ),
      column(3,
        actionButton(ns("btn_add_training"), "Yeni Təlim", icon = icon("plus"),
                     class = "btn-primary", style = "margin-top: 25px;")
      )
    ),
    fluidRow(
      column(12, DTOutput(ns("training_table")))
    ),
    fluidRow(
      column(12,
        box(
          title = "Təlim Statistikası", status = "info", solidHeader = TRUE,
          width = 12, collapsible = TRUE, collapsed = TRUE,
          fluidRow(
            valueBoxOutput(ns("total_trainings_box"), width = 3),
            valueBoxOutput(ns("total_hours_box"), width = 3),
            valueBoxOutput(ns("active_trainings_box"), width = 3),
            valueBoxOutput(ns("cert_count_box"), width = 3)
          )
        )
      )
    ),
    uiOutput(ns("training_modal"))
  )
}

# --- Onlayn Kurslar ---
dev_courses_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(
      column(12, h2(icon("laptop-code"), "Onlayn Kurslar"), hr())
    ),
    fluidRow(
      column(3,
        textInput(ns("search_course"), "Axtar:", placeholder = "Kurs adı...")
      ),
      column(3,
        selectInput(ns("filter_course_status"), "Status:",
          choices = c("Hamısı" = "", COURSE_STATUS))
      ),
      column(3,
        selectInput(ns("filter_course_level"), "Səviyyə:",
          choices = c("Hamısı" = "", DIFFICULTY_LEVELS))
      ),
      column(3,
        actionButton(ns("btn_add_course"), "Yeni Kurs", icon = icon("plus"),
                     class = "btn-success", style = "margin-top: 25px;")
      )
    ),
    fluidRow(
      column(12, DTOutput(ns("courses_table")))
    ),
    fluidRow(
      column(12,
        box(
          title = "Kurs Qeydiyyatları", status = "success", solidHeader = TRUE,
          width = 12, collapsible = TRUE, collapsed = TRUE,
          DTOutput(ns("enrollments_table"))
        )
      )
    ),
    uiOutput(ns("course_modal"))
  )
}

# --- Mentorluq ---
dev_mentorship_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(
      column(12, h2(icon("hands-helping"), "Mentorluq Proqramları"), hr())
    ),
    fluidRow(
      column(4,
        selectInput(ns("filter_mentor_status"), "Status:",
          choices = c("Hamısı" = "", "Aktiv" = "active",
                      "Tamamlanmış" = "completed"))
      ),
      column(4,
        actionButton(ns("btn_mentor_refresh"), "Yenilə", icon = icon("refresh"),
                     class = "btn-default", style = "margin-top: 25px;")
      ),
      column(4,
        actionButton(ns("btn_add_mentor_program"), "Yeni Proqram", icon = icon("plus"),
                     class = "btn-primary", style = "margin-top: 25px;")
      )
    ),
    fluidRow(
      column(12,
        box(
          title = "Proqramlar", status = "primary", solidHeader = TRUE, width = 12,
          DTOutput(ns("mentor_programs_table"))
        )
      )
    ),
    fluidRow(
      column(12,
        box(
          title = "Mentor-Mentee Cütləri", status = "success", solidHeader = TRUE, width = 12,
          DTOutput(ns("mentor_pairs_table")),
          tags$hr(),
          fluidRow(
            column(6,
              actionButton(ns("btn_add_pair"), "Yeni Cüt", icon = icon("link"),
                           class = "btn-info")
            ),
            column(6,
              actionButton(ns("btn_auto_match"), "Avtomatik Uyğunlaşdır", icon = icon("magic"),
                           class = "btn-warning")
            )
          )
        )
      )
    ),
    uiOutput(ns("mentorship_modal"))
  )
}
