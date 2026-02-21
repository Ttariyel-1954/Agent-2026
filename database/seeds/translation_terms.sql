-- =============================================
-- Tərcümə Terminologiyası Seed Data
-- ~80 əsas təhsil termini (en → az)
-- =============================================

-- === Kurikulum Terminləri ===
INSERT INTO translation_terminology (source_term, target_term, source_lang, target_lang, domain, confidence, is_verified)
VALUES
  ('curriculum', 'kurikulum', 'en', 'az', 'curriculum', 1.00, TRUE),
  ('standard', 'standart', 'en', 'az', 'curriculum', 1.00, TRUE),
  ('learning outcome', 'öyrənmə nəticəsi', 'en', 'az', 'curriculum', 1.00, TRUE),
  ('learning objective', 'öyrənmə məqsədi', 'en', 'az', 'curriculum', 1.00, TRUE),
  ('competency', 'kompetensiya', 'en', 'az', 'curriculum', 1.00, TRUE),
  ('content standard', 'məzmun standartı', 'en', 'az', 'curriculum', 1.00, TRUE),
  ('performance standard', 'fəaliyyət standartı', 'en', 'az', 'curriculum', 0.95, TRUE),
  ('subject area', 'fənn sahəsi', 'en', 'az', 'curriculum', 0.95, TRUE),
  ('grade level', 'sinif səviyyəsi', 'en', 'az', 'curriculum', 1.00, TRUE),
  ('scope and sequence', 'əhatə və ardıcıllıq', 'en', 'az', 'curriculum', 0.90, TRUE),
  ('cross-curricular', 'fənlərarası', 'en', 'az', 'curriculum', 0.95, TRUE),
  ('instructional design', 'tədris dizaynı', 'en', 'az', 'curriculum', 0.90, TRUE),
  ('syllabus', 'tədris proqramı', 'en', 'az', 'curriculum', 1.00, TRUE),
  ('lesson plan', 'dərs planı', 'en', 'az', 'curriculum', 1.00, TRUE),
  ('textbook', 'dərslik', 'en', 'az', 'curriculum', 1.00, TRUE)
ON CONFLICT (source_term, target_term, source_lang, target_lang, domain) DO NOTHING;

-- === Qiymətləndirmə Terminləri ===
INSERT INTO translation_terminology (source_term, target_term, source_lang, target_lang, domain, confidence, is_verified)
VALUES
  ('assessment', 'qiymətləndirmə', 'en', 'az', 'assessment', 1.00, TRUE),
  ('formative assessment', 'formativ qiymətləndirmə', 'en', 'az', 'assessment', 1.00, TRUE),
  ('summative assessment', 'summativ qiymətləndirmə', 'en', 'az', 'assessment', 1.00, TRUE),
  ('diagnostic assessment', 'diaqnostik qiymətləndirmə', 'en', 'az', 'assessment', 1.00, TRUE),
  ('rubric', 'rubrika', 'en', 'az', 'assessment', 0.95, TRUE),
  ('criterion', 'meyar', 'en', 'az', 'assessment', 1.00, TRUE),
  ('benchmark', 'göstərici', 'en', 'az', 'assessment', 0.90, TRUE),
  ('portfolio', 'portfolio', 'en', 'az', 'assessment', 0.95, TRUE),
  ('test item', 'test tapşırığı', 'en', 'az', 'assessment', 1.00, TRUE),
  ('distractor', 'çaşdırıcı variant', 'en', 'az', 'assessment', 0.95, TRUE),
  ('reliability', 'etibarlılıq', 'en', 'az', 'assessment', 1.00, TRUE),
  ('validity', 'düzgünlük (validlik)', 'en', 'az', 'assessment', 0.95, TRUE),
  ('norm-referenced', 'norma əsaslı', 'en', 'az', 'assessment', 0.90, TRUE),
  ('criterion-referenced', 'meyar əsaslı', 'en', 'az', 'assessment', 0.90, TRUE),
  ('achievement test', 'nailiyyət testi', 'en', 'az', 'assessment', 0.95, TRUE)
ON CONFLICT (source_term, target_term, source_lang, target_lang, domain) DO NOTHING;

