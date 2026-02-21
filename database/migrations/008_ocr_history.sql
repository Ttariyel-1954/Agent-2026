-- =============================================
-- ARTI-2026: OCR Tarixçə Cədvəli
-- Miqrasiya: 008_ocr_history.sql
-- =============================================

CREATE TABLE IF NOT EXISTS ocr_history (
    id            SERIAL PRIMARY KEY,
    ocr_type      VARCHAR(50)  NOT NULL,  -- answer_sheet, student_doc, certificate
    provider      VARCHAR(20)  NOT NULL,  -- gpt, claude
    file_name     VARCHAR(255),
    result_json   JSONB,
    confidence    NUMERIC(5,2),
    created_by    VARCHAR(100) NOT NULL DEFAULT 'system',
    created_at    TIMESTAMP    NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_ocr_history_type     ON ocr_history(ocr_type);
CREATE INDEX idx_ocr_history_date     ON ocr_history(created_at);
CREATE INDEX idx_ocr_history_provider ON ocr_history(provider);

COMMENT ON TABLE  ocr_history IS 'OCR əməliyyatlarının tarixçəsi';
COMMENT ON COLUMN ocr_history.ocr_type IS 'OCR növü: answer_sheet, student_doc, certificate';
COMMENT ON COLUMN ocr_history.provider IS 'AI provayder: gpt, claude';
