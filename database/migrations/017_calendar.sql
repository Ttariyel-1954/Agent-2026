-- =============================================
-- Miqrasiya 017: Akademik Təqvim
-- Tarix: 2026-02-20
-- Təsvir: calendar_events cədvəlinin yaradılması
-- =============================================

BEGIN;

-- Təqvim hadisələri cədvəli
CREATE TABLE IF NOT EXISTS calendar_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(200) NOT NULL,
    description TEXT,
    event_type VARCHAR(50) NOT NULL CHECK (event_type IN ('exam', 'holiday', 'meeting', 'deadline', 'training', 'other')),
    start_date DATE NOT NULL,
    end_date DATE,
    start_time TIME,
    end_time TIME,
    is_all_day BOOLEAN DEFAULT TRUE,
    location VARCHAR(200),
    subject_id UUID REFERENCES subjects(id),
    grade_level INTEGER,
    created_by UUID REFERENCES users(id),
    school_id UUID REFERENCES schools(id),
    is_recurring BOOLEAN DEFAULT FALSE,
    recurrence_rule VARCHAR(100),
    color VARCHAR(7) DEFAULT '#3498db',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- İndekslər
CREATE INDEX IF NOT EXISTS idx_calendar_events_dates ON calendar_events(start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_calendar_events_type ON calendar_events(event_type);
CREATE INDEX IF NOT EXISTS idx_calendar_events_school ON calendar_events(school_id);
CREATE INDEX IF NOT EXISTS idx_calendar_events_active ON calendar_events(is_active);
CREATE INDEX IF NOT EXISTS idx_calendar_events_created_by ON calendar_events(created_by);

-- Miqrasiya qeydiyyatı
INSERT INTO schema_migrations (version, description) VALUES
    ('017', 'Akademik təqvim - calendar_events cədvəli')
ON CONFLICT (version) DO NOTHING;

COMMIT;
