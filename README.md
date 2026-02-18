# ARTI-2026

**Azərbaycan Respublikası Təhsil İnstitutunun Hərtərəfli İdarəetmə Sistemi**

ARTI-2026 Azərbaycan təhsil institutları üçün nəzərdə tutulmuş, süni intellekt dəstəkli, tam funksional idarəetmə platformasıdır. Sistem R/Shiny + Python dual-stack arxitekturasında qurulub, PostgreSQL verilənlər bazası ilə işləyir və 10 əsas moduldan ibarətdir.

---

## Əsas Funksionallıqlar

| Modul | Təsvir |
|-------|--------|
| **Şagird İdarəetməsi** | Qeydiyyat, davamiyyət, akademik profil, fərdi inkişaf planı (FİP) |
| **Müəllim İdarəetməsi** | Kadr uçotu, dərs yükü, performans qiymətləndirmə |
| **Qiymətləndirmə** | IRT/CAT/MST əsaslı adaptiv test sistemi, sual bankı |
| **Kurikulum** | Standartlar, beynəlxalq müqayisə, uyğunluq analizi |
| **Analitika** | Məktəb dashboardu, prediktiv analitika, hesabatlar |
| **Sertifikasiya** | İşə qəbul imtahanları, sertifikasiya, sual bazası, avtomatlaşdırma |
| **Tədris Resursları** | Tədris proqramları, rəqəmsal kontent, dərslik kataloqu |
| **Tədqiqat** | Tədqiqat layihələri, siyasət analizi, doktorantura proqramları |
| **Peşəkar İnkişaf** | Müəllim təlimləri, onlayn kurslar, mentorluq proqramları |
| **Beynəlxalq Əməkdaşlıq** | Olimpiadalar, STEAM layihələri, partnyor proqramları |
| **AI Köməkçi** | Claude/GPT ilə sual generasiyası, kurikulum analizi, geri bildirim |

---

## Texnologiya Yığını

| Komponent | Texnologiya |
|-----------|-------------|
| Frontend | R Shiny, shinydashboardPlus, bslib, plotly, DT |
| Backend | R (Shiny Server) + Python |
| Verilənlər Bazası | PostgreSQL 15+ |
| Süni İntellekt | Claude API (Anthropic), GPT API (OpenAI) |
| Keş | Redis |
| Autentifikasiya | JWT (HS256), bcrypt |
| Deployment | Docker, Docker Compose, Nginx |
| Monitorinq | Prometheus |
| Test | testthat, shinytest2, pytest |

---

## Tez Başlanğıc

### Tələblər

- R >= 4.3.0
- Python >= 3.10
- PostgreSQL >= 15
- Redis (istəyə bağlı)
- Docker & Docker Compose (deployment üçün)

### Quraşdırma

```bash
# 1. Reponu klonlayın
git clone https://github.com/Ttariyel-1954/Agent-2026.git
cd Agent-2026

# 2. Mühit dəyişənlərini konfiqurasiya edin
cp .env.example .env
# .env faylını öz parametrlərinizlə doldurun (DB_PASSWORD, JWT_SECRET, API açarları)

# 3. Python asılılıqlarını quraşdırın
pip install -r requirements.txt

# 4. Verilənlər bazasını yaradın
createdb -U postgres arti_2026
psql -U postgres -d arti_2026 -c "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"; CREATE EXTENSION IF NOT EXISTS \"pgcrypto\";"
psql -U postgres -d arti_2026 -f database/schema/tables.sql
psql -U postgres -d arti_2026 -f database/migrations/001_initial.sql
psql -U postgres -d arti_2026 -f database/migrations/002_assessment.sql
psql -U postgres -d arti_2026 -f database/migrations/003_analytics.sql
psql -U postgres -d arti_2026 -f database/migrations/004_new_modules.sql
psql -U postgres -d arti_2026 -f database/functions/stored_procedures.sql
psql -U postgres -d arti_2026 -f database/seeds/sample_data.sql

# 5. Tətbiqi işə salın
Rscript app.R
```

### Docker ilə işə salma

```bash
docker-compose up -d
```

