-- =============================================
-- ARTI-2026: Test İstifadəçilər Seed Data
-- 5 test istifadəçi — müxtəlif rollar
-- =============================================

-- Qeyd: Şifrə hash-ləri nümunədir. Real mühitdə hash_password() funksiyası ilə yaradılmalıdır.
-- Bütün test istifadəçilərin şifrəsi: Test1234!

INSERT INTO users (id, username, email, password_hash, first_name, last_name, role, phone, is_active, created_at, updated_at) VALUES
    -- Admin istifadəçi
    (gen_random_uuid(), 'admin',
     'admin@arti2026.az',
     'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
     'Sistem', 'Administratoru', 'admin',
     '+994501000001', TRUE, NOW(), NOW()),

    -- Müəllim istifadəçi
    (gen_random_uuid(), 'muellim.test',
     'muellim@arti2026.az',
     'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
     'Əli', 'Həsənov', 'teacher',
     '+994502000002', TRUE, NOW(), NOW()),

    -- Şagird istifadəçi
    (gen_random_uuid(), 'sagird.test',
     'sagird@arti2026.az',
     'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
     'Fatimə', 'Məmmədova', 'student',
     '+994553000003', TRUE, NOW(), NOW()),

    -- Valideyn istifadəçi
    (gen_random_uuid(), 'valideyn.test',
     'valideyn@arti2026.az',
     'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
     'Kamran', 'Əliyev', 'parent',
     '+994704000004', TRUE, NOW(), NOW()),

    -- Müfəttiş / Metodist istifadəçi
    (gen_random_uuid(), 'metodist.test',
     'metodist@arti2026.az',
     'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
     'Aynur', 'Hüseynova', 'inspector',
     '+994775000005', TRUE, NOW(), NOW())
ON CONFLICT (username) DO NOTHING;
