# ============================================================
# ARTI 2026 - SERVER MONİTORİNQ PANELİ
# Server resurları, xidmətlər, ehtiyat nüsxə, təhlükəsizlik
# ============================================================

library(shiny)
library(shinydashboard)
library(plotly)
library(DT)
library(dplyr)

# ===== NÜMUNƏ MƏLUMATLAR =====

set.seed(2026)

# Son 24 saat CPU/RAM
saatlar <- format(Sys.time() - (23:0) * 3600, "%H:%M")
server_metrics <- data.frame(
  saat = factor(saatlar, levels = saatlar),
  cpu = round(runif(24, 15, 85), 1),
  ram = round(runif(24, 40, 78), 1),
  disk = round(runif(24, 55, 72), 1),
  network_in = round(runif(24, 10, 150), 1),
  network_out = round(runif(24, 20, 200), 1),
  aktiv_session = sample(5:250, 24, replace = TRUE),
  stringsAsFactors = FALSE
)

# Xidmətlər
xidmetler <- data.frame(
  xidmet = c("API Gateway", "Agent Service", "Assessment Service", "Certification Service",
             "Exam Platform", "Web Portal", "Admin Dashboard", "PostgreSQL",
             "Redis", "MongoDB", "Nginx", "Prometheus", "Grafana"),
  port = c(8000, 8001, 8002, 8003, 8004, 3001, 3002, 5432, 6379, 27017, 80, 9090, 3000),
  status = c("Aktiv", "Aktiv", "Aktiv", "Aktiv", "Aktiv", "Aktiv", "Aktiv",
             "Aktiv", "Aktiv", "Aktiv", "Aktiv", "Aktiv", "Aktiv"),
  cpu_faiz = round(runif(13, 1, 25), 1),
  ram_mb = sample(50:800, 13),
  uptime_saat = sample(24:720, 13),
  son_yoxlama = format(Sys.time() - sample(0:60, 13, replace = TRUE) * 60, "%H:%M:%S"),
  stringsAsFactors = FALSE
)

# Ehtiyat nüsxə tarixi
ehtiyat <- data.frame(
  tarix = format(Sys.Date() - 0:14, "%d.%m.%Y"),
  nov = rep(c("Tam", "İncremental"), length.out = 15),
  olchu_mb = sample(200:1500, 15),
  muddet_deq = sample(3:25, 15, replace = TRUE),
  status = sample(c("Uğurlu", "Uğurlu", "Uğurlu", "Xəta"), 15, replace = TRUE, prob = c(0.85, 0.05, 0.05, 0.05)),
  stringsAsFactors = FALSE
)

# Təhlükəsizlik hadisələri
tehlukesizlik <- data.frame(
  tarix = format(Sys.time() - sample(0:720, 20, replace = TRUE) * 3600, "%d.%m.%Y %H:%M"),
  nov = sample(c("Giriş cəhdi", "IP bloku", "Rate limit", "SSL xəbərdarlıq", "Uğurlu giriş"),
               20, replace = TRUE, prob = c(0.3, 0.15, 0.2, 0.05, 0.3)),
  ip = paste0(sample(1:255, 20, replace = TRUE), ".", sample(1:255, 20, replace = TRUE),
              ".", sample(1:255, 20, replace = TRUE), ".", sample(1:255, 20, replace = TRUE)),
  istifadechi = sample(c("admin", "examiner01", "bilinməyən", "teacher05", "API"), 20, replace = TRUE),
  netice = sample(c("Uğurlu", "Bloklandı", "Xəbərdarlıq"), 20, replace = TRUE, prob = c(0.4, 0.35, 0.25)),
  stringsAsFactors = FALSE
)

# DB statistikası
db_stat <- data.frame(
  cedvel = c("users", "schools", "students", "teachers", "items",
             "exams", "exam_sessions", "certifications", "training_programs", "publications"),
  setir_sayi = c(5200, 80, 24000, 3500, 4800, 120, 15000, 1200, 45, 50),
  olchu_mb = c(2.1, 0.3, 45.6, 5.8, 12.4, 0.5, 180.2, 3.2, 0.1, 0.2),
  indeks_sayi = c(3, 4, 5, 3, 6, 2, 7, 3, 1, 1),
  stringsAsFactors = FALSE
)


# ===== UI =====

