# =============================================
# ARTI-2026: OCR Modulu - Server Məntiqi
# Şəkil tanıma → Emal → DB yazma
# =============================================

# ---- Cavab Vərəqəsi Server ----
ocr_answer_sheet_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    ocr_result   <- reactiveVal(NULL)
    grade_result <- reactiveVal(NULL)
    batch_data   <- reactiveVal(data.frame())

    # Şagird/sinif dropdown-ları
    observe({
      students <- db_query(db_pool,
        "SELECT s.id, s.first_name || ' ' || s.last_name || ' (' || c.grade || '-' || c.section || ')' as name
         FROM students s LEFT JOIN classes c ON s.class_id = c.id
         WHERE s.status = 'active' ORDER BY s.last_name")
      if (nrow(students) > 0) updateSelectizeInput(session, "as_student", choices = setNames(students$id, students$name), server = TRUE)

      classes <- db_query(db_pool,
        "SELECT id, grade || '-' || section as name FROM classes WHERE academic_year = $1 ORDER BY grade, section",
        params = list(get_academic_year()))
      if (nrow(classes) > 0) updateSelectInput(session, "as_class", choices = c("Seçin..." = "", setNames(classes$id, classes$name)))
    })

    # Şəkil önbaxışı
    output$answer_preview <- renderUI({
      req(input$answer_image)
      tags$div(style = "text-align:center;",
        tags$img(src = knitr::image_uri(input$answer_image$datapath),
          style = "max-width:100%; max-height:400px; border:1px solid #ddd; border-radius:8px;")
      )
    })

    # ---- TANI VƏ QİYMƏTLƏNDİR ----
    observeEvent(input$btn_scan_answer, {
      req(input$answer_image)

      # Validasiya
      img_check <- validate_image(input$answer_image$datapath)
      if (!img_check$valid) {
        notify_error(img_check$message); return()
      }

      withProgress(message = "Cavab vərəqəsi tanınır...", value = 0.2, {
        # Prompt qur
        prompt <- build_answer_sheet_prompt(
          subject = input$as_subject %||% "",
          grade = input$as_grade %||% "",
          question_count = input$as_question_count %||% 20,
          answer_key = input$as_answer_key
        )

        system_prompt <- "Sən Azərbaycan təhsil sistemində test cavab vərəqələrini oxuyan OCR mütəxəssisisən.
Azərbaycan əlifbasını (ə, ı, ö, ü, ç, ş, ğ) düzgün tanıyırsan.
Yalnız JSON formatında cavab ver."

        setProgress(0.5, detail = "AI analiz edir...")

        # AI Vision çağır
        result <- if (input$as_ai_provider == "gpt") {
          call_gpt_vision(input$answer_image$datapath, prompt, system_prompt)
        } else {
          call_claude_vision(input$answer_image$datapath, prompt, system_prompt)
        }

        if (!result$success) {
          notify_error(result$message); return()
        }

        setProgress(0.8, detail = "Nəticə emal olunur...")

        # JSON parse
        parsed <- parse_ocr_response(result$message)
        ocr_result(parsed)

        # Qiymətləndirmə (əgər cavab açarı varsa)
        if (!is.null(parsed) && !is_empty(input$as_answer_key)) {
          gr <- grade_answer_sheet(parsed, input$as_answer_key)
          grade_result(gr)
        } else {
          grade_result(NULL)
        }

        setProgress(1.0, detail = "Tamamlandı!")
      })

      notify_success("Cavab vərəqəsi uğurla tanındı!")

      # OCR tarixçəsinə yaz
      log_ocr_action(db_pool, user_data(), "answer_sheet", input$as_ai_provider, input$answer_image$name)
    })

    # ---- NƏTİCƏ GÖSTƏRMƏSİ ----
    output$answer_result_summary <- renderUI({
      gr <- grade_result()
      parsed <- ocr_result()

      if (is.null(parsed)) {
        return(tags$p(class = "text-muted", "Hələ tanınmayıb. Şəkil yükləyin və \"Tanı\" basın."))
      }

      # Əgər yalnız OCR (açar yoxdur)
      if (is.null(gr)) {
        answers <- parsed$answers
        n <- length(answers)
        ans_text <- paste(sapply(answers, function(a) sprintf("%d→%s", a$question, a$answer %||% "?")), collapse = ", ")
        return(tagList(
          tags$div(style = "background:#eaf2f8; padding:12px; border-radius:8px;",
            h4(sprintf("📋 %d cavab tanındı", n)),
            tags$p(ans_text),
            if (!is_empty(parsed$student_name)) tags$p(tags$strong("Şagird: "), parsed$student_name),
            tags$small(sprintf("Etibarlılıq: %s%%", round((parsed$confidence %||% 0) * 100)))
          ),
          tags$p(class = "text-info", "Qiymətləndirmə üçün cavab açarını daxil edin.")
        ))
      }

      # Qiymətləndirmə nəticəsi
      color <- gr$grade_color
      tagList(
        tags$div(style = sprintf("background:%s15; border-left:4px solid %s; padding:16px; border-radius:8px;", color, color),
          fluidRow(
            column(3, div(style = "text-align:center;",
              h1(style = sprintf("color:%s; margin:0;", color), sprintf("%s%%", gr$percent)),
              tags$strong(gr$grade_label)
            )),
            column(3, div(style = "text-align:center;",
              h2(style = "margin:0;", sprintf("%d/%d", gr$score, gr$total)),
              tags$small("Düzgün cavab")
            )),
            column(3, div(style = "text-align:center;",
              h2(style = "margin:0;", sprintf("%s%%", round((gr$confidence %||% 0) * 100))),
              tags$small("OCR etibarlılığı")
            )),
            column(3, div(style = "text-align:center;",
              h3(style = "margin:4px 0;", gr$student_name %||% "—"),
              tags$small("Şagird adı")
            ))
          )
        )
      )
    })

    output$answer_detail_table <- renderDT({
      gr <- grade_result()
      if (is.null(gr) || nrow(gr$details) == 0) return(NULL)

      dt <- gr$details
      names(dt) <- c("Sual", "Şagird Cavabı", "Düzgün Cavab", "Nəticə")

      datatable(dt, rownames = FALSE, options = list(pageLength = 50, dom = "t", scrollY = "300px"),
        class = "display compact") %>%
        formatStyle("Nəticə",
          backgroundColor = styleEqual(
            c("Düzgün", "Səhv", "Oxunmadı"),
            c("#d4edda", "#f8d7da", "#fff3cd")
          ))
    })

    # Qiyməti DB-yə yaz
    observeEvent(input$btn_save_grade, {
      gr <- grade_result()
      if (is.null(gr)) { notify_warning("Əvvəlcə tanıma aparın."); return() }
      if (is_empty(input$as_student)) { notify_warning("Şagird seçin."); return() }
      if (is_empty(input$as_subject)) { notify_warning("Fənn seçin."); return() }

      # subject_id al
      subj <- db_get_one(db_pool, "SELECT id FROM subjects WHERE name = $1", params = list(input$as_subject))
      if (is.null(subj)) { notify_error("Fənn tapılmadı."); return() }

      user <- user_data()
      teacher_id <- tryCatch(
        db_get_one(db_pool, "SELECT id FROM teachers WHERE user_id = $1", params = list(user$id))$id,
        error = function(e) NULL
      )

      rows <- save_answer_grade_to_db(
        db_pool, gr, input$as_student, subj$id,
        teacher_id, input$as_class, get_academic_year()
      )

      if (rows > 0) notify_success(sprintf("Qiymət (%s%%) DB-yə yazıldı!", gr$percent))
      else notify_error("Qiymət yazıla bilmədi.")
    })

    # Təmizlə
    observeEvent(input$btn_clear_answer, {
      ocr_result(NULL)
      grade_result(NULL)
    })

    # ---- TOPLU TANIMA ----
    observeEvent(input$btn_batch_scan, {
      req(input$batch_images)
      files <- input$batch_images

      if (is.null(files) || nrow(files) == 0) { notify_warning("Fayl seçin."); return() }
      if (is_empty(input$as_answer_key)) { notify_warning("Cavab açarı daxil edin."); return() }

      results <- data.frame(
        Fayl = character(), Sagird = character(), Bal = character(),
        Duzgun = character(), Neticesi = character(), stringsAsFactors = FALSE
      )

      withProgress(message = "Toplu tanıma...", max = nrow(files), {
        for (i in seq_len(nrow(files))) {
          setProgress(i, detail = sprintf("%d / %d", i, nrow(files)))

          prompt <- build_answer_sheet_prompt(
            input$as_subject, input$as_grade, input$as_question_count, input$as_answer_key)

          res <- tryCatch({
            if (input$as_ai_provider == "gpt") {
              call_gpt_vision(files$datapath[i], prompt)
            } else {
              call_claude_vision(files$datapath[i], prompt)
            }
          }, error = function(e) list(success = FALSE, message = e$message))

          if (res$success) {
            parsed <- parse_ocr_response(res$message)
            gr <- grade_answer_sheet(parsed, input$as_answer_key)
            results <- rbind(results, data.frame(
              Fayl = files$name[i],
              Sagird = gr$student_name %||% "—",
              Bal = sprintf("%s%%", gr$percent),
              Duzgun = sprintf("%d/%d", gr$score, gr$total),
              Neticesi = gr$grade_label,
              stringsAsFactors = FALSE
            ))
          } else {
            results <- rbind(results, data.frame(
              Fayl = files$name[i], Sagird = "—", Bal = "—",
              Duzgun = "—", Neticesi = "Xəta",
              stringsAsFactors = FALSE
            ))
          }
        }
      })

      batch_data(results)
      notify_success(sprintf("%d cavab vərəqəsi emal olundu!", nrow(files)))
    })

    output$batch_results_table <- renderDT({
      d <- batch_data()
      if (nrow(d) == 0) return(NULL)
      names(d) <- c("Fayl", "Şagird", "Bal", "Düzgün", "Nəticə")
      datatable(d, rownames = FALSE, options = list(dom = "t", pageLength = 50)) %>%
        formatStyle("Nəticə",
          backgroundColor = styleEqual(
            c("Əla", "Yaxşı", "Kafi", "Qeyri-kafi", "Xəta"),
            c("#d4edda", "#cce5ff", "#fff3cd", "#f8d7da", "#f5c6cb")))
    })
  })
}

