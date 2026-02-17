
# ============================================================
# ARTI 2026 - QİYMƏTLƏNDİRMƏ PANELİ (CAT / MST)
# Kompüter Adaptiv Test və Çoxsəviyyəli Test Dashboard
# ============================================================

library(shiny)
library(shinydashboard)
library(plotly)
library(DT)
library(dplyr)

# ===== NÜMUNƏ MƏLUMATLAR =====

set.seed(2026)
n_students <- 500

# CAT nəticələri
cat_results <- data.frame(
  shagird_id = paste0("STU_", sprintf("%04d", 1:n_students)),
  ad_soyad = paste(
    sample(c("Əliyev", "Həsənov", "Məmmədov", "Quliyev", "Hüseynov",
             "Babayev", "Rəhimov", "İsmayılov", "Kərimov", "Novruzov"), n_students, replace = TRUE),
    sample(c("Kamran", "Aynur", "Fərid", "Günel", "Rəşad", "Sevinc",
             "Tural", "Leyla", "Orxan", "Nigar"), n_students, replace = TRUE)
  ),
  mekteb = paste0(
    sample(c("Bakı", "Gəncə", "Sumqayıt"), n_students, replace = TRUE),
    " ", sample(c("Lisey", "Gimnaziya", "Məktəb"), n_students, replace = TRUE),
    " #", sample(1:20, n_students, replace = TRUE)
  ),
  sinif = sample(7:11, n_students, replace = TRUE),
  fen = sample(c("Riyaziyyat", "Fizika", "Kimya", "Biologiya", "İnformatika"),
               n_students, replace = TRUE),
  theta = round(rnorm(n_students, 0.3, 1.1), 3),
  se = round(runif(n_students, 0.2, 0.5), 3),
  sual_sayi = sample(10:35, n_students, replace = TRUE),
  duzgun = sample(5:30, n_students, replace = TRUE),
  faiz = round(runif(n_students, 20, 95), 1),
  muddet_deq = sample(15:55, n_students, replace = TRUE),
  test_tipi = sample(c("CAT", "MST"), n_students, replace = TRUE, prob = c(0.6, 0.4)),
  tarix = format(Sys.Date() - sample(0:90, n_students, replace = TRUE), "%d.%m.%Y"),
  stringsAsFactors = FALSE
)

cat_results$seviyye <- cut(cat_results$theta,
                           breaks = c(-Inf, -1.5, -0.5, 0.5, 1.5, Inf),
                           labels = c("Çox zəif", "Zəif", "Orta", "Yaxşı", "Əla"))

# IRT parametrləri - sual bazası nümunəsi
irt_items <- data.frame(
  sual_id = paste0("ITEM_", sprintf("%04d", 1:200)),
  fen = sample(c("Riyaziyyat", "Fizika", "Kimya", "Biologiya", "İnformatika"),
               200, replace = TRUE),
  movzu = sample(c("Cəbr", "Həndəsə", "Mexanika", "Optika", "Kimyəvi rabitə",
                    "Hüceyrə", "Alqoritm", "Statistika", "Elektrik", "Genetika"),
                 200, replace = TRUE),
  a = round(runif(200, 0.3, 2.8), 2),
  b = round(rnorm(200, 0, 1.5), 2),
  c = round(runif(200, 0.05, 0.30), 2),
  istifade = sample(10:500, 200, replace = TRUE),
  uygunluq = sample(c("Yaxşı", "Orta", "Zəif"), 200, replace = TRUE, prob = c(0.7, 0.2, 0.1)),
  stringsAsFactors = FALSE
)


# ===== UI =====

