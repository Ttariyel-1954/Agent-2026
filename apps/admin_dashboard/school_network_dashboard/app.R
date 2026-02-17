# ============================================================
# ARTI 2026 - MƏKTƏB ŞƏBƏKƏSİ PANELİ
# Lisey, Gimnaziya, Ümumi Məktəb - Məlumat Toplama
# ============================================================

library(shiny)
library(shinydashboard)
library(plotly)
library(DT)
library(dplyr)

# ===== NÜMUNƏ MƏLUMATLAR =====

set.seed(2026)

n_schools <- 80

regionlar <- c("Bakı", "Gəncə", "Sumqayıt", "Mingəçevir", "Şəki",
               "Lənkəran", "Naxçıvan", "Şirvan", "Quba", "Şamaxı",
               "Bərdə", "Ağdam", "Şuşa", "Zaqatala", "Balakən")

mektebler <- data.frame(
  mekteb_id = paste0("SCH_", sprintf("%03d", 1:n_schools)),
  mekteb_adi = paste0(
    sample(regionlar, n_schools, replace = TRUE), " ",
    sample(c("Lisey", "Gimnaziya", "Məktəb"), n_schools, replace = TRUE, prob = c(0.3, 0.25, 0.45)),
    " #", sample(1:30, n_schools, replace = TRUE)
  ),
  tip = sample(c("Lisey", "Gimnaziya", "Ümumi"), n_schools, replace = TRUE, prob = c(0.3, 0.25, 0.45)),
  region = sample(regionlar, n_schools, replace = TRUE),
  shagird = sample(150:900, n_schools),
  muellim = sample(15:65, n_schools),
  sinif_sayi = sample(8:30, n_schools),
  komp_lab = sample(c("Var", "Yoxdur"), n_schools, replace = TRUE, prob = c(0.65, 0.35)),
  internet = sample(c("Yüksək (100+ Mbps)", "Orta (10-100 Mbps)", "Zəif (<10 Mbps)", "Yoxdur"),
                    n_schools, replace = TRUE, prob = c(0.2, 0.4, 0.3, 0.1)),
  cat_test = sample(c("Bəli", "Xeyr"), n_schools, replace = TRUE, prob = c(0.5, 0.5)),
  mst_test = sample(c("Bəli", "Xeyr"), n_schools, replace = TRUE, prob = c(0.4, 0.6)),
  ort_bal = round(runif(n_schools, 30, 90), 1),
  ort_theta = round(rnorm(n_schools, 0.1, 0.8), 2),
  kechid_faizi = round(runif(n_schools, 30, 98), 1),
  son_test_tarixi = format(Sys.Date() - sample(1:120, n_schools, replace = TRUE), "%d.%m.%Y"),
  stringsAsFactors = FALSE
)

mektebler$shagird_muellim = round(mektebler$shagird / mektebler$muellim, 1)

# Regionlar üzrə
region_stat <- mektebler %>%
  group_by(region) %>%
  summarise(
    mekteb_sayi = n(),
    shagird = sum(shagird),
    muellim = sum(muellim),
    ort_bal = round(mean(ort_bal), 1),
    kechid = round(mean(kechid_faizi), 1),
    komp_lab_faiz = round(mean(komp_lab == "Var") * 100, 1),
    .groups = "drop"
  ) %>% arrange(desc(mekteb_sayi))


# ===== UI =====

