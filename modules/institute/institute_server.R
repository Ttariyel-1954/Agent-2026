# =============================================
# İnstitut Strukturu: Server Məntiqi
# =============================================

# === 1. Struktur Server ===
inst_structure_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Reaktiv: vahidlər
    units_data <- reactiveVal(data.frame())

    load_units <- function() {
      tryCatch({
        data <- dbGetQuery(db_pool, "
          SELECT ou.*, p.name as parent_name
          FROM org_units ou
          LEFT JOIN org_units p ON ou.parent_id = p.id
          WHERE ou.is_active = TRUE
          ORDER BY ou.sort_order, ou.name
        ")
        units_data(data)
      }, error = function(e) {
        log_error("Vahidlər yüklənə bilmədi: {e$message}")
        units_data(data.frame())
      })
    }

    observe({ load_units() })

    # Statistika box-ları
    output$units_count_box <- renderValueBox({
      metrics <- calculate_institute_metrics(db_pool)
      valueBox(metrics$units, "Təşkilati Vahid", icon = icon("sitemap"), color = "aqua")
    })

    output$personnel_count_box <- renderValueBox({
      metrics <- calculate_institute_metrics(db_pool)
      valueBox(metrics$personnel, "Personal", icon = icon("users"), color = "green")
    })

    output$projects_count_box <- renderValueBox({
      metrics <- calculate_institute_metrics(db_pool)
      valueBox(metrics$projects, "Aktiv Layihə", icon = icon("project-diagram"), color = "yellow")
    })

    output$areas_count_box <- renderValueBox({
      metrics <- calculate_institute_metrics(db_pool)
      valueBox(metrics$areas, "Fəaliyyət Sahəsi", icon = icon("tasks"), color = "red")
    })

    # Org chart
    output$org_chart <- renderUI({
      units <- build_org_tree(db_pool)
      if (nrow(units) == 0) {
        return(tags$p(class = "text-muted", "Məlumat tapılmadı"))
      }
      tree_html <- render_org_tree_html(units)
      HTML(tree_html)
    })

    # Cədvəl
    output$units_table <- renderDT({
      data <- units_data()
      if (nrow(data) == 0) return(datatable(data.frame()))

      if (!is.null(input$filter_unit_type) && nchar(input$filter_unit_type) > 0) {
        data <- data[data$unit_type == input$filter_unit_type, ]
      }

      display_data <- data[, c("name", "unit_type", "head_name", "head_position", "phone", "email")]
      display_data$unit_type <- sapply(display_data$unit_type, function(x) {
        lbl <- UNIT_TYPES[x]; if (is.na(lbl)) x else lbl
      })
      colnames(display_data) <- c("Ad", "Növ", "Rəhbər", "Vəzifə", "Telefon", "E-poçt")

      datatable(display_data, selection = "single", rownames = FALSE,
        options = list(pageLength = 15, language = list(url = "//cdn.datatables.net/plug-ins/1.13.6/i18n/az.json"))
      )
    })

    # Yeni vahid əlavə et
    observeEvent(input$add_unit_btn, {
      showModal(modalDialog(
        title = "Yeni Təşkilati Vahid",
        textInput(ns("new_unit_name"), "Ad:", width = "100%"),
        textInput(ns("new_unit_short"), "Qısa Ad:"),
        selectInput(ns("new_unit_type"), "Növ:", choices = UNIT_TYPES),
        selectInput(ns("new_unit_parent"), "Tabe Olduğu Vahid:",
          choices = c("Yoxdur" = "", setNames(units_data()$id, units_data()$name))),
        textInput(ns("new_unit_head"), "Rəhbər:"),
        textInput(ns("new_unit_phone"), "Telefon:"),
        textInput(ns("new_unit_email"), "E-poçt:"),
        textAreaInput(ns("new_unit_desc"), "Təsvir:", rows = 3, width = "100%"),
        footer = tagList(
          modalButton("Ləğv et"),
          actionButton(ns("save_unit_btn"), "Saxla", class = "btn-primary")
        ),
        size = "m"
      ))
    })

    observeEvent(input$save_unit_btn, {
      data <- list(name = input$new_unit_name, unit_type = input$new_unit_type)
      validation <- validate_unit_data(data)
      if (!validation$valid) {
        showNotification(paste(validation$errors, collapse = "\n"), type = "error")
        return()
      }
      tryCatch({
        parent_val <- if (nchar(input$new_unit_parent) == 0) NA else input$new_unit_parent
        dbExecute(db_pool, "
          INSERT INTO org_units (name, short_name, unit_type, parent_id, head_name, phone, email, description)
          VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        ", params = list(
          input$new_unit_name, input$new_unit_short, input$new_unit_type,
          parent_val, input$new_unit_head, input$new_unit_phone,
          input$new_unit_email, input$new_unit_desc
        ))
        removeModal()
        load_units()
        showNotification("Vahid uğurla əlavə edildi", type = "message")
      }, error = function(e) {
        log_error("Vahid əlavə xətası: {e$message}")
        showNotification("Xəta baş verdi", type = "error")
      })
    })

    # Vahid redaktə et
    observeEvent(input$edit_unit_btn, {
      sel <- input$units_table_rows_selected
      if (is.null(sel) || length(sel) == 0) {
        showNotification("Redaktə üçün sətir seçin", type = "warning")
        return()
      }
      data <- units_data()
      if (!is.null(input$filter_unit_type) && nchar(input$filter_unit_type) > 0) {
        data <- data[data$unit_type == input$filter_unit_type, ]
      }
      row <- data[sel, ]
      showModal(modalDialog(
        title = "Vahidi Redaktə Et",
        hidden(textInput(ns("edit_unit_id"), "", value = row$id)),
        textInput(ns("edit_unit_name"), "Ad:", value = row$name, width = "100%"),
        textInput(ns("edit_unit_short"), "Qısa Ad:", value = row$short_name),
        selectInput(ns("edit_unit_type"), "Növ:", choices = UNIT_TYPES, selected = row$unit_type),
        selectInput(ns("edit_unit_parent"), "Tabe Olduğu Vahid:",
          choices = c("Yoxdur" = "", setNames(units_data()$id, units_data()$name)),
          selected = ifelse(is.na(row$parent_id), "", row$parent_id)),
        textInput(ns("edit_unit_head"), "Rəhbər:", value = row$head_name),
        textInput(ns("edit_unit_phone"), "Telefon:", value = row$phone),
        textInput(ns("edit_unit_email"), "E-poçt:", value = row$email),
        textAreaInput(ns("edit_unit_desc"), "Təsvir:", value = row$description, rows = 3, width = "100%"),
        footer = tagList(
          modalButton("Ləğv et"),
          actionButton(ns("update_unit_btn"), "Yenilə", class = "btn-primary")
        ),
        size = "m"
      ))
    })

    observeEvent(input$update_unit_btn, {
      data <- list(name = input$edit_unit_name, unit_type = input$edit_unit_type)
      validation <- validate_unit_data(data)
      if (!validation$valid) {
        showNotification(paste(validation$errors, collapse = "\n"), type = "error")
        return()
      }
      tryCatch({
        parent_val <- if (nchar(input$edit_unit_parent) == 0) NA else input$edit_unit_parent
        dbExecute(db_pool, "
          UPDATE org_units SET name=$1, short_name=$2, unit_type=$3, parent_id=$4,
            head_name=$5, phone=$6, email=$7, description=$8
          WHERE id=$9
        ", params = list(
          input$edit_unit_name, input$edit_unit_short, input$edit_unit_type,
          parent_val, input$edit_unit_head, input$edit_unit_phone,
          input$edit_unit_email, input$edit_unit_desc, input$edit_unit_id
        ))
        removeModal()
        load_units()
        showNotification("Vahid uğurla yeniləndi", type = "message")
      }, error = function(e) {
        log_error("Vahid yeniləmə xətası: {e$message}")
        showNotification("Xəta baş verdi", type = "error")
      })
    })

    # Vahid sil (soft delete)
    observeEvent(input$delete_unit_btn, {
      sel <- input$units_table_rows_selected
      if (is.null(sel) || length(sel) == 0) {
        showNotification("Silmək üçün sətir seçin", type = "warning")
        return()
      }
      data <- units_data()
      if (!is.null(input$filter_unit_type) && nchar(input$filter_unit_type) > 0) {
        data <- data[data$unit_type == input$filter_unit_type, ]
      }
      row <- data[sel, ]
      showModal(modalDialog(
        title = "Vahidi Sil",
        tags$p(paste0("'", row$name, "' vahidini silmək istədiyinizdən əminsiniz?")),
        tags$p(class = "text-danger", "Bu əməliyyat vahidə bağlı resurs və personal məlumatlarını da deaktiv edəcək."),
        footer = tagList(
          modalButton("Ləğv et"),
          actionButton(ns("confirm_delete_unit_btn"), "Sil", class = "btn-danger")
        )
      ))
    })

    observeEvent(input$confirm_delete_unit_btn, {
      sel <- input$units_table_rows_selected
      data <- units_data()
      if (!is.null(input$filter_unit_type) && nchar(input$filter_unit_type) > 0) {
        data <- data[data$unit_type == input$filter_unit_type, ]
      }
      row <- data[sel, ]
      tryCatch({
        dbExecute(db_pool, "UPDATE org_units SET is_active = FALSE WHERE id = $1", params = list(row$id))
        dbExecute(db_pool, "UPDATE unit_resources SET is_active = FALSE WHERE unit_id = $1", params = list(row$id))
        dbExecute(db_pool, "UPDATE unit_personnel SET is_active = FALSE WHERE unit_id = $1", params = list(row$id))
        removeModal()
        load_units()
        showNotification("Vahid uğurla silindi", type = "message")
      }, error = function(e) {
        log_error("Vahid silmə xətası: {e$message}")
        showNotification("Xəta baş verdi", type = "error")
      })
    })

    # Vahidlər export
    output$export_units_btn <- downloadHandler(
      filename = function() { paste0("vahidler_", format(Sys.Date(), "%Y%m%d"), ".csv") },
      content = function(file) {
        data <- units_data()
        if (nrow(data) > 0) {
          export <- data[, c("name", "unit_type", "head_name", "head_position", "phone", "email")]
          export$unit_type <- sapply(export$unit_type, function(x) { lbl <- UNIT_TYPES[x]; if(is.na(lbl)) x else lbl })
          colnames(export) <- c("Ad", "Növ", "Rəhbər", "Vəzifə", "Telefon", "E-poçt")
          write.csv(export, file, row.names = FALSE, fileEncoding = "UTF-8")
        } else {
          write.csv(data.frame(), file, row.names = FALSE)
        }
      }
    )
  })
}