Tətbiq `http://localhost:3838` ünvanında əlçatan olacaq.

### Nümunə giriş məlumatları

| Rol | İstifadəçi adı | Şifrə |
|-----|----------------|-------|
| Admin | `admin` | `Admin2026!` |
| Müəllim | `mammadov.eldar` | `Teacher2026!` |
| Şagird | `hasanov.ali` | `Student2026!` |

---

## Layihə Strukturu

```
Arti_2026/
├── app.R                                       # Əsas Shiny giriş nöqtəsi (801 sətir)
├── config.yml                                  # Tətbiq konfiqurasiyası
├── .env                                        # Mühit dəyişənləri (git-ə daxil deyil)
├── .env.example                                # .env nümunə şablonu
├── .gitignore
├── CLAUDE.md                                   # Layihə qaydaları (AI üçün)
├── Makefile
├── README.md                                   # Bu fayl
├── requirements.txt                            # Python asılılıqları
├── docker-compose.yml
├── Arti_2026_Telimat.docx                      # Layihə təlimatı
│
├── R/                                          # Paylaşılan R funksiyaları
│   ├── auth.R                                  #   JWT autentifikasiya, login/logout, icazə yoxlama
│   ├── constants.R                             #   Sabitlər (qiymət şkalası, fənlər, IRT/CAT/MST)
│   ├── db_connection.R                         #   PostgreSQL pool, sorğu funksiyaları
│   └── utils.R                                 #   Format, validasiya, bildiriş, ixrac
│
├── modules/                                    # ══════ Funksional Modullar ══════
│   ├── __init__.py
│   │
│   ├── student/                                # ── Şagird Modulu (R/Shiny) ──
│   │   ├── student_ui.R                        #   Siyahı, qeydiyyat, davamiyyət, profil, FİP UI
│   │   ├── student_server.R                    #   CRUD, filtr, cədvəl, modal server
│   │   └── student_helpers.R                   #   validate_student_data(), calculate_gpa()
│   │
│   ├── teacher/                                # ── Müəllim Modulu (R/Shiny) ──
│   │   ├── teacher_ui.R                        #   Siyahı, dərs yükü, inkişaf, performans UI
│   │   ├── teacher_server.R                    #   Müəllim CRUD, cədvəl idarəetmə
│   │   └── teacher_helpers.R                   #   validate_teacher_data(), calculate_workload()
│   │
│   ├── assessment/                             # ── Qiymətləndirmə Modulu ──
│   │   ├── item_bank.R                         #   Sual bankı idarəetmə (R)
│   │   ├── irt_engine.R                        #   IRT kalibrasiya mühərriki (1PL/2PL/3PL)
│   │   ├── cat_engine.R                        #   Kompüterləşdirilmiş Adaptiv Test (R)
│   │   ├── mst_engine.R                        #   Çoxmərhələli Test mühərriki (R)
│   │   ├── __init__.py
│   │   ├── cat/engine/cat_engine.py            #   CAT mühərrik (Python implementasiya)
│   │   ├── mst/engine/mst_engine.py            #   MST mühərrik (Python implementasiya)
│   │   ├── item_bank/
│   │   │   ├── creation/item_generator.py      #   AI ilə sual generasiyası
│   │   │   └── irt_analysis/irt_calibration.py #   IRT parametr kalibrasiyası
│   │   ├── online_collection/
│   │   │   └── api/collection_api.py           #   Onlayn data toplama API
│   │   └── analytics/
│   │       └── school/school_analytics.py      #   Məktəb səviyyəli analitika
│   │
│   ├── curriculum/                             # ── Kurikulum Modulu ──
│   │   ├── standards.R                         #   Kurikulum standartları idarəetmə
│   │   ├── comparison.R                        #   Beynəlxalq müqayisə (7 ölkə)
│   │   ├── alignment.R                         #   Standart-sual uyğunluq analizi
│   │   ├── __init__.py
│   │   └── programs/curriculum_manager.py      #   Proqram idarəetmə (Python)
│   │
│   ├── analytics/                              # ── Analitika Modulu (R/Shiny) ──
│   │   ├── school_dashboard.R                  #   Məktəb dashboard (plotly qrafiklər)
│   │   ├── reports.R                           #   PDF/Excel/CSV hesabat generasiyası
│   │   └── predictions.R                       #   Prediktiv analitika (random forest)
│   │
│   ├── certification/                          # ── Sertifikasiya Modulu (R/Shiny) ── ★ YENİ
│   │   ├── certification_ui.R                  #   İmtahan, sertifikasiya, sual bazası, avtomatlaşdırma UI
│   │   ├── certification_server.R              #   İmtahan CRUD, nəticə qiymətləndirmə, planlaşdırma
│   │   ├── certification_helpers.R             #   validate_exam_data(), calculate_exam_results(),
│   │   │                                       #   generate_certificate()
│   │   ├── __init__.py
│   │   ├── recruitment_exams/
│   │   │   └── exam_engine/exam_runner.py      #   İşə qəbul imtahan mühərriki
│   │   ├── certification_exams/
│   │   │   └── exam_engine/certification_runner.py  # Sertifikasiya imtahan mühərriki
│   │   └── automation/
│   │       └── workflow/exam_workflow.py        #   İmtahan iş axını avtomatlaşdırma
│   │
│   ├── resources/                              # ── Tədris Resursları Modulu (R/Shiny) ── ★ YENİ
│   │   ├── resources_ui.R                      #   Proqramlar, rəqəmsal kontent, dərsliklər UI
│   │   ├── resources_server.R                  #   Resurs CRUD, fayl yükləmə, kontent axtarışı
│   │   └── resources_helpers.R                 #   validate_resource(), search_resources(),
│   │                                           #   format_resource_metadata()
│   │
│   ├── research/                               # ── Tədqiqat Modulu (R/Shiny) ── ★ YENİ
│   │   ├── research_ui.R                       #   Tədqiqatlar, siyasət analizi, doktorantura UI
│   │   ├── research_server.R                   #   Layihə CRUD, nəşr idarəetmə, doktorant qeydiyyatı
│   │   ├── research_helpers.R                  #   validate_research_data(), calculate_research_metrics()
│   │   ├── __init__.py
│   │   └── projects/research_manager.py        #   Tədqiqat layihə idarəetmə (Python)
│   │
│   ├── development/                            # ── Peşəkar İnkişaf Modulu (R/Shiny) ── ★ YENİ
│   │   ├── development_ui.R                    #   Təlimlər, onlayn kurslar, mentorluq UI
│   │   ├── development_server.R                #   Təlim CRUD, kurs idarəetmə, mentor uyğunlaşdırma
│   │   └── development_helpers.R               #   validate_training(), calculate_development_score(),
│   │                                           #   match_mentor()
│   │
│   ├── international/                          # ── Beynəlxalq Əməkdaşlıq Modulu (R/Shiny) ── ★ YENİ
│   │   ├── international_ui.R                  #   Olimpiadalar, STEAM, partnyorlar UI
│   │   ├── international_server.R              #   Olimpiada qeydiyyat, layihə idarəetmə, partnyor əlaqələri
│   │   ├── international_helpers.R             #   validate_olympiad_data(), calculate_competition_stats()
│   │   ├── __init__.py
│   │   └── olympiads/olympiad_manager.py       #   Olimpiada idarəetmə (Python)
│   │
│   ├── professional_dev/                       # ── Peşəkar İnkişaf (Python) ──
│   │   ├── __init__.py
│   │   └── training/training_manager.py        #   Təlim proqramı idarəetmə
│   │
│   └── school_network/                         # ── Məktəb Şəbəkəsi (Python) ──
│       ├── __init__.py
│       └── data_collection/
│           └── school_data_collector.py        #   Məktəb data toplama
│
├── ai_integration/                             # ══════ AI İnteqrasiya ══════
│   ├── claude_api.R                            #   Anthropic Claude API çağırışları
│   ├── gpt_api.R                               #   OpenAI GPT API çağırışları
│   ├── response_parser.R                       #   AI cavab parsing və formatlaşdırma
│   └── prompt_templates/                       #   Prompt şablonları
│       ├── curriculum_analysis.txt             #     Kurikulum analizi promptu
│       ├── question_generation.txt             #     Sual generasiyası promptu
│       └── student_feedback.txt                #     Şagird geri bildirimi promptu
│
├── agent/                                      # ══════ Python Agent Sistemi ══════
│   ├── __init__.py
│   ├── Dockerfile
│   ├── config/settings.py                      #   Agent konfiqurasiyası
│   ├── core/
│   │   ├── engine.py                           #   Agent mühərriki
│   │   ├── main.py                             #   Giriş nöqtəsi
│   │   ├── router.py                           #   Sorğu yönləndirmə
│   │   └── state.py                            #   Vəziyyət idarəetmə
│   ├── plugins/base_plugin.py                  #   Plugin bazası
│   └── skills/base_skill.py                    #   Skill bazası
│
├── database/                                   # ══════ Verilənlər Bazası ══════
│   ├── schema/
│   │   └── tables.sql                          #   Əsas sxem — 49 cədvəl
│   ├── migrations/
│   │   ├── 001_initial.sql                     #   İlkin sxem (users, schools, students, teachers...)
│   │   ├── 002_assessment.sql                  #   Qiymətləndirmə (items, tests, test_sessions...)
│   │   ├── 003_analytics.sql                   #   Analitika (FİP, cədvəl, materialized views...)
│   │   └── 004_new_modules.sql                 #   5 yeni modul (19 cədvəl, 25 indeks) ★ YENİ
│   ├── functions/
│   │   └── stored_procedures.sql               #   9 funksiya + 5 trigger
│   └── seeds/
│       └── sample_data.sql                     #   Nümunə verilənlər (14 user, 3 məktəb, 15 fənn...)
│
├── data/                                       # ══════ Statik Data ══════
│   ├── curriculum_standards/                   #   Kurikulum standartları
│   ├── item_banks/                             #   Sual bankı faylları
│   ├── sample_reports/                         #   Nümunə hesabatlar
│   ├── schemas/models.py                       #   Data modelləri
│   └── sample/
│       ├── questions/sample_math_questions.json #   Riyaziyyat nümunə sualları
│       ├── schools/schools.json                #   Məktəb nümunə datası
│       ├── students/students.json              #   Şagird nümunə datası
│       └── teachers/teachers.json              #   Müəllim nümunə datası
│
├── apps/admin_dashboard/                       # ══════ Admin Dashboard-lar ══════
│   ├── main_dashboard/app.R                    #   Əsas admin dashboard
│   ├── assessment_dashboard/app.R              #   Qiymətləndirmə dashboard
│   ├── certification_dashboard/app.R           #   Sertifikasiya dashboard
│   ├── research_dashboard/app.R                #   Tədqiqat dashboard
│   ├── school_network_dashboard/app.R          #   Məktəb şəbəkəsi dashboard
│   ├── server_monitor_dashboard/app.R          #   Server monitorinq
│   └── training_dashboard/app.R                #   Təlim dashboard
│
├── infrastructure/                             # ══════ İnfrastruktur ══════
│   ├── __init__.py
│   ├── api/gateway/main.py                     #   API gateway
│   ├── backup/strategies/backup_config.py      #   Backup konfiqurasiyası
│   ├── database/schemas/001_init.sql           #   İnfrastruktur DB sxemi
│   ├── monitoring/prometheus/prometheus.yml    #   Prometheus konfiqurasiyası
│   ├── security/authentication/auth_service.py #   Autentifikasiya servisi
│   └── server/nginx/nginx.conf                 #   Nginx konfiqurasiyası
│
├── deploy/                                     # ══════ Deployment ══════
│   ├── Dockerfile                              #   Docker image
│   ├── docker-compose.yml                      #   Multi-container orkestrasiya
│   ├── nginx.conf                              #   Nginx reverse proxy
│   └── scripts/
│       ├── backup.sh                           #   Avtomatik backup skripti
│       └── deploy.sh                           #   Deployment avtomatlaşdırma
│
├── scripts/                                    # ══════ Əlavə Skriptlər ══════
│   ├── data_tools/seed_database.py             #   DB seed etmə aləti
│   ├── maintenance/backup.sh                   #   Texniki xidmət backup
│   └── setup/init_project.sh                   #   Layihə ilkin quraşdırma
│
├── tests/                                      # ══════ Testlər ══════
│   ├── test_cat.R                              #   CAT mühərrik testləri
│   ├── test_database.R                         #   DB bağlantı testləri
│   ├── test_irt.R                              #   IRT kalibrasiya testləri
│   └── unit/modules/test_cat_engine.py         #   Python unit testlər
│
├── docs/                                       # ══════ Sənədlər ══════
│   ├── api_reference.md                        #   API istinad sənədi
│   ├── architecture.md                         #   Sistem arxitekturası
│   ├── architecture/system_overview.md         #   Sistem icmalı
│   ├── deployment_guide.md                     #   Deployment təlimatı
│   └── user_guide.md                           #   İstifadəçi təlimatı
│
├── www/                                        # ══════ Statik Web Resurslar ══════
│   ├── css/custom.css                          #   Xüsusi stillər
│   ├── js/custom.js                            #   Xüsusi JavaScript
│   ├── img/logo.png                            #   Layihə logosu
│   └── fonts/                                  #   Şriftlər
│
└── logs/
    └── arti_2026.log                           #   Tətbiq logları
```

