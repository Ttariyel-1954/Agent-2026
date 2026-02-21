-- =============================================
-- ARTI-2026: Sual Bankı — İlk 50 Test Sualı
-- Fənlər: Riyaziyyat, Azərbaycan dili, Fizika, Kimya,
--         Biologiya, Tarix, Coğrafiya, İnformatika, İngilis dili
-- Bloom: Bilmə, Anlama, Tətbiq, Təhlil, Sintez, Qiymətləndirmə
-- DOK: 1-4, Çətinlik: Asan/Orta/Çətin, Siniflər: 3-11
-- =============================================

-- ===== RİYAZİYYAT (10 sual) =====

INSERT INTO items (question_text, question_type, option_a, option_b, option_c, option_d, correct_answer, difficulty, bloom_level, dok_level, grade_level, subject_id, is_active)
VALUES (
  'Ədəd 48-in sadə vuruqlara ayrılışı hansıdır?',
  'mcq', '2 × 3 × 8', '2⁴ × 3', '2³ × 6', '4 × 12',
  'B', 'Asan', 'Bilmə', 1, 5,
  (SELECT id FROM subjects WHERE name = 'Riyaziyyat' LIMIT 1), TRUE
);

INSERT INTO items (question_text, question_type, option_a, option_b, option_c, option_d, correct_answer, difficulty, bloom_level, dok_level, grade_level, subject_id, is_active)
VALUES (
  'Bir mağazada əmtəənin qiyməti 20% endirim edildikdən sonra 96 AZN oldu. Əmtəənin ilkin qiyməti neçə AZN idi?',
  'mcq', '112 AZN', '115,20 AZN', '120 AZN', '124 AZN',
  'C', 'Orta', 'Tətbiq', 2, 6,
  (SELECT id FROM subjects WHERE name = 'Riyaziyyat' LIMIT 1), TRUE
);

INSERT INTO items (question_text, question_type, option_a, option_b, option_c, option_d, correct_answer, difficulty, bloom_level, dok_level, grade_level, subject_id, is_active)
VALUES (
  'f(x) = 2x² − 8x + 6 funksiyasının minimumunu tapın.',
  'mcq', '−2', '−1', '0', '2',
  'A', 'Orta', 'Tətbiq', 2, 9,
  (SELECT id FROM subjects WHERE name = 'Riyaziyyat' LIMIT 1), TRUE
);

INSERT INTO items (question_text, question_type, option_a, option_b, option_c, option_d, correct_answer, difficulty, bloom_level, dok_level, grade_level, subject_id, is_active)
VALUES (
  'x² − 5x + 6 = 0 tənliyinin kökləri cəmi ilə hasilinin fərqini tapın.',
  'mcq', '−1', '0', '1', '−11',
  'A', 'Orta', 'Təhlil', 2, 8,
  (SELECT id FROM subjects WHERE name = 'Riyaziyyat' LIMIT 1), TRUE
);

INSERT INTO items (question_text, question_type, option_a, option_b, option_c, option_d, correct_answer, difficulty, bloom_level, dok_level, grade_level, subject_id, is_active)
VALUES (
  'Bir sinifdə 30 şagird var. Onların 40%-i oğlan, qalanı qızdır. Sinifə 5 yeni qız əlavə olunsa, qızların ümumi sayda payı neçə faiz olar?',
  'mcq', '60%', '65,7%', '68,6%', '71,4%',
  'C', 'Çətin', 'Təhlil', 3, 7,
  (SELECT id FROM subjects WHERE name = 'Riyaziyyat' LIMIT 1), TRUE
);

INSERT INTO items (question_text, question_type, option_a, option_b, option_c, option_d, correct_answer, difficulty, bloom_level, dok_level, grade_level, subject_id, is_active)
VALUES (
  'Hansı ədəd həm 3-ə, həm 4-ə, həm də 5-ə tam bölünür?',
  'mcq', '30', '45', '60', '72',
  'C', 'Asan', 'Anlama', 1, 5,
  (SELECT id FROM subjects WHERE name = 'Riyaziyyat' LIMIT 1), TRUE
);

