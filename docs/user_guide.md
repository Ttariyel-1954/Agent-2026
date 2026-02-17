# ARTI-2026 İstifadəçi Təlimatı

## 1. Giriş

ARTI-2026 Azərbaycan təhsil institutları üçün hərtərəfli idarəetmə sistemidir. Bu sənəd sistemin bütün funksiyalarının istifadəsini izah edir.

## 2. Sistemə Giriş

1. Brauzerdə `http://localhost:3838` ünvanını açın
2. İstifadəçi adı və şifrənizi daxil edin
3. "Daxil Ol" düyməsinə basın

**Default Admin Girişi:**
- İstifadəçi adı: `admin`
- Şifrə: `Admin2026!`

**Qeyd:** 5 uğursuz cəhddən sonra hesab 15 dəqiqə kilidlənir.

## 3. Ana Səhifə (Dashboard)

Ana səhifədə aşağıdakı məlumatlar göstərilir:
- **Şagird sayı**: Aktiv şagirdlərin ümumi sayı
- **Müəllim sayı**: Aktiv müəllimlərin sayı
- **Orta bal**: Bütün şagirdlərin orta performansı
- **Aktiv testlər**: Hazırda icra olunan testlər

## 4. Şagird İdarəetmə

### 4.1 Şagird Siyahısı
- Sol menyudan "Şagirdlər" → "Siyahı" seçin
- Sinif və status filtrləri ilə axtarış edin
- "Excel-ə İxrac" düyməsi ilə siyahını yükləyin

### 4.2 Yeni Şagird Qeydiyyatı
- "Yeni Şagird" düyməsinə basın
- Bütün məlumatları doldurun (ad, soyad, FIN, doğum tarixi)
- Valideyn məlumatlarını əlavə edin
- "Qeydiyyat" düyməsinə basın

### 4.3 Davamiyyət
- "Davamiyyət" bölməsinə keçin
- Sinif və tarixi seçin
- Hər şagird üçün status seçin (iştirak/qayıb/gecikmə/icazəli/xəstəlik)
- "Saxla" düyməsinə basın

### 4.4 Şagird Profili
- Şagird siyahısından bir şagird seçin
- GPA, qiymətlər cədvəli, fənlər üzrə proqres görüntülənir
- Plotly qrafiklərini böyütmək üçün üzərində klik edin

### 4.5 Fərdi İnkişaf Planı (FİP)
- "FİP" tabına keçin
- "Yeni Plan" düyməsi ilə yeni plan yaradın
- Hədəf bal, son tarix təyin edin
- Qeydlər əlavə edin

## 5. Müəllim İdarəetmə

### 5.1 Müəllim Siyahısı
- Fənn, kateqoriya, məktəb üzrə filtrləyin

### 5.2 İş Yükü
- Həftəlik dərs cədvəlini görüntüləyin
- Minimum 18, maksimum 36 saat yoxlaması avtomatik aparılır

### 5.3 Peşəkar İnkişaf
- Təlim tarixçəsi, sertifikatlar, attestasiya məlumatları

### 5.4 Performans Qiymətləndirmə
- 5 kriteriya üzrə qiymətləndirmə (1-5 şkala)
- KPI göstəriciləri: şagird nəticələri, davamiyyət, inkişaf

## 6. Qiymətləndirmə

### 6.1 Sual Bankı
- "Qiymətləndirmə" → "Sual Bankı" açın
- Fənn, sinif, çətinlik üzrə filtrləyin
- "Yeni Sual" ilə sual əlavə edin (IRT parametrləri ilə)
- "Kalibrasiya" düyməsi ilə sualları kalibrə edin

### 6.2 CAT (Kompüterləşdirilmiş Adaptiv Test)
- "CAT Test" bölməsinə keçin
- Fənn seçin və testi başladın
- Sistem avtomatik uyğun suallar seçir
- SE < 0.3 olduqda və ya 50 sualdan sonra test dayanır

### 6.3 MST (Çoxmərhələli Test)
- "MST Test" seçin
- 1-3-3 strukturda keçid edilir
- Hər mərhələdə performansa görə növbəti modul seçilir

### 6.4 IRT Analiz
- Sualların ICC əyrilərini görüntüləyin
- Test İnformasiya Funksiyasını yoxlayın
- Parametr cədvəlini analiz edin

## 7. Kurikulum

### 7.1 Standartlar
- Fənn və sinif üzrə standartları görüntüləyin
- Bloom taksonomiyası paylanmasını yoxlayın
- Yeni standart əlavə edin

### 7.2 Uyğunluq Analizi
- Fənn və sinif seçin, "Analiz Et" basın
- Standart-sual uyğunluq matrisi görüntülənir
- Webb DOK indeksi, əhatə dərəcəsi göstərilir
- Boşluqlar və artıqlıqlar cədvəldə göstərilir

### 7.3 Beynəlxalq Müqayisə
- Müqayisə etmək istədiyiniz ölkələri seçin
- Radar diaqram və PISA bal müqayisəsi görüntülənir
- Güclü/zəif tərəflər analizi oxuyun

## 8. Analitika

### 8.1 Məktəb Dashboard
- Ümumi statistika (şagird/müəllim sayı, orta bal, davamiyyət)
- Performans trendi, qiymət paylanması
- Fənn müqayisəsi, davamiyyət istilik xəritəsi
- Ən yaxşı və diqqət tələb edən şagirdlər

### 8.2 Hesabatlar
- Hesabat növünü seçin (şagird/sinif/məktəb/müəllim)
- Format seçin (Excel/CSV/PDF)
- Önbaxış edin və yükləyin
- Planlanmış hesabatlar yaradın

### 8.3 Prediktiv Analitika
- Model seçin (Random Forest/Logistic/GBM)
- Hədəf seçin (performans/tərk riski/davamiyyət)
- "Proqnozla" düyməsinə basın
- Risk altında olan şagirdlər cədvəlini yoxlayın

## 9. AI Köməkçi

1. "AI Köməkçi" bölməsinə keçin
2. Provider seçin (Claude və ya GPT)
3. Sualınızı yazın və "Göndər" basın
4. AI cavabını oxuyun

**Nümunə sorğular:**
- "8-ci sinif riyaziyyatdan 5 test sualı hazırla"
- "Bu şagirdin performansını təhlil et"
- "Kurikulum boşluqları haqqında tövsiyə ver"

## 10. Klaviatura Qısa Yolları

| Qısa Yol | Funksiya |
|-----------|----------|
| Ctrl+S | Saxla |
| Escape | Modalı bağla |
| Ctrl+F | Axtarış |
