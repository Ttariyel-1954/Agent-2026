library(shiny)
library(shinydashboard)
library(shinydashboardPlus)
library(shinyjs)
library(waiter)

ui <- dashboardPage(
  title = "ARTI-2026",
  header = dashboardHeader(
    title = "ARTI-2026",
    titleWidth = 280,
    userOutput("user_panel")
  ),
  sidebar = dashboardSidebar(
    width = 280,
    sidebarMenu(id = "main_menu",
      menuItem("Ana Səhifə", tabName = "home", icon = icon("home"), selected = TRUE),
      menuItem("Müəllimlər", icon = icon("chalkboard-teacher"),
        menuSubItem("Siyahı", tabName = "teacher_list"),
        menuSubItem("Performans", tabName = "teacher_performance")
      ),
      menuItem("Şagirdlər", icon = icon("user-graduate"),
        menuSubItem("Siyahı", tabName = "student_list"),
        menuSubItem("Qeydiyyat", tabName = "student_register")
      )
    )
  ),
  body = dashboardBody(
    useShinyjs(),
    useWaiter(),
    tabItems(
      tabItem(tabName = "home", h2("Ana Səhifə")),
      tabItem(tabName = "teacher_list", h2("Müəllim Siyahısı İŞLƏYİR")),
      tabItem(tabName = "teacher_performance", h2("Performans İŞLƏYİR")),
      tabItem(tabName = "student_list", h2("Şagird Siyahısı İŞLƏYİR")),
      tabItem(tabName = "student_register", h2("Qeydiyyat İŞLƏYİR"))
    )
  ),
  footer = dashboardFooter(
    left = "ARTI-2026",
    right = "v1.0.0"
  )
)

server <- function(input, output, session) {
  output$user_panel <- renderUser({
    dashboardUser(name = "Qonaq", image = "https://via.placeholder.com/50",
                  title = "Test", subtitle = "")
  })
  waiter_hide()
}

shinyApp(ui, server, options = list(port = 4040))
