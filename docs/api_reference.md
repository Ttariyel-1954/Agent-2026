# ARTI-2026 API Referans

## 1. Verilənlər Bazası Funksiyaları

### db_query(pool, query, params)
Parametrli SELECT sorğusu icra edir.
```r
db_query(pool, "SELECT * FROM students WHERE class_id = $1", params = list(class_id))
```

### db_execute(pool, query, params)
INSERT/UPDATE/DELETE sorğusu icra edir.
```r
db_execute(pool, "UPDATE students SET status = $1 WHERE id = $2", params = list("inactive", student_id))
```

### db_get_one(pool, query, params)
Tək sətir qaytarır.
```r
db_get_one(pool, "SELECT * FROM students WHERE id = $1", params = list(id))
```

### get_total_count(pool, table, condition)
Cədvəldəki sətir sayını qaytarır.
```r
get_total_count(pool, "students", "status = 'active'")
```

### db_transaction(pool, func)
Tranzaksiya daxilində əməliyyat icra edir.
```r
db_transaction(pool, function(conn) {
  dbExecute(conn, "INSERT INTO grades ...")
  dbExecute(conn, "INSERT INTO audit_log ...")
})
```

## 2. Autentifikasiya Funksiyaları

### login_user(pool, username, password)
İstifadəçi girişi. JWT token qaytarır.
```r
result <- login_user(pool, "admin", "password123")
# result$success, result$token, result$user
```

### verify_jwt_token(token, secret)
JWT tokeni yoxlayır.
```r
payload <- verify_jwt_token(token, Sys.getenv("JWT_SECRET"))
```

### check_permission(user_data, required_role)
İstifadəçi icazəsini yoxlayır.
```r
check_permission(user_data(), "admin")  # TRUE/FALSE
```

### register_user(pool, data)
Yeni istifadəçi qeydiyyatı.
```r
register_user(pool, list(
  username = "newuser",
  email = "new@test.az",
  password = "Str0ng!Pass",
  role = "teacher",
  first_name = "Ad",
  last_name = "Soyad"
))
```

## 3. IRT Funksiyaları

### irt_1pl_probability(theta, b)
1PL (Rasch) ehtimal hesablaması.
- `theta`: Qabiliyyət parametri
- `b`: Çətinlik parametri

### irt_2pl_probability(theta, a, b)
2PL ehtimal hesablaması.
- `a`: Fərqləndirmə parametri (>0)

### irt_3pl_probability(theta, a, b, c)
3PL ehtimal hesablaması.
- `c`: Təxmin parametri (0-1)

### calculate_information(theta, a, b, c)
Fisher informasiya funksiyası.
```r
info <- calculate_information(theta = 0, a = 1.5, b = 0.5, c = 0.2)
```

### estimate_theta_mle(responses, items)
MLE ilə theta qiymətləndirilməsi (Newton-Raphson).
```r
theta <- estimate_theta_mle(c(1,0,1,1,0), items_df)
```

### estimate_theta_eap(responses, items)
EAP ilə theta qiymətləndirilməsi (Gaussian quadrature).

## 4. CAT Funksiyaları

### initialize_cat(item_bank)
Yeni CAT sessiyası yaradır.
```r
session <- initialize_cat(item_bank_df)
```

### select_next_item(session, item_bank)
Növbəti sualı seçir (Maximum Fisher Information).
```r
next_item <- select_next_item(session, item_bank)
```

### update_theta(session, item_bank)
Cavabdan sonra theta-nı yeniləyir.

### check_stopping_rule(session)
Dayandırma şərtini yoxlayır (SE < 0.3 və ya max 50 sual).

## 5. AI İnteqrasiya Funksiyaları

### call_claude_api(prompt, system_prompt, max_tokens, temperature)
Claude API-yə sorğu göndərir.
```r
result <- call_claude_api("Sualı izah et", temperature = 0.7)
# result$success, result$message, result$usage
```

### call_gpt_api(prompt, system_prompt, max_tokens, temperature)
GPT API-yə sorğu göndərir. Eyni interfeys.

### call_ai(prompt, provider, system_prompt, temperature)
Ümumi AI sorğusu (provider seçimi ilə).
```r
result <- call_ai("Sual", provider = "claude")
```

### generate_questions_claude(subject, grade, topic, difficulty, count)
AI ilə sual generasiyası.
```r
result <- generate_questions_claude("Riyaziyyat", 8, "Tənliklər", "orta", 5)
```

### generate_student_feedback_claude(student_data)
Şagirdə fərdi rəy generasiyası.

### load_prompt_template(template_name)
Prompt şablonunu yükləyir.
```r
template <- load_prompt_template("question_generation")
```

## 6. Köməkçi Funksiyalar

### format_date_az(date)
Tarixi Azərbaycan formatına çevirir: "15.02.2026"

### get_grade_label(score)
Qiymət etiketini qaytarır: Əla/Yaxşı/Kafi/Qeyri-kafi

### validate_email(email), validate_phone_az(phone), validate_fin(fin)
Giriş validasiyası funksiyaları.

### hash_password(password), verify_password(password, hash)
Şifrə hashing (bcrypt).

### calculate_age(birth_date)
Doğum tarixindən yaş hesablaması.

### get_academic_year(), get_current_semester()
Cari tədris ili və yarımil.

### export_to_excel(data, filename, sheet_name)
Data frame-i Excel faylına ixrac edir.

### log_action(user_id, action, details)
Audit log-a yazır.

## 7. PostgreSQL Stored Procedures

### calculate_student_gpa(student_id, academic_year)
Şagird GPA-sını hesablayır.

### calculate_attendance_rate(student_id, start_date, end_date)
Davamiyyət faizini hesablayır.

### get_class_average(class_id, subject_id)
Sinif orta balını qaytarır.

### get_at_risk_students(school_id, threshold)
Risk altında olan şagirdləri qaytarır.

### refresh_analytics_views()
Materialized view-ları yeniləyir.

### estimate_theta_mle(session_id)
SQL səviyyəsində MLE theta hesablaması.
