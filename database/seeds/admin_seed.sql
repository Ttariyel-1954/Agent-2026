-- =============================================
-- ARTI-2026: Admin Seed Data
-- Sistem parametrləri və nümunə audit logları
-- =============================================

-- Sistem parametrləri
INSERT INTO system_settings (id, key, value, description, updated_at) VALUES
    (gen_random_uuid(), 'app_name', 'ARTI-2026', 'Tətbiqin adı', NOW()),
    (gen_random_uuid(), 'default_language', 'az', 'Standart dil (az, en, ru)', NOW()),
    (gen_random_uuid(), 'academic_year', '2025-2026', 'Cari akademik il', NOW()),
    (gen_random_uuid(), 'grading_system', '100', 'Qiymətləndirmə sistemi (100, 5, ects)', NOW()),
    (gen_random_uuid(), 'max_login_attempts', '5', 'Maksimum giriş cəhdi sayı', NOW()),
    (gen_random_uuid(), 'session_timeout', '30', 'Sessiya vaxtı (dəqiqə)', NOW()),
    (gen_random_uuid(), 'password_min_length', '8', 'Minimum şifrə uzunluğu', NOW()),
    (gen_random_uuid(), 'require_2fa', 'FALSE', 'İki faktorlu doğrulama tələb edilsin', NOW()),
    (gen_random_uuid(), 'ai_daily_limit', '50', 'Gündəlik AI sorğu limiti', NOW()),
    (gen_random_uuid(), 'ai_default_model', 'claude', 'Standart AI model (claude, gpt)', NOW()),
    (gen_random_uuid(), 'ai_max_tokens', '2000', 'Maks. AI cavab token sayı', NOW()),
    (gen_random_uuid(), 'maintenance_mode', 'FALSE', 'Texniki xidmət rejimi', NOW()),
    (gen_random_uuid(), 'maintenance_message', 'Sistem texniki xidmət rejimindədir.', 'Texniki xidmət mesajı', NOW()),
    (gen_random_uuid(), 'backup_frequency', 'daily', 'Ehtiyat nüsxə tezliyi (daily, weekly)', NOW()),
    (gen_random_uuid(), 'notification_email', 'admin@arti2026.az', 'Bildiriş e-poçt ünvanı', NOW())
ON CONFLICT (key) DO NOTHING;

-- Nümunə audit logları
INSERT INTO audit_logs (id, user_id, action, entity_type, details, created_at) VALUES
    (gen_random_uuid(), (SELECT id FROM users WHERE role = 'admin' LIMIT 1), 'system_start', 'system',
     '{"version": "1.0.0"}'::jsonb, NOW() - interval '7 days'),
    (gen_random_uuid(), (SELECT id FROM users WHERE role = 'admin' LIMIT 1), 'settings_update', 'system_settings',
     '{"updated_keys": ["app_name", "academic_year"]}'::jsonb, NOW() - interval '6 days'),
    (gen_random_uuid(), (SELECT id FROM users WHERE role = 'admin' LIMIT 1), 'user_create', 'user',
     '{"username": "test_teacher", "role": "teacher"}'::jsonb, NOW() - interval '5 days'),
    (gen_random_uuid(), (SELECT id FROM users WHERE role = 'admin' LIMIT 1), 'user_create', 'user',
     '{"username": "test_student", "role": "student"}'::jsonb, NOW() - interval '4 days'),
    (gen_random_uuid(), (SELECT id FROM users WHERE role = 'teacher' LIMIT 1), 'student_import', 'student',
     '{"total": 25, "success": 23, "failed": 2}'::jsonb, NOW() - interval '3 days'),
    (gen_random_uuid(), (SELECT id FROM users WHERE role = 'admin' LIMIT 1), 'settings_update', 'system_settings',
     '{"updated_keys": ["ai_daily_limit"]}'::jsonb, NOW() - interval '2 days'),
    (gen_random_uuid(), (SELECT id FROM users WHERE role = 'teacher' LIMIT 1), 'grade_import', 'grade',
     '{"subject": "Riyaziyyat", "total": 30, "success": 30, "failed": 0}'::jsonb, NOW() - interval '1 day'),
    (gen_random_uuid(), (SELECT id FROM users WHERE role = 'admin' LIMIT 1), 'event_create', 'calendar_event',
     '{"title": "Yarımillik imtahan", "type": "exam"}'::jsonb, NOW() - interval '12 hours'),
    (gen_random_uuid(), (SELECT id FROM users WHERE role = 'admin' LIMIT 1), 'user_deactivate', 'user',
     '{"reason": "Test hesab"}'::jsonb, NOW() - interval '6 hours'),
    (gen_random_uuid(), (SELECT id FROM users WHERE role = 'admin' LIMIT 1), 'backup_complete', 'system',
     '{"size_mb": 156, "duration_sec": 45}'::jsonb, NOW() - interval '1 hour');
