# 🧠 ARTİ-2026: Süni İntellekt Maksimum İnteqrasiya Strategiyası
## Azərbaycan Təhsil İnstitutu — 22 Məktəb Şəbəkəsi

**Hazırlanma tarixi:** 18 Fevral 2026  
**Məqsəd:** ARTI-2026 platformasında AI imkanlarından maksimum istifadə  
**Tətbiq müddəti:** 6 ay (3 mərhələ × 2 ay)

---

## ÜMUMİ VİZYON

ARTI-2026 sadəcə məlumat sistemi deyil — **ağıllı təhsil agenti** olmalıdır.
Hər modulda AI müəllimə, şagirdə və idarəçiyə real vaxtda kömək etməlidir.

```
┌─────────────────────────────────────────────────────────┐
│                    ARTI-2026 AI LAYERİ                   │
│                                                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐ │
│  │ Claude   │  │ Whisper  │  │ GPT-4o   │  │ Lokal    │ │
│  │ API      │  │ STT      │  │ Vision   │  │ Modellər │ │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘ │
│       └──────────────┼──────────────┼──────────────┘      │
│                      ▼                                    │
│            ┌──────────────────┐                           │
│            │  AI Router/Agent │                           │
│            └────────┬─────────┘                           │
│       ┌─────────────┼─────────────────┐                   │
│       ▼             ▼                 ▼                   │
│  ┌─────────┐  ┌──────────┐     ┌──────────┐             │
│  │Şagird AI│  │Müəllim AI│     │İdarəçi AI│             │
│  └─────────┘  └──────────┘     └──────────┘             │
└─────────────────────────────────────────────────────────┘
```

---

## MƏRHƏLƏ 1: ƏSAS AI QABLIYYƏTLƏR (Ay 1-2)
### Prioritet: Yüksək | Çətinlik: Orta

---

### 1.1 🤖 AI Sual Generatoru (Qiymətləndirmə Modulu)

**Nə edir:** Müəllim fənn, sinif, mövzu və çətinlik seçir → AI avtomatik test sualları yaradır.

**Texniki detallar:**
- Claude API: Sual mətni, variantlar, düzgün cavab, Bloom səviyyəsi
- GPT-4o: Şəkilli suallar (riyaziyyat qrafikləri, xəritələr)
- IRT parametrlərinin avtomatik təxmini
- Azərbaycan dilində grammatik yoxlama

**Claude Code tapşırığı:**
```
modules/assessment/item_bank.R faylına AI sual generasiyası əlavə et:

1. UI-da yeni düymə: "AI ilə Sual Yarat" (btn_ai_generate)
2. Modal dialog: fənn, sinif (1-11), mövzu, Bloom səviyyəsi, 
   çətinlik (asan/orta/çətin), sual sayı (1-20)
3. Server: ai_integration/claude_api.R-dan call_claude_api() çağır
4. Prompt: "Azərbaycan dilində [fənn] fənni, [sinif]-ci sinif, 
   [mövzu] mövzusu üzrə [say] ədəd [çətinlik] çətinlikdə 
   çoxseçimli test sualı yarat. Hər sual üçün: sual mətni, 
   4 variant (A,B,C,D), düzgün cavab, izah, Bloom səviyyəsi. 
   JSON formatında cavab ver."
5. Nəticə: parse_ai_response() ilə emal et, item_bank cədvəlinə yaz
6. Müəllimə redaktə imkanı ver (AI yaradır, müəllim təsdiq edir)
```

---

### 1.2 📝 Avtomatik Dərs Planı Generatoru (Kurikulum Modulu)

**Nə edir:** Müəllim mövzu seçir → AI həftəlik/aylıq dərs planı yaradır.

**Claude Code tapşırığı:**
```
modules/curriculum/standards.R faylına dərs planı generatoru əlavə et:

1. UI: "AI Dərs Planı" düyməsi
2. Parametrlər: fənn, sinif, mövzu, həftə sayı, dərs saatı
3. Claude API prompt: "Azərbaycan Kurikulum standartlarına uyğun 
   [fənn] fənni, [sinif] sinif, [mövzu] üzrə [həftə] həftəlik 
   dərs planı hazırla. Hər dərs üçün: məqsəd, fəaliyyətlər, 
   resurslar, qiymətləndirmə, ev tapşırığı, vaxt bölgüsü."
4. Nəticə: Word/PDF formatında yüklənə bilən dərs planı
5. Kurikulum standartları ilə avtomatik əlaqələndirmə
```

