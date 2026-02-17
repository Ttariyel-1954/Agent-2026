# ARTI-2026 Arxitektura Sənədi

## 1. Ümumi Baxış

ARTI-2026 Azərbaycan təhsil institutları üçün hərtərəfli idarəetmə sistemidir. Sistem R/Shiny texnologiyası üzərində qurulub və modular arxitektura prinsiplərinə əsaslanır.

## 2. Texnologiya Yığını

| Komponent | Texnologiya | Versiya |
|-----------|-------------|---------|
| Frontend | R Shiny + shinydashboardPlus | 4.x |
| Backend | R + Shiny Server | 4.3+ |
| Verilənlər Bazası | PostgreSQL | 15+ |
| Bağlantı Havuzu | pool (R) | 1.0+ |
| AI İnteqrasiya | Claude API, GPT API | - |
| Konteynerləşdirmə | Docker + Docker Compose | 24+ |
| Reverse Proxy | Nginx | 1.24+ |
| Autentifikasiya | JWT (jose R paketi) | - |

## 3. Sistem Arxitekturası

```
┌─────────────────────────────────────────────────┐
│                   Nginx (Reverse Proxy)          │
│                   :80 / :443 (SSL)               │
└──────────────────────┬──────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────┐
│              R Shiny Server (:3838)              │
│  ┌────────────────────────────────────────────┐  │
│  │              app.R (Əsas Giriş)            │  │
│  │  ┌──────────┐ ┌──────────┐ ┌───────────┐  │  │
│  │  │ Student  │ │ Teacher  │ │Assessment │  │  │
│  │  │ Module   │ │ Module   │ │  Module   │  │  │
│  │  └──────────┘ └──────────┘ └───────────┘  │  │
│  │  ┌──────────┐ ┌──────────┐ ┌───────────┐  │  │
│  │  │Curriculum│ │Analytics │ │    AI     │  │  │
│  │  │ Module   │ │ Module   │ │Integration│  │  │
│  │  └──────────┘ └──────────┘ └───────────┘  │  │
│  └────────────────────────────────────────────┘  │
│              R/ (Paylaşılan Funksiyalar)          │
│   ┌──────┐ ┌───────┐ ┌──────────┐ ┌──────┐      │
│   │utils │ │  auth  │ │db_connect│ │const │      │
│   └──────┘ └───────┘ └──────────┘ └──────┘      │
└──────────────────────┬──────────────────────────┘
                       │ pool
┌──────────────────────▼──────────────────────────┐
│            PostgreSQL 15+ (:5432)                │
│  ┌─────────┐ ┌──────────┐ ┌─────────────────┐   │
│  │ Tables  │ │Functions │ │Materialized View│   │
│  └─────────┘ └──────────┘ └─────────────────┘   │
└─────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────┐
│              Xarici Xidmətlər                    │
│  ┌──────────┐ ┌──────────┐ ┌─────────────────┐  │
│  │Claude API│ │ GPT API  │ │   SMTP Server   │  │
│  └──────────┘ └──────────┘ └─────────────────┘  │
└─────────────────────────────────────────────────┘
```

## 4. Modul Strukturu

Hər modul Shiny Module pattern-nə uyğundur:

```
modules/
├── module_name/
│   ├── module_ui.R         # UI funksiyaları (NS)
│   ├── module_server.R     # Server funksiyaları (moduleServer)
│   └── module_helpers.R    # Köməkçi funksiyalar
```

### 4.1 Şagird Modulu (`modules/student/`)
- Siyahı, qeydiyyat, davamiyyət, profil, FİP
- CRUD əməliyyatları, Excel ixrac, risk analizi

### 4.2 Müəllim Modulu (`modules/teacher/`)
- Siyahı, iş yükü, peşəkar inkişaf, performans
- Cədvəl idarəetmə, KPI hesablama, qiymətləndirmə

### 4.3 Qiymətləndirmə Modulu (`modules/assessment/`)
- **IRT Motor**: 1PL/2PL/3PL modellər, MLE/EAP theta, Fisher informasiya
- **CAT Motor**: MFI sual seçimi, Sympson-Hetter exposure control, SE dayandırma
- **MST Motor**: 1-3-3 panel dizayn, MLE routing, modul qiymətləndirmə
- **Sual Bankı**: CRUD, IRT kalibrasiya, statistika, ixrac/idxal

### 4.4 Kurikulum Modulu (`modules/curriculum/`)
- Standartlar idarəetmə, Webb DOK uyğunluq analizi
- Beynəlxalq müqayisə (PISA/TIMSS)

### 4.5 Analitika Modulu (`modules/analytics/`)
- Məktəb dashboard, hesabat generasiya
- Prediktiv analitika (RF, Logistic, GBM)

## 5. Verilənlər Bazası Arxitekturası

### Əsas Cədvəllər
- `users` - İstifadəçilər (admin, müəllim, şagird, valideyn)
- `schools` - Məktəblər
- `classes` - Siniflər (generated education_level sütunu)
- `students` - Şagirdlər (FIN ilə unikal)
- `teachers` - Müəllimlər (kateqoriya sistemi)
- `subjects` - Fənnlər (15 əsas fənn)
- `grades` - Qiymətlər (gündəlik, KSA, BSA, yarımill, illik)
- `attendance` - Davamiyyət (7 dərs saatı)

### Qiymətləndirmə Cədvəlləri
- `items` - Sual bankı (IRT parametrləri ilə)
- `tests`, `test_sessions`, `test_responses` - Test idarəetmə
- `assessment_alignment` - Standart-sual uyğunluğu
- `curriculum_standards` - Kurikulum standartları

### Materialized Views
- `mv_student_performance` - Şagird performans xülasəsi
- `mv_attendance_summary` - Davamiyyət xülasəsi

## 6. Autentifikasiya Axını

```
İstifadəçi → Login Form → password verification → JWT Token yaradılma
    → Session saxlama → Hər sorğuda JWT yoxlama → Rol əsaslı icazə
```

- JWT token 8 saat etibarlıdır
- 5 uğursuz cəhddən sonra 15 dəqiqə kilidlənmə
- Bütün login cəhdləri loglanır

## 7. AI İnteqrasiya Arxitekturası

```
İstifadəçi Sorğusu → Provider Seçimi (Claude/GPT)
    → Prompt Template yükləmə → API Sorğusu
    → Cavab Emalı (JSON/Markdown) → UI-da göstərmə
```

- Prompt şablonları `ai_integration/prompt_templates/` qovluğunda
- `response_parser.R` bütün AI cavablarını emal edir
- Token istifadəsi loglanır

## 8. Deployment Arxitekturası

```
Docker Compose
├── app (R Shiny) - port 3838
├── db (PostgreSQL) - port 5432
└── nginx (Reverse Proxy) - port 80/443
```

## 9. Təhlükəsizlik

- SQL injection qoruması: parametrli sorğular
- XSS qoruması: Shiny-nin daxili sanitizasiyası
- CSRF: Shiny token mexanizmi
- Şifrə hashing: bcrypt (sodium paketi)
- Audit log: bütün kritik əməliyyatlar loglanır
