# =============================================
# ARTI-2026: OCR Modulu - Köməkçi Funksiyalar
# GPT-4o Vision / Claude Vision ilə şəkil tanıma
# Azərbaycan dili (ə, ı, ö, ü, ç, ş, ğ) dəstəyi
# =============================================

# =============================================
# VİSİON API ÇAĞIRIŞLARI
# =============================================

#' Şəkili base64 formatına çevir
#' @param file_path Şəkil faylının yolu
#' @return base64 string
image_to_base64 <- function(file_path) {
  raw_bytes <- readBin(file_path, "raw", file.info(file_path)$size)
  base64enc::base64encode(raw_bytes)
}

#' Şəkil MIME növünü müəyyənləşdir
#' @param file_path Fayl yolu
#' @return MIME string
get_image_mime <- function(file_path) {
  ext <- tolower(tools::file_ext(file_path))
  switch(ext,
    "jpg" = , "jpeg" = "image/jpeg",
    "png" = "image/png",
    "gif" = "image/gif",
    "webp" = "image/webp",
    "bmp" = "image/bmp",
    "tiff" = , "tif" = "image/tiff",
    "image/jpeg"  # default
  )
}

#' GPT-4o Vision ilə OCR
#' @param image_path Şəkil faylının yolu
#' @param prompt OCR təlimatı
#' @param system_prompt Sistem promptu
#' @param max_tokens Maks token
#' @return list(success, message, usage)
call_gpt_vision <- function(image_path, prompt, system_prompt = NULL, max_tokens = 4096) {
  api_key <- Sys.getenv("GPT_API_KEY")
  if (api_key == "") {
    # OPENAI_API_KEY-i də yoxla (fallback)
    api_key <- Sys.getenv("OPENAI_API_KEY")
  }
  if (api_key == "") {
    return(list(success = FALSE, message = "GPT_API_KEY və ya OPENAI_API_KEY təyin olunmayıb."))
  }

  b64 <- image_to_base64(image_path)
  mime <- get_image_mime(image_path)

  messages <- list()
  if (!is.null(system_prompt) && nchar(system_prompt) > 0) {
    messages <- c(messages, list(list(role = "system", content = system_prompt)))
  }

  # Vision mesajı — mətn + şəkil
  messages <- c(messages, list(list(
    role = "user",
    content = list(
      list(type = "text", text = prompt),
      list(type = "image_url", image_url = list(
        url = paste0("data:", mime, ";base64,", b64),
        detail = "high"
      ))
    )
  )))

  body <- list(
    model = "gpt-4o",
    messages = messages,
    max_tokens = max_tokens,
    temperature = 0.2
  )

  response <- tryCatch({
    httr::POST(
      url = "https://api.openai.com/v1/chat/completions",
      httr::add_headers(
        Authorization = paste("Bearer", api_key),
        `Content-Type` = "application/json"
      ),
      body = jsonlite::toJSON(body, auto_unbox = TRUE),
      encode = "raw",
      httr::timeout(120)
    )
  }, error = function(e) {
    return(NULL)
  })

  if (is.null(response)) {
    return(list(success = FALSE, message = "GPT Vision API ilə əlaqə qurmaq mümkün olmadı."))
  }

  status <- httr::status_code(response)
  content <- httr::content(response, as = "text", encoding = "UTF-8")
  parsed <- jsonlite::fromJSON(content, simplifyVector = FALSE)

  if (status == 200) {
    text <- parsed$choices[[1]]$message$content
    list(
      success = TRUE,
      message = text,
      usage = list(
        prompt_tokens = parsed$usage$prompt_tokens %||% 0,
        completion_tokens = parsed$usage$completion_tokens %||% 0
      )
    )
  } else {
    error_msg <- parsed$error$message %||% "Naməlum xəta"
    list(success = FALSE, message = paste("GPT Vision xətası:", error_msg))
  }
}

