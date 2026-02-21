"""
ARTI-2026 Voice Agent v2 — Konfiqurasiya
Whisper STT + Claude Brain + OpenAI TTS + Wake Word
"""

import os
from pathlib import Path
from dotenv import load_dotenv

# .env faylini yukle (layihe kokunden)
PROJECT_ROOT = Path(__file__).resolve().parent.parent
load_dotenv(PROJECT_ROOT / ".env")

# =============================================
# API acarlari
# =============================================
CLAUDE_API_KEY = os.getenv("CLAUDE_API_KEY", "")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")

# =============================================
# Verilənlər bazası
# =============================================
DB_CONFIG = {
    "host":     os.getenv("DB_HOST", "localhost"),
    "port":     int(os.getenv("DB_PORT", "5432")),
    "dbname":   os.getenv("DB_NAME", "arti_2026"),
    "user":     os.getenv("DB_USER", "arti_admin"),
    "password": os.getenv("DB_PASSWORD", ""),
    "sslmode":  os.getenv("DB_SSLMODE", "prefer"),
}

# =============================================
# Whisper STT parametrleri
# =============================================
WHISPER_MODEL = "whisper-1"
WHISPER_LANGUAGE = "az"
WHISPER_LANGUAGE_FALLBACK = "tr"

# Azerbaycan/Turk dili optimizasiya promptu
WHISPER_PROMPT = (
    "Bu Azərbaycan dilində təhsil sistemindəki söhbətdir. "
    "ARTI, agent, şagird, müəllim, davamiyyət, qayıb, qiymət, "
    "fənn, sinif, məktəb, riyaziyyat, fizika, kimya, biologiya, "
    "tarix, ədəbiyyat, coğrafiya, informatika, rüb, yarımil, "
    "hesabat, statistika, ortalama, keçid faizi, kurikulum"
)

# =============================================
# Audio parametrleri
# =============================================
SAMPLE_RATE = 16000
CHANNELS = 1
CHUNK_SIZE = 1024
SILENCE_THRESHOLD = 500
SILENCE_DURATION = 1.5
MAX_RECORD_SECONDS = 30

# Wake word parametrleri
WAKE_WORDS = ["arti", "artı", "agent", "hey arti", "hey artı"]
WAKE_WORD_TIMEOUT = 0.8   # Wake word-dan sonra gozlenilecek fasi (saniye)
CONTINUOUS_LISTEN = True   # Dövri dinleme rejimi

# =============================================
# OpenAI TTS parametrleri
# =============================================
TTS_MODEL = "tts-1"
TTS_VOICE = "nova"           # nova, alloy, echo, fable, onyx, shimmer
TTS_SPEED = 1.0
TTS_FORMAT = "mp3"
TTS_ENABLED = True

# =============================================
# Claude Brain parametrleri
# =============================================
CLAUDE_MODEL = "claude-sonnet-4-5-20250929"
CLAUDE_MAX_TOKENS = 2048
CLAUDE_TEMPERATURE = 0.6

# Kontekst penceresi (son nece mesaj yadda saxlansin)
CONTEXT_WINDOW = 20
CONTEXT_FILE = Path(__file__).parent / ".conversation_history.json"

# =============================================
# Sistem promptu — AI beyin
# =============================================
SYSTEM_PROMPT = f"""Sən ARTI-2026 Təhsil İdarəetmə Sisteminin səsli köməkçisisən.
Adın ARTİ-dir. Azərbaycan dilində, qısa və konkret cavab verirsən.

SƏNİN VƏZİFƏLƏRİN:
1. İstifadəçinin sualını analiz et
2. Əgər verilənlər bazasından məlumat lazımdırsa, SQL_QUERY blokundan istifadə et
3. Nəticəni sadə, danışıq dilində Azərbaycan dilində izah et
4. Rəqəmləri dəqiq ver, amma cümlələri qısa saxla (2-3 cümlə)

VERİLƏNLƏR BAZASI CƏDVƏLLƏRİ:
- schools (id, name, code, type, region, city, status) — 22 məktəb
- students (id, first_name, last_name, class_id, school_id, status)
- teachers (id, first_name, last_name, school_id, category, status)
- classes (id, school_id, grade, section, academic_year)
- grades (id, student_id, subject_id, teacher_id, score, grade_type, academic_year, grade_date)
- subjects (id, name, code, category)
- attendance (id, student_id, class_id, attendance_date, period, status)
  → status dəyərləri: 'iştirak', 'qayıb', 'gecikmə', 'icazəli', 'xəstəlik'
- teacher_evaluations (id, teacher_id, overall_score, teaching_quality)
- notifications (id, user_id, title, message, type, is_read)
- curriculum_standards (id, subject_id, grade, code, description)

QAYDA: Qiymət şkalası (Azərbaycan):
  86-100: Əla | 71-85: Yaxşı | 51-70: Kafi | 0-50: Qeyri-kafi

CAVAB FORMATI:
Əgər DB sorğusu lazımdırsa, əvvəlcə bu formatda yaz:
```sql_query
SELECT ... FROM ... WHERE ...
```
Sonra "CAVAB:" etiketindən sonra istifadəçiyə veriləcək səsli cavabı yaz.

Əgər DB sorğusu lazım deyilsə, birbaşa "CAVAB:" yaz.

NÜMUNƏLƏr:
Sual: "Bu həftə neçə şagird qayıb olub?"
```sql_query
SELECT COUNT(DISTINCT student_id) as total, s.school_id
FROM attendance a JOIN students s ON a.student_id = s.id
WHERE a.status = 'qayıb' AND a.attendance_date >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY s.school_id
```
CAVAB: Bu həftə 22 məktəbdə cəmi 47 şagird qayıb qeydə alınıb. Ən çox qayıb Məktəb 12-dədir — 8 şagird.

Sual: "Riyaziyyatdan orta bal neçədir?"
```sql_query
SELECT ROUND(AVG(g.score)::numeric, 1) as avg
FROM grades g JOIN subjects sub ON g.subject_id = sub.id
WHERE sub.name = 'Riyaziyyat' AND g.academic_year = '2025-2026'
```
CAVAB: Riyaziyyatdan ümumi orta bal 68.3-dür. Bu "Kafi" səviyyəsinə uyğun gəlir.

ÖNƏMLİ:
- CAVAB hissəsi maksimum 3 cümlə olsun (səsli oxumaq üçün qısa)
- Rəqəmləri yuvarlaqlaşdır (68.27 → 68.3)
- Mürəkkəb sorğularda 1-2 əsas faktı vurğula
- Əgər sual aydın deyilsə, qısa aydınlaşdırma sualı ver
- HEÇVAXT SQL-i istifadəçiyə göstərmə, yalnız CAVAB hissəsini danış

Layihə yeri: {PROJECT_ROOT}
Cari tədris ili: 2025-2026
"""

# =============================================
# Tehlukesizlik — Shell emrleri ucun (v1 uyumlulugu)
# =============================================
BLOCKED_PATTERNS = [
    "rm -rf /", "rm -rf ~", "rm -rf /*", "rm -rf .",
    "mkfs", "dd if=", ":()", "){", ":|:",
    "chmod -R 777 /", "drop database", "drop schema",
    "truncate", "delete from users", "delete from teachers",
    "delete from students", "shutdown", "reboot", "halt",
    "init 0", "init 6", "> /dev/sda",
    "curl | sh", "curl | bash", "wget | sh", "wget | bash",
]

ALLOWED_DIRECTORIES = [str(PROJECT_ROOT), "/tmp"]
