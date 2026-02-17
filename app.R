# =============================================
# ARTI-2026: Təhsil İnstitutunun İdarəetmə Sistemi
# Əsas Tətbiq Giriş Nöqtəsi
# =============================================

# === Paketlərin yüklənməsi ===
library(shiny)
library(shinydashboard)

library(shinydashboardPlus)
library(bslib)
library(DBI)
library(RPostgres)
library(pool)
library(config)
library(dotenv)
library(shinyjs)
library(DT)
library(plotly)
library(ggplot2)
library(dplyr)
library(tidyr)
library(lubridate)
library(jsonlite)
library(httr2)
library(openssl)
library(jose)
library(logger)
library(waiter)

# === Mühit dəyişənlərini yüklə ===
dotenv::load_dot_env(".env")

# === Konfiqurasiyanı yüklə ===
app_config <- config::get(file = "config.yml")

# === Paylaşılan funksiyaları yüklə ===
source("R/constants.R")
source("R/utils.R")
source("R/db_connection.R")
source("R/auth.R")

# === Modulları yüklə ===
# Şagird modulu
source("modules/student/student_helpers.R")
source("modules/student/student_ui.R")
source("modules/student/student_server.R")

# Müəllim modulu
source("modules/teacher/teacher_helpers.R")
source("modules/teacher/teacher_ui.R")
source("modules/teacher/teacher_server.R")

# Qiymətləndirmə modulu
source("modules/assessment/item_bank.R")
source("modules/assessment/irt_engine.R")
source("modules/assessment/cat_engine.R")
source("modules/assessment/mst_engine.R")

# Kurikulum modulu
source("modules/curriculum/standards.R")
source("modules/curriculum/comparison.R")
source("modules/curriculum/alignment.R")

# Analitika modulu
source("modules/analytics/school_dashboard.R")
source("modules/analytics/reports.R")
source("modules/analytics/predictions.R")

# Sertifikasiya modulu
source("modules/certification/certification_helpers.R")
source("modules/certification/certification_ui.R")
source("modules/certification/certification_server.R")

# Tədris Resursları modulu
source("modules/resources/resources_helpers.R")
source("modules/resources/resources_ui.R")
source("modules/resources/resources_server.R")

# Tədqiqat modulu
source("modules/research/research_helpers.R")
source("modules/research/research_ui.R")
source("modules/research/research_server.R")

# Peşəkar İnkişaf modulu
source("modules/development/development_helpers.R")
source("modules/development/development_ui.R")
source("modules/development/development_server.R")

# Beynəlxalq Əməkdaşlıq modulu
source("modules/international/international_helpers.R")
source("modules/international/international_ui.R")
source("modules/international/international_server.R")

# AI İnteqrasiya
source("ai_integration/claude_api.R")
source("ai_integration/gpt_api.R")
source("ai_integration/response_parser.R")

# === Logger konfiqurasiyası ===
log_appender(appender_file(Sys.getenv("LOG_FILE", "logs/arti_2026.log")))

log_threshold(switch(
  app_config$app$log_level %||% "INFO",
  "DEBUG" = DEBUG,
  "INFO"  = INFO,
  "WARN"  = WARN,
  "ERROR" = ERROR,
  INFO
))

