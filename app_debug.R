library(shiny)
library(shinydashboard)
library(shinydashboardPlus)
library(DBI)
library(RPostgres)
library(pool)
library(dotenv)
library(shinyjs)
library(DT)
library(plotly)
library(ggplot2)
library(dplyr)
library(tidyr)
library(lubridate)
library(jsonlite)
library(logger)

dotenv::load_dot_env(".env")
source("R/constants.R")
source("R/utils.R")
source("R/db_connection.R")

source("modules/student/student_helpers.R")
source("modules/student/student_ui.R")
source("modules/student/student_server.R")
source("modules/teacher/teacher_helpers.R")
source("modules/teacher/teacher_ui.R")
source("modules/teacher/teacher_server.R")

log_appender(appender_console); log_threshold(INFO)
ui <- dashboardPage(title = "ARTI-2026 DEBUG",
  header = dashboardHeader(title = "ARTI-2026 DEBUG", titleWidth = 280),
  sidebar = dashboardSidebar(width = 280, sidebarMenu(id = "main_menu",
      menuItem("Ana Səhifə", tabName = "home", icon = icon("home"), selected = TRUE),
      menuItem("Şagirdlər", icon = icon("user-graduate"),
        menuSubItem("Siyahı", tabName = "student_list"),
        menuSubItem("Qeydiyyat", tabName = "student_register"),
        menuSubItem("Davamiyyət", tabName = "student_attendance"),
        menuSubItem("Akademik Profil", tabName = "student_profile"),
        menuSubItem("Fərdi İnkişaf Planı", tabName = "student_idp")),
      menuItem("Müəllimlər", icon = icon("chalkboard-teacher"),
        menuSubItem("Siyahı", tabName = "teacher_list"),
        menuSubItem("Dərs Yükü", tabName = "teacher_workload"),
        menuSubItem("Peşəkar İnkişaf", tabName = "teacher_development"),
        menuSubItem("Performans", tabName = "teacher_performance"))
  )),
  body = dashboardBody(
    useShinyjs(),
    tabItems(
      tabItem(tabName = "home", h2("ARTI-2026 DEBUG"), valueBoxOutput("db_test_box", width = 4)),
      tabItem(tabName = "student_list", student_list_ui("student_list")),
      tabItem(tabName = "student_register", student_register_ui("student_register")),
      tabItem(tabName = "student_attendance", student_attendance_ui("student_attendance")),
      tabItem(tabName = "student_profile", student_profile_ui("student_profile")),
      tabItem(tabName = "student_idp", student_idp_ui("student_idp")),
      tabItem(tabName = "teacher_list", teacher_list_ui("teacher_list")),
      tabItem(tabName = "teacher_workload", teacher_workload_ui("teacher_workload")),
      tabItem(tabName = "teacher_development", teacher_development_ui("teacher_development")),
      tabItem(tabName = "teacher_performance", teacher_performance_ui("teacher_performance"))
  )),
  footer = dashboardFooter(left = "ARTI-2026 DEBUG")
)
server <- function(input, output, session) {
  db_pool <- create_db_pool()
  onStop(function() poolClose(db_pool))
  user_data <- reactiveVal(list(id = "test", sub = "test", role = "admin"))
  output$db_test_box <- renderValueBox({
    count <- get_total_count(db_pool, "teachers")
    valueBox(count, "Müəllim", icon = icon("users"), color = "green")
  })
  student_list_server("student_list", db_pool, user_data)
  student_register_server("student_register", db_pool, user_data)
  student_attendance_server("student_attendance", db_pool, user_data)
  student_profile_server("student_profile", db_pool, user_data)
  student_idp_server("student_idp", db_pool, user_data)
  teacher_list_server("teacher_list", db_pool, user_data)
  teacher_workload_server("teacher_workload", db_pool, user_data)
  teacher_development_server("teacher_development", db_pool, user_data)
  teacher_performance_server("teacher_performance", db_pool, user_data)
}
shinyApp(ui, server, options = list(host = "0.0.0.0", port = 4040L))