---

## Verilənlər Bazası Sxemi

Sistem 49 PostgreSQL cədvəli ilə işləyir. Əsas cədvəl qrupları:

### Əsas Cədvəllər (Migration 001)
| Cədvəl | Təsvir |
|--------|--------|
| `users` | Bütün istifadəçilər (admin, müəllim, şagird, valideyn) |
| `schools` | Məktəb məlumatları |
| `subjects` | Fənn tərifləri (15 fənn) |
| `classes` | Sinif/bölmə təyinatları (1-11-ci sinif, A-D bölmə) |
| `students` | Şagird qeydləri (FİN, şəxsi məlumatlar) |
| `teachers` | Müəllim qeydləri (kateqoriya, ixtisas) |
| `grades` | Qiymətlər (KSA, BSA, yarımillik, illik) |
| `attendance` | Davamiyyət (dərs saatı dəqiqliyi ilə) |
| `notifications` | Bildirişlər |
| `audit_log` | Sistem logları |

### Qiymətləndirmə Cədvəlləri (Migration 002)
| Cədvəl | Təsvir |
|--------|--------|
| `curriculum_standards` | Kurikulum standartları (Bloom, DOK) |
| `items` | Test sualları (IRT parametrləri: a, b, c) |
| `tests` | Test tərifləri (CAT, MST, Fixed, Practice) |
| `test_sessions` | Test sessiyaları (theta, SE) |
| `test_responses` | Şagird cavabları |

