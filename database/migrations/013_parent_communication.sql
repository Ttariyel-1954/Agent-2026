-- =============================================
-- Migration 013: Valideyn Əlaqə Sistemi
-- Tarix: 2026-02-20
-- Təsvir: AI məktub generasiyası, SMS/E-poçt
--          göndərmə, müəllim təsdiqi
-- =============================================

BEGIN;

-- === 1. Valideyn Məktubları ===
CREATE TABLE IF NOT EXISTS parent_letters (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    academic_year VARCHAR(20) NOT NULL DEFAULT '2025-2026',
    report_month INTEGER NOT NULL CHECK (report_month BETWEEN 1 AND 12),

    -- AI nəticəsi
    letter_json JSONB,
    letter_text TEXT,
    letter_html TEXT,

    -- Müəllim redaktəsi
    teacher_edits TEXT,
    edited_at TIMESTAMP,

    -- Status idarəetmə
    status VARCHAR(20) NOT NULL DEFAULT 'draft' CHECK (status IN (
        'draft', 'edited', 'approved', 'sent', 'failed'
    )),
    approved_by UUID REFERENCES users(id),
    approved_at TIMESTAMP,

    -- Göndərmə
    sent_via VARCHAR(20) CHECK (sent_via IN ('email', 'sms', 'both', 'none')),
    sent_at TIMESTAMP,
    recipient_name VARCHAR(200),
    recipient_email VARCHAR(255),
    recipient_phone VARCHAR(20),

    -- AI metadata
    ai_model VARCHAR(50),
    tokens_used INTEGER DEFAULT 0,

    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    UNIQUE(student_id, academic_year, report_month)
);

CREATE INDEX IF NOT EXISTS idx_parent_letters_student
    ON parent_letters(student_id);
CREATE INDEX IF NOT EXISTS idx_parent_letters_status
    ON parent_letters(status);
CREATE INDEX IF NOT EXISTS idx_parent_letters_month
    ON parent_letters(academic_year, report_month);

-- === 2. Göndərmə Jurnalı ===
CREATE TABLE IF NOT EXISTS parent_message_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    letter_id UUID NOT NULL REFERENCES parent_letters(id) ON DELETE CASCADE,
    channel VARCHAR(10) NOT NULL CHECK (channel IN ('email', 'sms')),
    recipient VARCHAR(255) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN (
        'pending', 'sent', 'delivered', 'failed', 'bounced'
    )),
    sent_at TIMESTAMP,
    delivered_at TIMESTAMP,
    error_message TEXT,
    provider_response TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_parent_message_log_letter
    ON parent_message_log(letter_id);
CREATE INDEX IF NOT EXISTS idx_parent_message_log_status
    ON parent_message_log(status);

COMMIT;