# ---- Şagird Sənədi Server ----
ocr_student_doc_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    doc_result <- reactiveVal(NULL)

    output$doc_preview <- renderUI({
      req(input$student_doc_image)
      tags$div(style = "text-align:center;",
        tags$img(src = knitr::image_uri(input$student_doc_image$datapath),
          style = "max-width:100%; max-height:350px; border:1px solid #ddd; border-radius:8px;"))
    })

    # ---- SƏNƏDİ TANI ----
    observeEvent(input$btn_scan_doc, {
      req(input$student_doc_image)

      img_check <- validate_image(input$student_doc_image$datapath)
      if (!img_check$valid) { notify_error(img_check$message); return() }

      withProgress(message = "Sənəd tanınır...", value = 0.3, {
        prompt <- build_student_doc_prompt(input$doc_type)
        system_prompt <- "Sən Azərbaycan sənədlərini tanıyan OCR mütəxəssisisən.
Azərbaycan əlifbasını mükəmməl tanıyırsan: Ə, ə, I, ı, Ö, ö, Ü, ü, Ç, ç, Ş, ş, Ğ, ğ.
Yalnız JSON formatında cavab ver."

        setProgress(0.6, detail = "AI analiz edir...")

        result <- if (input$sd_ai_provider == "gpt") {
          call_gpt_vision(input$student_doc_image$datapath, prompt, system_prompt)
        } else {
          call_claude_vision(input$student_doc_image$datapath, prompt, system_prompt)
        }

        if (!result$success) { notify_error(result$message); return() }

        parsed <- parse_ocr_response(result$message)
        if (is.null(parsed)) { notify_error("OCR nəticəsi parse edilə bilmədi."); return() }

        fields <- extract_student_fields(parsed)
        doc_result(fields)

        # Form sahələrini doldur
        updateTextInput(session, "ext_first_name",  value = fields$first_name)
        updateTextInput(session, "ext_last_name",   value = fields$last_name)
        updateTextInput(session, "ext_father_name", value = fields$father_name)
        if (!is.na(fields$birth_date)) {
          updateDateInput(session, "ext_birth_date", value = fields$birth_date)
        }
        updateTextInput(session, "ext_fin_code", value = fields$fin_code)
        if (nchar(fields$gender) > 0) {
          gender_val <- if (grepl("qadın|qiz", tolower(fields$gender))) "qadın" else "kişi"
          updateSelectInput(session, "ext_gender", selected = gender_val)
        }
        updateTextInput(session, "ext_address", value = fields$address)
        updateTextAreaInput(session, "ext_notes", value = fields$notes)

        setProgress(1.0)
      })

      notify_success("Sənəd uğurla tanındı! Sahələri yoxlayın.")
      log_ocr_action(db_pool, user_data(), "student_doc", input$sd_ai_provider, input$student_doc_image$name)
    })

    output$doc_confidence_badge <- renderUI({
      f <- doc_result()
      if (is.null(f)) return(NULL)
      conf <- round((f$confidence %||% 0) * 100)
      color <- if (conf >= 85) "#27ae60" else if (conf >= 60) "#f39c12" else "#e74c3c"
      tags$span(class = "badge", style = sprintf("background:%s; font-size:13px;", color),
        sprintf("Etibarlılıq: %s%%", conf))
    })

    # Qeydiyyat formasına köçür (session storage ilə)
    observeEvent(input$btn_apply_to_register, {
      f <- doc_result()
      if (is.null(f)) { notify_warning("Əvvəlcə sənəd tanıyın."); return() }

      # Session-a yaz — student_register modulu oxuya bilsin
      session$userData$ocr_student_data <- list(
        first_name  = input$ext_first_name,
        last_name   = input$ext_last_name,
        father_name = input$ext_father_name,
        birth_date  = input$ext_birth_date,
        fin_code    = input$ext_fin_code,
        gender      = input$ext_gender,
        address     = input$ext_address
      )

      notify_success("Məlumatlar qeydiyyat formasına köçürüldü. 'Şagirdlər → Qeydiyyat' bölməsinə keçin.")
    })

    # Birbaşa DB-yə yaz
    observeEvent(input$btn_save_student_direct, {
      if (is_empty(input$ext_first_name) || is_empty(input$ext_last_name)) {
        notify_warning("Ad və soyad məcburidir."); return()
      }

      tryCatch({
        db_execute(db_pool,
          "INSERT INTO students (first_name, last_name, father_name, birth_date, gender, fin, address, status)
           VALUES ($1, $2, $3, $4, $5, $6, $7, 'active')",
          params = list(
            input$ext_first_name, input$ext_last_name, input$ext_father_name,
            input$ext_birth_date, input$ext_gender, input$ext_fin_code, input$ext_address
          ))
        notify_success("Şagird uğurla əlavə edildi!")
      }, error = function(e) {
        notify_error(sprintf("Xəta: %s", e$message))
      })
    })
  })
}