---

### 1.3 📊 AI Analitik Asistent (Analitika Modulu)

**Nə edir:** İdarəçi sual verir → AI data-nı analiz edib cavab verir.

**Claude Code tapşırığı:**
```
modules/analytics/school_dashboard.R-a AI analitik əlavə et:

1. UI: Söhbət interfeysi (chatbox) dashboard-un yanında
2. İstifadəçi yazır: "Hansı məktəbdə riyaziyyat nəticələri aşağıdır?"
3. Server: DB-dən müvafiq datanı çəkir, Claude API-yə göndərir
4. Claude analiz edir və cavab verir + qrafik tövsiyəsi
5. Nümunə suallar:
   - "Son 3 ayda ən çox irəliləyən məktəb hansıdır?"
   - "Davamiyyət problemi olan şagirdləri göstər"
   - "Müəllim performansını müqayisə et"
   - "Bu rübün nəticələrini xülasə et"
6. Kontekst: 22 məktəbin adları, fənlər, dövrlər
```

---

### 1.4 💬 Şagird üçün AI Tutor (Şagird Modulu)

**Nə edir:** Şagird sual verir → AI fərdi izahat verir.

**Claude Code tapşırığı:**
```
modules/student/student_profile.R-a AI tutor əlavə et:

1. UI: "AI Tutor" tab — söhbət interfeysi
2. Şagirdin profili (sinif, fənn nəticələri) kontekst kimi verilir
3. Claude API: "Sən [sinif]-ci sinif şagirdinə kömək edən 
   Azərbaycan dilində danışan müəllim assistentisən. 
   Şagirdin güclü tərəfləri: [x], zəif tərəfləri: [y]."
4. Şagird soruşur: "Kəsr ədədləri necə toplayım?"
5. AI: Addım-addım izah + nümunə + test sualı
6. Söhbət tarixçəsi saxlanılır
7. Müəllim şagirdin AI ilə söhbətlərini görə bilər
```

---

### 1.5 🔍 AI Kurikulum Müqayisəçi (Kurikulum Modulu)

**Nə edir:** Azərbaycan standartlarını beynəlxalq standartlarla müqayisə edir.

**Claude Code tapşırığı:**
```
modules/curriculum/comparison.R-da mövcud müqayisə funksiyasını 
AI ilə gücləndir:

1. Azərbaycan standartı seçilir
2. Claude API həmin standartı PISA/TIMSS/PIRLS çərçivəsi ilə müqayisə edir
3. Boşluqları (gaps) göstərir
4. Tövsiyələr verir: "Bu standarta nail olmaq üçün Finlandiya 
   modelindən X yanaşması tətbiq oluna bilər"
5. Vizual müqayisə xəritəsi yaradılır
```

---

## MƏRHƏLƏ 2: QABAQCIL AI (Ay 3-4)
### Prioritet: Orta | Çətinlik: Yüksək

---

### 2.1 🎯 Prediktiv Analitika — Risk Aşkarlama

**Nə edir:** AI şagirdlərin akademik uğursuzluq və tərketmə riskini proqnozlaşdırır.

**Claude Code tapşırığı:**
```
modules/analytics/predictions.R-ı tam funksional et:

1. R-da ML model: randomForest/xgboost
2. Giriş dəyişənləri: davamiyyət %, orta bal, bal trendi, 
   ev tapşırığı tamamlama %, sinif aktivliyi, sosial-iqtisadi göstəricilər
3. Çıxış: risk balı (0-100), risk kateqoriyası (yüksək/orta/aşağı)
4. Dashboard-da qırmızı/sarı/yaşıl göstəricilər
5. Yüksək riskli şagirdlər üçün avtomatik bildiriş müəllimə
6. AI tövsiyə: "Bu şagird üçün əlavə riyaziyyat dəstəyi tövsiyə olunur"
7. Hər ay model yenidən öyrənir (yeni data ilə)
```