#' Claude Vision ilə OCR
#' @param image_path Şəkil faylının yolu
#' @param prompt OCR təlimatı
#' @param system_prompt Sistem promptu
#' @param max_tokens Maks token
#' @return list(success, message, usage)
call_claude_vision <- function(image_path, prompt, system_prompt = NULL, max_tokens = 4096) {
  api_key <- Sys.getenv("CLAUDE_API_KEY")
  if (api_key == "") {
    return(list(success = FALSE, message = "CLAUDE_API_KEY təyin olunmayıb."))
  }

  b64 <- image_to_base64(image_path)
  mime <- get_image_mime(image_path)

  messages <- list(list(
    role = "user",
    content = list(
      list(type = "image", source = list(
        type = "base64",
        media_type = mime,
        data = b64
      )),
      list(type = "text", text = prompt)
    )
  ))

  body <- list(
    model = "claude-sonnet-4-5-20250929",
    max_tokens = max_tokens,
    temperature = 0.2,
    messages = messages
  )

  if (!is.null(system_prompt) && nchar(system_prompt) > 0) {
    body$system <- system_prompt
  }

  response <- tryCatch({
    httr::POST(
      url = "https://api.anthropic.com/v1/messages",
      httr::add_headers(
        `x-api-key` = api_key,
        `anthropic-version` = "2023-06-01",
        `content-type` = "application/json"
      ),
      body = jsonlite::toJSON(body, auto_unbox = TRUE),
      encode = "raw",
      httr::timeout(120)
    )
  }, error = function(e) {
    return(NULL)
  })

  if (is.null(response)) {
    return(list(success = FALSE, message = "Claude Vision API ilə əlaqə qurmaq mümkün olmadı."))
  }

  status <- httr::status_code(response)
  content <- httr::content(response, as = "text", encoding = "UTF-8")
  parsed <- jsonlite::fromJSON(content, simplifyVector = FALSE)

  if (status == 200) {
    text <- parsed$content[[1]]$text
    list(
      success = TRUE,
      message = text,
      usage = list(
        input_tokens = parsed$usage$input_tokens %||% 0,
        output_tokens = parsed$usage$output_tokens %||% 0
      )
    )
  } else {
    error_msg <- parsed$error$message %||% "Naməlum xəta"
    list(success = FALSE, message = paste("Claude Vision xətası:", error_msg))
  }
}

# =============================================
# OCR PROMPT ŞABLONLARI
# =============================================