INSERT INTO items (question_text, question_type, option_a, option_b, option_c, option_d, correct_answer, difficulty, bloom_level, dok_level, grade_level, subject_id, is_active)
VALUES (
  'Ədədi silsilə verilmişdir: 2, 6, 18, 54, ... Silsilənin 6-cı hədini tapın.',
  'mcq', '162', '324', '486', '972',
  'C', 'Çətin', 'Tətbiq', 3, 9,
  (SELECT id FROM subjects WHERE name = 'Riyaziyyat' LIMIT 1), TRUE
);

-- ===== AZƏRBAYCAN DİLİ (7 sual) =====

INSERT INTO items (question_text, question_type, option_a, option_b, option_c, option_d, correct_answer, difficulty, bloom_level, dok_level, grade_level, subject_id, is_active)
VALUES (
  'Aşağıdakı sözlərdən hansı mürəkkəb sözdür?',
  'mcq', 'dəftərxana', 'müəllim', 'kitab', 'dərs',
  'A', 'Asan', 'Bilmə', 1, 5,
  (SELECT id FROM subjects WHERE name = 'Azərbaycan dili' LIMIT 1), TRUE
);

INSERT INTO items (question_text, question_type, option_a, option_b, option_c, option_d, correct_answer, difficulty, bloom_level, dok_level, grade_level, subject_id, is_active)
VALUES (
  '"Uşaqlar bağda oynayırdılar" cümləsindəki felin zamanını müəyyən edin.',
  'mcq', 'Keçmiş zaman', 'İndiki zaman', 'Gələcək zaman', 'Şühudi keçmiş zaman',
  'A', 'Asan', 'Bilmə', 1, 6,
  (SELECT id FROM subjects WHERE name = 'Azərbaycan dili' LIMIT 1), TRUE
);

INSERT INTO items (question_text, question_type, option_a, option_b, option_c, option_d, correct_answer, difficulty, bloom_level, dok_level, grade_level, subject_id, is_active)
VALUES (
  '"Dağlar başı dumanlı, çəmənlər gül-çiçəkli" ifadəsində hansı bədii təsvir vasitəsi istifadə olunub?',
  'mcq', 'Təşbeh', 'Mübaliğə', 'Epitet', 'Metonimiya',
  'C', 'Orta', 'Təhlil', 2, 8,
  (SELECT id FROM subjects WHERE name = 'Azərbaycan dili' LIMIT 1), TRUE
);

INSERT INTO items (question_text, question_type, option_a, option_b, option_c, option_d, correct_answer, difficulty, bloom_level, dok_level, grade_level, subject_id, is_active)
VALUES (
  'Hansı cümlə sadə geniş cümlədir?',
  'mcq',
  'Günəş çıxdı.',
  'Şagirdlər dərsdə diqqətlə müəllimi dinləyirdilər.',
  'Yaz gəldi və çiçəklər açdı.',
  'Kitab oxudum, film baxdım.',
  'B', 'Orta', 'Anlama', 2, 7,
  (SELECT id FROM subjects WHERE name = 'Azərbaycan dili' LIMIT 1), TRUE
);

INSERT INTO items (question_text, question_type, option_a, option_b, option_c, option_d, correct_answer, difficulty, bloom_level, dok_level, grade_level, subject_id, is_active)
VALUES (
  '"Bütün dərslərinə yaxşı hazırlaş" cümləsindəki əsas fikri öz sözlərinizlə necə ifadə edərdiniz?',
  'mcq',
  'Yalnız vacib dərslərə hazırlaş',
  'Hər fənnə eyni diqqət və səylə yanaş',
  'Ən çətin dərslərə daha çox vaxt ayır',
  'İmtahandan əvvəl hazırlaşmaq kifayətdir',
  'B', 'Orta', 'Anlama', 2, 6,
  (SELECT id FROM subjects WHERE name = 'Azərbaycan dili' LIMIT 1), TRUE
);

