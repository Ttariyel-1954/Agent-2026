-- =============================================
-- ARTI-2026: ai_responses cədvəlinin genişləndirilməsi
-- Əlavə sütunlar: provider, status, input_tokens, output_tokens,
--   estimated_cost, prompt_text, response_text, error_message
-- =============================================

-- Provayder (claude, gpt, auto)
ALTER TABLE ai_responses ADD COLUMN IF NOT EXISTS provider VARCHAR(50);

-- Status (success, error)
ALTER TABLE ai_responses ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'success';

-- Ayrı token sayları
ALTER TABLE ai_responses ADD COLUMN IF NOT EXISTS input_tokens INTEGER DEFAULT 0;
ALTER TABLE ai_responses ADD COLUMN IF NOT EXISTS output_tokens INTEGER DEFAULT 0;

-- Təxmini xərc
ALTER TABLE ai_responses ADD COLUMN IF NOT EXISTS estimated_cost DECIMAL(10,6) DEFAULT 0;

-- Prompt mətni (input_text-dən ayrı — sorğu mətni)
ALTER TABLE ai_responses ADD COLUMN IF NOT EXISTS prompt_text TEXT;

-- Cavab mətni (output_text-dən ayrı — tam cavab)
ALTER TABLE ai_responses ADD COLUMN IF NOT EXISTS response_text TEXT;

-- Xəta mesajı
ALTER TABLE ai_responses ADD COLUMN IF NOT EXISTS error_message TEXT;

-- Mövcud sətirləri yeniləmə: tokens_used-dan input_tokens/output_tokens-a bölmə
UPDATE ai_responses
SET input_tokens = COALESCE(tokens_used, 0),
    output_tokens = 0,
    status = 'success',
    prompt_text = LEFT(input_text, 500),
    response_text = output_text
WHERE input_tokens IS NULL OR input_tokens = 0;

-- Əlavə indekslər
CREATE INDEX IF NOT EXISTS idx_ai_responses_provider ON ai_responses(provider);
CREATE INDEX IF NOT EXISTS idx_ai_responses_status ON ai_responses(status);