# === 2. Resurslar Server ===
inst_resources_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    resources_data <- reactiveVal(data.frame())

    load_resources <- function() {
      tryCatch({
        data <- dbGetQuery(db_pool, "
          SELECT ur.*, ou.name as unit_name
          FROM unit_resources ur
          JOIN org_units ou ON ur.unit_id = ou.id
          WHERE ur.is_active = TRUE
          ORDER BY ur.created_at DESC
        ")
        resources_data(data)
      }, error = function(e) {
        log_error("Resurslar yüklənə bilmədi: {e$message}")
        resources_data(data.frame())
      })
    }

    observe({
      load_resources()
      units <- tryCatch(
        dbGetQuery(db_pool, "SELECT id, name FROM org_units WHERE is_active = TRUE ORDER BY name"),
        error = function(e) data.frame(id = character(), name = character())
      )
      updateSelectInput(session, "res_unit_filter",
        choices = c("Hamısı" = "", setNames(units$id, units$name)))
    })

    # Filtrli data
    filtered_resources <- reactive({
      data <- resources_data()
      if (nrow(data) == 0) return(data)
      if (!is.null(input$res_unit_filter) && nchar(input$res_unit_filter) > 0)
        data <- data[data$unit_id == input$res_unit_filter, ]
      if (!is.null(input$res_type_filter) && nchar(input$res_type_filter) > 0)
        data <- data[data$resource_type == input$res_type_filter, ]
      if (!is.null(input$res_condition_filter) && nchar(input$res_condition_filter) > 0)
        data <- data[data$condition == input$res_condition_filter, ]
      data
    })

    # Cədvəl
    output$resources_table <- renderDT({
      data <- filtered_resources()
      if (nrow(data) == 0) return(datatable(data.frame()))

      display_data <- data.frame(
        Vahid = data$unit_name,
        Ad = data$name,
        `Növ` = sapply(data$resource_type, function(x) { lbl <- INST_RESOURCE_TYPES[x]; if(is.na(lbl)) x else lbl }),
        `Sayı` = data$quantity,
        `Büdcə` = sapply(data$budget_amount, format_budget_azn),
        `Vəziyyət` = sapply(data$condition, function(x) { lbl <- RESOURCE_CONDITION[x]; if(is.na(lbl)) x else lbl }),
        check.names = FALSE
      )

      datatable(display_data, selection = "single", rownames = FALSE,
        options = list(pageLength = 10, language = list(url = "//cdn.datatables.net/plug-ins/1.13.6/i18n/az.json"))
      )
    })

    # Büdcə pie chart
    output$budget_pie_chart <- renderPlotly({
      summary <- calculate_resource_summary(db_pool,
        if (!is.null(input$res_unit_filter) && nchar(input$res_unit_filter) > 0) input$res_unit_filter else NULL
      )
      if (nrow(summary) == 0) return(plotly_empty())

      labels <- sapply(summary$resource_type, function(x) {
        lbl <- INST_RESOURCE_TYPES[x]; if(is.na(lbl)) x else lbl
      })

      plot_ly(summary, labels = labels, values = ~total_budget, type = "pie",
        textinfo = "label+percent",
        marker = list(colors = c("#3498db", "#2ecc71", "#e74c3c", "#f1c40f", "#9b59b6"))
      ) %>% layout(showlegend = TRUE, margin = list(t = 10, b = 10))
    })

    # Büdcə xülasə
    output$budget_summary <- renderUI({
      summary <- calculate_resource_summary(db_pool)
      total <- sum(summary$total_budget, na.rm = TRUE)
      tags$div(
        tags$h4("Ümumi Büdcə"),
        tags$h3(style = "color: #27ae60;", format_budget_azn(total)),
        tags$small(class = "text-muted", paste("Resurs sayı:", sum(summary$count, na.rm = TRUE)))
      )
    })

    # Yeni resurs
    observeEvent(input$add_resource_btn, {
      units <- tryCatch(
        dbGetQuery(db_pool, "SELECT id, name FROM org_units WHERE is_active = TRUE ORDER BY name"),
        error = function(e) data.frame(id = character(), name = character())
      )
      showModal(modalDialog(
        title = "Yeni Resurs",
        selectInput(ns("new_res_unit"), "Vahid:", choices = setNames(units$id, units$name)),
        textInput(ns("new_res_name"), "Ad:", width = "100%"),
        selectInput(ns("new_res_type"), "Növ:", choices = INST_RESOURCE_TYPES),
        numericInput(ns("new_res_qty"), "Sayı:", value = 1, min = 1),
        numericInput(ns("new_res_budget"), "Büdcə (AZN):", value = 0, min = 0),
        selectInput(ns("new_res_condition"), "Vəziyyət:", choices = RESOURCE_CONDITION),
        textAreaInput(ns("new_res_desc"), "Təsvir:", rows = 2, width = "100%"),
        footer = tagList(
          modalButton("Ləğv et"),
          actionButton(ns("save_resource_btn"), "Saxla", class = "btn-primary")
        ),
        size = "m"
      ))
    })

    observeEvent(input$save_resource_btn, {
      data <- list(name = input$new_res_name, resource_type = input$new_res_type,
                   unit_id = input$new_res_unit, budget_amount = input$new_res_budget)
      validation <- validate_resource_data(data)
      if (!validation$valid) {
        showNotification(paste(validation$errors, collapse = "\n"), type = "error")
        return()
      }
      tryCatch({
        dbExecute(db_pool, "
          INSERT INTO unit_resources (unit_id, resource_type, name, description, quantity, budget_amount, condition)
          VALUES ($1, $2, $3, $4, $5, $6, $7)
        ", params = list(
          input$new_res_unit, input$new_res_type, input$new_res_name,
          input$new_res_desc, input$new_res_qty, input$new_res_budget, input$new_res_condition
        ))
        removeModal()
        load_resources()
        showNotification("Resurs uğurla əlavə edildi", type = "message")
      }, error = function(e) {
        log_error("Resurs əlavə xətası: {e$message}")
        showNotification("Xəta baş verdi", type = "error")
      })
    })

    # Resurs redaktə
    observeEvent(input$edit_resource_btn, {
      sel <- input$resources_table_rows_selected
      if (is.null(sel) || length(sel) == 0) {
        showNotification("Redaktə üçün sətir seçin", type = "warning")
        return()
      }
      data <- filtered_resources()
      row <- data[sel, ]
      units <- tryCatch(
        dbGetQuery(db_pool, "SELECT id, name FROM org_units WHERE is_active = TRUE ORDER BY name"),
        error = function(e) data.frame(id = character(), name = character())
      )
      showModal(modalDialog(
        title = "Resursu Redaktə Et",
        hidden(textInput(ns("edit_res_id"), "", value = row$id)),
        selectInput(ns("edit_res_unit"), "Vahid:", choices = setNames(units$id, units$name), selected = row$unit_id),
        textInput(ns("edit_res_name"), "Ad:", value = row$name, width = "100%"),
        selectInput(ns("edit_res_type"), "Növ:", choices = INST_RESOURCE_TYPES, selected = row$resource_type),
        numericInput(ns("edit_res_qty"), "Sayı:", value = row$quantity, min = 1),
        numericInput(ns("edit_res_budget"), "Büdcə (AZN):", value = row$budget_amount, min = 0),
        selectInput(ns("edit_res_condition"), "Vəziyyət:", choices = RESOURCE_CONDITION, selected = row$condition),
        textAreaInput(ns("edit_res_desc"), "Təsvir:", value = row$description, rows = 2, width = "100%"),
        footer = tagList(
          modalButton("Ləğv et"),
          actionButton(ns("update_resource_btn"), "Yenilə", class = "btn-primary")
        ),
        size = "m"
      ))
    })

    observeEvent(input$update_resource_btn, {
      tryCatch({
        dbExecute(db_pool, "
          UPDATE unit_resources SET unit_id=$1, resource_type=$2, name=$3, description=$4,
            quantity=$5, budget_amount=$6, condition=$7
          WHERE id=$8
        ", params = list(
          input$edit_res_unit, input$edit_res_type, input$edit_res_name,
          input$edit_res_desc, input$edit_res_qty, input$edit_res_budget,
          input$edit_res_condition, input$edit_res_id
        ))
        removeModal()
        load_resources()
        showNotification("Resurs uğurla yeniləndi", type = "message")
      }, error = function(e) {
        log_error("Resurs yeniləmə xətası: {e$message}")
        showNotification("Xəta baş verdi", type = "error")
      })
    })

    # Resurs sil
    observeEvent(input$delete_resource_btn, {
      sel <- input$resources_table_rows_selected
      if (is.null(sel) || length(sel) == 0) {
        showNotification("Silmək üçün sətir seçin", type = "warning")
        return()
      }
      data <- filtered_resources()
      row <- data[sel, ]
      showModal(modalDialog(
        title = "Resursu Sil",
        tags$p(paste0("'", row$name, "' resursunu silmək istədiyinizdən əminsiniz?")),
        footer = tagList(
          modalButton("Ləğv et"),
          actionButton(ns("confirm_delete_resource_btn"), "Sil", class = "btn-danger")
        )
      ))
    })

    observeEvent(input$confirm_delete_resource_btn, {
      sel <- input$resources_table_rows_selected
      data <- filtered_resources()
      row <- data[sel, ]
      tryCatch({
        dbExecute(db_pool, "UPDATE unit_resources SET is_active = FALSE WHERE id = $1", params = list(row$id))
        removeModal()
        load_resources()
        showNotification("Resurs uğurla silindi", type = "message")
      }, error = function(e) {
        log_error("Resurs silmə xətası: {e$message}")
        showNotification("Xəta baş verdi", type = "error")
      })
    })

    # Resurs export
    output$export_resources_btn <- downloadHandler(
      filename = function() { paste0("resurslar_", format(Sys.Date(), "%Y%m%d"), ".csv") },
      content = function(file) {
        data <- filtered_resources()
        if (nrow(data) > 0) {
          export <- data.frame(
            Vahid = data$unit_name, Ad = data$name,
            `Növ` = sapply(data$resource_type, function(x) { lbl <- INST_RESOURCE_TYPES[x]; if(is.na(lbl)) x else lbl }),
            `Sayı` = data$quantity, `Büdcə` = data$budget_amount,
            `Vəziyyət` = sapply(data$condition, function(x) { lbl <- RESOURCE_CONDITION[x]; if(is.na(lbl)) x else lbl }),
            check.names = FALSE
          )
          write.csv(export, file, row.names = FALSE, fileEncoding = "UTF-8")
        } else {
          write.csv(data.frame(), file, row.names = FALSE)
        }
      }
    )
  })
}

