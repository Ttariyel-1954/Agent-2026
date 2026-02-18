#!/bin/bash
# Modulları bir-bir test et
cd /Users/royatalibova/Desktop/Arti_2026

test_module() {
  local STEP="$1"
  local DESC="$2"
  local APP_CODE="$3"

  echo "================================================"
  echo "STEP $STEP: $DESC"
  echo "================================================"

  # Write the app file
  echo "$APP_CODE" > app_debug.R

  # Kill any existing process on port 4040
  lsof -ti:4040 | xargs kill -9 2>/dev/null
  sleep 1

  # Start the app
  Rscript app_debug.R > /tmp/arti_test_out.log 2>&1 &
  APP_PID=$!

  # Wait for startup
  sleep 8

  # Check if process is still running
  if ! kill -0 $APP_PID 2>/dev/null; then
    echo "FAIL: App crashed on startup!"
    echo "Last 10 lines:"
    tail -10 /tmp/arti_test_out.log
    echo ""
    return 1
  fi

  # Check HTTP response
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:4040 2>/dev/null)
  if [ "$HTTP_CODE" != "200" ]; then
    echo "FAIL: HTTP $HTTP_CODE"
    tail -10 /tmp/arti_test_out.log
    kill $APP_PID 2>/dev/null
    return 1
  fi

  # Check HTML structure — count treeview menus and sub-items
  TREEVIEW_COUNT=$(curl -s http://localhost:4040 | grep -c 'class="treeview"')
  SUBITEM_COUNT=$(curl -s http://localhost:4040 | grep -c 'treeview-menu')
  TAB_PANE_COUNT=$(curl -s http://localhost:4040 | grep -c 'class="tab-pane"')
  TEACHER_TAB=$(curl -s http://localhost:4040 | grep -c 'shiny-tab-teacher_list')

  echo "OK: HTTP 200 | Treeviews: $TREEVIEW_COUNT | SubMenus: $SUBITEM_COUNT | TabPanes: $TAB_PANE_COUNT | TeacherTab: $TEACHER_TAB"

  # Check for JS/CSS errors in the response
  ERROR_CHECK=$(curl -s http://localhost:4040 | grep -ic 'error\|exception' || true)
  if [ "$ERROR_CHECK" -gt 0 ]; then
    echo "WARNING: Found $ERROR_CHECK error/exception references in HTML"
  fi

  # Check R console for errors
  R_ERRORS=$(grep -c "ERROR\|Error\|error" /tmp/arti_test_out.log 2>/dev/null || true)
  if [ "$R_ERRORS" -gt 0 ]; then
    echo "WARNING: $R_ERRORS error lines in R console:"
    grep "ERROR\|Error\|error" /tmp/arti_test_out.log | head -5
  fi

  # Kill the app
  kill $APP_PID 2>/dev/null
  wait $APP_PID 2>/dev/null
  sleep 1

  echo ""
  return 0
}

# BASE template parts
BASE_LIBS='library(shiny)
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
source("modules/teacher/teacher_server.R")'

BASE_HOME_MENU='menuItem("Ana Səhifə", tabName = "home", icon = icon("home"), selected = TRUE)'
BASE_STUDENT_MENU='menuItem("Şagirdlər", icon = icon("user-graduate"),
        menuSubItem("Siyahı", tabName = "student_list"),
        menuSubItem("Qeydiyyat", tabName = "student_register"),
        menuSubItem("Davamiyyət", tabName = "student_attendance"),
        menuSubItem("Akademik Profil", tabName = "student_profile"),
        menuSubItem("Fərdi İnkişaf Planı", tabName = "student_idp"))'
BASE_TEACHER_MENU='menuItem("Müəllimlər", icon = icon("chalkboard-teacher"),
        menuSubItem("Siyahı", tabName = "teacher_list"),
        menuSubItem("Dərs Yükü", tabName = "teacher_workload"),
        menuSubItem("Peşəkar İnkişaf", tabName = "teacher_development"),
        menuSubItem("Performans", tabName = "teacher_performance"))'

BASE_HOME_TAB='tabItem(tabName = "home", h2("DEBUG"), valueBoxOutput("db_test_box", width = 4))'
BASE_STUDENT_TABS='tabItem(tabName = "student_list", student_list_ui("student_list")),
      tabItem(tabName = "student_register", student_register_ui("student_register")),
      tabItem(tabName = "student_attendance", student_attendance_ui("student_attendance")),
      tabItem(tabName = "student_profile", student_profile_ui("student_profile")),
      tabItem(tabName = "student_idp", student_idp_ui("student_idp"))'
BASE_TEACHER_TABS='tabItem(tabName = "teacher_list", teacher_list_ui("teacher_list")),
      tabItem(tabName = "teacher_workload", teacher_workload_ui("teacher_workload")),
      tabItem(tabName = "teacher_development", teacher_development_ui("teacher_development")),
      tabItem(tabName = "teacher_performance", teacher_performance_ui("teacher_performance"))'

BASE_HOME_SERVER='output$db_test_box <- renderValueBox({
    count <- get_total_count(db_pool, "teachers")
    valueBox(count, "Müəllim", icon = icon("users"), color = "green")
  })'
