-- ===============================================
-- SUPABASE DATABASE COMPLETE RECREATION
-- Run these queries in your Supabase SQL Editor
-- ===============================================

-- WARNING: This will DELETE ALL DATA and recreate tables from scratch
-- Make sure you have backups if you have important data

-- 1. ENABLE REQUIRED EXTENSIONS FIRST
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. DROP ALL EXISTING TABLES (CASCADE removes foreign keys)
DROP TABLE IF EXISTS chunk_processing_stats CASCADE;
DROP TABLE IF EXISTS chunk_embeddings CASCADE;
DROP TABLE IF EXISTS tax_brackets CASCADE;
DROP TABLE IF EXISTS tax_rules CASCADE;
DROP TABLE IF EXISTS form_schemas CASCADE;
DROP TABLE IF EXISTS tax_calculations CASCADE;
DROP TABLE IF EXISTS user_profiles CASCADE;
DROP TABLE IF EXISTS calculations CASCADE;
DROP TABLE IF EXISTS document_chunks CASCADE;
DROP TABLE IF EXISTS documents CASCADE;

-- 3. DROP EXISTING FUNCTIONS
DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;
DROP FUNCTION IF EXISTS ensure_single_active_schema() CASCADE;

-- 4. CREATE TRIGGER FUNCTION FOR UPDATED_AT
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 5. CREATE DOCUMENTS TABLE
CREATE TABLE documents (
    id TEXT PRIMARY KEY,
    filename TEXT NOT NULL,
    file_path TEXT NOT NULL,           -- Supabase Storage path
    content_type TEXT NOT NULL,
    upload_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    processed BOOLEAN DEFAULT FALSE,
    status TEXT DEFAULT 'uploaded',    -- 'uploaded', 'processing', 'chunking', 'extracting', 'completed', 'failed'
    total_chunks INTEGER DEFAULT 0,
    file_size BIGINT,
    document_type TEXT,                -- 'pdf', 'docx', 'doc', etc.
    processing_start_time TIMESTAMP,
    processing_end_time TIMESTAMP,
    processing_duration_ms INTEGER,
    error_message TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    CONSTRAINT valid_status CHECK (status IN ('uploaded', 'processing', 'chunking', 'extracting', 'embedded', 'completed', 'failed')),
    CONSTRAINT valid_document_type CHECK (document_type IN ('pdf', 'docx', 'doc', 'txt', 'html', 'xml', 'tax_document'))
);

