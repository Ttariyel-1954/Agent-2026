-- =============================================
-- Seed: İnstitut Strukturu
-- Tarix: 2026-02-18
-- Təsvir: ARTİ təşkilati strukturu, fəaliyyət sahələri
-- Mənbə: arti.edu.az
-- =============================================

BEGIN;

-- =============================================
-- 1. Rəhbərlik
-- =============================================

INSERT INTO org_units (id, parent_id, name, short_name, unit_type, head_name, head_position, description, sort_order)
VALUES
  ('10000000-0000-0000-0000-000000000001', NULL,
   'Azərbaycan Respublikasının Təhsil İnstitutu', 'ARTİ', 'rehberlik',
   'Emin Əmrullayev', 'Direktor',
   'Azərbaycan Respublikasının Təhsil İnstitutu - təhsil sahəsində elmi-tədqiqat, metodik təminat və innovasiya mərkəzi',
   0),

  ('10000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001',
   'Elmi işlər üzrə direktor müavini', NULL, 'rehberlik',
   NULL, 'Direktor müavini',
   'Elmi-tədqiqat fəaliyyətinin koordinasiyası', 1),

  ('10000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000001',
   'Tədris işləri üzrə direktor müavini', NULL, 'rehberlik',
   NULL, 'Direktor müavini',
   'Tədris və metodik fəaliyyətin koordinasiyası', 2),

  ('10000000-0000-0000-0000-000000000004', '10000000-0000-0000-0000-000000000001',
   'İnnovasiya və texnologiya üzrə direktor müavini', NULL, 'rehberlik',
   NULL, 'Direktor müavini',
   'İnnovasiya və rəqəmsal texnologiyaların tətbiqi', 3),

  ('10000000-0000-0000-0000-000000000005', '10000000-0000-0000-0000-000000000001',
   'Beynəlxalq əlaqələr üzrə direktor müavini', NULL, 'rehberlik',
   NULL, 'Direktor müavini',
   'Beynəlxalq əməkdaşlıq və layihələrin koordinasiyası', 4),

  ('10000000-0000-0000-0000-000000000006', '10000000-0000-0000-0000-000000000001',
   'Maliyyə və inzibati işlər üzrə direktor müavini', NULL, 'rehberlik',
   NULL, 'Direktor müavini',
   'Maliyyə, kadr və inzibati işlərin idarə edilməsi', 5),

  ('10000000-0000-0000-0000-000000000007', '10000000-0000-0000-0000-000000000001',
   'Strateji planlaşdırma üzrə direktor müavini', NULL, 'rehberlik',
   NULL, 'Direktor müavini',
   'Strateji planlaşdırma və inkişaf proqramları', 6),

  ('10000000-0000-0000-0000-000000000008', '10000000-0000-0000-0000-000000000001',
   'Keyfiyyət təminatı üzrə direktor müavini', NULL, 'rehberlik',
   NULL, 'Direktor müavini',
   'Keyfiyyət təminatı və monitorinq sistemləri', 7);

-- =============================================
-- 2. Mərkəzlər (8 ədəd)
-- =============================================

INSERT INTO org_units (id, parent_id, name, short_name, unit_type, description, address, phone, sort_order)
VALUES
  ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001',
   'Kurikulum Mərkəzi', 'KM', 'merkez',
   'Ümumi təhsil üzrə kurikulum və tədris proqramlarının hazırlanması, təkmilləşdirilməsi və qiymətləndirilməsi',
   'Bakı şəh., Yasamal r.', '+994 12 XXX XX XX', 10),

  ('20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001',
   'Qiymətləndirmə Mərkəzi', 'QM', 'merkez',
   'Təhsil sahəsində qiymətləndirmə alətlərinin hazırlanması, milli və beynəlxalq qiymətləndirmələrin aparılması',
   'Bakı şəh., Yasamal r.', '+994 12 XXX XX XX', 11),

  ('20000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000001',
   'Müəllim Peşəkar İnkişafı Mərkəzi', 'MPİM', 'merkez',
   'Müəllimlərin peşəkar inkişafının təmin edilməsi, təlim proqramlarının hazırlanması və həyata keçirilməsi',
   'Bakı şəh., Yasamal r.', '+994 12 XXX XX XX', 12),

  ('20000000-0000-0000-0000-000000000004', '10000000-0000-0000-0000-000000000001',
   'Təhsil Texnologiyaları Mərkəzi', 'TTM', 'merkez',
   'Rəqəmsal təhsil texnologiyalarının tətbiqi, e-tədris platformalarının inkişafı',
   'Bakı şəh., Yasamal r.', '+994 12 XXX XX XX', 13),

  ('20000000-0000-0000-0000-000000000005', '10000000-0000-0000-0000-000000000001',
   'Təhsil Siyasəti və Araşdırmalar Mərkəzi', 'TSAM', 'merkez',
   'Təhsil siyasətinin analizi, strateji araşdırmalar və tövsiyələrin hazırlanması',
   'Bakı şəh., Yasamal r.', '+994 12 XXX XX XX', 14),

  ('20000000-0000-0000-0000-000000000006', '10000000-0000-0000-0000-000000000001',
   'İnklüziv Təhsil Mərkəzi', 'İTM', 'merkez',
   'İnklüziv təhsilin inkişafı, xüsusi təhsil ehtiyacı olan şagirdlər üçün proqramların hazırlanması',
   'Bakı şəh., Yasamal r.', '+994 12 XXX XX XX', 15),

  ('20000000-0000-0000-0000-000000000007', '10000000-0000-0000-0000-000000000001',
   'Məktəbəqədər və İbtidai Təhsil Mərkəzi', 'MİTM', 'merkez',
   'Məktəbəqədər və ibtidai təhsil sahəsində metodik dəstək və proqramların hazırlanması',
   'Bakı şəh., Yasamal r.', '+994 12 XXX XX XX', 16),

  ('20000000-0000-0000-0000-000000000008', '10000000-0000-0000-0000-000000000001',
   'Dərslik və Tədris Resursları Mərkəzi', 'DTRM', 'merkez',
   'Dərsliklərin və tədris resurslarının hazırlanması, ekspertizası və nəşrinin koordinasiyası',
   'Bakı şəh., Yasamal r.', '+994 12 XXX XX XX', 17);