BASE_STUDENT_SERVER='student_list_server("student_list", db_pool, user_data)
  student_register_server("student_register", db_pool, user_data)
  student_attendance_server("student_attendance", db_pool, user_data)
  student_profile_server("student_profile", db_pool, user_data)
  student_idp_server("student_idp", db_pool, user_data)'
BASE_TEACHER_SERVER='teacher_list_server("teacher_list", db_pool, user_data)
  teacher_workload_server("teacher_workload", db_pool, user_data)
  teacher_development_server("teacher_development", db_pool, user_data)
  teacher_performance_server("teacher_performance", db_pool, user_data)'

# =============================================
# STEP 0: Base (student + teacher only)
# =============================================
test_module 0 "BASE: student + teacher only" "$BASE_LIBS

log_appender(appender_console); log_threshold(INFO)
ui <- dashboardPage(title='DEBUG',
  header = dashboardHeader(title = 'DEBUG', titleWidth = 280),
  sidebar = dashboardSidebar(width = 280, sidebarMenu(id = 'main_menu',
      $BASE_HOME_MENU,
      $BASE_STUDENT_MENU,
      $BASE_TEACHER_MENU
  )),
  body = dashboardBody(useShinyjs(), tabItems(
      $BASE_HOME_TAB,
      $BASE_STUDENT_TABS,
      $BASE_TEACHER_TABS
  )),
  footer = dashboardFooter(left = 'DEBUG')
)
server <- function(input, output, session) {
  db_pool <- create_db_pool()
  onStop(function() poolClose(db_pool))
  user_data <- reactiveVal(list(id='test', role='admin'))
  $BASE_HOME_SERVER
  $BASE_STUDENT_SERVER
  $BASE_TEACHER_SERVER
}
shinyApp(ui, server, options = list(host='0.0.0.0', port=4040L))
"

# =============================================
# STEP 1: + assessment
# =============================================
test_module 1 "+ assessment" "$BASE_LIBS
source('modules/assessment/item_bank.R')
source('modules/assessment/irt_engine.R')
source('modules/assessment/cat_engine.R')
source('modules/assessment/mst_engine.R')