### Analitika Cədvəlləri (Migration 003)
| Cədvəl | Təsvir |
|--------|--------|
| `teacher_schedule` | Dərs cədvəli |
| `teacher_trainings` | Müəllim təlimləri |
| `teacher_evaluations` | Performans qiymətləndirmə (5 meyar) |
| `individual_plans` | Fərdi İnkişaf Planı (FİP) |
| `mv_student_performance` | Materialized view — performans |
| `mv_attendance_summary` | Materialized view — davamiyyət |

### Yeni Modul Cədvəlləri (Migration 004)
| Cədvəl | Modul | Təsvir |
|--------|-------|--------|
| `certification_exams` | Sertifikasiya | İmtahan tərifləri |
| `certification_results` | Sertifikasiya | Nəticələr və sertifikatlar |
| `certification_questions` | Sertifikasiya | Sual bazası |
| `resource_categories` | Resurslar | Resurs kateqoriyaları |
| `teaching_resources` | Resurslar | Tədris resursları |
| `textbooks` | Resurslar | Dərslik kataloqu |
| `research_projects` | Tədqiqat | Tədqiqat layihələri |
| `research_publications` | Tədqiqat | Elmi nəşrlər |
| `doctoral_programs` | Tədqiqat | Doktorantura proqramları |
| `doctoral_students` | Tədqiqat | Doktorant qeydləri |
| `training_programs` | İnkişaf | Təlim proqramları |
| `online_courses` | İnkişaf | Onlayn kurslar |
| `course_enrollments` | İnkişaf | Kurs qeydiyyatları |
| `mentorship_programs` | İnkişaf | Mentorluq proqramları |
| `mentorship_pairs` | İnkişaf | Mentor-mentee cütləri |
| `olympiads` | Beynəlxalq | Olimpiadalar |
| `olympiad_participants` | Beynəlxalq | Olimpiada iştirakçıları |
| `steam_projects` | Beynəlxalq | STEAM layihələri |
| `partner_programs` | Beynəlxalq | Partnyor proqramları |