INSERT INTO items (question_text, question_type, option_a, option_b, option_c, option_d, correct_answer, difficulty, bloom_level, dok_level, grade_level, subject_id, is_active)
VALUES (
  'Verilmiş cümlələrdən hansında ahəng qanunu pozulmuş söz var?',
  'mcq',
  'Müəllimlər şagirdlərə kömək edir.',
  'Bu kitab çox maraqlıdır.',
  'Azərbaycan dili zəngin dildir.',
  'Şagirdlər idmançıları alqışladılar.',
  'D', 'Çətin', 'Təhlil', 3, 9,
  (SELECT id FROM subjects WHERE name = 'Azərbaycan dili' LIMIT 1), TRUE
);

INSERT INTO items (question_text, question_type, option_a, option_b, option_c, option_d, correct_answer, difficulty, bloom_level, dok_level, grade_level, subject_id, is_active)
VALUES (
  'Aşağıdakılardan hansı Nizami Gəncəvinin "Xəmsə"sinə daxil olan əsərlərdən biridir?',
  'mcq', 'Leyli və Məcnun', 'Koroğlu', 'Dədə Qorqud', 'Qarabağnamələr',
  'A', 'Asan', 'Bilmə', 1, 9,
  (SELECT id FROM subjects WHERE name = 'Azərbaycan dili' LIMIT 1), TRUE
);

-- ===== FİZİKA (6 sual) =====

INSERT INTO items (question_text, question_type, option_a, option_b, option_c, option_d, correct_answer, difficulty, bloom_level, dok_level, grade_level, subject_id, is_active)
VALUES (
  'Kütləsi 5 kq olan cisim yerə 10 m hündürlükdən düşür. Cismin yerə çatdıqda potensial enerjisi neçə C-dur? (g = 10 m/s²)',
  'mcq', '0 C', '50 C', '250 C', '500 C',
  'A', 'Orta', 'Tətbiq', 2, 9,
  (SELECT id FROM subjects WHERE name = 'Fizika' LIMIT 1), TRUE
);

INSERT INTO items (question_text, question_type, option_a, option_b, option_c, option_d, correct_answer, difficulty, bloom_level, dok_level, grade_level, subject_id, is_active)
VALUES (
  'İşığın vakuumdakı sürəti təxminən neçədir?',
  'mcq', '3 × 10⁶ m/s', '3 × 10⁸ m/s', '3 × 10¹⁰ m/s', '3 × 10⁵ m/s',
  'B', 'Asan', 'Bilmə', 1, 8,
  (SELECT id FROM subjects WHERE name = 'Fizika' LIMIT 1), TRUE
);

INSERT INTO items (question_text, question_type, option_a, option_b, option_c, option_d, correct_answer, difficulty, bloom_level, dok_level, grade_level, subject_id, is_active)
VALUES (
  'Omun qanununa görə dövrədəki cərəyan şiddəti 2 A, müqavimət 15 Ω olarsa, gərginlik neçə V-dur?',
  'mcq', '7,5 V', '13 V', '17 V', '30 V',
  'D', 'Asan', 'Tətbiq', 1, 8,
  (SELECT id FROM subjects WHERE name = 'Fizika' LIMIT 1), TRUE
);

INSERT INTO items (question_text, question_type, option_a, option_b, option_c, option_d, correct_answer, difficulty, bloom_level, dok_level, grade_level, subject_id, is_active)
VALUES (
  'Buz əriyərkən temperatur sabit qalır. Bu hadisənin səbəbi nədir?',
  'mcq',
  'İstilik enerjisi mühitə qaytarılır',
  'İstilik enerjisi kristal qəfəsi pozmağa sərf olunur',
  'Buzun kütləsi artır',
  'Suyun sıxlığı azalır',
  'B', 'Orta', 'Anlama', 2, 9,
  (SELECT id FROM subjects WHERE name = 'Fizika' LIMIT 1), TRUE
);