# =============================================
# UI - İstifadəçi İnterfeysi
# =============================================
ui <- dashboardPage(
  title = "ARTI-2026",

  # --- Header ---
  header = dashboardHeader(
    title = tags$span(
      tags$img(src = "img/logo.png", height = "30px", style = "margin-right: 10px;"),
      "ARTI-2026"
    ),
    titleWidth = 280,

    # Sağ tərəfdəki elementlər
    tags$li(
      class = "dropdown",
      tags$a(
        href = "#",
        class = "dropdown-toggle",
        `data-toggle` = "dropdown",
        icon("bell"),
        tags$span(class = "label label-warning", id = "notification_count", "0")
      )
    ),

    # İstifadəçi menyusu
    userOutput("user_panel")
  ),

  # --- Sidebar ---
  sidebar = dashboardSidebar(
    width = 280,

    # Axtarış
    sidebarSearchForm(
      textId = "sidebar_search",
      buttonId = "sidebar_search_btn",
      label = "Axtar..."
    ),

    sidebarMenu(
      id = "main_menu",

      # Ana səhifə
      menuItem(
        "Ana Səhifə",
        tabName = "home",
        icon = icon("home"),
        selected = TRUE
      ),

      # Şagird idarəetməsi
      menuItem(
        "Şagirdlər",
        tabName = "students",
        icon = icon("user-graduate"),
        menuSubItem("Siyahı", tabName = "student_list"),
        menuSubItem("Qeydiyyat", tabName = "student_register"),
        menuSubItem("Davamiyyət", tabName = "student_attendance"),
        menuSubItem("Akademik Profil", tabName = "student_profile"),
        menuSubItem("Fərdi İnkişaf Planı", tabName = "student_idp")
      ),

      # Müəllim idarəetməsi
      menuItem(
        "Müəllimlər",
        tabName = "teachers",
        icon = icon("chalkboard-teacher"),
        menuSubItem("Siyahı", tabName = "teacher_list"),
        menuSubItem("Dərs Yükü", tabName = "teacher_workload"),
        menuSubItem("Peşəkar İnkişaf", tabName = "teacher_development"),
        menuSubItem("Performans", tabName = "teacher_performance")
      ),

      # Qiymətləndirmə
      menuItem(
        "Qiymətləndirmə",
        tabName = "assessment",
        icon = icon("clipboard-check"),
        menuSubItem("Sual Bankı", tabName = "item_bank"),
        menuSubItem("IRT Analiz", tabName = "irt_analysis"),
        menuSubItem("CAT Test", tabName = "cat_test"),
        menuSubItem("MST Test", tabName = "mst_test"),
        menuSubItem("Nəticələr", tabName = "test_results")
      ),

      # Kurikulum
      menuItem(
        "Kurikulum",
        tabName = "curriculum",
        icon = icon("book"),
        menuSubItem("Standartlar", tabName = "standards"),
        menuSubItem("Beynəlxalq Müqayisə", tabName = "comparison"),
        menuSubItem("Uyğunluq Analizi", tabName = "alignment")
      ),

      # Analitika
      menuItem(
        "Analitika",
        tabName = "analytics",
        icon = icon("chart-line"),
        menuSubItem("Məktəb Dashboard", tabName = "school_dashboard"),
        menuSubItem("Hesabatlar", tabName = "reports"),
        menuSubItem("Prediktiv Analitika", tabName = "predictions")
      ),

      # Sertifikasiya
      menuItem(
        "Sertifikasiya",
        tabName = "certification",
        icon = icon("certificate"),
        menuSubItem("İşə Qəbul İmtahanları", tabName = "cert_recruitment"),
        menuSubItem("Sertifikasiya İmtahanları", tabName = "cert_exams"),
        menuSubItem("Sual Bazası", tabName = "cert_questions"),
        menuSubItem("Avtomatlaşdırma", tabName = "cert_automation")
      ),

      # Tədris Resursları
      menuItem(
        "Tədris Resursları",
        tabName = "resources",
        icon = icon("book-reader"),
        menuSubItem("Tədris Proqramları", tabName = "resources_programs"),
        menuSubItem("Rəqəmsal Kontent", tabName = "resources_digital"),
        menuSubItem("Dərsliklər", tabName = "resources_textbooks")
      ),

      # Tədqiqat
      menuItem(
        "Tədqiqat",
        tabName = "research",
        icon = icon("flask"),
        menuSubItem("Tədqiqatlar", tabName = "research_projects"),
        menuSubItem("Siyasət Analizi", tabName = "research_policy"),
        menuSubItem("Doktorantura", tabName = "research_doctoral")
      ),

      # DÜZƏLDİLMİŞ:
      menuItem(
        "Peşəkar İnkişaf",
        tabName = "development",
        icon = icon("chart-line"),
        menuSubItem("Müəllim Təlimləri", tabName = "dev_training"),
        menuSubItem("Onlayn Kurslar", tabName = "dev_courses"),
        menuSubItem("Mentorluq", tabName = "dev_mentorship")
      ),

      # Beynəlxalq Əməkdaşlıq
      menuItem(
        "Beynəlxalq",
        tabName = "international",
        icon = icon("globe"),
        menuSubItem("Olimpiadalar", tabName = "intl_olympiads"),
        menuSubItem("STEAM Layihələri", tabName = "intl_steam"),
        menuSubItem("Partnyor Proqramları", tabName = "intl_partners")
      ),

      # AI Köməkçi
      menuItem(
        "AI Köməkçi",
        tabName = "ai_assistant",
        icon = icon("robot"),
        badgeLabel = "YENİ",
        badgeColor = "green"
      ),

      # İdarəetmə
      menuItem(
        "İdarəetmə",
        tabName = "admin",
        icon = icon("cog"),
        menuSubItem("İstifadəçilər", tabName = "admin_users"),
        menuSubItem("Parametrlər", tabName = "admin_settings"),
        menuSubItem("Loglar", tabName = "admin_logs")
      )
    ),

    # Sidebar altlığı
    tags$div(
      class = "sidebar-footer",
      style = "position: absolute; bottom: 10px; width: 100%; text-align: center; color: #b8c7ce;",
      tags$small("ARTI-2026 v1.0.0"),
      tags$br(),
      tags$small("Azərbaycan Respublikası")
    )
  ),

  # --- Body ---
  body = dashboardBody(
    # Xüsusi CSS və JS
    tags$head(
      tags$link(rel = "stylesheet", type = "text/css", href = "css/custom.css"),
      tags$script(src = "js/custom.js"),
      tags$link(rel = "icon", type = "image/png", href = "img/logo.png")
    ),

    # ShinyJS aktivləşdir
    useShinyjs(),

    # Yükləmə ekranı
    useWaiter(),
    waiterShowOnLoad(
      html = tags$div(
        style = "text-align: center;",
        tags$img(src = "img/logo.png", height = "100px"),
        tags$h3("ARTI-2026 yüklənir...", style = "color: white; margin-top: 20px;"),
        tags$div(class = "progress", style = "width: 200px; margin: 20px auto;",
          tags$div(class = "progress-bar progress-bar-striped active",
                   role = "progressbar", style = "width: 100%")
        )
      ),
      color = "#2c3e50"
    ),

    # Tab məzmunları
    tabItems(
      # Ana səhifə
      tabItem(
        tabName = "home",
        fluidRow(
          # Statistika kartları
          valueBoxOutput("total_students_box", width = 3),
          valueBoxOutput("total_teachers_box", width = 3),
          valueBoxOutput("avg_performance_box", width = 3),
          valueBoxOutput("active_tests_box", width = 3)
        ),
        fluidRow(
          box(
            title = "Ümumi Performans Trendi",
            status = "primary",
            solidHeader = TRUE,
            width = 8,
            plotlyOutput("performance_trend_plot", height = "350px")
          ),
          box(
            title = "Son Fəaliyyətlər",
            status = "info",
            solidHeader = TRUE,
            width = 4,
            uiOutput("recent_activities")
          )
        ),
        fluidRow(
          box(
            title = "Fənn üzrə Orta Ballar",
            status = "success",
            solidHeader = TRUE,
            width = 6,
            plotlyOutput("subject_avg_plot", height = "300px")
          ),
          box(
            title = "Davamiyyət Statistikası",
            status = "warning",
            solidHeader = TRUE,
            width = 6,
            plotlyOutput("attendance_chart", height = "300px")
          )
        )
      ),

      # Şagird tabları
      tabItem(tabName = "student_list", student_list_ui("student_list")),
      tabItem(tabName = "student_register", student_register_ui("student_register")),
      tabItem(tabName = "student_attendance", student_attendance_ui("student_attendance")),
      tabItem(tabName = "student_profile", student_profile_ui("student_profile")),
      tabItem(tabName = "student_idp", student_idp_ui("student_idp")),

      # Müəllim tabları
      tabItem(tabName = "teacher_list", teacher_list_ui("teacher_list")),
      tabItem(tabName = "teacher_workload", teacher_workload_ui("teacher_workload")),
      tabItem(tabName = "teacher_development", teacher_development_ui("teacher_development")),
      tabItem(tabName = "teacher_performance", teacher_performance_ui("teacher_performance")),

      # Qiymətləndirmə tabları
      tabItem(tabName = "item_bank", item_bank_ui("item_bank")),
      tabItem(tabName = "irt_analysis", irt_analysis_ui("irt_analysis")),
      tabItem(tabName = "cat_test", cat_test_ui("cat_test")),
      tabItem(tabName = "mst_test", mst_test_ui("mst_test")),
      tabItem(tabName = "test_results", test_results_ui("test_results")),

      # Kurikulum tabları
      tabItem(tabName = "standards", standards_ui("standards")),
      tabItem(tabName = "comparison", comparison_ui("comparison")),
      tabItem(tabName = "alignment", alignment_ui("alignment")),

      # Analitika tabları
      tabItem(tabName = "school_dashboard", school_dashboard_ui("school_dashboard")),
      tabItem(tabName = "reports", reports_ui("reports")),
      tabItem(tabName = "predictions", predictions_ui("predictions")),

      # Sertifikasiya tabları
      tabItem(tabName = "cert_recruitment", cert_recruitment_ui("cert_recruitment")),
      tabItem(tabName = "cert_exams", cert_exams_ui("cert_exams")),
      tabItem(tabName = "cert_questions", cert_questions_ui("cert_questions")),
      tabItem(tabName = "cert_automation", cert_automation_ui("cert_automation")),

      # Tədris Resursları tabları
      tabItem(tabName = "resources_programs", resources_programs_ui("resources_programs")),
      tabItem(tabName = "resources_digital", resources_digital_ui("resources_digital")),
      tabItem(tabName = "resources_textbooks", resources_textbooks_ui("resources_textbooks")),

      # Tədqiqat tabları
      tabItem(tabName = "research_projects", research_projects_ui("research_projects")),
      tabItem(tabName = "research_policy", research_policy_ui("research_policy")),
      tabItem(tabName = "research_doctoral", research_doctoral_ui("research_doctoral")),

      # Peşəkar İnkişaf tabları
      tabItem(tabName = "dev_training", dev_training_ui("dev_training")),
      tabItem(tabName = "dev_courses", dev_courses_ui("dev_courses")),
      tabItem(tabName = "dev_mentorship", dev_mentorship_ui("dev_mentorship")),

      # Beynəlxalq Əməkdaşlıq tabları
      tabItem(tabName = "intl_olympiads", intl_olympiads_ui("intl_olympiads")),
      tabItem(tabName = "intl_steam", intl_steam_ui("intl_steam")),
      tabItem(tabName = "intl_partners", intl_partners_ui("intl_partners")),

      # AI Köməkçi
      tabItem(
        tabName = "ai_assistant",
        fluidRow(
          box(
            title = "AI Köməkçi",
            status = "success",
            solidHeader = TRUE,
            width = 12,
            fluidRow(
              column(4,
                selectInput("ai_task_type", "Tapşırıq Növü:",
                  choices = c(
                    "Sual Generasiyası" = "question_gen",
                    "Kurikulum Analizi" = "curriculum_analysis",
                    "Şagird Geri Bildirimi" = "student_feedback",
                    "Dərs Planı" = "lesson_plan",
                    "Hesabat Xülasəsi" = "report_summary"
                  )
                )
              ),
              column(4,
                selectInput("ai_provider", "AI Provayder:",
                  choices = c("Claude (Anthropic)" = "claude", "GPT (OpenAI)" = "gpt")
                )
              ),
              column(4,
                actionButton("ai_generate_btn", "Generasiya Et",
                  icon = icon("magic"), class = "btn-success btn-lg",
                  style = "margin-top: 25px; width: 100%;")
              )
            ),
            textAreaInput("ai_input", "Daxil edin:", rows = 5, width = "100%",
              placeholder = "Tapşırığınızı burada təsvir edin..."),
            tags$hr(),
            tags$h4("Nəticə:"),
            uiOutput("ai_result_output"),
            tags$br(),
            downloadButton("ai_download_btn", "Nəticəni Yüklə", class = "btn-info")
          )
        )
      ),

      # Admin tabları
      tabItem(
        tabName = "admin_users",
        fluidRow(
          box(
            title = "İstifadəçi İdarəetməsi",
            status = "danger",
            solidHeader = TRUE,
            width = 12,
            DTOutput("admin_users_table"),
            tags$hr(),
            actionButton("add_user_btn", "Yeni İstifadəçi", icon = icon("plus"), class = "btn-primary")
          )
        )
      ),

      tabItem(
        tabName = "admin_settings",
        fluidRow(
          box(
            title = "Sistem Parametrləri",
            status = "danger",
            solidHeader = TRUE,
            width = 12,
            uiOutput("system_settings_ui")
          )
        )
      ),

      tabItem(
        tabName = "admin_logs",
        fluidRow(
          box(
            title = "Sistem Logları",
            status = "danger",
            solidHeader = TRUE,
            width = 12,
            DTOutput("system_logs_table")
          )
        )
      )
    )
  ),

  # --- Footer ---
  footer = dashboardFooter(
    left = tags$span(
      "ARTI-2026 | Azərbaycan Respublikası Təhsil İnstitutu",
      tags$br(),
      tags$small("Müəllif hüquqları qorunur (c) 2026")
    ),
    right = tags$span(
      tags$small("Versiya 1.0.0 | "),
      tags$a(href = "docs/user_guide.md", "İstifadəçi Təlimatı")
    )
  )
)

