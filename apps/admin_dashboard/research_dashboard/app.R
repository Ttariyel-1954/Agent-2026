# ============================================================
# ARTI 2026 - TƏDQİQAT VƏ ANALİTİKA PANELİ
# Elmi-Pedaqoji Tədqiqat, Nəşrlər, Doktorantura
# ============================================================

library(shiny)
library(shinydashboard)
library(plotly)
library(DT)
library(dplyr)

# ===== NÜMUNƏ MƏLUMATLAR =====

set.seed(2026)

saheler <- c("Qiymətləndirmə", "Pedaqoji innovasiya", "Müəllim peşəkarlığı",
             "İnkluziv təhsil", "STEAM", "Kurikulum", "Təhsil siyasəti", "Rəqəmsal təhsil")

layiheler <- data.frame(
  layihe_id = paste0("RP_", sprintf("%03d", 1:30)),
  bashliq = paste("Tədqiqat:", sample(c(
    "CAT testlərin effektivliyi", "MST metodologiyasının tətbiqi",
    "Müəllim sertifikasiya sisteminin analizi", "STEAM layihələrinin nəticələri",
    "Rəqəmsal kurikulumun hazırlanması", "İnkluziv təhsil strategiyası",
    "Onlayn qiymətləndirmə metodları", "Təhsil keyfiyyətinin ölçülməsi",
    "Şagird motivasiyası tədqiqatı", "Valideyn-məktəb əlaqəsi"
  ), 30, replace = TRUE)),
  sahe = sample(saheler, 30, replace = TRUE),
  metod = sample(c("Eksperimental", "Kəmiyyət", "Keyfiyyət", "Qarışıq"), 30, replace = TRUE),
  rehber = sample(paste0("Dr. ", c("Əliyev T.", "Həsənov M.", "Məmmədova S.",
                                    "Quliyeva N.", "Babayev R.", "Kərimov F.")), 30, replace = TRUE),
  status = sample(c("Təklif", "Təsdiqləndi", "Aktiv", "Tamamlandı", "Nəşr olundu"),
                  30, replace = TRUE, prob = c(0.15, 0.1, 0.3, 0.25, 0.2)),
  baslama = format(as.Date("2024-01-01") + sample(0:600, 30, replace = TRUE), "%d.%m.%Y"),
  butce = sample(5000:50000, 30),
  stringsAsFactors = FALSE
)

neshrler <- data.frame(
  neshr_id = paste0("PUB_", sprintf("%03d", 1:50)),
  bashliq = paste("Məqalə:", sample(c(
    "IRT modelinin tətbiqi", "Adaptiv testləşdirmə Azərbaycanda",
    "Müəllim hazırlığı", "STEAM metodologiyası", "Rəqəmsal təhsil",
    "Kurikulum reforması", "Şagird nailiyyətləri", "İnkluziv təhsil"
  ), 50, replace = TRUE)),
  nov = sample(c("Jurnal məqaləsi", "Konfrans", "Hesabat", "Kitab fəsli", "Monoqrafiya"),
               50, replace = TRUE, prob = c(0.4, 0.25, 0.2, 0.1, 0.05)),
  jurnal = sample(c("Təhsil Jurnalı", "Pedaqogika", "İnnovativ Təhsil",
                     "Beynəlxalq Jurnal", "ARTI Bülleteni", NA), 50, replace = TRUE),
  il = sample(2022:2026, 50, replace = TRUE, prob = c(0.1, 0.15, 0.2, 0.25, 0.3)),
  istinad = sample(0:45, 50, replace = TRUE),
  stringsAsFactors = FALSE
)

doktorantlar <- data.frame(
  id = paste0("DOC_", sprintf("%03d", 1:20)),
  ad_soyad = paste(sample(c("Əliyev", "Həsənov", "Məmmədov", "Quliyev", "Babayev"), 20, replace = TRUE),
                   sample(c("Anar", "Günel", "Fərid", "Nigar", "Rəşad"), 20, replace = TRUE)),
  movzu = paste("Dissertasiya:", sample(c("CAT", "IRT", "MST", "STEAM", "Kurikulum", "Pedaqogika"), 20, replace = TRUE)),
  rehber = sample(paste0("Prof. ", c("Əliyev", "Həsənov", "Məmmədova")), 20, replace = TRUE),
  il = sample(1:4, 20, replace = TRUE),
  status = sample(c("Davam edir", "Müdafiə", "Tamamlandı"), 20, replace = TRUE, prob = c(0.6, 0.15, 0.25)),
  stringsAsFactors = FALSE
)


