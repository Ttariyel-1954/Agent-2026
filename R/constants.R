# =============================================
# ARTI-2026: Sabitlər
# Layihədə istifadə olunan sabit dəyərlər
# =============================================

# === Qiymətləndirmə Şkalası (Azərbaycan) ===
GRADE_SCALE <- list(
  excellent      = list(min = 86, max = 100, label = "Əla",         color = "#27ae60"),
  good           = list(min = 71, max = 85,  label = "Yaxşı",       color = "#2980b9"),
  satisfactory   = list(min = 51, max = 70,  label = "Kafi",        color = "#f39c12"),
  unsatisfactory = list(min = 0,  max = 50,  label = "Qeyri-kafi",  color = "#e74c3c")
)

# === Təhsil Pillələri ===
EDUCATION_LEVELS <- list(
  primary         = list(id = "primary",         name = "İbtidai təhsil",    grades = 1:4),
  lower_secondary = list(id = "lower_secondary", name = "Ümumi orta təhsil", grades = 5:9),
  upper_secondary = list(id = "upper_secondary", name = "Tam orta təhsil",   grades = 10:11)
)

# === Fənlər ===
SUBJECTS <- c(
  "Azərbaycan dili", "Riyaziyyat", "Fizika", "Kimya", "Biologiya",
  "Tarix", "Coğrafiya", "İnformatika", "İngilis dili", "Rus dili",
  "Ədəbiyyat", "Musiqi", "Təsviri incəsənət", "Texnologiya", "Bədən tərbiyəsi"
)

# === İstifadəçi Rolları ===
USER_ROLES <- c(
  admin    = "Administrator",
  director = "Direktor",
  teacher  = "Müəllim",
  student  = "Şagird",
  parent   = "Valideyn"
)

# === Müəllim Kateqoriyaları ===
TEACHER_CATEGORIES <- c(
  "Ali kateqoriya",
  "I kateqoriya",
  "II kateqoriya",
  "Kateqoriyasız"
)

# === Davamiyyət Statusları ===
ATTENDANCE_STATUS <- list(
  present = list(id = "present", label = "İştirak",     icon = "check-circle", color = "#27ae60"),
  absent  = list(id = "absent",  label = "Qayıb",       icon = "times-circle", color = "#e74c3c"),
  late    = list(id = "late",    label = "Gecikmiş",     icon = "clock",        color = "#f39c12"),
  excused = list(id = "excused", label = "Üzrlü qayıb",  icon = "info-circle",  color = "#3498db")
)

# === Bloom Taksonomiyası ===
BLOOM_LEVELS <- c(
  "Bilmə", "Anlama", "Tətbiq", "Təhlil", "Sintez", "Qiymətləndirmə"
)

# === Çətinlik Səviyyələri ===
DIFFICULTY_LEVELS <- c(easy = "Asan", medium = "Orta", hard = "Çətin")

# === Qiymət Növləri ===
GRADE_TYPES <- c(
  exam = "İmtahan", quiz = "Kiçik yoxlama", homework = "Ev tapşırığı",
  project = "Layihə", oral = "Şifahi"
)

# === Semestrlər ===
SEMESTERS <- c(first = "I yarımil", second = "II yarımil")

# === Həftənin Günləri ===
WEEKDAYS_AZ <- c(
  "Bazar ertəsi", "Çərşənbə axşamı", "Çərşənbə", "Cümə axşamı", "Cümə"
)

# === Dərs Saatları ===
PERIODS <- list(
  list(period = 1, start = "08:00", end = "08:45"),
  list(period = 2, start = "08:55", end = "09:40"),
  list(period = 3, start = "09:50", end = "10:35"),
  list(period = 4, start = "10:55", end = "11:40"),
  list(period = 5, start = "11:50", end = "12:35"),
  list(period = 6, start = "12:45", end = "13:30"),
  list(period = 7, start = "13:40", end = "14:25")
)

# === IRT Parametrləri ===
IRT_DEFAULTS <- list(
  theta_range = c(-4, 4), theta_points = 61,
  default_a = 1.0, default_b = 0.0, default_c = 0.0,
  convergence = 0.001, max_iterations = 100
)