ui <- dashboardPage(
  skin = "yellow",
  dashboardHeader(title = "ARTI - Məktəb Şəbəkəsi", titleWidth = 300),

  dashboardSidebar(
    width = 300,
    sidebarMenu(
      menuItem("Ümumi Baxış", tabName = "umumi", icon = icon("globe")),
      menuItem("Məktəb Siyahısı", tabName = "siyahi", icon = icon("list")),
      menuItem("Region Analizi", tabName = "region", icon = icon("map")),
      menuItem("İnfrastruktur", tabName = "infra", icon = icon("server")),
      menuItem("Test Əhatəsi", tabName = "ehat", icon = icon("check-double")),
      menuItem("Müqayisə", tabName = "muq", icon = icon("balance-scale")),
      hr(),
      selectInput("reg_f", "Region:", c("Hamısı", regionlar)),
      selectInput("tip_f", "Tip:", c("Hamısı", "Lisey", "Gimnaziya", "Ümumi")),
      checkboxInput("cat_f", "Yalnız CAT keçirilən", FALSE),
      checkboxInput("mst_f", "Yalnız MST keçirilən", FALSE)
    )
  ),

  dashboardBody(
    tags$head(tags$style(HTML("
      .content-wrapper { background-color: #f4f6f9; }
      .box-header { border-bottom: 2px solid #f39c12; }
    "))),

    tabItems(
      # ÜMUMİ
      tabItem(tabName = "umumi",
        h3("Məktəb Şəbəkəsi - Ümumi Baxış", style = "margin-top: 0;"),
        fluidRow(
          valueBox(n_schools, "Məktəb", icon = icon("school"), color = "blue", width = 2),
          valueBox(format(sum(mektebler$shagird), big.mark = " "), "Şagird",
                   icon = icon("users"), color = "green", width = 2),
          valueBox(format(sum(mektebler$muellim), big.mark = " "), "Müəllim",
                   icon = icon("chalkboard-teacher"), color = "yellow", width = 2),
          valueBox(paste0(round(mean(mektebler$ort_bal), 1), "%"), "Orta Bal",
                   icon = icon("chart-line"), color = "red", width = 2),
          valueBox(sum(mektebler$cat_test == "Bəli"), "CAT Əhatə",
                   icon = icon("laptop"), color = "purple", width = 2),
          valueBox(sum(mektebler$mst_test == "Bəli"), "MST Əhatə",
                   icon = icon("layer-group"), color = "aqua", width = 2)
        ),
        fluidRow(
          box(title = "Regionlar üzrə Məktəb Sayı", status = "primary", solidHeader = TRUE, width = 6, height = 420,
              plotlyOutput("region_bar_plot", height = "360px")),
          box(title = "Məktəb Tipləri", status = "success", solidHeader = TRUE, width = 3, height = 420,
              plotlyOutput("tip_pie_plot", height = "360px")),
          box(title = "İnternet Vəziyyəti", status = "warning", solidHeader = TRUE, width = 3, height = 420,
              plotlyOutput("internet_pie", height = "360px"))
        ),
        fluidRow(
          box(title = "Orta Bal vs Şagird Sayı (hər nöqtə bir məktəb)", status = "info",
              solidHeader = TRUE, width = 12, height = 420,
              plotlyOutput("scatter_all", height = "360px"))
        )
      ),

      # SİYAHI
      tabItem(tabName = "siyahi",
        h3("Məktəb Siyahısı"),
        box(title = "Bütün Məktəblər", status = "primary", solidHeader = TRUE, width = 12,
            DT::dataTableOutput("mekteb_full_table"))
      ),

      # REGİON
      tabItem(tabName = "region",
        h3("Region Analizi"),
        fluidRow(
          box(title = "Region Statistikası", status = "primary", solidHeader = TRUE, width = 12,
              DT::dataTableOutput("region_table"))
        ),
        fluidRow(
          box(title = "Regionlar üzrə Orta Bal", status = "info", solidHeader = TRUE, width = 6,
              plotlyOutput("region_bal_chart", height = "350px")),
          box(title = "Regionlar üzrə Komp. Lab Əhatəsi", status = "success", solidHeader = TRUE, width = 6,
              plotlyOutput("region_infra_chart", height = "350px"))
        )
      ),

      # İNFRASTRUKTUR
      tabItem(tabName = "infra",
        h3("İnfrastruktur Vəziyyəti"),
        fluidRow(
          infoBox("Komp. Lab Var", paste0(round(mean(mektebler$komp_lab == "Var") * 100), "%"),
                  icon = icon("desktop"), color = "blue", width = 4),
          infoBox("Yaxşı İnternet", paste0(round(mean(mektebler$internet %in% c("Yüksək (100+ Mbps)", "Orta (10-100 Mbps)")) * 100), "%"),
                  icon = icon("wifi"), color = "green", width = 4),
          infoBox("Ort. Şagird/Müəllim", round(mean(mektebler$shagird_muellim), 1),
                  icon = icon("users"), color = "yellow", width = 4)
        ),
        fluidRow(
          box(title = "Kompüter Laboratoriyası", status = "primary", solidHeader = TRUE, width = 6,
              plotlyOutput("komp_bar", height = "300px")),
          box(title = "İnternet Sürəti", status = "info", solidHeader = TRUE, width = 6,
              plotlyOutput("internet_bar", height = "300px"))
        )
      ),

      # TEST ƏHATƏSİ
      tabItem(tabName = "ehat",
        h3("CAT/MST Test Əhatəsi"),
        fluidRow(
          box(title = "Test Əhatəsi", status = "primary", solidHeader = TRUE, width = 6,
              plotlyOutput("ehat_bar", height = "300px")),
          box(title = "Tip üzrə Test Əhatəsi", status = "info", solidHeader = TRUE, width = 6,
              plotlyOutput("ehat_tip", height = "300px"))
        )
      ),

      # MÜQAYİSƏ
      tabItem(tabName = "muq",
        h3("Məktəb Tipləri Müqayisəsi"),
        fluidRow(
          box(title = "Tip üzrə Orta Bal", status = "primary", solidHeader = TRUE, width = 6,
              plotlyOutput("tip_compare_bal", height = "300px")),
          box(title = "Tip üzrə Theta", status = "success", solidHeader = TRUE, width = 6,
              plotlyOutput("tip_compare_theta", height = "300px"))
        )
      )
    )
  )
)


# ===== SERVER =====

server <- function(input, output, session) {

  filt <- reactive({
    df <- mektebler
    if (input$reg_f != "Hamısı") df <- df %>% filter(region == input$reg_f)
    if (input$tip_f != "Hamısı") df <- df %>% filter(tip == input$tip_f)
    if (input$cat_f) df <- df %>% filter(cat_test == "Bəli")
    if (input$mst_f) df <- df %>% filter(mst_test == "Bəli")
    df
  })

  output$region_bar_plot <- renderPlotly({
    df <- filt() %>% count(region) %>% arrange(desc(n))
    plot_ly(df, x = ~reorder(region, n), y = ~n, type = "bar",
            marker = list(color = "#3c8dbc"), text = ~n, textposition = "outside") %>%
      layout(xaxis = list(title = ""), yaxis = list(title = "Məktəb Sayı"), margin = list(b = 80))
  })

  output$tip_pie_plot <- renderPlotly({
    df <- filt() %>% count(tip)
    plot_ly(df, labels = ~tip, values = ~n, type = "pie",
            marker = list(colors = c("#00a65a", "#3c8dbc", "#f39c12")), hole = 0.4,
            textinfo = "label+percent") %>%
      layout(showlegend = FALSE, margin = list(l = 10, r = 10, t = 10, b = 10))
  })

  output$internet_pie <- renderPlotly({
    df <- filt() %>% count(internet)
    plot_ly(df, labels = ~internet, values = ~n, type = "pie",
            marker = list(colors = c("#00a65a", "#f39c12", "#dd4b39", "#999999")), hole = 0.4,
            textinfo = "label+percent") %>%
      layout(showlegend = FALSE, margin = list(l = 5, r = 5, t = 5, b = 5))
  })

  output$scatter_all <- renderPlotly({
    df <- filt()
    plot_ly(df, x = ~shagird, y = ~ort_bal, color = ~tip,
            size = ~muellim, sizes = c(5, 25),
            type = "scatter", mode = "markers",
            marker = list(opacity = 0.7),
            text = ~paste0(mekteb_adi, "<br>Şagird: ", shagird,
                           "<br>Orta Bal: ", ort_bal, "<br>Müəllim: ", muellim)) %>%
      layout(xaxis = list(title = "Şagird Sayı"), yaxis = list(title = "Orta Bal (%)"))
  })

  output$mekteb_full_table <- DT::renderDataTable({
    df <- filt() %>%
      select(mekteb_id, mekteb_adi, tip, region, shagird, muellim, komp_lab, internet,
             cat_test, mst_test, ort_bal, kechid_faizi, son_test_tarixi)
    datatable(df,
              colnames = c("ID", "Məktəb", "Tip", "Region", "Şagird", "Müəllim", "Komp.Lab",
                           "İnternet", "CAT", "MST", "Ort.Bal", "Keçid%", "Son Test"),
              options = list(pageLength = 15, scrollX = TRUE), rownames = FALSE, filter = "top") %>%
      formatStyle("ort_bal",
                  background = styleColorBar(c(0, 100), "#3c8dbc"),
                  backgroundSize = "90% 70%", backgroundRepeat = "no-repeat", backgroundPosition = "left") %>%
      formatStyle("cat_test", backgroundColor = styleEqual(c("Bəli", "Xeyr"), c("#d4edda", "#f8d7da"))) %>%
      formatStyle("mst_test", backgroundColor = styleEqual(c("Bəli", "Xeyr"), c("#d4edda", "#f8d7da")))
  })

  output$region_table <- DT::renderDataTable({
    datatable(region_stat,
              colnames = c("Region", "Məktəb", "Şagird", "Müəllim", "Ort.Bal", "Keçid%", "Komp.Lab%"),
              options = list(dom = "t", pageLength = 20), rownames = FALSE) %>%
      formatStyle("ort_bal",
                  background = styleColorBar(c(0, 100), "#00a65a"),
                  backgroundSize = "90% 70%", backgroundRepeat = "no-repeat", backgroundPosition = "left")
  })

  output$region_bal_chart <- renderPlotly({
    df <- region_stat %>% arrange(desc(ort_bal))
    plot_ly(df, x = ~reorder(region, ort_bal), y = ~ort_bal, type = "bar",
            marker = list(color = "#3c8dbc"), text = ~ort_bal, textposition = "outside") %>%
      layout(xaxis = list(title = ""), yaxis = list(title = "Orta Bal"), margin = list(b = 80))
  })

  output$region_infra_chart <- renderPlotly({
    df <- region_stat %>% arrange(desc(komp_lab_faiz))
    plot_ly(df, x = ~reorder(region, komp_lab_faiz), y = ~komp_lab_faiz, type = "bar",
            marker = list(color = "#00a65a"), text = ~paste0(komp_lab_faiz, "%"), textposition = "outside") %>%
      layout(xaxis = list(title = ""), yaxis = list(title = "Komp. Lab %", range = c(0, 100)),
             margin = list(b = 80))
  })

  output$komp_bar <- renderPlotly({
    df <- filt() %>% count(komp_lab)
    plot_ly(df, x = ~komp_lab, y = ~n, type = "bar",
            marker = list(color = c("#00a65a", "#dd4b39")),
            text = ~n, textposition = "outside") %>%
      layout(xaxis = list(title = ""), yaxis = list(title = "Məktəb Sayı"))
  })

  output$internet_bar <- renderPlotly({
    df <- filt() %>% count(internet) %>% arrange(desc(n))
    plot_ly(df, x = ~reorder(internet, n), y = ~n, type = "bar",
            marker = list(color = c("#00a65a", "#f39c12", "#dd4b39", "#999999")),
            text = ~n, textposition = "outside") %>%
      layout(xaxis = list(title = ""), yaxis = list(title = "Məktəb Sayı"), margin = list(b = 60))
  })

  output$ehat_bar <- renderPlotly({
    data <- data.frame(
      test = c("CAT keçirilən", "CAT keçirilməyən", "MST keçirilən", "MST keçirilməyən"),
      say = c(sum(mektebler$cat_test == "Bəli"), sum(mektebler$cat_test == "Xeyr"),
              sum(mektebler$mst_test == "Bəli"), sum(mektebler$mst_test == "Xeyr"))
    )
    plot_ly(data, x = ~test, y = ~say, type = "bar",
            marker = list(color = c("#3c8dbc", "#ccc", "#00a65a", "#ccc")),
            text = ~say, textposition = "outside") %>%
      layout(xaxis = list(title = ""), yaxis = list(title = "Məktəb Sayı"))
  })

  output$ehat_tip <- renderPlotly({
    df <- mektebler %>% group_by(tip) %>%
      summarise(cat = round(mean(cat_test == "Bəli") * 100, 1),
                mst = round(mean(mst_test == "Bəli") * 100, 1), .groups = "drop")
    plot_ly(df, x = ~tip) %>%
      add_trace(y = ~cat, name = "CAT", type = "bar", marker = list(color = "#3c8dbc")) %>%
      add_trace(y = ~mst, name = "MST", type = "bar", marker = list(color = "#00a65a")) %>%
      layout(barmode = "group", xaxis = list(title = ""), yaxis = list(title = "Əhatə (%)"))
  })

  output$tip_compare_bal <- renderPlotly({
    df <- filt()
    plot_ly(df, x = ~tip, y = ~ort_bal, color = ~tip, type = "violin",
            box = list(visible = TRUE), meanline = list(visible = TRUE)) %>%
      layout(xaxis = list(title = ""), yaxis = list(title = "Orta Bal"), showlegend = FALSE)
  })

  output$tip_compare_theta <- renderPlotly({
    df <- filt()
    plot_ly(df, x = ~tip, y = ~ort_theta, color = ~tip, type = "violin",
            box = list(visible = TRUE), meanline = list(visible = TRUE)) %>%
      layout(xaxis = list(title = ""), yaxis = list(title = "Orta Theta"), showlegend = FALSE)
  })
}

shinyApp(ui = ui, server = server)