-- =============================================
-- 3. Şöbələr (8 ədəd)
-- =============================================

INSERT INTO org_units (id, parent_id, name, short_name, unit_type, description, sort_order)
VALUES
  ('30000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001',
   'Beynəlxalq Əməkdaşlıq Şöbəsi', 'BƏŞ', 'shobe',
   'Beynəlxalq təşkilatlarla əməkdaşlıq, müqavilələr və layihələrin idarə edilməsi', 20),

  ('30000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001',
   'Elmi-Tədqiqat və İnnovasiya Şöbəsi', 'ETİŞ', 'shobe',
   'Elmi tədqiqatların planlaşdırılması, koordinasiyası və nəticələrin tətbiqi', 21),

  ('30000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000001',
   'Monitorinq və Qiymətləndirmə Şöbəsi', 'MQŞ', 'shobe',
   'Təhsil keyfiyyətinin monitorinqi, hesabatların hazırlanması', 22),

  ('30000000-0000-0000-0000-000000000004', '10000000-0000-0000-0000-000000000001',
   'İnsan Resursları və Kadr Şöbəsi', 'İRKŞ', 'shobe',
   'Kadr siyasəti, işə qəbul, əmək münasibətləri', 23),

  ('30000000-0000-0000-0000-000000000005', '10000000-0000-0000-0000-000000000001',
   'Maliyyə və Mühasibatlıq Şöbəsi', 'MMŞ', 'shobe',
   'Büdcə planlaşdırması, maliyyə hesabatları, mühasibatlıq', 24),

  ('30000000-0000-0000-0000-000000000006', '10000000-0000-0000-0000-000000000001',
   'İnformasiya Texnologiyaları Şöbəsi', 'İTŞ', 'shobe',
   'İT infrastrukturu, proqram təminatı, kibertəhlükəsizlik', 25),

  ('30000000-0000-0000-0000-000000000007', '10000000-0000-0000-0000-000000000001',
   'Hüquq və Sənədləşmə Şöbəsi', 'HSŞ', 'shobe',
   'Hüquqi dəstək, normativ sənədlər, müqavilələr', 26),

  ('30000000-0000-0000-0000-000000000008', '10000000-0000-0000-0000-000000000001',
   'İctimaiyyətlə Əlaqələr və Kommunikasiya Şöbəsi', 'İƏKŞ', 'shobe',
   'Media əlaqələri, ictimai məlumatlandırma, kommunikasiya strategiyası', 27);

-- =============================================
-- 4. Fəaliyyət Sahələri (16+ ədəd)
-- =============================================