ui <- dashboardPage(
  skin = "green",
  dashboardHeader(title = "ARTI - Qiymətləndirmə", titleWidth = 300),

  dashboardSidebar(
    width = 300,
    sidebarMenu(
      menuItem("Ümumi Baxış", tabName = "umumi", icon = icon("tachometer-alt")),
      menuItem("CAT Nəticələri", tabName = "cat", icon = icon("laptop")),
      menuItem("MST Nəticələri", tabName = "mst", icon = icon("layer-group")),
      menuItem("Theta Analizi", tabName = "theta", icon = icon("chart-line")),
      menuItem("IRT / Sual Analizi", tabName = "irt", icon = icon("microscope")),
      menuItem("Məktəb Müqayisəsi", tabName = "muqayise", icon = icon("balance-scale")),
      menuItem("Şagird Axtarışı", tabName = "axtarish", icon = icon("search")),
      hr(),
      selectInput("fen_filter", "Fən seçin:",
                  c("Hamısı", "Riyaziyyat", "Fizika", "Kimya", "Biologiya", "İnformatika")),
      selectInput("sinif_filter", "Sinif seçin:",
                  c("Hamısı", 7, 8, 9, 10, 11))
    )
  ),

  dashboardBody(
    tags$head(tags$style(HTML("
      .content-wrapper { background-color: #ecf0f5; }
      .small-box:hover { opacity: 0.95; transform: scale(1.01); transition: 0.2s; }
      .info-box-number { font-size: 24px; }
    "))),

    tabItems(
      # ===== ÜMUMİ BAXIŞ =====
      tabItem(tabName = "umumi",
        h3("Qiymətləndirmə Sistemi - Ümumi Baxış", style = "margin-top: 0;"),
        fluidRow(
          valueBox(nrow(cat_results %>% filter(test_tipi == "CAT")),
                   "CAT Test", icon = icon("laptop"), color = "blue", width = 3),
          valueBox(nrow(cat_results %>% filter(test_tipi == "MST")),
                   "MST Test", icon = icon("layer-group"), color = "green", width = 3),
          valueBox(paste0(round(mean(cat_results$faiz), 1), "%"),
                   "Orta Bal", icon = icon("percent"), color = "yellow", width = 3),
          valueBox(paste0("+", round(mean(cat_results$theta), 2)),
                   "Orta Theta", icon = icon("chart-line"), color = "red", width = 3)
        ),
        fluidRow(
          box(title = "Theta Paylanması (Bütün Şagirdlər)", status = "primary",
              solidHeader = TRUE, width = 8, height = 430,
              plotlyOutput("theta_hist", height = "370px")),
          box(title = "Performans Səviyyələri", status = "success",
              solidHeader = TRUE, width = 4, height = 430,
              plotlyOutput("seviyye_pie", height = "370px"))
        ),
        fluidRow(
          box(title = "Fənlər üzrə Theta Paylanması", status = "info",
              solidHeader = TRUE, width = 12, height = 420,
              plotlyOutput("fen_violin", height = "360px"))
        )
      ),

      # ===== CAT NƏTİCƏLƏRİ =====
      tabItem(tabName = "cat",
        h3("CAT (Kompüter Adaptiv Test) Nəticələri"),
        fluidRow(
          box(title = "CAT Nəticə Cədvəli", status = "primary",
              solidHeader = TRUE, width = 12,
              DT::dataTableOutput("cat_table"))
        ),
        fluidRow(
          box(title = "Theta vs Sual Sayı", status = "info",
              solidHeader = TRUE, width = 6,
              plotlyOutput("cat_theta_items", height = "300px")),
          box(title = "Dəqiqlik (%) Paylanması", status = "success",
              solidHeader = TRUE, width = 6,
              plotlyOutput("cat_accuracy_hist", height = "300px"))
        )
      ),

      # ===== MST NƏTİCƏLƏRİ =====
      tabItem(tabName = "mst",
        h3("MST (Çoxsəviyyəli Test) Nəticələri"),
        fluidRow(
          box(title = "MST Nəticə Cədvəli", status = "primary",
              solidHeader = TRUE, width = 12,
              DT::dataTableOutput("mst_table"))
        ),
        fluidRow(
          box(title = "MST Performans", status = "warning",
              solidHeader = TRUE, width = 12,
              plotlyOutput("mst_performance", height = "350px"))
        )
      ),

      # ===== THETA ANALİZİ =====
      tabItem(tabName = "theta",
        h3("Theta (Qabiliyyət) Ətraflı Analizi"),
        fluidRow(
          box(title = "Theta vs Standart Xəta", status = "primary",
              solidHeader = TRUE, width = 6,
              plotlyOutput("theta_se_scatter", height = "350px")),
          box(title = "Sinif üzrə Theta", status = "success",
              solidHeader = TRUE, width = 6,
              plotlyOutput("theta_by_class", height = "350px"))
        ),
        fluidRow(
          box(title = "Fən üzrə Theta Box Plot", status = "info",
              solidHeader = TRUE, width = 12,
              plotlyOutput("theta_boxplot", height = "350px"))
        )
      ),

      # ===== IRT ANALİZİ =====
      tabItem(tabName = "irt",
        h3("IRT Sual Analizi"),
        fluidRow(
          infoBox("Ümumi Sual", nrow(irt_items), icon = icon("question"), color = "blue", width = 3),
          infoBox("Orta a", round(mean(irt_items$a), 2), icon = icon("arrows-alt-v"),
                  color = "green", width = 3, subtitle = "Ayırd etmə"),
          infoBox("Orta b", round(mean(irt_items$b), 2), icon = icon("bullseye"),
                  color = "yellow", width = 3, subtitle = "Çətinlik"),
          infoBox("Yaxşı Fit", paste0(round(mean(irt_items$uygunluq == "Yaxşı") * 100), "%"),
                  icon = icon("check"), color = "red", width = 3)
        ),
        fluidRow(
          box(title = "Sual Parametrləri (a vs b)", status = "primary",
              solidHeader = TRUE, width = 8,
              plotlyOutput("irt_scatter", height = "400px")),
          box(title = "Çətinlik Paylanması", status = "info",
              solidHeader = TRUE, width = 4,
              plotlyOutput("irt_b_hist", height = "400px"))
        ),
        fluidRow(
          box(title = "Sual Bazası Cədvəli", status = "success",
              solidHeader = TRUE, width = 12,
              DT::dataTableOutput("irt_table"))
        )
      ),

      # ===== MƏKTƏB MÜQAYİSƏSİ =====
      tabItem(tabName = "muqayise",
        h3("Məktəblər arası Müqayisə"),
        fluidRow(
          box(title = "Məktəblər üzrə Orta Theta", status = "primary",
              solidHeader = TRUE, width = 12,
              plotlyOutput("school_compare", height = "400px"))
        )
      ),

      # ===== ŞAGİRD AXTARIŞI =====
      tabItem(tabName = "axtarish",
        h3("Şagird Axtarışı"),
        fluidRow(
          box(width = 12, status = "primary", solidHeader = TRUE,
              title = "Axtarış",
              textInput("search_id", "Şagird ID və ya Ad:", placeholder = "STU_0001 və ya Ad Soyad"),
              actionButton("search_btn", "Axtar", class = "btn-primary"))
        ),
        fluidRow(
          box(title = "Nəticələr", status = "info",
              solidHeader = TRUE, width = 12,
              DT::dataTableOutput("search_results"))
        )
      )
    )
  )
)


# ===== SERVER =====

server <- function(input, output, session) {

  # Filtrlənmiş data
  filtered_data <- reactive({
    df <- cat_results
    if (input$fen_filter != "Hamısı") df <- df %>% filter(fen == input$fen_filter)
    if (input$sinif_filter != "Hamısı") df <- df %>% filter(sinif == as.integer(input$sinif_filter))
    df
  })

  # --- Ümumi Baxış ---

  output$theta_hist <- renderPlotly({
    df <- filtered_data()
    plot_ly(df, x = ~theta, type = "histogram",
            marker = list(color = "#3c8dbc", line = list(color = "white", width = 0.5)),
            nbinsx = 40) %>%
      add_trace(x = seq(-4, 4, 0.1),
                y = dnorm(seq(-4, 4, 0.1), mean(df$theta), sd(df$theta)) * nrow(df) * 0.2,
                type = "scatter", mode = "lines",
                line = list(color = "#dd4b39", width = 3, dash = "dash"),
                name = "Normal əyri") %>%
      layout(xaxis = list(title = "Theta (Qabiliyyət)"),
             yaxis = list(title = "Şagird Sayı"),
             showlegend = TRUE,
             legend = list(x = 0.8, y = 0.9))
  })

  output$seviyye_pie <- renderPlotly({
    df <- filtered_data() %>% count(seviyye)
    colors <- c("Çox zəif" = "#dd4b39", "Zəif" = "#f39c12",
                "Orta" = "#3c8dbc", "Yaxşı" = "#00a65a", "Əla" = "#00c0ef")
    plot_ly(df, labels = ~seviyye, values = ~n, type = "pie",
            textinfo = "label+percent",
            marker = list(colors = colors[as.character(df$seviyye)]),
            hole = 0.45) %>%
      layout(showlegend = FALSE, margin = list(l = 5, r = 5, t = 30, b = 5))
  })

  output$fen_violin <- renderPlotly({
    df <- filtered_data()
    plot_ly(df, y = ~theta, x = ~fen, color = ~fen, type = "violin",
            box = list(visible = TRUE),
            meanline = list(visible = TRUE)) %>%
      layout(xaxis = list(title = ""),
             yaxis = list(title = "Theta"),
             showlegend = FALSE)
  })

  # --- CAT ---

  output$cat_table <- DT::renderDataTable({
    df <- filtered_data() %>% filter(test_tipi == "CAT") %>%
      select(shagird_id, ad_soyad, mekteb, sinif, fen, theta, se, sual_sayi, faiz, seviyye, tarix)
    datatable(df,
              colnames = c("ID", "Ad Soyad", "Məktəb", "Sinif", "Fən",
                           "Theta", "SE", "Sual", "Faiz%", "Səviyyə", "Tarix"),
              options = list(pageLength = 15, scrollX = TRUE),
              rownames = FALSE, filter = "top") %>%
      formatRound(c("theta", "se"), 3) %>%
      formatStyle("seviyye",
                  backgroundColor = styleEqual(
                    c("Əla", "Yaxşı", "Orta", "Zəif", "Çox zəif"),
                    c("#c3e6cb", "#d4edda", "#cce5ff", "#fff3cd", "#f8d7da")))
  })

  output$cat_theta_items <- renderPlotly({
    df <- filtered_data() %>% filter(test_tipi == "CAT")
    plot_ly(df, x = ~sual_sayi, y = ~theta, color = ~fen,
            type = "scatter", mode = "markers",
            marker = list(size = 6, opacity = 0.6),
            text = ~paste0(ad_soyad, "\nSual: ", sual_sayi, "\nTheta: ", theta)) %>%
      layout(xaxis = list(title = "Verilmiş Sual Sayı"),
             yaxis = list(title = "Theta"))
  })

  output$cat_accuracy_hist <- renderPlotly({
    df <- filtered_data() %>% filter(test_tipi == "CAT")
    plot_ly(df, x = ~faiz, type = "histogram",
            marker = list(color = "#00a65a", line = list(color = "white", width = 0.5)),
            nbinsx = 20) %>%
      layout(xaxis = list(title = "Dəqiqlik (%)"),
             yaxis = list(title = "Şagird Sayı"))
  })

  # --- MST ---

  output$mst_table <- DT::renderDataTable({
    df <- filtered_data() %>% filter(test_tipi == "MST") %>%
      select(shagird_id, ad_soyad, mekteb, sinif, fen, theta, faiz, seviyye, tarix)
    datatable(df,
              colnames = c("ID", "Ad Soyad", "Məktəb", "Sinif", "Fən",
                           "Theta", "Faiz%", "Səviyyə", "Tarix"),
              options = list(pageLength = 15, scrollX = TRUE),
              rownames = FALSE, filter = "top") %>%
      formatRound("theta", 3) %>%
      formatStyle("seviyye",
                  backgroundColor = styleEqual(
                    c("Əla", "Yaxşı", "Orta", "Zəif", "Çox zəif"),
                    c("#c3e6cb", "#d4edda", "#cce5ff", "#fff3cd", "#f8d7da")))
  })

  output$mst_performance <- renderPlotly({
    df <- filtered_data() %>% filter(test_tipi == "MST")
    plot_ly(df, x = ~fen, y = ~theta, color = ~seviyye, type = "box") %>%
      layout(xaxis = list(title = ""), yaxis = list(title = "Theta"),
             boxmode = "group")
  })

  # --- Theta Analizi ---

  output$theta_se_scatter <- renderPlotly({
    df <- filtered_data()
    plot_ly(df, x = ~theta, y = ~se, color = ~test_tipi,
            type = "scatter", mode = "markers",
            marker = list(size = 5, opacity = 0.5)) %>%
      layout(xaxis = list(title = "Theta"),
             yaxis = list(title = "Standart Xəta (SE)"))
  })

  output$theta_by_class <- renderPlotly({
    df <- filtered_data() %>%
      group_by(sinif) %>%
      summarise(ort_theta = mean(theta), sd_theta = sd(theta), n = n(), .groups = "drop")
    plot_ly(df, x = ~factor(sinif), y = ~ort_theta, type = "bar",
            marker = list(color = "#3c8dbc"),
            error_y = list(array = df$sd_theta, color = "#dd4b39"),
            text = ~paste0("n=", n), textposition = "outside") %>%
      layout(xaxis = list(title = "Sinif"),
             yaxis = list(title = "Orta Theta"))
  })

  output$theta_boxplot <- renderPlotly({
    df <- filtered_data()
    plot_ly(df, x = ~fen, y = ~theta, color = ~fen, type = "box") %>%
      layout(xaxis = list(title = ""), yaxis = list(title = "Theta"),
             showlegend = FALSE)
  })

  # --- IRT ---

  output$irt_scatter <- renderPlotly({
    plot_ly(irt_items, x = ~b, y = ~a, color = ~fen,
            type = "scatter", mode = "markers",
            marker = list(size = ~(c * 30 + 3), opacity = 0.7),
            text = ~paste0(sual_id, "<br>a=", a, " b=", b, " c=", c,
                           "<br>Uyğunluq: ", uygunluq)) %>%
      layout(xaxis = list(title = "b (Çətinlik)"),
             yaxis = list(title = "a (Ayırd etmə)"))
  })

  output$irt_b_hist <- renderPlotly({
    plot_ly(irt_items, x = ~b, type = "histogram",
            marker = list(color = "#f39c12", line = list(color = "white", width = 0.5)),
            nbinsx = 25) %>%
      layout(xaxis = list(title = "b (Çətinlik)"),
             yaxis = list(title = "Sual Sayı"))
  })

  output$irt_table <- DT::renderDataTable({
    datatable(irt_items,
              colnames = c("Sual ID", "Fən", "Mövzu", "a", "b", "c", "İstifadə", "Uyğunluq"),
              options = list(pageLength = 10, scrollX = TRUE),
              rownames = FALSE, filter = "top") %>%
      formatRound(c("a", "b", "c"), 2) %>%
      formatStyle("uygunluq",
                  backgroundColor = styleEqual(
                    c("Yaxşı", "Orta", "Zəif"),
                    c("#d4edda", "#fff3cd", "#f8d7da")))
  })

  # --- Məktəb Müqayisəsi ---

  output$school_compare <- renderPlotly({
    df <- filtered_data() %>%
      group_by(mekteb) %>%
      summarise(ort_theta = round(mean(theta), 3), n = n(), .groups = "drop") %>%
      filter(n >= 3) %>%
      arrange(desc(ort_theta)) %>%
      head(20)

    colors <- ifelse(df$ort_theta >= 0.5, "#00a65a",
                     ifelse(df$ort_theta >= 0, "#3c8dbc",
                            ifelse(df$ort_theta >= -0.5, "#f39c12", "#dd4b39")))

    plot_ly(df, x = ~reorder(mekteb, ort_theta), y = ~ort_theta, type = "bar",
            marker = list(color = colors),
            text = ~paste0("n=", n), textposition = "outside") %>%
      layout(xaxis = list(title = "", tickangle = -45),
             yaxis = list(title = "Orta Theta"),
             margin = list(b = 120))
  })

  # --- Axtarış ---

  output$search_results <- DT::renderDataTable({
    req(input$search_btn)
    isolate({
      query <- input$search_id
      if (nchar(query) < 2) return(NULL)

      df <- cat_results %>%
        filter(grepl(query, shagird_id, ignore.case = TRUE) |
               grepl(query, ad_soyad, ignore.case = TRUE))

      datatable(df,
                colnames = c("ID", "Ad Soyad", "Məktəb", "Sinif", "Fən", "Theta", "SE",
                             "Sual", "Düzgün", "Faiz%", "Müddət", "Tip", "Tarix", "Səviyyə"),
                options = list(pageLength = 10, scrollX = TRUE),
                rownames = FALSE) %>%
        formatRound(c("theta", "se"), 3)
    })
  })
}

shinyApp(ui = ui, server = server)