# ===== UI =====

ui <- dashboardPage(
  skin = "blue",
  dashboardHeader(title = "ARTI - Tədqiqat", titleWidth = 280),

  dashboardSidebar(
    width = 280,
    sidebarMenu(
      menuItem("Ümumi Baxış", tabName = "umumi", icon = icon("flask")),
      menuItem("Layihələr", tabName = "layihe", icon = icon("project-diagram")),
      menuItem("Nəşrlər", tabName = "neshr", icon = icon("book")),
      menuItem("Doktorantura", tabName = "dokt", icon = icon("graduation-cap")),
      menuItem("Analitika", tabName = "anal", icon = icon("chart-pie")),
      hr(),
      selectInput("sahe_f", "Tədqiqat sahəsi:", c("Hamısı", saheler))
    )
  ),

  dashboardBody(
    tags$head(tags$style(HTML(".box-header { border-bottom: 2px solid #3c8dbc; }"))),
    tabItems(
      tabItem(tabName = "umumi",
        h3("Elmi-Pedaqoji Tədqiqat Mərkəzi", style = "margin-top: 0;"),
        fluidRow(
          valueBox(nrow(layiheler), "Tədqiqat Layihəsi", icon = icon("flask"), color = "blue", width = 3),
          valueBox(nrow(neshrler), "Nəşr", icon = icon("book"), color = "green", width = 3),
          valueBox(nrow(doktorantlar), "Doktorant", icon = icon("user-graduate"), color = "yellow", width = 3),
          valueBox(paste0(format(sum(layiheler$butce), big.mark = " "), " AZN"),
                   "Ümumi Büdcə", icon = icon("money-bill"), color = "red", width = 3)
        ),
        fluidRow(
          box(title = "Layihə Statusu", status = "primary", solidHeader = TRUE, width = 6,
              plotlyOutput("layihe_status_bar", height = "300px")),
          box(title = "Sahələr üzrə Layihə Sayı", status = "success", solidHeader = TRUE, width = 6,
              plotlyOutput("sahe_bar", height = "300px"))
        ),
        fluidRow(
          box(title = "İllik Nəşr Dinamikası", status = "info", solidHeader = TRUE, width = 8,
              plotlyOutput("neshr_illik", height = "300px")),
          box(title = "Nəşr Növləri", status = "warning", solidHeader = TRUE, width = 4,
              plotlyOutput("neshr_nov_pie", height = "300px"))
        )
      ),

      tabItem(tabName = "layihe",
        h3("Tədqiqat Layihələri"),
        box(title = "Layihələr", status = "primary", solidHeader = TRUE, width = 12,
            DT::dataTableOutput("layihe_table"))
      ),

      tabItem(tabName = "neshr",
        h3("Nəşrlər"),
        box(title = "Nəşr Siyahısı", status = "primary", solidHeader = TRUE, width = 12,
            DT::dataTableOutput("neshr_table"))
      ),

      tabItem(tabName = "dokt",
        h3("Doktorantura Proqramları"),
        fluidRow(
          infoBox("Davam edir", sum(doktorantlar$status == "Davam edir"),
                  icon = icon("spinner"), color = "blue", width = 4),
          infoBox("Müdafiə", sum(doktorantlar$status == "Müdafiə"),
                  icon = icon("shield"), color = "yellow", width = 4),
          infoBox("Tamamlandı", sum(doktorantlar$status == "Tamamlandı"),
                  icon = icon("check"), color = "green", width = 4)
        ),
        box(title = "Doktorantlar", status = "primary", solidHeader = TRUE, width = 12,
            DT::dataTableOutput("dokt_table"))
      ),

      tabItem(tabName = "anal",
        h3("Tədqiqat Analitikası"),
        fluidRow(
          box(title = "Metod üzrə Layihə", status = "primary", solidHeader = TRUE, width = 6,
              plotlyOutput("metod_pie", height = "300px")),
          box(title = "Büdcə Paylanması", status = "info", solidHeader = TRUE, width = 6,
              plotlyOutput("butce_hist", height = "300px"))
        )
      )
    )
  )
)