log_appender(appender_console); log_threshold(INFO)
ui <- dashboardPage(title='DEBUG',
  header = dashboardHeader(title = 'DEBUG', titleWidth = 280),
  sidebar = dashboardSidebar(width = 280, sidebarMenu(id = 'main_menu',
      $BASE_HOME_MENU,
      $BASE_STUDENT_MENU,
      $BASE_TEACHER_MENU,
      menuItem('Qiymətləndirmə', icon = icon('clipboard-check'),
        menuSubItem('Sual Bankı', tabName = 'item_bank'),
        menuSubItem('IRT Analiz', tabName = 'irt_analysis'),
        menuSubItem('CAT Test', tabName = 'cat_test'),
        menuSubItem('MST Test', tabName = 'mst_test'),
        menuSubItem('Nəticələr', tabName = 'test_results'))
  )),
  body = dashboardBody(useShinyjs(), tabItems(
      $BASE_HOME_TAB,
      $BASE_STUDENT_TABS,
      $BASE_TEACHER_TABS,
      tabItem(tabName = 'item_bank', item_bank_ui('item_bank')),
      tabItem(tabName = 'irt_analysis', irt_analysis_ui('irt_analysis')),
      tabItem(tabName = 'cat_test', cat_test_ui('cat_test')),
      tabItem(tabName = 'mst_test', mst_test_ui('mst_test')),
      tabItem(tabName = 'test_results', test_results_ui('test_results'))
  )),
  footer = dashboardFooter(left = 'DEBUG')
)
server <- function(input, output, session) {
  db_pool <- create_db_pool()
  onStop(function() poolClose(db_pool))
  user_data <- reactiveVal(list(id='test', role='admin'))
  $BASE_HOME_SERVER
  $BASE_STUDENT_SERVER
  $BASE_TEACHER_SERVER
  item_bank_server('item_bank', db_pool, user_data)
  irt_analysis_server('irt_analysis', db_pool, user_data)
  cat_test_server('cat_test', db_pool, user_data)
  mst_test_server('mst_test', db_pool, user_data)
  test_results_server('test_results', db_pool, user_data)
}
shinyApp(ui, server, options = list(host='0.0.0.0', port=4040L))
"

# =============================================
# STEP 2: + curriculum
# =============================================
test_module 2 "+ curriculum" "$BASE_LIBS
source('modules/assessment/item_bank.R')
source('modules/assessment/irt_engine.R')
source('modules/assessment/cat_engine.R')
source('modules/assessment/mst_engine.R')
source('modules/curriculum/standards.R')
source('modules/curriculum/comparison.R')
source('modules/curriculum/alignment.R')

log_appender(appender_console); log_threshold(INFO)
ui <- dashboardPage(title='DEBUG',
  header = dashboardHeader(title = 'DEBUG', titleWidth = 280),
  sidebar = dashboardSidebar(width = 280, sidebarMenu(id = 'main_menu',
      $BASE_HOME_MENU,
      $BASE_STUDENT_MENU,
      $BASE_TEACHER_MENU,
      menuItem('Qiymətləndirmə', icon = icon('clipboard-check'),
        menuSubItem('Sual Bankı', tabName = 'item_bank'),
        menuSubItem('IRT Analiz', tabName = 'irt_analysis'),
        menuSubItem('CAT Test', tabName = 'cat_test'),
        menuSubItem('MST Test', tabName = 'mst_test'),
        menuSubItem('Nəticələr', tabName = 'test_results')),
      menuItem('Kurikulum', icon = icon('book'),
        menuSubItem('Standartlar', tabName = 'standards'),
        menuSubItem('Beynəlxalq Müqayisə', tabName = 'comparison'),
        menuSubItem('Uyğunluq Analizi', tabName = 'alignment'))
  )),
  body = dashboardBody(useShinyjs(), tabItems(
      $BASE_HOME_TAB,
      $BASE_STUDENT_TABS,
      $BASE_TEACHER_TABS,
      tabItem(tabName = 'item_bank', item_bank_ui('item_bank')),
      tabItem(tabName = 'irt_analysis', irt_analysis_ui('irt_analysis')),
      tabItem(tabName = 'cat_test', cat_test_ui('cat_test')),
      tabItem(tabName = 'mst_test', mst_test_ui('mst_test')),
      tabItem(tabName = 'test_results', test_results_ui('test_results')),
      tabItem(tabName = 'standards', standards_ui('standards')),
      tabItem(tabName = 'comparison', comparison_ui('comparison')),
      tabItem(tabName = 'alignment', alignment_ui('alignment'))
  )),
  footer = dashboardFooter(left = 'DEBUG')
)
server <- function(input, output, session) {
  db_pool <- create_db_pool()
  onStop(function() poolClose(db_pool))
  user_data <- reactiveVal(list(id='test', role='admin'))
  $BASE_HOME_SERVER
  $BASE_STUDENT_SERVER
  $BASE_TEACHER_SERVER
  item_bank_server('item_bank', db_pool, user_data)
  irt_analysis_server('irt_analysis', db_pool, user_data)
  cat_test_server('cat_test', db_pool, user_data)
  mst_test_server('mst_test', db_pool, user_data)
  test_results_server('test_results', db_pool, user_data)
  standards_server('standards', db_pool, user_data)
  comparison_server('comparison', db_pool, user_data)
  alignment_server('alignment', db_pool, user_data)
}
shinyApp(ui, server, options = list(host='0.0.0.0', port=4040L))
"

