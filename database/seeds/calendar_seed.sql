-- =============================================
-- ARTI-2026: Təqvim Seed Data
-- 2025-2026 akademik ili üçün nümunə hadisələr
-- =============================================

-- Tətillər
INSERT INTO calendar_events (id, title, description, event_type, start_date, end_date, is_all_day, color, is_active, created_at) VALUES
    (gen_random_uuid(), 'Yay Tətili Sonu', 'Yeni tədris ilinin başlanması', 'holiday', '2025-09-15', '2025-09-15', TRUE, '#27ae60', TRUE, NOW()),
    (gen_random_uuid(), 'Respublika Günü', '18 Oktyabr - Dövlət Müstəqilliyi Günü', 'holiday', '2025-10-18', '2025-10-18', TRUE, '#27ae60', TRUE, NOW()),
    (gen_random_uuid(), 'Qış Tətili', 'Qış tətili dövrü', 'holiday', '2025-12-31', '2026-01-11', TRUE, '#27ae60', TRUE, NOW()),
    (gen_random_uuid(), 'Novruz Bayramı', 'Novruz tətili', 'holiday', '2026-03-20', '2026-03-28', TRUE, '#27ae60', TRUE, NOW()),
    (gen_random_uuid(), 'Ramazan Bayramı', 'Ramazan bayramı tətili', 'holiday', '2026-03-30', '2026-03-31', TRUE, '#27ae60', TRUE, NOW()),
    (gen_random_uuid(), 'Qurban Bayramı', 'Qurban bayramı tətili', 'holiday', '2026-06-06', '2026-06-07', TRUE, '#27ae60', TRUE, NOW()),
    (gen_random_uuid(), '9 May Qələbə Günü', 'Faşizm üzərində qələbə günü', 'holiday', '2026-05-09', '2026-05-09', TRUE, '#27ae60', TRUE, NOW()),
    (gen_random_uuid(), '28 May Respublika Günü', 'Azərbaycan Xalq Cümhuriyyətinin yaranma günü', 'holiday', '2026-05-28', '2026-05-28', TRUE, '#27ae60', TRUE, NOW());

-- İmtahan dövrləri
INSERT INTO calendar_events (id, title, description, event_type, start_date, end_date, is_all_day, color, is_active, created_at) VALUES
    (gen_random_uuid(), 'I Yarımil İmtahan Dövrü', 'Birinci yarımillik imtahanlar', 'exam', '2025-12-15', '2025-12-27', TRUE, '#e74c3c', TRUE, NOW()),
    (gen_random_uuid(), 'II Yarımil Aralıq İmtahanı', 'İkinci yarımil aralıq qiymətləndirmə', 'exam', '2026-03-09', '2026-03-13', TRUE, '#e74c3c', TRUE, NOW()),
    (gen_random_uuid(), 'Buraxılış İmtahanları', 'Son sinif buraxılış imtahanları', 'exam', '2026-05-15', '2026-06-05', TRUE, '#e74c3c', TRUE, NOW()),
    (gen_random_uuid(), 'II Yarımil Yekun İmtahanları', 'İkinci yarımillik yekun qiymətləndirmə', 'exam', '2026-05-25', '2026-06-10', TRUE, '#e74c3c', TRUE, NOW());

-- İclaslar
INSERT INTO calendar_events (id, title, description, event_type, start_date, start_time, end_time, is_all_day, location, color, is_active, created_at) VALUES
    (gen_random_uuid(), 'Pedaqoji Şura', 'İlin ilk pedaqoji şura iclası', 'meeting', '2025-09-01', '10:00', '13:00', FALSE, 'Böyük iclas zalı', '#3498db', TRUE, NOW()),
    (gen_random_uuid(), 'Metodiki Birləşmə İclası', 'Fənn müəllimlərinin aylıq iclası', 'meeting', '2025-10-15', '14:00', '16:00', FALSE, 'Metodiki kabinet', '#3498db', TRUE, NOW()),
    (gen_random_uuid(), 'Valideyn İclası', 'I rüb valideyn iclası', 'meeting', '2025-11-20', '18:00', '20:00', FALSE, 'Sinif otaqları', '#3498db', TRUE, NOW()),
    (gen_random_uuid(), 'İlin Yekun Pedaqoji Şurası', 'Akademik il yekun iclası', 'meeting', '2026-06-15', '10:00', '13:00', FALSE, 'Böyük iclas zalı', '#3498db', TRUE, NOW());

-- Son tarixlər
INSERT INTO calendar_events (id, title, description, event_type, start_date, is_all_day, color, is_active, created_at) VALUES
    (gen_random_uuid(), 'Qeydiyyat Son Tarix', 'Yeni şagird qeydiyyatı üçün son tarix', 'deadline', '2025-09-30', TRUE, '#f39c12', TRUE, NOW()),
    (gen_random_uuid(), 'I Yarımil Qiymət Daxiletmə', 'I yarımil qiymətlərinin daxil edilməsi üçün son tarix', 'deadline', '2026-01-15', TRUE, '#f39c12', TRUE, NOW());

-- Təlimlər
INSERT INTO calendar_events (id, title, description, event_type, start_date, end_date, start_time, end_time, is_all_day, location, color, is_active, created_at) VALUES
    (gen_random_uuid(), 'Rəqəmsal Təhsil Təlimi', 'Müəllimlər üçün rəqəmsal alətlər təlimi', 'training', '2025-10-05', '2025-10-06', '09:00', '17:00', FALSE, 'Kompüter laboratoriyası', '#9b59b6', TRUE, NOW()),
    (gen_random_uuid(), 'IRT/CAT Təlimi', 'Qiymətləndirmə mütəxəssisləri üçün təlim', 'training', '2025-11-10', '2025-11-12', '09:00', '16:00', FALSE, 'Təlim mərkəzi', '#9b59b6', TRUE, NOW()),
    (gen_random_uuid(), 'AI Alətləri Təlimi', 'Süni intellekt alətlərindən istifadə təlimi', 'training', '2026-02-15', '2026-02-16', '10:00', '16:00', FALSE, 'Onlayn', '#9b59b6', TRUE, NOW());