INSERT INTO items (question_text, question_type, option_a, option_b, option_c, option_d, correct_answer, difficulty, bloom_level, dok_level, grade_level, subject_id, is_active)
VALUES (
  'Kütləsi 1000 kq olan avtomobil 20 m/s sürətlə hərəkət edir. Əyləc qüvvəsi 5000 N olarsa, avtomobil neçə saniyədə dayanar?',
  'mcq', '2 s', '4 s', '5 s', '10 s',
  'B', 'Çətin', 'Təhlil', 3, 10,
  (SELECT id FROM subjects WHERE name = 'Fizika' LIMIT 1), TRUE
);

INSERT INTO items (question_text, question_type, option_a, option_b, option_c, option_d, correct_answer, difficulty, bloom_level, dok_level, grade_level, subject_id, is_active)
VALUES (
  'Eyni yüksəklikdən atılan iki topdan biri ağır, digəri yüngüldür. Hava müqaviməti nəzərə alınmazsa, hansı əvvəl yerə düşər?',
  'mcq',
  'Ağır top',
  'Yüngül top',
  'Eyni vaxtda',
  'Topların materialından asılıdır',
  'C', 'Orta', 'Anlama', 2, 8,
  (SELECT id FROM subjects WHERE name = 'Fizika' LIMIT 1), TRUE
);

-- ===== KİMYA (5 sual) =====

INSERT INTO items (question_text, question_type, option_a, option_b, option_c, option_d, correct_answer, difficulty, bloom_level, dok_level, grade_level, subject_id, is_active)
VALUES (
  'Su molekulunun (H₂O) kimyəvi formulundakı elementlərin sayı neçədir?',
  'mcq', '1', '2', '3', '4',
  'B', 'Asan', 'Bilmə', 1, 7,
  (SELECT id FROM subjects WHERE name = 'Kimya' LIMIT 1), TRUE
);

INSERT INTO items (question_text, question_type, option_a, option_b, option_c, option_d, correct_answer, difficulty, bloom_level, dok_level, grade_level, subject_id, is_active)
VALUES (
  'Dövri cədvəldə 11-ci element hansıdır və hansı qrupa aiddir?',
  'mcq',
  'Neon, soy qazlar',
  'Natrium, qələvi metallar',
  'Maqnezium, qələvi-torpaq metalları',
  'Xlor, halogenlər',
  'B', 'Asan', 'Bilmə', 1, 8,
  (SELECT id FROM subjects WHERE name = 'Kimya' LIMIT 1), TRUE
);

INSERT INTO items (question_text, question_type, option_a, option_b, option_c, option_d, correct_answer, difficulty, bloom_level, dok_level, grade_level, subject_id, is_active)
VALUES (
  'NaOH + HCl → NaCl + H₂O reaksiyasının növünü müəyyən edin.',
  'mcq', 'Birləşmə', 'Parçalanma', 'Dəyişmə (neytrallaşma)', 'Əvəzetmə',
  'C', 'Orta', 'Anlama', 2, 8,
  (SELECT id FROM subjects WHERE name = 'Kimya' LIMIT 1), TRUE
);

INSERT INTO items (question_text, question_type, option_a, option_b, option_c, option_d, correct_answer, difficulty, bloom_level, dok_level, grade_level, subject_id, is_active)
VALUES (
  '0,5 mol CaCO₃-ün kütləsini hesablayın. (Ca=40, C=12, O=16)',
  'mcq', '25 q', '50 q', '75 q', '100 q',
  'B', 'Orta', 'Tətbiq', 2, 9,
  (SELECT id FROM subjects WHERE name = 'Kimya' LIMIT 1), TRUE
);