---

## Modulların Təfsilatlı Təsviri

### 1. Şagird Modulu (`modules/student/`)
- **Siyahı** — şagird axtarışı, filtr (sinif, status), Excel ixracı
- **Qeydiyyat** — yeni şagird əlavə etmə, FİN validasiyası
- **Davamiyyət** — gündəlik dərs saatı üzrə davamiyyət qeydləri
- **Akademik Profil** — fənn üzrə qiymət trendi, müqayisə
- **Fərdi İnkişaf Planı** — hədəf bali, irəliləyiş izləmə

### 2. Müəllim Modulu (`modules/teacher/`)
- **Siyahı** — müəllim axtarışı, kateqoriya filtri
- **Dərs Yükü** — həftəlik cədvəl, saat hesablama
- **Peşəkar İnkişaf** — təlim tarixçəsi, sertifikatlar
- **Performans** — 5 meyarlı qiymətləndirmə (1-5 bal)

### 3. Qiymətləndirmə Modulu (`modules/assessment/`)
- **Sual Bankı** — çoxseçimli, doğru/yanlış, esse, uyğunlaşdırma
- **IRT Analiz** — 1PL/2PL/3PL model, parametr kalibrasiyası
- **CAT Test** — adaptiv sual seçimi (MFI), theta kəsiyliyi, SE eşiyi
- **MST Test** — 3 mərhələli, 7 modullu çoxmərhələli test

