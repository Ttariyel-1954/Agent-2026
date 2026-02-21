-- =============================================
-- ARTI-2026: AI Tutor Söhbət Tarixçəsi
-- Miqrasiya 007
-- =============================================

BEGIN;

CREATE TABLE IF NOT EXISTS ai_tutor_chats (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    role VARCHAR(10) NOT NULL CHECK (role IN ('user', 'assistant')),
    content TEXT NOT NULL,
    subject VARCHAR(100),
    tokens_used INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_ai_tutor_student ON ai_tutor_chats(student_id);
CREATE INDEX idx_ai_tutor_created ON ai_tutor_chats(created_at DESC);
CREATE INDEX idx_ai_tutor_student_date ON ai_tutor_chats(student_id, created_at DESC);

INSERT INTO schema_migrations (version, description)
VALUES ('007', 'AI Tutor söhbət tarixçəsi cədvəli');

COMMIT;