---

### 2.2 📄 Avtomatik Hesabat Generatoru

**Nə edir:** Bir düymə ilə tam formatlı hesabat yaradılır.

**Claude Code tapşırığı:**
```
modules/analytics/reports.R-ı genişləndir:

1. Hesabat növləri: aylıq, rüblük, illik, fərdi şagird, 
   fərdi müəllim, məktəb, rayon
2. DB-dən data çəkilir → Claude API-yə göndərilir
3. Claude xülasə yazır: "Bu rübdə 22 məktəbdən 18-i 
   performans hədəflərinə çatıb. Ən böyük irəliləyiş 
   Məktəb #7-də müşahidə olunub (+12%)."
4. Qrafiklər avtomatik yaradılır (plotly → PNG)
5. Word/PDF formatında yüklənir (openxlsx, rmarkdown)
6. Hesabat şablonları: ARTİ rəsmi formatı
```

---

### 2.3 🗣️ Səsli AI Asistent (Voice Agent v2)

**Nə edir:** Tam səsli idarəetmə — sual ver, cavab al, əmr icra et.

**Claude Code tapşırığı:**
```
voice_agent/ genişləndir — v2:

1. Whisper STT (Azərbaycan/Türk dili optimizasiyası)
2. Claude API ilə əmr analizi + cavab generasiyası
3. OpenAI TTS ilə səsli cavab (text-to-speech)
4. Dövri dinləmə (wake word: "ARTI" və ya "Agent")
5. Nümunə dialoq:
   Mən: "ARTI, bu həftə neçə şagird qayıb olub?"
   ARTI: "Bu həftə 22 məktəbdə cəmi 47 şagird qayıb qeydə alınıb. 
          Ən çox qayıb Məktəb 12-dədir — 8 şagird."
6. Kontekstli söhbət (əvvəlki sualları xatırlayır)
```

---

### 2.4 📸 AI ilə Sənəd Tanıma (OCR)

**Nə edir:** Kağız sənədləri skan edib sistemə daxil edir.

**Claude Code tapşırığı:**
```
Yeni modul: modules/ocr/ yarat

1. Şəkil yüklə (telefon kamerası, skaner)
2. GPT-4o Vision və ya Claude Vision ilə mətni tanı
3. İstifadə halları:
   - Kağız test cavab vərəqəsi → avtomatik qiymətləndirmə
   - Şagird sənədləri → profil məlumatları
   - Müəllim sertifikatları → peşəkar inkişaf qeydi
4. Azərbaycan dilində OCR (ə, ı, ö, ü, ç, ş, ğ dəstəyi)
```

---

### 2.5 🧮 Adaptiv Öyrənmə Yolu (Şagird Modulu)

**Nə edir:** Hər şagird üçün fərdi öyrənmə yolu yaradılır.

**Claude Code tapşırığı:**
```
modules/student/student_idp.R (Fərdi İnkişaf Planı) genişləndir:

1. IRT/CAT nəticələrinə əsasən şagirdin bilk səviyyəsini təyin et
2. Claude API ilə fərdi öyrənmə planı yarat:
   - Zəif mövzular üçün əlavə resurslar
   - Güclü mövzularda çətinlik artırma
   - Həftəlik tapşırıq planı
3. Hər həftə plan avtomatik yenilənir (nəticələrə görə)
4. Valideynə aylıq hesabat göndərilir
5. Müəllimə tövsiyələr: "Bu şagirdə kəsr ədədlərində 
   daha çox praktika lazımdır"
```

---

## MƏRHƏLƏ 3: İNNOVATİV AI (Ay 5-6)
### Prioritet: Aşağı | Çətinlik: Çox Yüksək

---

### 3.1 🌐 Çoxdilli AI Tərcümə

**Nə edir:** Kurikulum materiallarını Azərbaycan ↔ İngilis ↔ Rus dilinə tərcümə edir.