### 4. Sertifikasiya Modulu (`modules/certification/`) ★
- **İşə Qəbul İmtahanları** — fənn üzrə imtahan CRUD, nəticə izləmə
- **Sertifikasiya İmtahanları** — 4 səviyyə (əsas, orta, ali, ekspert)
- **Sual Bazası** — çətinlik, Bloom, bal üzrə sual idarəetmə
- **Avtomatlaşdırma** — imtahan planlaşdırma, avtomatik qiymətləndirmə

### 5. Tədris Resursları Modulu (`modules/resources/`) ★
- **Tədris Proqramları** — fənn/sinif üzrə proqram kataloqu
- **Rəqəmsal Kontent** — video, audio, sənəd, təqdimat, interaktiv
- **Dərsliklər** — ISBN, nəşriyyat, təsdiq statusu ilə kataloq

### 6. Tədqiqat Modulu (`modules/research/`) ★
- **Tədqiqatlar** — fundamental/tətbiqi/siyasət analizi layihələri
- **Siyasət Analizi** — nəşr idarəetmə (DOI, jurnal, istinad)
- **Doktorantura** — proqram, doktorant, dissertasiya, elmi rəhbər

### 7. Peşəkar İnkişaf Modulu (`modules/development/`) ★
- **Müəllim Təlimləri** — seminar, workshop, konfrans, sertifikatlı
- **Onlayn Kurslar** — modul əsaslı, qeydiyyat, irəliləyiş, reytinq
- **Mentorluq** — proqram yaratma, cüt əlaqələndirmə, avtomatik uyğunlaşdırma

### 8. Beynəlxalq Əməkdaşlıq Modulu (`modules/international/`) ★
- **Olimpiadalar** — məktəb/rayon/respublika/beynəlxalq, medal statistikası
- **STEAM Layihələri** — elm/texnologiya/mühəndislik/sənət/riyaziyyat
- **Partnyor Proqramları** — universitet, təşkilat, hökumət, QHT əlaqələri