# =============================================
# STEP 3: + analytics
# =============================================
test_module 3 "+ analytics" "$BASE_LIBS
source('modules/assessment/item_bank.R')
source('modules/assessment/irt_engine.R')
source('modules/assessment/cat_engine.R')
source('modules/assessment/mst_engine.R')
source('modules/curriculum/standards.R')
source('modules/curriculum/comparison.R')
source('modules/curriculum/alignment.R')
source('modules/analytics/school_dashboard.R')
source('modules/analytics/reports.R')
source('modules/analytics/predictions.R')

log_appender(appender_console); log_threshold(INFO)
ui <- dashboardPage(title='DEBUG',
  header = dashboardHeader(title = 'DEBUG', titleWidth = 280),
  sidebar = dashboardSidebar(width = 280, sidebarMenu(id = 'main_menu',
      $BASE_HOME_MENU,
      $BASE_STUDENT_MENU,
      $BASE_TEACHER_MENU,
      menuItem('Qiymətləndirmə', icon = icon('clipboard-check'),
        menuSubItem('Sual Bankı', tabName = 'item_bank'),
        menuSubItem('IRT Analiz', tabName = 'irt_analysis'),
        menuSubItem('CAT Test', tabName = 'cat_test'),
        menuSubItem('MST Test', tabName = 'mst_test'),
        menuSubItem('Nəticələr', tabName = 'test_results')),
      menuItem('Kurikulum', icon = icon('book'),
        menuSubItem('Standartlar', tabName = 'standards'),
        menuSubItem('Beynəlxalq Müqayisə', tabName = 'comparison'),
        menuSubItem('Uyğunluq Analizi', tabName = 'alignment')),
      menuItem('Analitika', icon = icon('chart-line'),
        menuSubItem('Məktəb Dashboard', tabName = 'school_dashboard'),
        menuSubItem('Hesabatlar', tabName = 'reports'),
        menuSubItem('Prediktiv Analitika', tabName = 'predictions'))
  )),
  body = dashboardBody(useShinyjs(), tabItems(
      $BASE_HOME_TAB,
      $BASE_STUDENT_TABS,
      $BASE_TEACHER_TABS,
      tabItem(tabName = 'item_bank', item_bank_ui('item_bank')),
      tabItem(tabName = 'irt_analysis', irt_analysis_ui('irt_analysis')),
      tabItem(tabName = 'cat_test', cat_test_ui('cat_test')),
      tabItem(tabName = 'mst_test', mst_test_ui('mst_test')),
      tabItem(tabName = 'test_results', test_results_ui('test_results')),
      tabItem(tabName = 'standards', standards_ui('standards')),
      tabItem(tabName = 'comparison', comparison_ui('comparison')),
      tabItem(tabName = 'alignment', alignment_ui('alignment')),
      tabItem(tabName = 'school_dashboard', school_dashboard_ui('school_dashboard')),
      tabItem(tabName = 'reports', reports_ui('reports')),
      tabItem(tabName = 'predictions', predictions_ui('predictions'))
  )),
  footer = dashboardFooter(left = 'DEBUG')
)
server <- function(input, output, session) {
  db_pool <- create_db_pool()
  onStop(function() poolClose(db_pool))
  user_data <- reactiveVal(list(id='test', role='admin'))
  $BASE_HOME_SERVER
  $BASE_STUDENT_SERVER
  $BASE_TEACHER_SERVER
  item_bank_server('item_bank', db_pool, user_data)
  irt_analysis_server('irt_analysis', db_pool, user_data)
  cat_test_server('cat_test', db_pool, user_data)
  mst_test_server('mst_test', db_pool, user_data)
  test_results_server('test_results', db_pool, user_data)
  standards_server('standards', db_pool, user_data)
  comparison_server('comparison', db_pool, user_data)
  alignment_server('alignment', db_pool, user_data)
  school_dashboard_server('school_dashboard', db_pool, user_data)
  reports_server('reports', db_pool, user_data)
  predictions_server('predictions', db_pool, user_data)
}
shinyApp(ui, server, options = list(host='0.0.0.0', port=4040L))
"

