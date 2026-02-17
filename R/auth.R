# =============================================
# ARTI-2026: Autentifikasiya və Avtorizasiya
# JWT əsaslı istifadəçi idarəetməsi
# =============================================

library(jose)
library(openssl)
library(jsonlite)
library(logger)

#' JWT token yarat
create_jwt_token <- function(user_data) {
  secret <- charToRaw(Sys.getenv("JWT_SECRET", "default-secret"))
  expiry_hours <- as.integer(Sys.getenv("JWT_EXPIRY_HOURS", 24))

  jwt_encode_hmac(
    claim = jwt_claim(
      sub       = as.character(user_data$id),
      iss       = "ARTI-2026",
      exp       = as.integer(Sys.time() + expiry_hours * 3600),
      iat       = as.integer(Sys.time()),
      username  = user_data$username,
      role      = user_data$role,
      full_name = user_data$full_name,
      school_id = user_data$school_id
    ),
    secret = secret
  )
}

#' JWT token yoxla
verify_jwt_token <- function(token) {
  tryCatch({
    secret <- charToRaw(Sys.getenv("JWT_SECRET", "default-secret"))
    claims <- jwt_decode_hmac(token, secret = secret)
    if (as.integer(Sys.time()) > claims$exp) {
      log_warn("Token vaxtı keçib: {claims$sub}")
      return(NULL)
    }
    list(
      id = claims$sub, username = claims$username,
      role = claims$role, full_name = claims$full_name,
      school_id = claims$school_id
    )
  }, error = function(e) {
    log_warn("Token yoxlama xətası: {e$message}")
    NULL
  })
}

#' İstifadəçi daxil olma
login_user <- function(db_pool, username, password) {
  # Kilidlənmə yoxla
  lockout <- check_lockout(db_pool, username)
  if (lockout$locked) {
    return(list(success = FALSE,
                message = sprintf("Hesab %d dəqiqə müddətinə kilidlənib.", lockout$remaining_minutes)))
  }

  # İstifadəçini tap
  user <- db_get_one(db_pool,
    "SELECT id, username, password_hash, email, full_name, role, avatar, is_active, school_id
     FROM users WHERE username = $1", params = list(username))

  if (is.null(user)) {
    record_login_attempt(db_pool, username, FALSE)
    return(list(success = FALSE, message = "İstifadəçi adı və ya şifrə yanlışdır"))
  }

  if (!user$is_active) {
    return(list(success = FALSE, message = "Hesab deaktiv edilib"))
  }

  if (!verify_password(password, user$password_hash)) {
    record_login_attempt(db_pool, username, FALSE)
    remaining <- SYSTEM_LIMITS$max_login_attempts - get_failed_attempts(db_pool, username)
    return(list(success = FALSE,
                message = sprintf("Şifrə yanlışdır. %d cəhd qalıb.", max(0, remaining))))
  }

  # Uğurlu giriş
  record_login_attempt(db_pool, username, TRUE)
  token <- create_jwt_token(user)
  log_action(db_pool, user$id, "login", "user", user$id)
  log_info("İstifadəçi daxil oldu: {username}")

  list(
    success = TRUE, token = token,
    user = list(id = user$id, username = user$username, full_name = user$full_name,
                role = user$role, avatar = user$avatar, school_id = user$school_id)
  )
}

#' Çıxış
logout_user <- function(db_pool, user_id) {
  log_action(db_pool, user_id, "logout", "user", user_id)
  log_info("İstifadəçi çıxış etdi: {user_id}")
  TRUE
}

#' İstifadəçi qeydiyyatı
register_user <- function(db_pool, user_data) {
  if (is_empty(user_data$username) || is_empty(user_data$password)) {
    return(list(success = FALSE, message = "İstifadəçi adı və şifrə tələb olunur"))
  }

  existing <- db_get_one(db_pool, "SELECT id FROM users WHERE username = $1",
                         params = list(user_data$username))
  if (!is.null(existing)) {
    return(list(success = FALSE, message = "Bu istifadəçi adı artıq mövcuddur"))
  }

  pwd_check <- validate_password_strength(user_data$password)
  if (!pwd_check$valid) {
    return(list(success = FALSE, message = "Şifrə kifayət qədər güclü deyil"))
  }

  result <- db_execute(db_pool,
    "INSERT INTO users (username, password_hash, email, full_name, role, is_active, created_at)
     VALUES ($1, $2, $3, $4, $5, TRUE, NOW())",
    params = list(user_data$username, hash_password(user_data$password),
                  user_data$email, user_data$full_name, user_data$role %||% "student"))

  if (result > 0) {
    log_info("Yeni istifadəçi yaradıldı: {user_data$username}")
    list(success = TRUE, message = "İstifadəçi uğurla yaradıldı")
  } else {
    list(success = FALSE, message = "İstifadəçi yaradılarkən xəta baş verdi")
  }
}

#' Səlahiyyət yoxlaması
check_permission <- function(user_role, required_roles) {
  !is.null(user_role) && user_role %in% required_roles
}

is_admin   <- function(user_data) !is.null(user_data) && user_data$role == "admin"
is_teacher <- function(user_data) !is.null(user_data) && user_data$role %in% c("admin", "director", "teacher")

#' Giriş cəhdini qeyd et
record_login_attempt <- function(db_pool, username, success) {
  tryCatch({
    if (success) {
      db_execute(db_pool, "DELETE FROM login_attempts WHERE username = $1", params = list(username))
    } else {
      db_execute(db_pool,
        "INSERT INTO login_attempts (username, attempted_at) VALUES ($1, NOW())",
        params = list(username))
    }
  }, error = function(e) log_error("Giriş cəhdi qeyd xətası: {e$message}"))
}

#' Uğursuz cəhd sayını al
get_failed_attempts <- function(db_pool, username) {
  result <- db_query(db_pool,
    "SELECT COUNT(*) as count FROM login_attempts
     WHERE username = $1 AND attempted_at > NOW() - INTERVAL '15 minutes'",
    params = list(username))
  if (nrow(result) > 0) result$count[1] else 0
}

#' Kilidlənmə yoxlaması
check_lockout <- function(db_pool, username) {
  attempts <- get_failed_attempts(db_pool, username)
  if (attempts >= SYSTEM_LIMITS$max_login_attempts) {
    list(locked = TRUE, remaining_minutes = 15)
  } else {
    list(locked = FALSE, remaining_minutes = 0)
  }
}

#' Şifrə dəyişdirmə
change_password <- function(db_pool, user_id, old_password, new_password) {
  user <- db_get_one(db_pool, "SELECT password_hash FROM users WHERE id = $1",
                     params = list(user_id))
  if (is.null(user)) return(list(success = FALSE, message = "İstifadəçi tapılmadı"))
  if (!verify_password(old_password, user$password_hash))
    return(list(success = FALSE, message = "Köhnə şifrə yanlışdır"))

  pwd_check <- validate_password_strength(new_password)
  if (!pwd_check$valid)
    return(list(success = FALSE, message = "Yeni şifrə kifayət qədər güclü deyil"))

  result <- db_execute(db_pool,
    "UPDATE users SET password_hash = $1, updated_at = NOW() WHERE id = $2",
    params = list(hash_password(new_password), user_id))

  if (result > 0) {
    log_info("Şifrə dəyişdirildi: istifadəçi {user_id}")
    list(success = TRUE, message = "Şifrə uğurla dəyişdirildi")
  } else {
    list(success = FALSE, message = "Şifrə dəyişdirilə bilmədi")
  }
}