INSERT INTO activity_areas (id, unit_id, name, category, description, status, priority)
VALUES
  -- Kurikulum Mərkəzi
  ('40000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001',
   'Ümumi təhsil kurikulumunun təkmilləşdirilməsi', 'tedris',
   'K-11 kurikulumunun yenilənməsi, fənn proqramlarının hazırlanması', 'aktiv', 5),

  ('40000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000001',
   'Fənn standartlarının hazırlanması', 'metodik',
   'Təhsil standartlarının beynəlxalq təcrübə əsasında hazırlanması', 'aktiv', 4),

  -- Qiymətləndirmə Mərkəzi
  ('40000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000002',
   'Milli qiymətləndirmə proqramları', 'tedris',
   'PISA, TIMSS, PIRLS kimi beynəlxalq qiymətləndirmələrə hazırlıq və milli qiymətləndirmələrin aparılması', 'aktiv', 5),

  ('40000000-0000-0000-0000-000000000004', '20000000-0000-0000-0000-000000000002',
   'Test bankının inkişafı', 'innovasiya',
   'CAT, IRT, MST əsaslı qiymətləndirmə alətlərinin yaradılması', 'aktiv', 4),

  -- Müəllim Peşəkar İnkişafı Mərkəzi
  ('40000000-0000-0000-0000-000000000005', '20000000-0000-0000-0000-000000000003',
   'Müəllim təlim proqramları', 'tedris',
   'Müəllimlərin peşəkar inkişafı üçün təlim kurslarının hazırlanması və keçirilməsi', 'aktiv', 5),

  ('40000000-0000-0000-0000-000000000006', '20000000-0000-0000-0000-000000000003',
   'Müəllim sertifikasiya sistemi', 'metodik',
   'Müəllimlərin peşəkarlıq səviyyəsinin qiymətləndirilməsi və sertifikasiya', 'aktiv', 4),

  -- Təhsil Texnologiyaları Mərkəzi
  ('40000000-0000-0000-0000-000000000007', '20000000-0000-0000-0000-000000000004',
   'E-tədris platformalarının inkişafı', 'texnoloji',
   'Onlayn tədris platformalarının yaradılması və idarə edilməsi', 'aktiv', 5),

  ('40000000-0000-0000-0000-000000000008', '20000000-0000-0000-0000-000000000004',
   'Rəqəmsal kontent hazırlanması', 'innovasiya',
   'İnteraktiv dərs materialları, video dərslər, simulyasiyalar', 'aktiv', 4),

  -- Təhsil Siyasəti və Araşdırmalar Mərkəzi
  ('40000000-0000-0000-0000-000000000009', '20000000-0000-0000-0000-000000000005',
   'Təhsil siyasəti araşdırmaları', 'tedqiqat',
   'Təhsil sisteminin müxtəlif aspektlərinin tədqiqi və siyasət tövsiyələrinin hazırlanması', 'aktiv', 5),

  ('40000000-0000-0000-0000-000000000010', '20000000-0000-0000-0000-000000000005',
   'Statistik təhlil və hesabatlar', 'tedqiqat',
   'Təhsil statistikasının toplanması, təhlili və hesabatların hazırlanması', 'aktiv', 3),

  -- İnklüziv Təhsil Mərkəzi
  ('40000000-0000-0000-0000-000000000011', '20000000-0000-0000-0000-000000000006',
   'İnklüziv təhsil proqramları', 'tedris',
   'Xüsusi ehtiyacı olan şagirdlər üçün təhsil proqramlarının hazırlanması', 'aktiv', 5),

  ('40000000-0000-0000-0000-000000000012', '20000000-0000-0000-0000-000000000006',
   'Psixoloji dəstək xidmətləri', 'metodik',
   'Məktəb psixoloqları üçün metodik dəstək və vəsaitlər', 'aktiv', 4),

  -- Məktəbəqədər və İbtidai Təhsil Mərkəzi
  ('40000000-0000-0000-0000-000000000013', '20000000-0000-0000-0000-000000000007',
   'Məktəbəqədər təhsil proqramları', 'tedris',
   'Məktəbəqədər yaş qrupları üçün inkişaf proqramlarının hazırlanması', 'aktiv', 4),

  ('40000000-0000-0000-0000-000000000014', '20000000-0000-0000-0000-000000000007',
   'İbtidai sinif metodikası', 'metodik',
   'İbtidai siniflərdə tədrisin müasir metodlarla təşkili', 'aktiv', 4),

  -- Dərslik və Tədris Resursları Mərkəzi
  ('40000000-0000-0000-0000-000000000015', '20000000-0000-0000-0000-000000000008',
   'Dərslik hazırlanması və ekspertizası', 'metodik',
   'Yeni dərsliklərin yazılması, redaktəsi və ekspert qiymətləndirilməsi', 'aktiv', 5),

  ('40000000-0000-0000-0000-000000000016', '20000000-0000-0000-0000-000000000008',
   'Metodik vəsaitlərin hazırlanması', 'metodik',
   'Müəllimlər üçün metodik tövsiyələr və tədris vəsaitlərinin yaradılması', 'aktiv', 4),

  -- Beynəlxalq Əməkdaşlıq Şöbəsi
  ('40000000-0000-0000-0000-000000000017', '30000000-0000-0000-0000-000000000001',
   'Beynəlxalq layihələrin koordinasiyası', 'beynelxalq',
   'UNESCO, Dünya Bankı, UNICEF və digər təşkilatlarla birgə layihələr', 'aktiv', 4),

  -- Elmi-Tədqiqat və İnnovasiya Şöbəsi
  ('40000000-0000-0000-0000-000000000018', '30000000-0000-0000-0000-000000000002',
   'Təhsil innovasiyaları və tədqiqatlar', 'tedqiqat',
   'Təhsil sahəsində yeni yanaşmaların tədqiqi və tətbiqi', 'aktiv', 5);

COMMIT;