# =============================================
# STEP 4-10: remaining modules (certification through admin)
# Build the FULL app incrementally
# =============================================

# For steps 4-10, we add ALL remaining modules at once to save time
# If step 3 works, the issue is in steps 4-10
# If step 3 fails, it's in steps 1-3

test_module "4-10" "ALL remaining modules (full app without custom CSS/JS/waiter/auth)" "$BASE_LIBS
library(httr2)
library(openssl)
library(jose)

source('modules/assessment/item_bank.R')
source('modules/assessment/irt_engine.R')
source('modules/assessment/cat_engine.R')
source('modules/assessment/mst_engine.R')
source('modules/curriculum/standards.R')
source('modules/curriculum/comparison.R')
source('modules/curriculum/alignment.R')
source('modules/analytics/school_dashboard.R')
source('modules/analytics/reports.R')
source('modules/analytics/predictions.R')
source('modules/certification/certification_helpers.R')
source('modules/certification/certification_ui.R')
source('modules/certification/certification_server.R')
source('modules/resources/resources_helpers.R')
source('modules/resources/resources_ui.R')
source('modules/resources/resources_server.R')
source('modules/research/research_helpers.R')
source('modules/research/research_ui.R')
source('modules/research/research_server.R')
source('modules/development/development_helpers.R')
source('modules/development/development_ui.R')
source('modules/development/development_server.R')
source('modules/international/international_helpers.R')
source('modules/international/international_ui.R')
source('modules/international/international_server.R')
source('modules/institute/institute_helpers.R')
source('modules/institute/institute_ui.R')
source('modules/institute/institute_server.R')
source('R/auth.R')
source('ai_integration/claude_api.R')
source('ai_integration/gpt_api.R')
source('ai_integration/response_parser.R')