INSERT INTO items (question_text, question_type, option_a, option_b, option_c, option_d, correct_answer, difficulty, bloom_level, dok_level, grade_level, subject_id, is_active)
VALUES (
  'Laboratoriyada turşunun üzərinə metal əlavə edildikdə qaz ayrılır. Bu qaz hansıdır və necə yoxlanılır?',
  'mcq',
  'Oksigen — közərən çöplə',
  'Hidrogen — yanan çöplə (partlayış səsi)',
  'Karbon dioksid — əhəng suyu bulanır',
  'Azot — rəngsiz və qoxusuzdur',
  'B', 'Çətin', 'Təhlil', 3, 9,
  (SELECT id FROM subjects WHERE name = 'Kimya' LIMIT 1), TRUE
);

-- ===== BİOLOGİYA (5 sual) =====

INSERT INTO items (question_text, question_type, option_a, option_b, option_c, option_d, correct_answer, difficulty, bloom_level, dok_level, grade_level, subject_id, is_active)
VALUES (
  'Fotosintez prosesi zamanı bitki nə alır və nə buraxır?',
  'mcq',
  'CO₂ alır, O₂ buraxır',
  'O₂ alır, CO₂ buraxır',
  'N₂ alır, O₂ buraxır',
  'H₂O alır, CO₂ buraxır',
  'A', 'Asan', 'Bilmə', 1, 6,
  (SELECT id FROM subjects WHERE name = 'Biologiya' LIMIT 1), TRUE
);

INSERT INTO items (question_text, question_type, option_a, option_b, option_c, option_d, correct_answer, difficulty, bloom_level, dok_level, grade_level, subject_id, is_active)
VALUES (
  'İnsan qanında oksigeni daşıyan zülal hansıdır?',
  'mcq', 'Albumin', 'Hemoqlobin', 'Fibrinogen', 'İmmunoqlobulin',
  'B', 'Asan', 'Bilmə', 1, 8,
  (SELECT id FROM subjects WHERE name = 'Biologiya' LIMIT 1), TRUE
);

INSERT INTO items (question_text, question_type, option_a, option_b, option_c, option_d, correct_answer, difficulty, bloom_level, dok_level, grade_level, subject_id, is_active)
VALUES (
  'Bir ailədə ata Aa genotipli, ana aa genotiplidir. Nəsildə resessiv əlamətli övladların ehtimalı neçə faizdir?',
  'mcq', '0%', '25%', '50%', '100%',
  'C', 'Orta', 'Tətbiq', 2, 10,
  (SELECT id FROM subjects WHERE name = 'Biologiya' LIMIT 1), TRUE
);

INSERT INTO items (question_text, question_type, option_a, option_b, option_c, option_d, correct_answer, difficulty, bloom_level, dok_level, grade_level, subject_id, is_active)
VALUES (
  'Mitoz bölünmə nəticəsində ana hüceyrədən neçə hüceyrə əmələ gəlir və onların xromosom sayı necədir?',
  'mcq',
  '2 hüceyrə, xromosom sayı yarıbayarı',
  '4 hüceyrə, xromosom sayı eyni',
  '2 hüceyrə, xromosom sayı eyni',
  '4 hüceyrə, xromosom sayı yarıbayarı',
  'C', 'Orta', 'Anlama', 2, 9,
  (SELECT id FROM subjects WHERE name = 'Biologiya' LIMIT 1), TRUE
);

INSERT INTO items (question_text, question_type, option_a, option_b, option_c, option_d, correct_answer, difficulty, bloom_level, dok_level, grade_level, subject_id, is_active)
VALUES (
  'Ekosistemlərdə enerji piramidası nəyi göstərir və niyə hər pilləkdə enerji azalır?',
  'mcq',
  'Canlıların sayını; çünki yırtıcılar çoxdur',
  'Enerji axınını; çünki hər pilləkdə enerji istilik şəklində itirilir',
  'Biomassanı; çünki böyük canlılar az yeyir',
  'Su dövranını; çünki su buxarlanır',
  'B', 'Çətin', 'Təhlil', 3, 10,
  (SELECT id FROM subjects WHERE name = 'Biologiya' LIMIT 1), TRUE
);

-- ===== TARİX (5 sual) =====

