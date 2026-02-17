# ============================================================
# ARTI 2026 - SERTİFİKASİYA VƏ İŞƏ QƏBUL PANELİ
# Müəllim imtahanları, sertifikasiya, sual bazası
# ============================================================

library(shiny)
library(shinydashboard)
library(plotly)
library(DT)
library(dplyr)
library(tidyr)

# ===== NÜMUNƏ MƏLUMATLAR =====

set.seed(2026)
n_candidates <- 300

fenler_list <- c("Riyaziyyat", "Fizika", "Kimya", "Biologiya", "İnformatika",
                 "Azərb. dili", "Tarix", "Coğrafiya", "İngilis dili")

# Namizəd məlumatları
namizedler <- data.frame(
  namized_id = paste0("NAM_", sprintf("%04d", 1:n_candidates)),
  ad_soyad = paste(
    sample(c("Əliyev", "Həsənov", "Məmmədov", "Quliyev", "Hüseynov",
             "Babayev", "Rəhimov", "İsmayılov", "Kərimov", "Novruzov",
             "Əliyeva", "Həsənova", "Məmmədova", "Quliyeva"), n_candidates, replace = TRUE),
    sample(c("Kamran", "Aynur", "Fərid", "Günel", "Rəşad", "Sevinc",
             "Tural", "Leyla", "Orxan", "Nigar", "Səbinə", "Elvin"), n_candidates, replace = TRUE)
  ),
  fen = sample(fenler_list, n_candidates, replace = TRUE),
  imtahan_tipi = sample(c("İşə Qəbul", "Sertifikasiya"), n_candidates, replace = TRUE, prob = c(0.55, 0.45)),
  tecrube_il = sample(0:25, n_candidates, replace = TRUE),
  kvalifikasiya = sample(c("Bakalavr", "Magistr", "Doktor"), n_candidates, replace = TRUE, prob = c(0.5, 0.4, 0.1)),
  bal = round(runif(n_candidates, 15, 98), 1),
  kechid_bali = 50,
  s1_bal = round(runif(n_candidates, 20, 100), 1),  # Mərhələ 1
  s2_bal = round(runif(n_candidates, 15, 95), 1),   # Mərhələ 2
  s3_bal = round(runif(n_candidates, 10, 90), 1),    # Mərhələ 3
  tarix = format(as.Date("2026-01-01") + sample(0:180, n_candidates, replace = TRUE), "%d.%m.%Y"),
  region = sample(c("Bakı", "Gəncə", "Sumqayıt", "Mingəçevir", "Şəki",
                     "Lənkəran", "Naxçıvan", "Şirvan"), n_candidates, replace = TRUE),
  stringsAsFactors = FALSE
)

namizedler$netice <- ifelse(namizedler$bal >= namizedler$kechid_bali, "Keçdi", "Keçmədi")
namizedler$yekun_bal <- round((namizedler$s1_bal * 0.3 + namizedler$s2_bal * 0.4 + namizedler$s3_bal * 0.3), 1)

# Sual bazası statistikası
sual_bazasi <- data.frame(
  fen = fenler_list,
  asan = sample(100:300, 9),
  orta = sample(200:500, 9),
  chetin = sample(50:200, 9),
  stringsAsFactors = FALSE
)

sual_bazasi$umumi <- sual_bazasi$asan + sual_bazasi$orta + sual_bazasi$chetin


# ===== UI =====

