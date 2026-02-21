# =============================================
# ARTI-2026: AI Alətləri — Server Məntiqi
# Gün 7: Sual Generatoru Server + Gün 10: Dərs Planı Server
# =============================================

# =============================================
# BÖLÜM 1: SUAL GENERATORU SERVER (Gün 7)
# =============================================
question_generator_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # === Reactive dəyərlər ===
    generated_questions <- reactiveVal(NULL)
    generation_meta     <- reactiveVal(NULL)

    # === Statistikalar ===
    output$stat_total_generated <- renderValueBox({
      total <- tryCatch({
        stats <- get_ai_generation_stats(db_pool, "question_generation")
        val <- as.numeric(stats$total_requests %||% 0)
        if (is.null(val) || is.na(val)) 0 else val
      }, error = function(e) 0)
      valueBox(value = total, subtitle = "Ümumi Sorğu", icon = icon("robot"), color = "blue")
    })

    output$stat_success_rate <- renderValueBox({
      rate <- tryCatch({
        stats <- get_ai_generation_stats(db_pool, "question_generation")
        total <- as.numeric(stats$total_requests %||% 0)
        success <- as.numeric(stats$success_count %||% 0)
        if (is.null(total) || is.na(total)) total <- 0
        if (is.null(success) || is.na(success)) success <- 0
        if (total > 0) round(success / total * 100) else 0
      }, error = function(e) 0)
      valueBox(value = paste0(rate, "%"), subtitle = "Uğur Faizi", icon = icon("check-circle"), color = "green")
    })

    output$stat_total_tokens <- renderValueBox({
      label <- tryCatch({
        stats <- get_ai_generation_stats(db_pool, "question_generation")
        tokens <- as.numeric(stats$total_tokens %||% 0)
        if (is.null(tokens) || is.na(tokens)) tokens <- 0
        if (tokens > 1e6) paste0(round(tokens/1e6, 1), "M")
        else if (tokens > 1e3) paste0(round(tokens/1e3, 1), "K")
        else tokens
      }, error = function(e) 0)
      valueBox(value = label, subtitle = "Token İstifadəsi", icon = icon("coins"), color = "yellow")
    })

    output$stat_avg_time <- renderValueBox({
      avg_s <- tryCatch({
        stats <- get_ai_generation_stats(db_pool, "question_generation")
        avg_ms <- as.numeric(stats$avg_response_ms %||% 0)
        if (is.null(avg_ms) || is.na(avg_ms)) avg_ms <- 0
        round(avg_ms / 1000, 1)
      }, error = function(e) 0)
      valueBox(value = paste0(avg_s, "s"), subtitle = "Orta Cavab Vaxtı", icon = icon("clock"), color = "purple")
    })

    # === Has results flag ===
    output$qg_has_results <- reactive({ !is.null(generated_questions()) })
    outputOptions(output, "qg_has_results", suspendWhenHidden = FALSE)

    # === Generasiya ===
    observeEvent(input$btn_qg_generate, {
      tryCatch({
      req(input$qg_subject)
      req(input$qg_grade)
      req(input$qg_topic)
      if (is.null(input$qg_count)) return()

      bloom_text <- if (input$qg_bloom == "mixed") {
        "müxtəlif Bloom taksonomiyası səviyyələrində"
      } else {
        paste0(input$qg_bloom, " Bloom səviyyəsində")
      }

      diff_text <- if (input$qg_difficulty == "mixed") {
        "qarışıq çətinlik səviyyəsində"
      } else {
        paste0(input$qg_difficulty, " çətinlikdə")
      }

      dok_text <- if (input$qg_dok == "mixed") "" else paste0("\nDOK səviyyəsi: ", input$qg_dok)

      type_text <- tryCatch(
        names(QUESTION_TYPES)[QUESTION_TYPES == input$qg_type],
        error = function(e) "çoxseçimli"
      )
      if (is.null(type_text) || length(type_text) == 0) type_text <- "çoxseçimli"

      context_text <- if (!is_empty(input$qg_context)) paste0("\n\nƏlavə təlimat: ", input$qg_context) else ""

      std_text <- if (!is_empty(input$qg_standard)) paste0("\nStandart kodu: ", input$qg_standard) else ""

      template <- tryCatch(
        load_prompt_template("question_generation"),
        error = function(e) NULL
      )

      if (!is.null(template)) {
        prompt <- tryCatch(
          sprintf(template,
                  input$qg_subject, input$qg_grade, input$qg_topic,
                  diff_text, bloom_text, input$qg_count),
          error = function(e) NULL
        )
        if (is.null(prompt)) {
          prompt <- paste0(
            "Azərbaycan dilində ", input$qg_subject, " fənni, ",
            input$qg_grade, "-ci sinif, \"", input$qg_topic, "\" mövzusu üzrə ",
            input$qg_count, " ədəd sual yarat."
          )
        } else {
          prompt <- paste0(prompt, "\n\nSual tipi: ", type_text,
                           "\nBloom: ", bloom_text, dok_text, std_text,
                           if (isTRUE(input$qg_include_explanation)) "\nHər sual üçün təfsilatlı izah yaz." else "",
                           if (isTRUE(input$qg_include_time_estimate)) "\nHər sual üçün təxmini vaxt (saniyə) göstər." else "",
                           context_text)
        }
      } else {
        prompt <- paste0(
          "Azərbaycan dilində ", input$qg_subject, " fənni, ",
          input$qg_grade, "-ci sinif, \"", input$qg_topic, "\" mövzusu üzrə ",
          input$qg_count, " ədəd ", type_text, " tipli sual yarat.\n",
          "Çətinlik: ", diff_text, "\n",
          "Bloom: ", bloom_text, dok_text, std_text, "\n",
          "Hər sual üçün: question_text, option_a-d, correct_answer, explanation, bloom_level, difficulty, dok_level.\n",
          "Cavabı YALNIZ JSON array formatında qaytar.", context_text
        )
      }

      system_prompt <- paste0(
        "Sən Azərbaycan təhsil sistemi üçün sual hazırlayan ekspert müəllimsən. ",
        "Sualları Azərbaycan dilində, Bloom taksonomiyasına və DOK səviyyələrinə uyğun hazırla. ",
        "Çaşdırıcı variantlar məntiqi və inandırıcı olmalıdır. ",
        "Cavabı YALNIZ düzgün JSON array formatında qaytar, başqa heç nə yazma."
      )

      uid <- tryCatch(user_data()$id, error = function(e) NULL)

      withProgress(message = "AI sualları yaradır...", value = 0.3, {

        result <- tryCatch({
          if (input$qg_provider == "auto") {
            route_ai_request(
              prompt = prompt,
              task_type = "question_generation",
              system_prompt = system_prompt,
              temperature = input$qg_temperature,
              save_to_db = TRUE,
              db_pool = db_pool,
              user_id = uid
            )
          } else {
            if (input$qg_provider == "claude") {
              call_claude_api(prompt, system_prompt,
                              max_tokens = 4096, temperature = input$qg_temperature)
            } else {
              call_gpt_api(prompt, system_prompt,
                           max_tokens = 4096, temperature = input$qg_temperature)
            }
          }
        }, error = function(e) {
          list(success = FALSE, message = e$message, content = e$message)
        })

        setProgress(value = 0.7, message = "Cavab emal edilir...")

        if (!isTRUE(result$success)) {
          notify_error(paste("AI xətası:", result$message %||% "Naməlum xəta"))
          return()
        }

        questions_raw <- tryCatch(
          extract_json_from_response(result$content %||% result$message),
          error = function(e) NULL
        )

        if (is.null(questions_raw)) {
          notify_error("AI cavabı JSON formatında emal edilə bilmədi. Yenidən cəhd edin.")
          return()
        }

        df <- tryCatch(questions_to_dataframe(questions_raw), error = function(e) NULL)

        if (is.null(df) || nrow(df) == 0) {
          notify_error("AI heç bir sual yarada bilmədi.")
          return()
        }

        generated_questions(df)
        generation_meta(list(
          provider = result$provider %||% result$routed_provider %||% input$qg_provider,
          model = result$model %||% "",
          tokens = result$usage$total_tokens %||%
                   ((result$usage$input_tokens %||% 0) + (result$usage$output_tokens %||% 0)),
          time = result$response_time_sec %||% 0,
          subject = input$qg_subject,
          grade = input$qg_grade,
          topic = input$qg_topic
        ))

        setProgress(value = 1, message = "Tamamlandı!")
        notify_success(paste0(nrow(df), " sual uğurla yaradıldı!"))
      })
      }, error = function(e) {
        log_error(paste("Sual generasiyası xətası:", e$message))
        showNotification(paste("Xəta baş verdi:", e$message), type = "error", duration = 10)
      })
    })

    # === Status mesajı ===
    output$qg_status_message <- renderUI({
      meta <- generation_meta()
      if (is.null(meta)) return(NULL)

      tags$div(
        class = "alert alert-info",
        style = "display:flex; justify-content:space-between; align-items:center;",
        tags$span(
          icon("info-circle"),
          paste0(" ", nrow(generated_questions()), " sual yaradıldı | "),
          paste0("Provayder: ", toupper(meta$provider)),
          if (meta$tokens > 0) paste0(" | Token: ", meta$tokens) else "",
          if (meta$time > 0) paste0(" | Vaxt: ", meta$time, "s") else ""
        ),
        tags$small(class = "text-muted", format(Sys.time(), "%H:%M:%S"))
      )
    })

    # === Sualları göstər ===
    output$qg_results_ui <- renderUI({
      df <- generated_questions()
      if (is.null(df)) {
        return(tags$div(
          style = "text-align:center; padding:60px 20px; color:#aaa;",
          icon("robot", style = "font-size:48px;"),
          tags$h4("Hələ sual yaradılmayıb"),
          tags$p("Sol paneldə parametrləri doldurun və \"Sualları Yarat\" düyməsinə basın")
        ))
      }
      questions_to_html_cards(df)
    })

    # === Sual Bankına Saxla ===
    observeEvent(input$btn_qg_save_bank, {
      req(generated_questions())
      df <- generated_questions()

      choices <- setNames(seq_len(nrow(df)),
        paste0("Sual ", seq_len(nrow(df)), ": ", substr(df$question_text, 1, 50), "..."))

      showModal(modalDialog(
        title = tagList(icon("database"), " Sual Bankına Saxla"),
        size = "m",
        checkboxGroupInput(ns("qg_save_select"), "Saxlanılacaq sualları seçin:",
                           choices = choices, selected = seq_len(nrow(df))),
        footer = tagList(
          actionButton(ns("btn_qg_confirm_save"), "Saxla", icon = icon("save"), class = "btn-success"),
          modalButton("Ləğv et")
        )
      ))
    })

    observeEvent(input$btn_qg_confirm_save, {
      req(input$qg_save_select, generated_questions())
      df <- generated_questions()
      meta <- generation_meta()
      selected_idx <- as.integer(input$qg_save_select)
      saved <- 0

      for (idx in selected_idx) {
        q <- df[idx, ]
        result <- tryCatch(
          db_execute(db_pool,
            "INSERT INTO items (question_text, option_a, option_b, option_c, option_d, option_e,
             correct_answer, subject_id, bloom_level, difficulty, grade_level, is_active, created_by, created_at)
             VALUES ($1, $2, $3, $4, $5, $6, $7, (SELECT id FROM subjects WHERE name = $8),
             $9, $10, $11, TRUE, $12, NOW())",
            params = list(
              q$question_text,
              q$option_a %||% "", q$option_b %||% "",
              q$option_c %||% "", q$option_d %||% "", q$option_e %||% "",
              q$correct_answer,
              meta$subject %||% input$qg_subject,
              q$bloom_level %||% "understand", q$difficulty %||% "orta",
              as.integer(meta$grade %||% input$qg_grade),
              user_data()$id
            )),
          error = function(e) { log_error("Sual saxlama xətası: {e$message}"); 0 }
        )
        if (result > 0) saved <- saved + 1
      }

      removeModal()
      if (saved > 0) {
        notify_success(paste0(saved, "/", length(selected_idx), " sual bankına əlavə edildi!"))
      } else {
        notify_error("Suallar saxlanarkən xəta baş verdi.")
      }
    })

    # === TXT Export ===
    output$btn_qg_export_txt <- downloadHandler(
      filename = function() {
        paste0("suallar_", input$qg_subject, "_", input$qg_grade, "sinif_",
               format(Sys.Date(), "%Y%m%d"), ".txt")
      },
      content = function(file) {
        df <- generated_questions()
        if (!is.null(df)) {
          header <- paste0("ARTI-2026 AI Sual Generatoru\n",
                           "Fənn: ", input$qg_subject, "\n",
                           "Sinif: ", input$qg_grade, "-ci sinif\n",
                           "Mövzu: ", input$qg_topic, "\n",
                           "Tarix: ", format(Sys.Date(), "%d.%m.%Y"), "\n",
                           paste(rep("=", 50), collapse = ""), "\n\n")
          writeLines(paste0(header, questions_to_text(df)), file)
        }
      }
    )

    # === Word Export ===
    output$btn_qg_export_word <- downloadHandler(
      filename = function() {
        paste0("suallar_", input$qg_subject, "_", input$qg_grade, "sinif_",
               format(Sys.Date(), "%Y%m%d"), ".docx")
      },
      content = function(file) {
        df <- generated_questions()
        if (!is.null(df) && requireNamespace("officer", quietly = TRUE)) {
          doc <- officer::read_docx()

          doc <- officer::body_add_par(doc, "ARTI-2026 AI Sual Generatoru", style = "heading 1")
          doc <- officer::body_add_par(doc, paste0("Fənn: ", input$qg_subject,
            " | Sinif: ", input$qg_grade, "-ci sinif | Mövzu: ", input$qg_topic))
          doc <- officer::body_add_par(doc, paste0("Tarix: ", format(Sys.Date(), "%d.%m.%Y")))
          doc <- officer::body_add_par(doc, "")

          for (i in seq_len(nrow(df))) {
            q <- df[i, ]
            doc <- officer::body_add_par(doc, paste0("Sual ", i, ". ", q$question_text), style = "heading 2")
            doc <- officer::body_add_par(doc, paste0("A) ", q$option_a))
            doc <- officer::body_add_par(doc, paste0("B) ", q$option_b))
            if (!is.null(q$option_c) && nchar(q$option_c) > 0)
              doc <- officer::body_add_par(doc, paste0("C) ", q$option_c))
            if (!is.null(q$option_d) && nchar(q$option_d) > 0)
              doc <- officer::body_add_par(doc, paste0("D) ", q$option_d))
            doc <- officer::body_add_par(doc, paste0("Düzgün cavab: ", q$correct_answer))
            if (!is.null(q$explanation) && nchar(q$explanation) > 0)
              doc <- officer::body_add_par(doc, paste0("İzah: ", q$explanation))
            if (!is.null(q$bloom_level) && nchar(q$bloom_level) > 0)
              doc <- officer::body_add_par(doc, paste0("Bloom: ", q$bloom_level,
                " | Çətinlik: ", q$difficulty))
            doc <- officer::body_add_par(doc, "")
          }

          print(doc, target = file)
        } else {
          writeLines(questions_to_text(generated_questions()), file)
        }
      }
    )

    # === Yenidən yarat ===
    observeEvent(input$btn_qg_regenerate, {
      generated_questions(NULL)
      generation_meta(NULL)
      shinyjs::click("btn_qg_generate")
    })

    # === Təmizlə ===
    observeEvent(input$btn_qg_clear, {
      generated_questions(NULL)
      generation_meta(NULL)
    })

    # === Tarixçə ===
    output$qg_history_table <- renderDT({
      data <- tryCatch(
        db_query(db_pool,
          "SELECT provider, model, response_time_ms, input_tokens + output_tokens as total_tokens,
                  estimated_cost, status, created_at
           FROM ai_responses
           WHERE task_type = 'question_generation'
           ORDER BY created_at DESC LIMIT 50"),
        error = function(e) data.frame()
      )

      if (nrow(data) == 0) return(datatable(data.frame("Tarixçə boşdur" = character(0))))

      data$created_at <- format_date_az(data$created_at)
      data$response_time_ms <- paste0(round(data$response_time_ms / 1000, 1), "s")
      data$estimated_cost <- paste0("$", round(data$estimated_cost, 4))

      names(data) <- c("Provayder", "Model", "Vaxt", "Token", "Xərc", "Status", "Tarix")
      datatable(data, selection = "none", options = default_dt_options(10))
    })
  })
}

