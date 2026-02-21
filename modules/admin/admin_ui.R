# =============================================
# ARTI-2026: Admin Paneli UI
# İstifadəçi idarəetməsi, parametrlər, audit loglar
# =============================================

# === İstifadəçi İdarəetməsi UI ===
admin_users_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(
      column(12, h2(icon("users-cog"), "İstifadəçi İdarəetməsi"), hr())
    ),

    # Filtrlər
    fluidRow(
      column(3,
        textInput(ns("search"), "Axtar:",
                  placeholder = "Ad, e-poçt və ya istifadəçi adı...")
      ),
      column(2,
        selectInput(ns("filter_role"), "Rol:",
          choices = c("Hamısı" = "", "Admin" = "admin", "Müəllim" = "teacher",
                      "Şagird" = "student", "Valideyn" = "parent", "Müfəttiş" = "inspector")
        )
      ),
      column(2,
        selectInput(ns("filter_status"), "Status:",
          choices = c("Hamısı" = "", "Aktiv" = "active", "Deaktiv" = "inactive")
        )
      ),
      column(5,
        div(class = "btn-toolbar", style = "margin-top: 25px;",
          actionButton(ns("btn_add"), "Yeni İstifadəçi",
                       icon = icon("plus"), class = "btn-success"),
          actionButton(ns("btn_refresh"), "Yenilə",
                       icon = icon("refresh"), class = "btn-default"),
          downloadButton(ns("btn_export"), "İxrac", class = "btn-warning")
        )
      )
    ),

    # Statistika
    fluidRow(
      valueBoxOutput(ns("total_users_box"), width = 3),
      valueBoxOutput(ns("active_users_box"), width = 3),
      valueBoxOutput(ns("admin_count_box"), width = 3),
      valueBoxOutput(ns("teacher_count_box"), width = 3)
    ),

    # Cədvəl
    fluidRow(
      box(
        title = "İstifadəçi Siyahısı",
        status = "primary",
        solidHeader = TRUE,
        width = 12,
        DTOutput(ns("users_table"))
      )
    )
  )
}

# === Sistem Parametrləri UI ===
admin_settings_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(
      column(12, h2(icon("cogs"), "Sistem Parametrləri"), hr())
    ),

    fluidRow(
      # Ümumi parametrlər
      box(
        title = "Ümumi Parametrlər",
        status = "primary",
        solidHeader = TRUE,
        width = 6,
        textInput(ns("app_name"), "Tətbiq Adı:", value = "ARTI-2026"),
        selectInput(ns("default_language"), "Standart Dil:",
          choices = c("Azərbaycan" = "az", "İngilis" = "en", "Rus" = "ru"),
          selected = "az"
        ),
        textInput(ns("academic_year"), "Akademik İl:", value = get_academic_year()),
        selectInput(ns("grading_system"), "Qiymətləndirmə Sistemi:",
          choices = c("100 ballıq" = "100", "5 ballıq" = "5", "ECTS" = "ects"),
          selected = "100"
        )
      ),

      # Təhlükəsizlik
      box(
        title = "Təhlükəsizlik Parametrləri",
        status = "danger",
        solidHeader = TRUE,
        width = 6,
        numericInput(ns("max_login_attempts"), "Maks. Giriş Cəhdi:",
                     value = 5, min = 1, max = 20),
        numericInput(ns("session_timeout"), "Sessiya Vaxtı (dəq):",
                     value = 30, min = 5, max = 480),
        numericInput(ns("password_min_length"), "Min. Şifrə Uzunluğu:",
                     value = 8, min = 6, max = 20),
        checkboxInput(ns("require_2fa"), "İki faktorlu doğrulama tələb et",
                      value = FALSE)
      )
    ),

    fluidRow(
      # AI parametrləri
      box(
        title = "AI Parametrləri",
        status = "info",
        solidHeader = TRUE,
        width = 6,
        numericInput(ns("ai_daily_limit"), "Gündəlik AI Limit:",
                     value = 50, min = 1, max = 1000),
        selectInput(ns("ai_default_model"), "Standart AI Model:",
          choices = c("Claude" = "claude", "GPT" = "gpt"),
          selected = "claude"
        ),
        numericInput(ns("ai_max_tokens"), "Maks. Token:",
                     value = 2000, min = 100, max = 10000)
      ),

      # Texniki xidmət
      box(
        title = "Texniki Xidmət",
        status = "warning",
        solidHeader = TRUE,
        width = 6,
        checkboxInput(ns("maintenance_mode"), "Texniki Xidmət Rejimi",
                      value = FALSE),
        textAreaInput(ns("maintenance_message"), "Texniki Xidmət Mesajı:",
                      value = "Sistem texniki xidmət rejimindədir. Zəhmət olmasa bir az sonra yenidən cəhd edin.",
                      rows = 3)
      )
    ),

    fluidRow(
      column(12,
        div(class = "btn-toolbar",
          actionButton(ns("btn_save"), "Yadda Saxla",
                       icon = icon("save"), class = "btn-success btn-lg"),
          actionButton(ns("btn_reset"), "Sıfırla",
                       icon = icon("undo"), class = "btn-default btn-lg")
        )
      )
    )
  )
}

# === Audit Log UI ===
admin_logs_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(
      column(12, h2(icon("history"), "Audit Logları"), hr())
    ),

    # Filtrlər
    fluidRow(
      column(3,
        selectInput(ns("filter_action"), "Əməliyyat:",
          choices = c("Hamısı" = "")
        )
      ),
      column(3,
        selectInput(ns("filter_user"), "İstifadəçi:",
          choices = c("Hamısı" = "")
        )
      ),
      column(2,
        dateInput(ns("date_from"), "Başlanğıc:", value = Sys.Date() - 30,
                  language = "az")
      ),
      column(2,
        dateInput(ns("date_to"), "Son:", value = Sys.Date(),
                  language = "az")
      ),
      column(2,
        div(style = "margin-top: 25px;",
          actionButton(ns("btn_filter"), "Filtrə",
                       icon = icon("filter"), class = "btn-primary"),
          downloadButton(ns("btn_export"), "CSV", class = "btn-warning")
        )
      )
    ),

    # Statistika
    fluidRow(
      valueBoxOutput(ns("total_logs_box"), width = 4),
      valueBoxOutput(ns("today_logs_box"), width = 4),
      valueBoxOutput(ns("unique_users_box"), width = 4)
    ),

    # Log cədvəli
    fluidRow(
      box(
        title = "Log Qeydləri",
        status = "info",
        solidHeader = TRUE,
        width = 12,
        DTOutput(ns("logs_table"))
      )
    )
  )
}
