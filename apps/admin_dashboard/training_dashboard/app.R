# ============================================================
# ARTI 2026 - MÜƏLLİM TƏLİM VƏ PEŞƏKAR İNKİŞAF PANELİ
# Təlimlər, kurslar, mentorluq, qiymətləndirmə
# ============================================================

library(shiny)
library(shinydashboard)
library(plotly)
library(DT)
library(dplyr)

# ===== NÜMUNƏ MƏLUMATLAR =====

set.seed(2026)

telim_proqramlari <- data.frame(
  proqram_id = paste0("TP_", sprintf("%03d", 1:15)),
  bashliq = c(
    "CAT/MST Test Texnologiyaları", "Rəqəmsal Savadlıq", "İnkluziv Təhsil Seminarı",
    "STEAM Metodologiyası", "Kurikulum Yenilənməsi", "Fəal Təlim Metodları",
    "Onlayn Təlim Platformaları", "Şagird Qiymətləndirmə", "Sinif İdarəetməsi",
    "Tənqidi Təfəkkür Təlimi", "Layihəyə Əsaslanan Təlim", "Diferensial Təlim",
    "Formativ Qiymətləndirmə", "Təhsil Texnologiyaları", "Liderlik Təlimi"
  ),
  nov = sample(c("Üz-üzə", "Onlayn", "Qarışıq"), 15, replace = TRUE, prob = c(0.3, 0.4, 0.3)),
  sahe = sample(c("Pedaqogika", "Texnologiya", "Qiymətləndirmə", "Kurikulum", "İdarəetmə"), 15, replace = TRUE),
  saat = sample(c(16, 24, 32, 40, 48, 72), 15, replace = TRUE),
  max_ishtirk = sample(c(20, 25, 30, 40, 50), 15, replace = TRUE),
  qeydiyyat = sample(10:50, 15, replace = TRUE),
  tamamlayan = sample(8:45, 15, replace = TRUE),
  ort_pre = round(runif(15, 40, 65), 1),
  ort_post = round(runif(15, 55, 90), 1),
  memuniyet = round(runif(15, 3.2, 5.0), 1),
  status = sample(c("Planlaşdırılır", "Davam edir", "Tamamlandı"), 15, replace = TRUE, prob = c(0.2, 0.35, 0.45)),
  stringsAsFactors = FALSE
)
telim_proqramlari$inkishaf <- telim_proqramlari$ort_post - telim_proqramlari$ort_pre

# İştirakçılar
n_part <- 200
ishtirk <- data.frame(
  muellim_id = paste0("TCH_", sprintf("%04d", 1:n_part)),
  ad_soyad = paste(sample(c("Əliyev", "Həsənov", "Məmmədov", "Quliyev", "Babayev",
                             "Əliyeva", "Həsənova", "Məmmədova"), n_part, replace = TRUE),
                   sample(c("Anar", "Günel", "Fərid", "Nigar", "Rəşad", "Sevinc"), n_part, replace = TRUE)),
  proqram = sample(telim_proqramlari$bashliq, n_part, replace = TRUE),
  pre_bal = round(runif(n_part, 30, 75), 1),
  post_bal = round(runif(n_part, 45, 95), 1),
  davamiyyet = round(runif(n_part, 50, 100), 1),
  sertifikat = sample(c("Bəli", "Xeyr"), n_part, replace = TRUE, prob = c(0.7, 0.3)),
  memuniyet = sample(1:5, n_part, replace = TRUE, prob = c(0.02, 0.05, 0.15, 0.38, 0.4)),
  stringsAsFactors = FALSE
)
ishtirk$inkishaf <- ishtirk$post_bal - ishtirk$pre_bal


# ===== UI =====