# === CAT Parametrləri ===
CAT_DEFAULTS <- list(
  min_items = 10, max_items = 50, se_threshold = 0.3,
  initial_theta = 0, max_exposure_rate = 0.25
)

# === MST Parametrləri ===
MST_DEFAULTS <- list(stages = 3, modules_per_stage = c(1, 3, 3), panel_size = 5)

# === Hesabat Formatları ===
EXPORT_FORMATS <- c(pdf = "PDF", xlsx = "Excel", csv = "CSV", html = "HTML")

# === Rənglər ===
ARTI_COLORS <- list(
  primary = "#2c3e50", secondary = "#34495e", success = "#27ae60",
  warning = "#f39c12", danger = "#e74c3c", info = "#3498db",
  light = "#ecf0f1", dark = "#2c3e50"
)

# === Beynəlxalq Müqayisə Ölkələri ===
COMPARISON_COUNTRIES <- c(
  "Azərbaycan", "Finlandiya", "Sinqapur",
  "Cənubi Koreya", "Estoniya", "Yaponiya", "Türkiyə"
)

# === İmtahan Növləri ===
EXAM_TYPES <- c(
  ise_qebul = "İşə Qəbul",
  sertifikasiya = "Sertifikasiya"
)

# === Sertifikasiya Səviyyələri ===
CERTIFICATION_LEVELS <- c(
  basic = "Əsas",
  intermediate = "Orta",
  advanced = "Ali",
  expert = "Ekspert"
)

# === Resurs Növləri ===
RESOURCE_TYPES <- c(
  tedris_proqrami = "Tədris Proqramı",
  reqemsal_kontent = "Rəqəmsal Kontent",
  metodik_vesait = "Metodik Vəsait",
  derslik = "Dərslik"
)

# === Tədqiqat Statusları ===
RESEARCH_STATUS <- c(
  fundamental = "Fundamental",
  tetbiqi = "Tətbiqi",
  siyaset_analizi = "Siyasət Analizi"
)

# === Kurs Statusları ===
COURSE_STATUS <- c(
  draft = "Qaralama",
  published = "Nəşr edilmiş",
  archived = "Arxivləşdirilmiş"
)

# === Olimpiada Fənləri ===
OLYMPIAD_SUBJECTS <- c(
  "Riyaziyyat", "Fizika", "Kimya", "Biologiya", "İnformatika",
  "Azərbaycan dili", "İngilis dili", "Tarix", "Coğrafiya"
)

# === Sistem Limitləri ===
SYSTEM_LIMITS <- list(
  max_upload_mb = 50, max_students_per_class = 35,
  max_weekly_hours_teacher = 36, min_weekly_hours_teacher = 18,
  session_timeout_minutes = 60, max_login_attempts = 5
)

# === İnstitut Strukturu Sabitləri ===

# Təşkilati vahid növləri
UNIT_TYPES <- c(
  rehberlik    = "Rəhbərlik",
  merkez       = "Mərkəz",
  shobe        = "Şöbə",
  laboratoriya = "Laboratoriya",
  bolme        = "Bölmə"
)

# İnstitut resurs növləri
INST_RESOURCE_TYPES <- c(
  budce     = "Büdcə",
  avadanliq = "Avadanlıq",
  sahe      = "Sahə (kv.m)",
  proqram   = "Proqram Təminatı",
  neqliyyat = "Nəqliyyat"
)

# Resurs vəziyyəti
RESOURCE_CONDITION <- c(
  ela       = "Əla",
  yaxsi     = "Yaxşı",
  kafi      = "Kafi",
  kohnelmis = "Köhnəlmiş"
)

# Personal növləri
PERSONNEL_TYPES <- c(
  emedkas    = "Əməkdaş",
  tedqiqatci = "Tədqiqatçı",
  doktorant  = "Doktorant",
  muqavile   = "Müqavilə ilə",
  tecrubechi = "Təcrübəçi"
)

