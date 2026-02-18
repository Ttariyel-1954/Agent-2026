library(shiny)
library(shinydashboard)
library(shinydashboardPlus)
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

dotenv::load_dot_env(".env")
app_config <- config::get(file = "config.yml")
source("R/constants.R")
source("R/utils.R")
source("R/db_connection.R")
source("R/auth.R")

# YALNIZ müəllim modulu
source("modules/teacher/teacher_helpers.R")
source("modules/teacher/teacher_ui.R")
source("modules/teacher/teacher_server.R")

ui <- dashboardPage(
  title = "TEST",
  header = dashboardHeader(title = "ARTI TEST"),
  sidebar = dashboardSidebar(
    sidebarMenu(id = "main_menu",
      menuItem("Ana Səhifə", tabName = "home", icon = icon("home"), selected = TRUE),
      menuItem("Müəllimlər", icon = icon("chalkboard-teacher"),
        menuSubItem("Siyahı", tabName = "teacher_list"),
        menuSubItem("Performans", tabName = "teacher_performance")
      )
    )
  ),
  body = dashboardBody(
    useShinyjs(),
    tabItems(
      tabItem(tabName = "home", h2("Ana Səhifə işləyir")),
      tabItem(tabName = "teacher_list", teacher_list_ui("teacher_list")),
      tabItem(tabName = "teacher_performance", teacher_performance_ui("teacher_performance"))
    )
  )
)

server <- function(input, output, session) {
  db_pool <- create_db_pool()
  onStop(function() { poolClose(db_pool) })
  user_data <- reactiveVal(NULL)
  teacher_list_server("teacher_list", db_pool, user_data)
  teacher_performance_server("teacher_performance", db_pool, user_data)
}

shinyApp(ui, server, options = list(port = 4040))