ui <- dashboardPage(
  skin = "green",
  dashboardHeader(title = "ARTI - Peşəkar İnkişaf", titleWidth = 300),

  dashboardSidebar(
    width = 300,
    sidebarMenu(
      menuItem("Ümumi Baxış", tabName = "umumi", icon = icon("graduation-cap")),
      menuItem("Təlim Proqramları", tabName = "proqram", icon = icon("chalkboard")),
      menuItem("İştirakçılar", tabName = "ishtirk", icon = icon("users")),
      menuItem("Effektivlik", tabName = "effektiv", icon = icon("chart-line")),
      menuItem("Məmnuniyyət", tabName = "memnun", icon = icon("smile")),
      hr(),
      selectInput("nov_f", "Təlim növü:", c("Hamısı", "Üz-üzə", "Onlayn", "Qarışıq")),
      selectInput("sahe_f2", "Sahə:", c("Hamısı", "Pedaqogika", "Texnologiya", "Qiymətləndirmə", "Kurikulum", "İdarəetmə"))
    )
  ),

  dashboardBody(
    tags$head(tags$style(HTML(".box-header { border-bottom: 2px solid #00a65a; }"))),
    tabItems(
      tabItem(tabName = "umumi",
        h3("Müəllim Peşəkar İnkişaf - Ümumi Baxış", style = "margin-top: 0;"),
        fluidRow(
          valueBox(nrow(telim_proqramlari), "Təlim Proqramı", icon = icon("chalkboard"), color = "green", width = 3),
          valueBox(sum(telim_proqramlari$qeydiyyat), "Qeydiyyat", icon = icon("user-plus"), color = "blue", width = 3),
          valueBox(sum(telim_proqramlari$tamamlayan), "Tamamlayan", icon = icon("check"), color = "yellow", width = 3),
          valueBox(paste0("+", round(mean(telim_proqramlari$inkishaf), 1)), "Orta İnkişaf",
                   icon = icon("arrow-up"), color = "red", width = 3, subtitle = "Post - Pre bal")
        ),
        fluidRow(
          box(title = "Pre vs Post Bal (Hər proqram)", status = "primary", solidHeader = TRUE, width = 8, height = 420,
              plotlyOutput("pre_post_chart", height = "360px")),
          box(title = "Təlim Növü", status = "success", solidHeader = TRUE, width = 4, height = 420,
              plotlyOutput("nov_pie", height = "170px"),
              hr(),
              plotlyOutput("status_pie2", height = "170px"))
        ),
        fluidRow(
          box(title = "Proqram üzrə Məmnuniyyət (5 ballıq)", status = "info", solidHeader = TRUE, width = 12,
              plotlyOutput("memnun_bar", height = "300px"))
        )
      ),

      tabItem(tabName = "proqram",
        h3("Təlim Proqramları"),
        box(title = "Bütün Proqramlar", status = "primary", solidHeader = TRUE, width = 12,
            DT::dataTableOutput("proqram_table"))
      ),

      tabItem(tabName = "ishtirk",
        h3("İştirakçılar"),
        box(title = "Müəllim İştirakçılar", status = "primary", solidHeader = TRUE, width = 12,
            DT::dataTableOutput("ishtirk_table"))
      ),

      tabItem(tabName = "effektiv",
        h3("Təlim Effektivliyi"),
        fluidRow(
          box(title = "Pre vs Post Bal (Hər müəllim)", status = "primary", solidHeader = TRUE, width = 6,
              plotlyOutput("pre_post_scatter", height = "350px")),
          box(title = "İnkişaf Paylanması", status = "success", solidHeader = TRUE, width = 6,
              plotlyOutput("inkishaf_hist", height = "350px"))
        ),
        fluidRow(
          box(title = "Davamiyyət vs İnkişaf", status = "info", solidHeader = TRUE, width = 12,
              plotlyOutput("davamiyyet_inkishaf", height = "350px"))
        )
      ),

      tabItem(tabName = "memnun",
        h3("Məmnuniyyət Analizi"),
        fluidRow(
          box(title = "Məmnuniyyət Paylanması", status = "primary", solidHeader = TRUE, width = 6,
              plotlyOutput("memnun_hist", height = "300px")),
          box(title = "Məmnuniyyət vs İnkişaf", status = "info", solidHeader = TRUE, width = 6,
              plotlyOutput("memnun_inkishaf", height = "300px"))
        )
      )
    )
  )
)