INSERT INTO items (question_text, question_type, option_a, option_b, option_c, option_d, correct_answer, difficulty, bloom_level, dok_level, grade_level, subject_id, is_active)
VALUES (
  'Azərbaycan Xalq Cümhuriyyəti hansı ildə elan olunmuşdur?',
  'mcq', '1917', '1918', '1920', '1991',
  'B', 'Asan', 'Bilmə', 1, 9,
  (SELECT id FROM subjects WHERE name = 'Tarix' LIMIT 1), TRUE
);

INSERT INTO items (question_text, question_type, option_a, option_b, option_c, option_d, correct_answer, difficulty, bloom_level, dok_level, grade_level, subject_id, is_active)
VALUES (
  'Azərbaycan Xalq Cümhuriyyəti müsəlman Şərqində ilk demokratik respublika sayılır. Bu nəyə görə tarixi əhəmiyyət daşıyır?',
  'mcq',
  'Çünki ən uzunömürlü dövlət olub',
  'Çünki qadınlara seçki hüququ verən ilk müsəlman ölkəsi olub',
  'Çünki ən böyük əraziyə sahib olub',
  'Çünki Osmanlı imperiyasının tərkibində olub',
  'B', 'Orta', 'Anlama', 2, 9,
  (SELECT id FROM subjects WHERE name = 'Tarix' LIMIT 1), TRUE
);

INSERT INTO items (question_text, question_type, option_a, option_b, option_c, option_d, correct_answer, difficulty, bloom_level, dok_level, grade_level, subject_id, is_active)
VALUES (
  'Böyük İpək Yolu hansı qitələri birləşdirirdi?',
  'mcq', 'Avropa və Afrika', 'Asiya və Amerika', 'Asiya və Avropa', 'Afrika və Asiya',
  'C', 'Asan', 'Bilmə', 1, 6,
  (SELECT id FROM subjects WHERE name = 'Tarix' LIMIT 1), TRUE
);

INSERT INTO items (question_text, question_type, option_a, option_b, option_c, option_d, correct_answer, difficulty, bloom_level, dok_level, grade_level, subject_id, is_active)
VALUES (
  'Səfəvilər dövlətinin yaranması Azərbaycan tarixində hansı dəyişikliyi gətirdi?',
  'mcq',
  'İlk dəfə pul istifadəyə verildi',
  'Mərkəzləşdirilmiş Azərbaycan dövləti yaradıldı və Azərbaycan türkcəsi dövlət dili oldu',
  'Xristianlıq rəsmi din oldu',
  'Azərbaycan Rusiyanın tərkibinə keçdi',
  'B', 'Çətin', 'Qiymətləndirmə', 3, 10,
  (SELECT id FROM subjects WHERE name = 'Tarix' LIMIT 1), TRUE
);

INSERT INTO items (question_text, question_type, option_a, option_b, option_c, option_d, correct_answer, difficulty, bloom_level, dok_level, grade_level, subject_id, is_active)
VALUES (
  'İkinci Dünya Müharibəsi hansı illərdə baş vermişdir?',
  'mcq', '1914–1918', '1939–1945', '1941–1945', '1936–1943',
  'B', 'Asan', 'Bilmə', 1, 9,
  (SELECT id FROM subjects WHERE name = 'Tarix' LIMIT 1), TRUE
);

-- ===== COĞRAFİYA (5 sual) =====

INSERT INTO items (question_text, question_type, option_a, option_b, option_c, option_d, correct_answer, difficulty, bloom_level, dok_level, grade_level, subject_id, is_active)
VALUES (
  'Azərbaycanın ən böyük gölü hansıdır?',
  'mcq', 'Göygöl', 'Sarısu', 'Hacıqabul', 'Xəzər dənizi (göl)',
  'D', 'Asan', 'Bilmə', 1, 6,
  (SELECT id FROM subjects WHERE name = 'Coğrafiya' LIMIT 1), TRUE
);

