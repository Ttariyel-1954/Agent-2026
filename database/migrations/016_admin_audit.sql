-- =============================================
-- Miqrasiya 016: Admin Panel — Sistem Parametrləri və Audit Logları
-- Tarix: 2026-02-20
-- Təsvir: system_settings və audit_logs cədvəllərinin yaradılması
-- =============================================

BEGIN;

-- Sistem parametrləri cədvəli
CREATE TABLE IF NOT EXISTS system_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key VARCHAR(100) UNIQUE NOT NULL,
    value TEXT,
    description TEXT,
    updated_by UUID REFERENCES users(id),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Audit logları cədvəli
CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id),
    action VARCHAR(100) NOT NULL,
    entity_type VARCHAR(50),
    entity_id UUID,
    details JSONB,
    ip_address INET,
    created_at TIMESTAMP DEFAULT NOW()
);

-- İndekslər
CREATE INDEX IF NOT EXISTS idx_system_settings_key ON system_settings(key);
CREATE INDEX IF NOT EXISTS idx_audit_logs_user ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created ON audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_entity ON audit_logs(entity_type, entity_id);

-- Miqrasiya qeydiyyatı
INSERT INTO schema_migrations (version, description) VALUES
    ('016', 'Admin panel - sistem parametrləri və audit logları')
ON CONFLICT (version) DO NOTHING;

COMMIT;