-- 6. CREATE DOCUMENT_CHUNKS TABLE
CREATE TABLE document_chunks (
    id TEXT PRIMARY KEY,
    document_id TEXT REFERENCES documents(id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
    chunk_sequence INTEGER NOT NULL,   -- Order within document
    start_position INTEGER,            -- Character start position
    end_position INTEGER,              -- Character end position
    chunk_text TEXT NOT NULL,          -- The actual chunk content
    chunk_size INTEGER,                -- Character count
    token_count INTEGER,               -- Token count for the chunk
    chunk_type TEXT DEFAULT 'paragraph', -- 'paragraph', 'table', 'header', 'list', 'formula'
    processing_status TEXT DEFAULT 'created', -- 'created', 'scored', 'validated', 'embedded', 'stored'
    relevance_score DECIMAL(5,4),      -- Tax relevance score (0.0000-1.0000)
    context_keywords TEXT[],           -- Array of extracted keywords
    embedding vector(768),             -- Gemini text-embedding-004 (768 dimensions)
    embedding_model TEXT DEFAULT 'text-embedding-004',
    embedding_provider TEXT DEFAULT 'google_gemini',
    embedding_generated_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    CONSTRAINT unique_document_sequence UNIQUE(document_id, chunk_sequence),
    CONSTRAINT valid_chunk_type CHECK (chunk_type IN ('paragraph', 'table', 'header', 'list', 'formula', 'definition', 'example')),
    CONSTRAINT valid_processing_status CHECK (processing_status IN ('created', 'scored', 'validated', 'embedded', 'stored', 'failed')),
    CONSTRAINT valid_relevance_score CHECK (relevance_score >= 0.0 AND relevance_score <= 1.0)
);

-- 7. CREATE CHUNK_PROCESSING_STATS TABLE
CREATE TABLE chunk_processing_stats (
    id TEXT PRIMARY KEY,
    chunk_id TEXT REFERENCES document_chunks(id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
    processing_start_time TIMESTAMP,
    processing_end_time TIMESTAMP,
    gemini_api_calls INTEGER DEFAULT 0,
    rules_extracted INTEGER DEFAULT 0,
    processing_errors INTEGER DEFAULT 0,
    quality_score DECIMAL(3,2),        -- Overall processing quality (0.00-1.00)
    retry_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    CONSTRAINT valid_quality_score CHECK (quality_score >= 0.00 AND quality_score <= 1.00)
);

-- 8. CREATE TAX_RULES TABLE
CREATE TABLE tax_rules (
    id TEXT PRIMARY KEY,
    rule_type TEXT NOT NULL,           -- 'income_tax', 'vat', 'paye', etc.
    rule_category TEXT,                -- 'rates', 'exemptions', 'deductions'
    title TEXT NOT NULL,
    description TEXT,
    rule_data JSONB NOT NULL,          -- The extracted rule in structured format
    embedding vector(768),             -- Rule embedding for similarity search
    effective_date DATE,
    expiry_date DATE,
    document_source_id TEXT REFERENCES documents(id) ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    chunk_id TEXT REFERENCES document_chunks(id) ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED,
    chunk_sequence INTEGER,
    chunk_confidence DECIMAL(3,2),     -- Confidence in chunk extraction (0.00-1.00)
    extraction_context TEXT,
    cross_chunk_refs INTEGER DEFAULT 0,
    
    -- Constraints
    CONSTRAINT valid_date_range CHECK (expiry_date IS NULL OR expiry_date >= effective_date)
);

-- 9. CREATE TAX_BRACKETS TABLE
CREATE TABLE tax_brackets (
    id TEXT PRIMARY KEY,
    rule_id TEXT REFERENCES tax_rules(id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
    min_income DECIMAL(15,2),
    max_income DECIMAL(15,2),
    rate DECIMAL(5,4) NOT NULL,        -- Tax rate as decimal (e.g., 0.24 for 24%)
    fixed_amount DECIMAL(15,2) DEFAULT 0,
    bracket_order INTEGER NOT NULL,
    
    -- Constraints
    CONSTRAINT unique_rule_bracket_order UNIQUE(rule_id, bracket_order)
);

-- 10. CREATE FORM_SCHEMAS TABLE
CREATE TABLE form_schemas (
    id TEXT PRIMARY KEY,
    schema_type TEXT NOT NULL,         -- 'income_tax', 'vat', 'paye'
    version INTEGER NOT NULL,
    schema_data JSONB NOT NULL,        -- JSON schema for dynamic form generation
    is_active BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    CONSTRAINT unique_active_schema_type UNIQUE(schema_type, is_active) DEFERRABLE INITIALLY DEFERRED
);

-- 11. CREATE TAX_CALCULATIONS TABLE
CREATE TABLE calculations (
    id TEXT PRIMARY KEY,
    user_id TEXT,                      -- Optional user identification
    calculation_type TEXT NOT NULL,    -- 'income_tax', 'vat', 'paye', etc.
    input_data JSONB NOT NULL,         -- User input data
    result_data JSONB NOT NULL,        -- Calculation results
    total_tax DECIMAL(15,2),           -- Final tax amount
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    CONSTRAINT valid_calculation_type CHECK (calculation_type IN ('income_tax', 'vat', 'paye', 'wht', 'nbt', 'sscl', 'combined'))
);

-- 12. CREATE USER_PROFILES TABLE
CREATE TABLE user_profiles (
    id TEXT PRIMARY KEY,
    email TEXT UNIQUE,
    full_name TEXT,
    role TEXT DEFAULT 'user',          -- 'admin', 'user', 'viewer'
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    CONSTRAINT valid_role CHECK (role IN ('admin', 'user', 'viewer'))
);

-- 13. CREATE TRIGGERS FOR AUTO-UPDATING TIMESTAMPS
CREATE TRIGGER update_documents_updated_at 
    BEFORE UPDATE ON documents 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_document_chunks_updated_at 
    BEFORE UPDATE ON document_chunks 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_tax_rules_updated_at 
    BEFORE UPDATE ON tax_rules 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_profiles_updated_at 
    BEFORE UPDATE ON user_profiles 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 14. CREATE INDEXES FOR PERFORMANCE
-- Documents table indexes
CREATE INDEX idx_documents_status ON documents(status);
CREATE INDEX idx_documents_processed ON documents(processed);
CREATE INDEX idx_documents_upload_date ON documents(upload_date);
CREATE INDEX idx_documents_document_type ON documents(document_type);

-- Document chunks table indexes
CREATE INDEX idx_document_chunks_document_id ON document_chunks(document_id);
CREATE INDEX idx_document_chunks_sequence ON document_chunks(chunk_sequence);
CREATE INDEX idx_document_chunks_processing_status ON document_chunks(processing_status);
CREATE INDEX idx_document_chunks_relevance_score ON document_chunks(relevance_score);

-- Vector similarity search indexes (CRITICAL for embeddings)
CREATE INDEX idx_document_chunks_embedding_cosine 
    ON document_chunks USING ivfflat (embedding vector_cosine_ops) 
    WITH (lists = 100);

CREATE INDEX idx_tax_rules_embedding_cosine 
    ON tax_rules USING ivfflat (embedding vector_cosine_ops) 
    WITH (lists = 100);

-- Tax rules indexes
CREATE INDEX idx_tax_rules_rule_type ON tax_rules(rule_type);
CREATE INDEX idx_tax_rules_effective_date ON tax_rules(effective_date);
CREATE INDEX idx_tax_rules_document_source ON tax_rules(document_source_id);

-- Calculations indexes
CREATE INDEX idx_calculations_user_date ON calculations(user_id, created_at DESC);
CREATE INDEX idx_calculations_type ON calculations(calculation_type);

-- 15. ENABLE ROW LEVEL SECURITY (RLS)
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE document_chunks ENABLE ROW LEVEL SECURITY;
ALTER TABLE tax_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE calculations ENABLE ROW LEVEL SECURITY;

-- Create RLS policies (allow all operations for now)
CREATE POLICY "Enable read access for all users" ON documents FOR SELECT USING (true);
CREATE POLICY "Enable insert for all users" ON documents FOR INSERT WITH CHECK (true);
CREATE POLICY "Enable update for all users" ON documents FOR UPDATE USING (true);

CREATE POLICY "Enable read access for all users" ON document_chunks FOR SELECT USING (true);
CREATE POLICY "Enable insert for all users" ON document_chunks FOR INSERT WITH CHECK (true);
CREATE POLICY "Enable update for all users" ON document_chunks FOR UPDATE USING (true);

CREATE POLICY "Enable read access for all users" ON tax_rules FOR SELECT USING (true);
CREATE POLICY "Enable insert for all users" ON tax_rules FOR INSERT WITH CHECK (true);
CREATE POLICY "Enable update for all users" ON tax_rules FOR UPDATE USING (true);

CREATE POLICY "Enable read access for all users" ON calculations FOR SELECT USING (true);
CREATE POLICY "Enable insert for all users" ON calculations FOR INSERT WITH CHECK (true);

-- 16. VERIFY THE SCHEMA IS CORRECT
SELECT 
    table_name, 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name IN ('documents', 'document_chunks', 'tax_rules', 'tax_brackets', 'calculations') 
ORDER BY table_name, ordinal_position;

-- 17. TEST VECTOR OPERATIONS
SELECT '[1,2,3]'::vector(3) <-> '[4,5,6]'::vector(3) as cosine_distance_test;

-- 18. SHOW ALL CREATED TABLES
SELECT table_name, table_type 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('documents', 'document_chunks', 'tax_rules', 'tax_brackets', 'chunk_processing_stats', 'form_schemas', 'calculations', 'user_profiles')
ORDER BY table_name;

-- SUCCESS MESSAGE
SELECT 'Database completely recreated successfully! All tables, indexes, and constraints created from scratch.' as status;