# === 3. Kontingent Server ===
inst_contingent_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    personnel_data <- reactiveVal(data.frame())

    load_personnel <- function() {
      tryCatch({
        data <- dbGetQuery(db_pool, "
          SELECT up.*, ou.name as unit_name
          FROM unit_personnel up
          JOIN org_units ou ON up.unit_id = ou.id
          WHERE up.is_active = TRUE
          ORDER BY up.full_name
        ")
        personnel_data(data)
      }, error = function(e) {
        log_error("Personal yüklənə bilmədi: {e$message}")
        personnel_data(data.frame())
      })
    }

    observe({
      load_personnel()
      units <- tryCatch(
        dbGetQuery(db_pool, "SELECT id, name FROM org_units WHERE is_active = TRUE ORDER BY name"),
        error = function(e) data.frame(id = character(), name = character())
      )
      updateSelectInput(session, "pers_unit_filter",
        choices = c("Hamısı" = "", setNames(units$id, units$name)))
    })

    # Filtrli data
    filtered_personnel <- reactive({
      data <- personnel_data()
      if (nrow(data) == 0) return(data)
      if (!is.null(input$pers_unit_filter) && nchar(input$pers_unit_filter) > 0)
        data <- data[data$unit_id == input$pers_unit_filter, ]
      if (!is.null(input$pers_type_filter) && nchar(input$pers_type_filter) > 0)
        data <- data[data$personnel_type == input$pers_type_filter, ]
      if (!is.null(input$pers_employment_filter) && nchar(input$pers_employment_filter) > 0)
        data <- data[data$employment_type == input$pers_employment_filter, ]
      data
    })

    # Cədvəl
    output$personnel_table <- renderDT({
      data <- filtered_personnel()
      if (nrow(data) == 0) return(datatable(data.frame()))

      display_data <- data.frame(
        `Ad Soyad` = data$full_name,
        Vahid = data$unit_name,
        `Vəzifə` = data$position,
        `Növ` = sapply(data$personnel_type, function(x) { lbl <- PERSONNEL_TYPES[x]; if(is.na(lbl)) x else lbl }),
        `Məşğulluq` = sapply(data$employment_type, function(x) { lbl <- EMPLOYMENT_TYPES[x]; if(is.na(lbl)) x else lbl }),
        `İşə başlama` = format(as.Date(data$hire_date), "%d.%m.%Y"),
        check.names = FALSE
      )

      datatable(display_data, selection = "single", rownames = FALSE,
        options = list(pageLength = 10, language = list(url = "//cdn.datatables.net/plug-ins/1.13.6/i18n/az.json"))
      )
    })

    # Vahid üzrə chart
    output$personnel_by_unit_chart <- renderPlotly({
      data <- personnel_data()
      if (nrow(data) == 0) return(plotly_empty())
      by_unit <- data %>% group_by(unit_name) %>% summarise(count = n(), .groups = "drop") %>% arrange(desc(count))
      plot_ly(by_unit, x = ~reorder(unit_name, count), y = ~count, type = "bar",
        marker = list(color = "#3498db")) %>%
        layout(xaxis = list(title = "", tickangle = -45), yaxis = list(title = "Nəfər"), margin = list(b = 100))
    })

    # Növ üzrə chart
    output$personnel_by_type_chart <- renderPlotly({
      data <- personnel_data()
      if (nrow(data) == 0) return(plotly_empty())
      by_type <- data %>% group_by(personnel_type) %>% summarise(count = n(), .groups = "drop")
      labels <- sapply(by_type$personnel_type, function(x) { lbl <- PERSONNEL_TYPES[x]; if(is.na(lbl)) x else lbl })
      plot_ly(by_type, labels = labels, values = ~count, type = "pie",
        textinfo = "label+percent",
        marker = list(colors = c("#2ecc71", "#3498db", "#e74c3c", "#f1c40f", "#9b59b6"))
      ) %>% layout(showlegend = FALSE, margin = list(t = 10, b = 10))
    })

    # Yeni personal
    observeEvent(input$add_personnel_btn, {
      units <- tryCatch(
        dbGetQuery(db_pool, "SELECT id, name FROM org_units WHERE is_active = TRUE ORDER BY name"),
        error = function(e) data.frame(id = character(), name = character())
      )
      showModal(modalDialog(
        title = "Yeni Personal",
        textInput(ns("new_pers_name"), "Ad Soyad:", width = "100%"),
        selectInput(ns("new_pers_unit"), "Vahid:", choices = setNames(units$id, units$name)),
        textInput(ns("new_pers_position"), "Vəzifə:"),
        selectInput(ns("new_pers_type"), "Növ:", choices = PERSONNEL_TYPES),
        selectInput(ns("new_pers_employment"), "Məşğulluq:", choices = EMPLOYMENT_TYPES),
        textInput(ns("new_pers_specialization"), "İxtisas:"),
        textInput(ns("new_pers_phone"), "Telefon:"),
        textInput(ns("new_pers_email"), "E-poçt:"),
        dateInput(ns("new_pers_hire_date"), "İşə başlama tarixi:", value = Sys.Date(), language = "az"),
        footer = tagList(
          modalButton("Ləğv et"),
          actionButton(ns("save_personnel_btn"), "Saxla", class = "btn-primary")
        ),
        size = "m"
      ))
    })

    observeEvent(input$save_personnel_btn, {
      data <- list(full_name = input$new_pers_name, personnel_type = input$new_pers_type, unit_id = input$new_pers_unit)
      validation <- validate_personnel_data(data)
      if (!validation$valid) {
        showNotification(paste(validation$errors, collapse = "\n"), type = "error")
        return()
      }
      tryCatch({
        dbExecute(db_pool, "
          INSERT INTO unit_personnel (unit_id, full_name, position, personnel_type, employment_type,
                                       specialization, phone, email, hire_date)
          VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
        ", params = list(
          input$new_pers_unit, input$new_pers_name, input$new_pers_position,
          input$new_pers_type, input$new_pers_employment, input$new_pers_specialization,
          input$new_pers_phone, input$new_pers_email, as.character(input$new_pers_hire_date)
        ))
        removeModal()
        load_personnel()
        showNotification("Personal uğurla əlavə edildi", type = "message")
      }, error = function(e) {
        log_error("Personal əlavə xətası: {e$message}")
        showNotification("Xəta baş verdi", type = "error")
      })
    })

    # Personal redaktə
    observeEvent(input$edit_personnel_btn, {
      sel <- input$personnel_table_rows_selected
      if (is.null(sel) || length(sel) == 0) {
        showNotification("Redaktə üçün sətir seçin", type = "warning")
        return()
      }
      data <- filtered_personnel()
      row <- data[sel, ]
      units <- tryCatch(
        dbGetQuery(db_pool, "SELECT id, name FROM org_units WHERE is_active = TRUE ORDER BY name"),
        error = function(e) data.frame(id = character(), name = character())
      )
      showModal(modalDialog(
        title = "Personalı Redaktə Et",
        hidden(textInput(ns("edit_pers_id"), "", value = row$id)),
        textInput(ns("edit_pers_name"), "Ad Soyad:", value = row$full_name, width = "100%"),
        selectInput(ns("edit_pers_unit"), "Vahid:", choices = setNames(units$id, units$name), selected = row$unit_id),
        textInput(ns("edit_pers_position"), "Vəzifə:", value = row$position),
        selectInput(ns("edit_pers_type"), "Növ:", choices = PERSONNEL_TYPES, selected = row$personnel_type),
        selectInput(ns("edit_pers_employment"), "Məşğulluq:", choices = EMPLOYMENT_TYPES, selected = row$employment_type),
        textInput(ns("edit_pers_specialization"), "İxtisas:", value = row$specialization),
        textInput(ns("edit_pers_phone"), "Telefon:", value = row$phone),
        textInput(ns("edit_pers_email"), "E-poçt:", value = row$email),
        footer = tagList(
          modalButton("Ləğv et"),
          actionButton(ns("update_personnel_btn"), "Yenilə", class = "btn-primary")
        ),
        size = "m"
      ))
    })

    observeEvent(input$update_personnel_btn, {
      tryCatch({
        dbExecute(db_pool, "
          UPDATE unit_personnel SET unit_id=$1, full_name=$2, position=$3, personnel_type=$4,
            employment_type=$5, specialization=$6, phone=$7, email=$8
          WHERE id=$9
        ", params = list(
          input$edit_pers_unit, input$edit_pers_name, input$edit_pers_position,
          input$edit_pers_type, input$edit_pers_employment, input$edit_pers_specialization,
          input$edit_pers_phone, input$edit_pers_email, input$edit_pers_id
        ))
        removeModal()
        load_personnel()
        showNotification("Personal uğurla yeniləndi", type = "message")
      }, error = function(e) {
        log_error("Personal yeniləmə xətası: {e$message}")
        showNotification("Xəta baş verdi", type = "error")
      })
    })

    # Personal sil
    observeEvent(input$delete_personnel_btn, {
      sel <- input$personnel_table_rows_selected
      if (is.null(sel) || length(sel) == 0) {
        showNotification("Silmək üçün sətir seçin", type = "warning")
        return()
      }
      data <- filtered_personnel()
      row <- data[sel, ]
      showModal(modalDialog(
        title = "Personalı Sil",
        tags$p(paste0("'", row$full_name, "' personalını silmək istədiyinizdən əminsiniz?")),
        footer = tagList(
          modalButton("Ləğv et"),
          actionButton(ns("confirm_delete_personnel_btn"), "Sil", class = "btn-danger")
        )
      ))
    })

    observeEvent(input$confirm_delete_personnel_btn, {
      sel <- input$personnel_table_rows_selected
      data <- filtered_personnel()
      row <- data[sel, ]
      tryCatch({
        dbExecute(db_pool, "UPDATE unit_personnel SET is_active = FALSE WHERE id = $1", params = list(row$id))
        removeModal()
        load_personnel()
        showNotification("Personal uğurla silindi", type = "message")
      }, error = function(e) {
        log_error("Personal silmə xətası: {e$message}")
        showNotification("Xəta baş verdi", type = "error")
      })
    })

    # Personal export
    output$export_personnel_btn <- downloadHandler(
      filename = function() { paste0("personal_", format(Sys.Date(), "%Y%m%d"), ".csv") },
      content = function(file) {
        data <- filtered_personnel()
        if (nrow(data) > 0) {
          export <- data.frame(
            `Ad Soyad` = data$full_name, Vahid = data$unit_name, `Vəzifə` = data$position,
            `Növ` = sapply(data$personnel_type, function(x) { lbl <- PERSONNEL_TYPES[x]; if(is.na(lbl)) x else lbl }),
            `Məşğulluq` = sapply(data$employment_type, function(x) { lbl <- EMPLOYMENT_TYPES[x]; if(is.na(lbl)) x else lbl }),
            check.names = FALSE
          )
          write.csv(export, file, row.names = FALSE, fileEncoding = "UTF-8")
        } else {
          write.csv(data.frame(), file, row.names = FALSE)
        }
      }
    )
  })
}