ui <- dashboardPage(
  skin = "black",
  dashboardHeader(title = "ARTI - Server Monitor", titleWidth = 280),

  dashboardSidebar(
    width = 280,
    sidebarMenu(
      menuItem("Real Vaxt", tabName = "realvaxt", icon = icon("tachometer-alt")),
      menuItem("Xidmətlər", tabName = "xidmet", icon = icon("server")),
      menuItem("Verilənlər Bazası", tabName = "db", icon = icon("database")),
      menuItem("Ehtiyat Nüsxə", tabName = "ehtiyat", icon = icon("save")),
      menuItem("Təhlükəsizlik", tabName = "tehluke", icon = icon("shield-alt")),
      menuItem("Şəbəkə", tabName = "sebeke", icon = icon("network-wired")),
      hr(),
      tags$div(style = "padding: 15px; color: #b8c7ce;",
               tags$p(icon("circle", style = "color: #00a65a;"), " Bütün xidmətlər aktiv"),
               tags$p(paste0("Son yeniləmə: ", format(Sys.time(), "%H:%M:%S"))),
               actionButton("refresh_btn", "Yenilə", class = "btn-sm btn-default", width = "100%")
      )
    )
  ),

  dashboardBody(
    tags$head(tags$style(HTML("
      .content-wrapper { background-color: #1a1a2e; color: #e0e0e0; }
      .box { background-color: #16213e; border-top: 3px solid #0f3460; }
      .box-header { color: #e0e0e0; }
      .box-body { color: #ccc; }
      .small-box { background-color: #0f3460 !important; }
      .info-box { background-color: #16213e; }
      .box-header { border-bottom: 1px solid #0f3460; }
      h3 { color: #e94560; }
      .skin-black .main-header .logo { background-color: #0f3460; }
      .skin-black .main-header .navbar { background-color: #16213e; }
    "))),

    tabItems(
      # REAL VAXT
      tabItem(tabName = "realvaxt",
        h3("Server Real Vaxt Monitorinq", style = "margin-top: 0;"),
        fluidRow(
          valueBox(paste0(tail(server_metrics$cpu, 1), "%"), "CPU", icon = icon("microchip"),
                   color = if(tail(server_metrics$cpu,1) > 70) "red" else "green", width = 2),
          valueBox(paste0(tail(server_metrics$ram, 1), "%"), "RAM", icon = icon("memory"),
                   color = if(tail(server_metrics$ram,1) > 70) "red" else "blue", width = 2),
          valueBox(paste0(tail(server_metrics$disk, 1), "%"), "Disk", icon = icon("hdd"),
                   color = "yellow", width = 2),
          valueBox(tail(server_metrics$aktiv_session, 1), "Sessiya", icon = icon("users"),
                   color = "purple", width = 2),
          valueBox("99.7%", "Uptime", icon = icon("clock"), color = "green", width = 2),
          valueBox(nrow(xidmetler), "Xidmət", icon = icon("cubes"), color = "aqua", width = 2)
        ),
        fluidRow(
          box(title = "CPU & RAM (Son 24 saat)", width = 8, height = 400, solidHeader = TRUE,
              status = "primary",
              plotlyOutput("cpu_ram_chart", height = "340px")),
          box(title = "Aktiv Sessiyalar", width = 4, height = 400, solidHeader = TRUE,
              status = "info",
              plotlyOutput("session_chart", height = "340px"))
        ),
        fluidRow(
          box(title = "Şəbəkə Trafiki (Mb/s)", width = 12, height = 350, solidHeader = TRUE,
              status = "success",
              plotlyOutput("network_chart", height = "290px"))
        )
      ),

      # XİDMƏTLƏR
      tabItem(tabName = "xidmet",
        h3("Docker Xidmətləri"),
        box(title = "Xidmət Statusu", width = 12, solidHeader = TRUE, status = "primary",
            DT::dataTableOutput("xidmet_table"))
      ),

      # DB
      tabItem(tabName = "db",
        h3("Verilənlər Bazası"),
        fluidRow(
          infoBox("PostgreSQL", "Aktiv", icon = icon("database"), color = "blue", width = 3),
          infoBox("Ümumi Ölçü", paste0(round(sum(db_stat$olchu_mb), 1), " MB"),
                  icon = icon("hdd"), color = "green", width = 3),
          infoBox("Cədvəl", nrow(db_stat), icon = icon("table"), color = "yellow", width = 3),
          infoBox("Ümumi Sətir", format(sum(db_stat$setir_sayi), big.mark = " "),
                  icon = icon("list"), color = "red", width = 3)
        ),
        fluidRow(
          box(title = "Cədvəl Ölçüləri", width = 7, solidHeader = TRUE, status = "primary",
              plotlyOutput("db_olchu_bar", height = "350px")),
          box(title = "Cədvəllər", width = 5, solidHeader = TRUE, status = "info",
              DT::dataTableOutput("db_table"))
        )
      ),

      # EHTİYAT
      tabItem(tabName = "ehtiyat",
        h3("Ehtiyat Nüsxə Tarixi"),
        fluidRow(
          infoBox("Son Ehtiyat", ehtiyat$tarix[1], icon = icon("save"), color = "green", width = 4),
          infoBox("Ümumi Ölçü", paste0(round(sum(ehtiyat$olchu_mb) / 1024, 1), " GB"),
                  icon = icon("archive"), color = "blue", width = 4),
          infoBox("Uğur %", paste0(round(mean(ehtiyat$status == "Uğurlu") * 100), "%"),
                  icon = icon("check-circle"), color = "yellow", width = 4)
        ),
        box(title = "Ehtiyat Nüsxə Cədvəli", width = 12, solidHeader = TRUE, status = "primary",
            DT::dataTableOutput("ehtiyat_table"))
      ),

      # TƏHLÜKƏSİZLİK
      tabItem(tabName = "tehluke",
        h3("Təhlükəsizlik Hadisələri"),
        fluidRow(
          infoBox("Giriş Cəhdi", sum(tehlukesizlik$nov == "Giriş cəhdi"),
                  icon = icon("sign-in-alt"), color = "blue", width = 3),
          infoBox("IP Bloku", sum(tehlukesizlik$nov == "IP bloku"),
                  icon = icon("ban"), color = "red", width = 3),
          infoBox("Rate Limit", sum(tehlukesizlik$nov == "Rate limit"),
                  icon = icon("tachometer-alt"), color = "yellow", width = 3),
          infoBox("SSL Xəbərd.", sum(tehlukesizlik$nov == "SSL xəbərdarlıq"),
                  icon = icon("lock"), color = "purple", width = 3)
        ),
        box(title = "Hadisə Jurnalı", width = 12, solidHeader = TRUE, status = "primary",
            DT::dataTableOutput("tehluke_table"))
      ),

      # ŞƏBƏKƏ
      tabItem(tabName = "sebeke",
        h3("Şəbəkə Statistikası"),
        fluidRow(
          box(title = "Giriş vs Çıxış Trafiki", width = 12, solidHeader = TRUE, status = "primary",
              plotlyOutput("sebeke_chart", height = "350px"))
        )
      )
    )
  )
)


# ===== SERVER =====

server <- function(input, output, session) {

  output$cpu_ram_chart <- renderPlotly({
    plot_ly(server_metrics, x = ~saat) %>%
      add_trace(y = ~cpu, name = "CPU %", type = "scatter", mode = "lines",
                line = list(color = "#e94560", width = 2.5), fill = "tozeroy",
                fillcolor = "rgba(233,69,96,0.1)") %>%
      add_trace(y = ~ram, name = "RAM %", type = "scatter", mode = "lines",
                line = list(color = "#0f3460", width = 2.5), fill = "tozeroy",
                fillcolor = "rgba(15,52,96,0.1)") %>%
      add_trace(y = ~disk, name = "Disk %", type = "scatter", mode = "lines",
                line = list(color = "#f39c12", width = 1.5, dash = "dot")) %>%
      layout(xaxis = list(title = "", color = "#ccc"),
             yaxis = list(title = "%", range = c(0, 100), color = "#ccc"),
             paper_bgcolor = "rgba(0,0,0,0)", plot_bgcolor = "rgba(0,0,0,0)",
             font = list(color = "#ccc"),
             legend = list(orientation = "h", y = -0.15))
  })

  output$session_chart <- renderPlotly({
    plot_ly(server_metrics, x = ~saat, y = ~aktiv_session, type = "bar",
            marker = list(color = "#533483")) %>%
      layout(xaxis = list(title = "", color = "#ccc", tickangle = -45),
             yaxis = list(title = "Sessiya", color = "#ccc"),
             paper_bgcolor = "rgba(0,0,0,0)", plot_bgcolor = "rgba(0,0,0,0)",
             font = list(color = "#ccc"), margin = list(b = 60))
  })

  output$network_chart <- renderPlotly({
    plot_ly(server_metrics, x = ~saat) %>%
      add_trace(y = ~network_in, name = "Giriş (Mb/s)", type = "scatter", mode = "lines",
                line = list(color = "#00a65a", width = 2), fill = "tozeroy",
                fillcolor = "rgba(0,166,90,0.1)") %>%
      add_trace(y = ~network_out, name = "Çıxış (Mb/s)", type = "scatter", mode = "lines",
                line = list(color = "#3c8dbc", width = 2), fill = "tozeroy",
                fillcolor = "rgba(60,141,188,0.1)") %>%
      layout(xaxis = list(title = "", color = "#ccc"),
             yaxis = list(title = "Mb/s", color = "#ccc"),
             paper_bgcolor = "rgba(0,0,0,0)", plot_bgcolor = "rgba(0,0,0,0)",
             font = list(color = "#ccc"),
             legend = list(orientation = "h", y = -0.2))
  })

  output$xidmet_table <- DT::renderDataTable({
    datatable(xidmetler,
              colnames = c("Xidmət", "Port", "Status", "CPU %", "RAM (MB)", "Uptime (saat)", "Son Yoxlama"),
              options = list(dom = "t", pageLength = 15), rownames = FALSE) %>%
      formatStyle("status", backgroundColor = styleEqual("Aktiv", "#d4edda"), fontWeight = "bold") %>%
      formatStyle("cpu_faiz",
                  background = styleColorBar(c(0, 30), "#e94560"),
                  backgroundSize = "90% 70%", backgroundRepeat = "no-repeat", backgroundPosition = "left")
  })

  output$db_olchu_bar <- renderPlotly({
    df <- db_stat %>% arrange(desc(olchu_mb))
    plot_ly(df, x = ~reorder(cedvel, olchu_mb), y = ~olchu_mb, type = "bar",
            marker = list(color = "#0f3460"),
            text = ~paste0(olchu_mb, " MB"), textposition = "outside") %>%
      layout(xaxis = list(title = "", color = "#ccc"),
             yaxis = list(title = "MB", color = "#ccc"),
             paper_bgcolor = "rgba(0,0,0,0)", plot_bgcolor = "rgba(0,0,0,0)",
             font = list(color = "#ccc"), margin = list(b = 80))
  })

  output$db_table <- DT::renderDataTable({
    datatable(db_stat, colnames = c("Cədvəl", "Sətir", "Ölçü (MB)", "İndeks"),
              options = list(dom = "t", pageLength = 10), rownames = FALSE) %>%
      formatCurrency("olchu_mb", currency = "", digits = 1)
  })

  output$ehtiyat_table <- DT::renderDataTable({
    datatable(ehtiyat, colnames = c("Tarix", "Növ", "Ölçü (MB)", "Müddət (dəq)", "Status"),
              options = list(dom = "t", pageLength = 15), rownames = FALSE) %>%
      formatStyle("status", backgroundColor = styleEqual(c("Uğurlu", "Xəta"), c("#d4edda", "#f8d7da")),
                  fontWeight = "bold")
  })

  output$tehluke_table <- DT::renderDataTable({
    datatable(tehlukesizlik, colnames = c("Tarix", "Növ", "IP", "İstifadəçi", "Nəticə"),
              options = list(pageLength = 10, order = list(list(0, "desc"))), rownames = FALSE) %>%
      formatStyle("netice", backgroundColor = styleEqual(
        c("Uğurlu", "Bloklandı", "Xəbərdarlıq"), c("#d4edda", "#f8d7da", "#fff3cd")))
  })

  output$sebeke_chart <- renderPlotly({
    plot_ly(server_metrics, x = ~saat) %>%
      add_trace(y = ~network_in, name = "Giriş", type = "scatter", mode = "lines+markers",
                line = list(color = "#00a65a", width = 2)) %>%
      add_trace(y = ~network_out, name = "Çıxış", type = "scatter", mode = "lines+markers",
                line = list(color = "#e94560", width = 2)) %>%
      layout(xaxis = list(title = "Saat", color = "#ccc"),
             yaxis = list(title = "Mb/s", color = "#ccc"),
             paper_bgcolor = "rgba(0,0,0,0)", plot_bgcolor = "rgba(0,0,0,0)",
             font = list(color = "#ccc"))
  })
}

shinyApp(ui = ui, server = server)