INSERT INTO items (question_text, question_type, option_a, option_b, option_c, option_d, correct_answer, difficulty, bloom_level, dok_level, grade_level, subject_id, is_active)
VALUES (
  'Yer kürəsinin öz oxu ətrafında fırlanma müddəti nə qədərdir?',
  'mcq', '12 saat', '24 saat', '365 gün', '30 gün',
  'B', 'Asan', 'Bilmə', 1, 5,
  (SELECT id FROM subjects WHERE name = 'Coğrafiya' LIMIT 1), TRUE
);

INSERT INTO items (question_text, question_type, option_a, option_b, option_c, option_d, correct_answer, difficulty, bloom_level, dok_level, grade_level, subject_id, is_active)
VALUES (
  'Azərbaycanda 9 iqlim tipinin mövcud olmasının əsas səbəbi nədir?',
  'mcq',
  'Yalnız dəniz təsiri',
  'Yalnız relyef müxtəlifliyi',
  'Relyef müxtəlifliyi, coğrafi mövqe və dəniz təsirinin birləşməsi',
  'Yalnız enliyə görə',
  'C', 'Çətin', 'Təhlil', 3, 9,
  (SELECT id FROM subjects WHERE name = 'Coğrafiya' LIMIT 1), TRUE
);

INSERT INTO items (question_text, question_type, option_a, option_b, option_c, option_d, correct_answer, difficulty, bloom_level, dok_level, grade_level, subject_id, is_active)
VALUES (
  'Aşağıdakı ölkələrdən hansı Cənubi Amerikada yerləşir?',
  'mcq', 'Meksika', 'Kuba', 'Braziliya', 'Yamayka',
  'C', 'Asan', 'Bilmə', 1, 7,
  (SELECT id FROM subjects WHERE name = 'Coğrafiya' LIMIT 1), TRUE
);

INSERT INTO items (question_text, question_type, option_a, option_b, option_c, option_d, correct_answer, difficulty, bloom_level, dok_level, grade_level, subject_id, is_active)
VALUES (
  'Bir xəritədə miqyas 1:100000-dir. Xəritədə 5 sm olan məsafə reallıqda neçə km-dir?',
  'mcq', '0,5 km', '5 km', '50 km', '500 km',
  'B', 'Orta', 'Tətbiq', 2, 7,
  (SELECT id FROM subjects WHERE name = 'Coğrafiya' LIMIT 1), TRUE
);

-- ===== İNFORMATİKA (6 sual) =====

INSERT INTO items (question_text, question_type, option_a, option_b, option_c, option_d, correct_answer, difficulty, bloom_level, dok_level, grade_level, subject_id, is_active)
VALUES (
  '1 baytda neçə bit var?',
  'mcq', '2', '4', '8', '16',
  'C', 'Asan', 'Bilmə', 1, 5,
  (SELECT id FROM subjects WHERE name = 'İnformatika' LIMIT 1), TRUE
);

INSERT INTO items (question_text, question_type, option_a, option_b, option_c, option_d, correct_answer, difficulty, bloom_level, dok_level, grade_level, subject_id, is_active)
VALUES (
  'İkili ədəd sistemində 1011₂ onluq ədəd sistemində neçəyə bərabərdir?',
  'mcq', '9', '10', '11', '13',
  'C', 'Orta', 'Tətbiq', 2, 7,
  (SELECT id FROM subjects WHERE name = 'İnformatika' LIMIT 1), TRUE
);

INSERT INTO items (question_text, question_type, option_a, option_b, option_c, option_d, correct_answer, difficulty, bloom_level, dok_level, grade_level, subject_id, is_active)
VALUES (
  'Alqoritmin xətti, budaqlanan və dövri növlərindən hansında şərt yoxlanılır?',
  'mcq', 'Yalnız xətti', 'Yalnız dövri', 'Budaqlanan və dövri', 'Hamısında',
  'C', 'Orta', 'Anlama', 2, 7,
  (SELECT id FROM subjects WHERE name = 'İnformatika' LIMIT 1), TRUE
);