# ---- Müəllim Sertifikatı Server ----
ocr_certificate_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    cert_result  <- reactiveVal(NULL)
    batch_certs  <- reactiveVal(data.frame())

    # Müəllim dropdown
    observe({
      teachers <- db_query(db_pool,
        "SELECT id, first_name || ' ' || last_name as name FROM teachers WHERE status = 'active' ORDER BY last_name")
      if (nrow(teachers) > 0) updateSelectizeInput(session, "cert_teacher", choices = setNames(teachers$id, teachers$name), server = TRUE)
    })

    output$cert_preview <- renderUI({
      req(input$cert_image)
      tags$div(style = "text-align:center;",
        tags$img(src = knitr::image_uri(input$cert_image$datapath),
          style = "max-width:100%; max-height:350px; border:1px solid #ddd; border-radius:8px;"))
    })

    # ---- SERTİFİKATI TANI ----
    observeEvent(input$btn_scan_cert, {
      req(input$cert_image)

      img_check <- validate_image(input$cert_image$datapath)
      if (!img_check$valid) { notify_error(img_check$message); return() }

      withProgress(message = "Sertifikat tanınır...", value = 0.3, {
        prompt <- build_certificate_prompt()
        system_prompt <- "Sən Azərbaycan dilində sertifikat və diplomları tanıyan OCR mütəxəssisisən.
Azərbaycan əlifbasını mükəmməl tanıyırsan. Yalnız JSON formatında cavab ver."

        setProgress(0.6, detail = "AI analiz edir...")

        result <- if (input$cert_ai_provider == "gpt") {
          call_gpt_vision(input$cert_image$datapath, prompt, system_prompt)
        } else {
          call_claude_vision(input$cert_image$datapath, prompt, system_prompt)
        }

        if (!result$success) { notify_error(result$message); return() }

        parsed <- parse_ocr_response(result$message)
        if (is.null(parsed)) { notify_error("Sertifikat parse edilə bilmədi."); return() }

        fields <- extract_certificate_fields(parsed)
        cert_result(fields)

        # Form sahələrini doldur
        updateTextInput(session, "cert_title",    value = fields$title)
        updateTextInput(session, "cert_provider",  value = fields$provider)
        updateSelectInput(session, "cert_type",    selected = fields$cert_type)
        if (!is.na(fields$start_date)) updateDateInput(session, "cert_start", value = fields$start_date)
        if (!is.na(fields$end_date))   updateDateInput(session, "cert_end",   value = fields$end_date)
        updateNumericInput(session, "cert_hours",   value = fields$hours)
        updateTextInput(session, "cert_number",    value = fields$cert_number)

        setProgress(1.0)
      })

      notify_success("Sertifikat uğurla tanındı!")
      log_ocr_action(db_pool, user_data(), "certificate", input$cert_ai_provider, input$cert_image$name)
    })

    output$cert_confidence_badge <- renderUI({
      f <- cert_result()
      if (is.null(f)) return(NULL)
      conf <- round((f$confidence %||% 0) * 100)
      color <- if (conf >= 85) "#27ae60" else if (conf >= 60) "#f39c12" else "#e74c3c"
      tags$span(class = "badge", style = sprintf("background:%s; font-size:13px;", color),
        sprintf("Etibarlılıq: %s%%", conf))
    })

    # DB-yə yaz
    observeEvent(input$btn_save_cert, {
      if (is_empty(input$cert_teacher)) { notify_warning("Müəllim seçin."); return() }
      if (is_empty(input$cert_title))   { notify_warning("Sertifikat adı daxil edin."); return() }

      fields <- list(
        title       = input$cert_title,
        provider    = input$cert_provider,
        cert_type   = input$cert_type,
        issue_date  = input$cert_start %||% Sys.Date(),
        start_date  = input$cert_start %||% Sys.Date(),
        end_date    = input$cert_end %||% input$cert_start %||% Sys.Date(),
        hours       = input$cert_hours %||% 0,
        cert_number = input$cert_number %||% ""
      )

      rows <- save_certificate_to_db(db_pool, fields, input$cert_teacher)
      if (rows > 0) notify_success("Sertifikat peşəkar inkişaf qeydinə əlavə edildi!")
      else notify_error("Sertifikat yazıla bilmədi.")
    })

    # Toplu sertifikat
    observeEvent(input$btn_batch_cert, {
      req(input$batch_certs)
      files <- input$batch_certs

      results <- data.frame(
        Fayl = character(), Ad = character(), Muellim = character(),
        Tarix = character(), Saat = character(), stringsAsFactors = FALSE
      )

      withProgress(message = "Toplu sertifikat tanıma...", max = nrow(files), {
        for (i in seq_len(nrow(files))) {
          setProgress(i, detail = sprintf("%d / %d", i, nrow(files)))

          res <- tryCatch({
            if (input$cert_ai_provider == "gpt") {
              call_gpt_vision(files$datapath[i], build_certificate_prompt())
            } else {
              call_claude_vision(files$datapath[i], build_certificate_prompt())
            }
          }, error = function(e) list(success = FALSE))

          if (isTRUE(res$success)) {
            parsed <- parse_ocr_response(res$message)
            f <- extract_certificate_fields(parsed)
            results <- rbind(results, data.frame(
              Fayl = files$name[i], Ad = f$title %||% "—",
              Muellim = f$teacher_name %||% "—",
              Tarix = if (!is.na(f$issue_date)) format(f$issue_date, "%d.%m.%Y") else "—",
              Saat = f$hours %||% 0, stringsAsFactors = FALSE))
          } else {
            results <- rbind(results, data.frame(
              Fayl = files$name[i], Ad = "Xəta", Muellim = "—", Tarix = "—", Saat = 0,
              stringsAsFactors = FALSE))
          }
        }
      })

      batch_certs(results)
      notify_success(sprintf("%d sertifikat emal olundu!", nrow(files)))
    })

    output$batch_cert_table <- renderDT({
      d <- batch_certs()
      if (nrow(d) == 0) return(NULL)
      names(d) <- c("Fayl", "Sertifikat Adı", "Müəllim", "Tarix", "Saat")
      datatable(d, rownames = FALSE, options = list(dom = "t", pageLength = 50))
    })
  })
}