ui <- dashboardPage(
  skin = "purple",
  dashboardHeader(title = "ARTI - Sertifikasiya", titleWidth = 300),

  dashboardSidebar(
    width = 300,
    sidebarMenu(
      menuItem("Ümumi Baxış", tabName = "umumi", icon = icon("tachometer-alt")),
      menuItem("İşə Qəbul İmtahanları", tabName = "ishe_qebul", icon = icon("user-plus")),
      menuItem("Sertifikasiya", tabName = "sertifikasiya", icon = icon("certificate")),
      menuItem("Sual Bazası", tabName = "sual_bazasi", icon = icon("database")),
      menuItem("Nəticə Analizi", tabName = "analiz", icon = icon("chart-bar")),
      menuItem("Namizəd Axtarışı", tabName = "axtarish", icon = icon("search")),
      hr(),
      selectInput("fen_sec", "Fən:", c("Hamısı", fenler_list)),
      selectInput("tip_sec", "İmtahan Tipi:", c("Hamısı", "İşə Qəbul", "Sertifikasiya")),
      selectInput("region_sec", "Region:", c("Hamısı", "Bakı", "Gəncə", "Sumqayıt",
                                             "Mingəçevir", "Şəki", "Lənkəran", "Naxçıvan", "Şirvan"))
    )
  ),

  dashboardBody(
    tags$head(tags$style(HTML("
      .content-wrapper { background-color: #f4f6f9; }
      .info-box-number { font-size: 22px; }
      .box-header { border-bottom: 2px solid #605ca8; }
    "))),

    tabItems(
      # ===== ÜMUMİ =====
      tabItem(tabName = "umumi",
        h3("Sertifikasiya və İşə Qəbul - Ümumi Baxış", style = "margin-top: 0;"),
        fluidRow(
          valueBox(n_candidates, "Ümumi Namizəd", icon = icon("users"), color = "purple", width = 3),
          valueBox(sum(namizedler$netice == "Keçdi"), "Keçən", icon = icon("check"), color = "green", width = 3),
          valueBox(paste0(round(mean(namizedler$netice == "Keçdi") * 100, 1), "%"),
                   "Keçid Faizi", icon = icon("percent"), color = "yellow", width = 3),
          valueBox(format(sum(sual_bazasi$umumi), big.mark = " "),
                   "Sual Bazası", icon = icon("database"), color = "blue", width = 3)
        ),
        fluidRow(
          box(title = "Bal Paylanması", status = "primary", solidHeader = TRUE, width = 8, height = 420,
              plotlyOutput("bal_hist", height = "360px")),
          box(title = "Keçid Nəticəsi", status = "success", solidHeader = TRUE, width = 4, height = 420,
              plotlyOutput("kechid_pie", height = "170px"),
              hr(),
              plotlyOutput("tip_pie", height = "170px"))
        ),
        fluidRow(
          box(title = "Fənlər üzrə Orta Bal", status = "info", solidHeader = TRUE, width = 6,
              plotlyOutput("fen_bal_bar", height = "350px")),
          box(title = "Regionlar üzrə Keçid Faizi", status = "warning", solidHeader = TRUE, width = 6,
              plotlyOutput("region_kechid", height = "350px"))
        )
      ),

      # ===== İŞƏ QƏBUL =====
      tabItem(tabName = "ishe_qebul",
        h3("Müəllim İşə Qəbul İmtahanları"),
        fluidRow(
          box(title = "İşə Qəbul Nəticələri", status = "primary", solidHeader = TRUE, width = 12,
              DT::dataTableOutput("iq_table"))
        ),
        fluidRow(
          box(title = "Təcrübə vs Bal", status = "info", solidHeader = TRUE, width = 6,
              plotlyOutput("tecrube_bal", height = "300px")),
          box(title = "Kvalifikasiya üzrə Nəticə", status = "success", solidHeader = TRUE, width = 6,
              plotlyOutput("kvalifikasiya_bar", height = "300px"))
        )
      ),

      # ===== SERTİFİKASİYA =====
      tabItem(tabName = "sertifikasiya",
        h3("Müəllim Sertifikasiya İmtahanları"),
        fluidRow(
          box(title = "Sertifikasiya Nəticələri", status = "primary", solidHeader = TRUE, width = 12,
              DT::dataTableOutput("sert_table"))
        ),
        fluidRow(
          box(title = "Mərhələlər üzrə Bal Paylanması", status = "info", solidHeader = TRUE, width = 12,
              plotlyOutput("merhele_boxplot", height = "350px"))
        )
      ),

      # ===== SUAL BAZASI =====
      tabItem(tabName = "sual_bazasi",
        h3("Sual Bazası İdarəetməsi"),
        fluidRow(
          infoBox("Ümumi Sual", format(sum(sual_bazasi$umumi), big.mark = " "),
                  icon = icon("question-circle"), color = "purple", width = 3),
          infoBox("Asan", format(sum(sual_bazasi$asan), big.mark = " "),
                  icon = icon("smile"), color = "green", width = 3),
          infoBox("Orta", format(sum(sual_bazasi$orta), big.mark = " "),
                  icon = icon("meh"), color = "yellow", width = 3),
          infoBox("Çətin", format(sum(sual_bazasi$chetin), big.mark = " "),
                  icon = icon("frown"), color = "red", width = 3)
        ),
        fluidRow(
          box(title = "Fənlər üzrə Sual Sayı", status = "primary", solidHeader = TRUE, width = 8,
              plotlyOutput("sual_stacked", height = "400px")),
          box(title = "Çətinlik Paylanması", status = "info", solidHeader = TRUE, width = 4,
              plotlyOutput("cetinlik_pie", height = "400px"))
        ),
        fluidRow(
          box(title = "Sual Bazası Cədvəli", status = "success", solidHeader = TRUE, width = 12,
              DT::dataTableOutput("sual_table"))
        )
      ),

      # ===== ANALİZ =====
      tabItem(tabName = "analiz",
        h3("Ətraflı Nəticə Analizi"),
        fluidRow(
          box(title = "Kvalifikasiya × Fən Heatmap", status = "primary", solidHeader = TRUE, width = 12,
              plotlyOutput("heatmap", height = "400px"))
        )
      ),

      # ===== AXTARIŞ =====
      tabItem(tabName = "axtarish",
        h3("Namizəd Axtarışı"),
        fluidRow(
          box(width = 12, status = "primary", solidHeader = TRUE, title = "Axtarış",
              fluidRow(
                column(6, textInput("search_nam", "Namizəd ID və ya Ad:", placeholder = "NAM_0001")),
                column(3, actionButton("search_btn2", "Axtar", class = "btn-primary", style = "margin-top: 25px;"))
              ))
        ),
        fluidRow(
          box(title = "Tapılan Nəticələr", status = "info", solidHeader = TRUE, width = 12,
              DT::dataTableOutput("search_table2"))
        )
      )
    )
  )
)


# ===== SERVER =====

server <- function(input, output, session) {

  filt <- reactive({
    df <- namizedler
    if (input$fen_sec != "Hamısı") df <- df %>% filter(fen == input$fen_sec)
    if (input$tip_sec != "Hamısı") df <- df %>% filter(imtahan_tipi == input$tip_sec)
    if (input$region_sec != "Hamısı") df <- df %>% filter(region == input$region_sec)
    df
  })

  # Ümumi
  output$bal_hist <- renderPlotly({
    df <- filt()
    plot_ly() %>%
      add_histogram(data = df %>% filter(netice == "Keçdi"), x = ~bal, name = "Keçdi",
                    marker = list(color = "#00a65a", opacity = 0.7)) %>%
      add_histogram(data = df %>% filter(netice == "Keçmədi"), x = ~bal, name = "Keçmədi",
                    marker = list(color = "#dd4b39", opacity = 0.7)) %>%
      add_segments(x = 50, xend = 50, y = 0, yend = 30,
                   line = list(color = "black", width = 2, dash = "dash"), name = "Keçid Balı") %>%
      layout(barmode = "overlay",
             xaxis = list(title = "Bal"), yaxis = list(title = "Namizəd Sayı"))
  })

  output$kechid_pie <- renderPlotly({
    df <- filt() %>% count(netice)
    plot_ly(df, labels = ~netice, values = ~n, type = "pie",
            marker = list(colors = c("#dd4b39", "#00a65a")), hole = 0.5,
            textinfo = "label+percent") %>%
      layout(showlegend = FALSE, margin = list(l = 5, r = 5, t = 5, b = 5))
  })

  output$tip_pie <- renderPlotly({
    df <- filt() %>% count(imtahan_tipi)
    plot_ly(df, labels = ~imtahan_tipi, values = ~n, type = "pie",
            marker = list(colors = c("#605ca8", "#3c8dbc")), hole = 0.5,
            textinfo = "label+percent") %>%
      layout(showlegend = FALSE, margin = list(l = 5, r = 5, t = 5, b = 5))
  })

  output$fen_bal_bar <- renderPlotly({
    df <- filt() %>% group_by(fen) %>%
      summarise(ort = round(mean(bal), 1), .groups = "drop") %>% arrange(desc(ort))
    colors <- ifelse(df$ort >= 60, "#00a65a", ifelse(df$ort >= 45, "#f39c12", "#dd4b39"))
    plot_ly(df, x = ~reorder(fen, ort), y = ~ort, type = "bar",
            marker = list(color = colors),
            text = ~ort, textposition = "outside") %>%
      layout(xaxis = list(title = ""), yaxis = list(title = "Orta Bal", range = c(0, max(df$ort) * 1.15)),
             margin = list(b = 80))
  })

  output$region_kechid <- renderPlotly({
    df <- filt() %>% group_by(region) %>%
      summarise(kechid = round(mean(netice == "Keçdi") * 100, 1), .groups = "drop") %>%
      arrange(desc(kechid))
    plot_ly(df, x = ~reorder(region, kechid), y = ~kechid, type = "bar",
            marker = list(color = "#605ca8"),
            text = ~paste0(kechid, "%"), textposition = "outside") %>%
      layout(xaxis = list(title = ""), yaxis = list(title = "Keçid %", range = c(0, 100)),
             margin = list(b = 80))
  })

  # İşə Qəbul
  output$iq_table <- DT::renderDataTable({
    df <- filt() %>% filter(imtahan_tipi == "İşə Qəbul") %>%
      select(namized_id, ad_soyad, fen, region, tecrube_il, kvalifikasiya, bal, netice, tarix)
    datatable(df, colnames = c("ID", "Ad Soyad", "Fən", "Region", "Təcrübə", "Kvalif.", "Bal", "Nəticə", "Tarix"),
              options = list(pageLength = 12, scrollX = TRUE), rownames = FALSE, filter = "top") %>%
      formatStyle("netice", backgroundColor = styleEqual(c("Keçdi", "Keçmədi"), c("#d4edda", "#f8d7da")),
                  fontWeight = "bold")
  })

  output$tecrube_bal <- renderPlotly({
    df <- filt() %>% filter(imtahan_tipi == "İşə Qəbul")
    plot_ly(df, x = ~tecrube_il, y = ~bal, color = ~netice,
            colors = c("Keçdi" = "#00a65a", "Keçmədi" = "#dd4b39"),
            type = "scatter", mode = "markers", marker = list(size = 6, opacity = 0.6)) %>%
      layout(xaxis = list(title = "Təcrübə (il)"), yaxis = list(title = "Bal"))
  })

  output$kvalifikasiya_bar <- renderPlotly({
    df <- filt() %>% group_by(kvalifikasiya) %>%
      summarise(ort = round(mean(bal), 1), kechid = round(mean(netice == "Keçdi") * 100, 1), .groups = "drop")
    plot_ly(df, x = ~kvalifikasiya) %>%
      add_trace(y = ~ort, name = "Orta Bal", type = "bar", marker = list(color = "#3c8dbc")) %>%
      add_trace(y = ~kechid, name = "Keçid %", type = "bar", marker = list(color = "#00a65a")) %>%
      layout(barmode = "group", xaxis = list(title = ""), yaxis = list(title = ""))
  })

  # Sertifikasiya
  output$sert_table <- DT::renderDataTable({
    df <- filt() %>% filter(imtahan_tipi == "Sertifikasiya") %>%
      select(namized_id, ad_soyad, fen, region, tecrube_il, s1_bal, s2_bal, s3_bal, yekun_bal, netice)
    datatable(df, colnames = c("ID", "Ad Soyad", "Fən", "Region", "Təcrübə",
                               "Mərhələ 1", "Mərhələ 2", "Mərhələ 3", "Yekun", "Nəticə"),
              options = list(pageLength = 12, scrollX = TRUE), rownames = FALSE, filter = "top") %>%
      formatRound(c("s1_bal", "s2_bal", "s3_bal", "yekun_bal"), 1) %>%
      formatStyle("netice", backgroundColor = styleEqual(c("Keçdi", "Keçmədi"), c("#d4edda", "#f8d7da")))
  })

  output$merhele_boxplot <- renderPlotly({
    df <- filt() %>% filter(imtahan_tipi == "Sertifikasiya") %>%
      select(namized_id, s1_bal, s2_bal, s3_bal) %>%
      pivot_longer(-namized_id, names_to = "merhele", values_to = "bal") %>%
      mutate(merhele = recode(merhele, s1_bal = "Mərhələ 1\n(İbtidai)", s2_bal = "Mərhələ 2\n(Fən Biliyəri)",
                              s3_bal = "Mərhələ 3\n(Pedaqogika)"))
    plot_ly(df, x = ~merhele, y = ~bal, color = ~merhele, type = "violin",
            box = list(visible = TRUE), meanline = list(visible = TRUE)) %>%
      layout(xaxis = list(title = ""), yaxis = list(title = "Bal"), showlegend = FALSE)
  })

  # Sual Bazası
  output$sual_stacked <- renderPlotly({
    df <- sual_bazasi %>% arrange(desc(umumi))
    plot_ly(df, x = ~reorder(fen, umumi)) %>%
      add_trace(y = ~asan, name = "Asan", type = "bar", marker = list(color = "#00a65a")) %>%
      add_trace(y = ~orta, name = "Orta", type = "bar", marker = list(color = "#f39c12")) %>%
      add_trace(y = ~chetin, name = "Çətin", type = "bar", marker = list(color = "#dd4b39")) %>%
      layout(barmode = "stack", xaxis = list(title = ""), yaxis = list(title = "Sual Sayı"),
             legend = list(orientation = "h", y = -0.15), margin = list(b = 80))
  })

  output$cetinlik_pie <- renderPlotly({
    data <- data.frame(
      cetinlik = c("Asan", "Orta", "Çətin"),
      say = c(sum(sual_bazasi$asan), sum(sual_bazasi$orta), sum(sual_bazasi$chetin))
    )
    plot_ly(data, labels = ~cetinlik, values = ~say, type = "pie",
            marker = list(colors = c("#00a65a", "#f39c12", "#dd4b39")), hole = 0.45,
            textinfo = "label+percent") %>%
      layout(showlegend = FALSE, margin = list(l = 10, r = 10, t = 30, b = 10))
  })

  output$sual_table <- DT::renderDataTable({
    datatable(sual_bazasi, colnames = c("Fən", "Asan", "Orta", "Çətin", "Ümumi"),
              options = list(dom = "t", pageLength = 10), rownames = FALSE) %>%
      formatStyle("umumi", fontWeight = "bold",
                  background = styleColorBar(c(0, max(sual_bazasi$umumi)), "#605ca8"),
                  backgroundSize = "90% 70%", backgroundRepeat = "no-repeat", backgroundPosition = "left")
  })

  # Analiz - Heatmap
  output$heatmap <- renderPlotly({
    df <- filt() %>% group_by(kvalifikasiya, fen) %>%
      summarise(ort = round(mean(bal), 1), .groups = "drop") %>%
      pivot_wider(names_from = fen, values_from = ort, values_fill = 0)
    mat <- as.matrix(df[, -1])
    rownames(mat) <- df$kvalifikasiya
    plot_ly(z = mat, x = colnames(mat), y = rownames(mat), type = "heatmap",
            colorscale = "Viridis", text = mat, texttemplate = "%{text}") %>%
      layout(xaxis = list(title = ""), yaxis = list(title = ""))
  })

  # Axtarış
  output$search_table2 <- DT::renderDataTable({
    req(input$search_btn2)
    isolate({
      q <- input$search_nam
      if (nchar(q) < 2) return(NULL)
      df <- namizedler %>% filter(grepl(q, namized_id, ignore.case = TRUE) |
                                  grepl(q, ad_soyad, ignore.case = TRUE))
      datatable(df, options = list(pageLength = 10, scrollX = TRUE), rownames = FALSE)
    })
  })
}

shinyApp(ui = ui, server = server)
