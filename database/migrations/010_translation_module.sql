-- =============================================
-- 010: Tərcümə Modulu
-- Tarix: 2026-02-20
-- Kontekstli tərcümə sistemi: terminologiya və tarixçə
-- =============================================

BEGIN;

-- 1. Təhsil terminologiyası lüğəti
CREATE TABLE IF NOT EXISTS translation_terminology (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    source_term VARCHAR(500) NOT NULL,
    target_term VARCHAR(500) NOT NULL,
    source_lang VARCHAR(10) NOT NULL DEFAULT 'en',
    target_lang VARCHAR(10) NOT NULL DEFAULT 'az',
    domain VARCHAR(50) NOT NULL DEFAULT 'general'
        CHECK (domain IN ('curriculum', 'assessment', 'pisa', 'pedagogy', 'irt', 'general')),
    subject_id UUID REFERENCES subjects(id) ON DELETE SET NULL,
    confidence NUMERIC(3,2) DEFAULT 1.00 CHECK (confidence >= 0 AND confidence <= 1),
    is_verified BOOLEAN DEFAULT FALSE,
    notes TEXT,
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(source_term, target_term, source_lang, target_lang, domain)
);

CREATE INDEX idx_term_domain ON translation_terminology(domain);
CREATE INDEX idx_term_langs ON translation_terminology(source_lang, target_lang);
CREATE INDEX idx_term_subject ON translation_terminology(subject_id);
CREATE INDEX idx_term_verified ON translation_terminology(is_verified);

-- 2. Tərcümə audit izi
CREATE TABLE IF NOT EXISTS translation_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    source_text TEXT NOT NULL,
    translated_text TEXT NOT NULL,
    source_lang VARCHAR(10) NOT NULL DEFAULT 'en',
    target_lang VARCHAR(10) NOT NULL DEFAULT 'az',
    translation_type VARCHAR(50) NOT NULL DEFAULT 'general'
        CHECK (translation_type IN ('curriculum', 'research', 'pisa', 'general')),
    domain VARCHAR(50) DEFAULT 'general',
    subject_id UUID REFERENCES subjects(id) ON DELETE SET NULL,
    tokens_used INTEGER DEFAULT 0,
    model_used VARCHAR(50),
    quality_score NUMERIC(3,2) CHECK (quality_score IS NULL OR (quality_score >= 0 AND quality_score <= 5)),
    is_verified BOOLEAN DEFAULT FALSE,
    verified_by UUID REFERENCES users(id) ON DELETE SET NULL,
    verified_at TIMESTAMP,
    reviewer_notes TEXT,
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_hist_type ON translation_history(translation_type);
CREATE INDEX idx_hist_langs ON translation_history(source_lang, target_lang);
CREATE INDEX idx_hist_subject ON translation_history(subject_id);
CREATE INDEX idx_hist_verified ON translation_history(is_verified);
CREATE INDEX idx_hist_created ON translation_history(created_at DESC);

COMMIT;