server <- function(input, output, session) {

  output$pre_post_chart <- renderPlotly({
    df <- telim_proqramlari %>% arrange(desc(inkishaf))
    plot_ly(df, x = ~reorder(bashliq, inkishaf)) %>%
      add_trace(y = ~ort_pre, name = "Pre-test", type = "bar", marker = list(color = "#f39c12")) %>%
      add_trace(y = ~ort_post, name = "Post-test", type = "bar", marker = list(color = "#00a65a")) %>%
      layout(barmode = "group", xaxis = list(title = "", tickangle = -45),
             yaxis = list(title = "Bal"), legend = list(orientation = "h", y = -0.3), margin = list(b = 150))
  })

  output$nov_pie <- renderPlotly({
    df <- telim_proqramlari %>% count(nov)
    plot_ly(df, labels = ~nov, values = ~n, type = "pie", hole = 0.45,
            marker = list(colors = c("#3c8dbc", "#00a65a", "#f39c12")), textinfo = "label+percent") %>%
      layout(showlegend = FALSE, margin = list(l = 5, r = 5, t = 5, b = 5))
  })

  output$status_pie2 <- renderPlotly({
    df <- telim_proqramlari %>% count(status)
    plot_ly(df, labels = ~status, values = ~n, type = "pie", hole = 0.45,
            marker = list(colors = c("#f39c12", "#3c8dbc", "#00a65a")), textinfo = "label+percent") %>%
      layout(showlegend = FALSE, margin = list(l = 5, r = 5, t = 5, b = 5))
  })

  output$memnun_bar <- renderPlotly({
    df <- telim_proqramlari %>% arrange(desc(memuniyet))
    colors <- ifelse(df$memuniyet >= 4.5, "#00a65a", ifelse(df$memuniyet >= 3.5, "#f39c12", "#dd4b39"))
    plot_ly(df, x = ~reorder(bashliq, memuniyet), y = ~memuniyet, type = "bar",
            marker = list(color = colors),
            text = ~memuniyet, textposition = "outside") %>%
      layout(xaxis = list(title = "", tickangle = -45),
             yaxis = list(title = "Bal (5-lik)", range = c(0, 5.5)), margin = list(b = 150))
  })

  output$proqram_table <- DT::renderDataTable({
    datatable(telim_proqramlari,
              colnames = c("ID", "Başlıq", "Növ", "Sahə", "Saat", "Max", "Qeydiyyat",
                           "Tamamlayan", "Pre Bal", "Post Bal", "Məmnuniyyət", "Status", "İnkişaf"),
              options = list(pageLength = 15, scrollX = TRUE), rownames = FALSE) %>%
      formatStyle("inkishaf",
                  background = styleColorBar(c(-10, 40), "#00a65a"),
                  backgroundSize = "90% 70%", backgroundRepeat = "no-repeat", backgroundPosition = "left") %>%
      formatStyle("status", backgroundColor = styleEqual(
        c("Tamamlandı", "Davam edir", "Planlaşdırılır"), c("#d4edda", "#cce5ff", "#fff3cd")))
  })

  output$ishtirk_table <- DT::renderDataTable({
    datatable(ishtirk,
              colnames = c("ID", "Ad Soyad", "Proqram", "Pre Bal", "Post Bal",
                           "Davamiyyət%", "Sertifikat", "Məmnuniyyət", "İnkişaf"),
              options = list(pageLength = 15, scrollX = TRUE), rownames = FALSE, filter = "top") %>%
      formatStyle("sertifikat", backgroundColor = styleEqual(c("Bəli", "Xeyr"), c("#d4edda", "#f8d7da"))) %>%
      formatStyle("inkishaf",
                  color = styleInterval(0, c("#dd4b39", "#00a65a")), fontWeight = "bold")
  })

  output$pre_post_scatter <- renderPlotly({
    plot_ly(ishtirk, x = ~pre_bal, y = ~post_bal, color = ~sertifikat,
            colors = c("Bəli" = "#00a65a", "Xeyr" = "#dd4b39"),
            type = "scatter", mode = "markers", marker = list(size = 5, opacity = 0.6)) %>%
      add_trace(x = c(0, 100), y = c(0, 100), type = "scatter", mode = "lines",
                line = list(color = "gray", dash = "dash"), name = "Bərabər xətt") %>%
      layout(xaxis = list(title = "Pre Bal"), yaxis = list(title = "Post Bal"))
  })

  output$inkishaf_hist <- renderPlotly({
    plot_ly(ishtirk, x = ~inkishaf, type = "histogram",
            marker = list(color = "#00a65a"), nbinsx = 25) %>%
      layout(xaxis = list(title = "İnkişaf (Post - Pre)"), yaxis = list(title = "Müəllim Sayı"))
  })

  output$davamiyyet_inkishaf <- renderPlotly({
    plot_ly(ishtirk, x = ~davamiyyet, y = ~inkishaf, color = ~sertifikat,
            colors = c("Bəli" = "#3c8dbc", "Xeyr" = "#f39c12"),
            type = "scatter", mode = "markers", marker = list(size = 5, opacity = 0.6)) %>%
      layout(xaxis = list(title = "Davamiyyət (%)"), yaxis = list(title = "İnkişaf"))
  })

  output$memnun_hist <- renderPlotly({
    df <- ishtirk %>% count(memuniyet)
    plot_ly(df, x = ~factor(memuniyet), y = ~n, type = "bar",
            marker = list(color = c("#dd4b39", "#f39c12", "#3c8dbc", "#00a65a", "#00c0ef")),
            text = ~n, textposition = "outside") %>%
      layout(xaxis = list(title = "Məmnuniyyət (1-5)"), yaxis = list(title = "Müəllim Sayı"))
  })

  output$memnun_inkishaf <- renderPlotly({
    df <- ishtirk %>% group_by(memuniyet) %>%
      summarise(ort_ink = round(mean(inkishaf), 1), .groups = "drop")
    plot_ly(df, x = ~factor(memuniyet), y = ~ort_ink, type = "bar",
            marker = list(color = "#605ca8"), text = ~ort_ink, textposition = "outside") %>%
      layout(xaxis = list(title = "Məmnuniyyət"), yaxis = list(title = "Orta İnkişaf"))
  })
}

shinyApp(ui = ui, server = server)