---

## Konfiqurasiya

### Mühit Dəyişənləri (`.env`)

| Dəyişən | Təsvir | Nümunə |
|---------|--------|--------|
| `DB_HOST` | Verilənlər bazası hostu | `localhost` |
| `DB_PORT` | Verilənlər bazası portu | `5432` |
| `DB_NAME` | Verilənlər bazası adı | `arti_2026` |
| `DB_USER` | DB istifadəçisi | `arti_admin` |
| `DB_PASSWORD` | DB şifrəsi | `****` |
| `JWT_SECRET` | JWT imzalama açarı | `****` |
| `JWT_EXPIRY_HOURS` | Token müddəti | `24` |
| `CLAUDE_API_KEY` | Anthropic API açarı | `sk-ant-...` |
| `OPENAI_API_KEY` | OpenAI API açarı | `sk-...` |
| `APP_PORT` | Tətbiq portu | `3838` |
| `LOG_LEVEL` | Loglama səviyyəsi | `INFO` |

### Tətbiq Parametrləri (`config.yml`)

- **Qiymət şkalası:** Əla (86-100), Yaxşı (71-85), Kafi (51-70), Qeyri-kafi (0-50)
- **IRT:** 2PL model, theta [-4, 4], convergence 0.001
- **CAT:** 10-50 sual, SE eşiyi 0.3, MFI sual seçimi
- **MST:** 3 mərhələ, [1, 3, 3] modul, MLE yönləndirmə
- **Təhlükəsizlik:** 60 dəq sessiya, 5 giriş cəhdi, 15 dəq bloklanma

---

## Qiymətləndirmə Şkalası

```
100 ┤████████████████  Əla (86-100)
 85 ┤██████████████    Yaxşı (71-85)
 70 ┤██████████        Kafi (51-70)
 50 ┤██████            Qeyri-kafi (0-50)
  0 ┤
```

---

## API İnteqrasiya

### Claude API
```r
call_claude_api(
  task_type = "question_gen",      # sual generasiyası
  user_input = "8-ci sinif riyaziyyat, tənliklər",
  config = app_config$ai
)
```

### GPT API
```r
call_gpt_api(
  task_type = "curriculum_analysis",
  user_input = "Riyaziyyat standartlarını Finlandiya ilə müqayisə et",
  config = app_config$ai
)
```

---

## Deployment

### Production (Docker)

```bash
# Build və run
docker-compose -f deploy/docker-compose.yml up -d

# Logları izlə
docker-compose logs -f arti-app

# Backup
bash deploy/scripts/backup.sh
```

### Nginx Reverse Proxy

Tətbiq `3838` portunda işləyir, Nginx `80/443` portlarından reverse proxy edir.

---

## İnkişaf Qaydaları

- Azərbaycan dilində şərhlər
- Dəyişən adları `snake_case`
- Hər modul `_ui.R`, `_server.R`, `_helpers.R` strukturu
- SQL injection-dan qorunmaq üçün parametrli sorğular (`$1`, `$2`)
- API açarları `.env` faylında, heç vaxt git-ə əlavə etməyin
- Miqrasiyalar ardıcıl nömrələnir: `001_`, `002_`, ...
- Hər yeni cədvəl üçün indeks yaradılmalıdır

---

## Statistika

| Metrika | Dəyər |
|---------|-------|
| Ümumi fayl sayı | ~130 |
| Kod sətirləri | 13,000+ |
| PostgreSQL cədvəlləri | 49 |
| Materialized view-lar | 2 |
| Shiny modulları | 10 |
| Python modulları | 7 |
| Admin dashboard-lar | 7 |
| Stored procedures | 9 |
| Triggers | 5 |
| DB indeksləri | 40+ |

---

## Lisenziya

Bu layihə Azərbaycan Respublikası Təhsil Nazirliyi tərəfindən dəstəklənir.
Bütün hüquqlar qorunur &copy; 2026 ARTI Komandası.
