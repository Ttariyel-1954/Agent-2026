-- =============================================
-- Miqrasiya 005: İnstitut Strukturu
-- Tarix: 2026-02-18
-- Təsvir: Təşkilati vahidlər, resurslar, kontingent,
--          fəaliyyət sahələri, KPI, layihələr
-- =============================================

BEGIN;

-- =============================================
-- 1. Təşkilati Vahidlər (Mərkəz / Şöbə / Rəhbərlik)
-- =============================================

CREATE TABLE IF NOT EXISTS org_units (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    parent_id UUID REFERENCES org_units(id) ON DELETE SET NULL,
    name VARCHAR(255) NOT NULL,
    short_name VARCHAR(50),
    unit_type VARCHAR(30) NOT NULL, -- 'rehberlik', 'merkez', 'shobe', 'laboratoriya', 'bolme'
    description TEXT,
    head_name VARCHAR(255),
    head_position VARCHAR(255),
    address VARCHAR(500),
    phone VARCHAR(50),
    email VARCHAR(255),
    website VARCHAR(255),
    established_date DATE,
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================
-- 2. Vahid Resursları (büdcə, avadanlıq, sahə, proqram təminatı)
-- =============================================

CREATE TABLE IF NOT EXISTS unit_resources (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    unit_id UUID NOT NULL REFERENCES org_units(id) ON DELETE CASCADE,
    resource_type VARCHAR(30) NOT NULL, -- 'budce', 'avadanliq', 'sahe', 'proqram', 'neqliyyat'
    name VARCHAR(255) NOT NULL,
    description TEXT,
    quantity INTEGER DEFAULT 1,
    unit_measure VARCHAR(50),
    budget_amount NUMERIC(15,2) DEFAULT 0,
    currency VARCHAR(3) DEFAULT 'AZN',
    condition VARCHAR(30) DEFAULT 'yaxsi', -- 'ela', 'yaxsi', 'kafi', 'kohnelmis'
    acquired_date DATE,
    warranty_until DATE,
    location VARCHAR(255),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================
-- 3. Kontingent (əməkdaş, tədqiqatçı, doktorant, müqavilə, təcrübəçi)
-- =============================================

CREATE TABLE IF NOT EXISTS unit_personnel (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    unit_id UUID NOT NULL REFERENCES org_units(id) ON DELETE CASCADE,
    full_name VARCHAR(255) NOT NULL,
    position VARCHAR(255),
    personnel_type VARCHAR(30) NOT NULL, -- 'emedkas', 'tedqiqatci', 'doktorant', 'muqavile', 'tecrubechi'
    employment_type VARCHAR(30) DEFAULT 'tam_shtат', -- 'tam_shtat', 'yarim_shtat', 'muqavile', 'konullu'
    education_level VARCHAR(100),
    specialization VARCHAR(255),
    phone VARCHAR(50),
    email VARCHAR(255),
    hire_date DATE,
    contract_end_date DATE,
    salary NUMERIC(10,2),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================
-- 4. Fəaliyyət Sahələri
-- =============================================

CREATE TABLE IF NOT EXISTS activity_areas (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    unit_id UUID NOT NULL REFERENCES org_units(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    category VARCHAR(50) NOT NULL, -- 'tedris', 'tedqiqat', 'metodik', 'innovasiya', 'beynelxalq', 'texnoloji'
    description TEXT,
    objectives TEXT,
    target_audience VARCHAR(255),
    start_date DATE,
    end_date DATE,
    priority INTEGER DEFAULT 3, -- 1-5
    status VARCHAR(20) DEFAULT 'aktiv', -- 'planlasdirilan', 'aktiv', 'dayandirilan', 'tamamlanmis'
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================
-- 5. KPI Göstəriciləri
-- =============================================

CREATE TABLE IF NOT EXISTS activity_kpis (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    activity_id UUID NOT NULL REFERENCES activity_areas(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    unit_measure VARCHAR(50),
    target_value NUMERIC(15,2) NOT NULL,
    baseline_value NUMERIC(15,2) DEFAULT 0,
    frequency VARCHAR(20) DEFAULT 'ayliq', -- 'gunluk', 'heftelik', 'ayliq', 'rublik', 'illik'
    weight NUMERIC(5,2) DEFAULT 1.0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================
-- 6. KPI İrəliləyiş Qeydləri
-- =============================================

CREATE TABLE IF NOT EXISTS activity_progress (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    kpi_id UUID NOT NULL REFERENCES activity_kpis(id) ON DELETE CASCADE,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    actual_value NUMERIC(15,2) NOT NULL,
    notes TEXT,
    recorded_by VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================
-- 7. Vahid Layihələri
-- =============================================

CREATE TABLE IF NOT EXISTS unit_projects (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    unit_id UUID NOT NULL REFERENCES org_units(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    project_type VARCHAR(50),
    budget NUMERIC(15,2) DEFAULT 0,
    currency VARCHAR(3) DEFAULT 'AZN',
    priority VARCHAR(20) DEFAULT 'orta', -- 'cox_yuksek', 'yuksek', 'orta', 'asagi'
    status VARCHAR(20) DEFAULT 'planlasdirilan', -- 'planlasdirilan', 'aktiv', 'dayandirilan', 'tamamlanmis', 'legv'
    start_date DATE,
    end_date DATE,
    manager_name VARCHAR(255),
    milestones JSONB DEFAULT '[]'::jsonb,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================
-- İndekslər
-- =============================================

CREATE INDEX IF NOT EXISTS idx_org_units_parent ON org_units(parent_id);
CREATE INDEX IF NOT EXISTS idx_org_units_type ON org_units(unit_type);
CREATE INDEX IF NOT EXISTS idx_org_units_active ON org_units(is_active);

CREATE INDEX IF NOT EXISTS idx_unit_resources_unit ON unit_resources(unit_id);
CREATE INDEX IF NOT EXISTS idx_unit_resources_type ON unit_resources(resource_type);

CREATE INDEX IF NOT EXISTS idx_unit_personnel_unit ON unit_personnel(unit_id);
CREATE INDEX IF NOT EXISTS idx_unit_personnel_type ON unit_personnel(personnel_type);

CREATE INDEX IF NOT EXISTS idx_activity_areas_unit ON activity_areas(unit_id);
CREATE INDEX IF NOT EXISTS idx_activity_kpis_activity ON activity_kpis(activity_id);
CREATE INDEX IF NOT EXISTS idx_activity_progress_kpi ON activity_progress(kpi_id);

CREATE INDEX IF NOT EXISTS idx_unit_projects_unit ON unit_projects(unit_id);
CREATE INDEX IF NOT EXISTS idx_unit_projects_status ON unit_projects(status);

-- =============================================
-- Yenilənmə triggerləri
-- =============================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
DECLARE
    tbl TEXT;
BEGIN
    FOREACH tbl IN ARRAY ARRAY['org_units', 'unit_resources', 'unit_personnel', 'activity_areas', 'activity_kpis', 'activity_progress', 'unit_projects']
    LOOP
        EXECUTE format(
            'DROP TRIGGER IF EXISTS trg_%s_updated_at ON %I; CREATE TRIGGER trg_%s_updated_at BEFORE UPDATE ON %I FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();',
            tbl, tbl, tbl, tbl
        );
    END LOOP;
END;
$$;

COMMIT;