-- === Bloom Taksonomiyası ===
INSERT INTO translation_terminology (source_term, target_term, source_lang, target_lang, domain, confidence, is_verified)
VALUES
  ('Bloom''s taxonomy', 'Bloom taksonomiyası', 'en', 'az', 'assessment', 1.00, TRUE),
  ('remembering', 'bilmə (xatırlama)', 'en', 'az', 'assessment', 1.00, TRUE),
  ('understanding', 'anlama', 'en', 'az', 'assessment', 1.00, TRUE),
  ('applying', 'tətbiq', 'en', 'az', 'assessment', 1.00, TRUE),
  ('analyzing', 'təhlil', 'en', 'az', 'assessment', 1.00, TRUE),
  ('evaluating', 'qiymətləndirmə', 'en', 'az', 'assessment', 1.00, TRUE),
  ('creating', 'yaratma (sintez)', 'en', 'az', 'assessment', 1.00, TRUE),
  ('depth of knowledge', 'bilik dərinliyi (DOK)', 'en', 'az', 'assessment', 0.95, TRUE),
  ('higher-order thinking', 'yüksək səviyyəli düşüncə', 'en', 'az', 'assessment', 0.95, TRUE),
  ('critical thinking', 'tənqidi düşüncə', 'en', 'az', 'assessment', 1.00, TRUE)
ON CONFLICT (source_term, target_term, source_lang, target_lang, domain) DO NOTHING;

-- === PISA Terminləri ===
INSERT INTO translation_terminology (source_term, target_term, source_lang, target_lang, domain, confidence, is_verified)
VALUES
  ('PISA', 'Beynəlxalq Şagird Qiymətləndirmə Proqramı (PISA)', 'en', 'az', 'pisa', 1.00, TRUE),
  ('reading literacy', 'oxu savadlılığı', 'en', 'az', 'pisa', 1.00, TRUE),
  ('mathematical literacy', 'riyazi savadlılıq', 'en', 'az', 'pisa', 1.00, TRUE),
  ('scientific literacy', 'elmi savadlılıq', 'en', 'az', 'pisa', 1.00, TRUE),
  ('proficiency level', 'bacarıq səviyyəsi', 'en', 'az', 'pisa', 0.95, TRUE),
  ('TIMSS', 'Riyaziyyat və Elm üzrə Beynəlxalq Tendensiyalar (TIMSS)', 'en', 'az', 'pisa', 1.00, TRUE),
  ('PIRLS', 'Beynəlxalq Oxu Savadlılığı Tədqiqatı (PIRLS)', 'en', 'az', 'pisa', 1.00, TRUE),
  ('OECD average', 'OECD ortalaması', 'en', 'az', 'pisa', 1.00, TRUE),
  ('performance band', 'performans aralığı', 'en', 'az', 'pisa', 0.90, TRUE),
  ('cognitive demand', 'koqnitiv tələb', 'en', 'az', 'pisa', 0.90, TRUE),
  ('problem solving', 'problem həlli', 'en', 'az', 'pisa', 1.00, TRUE),
  ('real-world context', 'real həyat konteksti', 'en', 'az', 'pisa', 0.90, TRUE),
  ('financial literacy', 'maliyyə savadlılığı', 'en', 'az', 'pisa', 0.95, TRUE),
  ('global competence', 'qlobal kompetensiya', 'en', 'az', 'pisa', 0.90, TRUE),
  ('creative thinking', 'yaradıcı düşüncə', 'en', 'az', 'pisa', 0.95, TRUE)
ON CONFLICT (source_term, target_term, source_lang, target_lang, domain) DO NOTHING;

-- === IRT Terminləri ===
INSERT INTO translation_terminology (source_term, target_term, source_lang, target_lang, domain, confidence, is_verified)
VALUES
  ('item response theory', 'element cavab nəzəriyyəsi (IRT)', 'en', 'az', 'irt', 1.00, TRUE),
  ('theta', 'qabiliyyət parametri (θ)', 'en', 'az', 'irt', 1.00, TRUE),
  ('discrimination', 'ayırdetmə (a parametri)', 'en', 'az', 'irt', 1.00, TRUE),
  ('difficulty parameter', 'çətinlik parametri (b)', 'en', 'az', 'irt', 1.00, TRUE),
  ('guessing parameter', 'təxmin parametri (c)', 'en', 'az', 'irt', 0.95, TRUE),
  ('item characteristic curve', 'element xarakteristik əyrisi (ICC)', 'en', 'az', 'irt', 0.95, TRUE),
  ('information function', 'informasiya funksiyası', 'en', 'az', 'irt', 0.95, TRUE),
  ('computerized adaptive testing', 'kompüterləşdirilmiş adaptiv test (CAT)', 'en', 'az', 'irt', 1.00, TRUE),
  ('multistage testing', 'çoxmərhələli test (MST)', 'en', 'az', 'irt', 0.95, TRUE),
  ('standard error of measurement', 'ölçmə standart xətası (SEM)', 'en', 'az', 'irt', 0.95, TRUE),
  ('maximum likelihood estimation', 'maksimum ehtimal qiymətləndirməsi (MLE)', 'en', 'az', 'irt', 0.90, TRUE),
  ('differential item functioning', 'differensial element funksionallığı (DIF)', 'en', 'az', 'irt', 0.90, TRUE),
  ('test equating', 'test bərabərləşdirmə', 'en', 'az', 'irt', 0.90, TRUE),
  ('item bank', 'sual bankı', 'en', 'az', 'irt', 1.00, TRUE),
  ('exposure control', 'istifadə nəzarəti', 'en', 'az', 'irt', 0.85, TRUE)