**Claude Code tapşırığı:**
```
ai_integration/ genişləndir:

1. Kurikulum standartlarının tərcüməsi
2. Beynəlxalq tədqiqatların Azərbaycan dilinə tərcüməsi
3. PISA test nümunələrinin lokalizasiyası
4. Terminologiya bazası (təhsil terminlərinin düzgün tərcüməsi)
5. Claude API: kontekstli tərcümə (təhsil sahəsi)
```

---

### 3.2 🎓 AI Müəllim Mentoru (Müəllim Modulu)

**Nə edir:** Hər müəllimə fərdi AI mentor təyin olunur.

**Claude Code tapşırığı:**
```
modules/teacher/teacher_performance.R genişləndir:

1. TALIS göstəricilərinə əsasən zəif sahələri müəyyən et
2. AI mentor hər həftə tövsiyə verir:
   - "Sinif idarəetməsi üçün bu strategiyanı sınayın..."
   - "Bu mövzuda interaktiv tədris üsulu daha effektivdir..."
3. Video/məqalə resursları tövsiyə edir
4. Müəllimin irəliləyişini izləyir
5. Attestasiyaya hazırlıq planı yaradır
```

---

### 3.3 📈 AI ilə Strateji Planlaşdırma

**Nə edir:** İnstitut rəhbərliyinə strateji qərarlar üçün AI məsləhət verir.

**Claude Code tapşırığı:**
```
Yeni: modules/strategy/ yarat

1. Bütün 22 məktəbin datası analiz olunur
2. AI strateji hesabat hazırlayır:
   - Güclü/zəif tərəflər (SWOT)
   - Resurs bölgüsü tövsiyəsi
   - Müəllim yerləşdirmə optimallaşdırması
   - Büdcə prioritetləri
3. "Əgər... olsa" scenariləri (what-if analysis)
4. Beynəlxalq benchmark müqayisəsi
```

---

### 3.4 🤝 AI Valideyn Əlaqə Sistemi

**Nə edir:** Valideynlərə avtomatik fərdi hesabat göndərir.

**Claude Code tapşırığı:**
```
Yeni funksionallıq:

1. Hər ay AI şagirdin vəziyyətini analiz edir
2. Valideynə Azərbaycan dilində məktub hazırlayır:
   - Akademik nəticələr
   - Davamiyyət
   - Güclü/zəif tərəflər
   - Ev tapşırığı statistikası
   - Tövsiyələr
3. SMS/E-poçt ilə göndərilir
4. Müəllim redaktə edib təsdiq edir
```

---

### 3.5 🔬 AI Tədqiqat Asistenti (Tədqiqat Modulu)

**Nə edir:** Tədqiqatçılara ədəbiyyat axtarışı, analiz və yazımda kömək edir.

**Claude Code tapşırığı:**
```
modules/research/research_helpers.R genişləndir:

1. Tədqiqat sualı daxil edilir
2. AI müvafiq ədəbiyyat bazasını axtarır
3. Metodologiya tövsiyəsi verir
4. Statistik analiz planı hazırlayır
5. Nəticə bölməsi qaralama yazır
6. APA/Harvard istinad formatını avtomatik tətbiq edir
```

---

## CLAUDE CODE İCRA PLANI

Hər gün Claude Code-a bir tapşırıq verin. Sıra:

### Həftə 1-2: Əsas AI infrastruktur
```
Gün 1: ai_integration/claude_api.R optimallaşdır — error handling, 
        retry logic, rate limiting, response caching
Gün 2: ai_integration/gpt_api.R optimallaşdır
Gün 3: ai_integration/prompt_templates/ — bütün prompt şablonlarını 
        yenilə və genişləndir (10+ şablon)
Gün 4: AI Router yaradılsın — tapşırığa görə Claude/GPT seçimi
Gün 5: AI cavablarının DB-də saxlanması (ai_responses cədvəli)
```

### Həftə 3-4: Sual Generatoru + Dərs Planı
```
Gün 6:  Sual generatoru UI (modal dialog)
Gün 7:  Sual generatoru server (API çağırışı + parse)
Gün 8:  Sual generatoru test və düzəliş
Gün 9:  Dərs planı generatoru UI
Gün 10: Dərs planı generatoru server + Word export
```