log_appender(appender_console); log_threshold(INFO)
ui <- dashboardPage(title=\"DEBUG-FULL\",
  header = dashboardHeader(title = \"DEBUG-FULL\", titleWidth = 280),
  sidebar = dashboardSidebar(width = 280, sidebarMenu(id = \"main_menu\",
      $BASE_HOME_MENU,
      $BASE_STUDENT_MENU,
      $BASE_TEACHER_MENU,
      menuItem(\"Qiymətləndirmə\", icon = icon(\"clipboard-check\"),
        menuSubItem(\"Sual Bankı\", tabName = \"item_bank\"),
        menuSubItem(\"IRT Analiz\", tabName = \"irt_analysis\"),
        menuSubItem(\"CAT Test\", tabName = \"cat_test\"),
        menuSubItem(\"MST Test\", tabName = \"mst_test\"),
        menuSubItem(\"Nəticələr\", tabName = \"test_results\")),
      menuItem(\"Kurikulum\", icon = icon(\"book\"),
        menuSubItem(\"Standartlar\", tabName = \"standards\"),
        menuSubItem(\"Beynəlxalq Müqayisə\", tabName = \"comparison\"),
        menuSubItem(\"Uyğunluq Analizi\", tabName = \"alignment\")),
      menuItem(\"Analitika\", icon = icon(\"chart-line\"),
        menuSubItem(\"Məktəb Dashboard\", tabName = \"school_dashboard\"),
        menuSubItem(\"Hesabatlar\", tabName = \"reports\"),
        menuSubItem(\"Prediktiv Analitika\", tabName = \"predictions\")),
      menuItem(\"Sertifikasiya\", icon = icon(\"certificate\"),
        menuSubItem(\"İşə Qəbul\", tabName = \"cert_recruitment\"),
        menuSubItem(\"Sertifikasiya\", tabName = \"cert_exams\"),
        menuSubItem(\"Sual Bazası\", tabName = \"cert_questions\"),
        menuSubItem(\"Avtomatlaşdırma\", tabName = \"cert_automation\")),
      menuItem(\"Tədris Resursları\", icon = icon(\"book-reader\"),
        menuSubItem(\"Proqramlar\", tabName = \"resources_programs\"),
        menuSubItem(\"Rəqəmsal\", tabName = \"resources_digital\"),
        menuSubItem(\"Dərsliklər\", tabName = \"resources_textbooks\")),
      menuItem(\"Tədqiqat\", icon = icon(\"flask\"),
        menuSubItem(\"Tədqiqatlar\", tabName = \"research_projects\"),
        menuSubItem(\"Siyasət\", tabName = \"research_policy\"),
        menuSubItem(\"Doktorantura\", tabName = \"research_doctoral\")),
      menuItem(\"Peşəkar İnkişaf\", icon = icon(\"chart-line\"),
        menuSubItem(\"Təlimlər\", tabName = \"dev_training\"),
        menuSubItem(\"Kurslar\", tabName = \"dev_courses\"),
        menuSubItem(\"Mentorluq\", tabName = \"dev_mentorship\")),
      menuItem(\"Beynəlxalq\", icon = icon(\"globe\"),
        menuSubItem(\"Olimpiadalar\", tabName = \"intl_olympiads\"),
        menuSubItem(\"STEAM\", tabName = \"intl_steam\"),
        menuSubItem(\"Partnyor\", tabName = \"intl_partners\")),
      menuItem(\"İnstitut\", icon = icon(\"building\"),
        menuSubItem(\"Struktur\", tabName = \"inst_structure\"),
        menuSubItem(\"Resurslar\", tabName = \"inst_resources\"),
        menuSubItem(\"Kontingent\", tabName = \"inst_contingent\"),
        menuSubItem(\"Monitorinq\", tabName = \"inst_monitoring\")),
      menuItem(\"AI Köməkçi\", tabName = \"ai_assistant\", icon = icon(\"robot\"))
  )),
  body = dashboardBody(useShinyjs(), tabItems(
      $BASE_HOME_TAB,
      $BASE_STUDENT_TABS,
      $BASE_TEACHER_TABS,
      tabItem(tabName = \"item_bank\", item_bank_ui(\"item_bank\")),
      tabItem(tabName = \"irt_analysis\", irt_analysis_ui(\"irt_analysis\")),
      tabItem(tabName = \"cat_test\", cat_test_ui(\"cat_test\")),
      tabItem(tabName = \"mst_test\", mst_test_ui(\"mst_test\")),
      tabItem(tabName = \"test_results\", test_results_ui(\"test_results\")),
      tabItem(tabName = \"standards\", standards_ui(\"standards\")),
      tabItem(tabName = \"comparison\", comparison_ui(\"comparison\")),
      tabItem(tabName = \"alignment\", alignment_ui(\"alignment\")),
      tabItem(tabName = \"school_dashboard\", school_dashboard_ui(\"school_dashboard\")),
      tabItem(tabName = \"reports\", reports_ui(\"reports\")),
      tabItem(tabName = \"predictions\", predictions_ui(\"predictions\")),
      tabItem(tabName = \"cert_recruitment\", cert_recruitment_ui(\"cert_recruitment\")),
      tabItem(tabName = \"cert_exams\", cert_exams_ui(\"cert_exams\")),
      tabItem(tabName = \"cert_questions\", cert_questions_ui(\"cert_questions\")),
      tabItem(tabName = \"cert_automation\", cert_automation_ui(\"cert_automation\")),
      tabItem(tabName = \"resources_programs\", resources_programs_ui(\"resources_programs\")),
      tabItem(tabName = \"resources_digital\", resources_digital_ui(\"resources_digital\")),
      tabItem(tabName = \"resources_textbooks\", resources_textbooks_ui(\"resources_textbooks\")),
      tabItem(tabName = \"research_projects\", research_projects_ui(\"research_projects\")),
      tabItem(tabName = \"research_policy\", research_policy_ui(\"research_policy\")),
      tabItem(tabName = \"research_doctoral\", research_doctoral_ui(\"research_doctoral\")),
      tabItem(tabName = \"dev_training\", dev_training_ui(\"dev_training\")),
      tabItem(tabName = \"dev_courses\", dev_courses_ui(\"dev_courses\")),
      tabItem(tabName = \"dev_mentorship\", dev_mentorship_ui(\"dev_mentorship\")),
      tabItem(tabName = \"intl_olympiads\", intl_olympiads_ui(\"intl_olympiads\")),
      tabItem(tabName = \"intl_steam\", intl_steam_ui(\"intl_steam\")),
      tabItem(tabName = \"intl_partners\", intl_partners_ui(\"intl_partners\")),
      tabItem(tabName = \"inst_structure\", inst_structure_ui(\"inst_structure\")),
      tabItem(tabName = \"inst_resources\", inst_resources_ui(\"inst_resources\")),
      tabItem(tabName = \"inst_contingent\", inst_contingent_ui(\"inst_contingent\")),
      tabItem(tabName = \"inst_monitoring\", inst_monitoring_ui(\"inst_monitoring\")),
      tabItem(tabName = \"ai_assistant\", h2(\"AI Köməkçi\"))
  )),
  footer = dashboardFooter(left = \"DEBUG-FULL\")
)
server <- function(input, output, session) {
  db_pool <- create_db_pool()
  onStop(function() poolClose(db_pool))
  user_data <- reactiveVal(list(id=\"test\", role=\"admin\"))
  $BASE_HOME_SERVER
  $BASE_STUDENT_SERVER
  $BASE_TEACHER_SERVER
  item_bank_server(\"item_bank\", db_pool, user_data)
  irt_analysis_server(\"irt_analysis\", db_pool, user_data)
  cat_test_server(\"cat_test\", db_pool, user_data)
  mst_test_server(\"mst_test\", db_pool, user_data)
  test_results_server(\"test_results\", db_pool, user_data)
  standards_server(\"standards\", db_pool, user_data)
  comparison_server(\"comparison\", db_pool, user_data)
  alignment_server(\"alignment\", db_pool, user_data)
  school_dashboard_server(\"school_dashboard\", db_pool, user_data)
  reports_server(\"reports\", db_pool, user_data)
  predictions_server(\"predictions\", db_pool, user_data)
  cert_recruitment_server(\"cert_recruitment\", db_pool, user_data)
  cert_exams_server(\"cert_exams\", db_pool, user_data)
  cert_questions_server(\"cert_questions\", db_pool, user_data)
  cert_automation_server(\"cert_automation\", db_pool, user_data)
  resources_programs_server(\"resources_programs\", db_pool, user_data)
  resources_digital_server(\"resources_digital\", db_pool, user_data)
  resources_textbooks_server(\"resources_textbooks\", db_pool, user_data)
  research_projects_server(\"research_projects\", db_pool, user_data)
  research_policy_server(\"research_policy\", db_pool, user_data)
  research_doctoral_server(\"research_doctoral\", db_pool, user_data)
  dev_training_server(\"dev_training\", db_pool, user_data)
  dev_courses_server(\"dev_courses\", db_pool, user_data)
  dev_mentorship_server(\"dev_mentorship\", db_pool, user_data)
  intl_olympiads_server(\"intl_olympiads\", db_pool, user_data)
  intl_steam_server(\"intl_steam\", db_pool, user_data)
  intl_partners_server(\"intl_partners\", db_pool, user_data)
  inst_structure_server(\"inst_structure\", db_pool, user_data)
  inst_resources_server(\"inst_resources\", db_pool, user_data)
  inst_contingent_server(\"inst_contingent\", db_pool, user_data)
  inst_monitoring_server(\"inst_monitoring\", db_pool, user_data)
}
shinyApp(ui, server, options = list(host=\"0.0.0.0\", port=4040L))
"

# Final: test with custom CSS/JS (the likely culprit)
test_module "CSS-JS" "Full app + custom.css + custom.js" "$BASE_LIBS

source('modules/assessment/item_bank.R')
source('modules/assessment/irt_engine.R')
source('modules/assessment/cat_engine.R')
source('modules/assessment/mst_engine.R')
source('modules/curriculum/standards.R')
source('modules/curriculum/comparison.R')
source('modules/curriculum/alignment.R')
source('modules/analytics/school_dashboard.R')
source('modules/analytics/reports.R')
source('modules/analytics/predictions.R')

log_appender(appender_console); log_threshold(INFO)
ui <- dashboardPage(title=\"DEBUG-CSSJS\",
  header = dashboardHeader(title = \"DEBUG-CSSJS\", titleWidth = 280),
  sidebar = dashboardSidebar(width = 280, sidebarMenu(id = \"main_menu\",
      $BASE_HOME_MENU,
      $BASE_STUDENT_MENU,
      $BASE_TEACHER_MENU,
      menuItem(\"Qiymətləndirmə\", icon = icon(\"clipboard-check\"),
        menuSubItem(\"Sual Bankı\", tabName = \"item_bank\"),
        menuSubItem(\"IRT Analiz\", tabName = \"irt_analysis\"),
        menuSubItem(\"CAT Test\", tabName = \"cat_test\"),
        menuSubItem(\"MST Test\", tabName = \"mst_test\"),
        menuSubItem(\"Nəticələr\", tabName = \"test_results\")),
      menuItem(\"Kurikulum\", icon = icon(\"book\"),
        menuSubItem(\"Standartlar\", tabName = \"standards\"),
        menuSubItem(\"Beynəlxalq Müqayisə\", tabName = \"comparison\"),
        menuSubItem(\"Uyğunluq Analizi\", tabName = \"alignment\")),
      menuItem(\"Analitika\", icon = icon(\"chart-line\"),
        menuSubItem(\"Məktəb Dashboard\", tabName = \"school_dashboard\"),
        menuSubItem(\"Hesabatlar\", tabName = \"reports\"),
        menuSubItem(\"Prediktiv Analitika\", tabName = \"predictions\"))
  )),
  body = dashboardBody(
    tags\$head(
      tags\$link(rel = \"stylesheet\", type = \"text/css\", href = \"css/custom.css\"),
      tags\$script(src = \"js/custom.js\")
    ),
    useShinyjs(),
    tabItems(
      $BASE_HOME_TAB,
      $BASE_STUDENT_TABS,
      $BASE_TEACHER_TABS,
      tabItem(tabName = \"item_bank\", item_bank_ui(\"item_bank\")),
      tabItem(tabName = \"irt_analysis\", irt_analysis_ui(\"irt_analysis\")),
      tabItem(tabName = \"cat_test\", cat_test_ui(\"cat_test\")),
      tabItem(tabName = \"mst_test\", mst_test_ui(\"mst_test\")),
      tabItem(tabName = \"test_results\", test_results_ui(\"test_results\")),
      tabItem(tabName = \"standards\", standards_ui(\"standards\")),
      tabItem(tabName = \"comparison\", comparison_ui(\"comparison\")),
      tabItem(tabName = \"alignment\", alignment_ui(\"alignment\")),
      tabItem(tabName = \"school_dashboard\", school_dashboard_ui(\"school_dashboard\")),
      tabItem(tabName = \"reports\", reports_ui(\"reports\")),
      tabItem(tabName = \"predictions\", predictions_ui(\"predictions\"))
  )),
  footer = dashboardFooter(left = \"DEBUG-CSSJS\")
)
server <- function(input, output, session) {
  db_pool <- create_db_pool()
  onStop(function() poolClose(db_pool))
  user_data <- reactiveVal(list(id=\"test\", role=\"admin\"))
  $BASE_HOME_SERVER
  $BASE_STUDENT_SERVER
  $BASE_TEACHER_SERVER
  item_bank_server(\"item_bank\", db_pool, user_data)
  irt_analysis_server(\"irt_analysis\", db_pool, user_data)
  cat_test_server(\"cat_test\", db_pool, user_data)
  mst_test_server(\"mst_test\", db_pool, user_data)
  test_results_server(\"test_results\", db_pool, user_data)
  standards_server(\"standards\", db_pool, user_data)
  comparison_server(\"comparison\", db_pool, user_data)
  alignment_server(\"alignment\", db_pool, user_data)
  school_dashboard_server(\"school_dashboard\", db_pool, user_data)
  reports_server(\"reports\", db_pool, user_data)
  predictions_server(\"predictions\", db_pool, user_data)
}
shinyApp(ui, server, options = list(host=\"0.0.0.0\", port=4040L))
"

echo ""
echo "================================================"
echo "BÜTÜN TESTLƏR TAMAMLANDI"
echo "================================================"