# === 4. Monitorinq Server ===
inst_monitoring_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    areas_data <- reactiveVal(data.frame())
    kpis_data <- reactiveVal(data.frame())
    projects_data <- reactiveVal(data.frame())
    progress_data <- reactiveVal(data.frame())

    load_areas <- function() {
      tryCatch({
        data <- dbGetQuery(db_pool, "
          SELECT aa.*, ou.name as unit_name
          FROM activity_areas aa
          JOIN org_units ou ON aa.unit_id = ou.id
          WHERE aa.is_active = TRUE
          ORDER BY aa.priority DESC, aa.name
        ")
        areas_data(data)
      }, error = function(e) {
        log_error("Fəaliyyət sahələri yüklənə bilmədi: {e$message}")
        areas_data(data.frame())
      })
    }

    load_kpis <- function() {
      tryCatch({
        data <- dbGetQuery(db_pool, "
          SELECT ak.*, aa.name as activity_name
          FROM activity_kpis ak
          JOIN activity_areas aa ON ak.activity_id = aa.id
          WHERE ak.is_active = TRUE
          ORDER BY ak.name
        ")
        kpis_data(data)
      }, error = function(e) {
        log_error("KPI-lər yüklənə bilmədi: {e$message}")
        kpis_data(data.frame())
      })
    }

    load_projects <- function() {
      tryCatch({
        data <- dbGetQuery(db_pool, "
          SELECT up.*, ou.name as unit_name
          FROM unit_projects up
          JOIN org_units ou ON up.unit_id = ou.id
          WHERE up.is_active = TRUE
          ORDER BY up.priority, up.name
        ")
        projects_data(data)
      }, error = function(e) {
        log_error("Layihələr yüklənə bilmədi: {e$message}")
        projects_data(data.frame())
      })
    }

    load_progress <- function() {
      tryCatch({
        data <- dbGetQuery(db_pool, "
          SELECT ap.*, ak.name as kpi_name, ak.target_value, ak.unit_measure
          FROM activity_progress ap
          JOIN activity_kpis ak ON ap.kpi_id = ak.id
          ORDER BY ap.period_end DESC
        ")
        progress_data(data)
      }, error = function(e) {
        log_error("İrəliləyiş yüklənə bilmədi: {e$message}")
        progress_data(data.frame())
      })
    }

    observe({
      load_areas()
      load_kpis()
      load_projects()
      load_progress()

      units <- tryCatch(
        dbGetQuery(db_pool, "SELECT id, name FROM org_units WHERE is_active = TRUE ORDER BY name"),
        error = function(e) data.frame(id = character(), name = character())
      )
      for (input_id in c("area_unit_filter", "proj_unit_filter")) {
        updateSelectInput(session, input_id, choices = c("Hamısı" = "", setNames(units$id, units$name)))
      }

      areas <- areas_data()
      if (nrow(areas) > 0) {
        updateSelectInput(session, "kpi_activity_filter", choices = c("Hamısı" = "", setNames(areas$id, areas$name)))
      }

      kpis <- kpis_data()
      if (nrow(kpis) > 0) {
        updateSelectInput(session, "prog_kpi_filter", choices = c("Hamısı" = "", setNames(kpis$id, kpis$name)))
      }
    })

    # Fəaliyyət sahələri cədvəli
    output$areas_table <- renderDT({
      data <- areas_data()
      if (nrow(data) == 0) return(datatable(data.frame()))
      if (!is.null(input$area_unit_filter) && nchar(input$area_unit_filter) > 0)
        data <- data[data$unit_id == input$area_unit_filter, ]
      if (!is.null(input$area_category_filter) && nchar(input$area_category_filter) > 0)
        data <- data[data$category == input$area_category_filter, ]
      if (nrow(data) == 0) return(datatable(data.frame()))

      display_data <- data.frame(
        Ad = data$name, Vahid = data$unit_name,
        Kateqoriya = sapply(data$category, function(x) { lbl <- ACTIVITY_CATEGORIES[x]; if(is.na(lbl)) x else lbl }),
        Prioritet = data$priority, Status = data$status, check.names = FALSE
      )
      datatable(display_data, selection = "single", rownames = FALSE,
        options = list(pageLength = 10, language = list(url = "//cdn.datatables.net/plug-ins/1.13.6/i18n/az.json")))
    })

    # KPI cədvəli
    output$kpis_table <- renderDT({
      data <- kpis_data()
      if (nrow(data) == 0) return(datatable(data.frame()))
      if (!is.null(input$kpi_activity_filter) && nchar(input$kpi_activity_filter) > 0)
        data <- data[data$activity_id == input$kpi_activity_filter, ]
      if (nrow(data) == 0) return(datatable(data.frame()))

      display_data <- data.frame(
        Ad = data$name, `Fəaliyyət` = data$activity_name,
        `Hədəf` = data$target_value, `Baza` = data$baseline_value,
        `Ölçü` = data$unit_measure,
        Tezlik = sapply(data$frequency, function(x) { lbl <- KPI_FREQUENCY[x]; if(is.na(lbl)) x else lbl }),
        check.names = FALSE
      )
      datatable(display_data, selection = "single", rownames = FALSE,
        options = list(pageLength = 10, language = list(url = "//cdn.datatables.net/plug-ins/1.13.6/i18n/az.json")))
    })

    # KPI completion chart
    output$kpi_completion_chart <- renderPlotly({
      completion <- calculate_kpi_completion(db_pool,
        if (!is.null(input$kpi_activity_filter) && nchar(input$kpi_activity_filter) > 0) input$kpi_activity_filter else NULL)
      if (nrow(completion) == 0) return(plotly_empty())
      colors <- ifelse(completion$completion_pct >= 100, "#27ae60",
                 ifelse(completion$completion_pct >= 70, "#f39c12", "#e74c3c"))
      plot_ly(completion, x = ~name, y = ~completion_pct, type = "bar",
        marker = list(color = colors), text = ~paste0(completion_pct, "%"), textposition = "outside") %>%
        layout(xaxis = list(title = "", tickangle = -45),
          yaxis = list(title = "Tamamlanma (%)", range = c(0, max(120, max(completion$completion_pct) + 10))),
          shapes = list(list(type = "line", x0 = -0.5, x1 = nrow(completion) - 0.5,
            y0 = 100, y1 = 100, line = list(color = "#27ae60", dash = "dash", width = 2))),
          margin = list(b = 120))
    })

    # Layihələr cədvəli
    output$projects_table <- renderDT({
      data <- projects_data()
      if (nrow(data) == 0) return(datatable(data.frame()))
      if (!is.null(input$proj_unit_filter) && nchar(input$proj_unit_filter) > 0)
        data <- data[data$unit_id == input$proj_unit_filter, ]
      if (!is.null(input$proj_status_filter) && nchar(input$proj_status_filter) > 0)
        data <- data[data$status == input$proj_status_filter, ]
      if (!is.null(input$proj_priority_filter) && nchar(input$proj_priority_filter) > 0)
        data <- data[data$priority == input$proj_priority_filter, ]
      if (nrow(data) == 0) return(datatable(data.frame()))

      display_data <- data.frame(
        Ad = data$name, Vahid = data$unit_name,
        `Büdcə` = sapply(data$budget, format_budget_azn),
        Prioritet = sapply(data$priority, function(x) { lbl <- PROJECT_PRIORITY[x]; if(is.na(lbl)) x else lbl }),
        Status = sapply(data$status, function(x) { lbl <- INST_PROJECT_STATUS[x]; if(is.na(lbl)) x else lbl }),
        `Başlama` = format(as.Date(data$start_date), "%d.%m.%Y"), check.names = FALSE
      )
      datatable(display_data, selection = "single", rownames = FALSE,
        options = list(pageLength = 10, language = list(url = "//cdn.datatables.net/plug-ins/1.13.6/i18n/az.json")))
    })

    # İrəliləyiş cədvəli
    output$progress_table <- renderDT({
      data <- progress_data()
      if (nrow(data) == 0) return(datatable(data.frame()))
      if (!is.null(input$prog_kpi_filter) && nchar(input$prog_kpi_filter) > 0)
        data <- data[data$kpi_id == input$prog_kpi_filter, ]
      if (!is.null(input$prog_date_range))
        data <- data[as.Date(data$period_end) >= input$prog_date_range[1] &
                     as.Date(data$period_end) <= input$prog_date_range[2], ]
      if (nrow(data) == 0) return(datatable(data.frame()))

      display_data <- data.frame(
        KPI = data$kpi_name, `Faktiki` = data$actual_value, `Hədəf` = data$target_value,
        `Ölçü` = data$unit_measure, `Dövr sonu` = format(as.Date(data$period_end), "%d.%m.%Y"),
        Qeyd = data$notes, check.names = FALSE
      )
      datatable(display_data, selection = "single", rownames = FALSE,
        options = list(pageLength = 10, language = list(url = "//cdn.datatables.net/plug-ins/1.13.6/i18n/az.json")))
    })

    # İrəliləyiş trend chart
    output$progress_trend_chart <- renderPlotly({
      data <- progress_data()
      if (nrow(data) == 0) return(plotly_empty())
      if (!is.null(input$prog_kpi_filter) && nchar(input$prog_kpi_filter) > 0)
        data <- data[data$kpi_id == input$prog_kpi_filter, ]
      if (nrow(data) == 0) return(plotly_empty())

      data$period_end <- as.Date(data$period_end)
      data <- data[order(data$period_end), ]
      plot_ly(data, x = ~period_end, y = ~actual_value, type = "scatter", mode = "lines+markers",
        name = "Faktiki", line = list(color = "#3498db", width = 3),
        marker = list(size = 8, color = "#2980b9")) %>%
        add_trace(y = ~target_value, name = "Hədəf",
          line = list(color = "#27ae60", dash = "dash", width = 2), marker = list(size = 0)) %>%
        layout(xaxis = list(title = "Tarix"), yaxis = list(title = "Dəyər"), hovermode = "x unified")
    })

    # === CRUD Modallar ===

    # Yeni sahə
    observeEvent(input$add_area_btn, {
      units <- tryCatch(
        dbGetQuery(db_pool, "SELECT id, name FROM org_units WHERE is_active = TRUE ORDER BY name"),
        error = function(e) data.frame(id = character(), name = character()))
      showModal(modalDialog(
        title = "Yeni Fəaliyyət Sahəsi",
        textInput(ns("new_area_name"), "Ad:", width = "100%"),
        selectInput(ns("new_area_unit"), "Məsul Vahid:", choices = setNames(units$id, units$name)),
        selectInput(ns("new_area_category"), "Kateqoriya:", choices = ACTIVITY_CATEGORIES),
        textAreaInput(ns("new_area_desc"), "Təsvir:", rows = 3, width = "100%"),
        numericInput(ns("new_area_priority"), "Prioritet (1-5):", value = 3, min = 1, max = 5),
        footer = tagList(modalButton("Ləğv et"), actionButton(ns("save_area_btn"), "Saxla", class = "btn-primary")),
        size = "m"))
    })

    observeEvent(input$save_area_btn, {
      tryCatch({
        dbExecute(db_pool, "INSERT INTO activity_areas (unit_id, name, category, description, priority) VALUES ($1, $2, $3, $4, $5)",
          params = list(input$new_area_unit, input$new_area_name, input$new_area_category, input$new_area_desc, input$new_area_priority))
        removeModal(); load_areas()
        showNotification("Fəaliyyət sahəsi uğurla əlavə edildi", type = "message")
      }, error = function(e) { log_error("Sahə əlavə xətası: {e$message}"); showNotification("Xəta baş verdi", type = "error") })
    })

    # Sahə silmə
    observeEvent(input$delete_area_btn, {
      sel <- input$areas_table_rows_selected
      if (is.null(sel)) { showNotification("Sətir seçin", type = "warning"); return() }
      data <- areas_data()
      row <- data[sel, ]
      showModal(modalDialog(title = "Sahəni Sil",
        tags$p(paste0("'", row$name, "' sahəsini silmək istəyirsiniz?")),
        footer = tagList(modalButton("Ləğv et"), actionButton(ns("confirm_delete_area_btn"), "Sil", class = "btn-danger"))))
    })

    observeEvent(input$confirm_delete_area_btn, {
      sel <- input$areas_table_rows_selected
      row <- areas_data()[sel, ]
      tryCatch({
        dbExecute(db_pool, "UPDATE activity_areas SET is_active = FALSE WHERE id = $1", params = list(row$id))
        removeModal(); load_areas()
        showNotification("Sahə silindi", type = "message")
      }, error = function(e) { showNotification("Xəta baş verdi", type = "error") })
    })

    # Yeni KPI
    observeEvent(input$add_kpi_btn, {
      areas <- areas_data()
      area_choices <- if (nrow(areas) > 0) setNames(areas$id, areas$name) else character()
      showModal(modalDialog(
        title = "Yeni KPI Göstəricisi",
        textInput(ns("new_kpi_name"), "Ad:", width = "100%"),
        selectInput(ns("new_kpi_activity"), "Fəaliyyət Sahəsi:", choices = area_choices),
        numericInput(ns("new_kpi_target"), "Hədəf Dəyər:", value = 100, min = 0),
        numericInput(ns("new_kpi_baseline"), "Baza Dəyər:", value = 0, min = 0),
        textInput(ns("new_kpi_unit"), "Ölçü Vahidi:", value = "%"),
        selectInput(ns("new_kpi_frequency"), "Tezlik:", choices = KPI_FREQUENCY, selected = "ayliq"),
        textAreaInput(ns("new_kpi_desc"), "Təsvir:", rows = 2, width = "100%"),
        footer = tagList(modalButton("Ləğv et"), actionButton(ns("save_kpi_btn"), "Saxla", class = "btn-primary")),
        size = "m"))
    })

    observeEvent(input$save_kpi_btn, {
      data <- list(name = input$new_kpi_name, target_value = input$new_kpi_target, activity_id = input$new_kpi_activity)
      validation <- validate_kpi_data(data)
      if (!validation$valid) { showNotification(paste(validation$errors, collapse = "\n"), type = "error"); return() }
      tryCatch({
        dbExecute(db_pool, "INSERT INTO activity_kpis (activity_id, name, description, unit_measure, target_value, baseline_value, frequency) VALUES ($1, $2, $3, $4, $5, $6, $7)",
          params = list(input$new_kpi_activity, input$new_kpi_name, input$new_kpi_desc, input$new_kpi_unit, input$new_kpi_target, input$new_kpi_baseline, input$new_kpi_frequency))
        removeModal(); load_kpis()
        showNotification("KPI uğurla əlavə edildi", type = "message")
      }, error = function(e) { log_error("KPI əlavə xətası: {e$message}"); showNotification("Xəta baş verdi", type = "error") })
    })

    # İrəliləyiş qeyd et
    observeEvent(input$add_progress_btn, {
      kpis <- kpis_data()
      kpi_choices <- if (nrow(kpis) > 0) setNames(kpis$id, kpis$name) else character()
      showModal(modalDialog(
        title = "KPI İrəliləyiş Qeydi",
        selectInput(ns("new_prog_kpi"), "KPI:", choices = kpi_choices),
        numericInput(ns("new_prog_value"), "Faktiki Dəyər:", value = 0, min = 0),
        dateInput(ns("new_prog_start"), "Dövr başlanğıcı:", value = Sys.Date() - 30, language = "az"),
        dateInput(ns("new_prog_end"), "Dövr sonu:", value = Sys.Date(), language = "az"),
        textAreaInput(ns("new_prog_notes"), "Qeydlər:", rows = 2, width = "100%"),
        footer = tagList(modalButton("Ləğv et"), actionButton(ns("save_progress_btn"), "Saxla", class = "btn-primary")),
        size = "m"))
    })

    observeEvent(input$save_progress_btn, {
      tryCatch({
        dbExecute(db_pool, "INSERT INTO activity_progress (kpi_id, period_start, period_end, actual_value, notes) VALUES ($1, $2, $3, $4, $5)",
          params = list(input$new_prog_kpi, as.character(input$new_prog_start), as.character(input$new_prog_end), input$new_prog_value, input$new_prog_notes))
        removeModal(); load_progress()
        showNotification("İrəliləyiş qeydi əlavə edildi", type = "message")
      }, error = function(e) { log_error("İrəliləyiş xətası: {e$message}"); showNotification("Xəta baş verdi", type = "error") })
    })

    # Yeni layihə
    observeEvent(input$add_project_btn, {
      units <- tryCatch(
        dbGetQuery(db_pool, "SELECT id, name FROM org_units WHERE is_active = TRUE ORDER BY name"),
        error = function(e) data.frame(id = character(), name = character()))
      showModal(modalDialog(
        title = "Yeni Layihə",
        textInput(ns("new_proj_name"), "Ad:", width = "100%"),
        selectInput(ns("new_proj_unit"), "Vahid:", choices = setNames(units$id, units$name)),
        textAreaInput(ns("new_proj_desc"), "Təsvir:", rows = 3, width = "100%"),
        numericInput(ns("new_proj_budget"), "Büdcə (AZN):", value = 0, min = 0),
        selectInput(ns("new_proj_priority"), "Prioritet:", choices = PROJECT_PRIORITY, selected = "orta"),
        selectInput(ns("new_proj_status"), "Status:", choices = INST_PROJECT_STATUS, selected = "planlasdirilan"),
        dateInput(ns("new_proj_start"), "Başlama tarixi:", value = Sys.Date(), language = "az"),
        dateInput(ns("new_proj_end"), "Bitmə tarixi:", value = Sys.Date() + 180, language = "az"),
        textInput(ns("new_proj_manager"), "Layihə meneceri:"),
        footer = tagList(modalButton("Ləğv et"), actionButton(ns("save_project_btn"), "Saxla", class = "btn-primary")),
        size = "m"))
    })

    observeEvent(input$save_project_btn, {
      data <- list(name = input$new_proj_name, unit_id = input$new_proj_unit, budget = input$new_proj_budget)
      validation <- validate_project_data(data)
      if (!validation$valid) { showNotification(paste(validation$errors, collapse = "\n"), type = "error"); return() }
      tryCatch({
        dbExecute(db_pool, "INSERT INTO unit_projects (unit_id, name, description, budget, priority, status, start_date, end_date, manager_name) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)",
          params = list(input$new_proj_unit, input$new_proj_name, input$new_proj_desc, input$new_proj_budget,
            input$new_proj_priority, input$new_proj_status, as.character(input$new_proj_start), as.character(input$new_proj_end), input$new_proj_manager))
        removeModal(); load_projects()
        showNotification("Layihə uğurla əlavə edildi", type = "message")
      }, error = function(e) { log_error("Layihə xətası: {e$message}"); showNotification("Xəta baş verdi", type = "error") })
    })

    # Layihə silmə
    observeEvent(input$delete_project_btn, {
      sel <- input$projects_table_rows_selected
      if (is.null(sel)) { showNotification("Sətir seçin", type = "warning"); return() }
      data <- projects_data()
      row <- data[sel, ]
      showModal(modalDialog(title = "Layihəni Sil",
        tags$p(paste0("'", row$name, "' layihəsini silmək istəyirsiniz?")),
        footer = tagList(modalButton("Ləğv et"), actionButton(ns("confirm_delete_project_btn"), "Sil", class = "btn-danger"))))
    })

    observeEvent(input$confirm_delete_project_btn, {
      sel <- input$projects_table_rows_selected
      row <- projects_data()[sel, ]
      tryCatch({
        dbExecute(db_pool, "UPDATE unit_projects SET is_active = FALSE WHERE id = $1", params = list(row$id))
        removeModal(); load_projects()
        showNotification("Layihə silindi", type = "message")
      }, error = function(e) { showNotification("Xəta baş verdi", type = "error") })
    })
  })
}