# Məşğulluq növləri
EMPLOYMENT_TYPES <- c(
  tam_shtat  = "Tam ştat",
  yarim_shtat = "Yarım ştat",
  muqavile   = "Müqavilə",
  konullu    = "Könüllü"
)

# Fəaliyyət kateqoriyaları
ACTIVITY_CATEGORIES <- c(
  tedris     = "Tədris",
  tedqiqat   = "Tədqiqat",
  metodik    = "Metodik",
  innovasiya = "İnnovasiya",
  beynelxalq = "Beynəlxalq",
  texnoloji  = "Texnoloji"
)

# KPI tezliyi
KPI_FREQUENCY <- c(
  gunluk   = "Günlük",
  heftelik = "Həftəlik",
  ayliq    = "Aylıq",
  rublik   = "Rüblük",
  illik    = "İllik"
)

# Layihə prioriteti
PROJECT_PRIORITY <- c(
  cox_yuksek = "Çox Yüksək",
  yuksek     = "Yüksək",
  orta       = "Orta",
  asagi      = "Aşağı"
)

# İnstitut layihə statusları
INST_PROJECT_STATUS <- c(
  planlasdirilan = "Planlaşdırılan",
  aktiv          = "Aktiv",
  dayandirilan   = "Dayandırılan",
  tamamlanmis    = "Tamamlanmış",
  legv           = "Ləğv edilmiş"
)

# === Müəllim Genişləndirilmiş Göstəriciləri ===

# Fəxri adlar
HONORARY_TITLES <- c(
  "Əməkdar müəllim",
  "Xalq müəllimi",
  "Qabaqcıl təhsil işçisi",
  "Fəxri pedaqoq",
  "İlin müəllimi"
)

# İKT kompetensiya səviyyələri
ICT_COMPETENCY_LEVELS <- c(
  baslangic   = "Başlanğıc",
  orta        = "Orta",
  irelilemis  = "İrəliləmiş",
  ekspert     = "Ekspert"
)

# Mentorluq statusları
MENTORING_STATUS <- c(
  mentor  = "Mentor",
  mentee  = "Mentee",
  both    = "Hər ikisi",
  none    = "Yoxdur"
)

# Mükafat növləri
AWARD_TYPES <- c(
  dovlet      = "Dövlət mükafatı",
  nazirlik    = "Nazirlik mükafatı",
  mekteb      = "Məktəb mükafatı",
  beynelxalq  = "Beynəlxalq mükafat"
)

# Nəşr növləri
PUBLICATION_TYPES <- c(
  meqale              = "Məqalə",
  kitab               = "Kitab",
  konfrans_materiali  = "Konfrans materialı",
  metodik_vesait      = "Metodik vəsait"
)

# TALIS benchmark göstəriciləri (OECD ortalamaları)
TALIS_BENCHMARKS <- list(
  self_efficacy        = list(min = 1, max = 10, oecd_avg = 7.2, label = "Öz-effektivlik"),
  job_satisfaction     = list(min = 1, max = 10, oecd_avg = 7.5, label = "İş məmnuniyyəti"),
  classroom_management = list(min = 1, max = 10, oecd_avg = 7.0, label = "Sinif idarəetməsi"),
  cpd_hours            = list(min = 0, max = 500, oecd_avg = 60,  label = "PKİ saatları"),
  cpd_impact           = list(min = 1, max = 10, oecd_avg = 6.5, label = "PKİ təsiri"),
  collaboration        = list(min = 1, max = 10, oecd_avg = 6.8, label = "Həmkar əməkdaşlığı"),
  student_pass_rate    = list(min = 0, max = 100, oecd_avg = 78,  label = "Keçid faizi"),
  ict_usage            = list(min = 1, max = 10, oecd_avg = 6.0, label = "İKT istifadəsi"),
  value_added          = list(min = -5, max = 5, oecd_avg = 0.0, label = "Əlavə dəyər")
)

# İKT istifadə tezliyi
ICT_USAGE_FREQUENCY <- c(
  her_ders  = "Hər dərs",
  heftelik  = "Həftəlik",
  ayliq     = "Aylıq",
  nadir     = "Nadir"
)