INSERT INTO items (question_text, question_type, option_a, option_b, option_c, option_d, correct_answer, difficulty, bloom_level, dok_level, grade_level, subject_id, is_active)
VALUES (
  'HTML-də hiperlinkə aid düzgün teq hansıdır?',
  'mcq', '<link>', '<a href="...">', '<url>', '<href>',
  'B', 'Asan', 'Bilmə', 1, 8,
  (SELECT id FROM subjects WHERE name = 'İnformatika' LIMIT 1), TRUE
);

INSERT INTO items (question_text, question_type, option_a, option_b, option_c, option_d, correct_answer, difficulty, bloom_level, dok_level, grade_level, subject_id, is_active)
VALUES (
  'Aşağıdakı Python kodunun nəticəsi nədir?\nx = [1, 2, 3, 4, 5]\nprint(x[1:3])',
  'mcq', '[1, 2, 3]', '[2, 3]', '[2, 3, 4]', '[1, 2]',
  'B', 'Orta', 'Tətbiq', 2, 9,
  (SELECT id FROM subjects WHERE name = 'İnformatika' LIMIT 1), TRUE
);

-- ===== İNGİLİS DİLİ (6 sual) =====

INSERT INTO items (question_text, question_type, option_a, option_b, option_c, option_d, correct_answer, difficulty, bloom_level, dok_level, grade_level, subject_id, is_active)
VALUES (
  'Choose the correct form: "She _____ to school every day."',
  'mcq', 'go', 'goes', 'going', 'gone',
  'B', 'Asan', 'Bilmə', 1, 5,
  (SELECT id FROM subjects WHERE name = 'İngilis dili' LIMIT 1), TRUE
);

INSERT INTO items (question_text, question_type, option_a, option_b, option_c, option_d, correct_answer, difficulty, bloom_level, dok_level, grade_level, subject_id, is_active)
VALUES (
  'Choose the correct sentence:',
  'mcq',
  'If I was rich, I will buy a car.',
  'If I were rich, I would buy a car.',
  'If I am rich, I would buy a car.',
  'If I were rich, I will buy a car.',
  'B', 'Orta', 'Tətbiq', 2, 8,
  (SELECT id FROM subjects WHERE name = 'İngilis dili' LIMIT 1), TRUE
);

INSERT INTO items (question_text, question_type, option_a, option_b, option_c, option_d, correct_answer, difficulty, bloom_level, dok_level, grade_level, subject_id, is_active)
VALUES (
  'What is the passive form of "The teacher explains the lesson"?',
  'mcq',
  'The lesson is explained by the teacher.',
  'The lesson was explained by the teacher.',
  'The lesson explains by the teacher.',
  'The teacher is explained by the lesson.',
  'A', 'Orta', 'Tətbiq', 2, 9,
  (SELECT id FROM subjects WHERE name = 'İngilis dili' LIMIT 1), TRUE
);

INSERT INTO items (question_text, question_type, option_a, option_b, option_c, option_d, correct_answer, difficulty, bloom_level, dok_level, grade_level, subject_id, is_active)
VALUES (
  'Read the sentence and choose the meaning of the underlined word: "The politician gave an AMBIGUOUS answer that confused everyone."',
  'mcq', 'Clear and direct', 'Having multiple meanings; unclear', 'Funny and entertaining', 'Angry and aggressive',
  'B', 'Orta', 'Anlama', 2, 10,
  (SELECT id FROM subjects WHERE name = 'İngilis dili' LIMIT 1), TRUE
);

INSERT INTO items (question_text, question_type, option_a, option_b, option_c, option_d, correct_answer, difficulty, bloom_level, dok_level, grade_level, subject_id, is_active)
VALUES (
  'Fill in: "By the time we arrived, the movie _____ already _____."',
  'mcq', 'has / started', 'had / started', 'was / starting', 'have / started',
  'B', 'Çətin', 'Tətbiq', 2, 10,
  (SELECT id FROM subjects WHERE name = 'İngilis dili' LIMIT 1), TRUE
);