# ---- Tarixçə Server ----
ocr_history_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {

    history_data <- reactiveVal(data.frame())

    observeEvent(input$btn_hist_load, {
      type_filter <- if (!is_empty(input$hist_type)) "AND ocr_type = $3" else ""
      provider_filter <- if (!is_empty(input$hist_provider)) {
        if (is_empty(input$hist_type)) "AND provider = $3" else "AND provider = $4"
      } else ""

      params <- list(input$hist_dates[1], input$hist_dates[2])
      if (!is_empty(input$hist_type)) params <- c(params, list(input$hist_type))
      if (!is_empty(input$hist_provider)) params <- c(params, list(input$hist_provider))

      query <- sprintf(
        "SELECT created_at, ocr_type, provider, file_name, created_by
         FROM ocr_history
         WHERE created_at::date BETWEEN $1 AND $2 %s %s
         ORDER BY created_at DESC LIMIT 200",
        type_filter, provider_filter
      )

      result <- db_query(db_pool, query, params = params)
      history_data(result)
    })

    output$history_table <- renderDT({
      d <- history_data()
      if (nrow(d) == 0) return(datatable(data.frame(Mesaj = "Tarixçə boşdur"), options = list(dom = "t")))

      type_labels <- c(answer_sheet = "Cavab Vərəqəsi", student_doc = "Şagird Sənədi", certificate = "Sertifikat")
      d$ocr_type <- sapply(d$ocr_type, function(t) type_labels[t] %||% t)
      d$created_at <- format(d$created_at, "%d.%m.%Y %H:%M")
      names(d) <- c("Tarix", "Növ", "AI", "Fayl", "İstifadəçi")
      datatable(d, rownames = FALSE, options = default_dt_options(25))
    })
  })
}

# =============================================
# YARDIMÇI: OCR əməliyyatını logla
# =============================================
log_ocr_action <- function(db_pool, user, ocr_type, provider, file_name) {
  tryCatch({
    # ocr_history cədvəli mövcuddursa yaz
    db_execute(db_pool,
      "INSERT INTO ocr_history (ocr_type, provider, file_name, created_by, created_at)
       VALUES ($1, $2, $3, $4, NOW())",
      params = list(ocr_type, provider, file_name, user$id %||% "system"))
  }, error = function(e) {
    # Cədvəl mövcud deyilsə xəta critical deyil
    logger::log_debug("OCR log xətası (cədvəl olmaya bilər): {e$message}")
  })
}