server <- function(input, output, session) {

  output$layihe_status_bar <- renderPlotly({
    df <- layiheler %>% count(status) %>%
      mutate(status = factor(status, levels = c("Təklif", "Təsdiqləndi", "Aktiv", "Tamamlandı", "Nəşr olundu")))
    plot_ly(df, x = ~status, y = ~n, type = "bar",
            marker = list(color = c("#999", "#3c8dbc", "#00a65a", "#f39c12", "#605ca8")),
            text = ~n, textposition = "outside") %>%
      layout(xaxis = list(title = ""), yaxis = list(title = "Layihə Sayı"))
  })

  output$sahe_bar <- renderPlotly({
    df <- layiheler %>% count(sahe) %>% arrange(desc(n))
    plot_ly(df, x = ~reorder(sahe, n), y = ~n, type = "bar",
            marker = list(color = "#3c8dbc"), text = ~n, textposition = "outside") %>%
      layout(xaxis = list(title = ""), yaxis = list(title = "Sayı"), margin = list(b = 80))
  })

  output$neshr_illik <- renderPlotly({
    df <- neshrler %>% count(il) %>% arrange(il)
    plot_ly(df, x = ~il, y = ~n, type = "scatter", mode = "lines+markers",
            line = list(color = "#00a65a", width = 3), marker = list(size = 10),
            text = ~n, textposition = "top") %>%
      layout(xaxis = list(title = "İl"), yaxis = list(title = "Nəşr Sayı"))
  })

  output$neshr_nov_pie <- renderPlotly({
    df <- neshrler %>% count(nov)
    plot_ly(df, labels = ~nov, values = ~n, type = "pie", hole = 0.4, textinfo = "label+percent") %>%
      layout(showlegend = FALSE, margin = list(l = 5, r = 5, t = 20, b = 5))
  })

  output$layihe_table <- DT::renderDataTable({
    datatable(layiheler, colnames = c("ID", "Başlıq", "Sahə", "Metod", "Rəhbər", "Status", "Başlama", "Büdcə (AZN)"),
              options = list(pageLength = 12, scrollX = TRUE), rownames = FALSE, filter = "top") %>%
      formatCurrency("butce", currency = "", digits = 0) %>%
      formatStyle("status", backgroundColor = styleEqual(
        c("Aktiv", "Tamamlandı", "Nəşr olundu", "Təsdiqləndi", "Təklif"),
        c("#d4edda", "#cce5ff", "#d1c4e9", "#fff3cd", "#f8d7da")))
  })

  output$neshr_table <- DT::renderDataTable({
    datatable(neshrler, colnames = c("ID", "Başlıq", "Növ", "Jurnal", "İl", "İstinad"),
              options = list(pageLength = 12, scrollX = TRUE), rownames = FALSE, filter = "top")
  })

  output$dokt_table <- DT::renderDataTable({
    datatable(doktorantlar, colnames = c("ID", "Ad Soyad", "Mövzu", "Rəhbər", "İl", "Status"),
              options = list(pageLength = 10, dom = "t"), rownames = FALSE) %>%
      formatStyle("status", backgroundColor = styleEqual(
        c("Davam edir", "Müdafiə", "Tamamlandı"), c("#cce5ff", "#fff3cd", "#d4edda")))
  })

  output$metod_pie <- renderPlotly({
    df <- layiheler %>% count(metod)
    plot_ly(df, labels = ~metod, values = ~n, type = "pie", hole = 0.4, textinfo = "label+percent") %>%
      layout(showlegend = FALSE)
  })

  output$butce_hist <- renderPlotly({
    plot_ly(layiheler, x = ~butce, type = "histogram",
            marker = list(color = "#f39c12"), nbinsx = 15) %>%
      layout(xaxis = list(title = "Büdcə (AZN)"), yaxis = list(title = "Layihə Sayı"))
  })
}

shinyApp(ui = ui, server = server)
