-- =============================================
-- ARTI-2026: AI Cavablarının Saxlanması — Supabase Miqrasiya
-- =============================================

-- AI cavabları audit cədvəli (Supabase-uyğun)
CREATE TABLE IF NOT EXISTS ai_responses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id),
    task_type VARCHAR(50) NOT NULL,
    input_text TEXT,
    output_text TEXT,
    model VARCHAR(50),
    tokens_used INTEGER DEFAULT 0,
    response_time_ms INTEGER,
    created_at TIMESTAMP DEFAULT NOW()
);

-- RLS (Row Level Security) aktiv et
ALTER TABLE ai_responses ENABLE ROW LEVEL SECURITY;

-- İstifadəçilər yalnız öz cavablarını görə bilər
CREATE POLICY "İstifadəçilər öz AI cavablarını oxuya bilər"
    ON ai_responses FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "İstifadəçilər AI cavab yarada bilər"
    ON ai_responses FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- İndekslər
CREATE INDEX IF NOT EXISTS idx_ai_responses_user ON ai_responses(user_id);
CREATE INDEX IF NOT EXISTS idx_ai_responses_task_type ON ai_responses(task_type);
CREATE INDEX IF NOT EXISTS idx_ai_responses_created ON ai_responses(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_responses_model ON ai_responses(model);