ON CONFLICT (source_term, target_term, source_lang, target_lang, domain) DO NOTHING;

-- === Pedaqogika Terminləri ===
INSERT INTO translation_terminology (source_term, target_term, source_lang, target_lang, domain, confidence, is_verified)
VALUES
  ('scaffolding', 'dəstəkləmə (skaffoldinq)', 'en', 'az', 'pedagogy', 1.00, TRUE),
  ('differentiation', 'fərqləndirmə', 'en', 'az', 'pedagogy', 1.00, TRUE),
  ('inclusive education', 'inklüziv təhsil', 'en', 'az', 'pedagogy', 1.00, TRUE),
  ('active learning', 'aktiv öyrənmə', 'en', 'az', 'pedagogy', 1.00, TRUE),
  ('cooperative learning', 'kooperativ öyrənmə', 'en', 'az', 'pedagogy', 0.95, TRUE),
  ('project-based learning', 'layihə əsaslı öyrənmə', 'en', 'az', 'pedagogy', 0.95, TRUE),
  ('inquiry-based learning', 'tədqiqat əsaslı öyrənmə', 'en', 'az', 'pedagogy', 0.90, TRUE),
  ('student-centered', 'şagird mərkəzli', 'en', 'az', 'pedagogy', 1.00, TRUE),
  ('teacher professional development', 'müəllim peşəkar inkişafı', 'en', 'az', 'pedagogy', 1.00, TRUE),
  ('classroom management', 'sinif idarəetməsi', 'en', 'az', 'pedagogy', 1.00, TRUE),
  ('motivation', 'motivasiya', 'en', 'az', 'pedagogy', 1.00, TRUE),
  ('self-efficacy', 'öz-effektivlik', 'en', 'az', 'pedagogy', 0.95, TRUE),
  ('metacognition', 'metakoqnisiya', 'en', 'az', 'pedagogy', 0.90, TRUE),
  ('zone of proximal development', 'yaxın inkişaf zonası', 'en', 'az', 'pedagogy', 0.95, TRUE),
  ('feedback', 'geri əlaqə (rəy)', 'en', 'az', 'pedagogy', 1.00, TRUE),
  ('peer assessment', 'həmyaşıd qiymətləndirmə', 'en', 'az', 'pedagogy', 0.90, TRUE),
  ('self-assessment', 'özünüqiymətləndirmə', 'en', 'az', 'pedagogy', 0.95, TRUE),
  ('blended learning', 'qarışıq öyrənmə', 'en', 'az', 'pedagogy', 0.90, TRUE),
  ('flipped classroom', 'tərsinə sinif', 'en', 'az', 'pedagogy', 0.85, TRUE),
  ('STEAM education', 'STEAM təhsili', 'en', 'az', 'pedagogy', 0.95, TRUE)
ON CONFLICT (source_term, target_term, source_lang, target_lang, domain) DO NOTHING;

-- === Ümumi Təhsil Terminləri ===
INSERT INTO translation_terminology (source_term, target_term, source_lang, target_lang, domain, confidence, is_verified)
VALUES
  ('education', 'təhsil', 'en', 'az', 'general', 1.00, TRUE),
  ('student', 'şagird', 'en', 'az', 'general', 1.00, TRUE),
  ('teacher', 'müəllim', 'en', 'az', 'general', 1.00, TRUE),
  ('school', 'məktəb', 'en', 'az', 'general', 1.00, TRUE),
  ('academic year', 'tədris ili', 'en', 'az', 'general', 1.00, TRUE),
  ('semester', 'yarımil', 'en', 'az', 'general', 1.00, TRUE),
  ('attendance', 'davamiyyət', 'en', 'az', 'general', 1.00, TRUE),
  ('enrollment', 'qeydiyyat', 'en', 'az', 'general', 1.00, TRUE),
  ('graduation', 'məzuniyyət', 'en', 'az', 'general', 1.00, TRUE),
  ('dropout', 'təhsili tərk etmə', 'en', 'az', 'general', 0.95, TRUE)
ON CONFLICT (source_term, target_term, source_lang, target_lang, domain) DO NOTHING;