# =============================================
# SERVER - Server Məntiqi
# =============================================
server <- function(input, output, session) {

  # === Verilənlər bazası bağlantısı ===
  db_pool <- create_db_pool()

  # Tətbiq bağlandıqda pool-u bağla
  onStop(function() {
    poolClose(db_pool)
    log_info("Verilənlər bazası bağlantısı bağlandı")
  })

  # === Autentifikasiya ===
  user_data <- reactiveVal(NULL)

  observe({
    token <- session$request$HTTP_AUTHORIZATION
    if (!is.null(token)) {
      user <- verify_jwt_token(gsub("Bearer ", "", token))
      user_data(user)
    }
  })

  # === İstifadəçi paneli ===
  output$user_panel <- renderUser({
    user <- user_data()
    if (is.null(user)) {
      dashboardUser(
        name = "Qonaq",
        image = "img/default_avatar.png",
        title = "Daxil olun",
        subtitle = "",
        footer = actionButton("login_btn", "Daxil ol", class = "btn-primary btn-block")
      )
    } else {
      dashboardUser(
        name = user$full_name,
        image = user$avatar %||% "img/default_avatar.png",
        title = user$role,
        subtitle = user$school_name,
        footer = actionButton("logout_btn", "Çıxış", class = "btn-danger btn-block")
      )
    }
  })

  # === Ana Səhifə Statistikaları ===
  output$total_students_box <- renderValueBox({
    count <- get_total_count(db_pool, "students")
    valueBox(
      value = format(count, big.mark = "."),
      subtitle = "Ümumi Şagird",
      icon = icon("user-graduate"),
      color = "aqua"
    )
  })

  output$total_teachers_box <- renderValueBox({
    count <- get_total_count(db_pool, "teachers")
    valueBox(
      value = format(count, big.mark = "."),
      subtitle = "Ümumi Müəllim",
      icon = icon("chalkboard-teacher"),
      color = "green"
    )
  })

  output$avg_performance_box <- renderValueBox({
    avg <- get_average_performance(db_pool)
    valueBox(
      value = paste0(round(avg, 1), "%"),
      subtitle = "Orta Performans",
      icon = icon("chart-line"),
      color = "yellow"
    )
  })

  output$active_tests_box <- renderValueBox({
    count <- get_active_tests_count(db_pool)
    valueBox(
      value = count,
      subtitle = "Aktiv Testlər",
      icon = icon("clipboard-check"),
      color = "red"
    )
  })

  # === Performans Trendi ===
  output$performance_trend_plot <- renderPlotly({
    data <- get_performance_trend(db_pool)
    plot_ly(data, x = ~month, y = ~avg_score, type = "scatter", mode = "lines+markers",
            line = list(color = "#3498db", width = 3),
            marker = list(size = 8, color = "#2980b9")) %>%
      layout(
        xaxis = list(title = "Ay"),
        yaxis = list(title = "Orta Bal", range = c(0, 100)),
        hovermode = "x unified"
      )
  })

  # === Son Fəaliyyətlər ===
  output$recent_activities <- renderUI({
    activities <- get_recent_activities(db_pool, limit = 10)
    tags$div(
      class = "activity-list",
      lapply(seq_len(nrow(activities)), function(i) {
        act <- activities[i, ]
        tags$div(
          class = "activity-item",
          style = "padding: 8px 0; border-bottom: 1px solid #eee;",
          tags$small(class = "text-muted", format(act$created_at, "%d.%m.%Y %H:%M")),
          tags$br(),
          tags$span(act$description)
        )
      })
    )
  })

  # === Fənn üzrə Orta Ballar ===
  output$subject_avg_plot <- renderPlotly({
    data <- get_subject_averages(db_pool)
    plot_ly(data, x = ~subject, y = ~avg_score, type = "bar",
            marker = list(color = "#2ecc71")) %>%
      layout(
        xaxis = list(title = "", tickangle = -45),
        yaxis = list(title = "Orta Bal", range = c(0, 100))
      )
  })

  # === Davamiyyət Statistikası ===
  output$attendance_chart <- renderPlotly({
    data <- get_attendance_stats(db_pool)
    plot_ly(data, labels = ~status, values = ~count, type = "pie",
            marker = list(colors = c("#2ecc71", "#e74c3c", "#f1c40f")),
            textinfo = "label+percent") %>%
      layout(showlegend = TRUE)
  })

  # === Modulları çağır ===
  # Şagird modulları
  student_list_server("student_list", db_pool, user_data)
  student_register_server("student_register", db_pool, user_data)
  student_attendance_server("student_attendance", db_pool, user_data)
  student_profile_server("student_profile", db_pool, user_data)
  student_idp_server("student_idp", db_pool, user_data)

  # Müəllim modulları
  teacher_list_server("teacher_list", db_pool, user_data)
  teacher_workload_server("teacher_workload", db_pool, user_data)
  teacher_development_server("teacher_development", db_pool, user_data)
  teacher_performance_server("teacher_performance", db_pool, user_data)

  # Qiymətləndirmə modulları
  item_bank_server("item_bank", db_pool, user_data)
  irt_analysis_server("irt_analysis", db_pool, user_data)
  cat_test_server("cat_test", db_pool, user_data)
  mst_test_server("mst_test", db_pool, user_data)
  test_results_server("test_results", db_pool, user_data)

  # Kurikulum modulları
  standards_server("standards", db_pool, user_data)
  comparison_server("comparison", db_pool, user_data)
  alignment_server("alignment", db_pool, user_data)

  # Analitika modulları
  school_dashboard_server("school_dashboard", db_pool, user_data)
  reports_server("reports", db_pool, user_data)
  predictions_server("predictions", db_pool, user_data)

  # Sertifikasiya modulları
  cert_recruitment_server("cert_recruitment", db_pool, user_data)
  cert_exams_server("cert_exams", db_pool, user_data)
  cert_questions_server("cert_questions", db_pool, user_data)
  cert_automation_server("cert_automation", db_pool, user_data)

  # Tədris Resursları modulları
  resources_programs_server("resources_programs", db_pool, user_data)
  resources_digital_server("resources_digital", db_pool, user_data)
  resources_textbooks_server("resources_textbooks", db_pool, user_data)

  # Tədqiqat modulları
  research_projects_server("research_projects", db_pool, user_data)
  research_policy_server("research_policy", db_pool, user_data)
  research_doctoral_server("research_doctoral", db_pool, user_data)

  # Peşəkar İnkişaf modulları
  dev_training_server("dev_training", db_pool, user_data)
  dev_courses_server("dev_courses", db_pool, user_data)
  dev_mentorship_server("dev_mentorship", db_pool, user_data)

  # Beynəlxalq Əməkdaşlıq modulları
  intl_olympiads_server("intl_olympiads", db_pool, user_data)
  intl_steam_server("intl_steam", db_pool, user_data)
  intl_partners_server("intl_partners", db_pool, user_data)

  # === AI Köməkçi ===
  ai_result <- reactiveVal(NULL)

  observeEvent(input$ai_generate_btn, {
    req(input$ai_input)

    showNotification("AI cavab hazırlayır...", type = "message", duration = NULL, id = "ai_loading")

    result <- tryCatch({
      if (input$ai_provider == "claude") {
        call_claude_api(
          task_type = input$ai_task_type,
          user_input = input$ai_input,
          config = app_config$ai
        )
      } else {
        call_gpt_api(
          task_type = input$ai_task_type,
          user_input = input$ai_input,
          config = app_config$ai
        )
      }
    }, error = function(e) {
      log_error("AI API xətası: {e$message}")
      list(success = FALSE, error = e$message)
    })

    removeNotification("ai_loading")
    ai_result(result)
  })

  output$ai_result_output <- renderUI({
    result <- ai_result()
    if (is.null(result)) {
      tags$p(class = "text-muted", "Nəticə burada görünəcək...")
    } else if (isFALSE(result$success)) {
      tags$div(class = "alert alert-danger", icon("exclamation-triangle"), result$error)
    } else {
      tags$div(
        class = "ai-result-container",
        style = "background: #f8f9fa; padding: 15px; border-radius: 5px; white-space: pre-wrap;",
        HTML(result$content)
      )
    }
  })

  output$ai_download_btn <- downloadHandler(
    filename = function() {
      paste0("arti_ai_result_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".txt")
    },
    content = function(file) {
      result <- ai_result()
      if (!is.null(result) && isTRUE(result$success)) {
        writeLines(result$content, file)
      }
    }
  )

  # === Yükləmə ekranını gizlə ===
  waiter_hide()

  log_info("ARTI-2026 uğurla başladıldı")
}

# =============================================
# Tətbiqi Başlat
# =============================================
shinyApp(
  ui = ui,
  server = server,
  options = list(
    host = Sys.getenv("APP_HOST", "0.0.0.0"),
    port = as.integer(Sys.getenv("APP_PORT", 3838))
  )
)