### Həftə 5-6: AI Analitik + AI Tutor
```
Gün 11: Analitik chatbox UI
Gün 12: Analitik chatbox server (DB data + Claude)
Gün 13: AI Tutor UI (şagird profili)
Gün 14: AI Tutor server (kontekstli söhbət)
Gün 15: Test, düzəliş, commit
```

### Həftə 7-8: Prediktiv Analitika
```
Gün 16: ML model yaradılması (randomForest)
Gün 17: Risk dashboard UI
Gün 18: Avtomatik bildiriş sistemi
Gün 19: Model doğrulanması və test
Gün 20: Hesabat generatoru + Word/PDF export
```

---

## TEXNİKİ ARXİTEKTURA

### API İstifadə Planı

| Xidmət | İstifadə | Aylıq Təxmini Xərc |
|--------|----------|---------------------|
| Claude API (Sonnet) | Sual gen, dərs planı, analitik, tutor | ~$50-100 |
| Claude API (Opus) | Strateji analiz, mürəkkəb hesabatlar | ~$20-50 |
| OpenAI Whisper | Səsli əmrlər | ~$5-10 |
| OpenAI GPT-4o | Şəkil analizi, OCR | ~$20-30 |
| OpenAI TTS | Səsli cavablar | ~$5-10 |
| **CƏMİ** | | **~$100-200/ay** |

### Performans Optimallaşdırması

```
1. Response Caching — eyni suallar üçün DB cache
2. Batch Processing — çoxlu sual bir API çağırışında
3. Async Calls — UI bloklanmasın (promises paketi)
4. Rate Limiting — API limitlərini aşmamaq
5. Fallback — Claude əlçatmaz → GPT, GPT əlçatmaz → offline
```

### Təhlükəsizlik

```
1. API açarları .env-də (heç vaxt kodda)
2. İstifadəçi sorğuları loglanır
3. AI cavabları müəllim/admin tərəfindən təsdiq olunur
4. Şagird datası anonimləşdirilir (AI-yə göndəriləndə)
5. Content filtering — uyğunsuz məzmun bloklanır
```

---

## MÜVƏFFƏQİYYƏT KRİTERİYALARI

| Göstərici | Hədəf (6 ay sonra) |
|-----------|-------------------|
| AI yaradılmış test sualları | 5000+ sual |
| AI dərs planları | 200+ plan |
| Müəllimlərin AI istifadə faizi | 70%+ |
| Şagird risk proqnozu dəqiqliyi | 80%+ |
| Avtomatik hesabat sayı | 100+/ay |
| AI tutor söhbət sessiyaları | 500+/ay |
| Vaxt qənaəti (müəllim başına) | 5+ saat/həftə |

---

## DƏRHAL BAŞLAMAQ ÜÇÜN İLK 5 ADDIM

Claude Code-a **bu gün** verin:

### Addım 1:
```
ai_integration/claude_api.R faylını optimallaşdır:
- Error handling əlavə et (retry 3 dəfə)
- Response caching (eyni sorğu 24 saat ərzində cache-dən)
- Rate limiting (dəqiqədə max 10 sorğu)
- Logging (hər API çağırışı loglanır)
```

### Addım 2:
```
Supabase-də ai_responses cədvəli yarat:
CREATE TABLE ai_responses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id),
  task_type VARCHAR(50),
  input_text TEXT,
  output_text TEXT,
  model VARCHAR(50),
  tokens_used INTEGER,
  response_time_ms INTEGER,
  created_at TIMESTAMP DEFAULT NOW()
);
```

### Addım 3:
```
modules/assessment/item_bank.R-a "AI ilə Sual Yarat" düyməsi 
və modal dialog əlavə et
```

### Addım 4:
```
AI Sual generasiya prompt şablonunu optimallaşdır və test et
```

### Addım 5:
```
İlk 50 test sualını AI ilə generasiya et və item_bank-a yaz
```

---

*Bu strategiya sənədi ARTI-2026 platformasının AI imkanlarını maksimum səviyyəyə çıxarmaq üçün yol xəritəsidir.*