#' Test cavab vərəqəsi üçün OCR promptu
build_answer_sheet_prompt <- function(subject, grade, question_count, answer_key) {
  key_text <- ""
  if (!is.null(answer_key) && nchar(answer_key) > 0) {
    key_text <- sprintf("\n\nDÜZGÜN CAVAB AÇARI:\n%s", answer_key)
  }

  sprintf(
'Bu test cavab vərəqəsinin şəklini analiz et.
Fənn: %s | Sinif: %s | Sual sayı: %s

TAPŞIRIQ:
1. Hər sualın nömrəsini və işarələnmiş cavabı (A, B, C, D, E) müəyyənləşdir
2. Əgər cavab oxunaqlı deyilsə "?" qoy
3. Şagirdin adı/soyadı varsa onu da oxu
4. Əgər FİN kod və ya sinif yazılıbsa onu da oxu
%s

JSON formatında cavab ver:
{
  "student_name": "Ad Soyad (əgər varsa)",
  "fin_code": "FİN (əgər varsa)",
  "class_info": "Sinif (əgər varsa)",
  "answers": [
    {"question": 1, "answer": "A"},
    {"question": 2, "answer": "C"},
    ...
  ],
  "confidence": 0.95,
  "notes": "Əlavə qeydlər (oxunaqlılıq problemi və s.)"
}

ÖNƏMLİ: Azərbaycan dilində yazılmış məlumatları da düzgün oxu (ə, ı, ö, ü, ç, ş, ğ).', subject, grade, question_count, key_text)
}

#' Şagird sənədi üçün OCR promptu
build_student_doc_prompt <- function(doc_type) {
  type_desc <- switch(doc_type,
    "birth_cert" = "doğum haqqında şəhadətnamə",
    "id_card"    = "şəxsiyyət vəsiqəsi",
    "transcript" = "attestat / qiymət cədvəli",
    "medical"    = "tibbi arayış",
    "transfer"   = "köçürmə sənədi",
    "sənəd"
  )

  sprintf(
'Bu Azərbaycan dilində %s sənədinin şəklini analiz et.

TAPŞIRIQ:
1. Sənəddəki bütün məlumatları oxu
2. Azərbaycan hərflərini düzgün tanı: Ə, ə, I, ı, Ö, ö, Ü, ü, Ç, ç, Ş, ş, Ğ, ğ
3. Tarixləri dd.mm.yyyy formatında yaz
4. FİN kodu, seria nömrəsi və s. dəqiq yaz

JSON formatında cavab ver:
{
  "document_type": "%s",
  "fields": {
    "first_name": "",
    "last_name": "",
    "father_name": "",
    "birth_date": "dd.mm.yyyy",
    "gender": "Kişi/Qadın",
    "fin_code": "",
    "seria_number": "",
    "nationality": "",
    "birth_place": "",
    "address": "",
    "issue_date": "dd.mm.yyyy",
    "issued_by": ""
  },
  "additional_fields": {},
  "confidence": 0.9,
  "notes": "Oxunaqlılıq problemləri, natamam məlumatlar"
}

ÖNƏMLİ: Sənəddə olmayan sahələri boş saxla. Oxuna bilməyən hissələr üçün "?" qoy.', type_desc, doc_type)
}

#' Müəllim sertifikatı üçün OCR promptu
build_certificate_prompt <- function() {
'Bu müəllim sertifikatı/diplom/təlim sənədinin şəklini analiz et.

TAPŞIRIQ:
1. Sertifikatın başlığını, verilmə tarixini, təşkilatçını oxu
2. Müəllimin adını, soyadını müəyyənləşdir
3. Təlimin mövzusunu, müddətini, saatını tapçıxar
4. Sertifikat nömrəsini, seria nömrəsini yazı
5. Azərbaycan hərflərini düzgün tanı: Ə, ə, I, ı, Ö, ö, Ü, ü, Ç, ç, Ş, ş, Ğ, ğ

JSON formatında cavab ver:
{
  "certificate_type": "kurs/seminar/konfrans/sertifikat/diplom",
  "title": "Sertifikatın/təlimin adı",
  "teacher_name": "Ad Soyad",
  "provider": "Təşkilatçı/Qurum adı",
  "issue_date": "dd.mm.yyyy",
  "start_date": "dd.mm.yyyy",
  "end_date": "dd.mm.yyyy",
  "hours": 0,
  "certificate_number": "",
  "topic": "Mövzu/sahə",
  "level": "əsas/orta/irəliləmiş/ekspert",
  "additional_info": {},
  "confidence": 0.9,
  "notes": ""
}

ÖNƏMLİ: Sənəddə olmayan sahələri boş saxla.'
}

# =============================================
# NƏTİCƏ EMAL FUNKSİYALARI
# =============================================

#' Vision API cavabından JSON çıxar
#' @param response_text API cavab mətni
#' @return parsed JSON (list) və ya NULL
parse_ocr_response <- function(response_text) {
  if (is.null(response_text) || nchar(response_text) == 0) return(NULL)

  # ```json ... ``` bloku
  json_match <- regmatches(response_text, regexpr("```json\\s*\\n(.*?)\\n\\s*```", response_text, perl = TRUE))
  if (length(json_match) > 0) {
    json_text <- gsub("```json\\s*\\n|\\n\\s*```", "", json_match[1])
  } else {
    json_text <- trimws(response_text)
    if (!grepl("^\\{", json_text)) return(NULL)
  }

  tryCatch(
    jsonlite::fromJSON(json_text, simplifyVector = FALSE),
    error = function(e) {
      logger::log_warn("OCR JSON parse xətası: {e$message}")
      NULL
    }
  )
}

#' Cavab vərəqəsini qiymətləndir
#' @param student_answers list — şagirdin cavabları (parse_ocr_response nəticəsi)
#' @param answer_key character — düzgün cavab açarı ("1A,2C,3B,..." formatı)
#' @return list(score, total, percent, details)
grade_answer_sheet <- function(student_answers, answer_key) {
  if (is.null(student_answers) || is.null(student_answers$answers)) {
    return(list(score = 0, total = 0, percent = 0, details = data.frame()))
  }

  # Cavab açarını parse et
  key_pairs <- strsplit(trimws(answer_key), "[,;\\s]+")[[1]]
  correct <- list()
  for (pair in key_pairs) {
    pair <- trimws(pair)
    if (nchar(pair) >= 2) {
      # "1A" və ya "1-A" və ya "1:A" formatları
      num <- gsub("[^0-9]", "", pair)
      ans <- gsub("[^A-Ea-e]", "", pair)
      if (nchar(num) > 0 && nchar(ans) > 0) {
        correct[[num]] <- toupper(ans)
      }
    }
  }

  # Qiymətləndirmə
  details <- data.frame(
    sual = integer(), sagird_cavab = character(),
    duzgun_cavab = character(), neticesi = character(),
    stringsAsFactors = FALSE
  )

  score <- 0
  total <- length(correct)

  for (item in student_answers$answers) {
    q_num <- as.character(item$question)
    s_ans <- toupper(item$answer %||% "?")
    c_ans <- correct[[q_num]] %||% "?"

    is_correct <- (s_ans == c_ans && s_ans != "?")
    if (is_correct) score <- score + 1

    details <- rbind(details, data.frame(
      sual = as.integer(q_num),
      sagird_cavab = s_ans,
      duzgun_cavab = c_ans,
      neticesi = if (s_ans == "?") "Oxunmadı" else if (is_correct) "Düzgün" else "Səhv",
      stringsAsFactors = FALSE
    ))
  }

  details <- details[order(details$sual), ]
  percent <- if (total > 0) round(score / total * 100, 1) else 0

  list(
    score = score,
    total = total,
    percent = percent,
    grade_label = get_grade_label(percent),
    grade_color = get_grade_color(percent),
    student_name = student_answers$student_name %||% "",
    confidence = student_answers$confidence %||% 0,
    details = details
  )
}

#' Şagird sənədindən profil datasiını çıxar
#' @param parsed_doc parse_ocr_response nəticəsi
#' @return list — student profil sahələri
extract_student_fields <- function(parsed_doc) {
  if (is.null(parsed_doc) || is.null(parsed_doc$fields)) return(list())

  f <- parsed_doc$fields
  list(
    first_name  = normalize_az_text(f$first_name %||% ""),
    last_name   = normalize_az_text(f$last_name %||% ""),
    father_name = normalize_az_text(f$father_name %||% ""),
    birth_date  = parse_az_date(f$birth_date %||% ""),
    gender      = f$gender %||% "",
    fin_code    = toupper(gsub("[^A-Za-z0-9]", "", f$fin_code %||% "")),
    nationality = f$nationality %||% "Azərbaycan",
    address     = normalize_az_text(f$address %||% ""),
    doc_type    = parsed_doc$document_type %||% "",
    confidence  = parsed_doc$confidence %||% 0,
    notes       = parsed_doc$notes %||% ""
  )
}

#' Müəllim sertifikatından peşəkar inkişaf qeydi çıxar
#' @param parsed_cert parse_ocr_response nəticəsi
#' @return list — training record sahələri
extract_certificate_fields <- function(parsed_cert) {
  if (is.null(parsed_cert)) return(list())

  list(
    title         = normalize_az_text(parsed_cert$title %||% ""),
    teacher_name  = normalize_az_text(parsed_cert$teacher_name %||% ""),
    provider      = normalize_az_text(parsed_cert$provider %||% ""),
    cert_type     = parsed_cert$certificate_type %||% "sertifikat",
    issue_date    = parse_az_date(parsed_cert$issue_date %||% ""),
    start_date    = parse_az_date(parsed_cert$start_date %||% ""),
    end_date      = parse_az_date(parsed_cert$end_date %||% ""),
    hours         = as.integer(parsed_cert$hours %||% 0),
    cert_number   = parsed_cert$certificate_number %||% "",
    topic         = normalize_az_text(parsed_cert$topic %||% ""),
    level         = parsed_cert$level %||% "",
    confidence    = parsed_cert$confidence %||% 0,
    notes         = parsed_cert$notes %||% ""
  )
}

# =============================================
# AZƏRBAYCAN DİLİ YARDIMÇI FUNKSİYALAR
# =============================================

#' Azərbaycan mətni normallaşdır
#' @param text Giriş mətni
#' @return Normallaşdırılmış mətn
normalize_az_text <- function(text) {
  if (is.null(text) || nchar(trimws(text)) == 0) return("")

  result <- trimws(text)

  # Ümumi OCR xətaları düzəlişləri
  corrections <- c(
    "\u0259" = "ə",  # Latin ə
    "\u018F" = "Ə",  # Latin Ə
    "\u0131" = "ı",  # Dotless i
    "\u0130" = "İ",  # Dotted I
    "\u00F6" = "ö",  # o-umlaut
    "\u00D6" = "Ö",  # O-umlaut
    "\u00FC" = "ü",  # u-umlaut
    "\u00DC" = "Ü",  # U-umlaut
    "\u015F" = "ş",  # s-cedilla
    "\u015E" = "Ş",  # S-cedilla
    "\u00E7" = "ç",  # c-cedilla
    "\u00C7" = "Ç",  # C-cedilla
    "\u011F" = "ğ",  # g-breve
    "\u011E" = "Ğ"   # G-breve
  )

  for (from in names(corrections)) {
    result <- gsub(from, corrections[[from]], result, fixed = TRUE)
  }

  # Çoxlu boşluqları tək boşluğa çevir
  result <- gsub("\\s+", " ", result)

  result
}

#' Azərbaycan tarixini parse et
#' @param date_str Tarix stringi ("dd.mm.yyyy", "dd/mm/yyyy", "yyyy-mm-dd")
#' @return Date və ya NA
parse_az_date <- function(date_str) {
  if (is.null(date_str) || nchar(trimws(date_str)) == 0) return(NA)
  d <- trimws(date_str)

  # Formatları cəhd et
  formats <- c("%d.%m.%Y", "%d/%m/%Y", "%Y-%m-%d", "%d-%m-%Y", "%d %m %Y")
  for (fmt in formats) {
    parsed <- tryCatch(as.Date(d, format = fmt), error = function(e) NA)
    if (!is.na(parsed) && parsed > as.Date("1900-01-01") && parsed < as.Date("2100-01-01")) {
      return(parsed)
    }
  }
  NA
}

#' Şəkil ölçüsünü yoxla (Vision API limiti)
#' @param file_path Fayl yolu
#' @return list(valid, message, size_mb)
validate_image <- function(file_path) {
  if (!file.exists(file_path)) {
    return(list(valid = FALSE, message = "Fayl tapılmadı.", size_mb = 0))
  }

  size_bytes <- file.info(file_path)$size
  size_mb <- round(size_bytes / (1024 * 1024), 2)

  # Maks 20 MB (Vision API limiti)
  if (size_mb > 20) {
    return(list(valid = FALSE, message = sprintf("Şəkil çox böyükdür (%s MB). Maks: 20 MB.", size_mb), size_mb = size_mb))
  }

  # Destəklənən formatlar
  ext <- tolower(tools::file_ext(file_path))
  valid_exts <- c("jpg", "jpeg", "png", "gif", "webp", "bmp", "tiff", "tif")
  if (!(ext %in% valid_exts)) {
    return(list(valid = FALSE,
      message = sprintf("Dəstəklənməyən format: .%s. Dəstəklənən: %s", ext, paste(valid_exts, collapse = ", ")),
      size_mb = size_mb))
  }

  list(valid = TRUE, message = "OK", size_mb = size_mb)
}

#' OCR nəticəsini DB-yə yazma (cavab vərəqəsi → grades)
#' @param db_pool DB pool
#' @param grading list — grade_answer_sheet nəticəsi
#' @param student_id UUID
#' @param subject_id UUID
#' @param teacher_id UUID
#' @param class_id UUID
#' @param academic_year character
#' @return integer — əlavə olunan sətir sayı
save_answer_grade_to_db <- function(db_pool, grading, student_id, subject_id,
                                     teacher_id, class_id, academic_year) {
  tryCatch({
    db_execute(db_pool,
      "INSERT INTO grades (student_id, subject_id, teacher_id, class_id,
        score, grade_type, academic_year, grade_date, comments)
       VALUES ($1, $2, $3, $4, $5, 'ksa', $6, CURRENT_DATE, $7)",
      params = list(
        student_id, subject_id, teacher_id, class_id,
        grading$percent, academic_year,
        sprintf("OCR ilə qiymətləndirildi. %d/%d düzgün (etibarlılıq: %s%%)",
          grading$score, grading$total, round(grading$confidence * 100))
      ))
  }, error = function(e) {
    logger::log_error("OCR qiymət yazma xətası: {e$message}")
    0
  })
}

#' Sertifikat məlumatını DB-yə yaz (teacher_trainings)
#' @param db_pool DB pool
#' @param cert_fields list — extract_certificate_fields nəticəsi
#' @param teacher_id UUID
#' @return integer
save_certificate_to_db <- function(db_pool, cert_fields, teacher_id) {
  tryCatch({
    # Təlim növü mapping
    type_map <- c(
      "kurs" = "kurs", "seminar" = "seminar", "konfrans" = "konfrans",
      "sertifikat" = "sertifikat", "diplom" = "magistratura"
    )
    training_type <- type_map[cert_fields$cert_type] %||% "sertifikat"

    db_execute(db_pool,
      "INSERT INTO teacher_trainings (teacher_id, title, provider, training_type,
        start_date, end_date, hours, certificate_number, status)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'completed')",
      params = list(
        teacher_id,
        cert_fields$title,
        cert_fields$provider,
        training_type,
        if (is.na(cert_fields$start_date)) cert_fields$issue_date else cert_fields$start_date,
        if (is.na(cert_fields$end_date)) cert_fields$issue_date else cert_fields$end_date,
        cert_fields$hours,
        cert_fields$cert_number
      ))
  }, error = function(e) {
    logger::log_error("OCR sertifikat yazma xətası: {e$message}")
    0
  })
}