# =============================================
# BÖLÜM 2: DƏRS PLANI GENERATORU SERVER (Gün 10)
# =============================================
lesson_plan_server <- function(id, db_pool, user_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # === Reactive dəyərlər ===
    generated_plan  <- reactiveVal(NULL)
    plan_raw_text   <- reactiveVal(NULL)
    plan_meta       <- reactiveVal(NULL)

    # === Statistikalar ===
    output$lp_stat_total <- renderValueBox({
      total <- tryCatch({
        stats <- get_ai_generation_stats(db_pool, "lesson_plan")
        val <- as.numeric(stats$total_requests %||% 0)
        if (is.null(val) || is.na(val)) 0 else val
      }, error = function(e) 0)
      valueBox(value = total, subtitle = "Ümumi Plan",
               icon = icon("chalkboard"), color = "blue")
    })

    output$lp_stat_subjects <- renderValueBox({
      count <- tryCatch({
        r <- db_get_one(db_pool,
          "SELECT COUNT(DISTINCT prompt_text) as cnt FROM ai_responses
           WHERE task_type = 'lesson_plan' AND status = 'success'")
        val <- as.numeric(r$cnt %||% 0)
        if (is.null(val) || is.na(val)) 0 else val
      }, error = function(e) 0)
      valueBox(value = count, subtitle = "Unikal Mövzu", icon = icon("book"), color = "green")
    })

    output$lp_stat_tokens <- renderValueBox({
      label <- tryCatch({
        stats <- get_ai_generation_stats(db_pool, "lesson_plan")
        tokens <- as.numeric(stats$total_tokens %||% 0)
        if (is.null(tokens) || is.na(tokens)) tokens <- 0
        if (tokens > 1e6) paste0(round(tokens/1e6, 1), "M")
        else if (tokens > 1e3) paste0(round(tokens/1e3, 1), "K")
        else tokens
      }, error = function(e) 0)
      valueBox(value = label, subtitle = "Token", icon = icon("coins"), color = "yellow")
    })

    output$lp_stat_cost <- renderValueBox({
      cost_val <- tryCatch({
        stats <- get_ai_generation_stats(db_pool, "lesson_plan")
        val <- as.numeric(stats$total_cost %||% 0)
        if (is.null(val) || is.na(val)) 0 else round(val, 2)
      }, error = function(e) 0)
      valueBox(value = paste0("$", cost_val), subtitle = "Ümumi Xərc",
               icon = icon("dollar-sign"), color = "purple")
    })

    # === Has results flag ===
    output$lp_has_results <- reactive({ !is.null(generated_plan()) })
    outputOptions(output, "lp_has_results", suspendWhenHidden = FALSE)

    # === Generasiya ===
    observeEvent(input$btn_lp_generate, {
      req(input$lp_topic)

      sections <- c()
      if (isTRUE(input$lp_inc_outcomes))        sections <- c(sections, "öyrənmə nəticələri")
      if (isTRUE(input$lp_inc_stages))          sections <- c(sections, "dərs mərhələləri (müəllim/şagird fəaliyyətləri ilə)")
      if (isTRUE(input$lp_inc_differentiation)) sections <- c(sections, "fərqləndirmə strategiyaları")
      if (isTRUE(input$lp_inc_assessment))      sections <- c(sections, "qiymətləndirmə tapşırıqları")
      if (isTRUE(input$lp_inc_homework))        sections <- c(sections, "ev tapşırığı")
      if (isTRUE(input$lp_inc_materials))       sections <- c(sections, "lazım olan materiallar")
      if (isTRUE(input$lp_inc_ict))             sections <- c(sections, "İKT inteqrasiyası")

      sections_text <- paste(sections, collapse = ", ")

      method_name <- names(TEACHING_METHODS)[TEACHING_METHODS == input$lp_method]

      template <- tryCatch(
        load_prompt_template("lesson_plan"),
        error = function(e) NULL
      )

      objectives_text <- if (!is_empty(input$lp_objectives)) input$lp_objectives else "AI tərəfindən müəyyən edilsin"

      if (!is.null(template)) {
        prompt <- sprintf(template,
                          input$lp_subject, input$lp_grade, input$lp_topic,
                          input$lp_duration, objectives_text, input$lp_student_count)
        prompt <- paste0(prompt, "\n\nTədris metodu: ", method_name,
                         "\nSinif səviyyəsi: ", input$lp_level,
                         "\nDaxil edilməli bölmələr: ", sections_text,
                         if (!is_empty(input$lp_context)) paste0("\n\nƏlavə kontekst: ", input$lp_context) else "")
      } else {
        prompt <- paste0(
          "Azərbaycan dilində ", input$lp_subject, " fənni, ",
          input$lp_grade, "-ci sinif, \"", input$lp_topic, "\" mövzusu üzrə ",
          input$lp_duration, " dəqiqəlik dərs planı hazırla.\n",
          "Şagird sayı: ", input$lp_student_count, "\n",
          "Tədris metodu: ", method_name, "\n",
          "Məqsədlər: ", objectives_text, "\n",
          "Daxil et: ", sections_text, "\n",
          "Cavabı JSON formatında qaytar: title, subject, grade, topic, duration, method, ",
          "learning_outcomes (array), stages (array of {name, duration, teacher_activity, student_activity, ",
          "resources, assessment}), differentiation ({advanced, struggling, ell}), ",
          "homework, materials (array), notes",
          if (!is_empty(input$lp_context)) paste0("\n\nƏlavə: ", input$lp_context) else ""
        )
      }

      system_prompt <- paste0(
        "Sən təcrübəli Azərbaycan müəllimisən və dərs planları hazırlayırsan. ",
        "Dərs planını Azərbaycan Respublikası kurikulum standartlarına uyğun hazırla. ",
        "Müasir pedaqoji yanaşmalardan istifadə et. ",
        "Cavabı YALNIZ düzgün JSON formatında qaytar, başqa heç nə yazma."
      )

      withProgress(message = "AI dərs planı hazırlayır...", value = 0.3, {

        result <- tryCatch({
          if (input$lp_provider == "auto") {
            route_ai_request(
              prompt = prompt,
              task_type = "lesson_plan",
              system_prompt = system_prompt,
              temperature = input$lp_temperature,
              max_tokens = 6144,
              save_to_db = TRUE,
              db_pool = db_pool,
              user_id = user_data()$id
            )
          } else {
            if (input$lp_provider == "claude") {
              call_claude_api(prompt, system_prompt, max_tokens = 6144, temperature = input$lp_temperature)
            } else {
              call_gpt_api(prompt, system_prompt, max_tokens = 6144, temperature = input$lp_temperature)
            }
          }
        }, error = function(e) {
          list(success = FALSE, message = e$message, content = e$message)
        })

        setProgress(value = 0.7, message = "Cavab emal edilir...")

        if (!isTRUE(result$success)) {
          notify_error(paste("AI xətası:", result$message %||% "Naməlum xəta"))
          return()
        }

        raw_text <- result$content %||% result$message
        plan_raw_text(raw_text)

        plan_data <- tryCatch(
          extract_json_from_response(raw_text),
          error = function(e) NULL
        )

        if (is.null(plan_data)) {
          generated_plan(list(
            title = paste0(input$lp_subject, " — ", input$lp_topic),
            subject = input$lp_subject,
            grade = input$lp_grade,
            topic = input$lp_topic,
            duration = input$lp_duration,
            raw_text = raw_text
          ))
        } else {
          plan <- list(
            title    = plan_data$lesson_title %||% plan_data$title %||% paste0(input$lp_subject, " — ", input$lp_topic),
            subject  = plan_data$subject %||% input$lp_subject,
            grade    = plan_data$grade %||% input$lp_grade,
            topic    = plan_data$topic %||% input$lp_topic,
            duration = plan_data$duration_minutes %||% plan_data$duration %||% input$lp_duration,
            method   = plan_data$method %||% method_name,
            learning_outcomes = plan_data$learning_objectives %||% plan_data$learning_outcomes %||% list(),
            stages = lapply(plan_data$lesson_phases %||% plan_data$stages %||% list(), function(s) {
              list(
                name = s$phase %||% s$name %||% s$stage_name %||% "",
                duration = s$duration_minutes %||% s$duration %||% "",
                teacher_activity = s$teacher_actions %||% s$teacher_activity %||% "",
                student_activity = s$student_actions %||% s$student_activity %||% "",
                resources = s$resources %||% s$materials %||% NULL,
                assessment = s$assessment %||% NULL,
                description = if (!is.null(s$activities)) paste(unlist(s$activities), collapse = "; ") else NULL
              )
            }),
            differentiation = plan_data$differentiation %||% NULL,
            homework = plan_data$homework %||% NULL,
            materials = plan_data$materials %||% plan_data$prerequisites %||% list(),
            notes = plan_data$reflection_questions %||% plan_data$notes %||% NULL
          )
          if (is.list(plan$notes)) plan$notes <- paste(unlist(plan$notes), collapse = "\n")

          generated_plan(plan)
        }

        plan_meta(list(
          provider = result$provider %||% result$routed_provider %||% input$lp_provider,
          model = result$model %||% "",
          tokens = result$usage$total_tokens %||%
                   ((result$usage$input_tokens %||% 0) + (result$usage$output_tokens %||% 0)),
          time = result$response_time_sec %||% 0
        ))

        setProgress(value = 1, message = "Tamamlandı!")
        notify_success("Dərs planı uğurla yaradıldı!")
      })
    })

    # === Status mesajı ===
    output$lp_status_message <- renderUI({
      meta <- plan_meta()
      if (is.null(meta)) return(NULL)
      tags$div(
        class = "alert alert-info",
        style = "display:flex; justify-content:space-between; align-items:center;",
        tags$span(
          icon("info-circle"),
          paste0(" Dərs planı hazırlandı | Provayder: ", toupper(meta$provider)),
          if (meta$tokens > 0) paste0(" | Token: ", meta$tokens) else "",
          if (meta$time > 0) paste0(" | Vaxt: ", meta$time, "s") else ""
        ),
        tags$small(class = "text-muted", format(Sys.time(), "%H:%M:%S"))
      )
    })

    # === Dərs Planını göstər ===
    output$lp_results_ui <- renderUI({
      plan <- generated_plan()
      if (is.null(plan)) {
        return(tags$div(
          style = "text-align:center; padding:60px 20px; color:#aaa;",
          icon("chalkboard", style = "font-size:48px;"),
          tags$h4("Hələ dərs planı yaradılmayıb"),
          tags$p("Sol paneldə parametrləri doldurun və \"Dərs Planı Yarat\" düyməsinə basın")
        ))
      }

      if (!is.null(plan$raw_text)) {
        return(tags$div(
          style = "background:#f8f9fa; padding:15px; border-radius:8px; white-space:pre-wrap;",
          HTML(markdown_to_html(plan$raw_text))
        ))
      }

      lesson_plan_to_html(plan)
    })

    # === TXT Export ===
    output$btn_lp_export_txt <- downloadHandler(
      filename = function() {
        paste0("ders_plani_", input$lp_subject, "_", input$lp_grade, "sinif_",
               format(Sys.Date(), "%Y%m%d"), ".txt")
      },
      content = function(file) {
        plan <- generated_plan()
        if (!is.null(plan)) {
          header <- paste0("ARTI-2026 AI Dərs Planı Generatoru\n",
                           "Tarix: ", format(Sys.Date(), "%d.%m.%Y"), "\n",
                           paste(rep("=", 50), collapse = ""), "\n\n")
          writeLines(paste0(header, lesson_plan_to_text(plan)), file)
        }
      }
    )

    # === Word Export (Gün 10) ===
    output$btn_lp_export_word <- downloadHandler(
      filename = function() {
        paste0("ders_plani_", input$lp_subject, "_", input$lp_grade, "sinif_",
               format(Sys.Date(), "%Y%m%d"), ".docx")
      },
      content = function(file) {
        plan <- generated_plan()
        if (!is.null(plan) && requireNamespace("officer", quietly = TRUE)) {
          doc <- officer::read_docx()

          doc <- officer::body_add_par(doc, plan$title %||% "Dərs Planı", style = "heading 1")
          doc <- officer::body_add_par(doc, paste0("Fənn: ", plan$subject, " | Sinif: ", plan$grade,
            "-ci sinif | Müddət: ", plan$duration, " dəq."))
          doc <- officer::body_add_par(doc, paste0("Mövzu: ", plan$topic))
          if (!is.null(plan$method)) doc <- officer::body_add_par(doc, paste0("Metod: ", plan$method))
          doc <- officer::body_add_par(doc, paste0("Tarix: ", format(Sys.Date(), "%d.%m.%Y")))
          doc <- officer::body_add_par(doc, "")

          if (!is.null(plan$learning_outcomes) && length(plan$learning_outcomes) > 0) {
            doc <- officer::body_add_par(doc, "ÖYRƏNMƏ NƏTİCƏLƏRİ", style = "heading 2")
            for (i in seq_along(plan$learning_outcomes)) {
              doc <- officer::body_add_par(doc, paste0(i, ". ", plan$learning_outcomes[[i]]))
            }
            doc <- officer::body_add_par(doc, "")
          }

          if (!is.null(plan$stages) && length(plan$stages) > 0) {
            doc <- officer::body_add_par(doc, "DƏRS MƏRHƏLƏLƏRİ", style = "heading 2")
            for (i in seq_along(plan$stages)) {
              s <- plan$stages[[i]]
              name <- s$name %||% paste("Mərhələ", i)
              dur <- if (!is.null(s$duration) && s$duration != "") paste0(" (", s$duration, " dəq.)") else ""
              doc <- officer::body_add_par(doc, paste0(i, ". ", name, dur), style = "heading 3")
              if (!is.null(s$teacher_activity) && nchar(s$teacher_activity) > 0)
                doc <- officer::body_add_par(doc, paste0("Müəllim fəaliyyəti: ", s$teacher_activity))
              if (!is.null(s$student_activity) && nchar(s$student_activity) > 0)
                doc <- officer::body_add_par(doc, paste0("Şagird fəaliyyəti: ", s$student_activity))
              if (!is.null(s$resources))
                doc <- officer::body_add_par(doc, paste0("Resurslar: ",
                  if (is.list(s$resources)) paste(unlist(s$resources), collapse = ", ") else s$resources))
              if (!is.null(s$assessment) && nchar(s$assessment) > 0)
                doc <- officer::body_add_par(doc, paste0("Qiymətləndirmə: ", s$assessment))
              if (!is.null(s$description) && nchar(s$description) > 0)
                doc <- officer::body_add_par(doc, s$description)
              doc <- officer::body_add_par(doc, "")
            }
          }

          if (!is.null(plan$differentiation)) {
            d <- plan$differentiation
            doc <- officer::body_add_par(doc, "FƏRQLƏNDİRMƏ", style = "heading 2")
            if (!is.null(d$advanced)) doc <- officer::body_add_par(doc, paste0("Güclü şagirdlər: ", d$advanced))
            if (!is.null(d$struggling)) doc <- officer::body_add_par(doc, paste0("Çətinlik çəkən: ", d$struggling))
            if (!is.null(d$ell)) doc <- officer::body_add_par(doc, paste0("Dil dəstəyi: ", d$ell))
            doc <- officer::body_add_par(doc, "")
          }

          if (!is.null(plan$homework)) {
            doc <- officer::body_add_par(doc, "EV TAPŞIRIĞI", style = "heading 2")
            doc <- officer::body_add_par(doc,
              if (is.list(plan$homework)) paste(unlist(plan$homework), collapse = "; ") else plan$homework)
            doc <- officer::body_add_par(doc, "")
          }

          if (!is.null(plan$materials) && length(plan$materials) > 0) {
            doc <- officer::body_add_par(doc, "LAZIM OLAN MATERİALLAR", style = "heading 2")
            for (m in plan$materials) {
              doc <- officer::body_add_par(doc, paste0("- ", m))
            }
            doc <- officer::body_add_par(doc, "")
          }

          if (!is.null(plan$notes) && nchar(plan$notes) > 0) {
            doc <- officer::body_add_par(doc, "QEYDLƏR", style = "heading 2")
            doc <- officer::body_add_par(doc, plan$notes)
          }

          doc <- officer::body_add_par(doc, "")
          doc <- officer::body_add_par(doc, "--- ARTI-2026 AI Dərs Planı Generatoru ilə yaradılmışdır ---")

          print(doc, target = file)
        } else {
          writeLines(lesson_plan_to_text(generated_plan()), file)
        }
      }
    )

    # === DB-yə Saxla ===
    observeEvent(input$btn_lp_save_db, {
      plan <- generated_plan()
      meta <- plan_meta()
      req(plan)

      tryCatch({
        plan_json <- jsonlite::toJSON(plan, auto_unbox = TRUE, null = "null")
        db_execute(db_pool,
          "INSERT INTO ai_responses (provider, model, task_type, prompt_text, response_text,
           input_tokens, output_tokens, response_time_ms, status, user_id, created_at)
           VALUES ($1, $2, 'lesson_plan', $3, $4, $5, $6, $7, 'success', $8, NOW())",
          params = list(
            meta$provider %||% "auto",
            meta$model %||% "",
            paste0(input$lp_subject, " | ", input$lp_grade, " | ", input$lp_topic),
            as.character(plan_json),
            0, meta$tokens %||% 0,
            round((meta$time %||% 0) * 1000),
            user_data()$id
          ))
        notify_success("Dərs planı DB-yə saxlanıldı!")
      }, error = function(e) {
        notify_error(paste("Saxlama xətası:", e$message))
      })
    })

    # === Yenidən yarat ===
    observeEvent(input$btn_lp_regenerate, {
      generated_plan(NULL)
      plan_raw_text(NULL)
      plan_meta(NULL)
      shinyjs::click("btn_lp_generate")
    })

    # === Təmizlə ===
    observeEvent(input$btn_lp_clear, {
      generated_plan(NULL)
      plan_raw_text(NULL)
      plan_meta(NULL)
    })

    # === Tarixçə ===
    output$lp_history_table <- renderDT({
      data <- tryCatch(
        db_query(db_pool,
          "SELECT provider, model, prompt_text, response_time_ms,
                  input_tokens + output_tokens as total_tokens,
                  estimated_cost, status, created_at
           FROM ai_responses
           WHERE task_type = 'lesson_plan'
           ORDER BY created_at DESC LIMIT 50"),
        error = function(e) data.frame()
      )

      if (nrow(data) == 0) return(datatable(data.frame("Tarixçə boşdur" = character(0))))

      data$created_at <- format_date_az(data$created_at)
      data$response_time_ms <- paste0(round(data$response_time_ms / 1000, 1), "s")
      data$estimated_cost <- paste0("$", round(data$estimated_cost, 4))
      data$prompt_text <- substr(data$prompt_text, 1, 60)

      names(data) <- c("Provayder", "Model", "Mövzu", "Vaxt", "Token", "Xərc", "Status", "Tarix")
      datatable(data, selection = "none", options = default_dt_options(10))
    })
  })
}
