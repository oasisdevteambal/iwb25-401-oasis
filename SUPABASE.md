# Supabase Database Schema & Configuration

## Overview

This document contains the complete database schema, configuration, and setup instructions for the Sri Lankan Tax Calculation Application using Supabase as the backend database and storage solution.

## 🏗️ Supabase Project Setup

### Prerequisites
- Supabase account (free tier available)
- PostgreSQL 14+ with pgvector extension
- Admin access to Supabase SQL Editor

### Project Configuration
```
Project URL: https://ohdbwbrutlwikcmpprky.supabase.co
Database Host: db.ohdbwbrutlwikcmpprky.supabase.co
Port: 5432
Database: postgres
```

## 🔧 Extensions Setup

Enable required PostgreSQL extensions in Supabase SQL Editor:

```sql
-- Enable vector extension for semantic embeddings
CREATE EXTENSION IF NOT EXISTS vector;

-- Enable UUID extension for primary keys
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Enable timestamp functions
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
```

## 📊 Complete Database Schema

### 1. Documents Table

Main table for storing document metadata and processing status.

```sql
-- Main documents table
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
    CONSTRAINT valid_document_type CHECK (document_type IN ('pdf', 'docx', 'doc', 'txt', 'html', 'xml'))
);

-- Trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_documents_updated_at 
    BEFORE UPDATE ON documents 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

### 2. Document Chunks Table

Table for storing intelligent document chunks with embeddings for semantic search.

```sql
-- Document chunks table for intelligent document segmentation
CREATE TABLE document_chunks (
    id TEXT PRIMARY KEY,
    document_id TEXT REFERENCES documents(id) ON DELETE CASCADE,
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

-- Trigger for updated_at
CREATE TRIGGER update_document_chunks_updated_at 
    BEFORE UPDATE ON document_chunks 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

### 3. Tax Rules Table

Table for storing extracted tax rules linked to document chunks.

```sql
-- Enhanced tax rules table with chunk tracking
CREATE TABLE tax_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    chunk_id TEXT REFERENCES document_chunks(id) ON DELETE SET NULL,
    chunk_sequence INTEGER,            -- Reference to chunk sequence
    chunk_confidence DECIMAL(3,2),     -- Confidence in rule extraction (0.00-1.00)
    extraction_context TEXT,           -- Surrounding text context
    rule_type TEXT NOT NULL,           -- 'income_tax', 'vat', 'paye', 'wht', 'nbt', 'sscl'
    rule_category TEXT,                -- 'bracket', 'deduction', 'exemption', 'rate'
    title TEXT NOT NULL,
    description TEXT,
    rule_data JSONB NOT NULL,          -- Structured rule data
    effective_date DATE,
    expiry_date DATE,
    is_active BOOLEAN DEFAULT TRUE,
    validation_status TEXT DEFAULT 'pending', -- 'pending', 'validated', 'rejected'
    validated_by TEXT,                 -- User who validated the rule
    validated_at TIMESTAMP,
    priority INTEGER DEFAULT 1,       -- Rule priority for conflicts
    embedding vector(768),             -- Rule embedding for semantic search
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    CONSTRAINT valid_rule_type CHECK (rule_type IN ('income_tax', 'vat', 'paye', 'wht', 'nbt', 'sscl', 'general')),
    CONSTRAINT valid_rule_category CHECK (rule_category IN ('bracket', 'deduction', 'exemption', 'rate', 'threshold', 'allowance')),
    CONSTRAINT valid_validation_status CHECK (validation_status IN ('pending', 'validated', 'rejected')),
    CONSTRAINT valid_chunk_confidence CHECK (chunk_confidence >= 0.00 AND chunk_confidence <= 1.00),
    CONSTRAINT valid_priority CHECK (priority >= 1 AND priority <= 10),
    CONSTRAINT valid_date_range CHECK (expiry_date IS NULL OR expiry_date >= effective_date)
);

-- Trigger for updated_at
CREATE TRIGGER update_tax_rules_updated_at 
    BEFORE UPDATE ON tax_rules 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

### 4. Tax Brackets Table

Table for storing specific tax bracket information linked to tax rules.

```sql
-- Tax brackets table for detailed tax calculation data
CREATE TABLE tax_brackets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_id UUID REFERENCES tax_rules(id) ON DELETE CASCADE,
    min_income DECIMAL(15,2),
    max_income DECIMAL(15,2),
    tax_rate DECIMAL(5,4),             -- Percentage rate (e.g., 0.2400 for 24%)
    fixed_amount DECIMAL(15,2) DEFAULT 0,
    bracket_order INTEGER,
    currency TEXT DEFAULT 'LKR',
    applicable_to TEXT[],              -- ['individual', 'company', 'non_resident']
    conditions JSONB,                  -- Additional conditions for bracket
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    CONSTRAINT valid_income_range CHECK (max_income IS NULL OR max_income >= min_income),
    CONSTRAINT valid_tax_rate CHECK (tax_rate >= 0.0 AND tax_rate <= 1.0),
    CONSTRAINT valid_bracket_order CHECK (bracket_order > 0),
    CONSTRAINT valid_currency CHECK (currency IN ('LKR', 'USD', 'EUR')),
    CONSTRAINT unique_rule_bracket_order UNIQUE(rule_id, bracket_order)
);

-- Trigger for updated_at
CREATE TRIGGER update_tax_brackets_updated_at 
    BEFORE UPDATE ON tax_brackets 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

### 5. Form Schemas Table

Table for storing dynamic form schemas generated from tax rules.

```sql
-- Form schemas table for dynamic form generation
CREATE TABLE form_schemas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    schema_type TEXT NOT NULL,         -- 'income_tax', 'vat', 'paye', etc.
    version TEXT NOT NULL,             -- Semantic version (e.g., '1.0.0')
    schema_data JSONB NOT NULL,        -- JSON Schema for React JSON Schema Form
    ui_schema JSONB,                   -- UI Schema for form customization
    is_active BOOLEAN DEFAULT FALSE,
    chunk_sources TEXT[],              -- IDs of chunks that contributed to this schema
    generation_method TEXT DEFAULT 'ai_extracted', -- 'ai_extracted', 'manual', 'hybrid'
    validation_rules JSONB,            -- Additional validation rules
    created_by TEXT,                   -- User who created/approved the schema
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    CONSTRAINT valid_schema_type CHECK (schema_type IN ('income_tax', 'vat', 'paye', 'wht', 'nbt', 'sscl', 'combined')),
    CONSTRAINT valid_generation_method CHECK (generation_method IN ('ai_extracted', 'manual', 'hybrid')),
    CONSTRAINT unique_active_schema_type UNIQUE(schema_type, is_active) DEFERRABLE INITIALLY DEFERRED
);

-- Trigger for updated_at
CREATE TRIGGER update_form_schemas_updated_at 
    BEFORE UPDATE ON form_schemas 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to ensure only one active schema per type
CREATE OR REPLACE FUNCTION ensure_single_active_schema()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.is_active = TRUE THEN
        -- Deactivate other schemas of the same type
        UPDATE form_schemas 
        SET is_active = FALSE 
        WHERE schema_type = NEW.schema_type 
        AND id != NEW.id 
        AND is_active = TRUE;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ensure_single_active_schema_trigger
    BEFORE INSERT OR UPDATE ON form_schemas
    FOR EACH ROW EXECUTE FUNCTION ensure_single_active_schema();
```

### 6. Tax Calculations Table

Table for storing user tax calculation results and history.

```sql
-- Tax calculations table for storing user calculation results
CREATE TABLE tax_calculations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID,                      -- Optional user identification
    session_id TEXT,                   -- Session tracking for anonymous users
    calculation_type TEXT NOT NULL,    -- 'income_tax', 'vat', 'paye', etc.
    input_data JSONB NOT NULL,         -- User input data
    result_data JSONB NOT NULL,        -- Calculation results
    tax_amount DECIMAL(15,2),          -- Final tax amount
    effective_rate DECIMAL(5,4),       -- Effective tax rate
    applicable_rules UUID[],           -- Array of tax rule IDs used
    schema_version TEXT,               -- Form schema version used
    calculation_method TEXT DEFAULT 'standard', -- 'standard', 'simplified', 'estimated'
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    CONSTRAINT valid_calculation_type CHECK (calculation_type IN ('income_tax', 'vat', 'paye', 'wht', 'nbt', 'sscl', 'combined')),
    CONSTRAINT valid_calculation_method CHECK (calculation_method IN ('standard', 'simplified', 'estimated')),
    CONSTRAINT valid_effective_rate CHECK (effective_rate >= 0.0 AND effective_rate <= 1.0)
);

-- Index for user calculations history
CREATE INDEX idx_tax_calculations_user_date ON tax_calculations(user_id, created_at DESC);
CREATE INDEX idx_tax_calculations_session_date ON tax_calculations(session_id, created_at DESC);
```

### 7. Chunk Processing Statistics Table

Table for monitoring and analytics of document processing performance.

```sql
-- Chunk processing analytics for monitoring
CREATE TABLE chunk_processing_stats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id TEXT REFERENCES documents(id) ON DELETE CASCADE,
    total_chunks INTEGER,
    processed_chunks INTEGER,
    failed_chunks INTEGER,
    processing_start_time TIMESTAMP,
    processing_end_time TIMESTAMP,
    total_processing_time_ms INTEGER,
    average_chunk_size DECIMAL(10,2),
    tax_relevant_chunks INTEGER,
    quality_score DECIMAL(3,2),        -- Overall processing quality (0.00-1.00)
    embedding_generation_time_ms INTEGER,
    storage_time_ms INTEGER,
    errors JSONB,                      -- Array of error details
    warnings JSONB,                    -- Array of warning messages
    performance_metrics JSONB,        -- Additional performance data
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    CONSTRAINT valid_quality_score CHECK (quality_score >= 0.00 AND quality_score <= 1.00),
    CONSTRAINT valid_chunk_counts CHECK (processed_chunks + failed_chunks <= total_chunks)
);
```

### 8. User Management Tables (Optional)

If implementing user authentication and management:

```sql
-- User profiles table (extends Supabase Auth users)
CREATE TABLE user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT UNIQUE,
    full_name TEXT,
    role TEXT DEFAULT 'user',          -- 'admin', 'user', 'viewer'
    organization TEXT,
    preferences JSONB DEFAULT '{}',
    last_login TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    CONSTRAINT valid_role CHECK (role IN ('admin', 'user', 'viewer'))
);

-- Trigger for updated_at
CREATE TRIGGER update_user_profiles_updated_at 
    BEFORE UPDATE ON user_profiles 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- User activity log
CREATE TABLE user_activity_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES user_profiles(id) ON DELETE SET NULL,
    action TEXT NOT NULL,              -- 'upload', 'calculate', 'search', 'export'
    resource_type TEXT,               -- 'document', 'calculation', 'rule'
    resource_id TEXT,
    details JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    CONSTRAINT valid_action CHECK (action IN ('upload', 'calculate', 'search', 'export', 'view', 'edit', 'delete'))
);

-- Index for activity queries
CREATE INDEX idx_user_activity_user_date ON user_activity_log(user_id, created_at DESC);
CREATE INDEX idx_user_activity_action_date ON user_activity_log(action, created_at DESC);
```

## 🔍 Indexes for Performance

### Vector Search Indexes
```sql
-- Vector similarity search indexes for semantic search
CREATE INDEX ON document_chunks USING ivfflat (embedding vector_cosine_ops) 
WITH (lists = 100);

CREATE INDEX ON tax_rules USING ivfflat (embedding vector_cosine_ops) 
WITH (lists = 100);
```

### Standard Indexes
```sql
-- Document indexes
CREATE INDEX idx_documents_status ON documents(status);
CREATE INDEX idx_documents_type ON documents(document_type);
CREATE INDEX idx_documents_processed ON documents(processed);
CREATE INDEX idx_documents_upload_date ON documents(upload_date DESC);

-- Chunk indexes
CREATE INDEX idx_chunks_document_sequence ON document_chunks(document_id, chunk_sequence);
CREATE INDEX idx_chunks_processing_status ON document_chunks(processing_status);
CREATE INDEX idx_chunks_type ON document_chunks(chunk_type);
CREATE INDEX idx_chunks_keywords ON document_chunks USING GIN(context_keywords);
CREATE INDEX idx_chunks_relevance ON document_chunks(relevance_score DESC);

-- Tax rules indexes
CREATE INDEX idx_tax_rules_chunk ON tax_rules(chunk_id);
CREATE INDEX idx_tax_rules_type ON tax_rules(rule_type);
CREATE INDEX idx_tax_rules_date ON tax_rules(effective_date, expiry_date);
CREATE INDEX idx_tax_rules_active ON tax_rules(is_active, rule_type);
CREATE INDEX idx_tax_rules_validation ON tax_rules(validation_status);

-- Tax brackets indexes
CREATE INDEX idx_tax_brackets_rule ON tax_brackets(rule_id);
CREATE INDEX idx_tax_brackets_income ON tax_brackets(min_income, max_income);
CREATE INDEX idx_tax_brackets_order ON tax_brackets(rule_id, bracket_order);

-- Form schemas indexes
CREATE INDEX idx_form_schemas_type_active ON form_schemas(schema_type, is_active);
CREATE INDEX idx_form_schemas_version ON form_schemas(schema_type, version);

-- Processing stats indexes
CREATE INDEX idx_chunk_stats_document ON chunk_processing_stats(document_id);
CREATE INDEX idx_chunk_stats_processing_time ON chunk_processing_stats(processing_start_time, processing_end_time);
CREATE INDEX idx_chunk_stats_quality ON chunk_processing_stats(quality_score DESC);
```

## 🔐 Row Level Security (RLS)

Enable RLS for secure data access:

```sql
-- Enable RLS on all tables
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE document_chunks ENABLE ROW LEVEL SECURITY;
ALTER TABLE tax_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE tax_brackets ENABLE ROW LEVEL SECURITY;
ALTER TABLE form_schemas ENABLE ROW LEVEL SECURITY;
ALTER TABLE tax_calculations ENABLE ROW LEVEL SECURITY;
ALTER TABLE chunk_processing_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_activity_log ENABLE ROW LEVEL SECURITY;

-- RLS Policies for documents (admin can access all, users can view processed)
CREATE POLICY "Documents admin access" ON documents
FOR ALL USING (
    EXISTS (
        SELECT 1 FROM user_profiles 
        WHERE id = auth.uid() AND role = 'admin'
    )
);

CREATE POLICY "Documents public read" ON documents
FOR SELECT USING (processed = true AND status = 'completed');

-- RLS Policies for chunks (public read for processed chunks)
CREATE POLICY "Chunks admin access" ON document_chunks
FOR ALL USING (
    EXISTS (
        SELECT 1 FROM user_profiles 
        WHERE id = auth.uid() AND role = 'admin'
    )
);

CREATE POLICY "Chunks public read" ON document_chunks
FOR SELECT USING (processing_status = 'stored');

-- RLS Policies for tax rules (public read for active rules)
CREATE POLICY "Tax rules admin access" ON tax_rules
FOR ALL USING (
    EXISTS (
        SELECT 1 FROM user_profiles 
        WHERE id = auth.uid() AND role = 'admin'
    )
);

CREATE POLICY "Tax rules public read" ON tax_rules
FOR SELECT USING (is_active = true AND validation_status = 'validated');

-- RLS Policies for tax brackets (public read)
CREATE POLICY "Tax brackets admin access" ON tax_brackets
FOR ALL USING (
    EXISTS (
        SELECT 1 FROM user_profiles 
        WHERE id = auth.uid() AND role = 'admin'
    )
);

CREATE POLICY "Tax brackets public read" ON tax_brackets
FOR SELECT USING (true);

-- RLS Policies for form schemas (public read for active schemas)
CREATE POLICY "Form schemas admin access" ON form_schemas
FOR ALL USING (
    EXISTS (
        SELECT 1 FROM user_profiles 
        WHERE id = auth.uid() AND role = 'admin'
    )
);

CREATE POLICY "Form schemas public read" ON form_schemas
FOR SELECT USING (is_active = true);

-- RLS Policies for calculations (users can access their own)
CREATE POLICY "Calculations user access" ON tax_calculations
FOR ALL USING (user_id = auth.uid());

CREATE POLICY "Calculations admin access" ON tax_calculations
FOR ALL USING (
    EXISTS (
        SELECT 1 FROM user_profiles 
        WHERE id = auth.uid() AND role = 'admin'
    )
);

-- RLS Policies for user profiles
CREATE POLICY "User profiles self access" ON user_profiles
FOR ALL USING (id = auth.uid());

CREATE POLICY "User profiles admin access" ON user_profiles
FOR ALL USING (
    EXISTS (
        SELECT 1 FROM user_profiles 
        WHERE id = auth.uid() AND role = 'admin'
    )
);
```

## 📁 Supabase Storage Configuration

### Storage Buckets Setup

```sql
-- Create storage bucket for documents
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'documents',
    'documents',
    false,
    10485760, -- 10MB limit
    ARRAY['application/pdf', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', 'text/plain']
);

-- Storage policies for documents bucket
CREATE POLICY "Documents upload admin" ON storage.objects
FOR INSERT WITH CHECK (
    bucket_id = 'documents' AND
    EXISTS (
        SELECT 1 FROM user_profiles 
        WHERE id = auth.uid() AND role = 'admin'
    )
);

CREATE POLICY "Documents view admin" ON storage.objects
FOR SELECT USING (
    bucket_id = 'documents' AND
    EXISTS (
        SELECT 1 FROM user_profiles 
        WHERE id = auth.uid() AND role = 'admin'
    )
);

CREATE POLICY "Documents delete admin" ON storage.objects
FOR DELETE USING (
    bucket_id = 'documents' AND
    EXISTS (
        SELECT 1 FROM user_profiles 
        WHERE id = auth.uid() AND role = 'admin'
    )
);
```

## ⚙️ Configuration Values

### Environment Variables for Ballerina Backend

```toml
# Ballerina.toml - Configuration values
[build-options]
observabilityIncluded = true

[[dependency]]
org = "ballerinax"
name = "postgresql"
version = "1.11.0"

# Configuration in Config.toml
[oasis.backend]
SUPABASE_URL = "https://ohdbwbrutlwikcmpprky.supabase.co"
SUPABASE_SERVICE_ROLE_KEY = "your_service_role_key"
SUPABASE_STORAGE_BUCKET = "documents"
SUPABASE_DB_HOST = "db.ohdbwbrutlwikcmpprky.supabase.co"
SUPABASE_DB_PASSWORD = "your_db_password"
GEMINI_API_KEY = "your_gemini_api_key"
```

## 🔧 Database Functions

### Utility Functions

```sql
-- Function to search similar chunks using vector similarity
CREATE OR REPLACE FUNCTION search_similar_chunks(
    query_embedding vector(768),
    similarity_threshold float DEFAULT 0.7,
    max_results int DEFAULT 10
)
RETURNS TABLE (
    chunk_id text,
    document_id text,
    chunk_text text,
    similarity_score float,
    relevance_score decimal
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        dc.id,
        dc.document_id,
        dc.chunk_text,
        1 - (dc.embedding <=> query_embedding) as similarity,
        dc.relevance_score
    FROM document_chunks dc
    WHERE dc.embedding IS NOT NULL
    AND 1 - (dc.embedding <=> query_embedding) >= similarity_threshold
    ORDER BY dc.embedding <=> query_embedding
    LIMIT max_results;
END;
$$ LANGUAGE plpgsql;

-- Function to get active tax rules by type
CREATE OR REPLACE FUNCTION get_active_tax_rules(rule_type_param text)
RETURNS TABLE (
    rule_id uuid,
    title text,
    description text,
    rule_data jsonb,
    effective_date date,
    expiry_date date
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        tr.id,
        tr.title,
        tr.description,
        tr.rule_data,
        tr.effective_date,
        tr.expiry_date
    FROM tax_rules tr
    WHERE tr.rule_type = rule_type_param
    AND tr.is_active = true
    AND tr.validation_status = 'validated'
    AND (tr.effective_date IS NULL OR tr.effective_date <= CURRENT_DATE)
    AND (tr.expiry_date IS NULL OR tr.expiry_date > CURRENT_DATE)
    ORDER BY tr.priority DESC, tr.effective_date DESC;
END;
$$ LANGUAGE plpgsql;

-- Function to calculate document processing statistics
CREATE OR REPLACE FUNCTION update_document_processing_stats(doc_id text)
RETURNS void AS $$
DECLARE
    chunk_count int;
    processed_count int;
    failed_count int;
    avg_relevance decimal;
BEGIN
    -- Count chunks
    SELECT COUNT(*) INTO chunk_count
    FROM document_chunks 
    WHERE document_id = doc_id;
    
    -- Count processed chunks
    SELECT COUNT(*) INTO processed_count
    FROM document_chunks 
    WHERE document_id = doc_id 
    AND processing_status = 'stored';
    
    -- Count failed chunks
    SELECT COUNT(*) INTO failed_count
    FROM document_chunks 
    WHERE document_id = doc_id 
    AND processing_status = 'failed';
    
    -- Calculate average relevance
    SELECT AVG(relevance_score) INTO avg_relevance
    FROM document_chunks 
    WHERE document_id = doc_id 
    AND relevance_score IS NOT NULL;
    
    -- Update document status
    UPDATE documents 
    SET 
        total_chunks = chunk_count,
        processed = (processed_count = chunk_count AND chunk_count > 0),
        status = CASE 
            WHEN processed_count = chunk_count AND chunk_count > 0 THEN 'completed'
            WHEN failed_count > 0 THEN 'failed'
            ELSE 'processing'
        END,
        processing_end_time = CASE 
            WHEN processed_count = chunk_count AND chunk_count > 0 THEN CURRENT_TIMESTAMP
            ELSE processing_end_time
        END
    WHERE id = doc_id;
    
END;
$$ LANGUAGE plpgsql;
```

## 📈 Analytics Views

```sql
-- View for document processing analytics
CREATE VIEW document_processing_analytics AS
SELECT 
    DATE_TRUNC('day', d.upload_date) as upload_date,
    COUNT(*) as total_documents,
    COUNT(*) FILTER (WHERE d.processed = true) as processed_documents,
    COUNT(*) FILTER (WHERE d.status = 'failed') as failed_documents,
    AVG(d.total_chunks) as avg_chunks_per_document,
    AVG(EXTRACT(EPOCH FROM (d.processing_end_time - d.processing_start_time))) as avg_processing_time_seconds
FROM documents d
GROUP BY DATE_TRUNC('day', d.upload_date)
ORDER BY upload_date DESC;

-- View for tax rule statistics
CREATE VIEW tax_rule_statistics AS
SELECT 
    rule_type,
    COUNT(*) as total_rules,
    COUNT(*) FILTER (WHERE is_active = true) as active_rules,
    COUNT(*) FILTER (WHERE validation_status = 'validated') as validated_rules,
    COUNT(*) FILTER (WHERE validation_status = 'pending') as pending_rules,
    AVG(chunk_confidence) as avg_extraction_confidence
FROM tax_rules
GROUP BY rule_type
ORDER BY rule_type;

-- View for chunk processing performance
CREATE VIEW chunk_processing_performance AS
SELECT 
    dc.chunk_type,
    COUNT(*) as total_chunks,
    AVG(dc.token_count) as avg_token_count,
    AVG(dc.relevance_score) as avg_relevance_score,
    COUNT(*) FILTER (WHERE dc.embedding IS NOT NULL) as chunks_with_embeddings,
    COUNT(*) FILTER (WHERE dc.processing_status = 'stored') as successfully_processed
FROM document_chunks dc
GROUP BY dc.chunk_type
ORDER BY total_chunks DESC;
```

## 🚀 Sample Data

### Insert Sample Tax Rules

```sql
-- Sample Income Tax Rule
INSERT INTO tax_rules (rule_type, rule_category, title, description, rule_data, effective_date, is_active, validation_status)
VALUES (
    'income_tax',
    'bracket',
    'Individual Income Tax Brackets 2024',
    'Progressive tax brackets for individual taxpayers in Sri Lanka',
    '{
        "brackets": [
            {"min": 0, "max": 1200000, "rate": 0, "description": "Tax-free threshold"},
            {"min": 1200000, "max": 1700000, "rate": 0.06, "description": "6% tax bracket"},
            {"min": 1700000, "max": 2200000, "rate": 0.12, "description": "12% tax bracket"},
            {"min": 2200000, "max": 2700000, "rate": 0.18, "description": "18% tax bracket"},
            {"min": 2700000, "max": 3200000, "rate": 0.24, "description": "24% tax bracket"},
            {"min": 3200000, "max": null, "rate": 0.30, "description": "30% tax bracket"}
        ],
        "currency": "LKR",
        "taxYear": "2024"
    }',
    '2024-01-01',
    true,
    'validated'
);

-- Insert corresponding tax brackets
INSERT INTO tax_brackets (rule_id, min_income, max_income, tax_rate, bracket_order, applicable_to)
SELECT 
    tr.id,
    (bracket->>'min')::decimal,
    CASE WHEN bracket->>'max' = 'null' THEN NULL ELSE (bracket->>'max')::decimal END,
    (bracket->>'rate')::decimal,
    ROW_NUMBER() OVER (),
    ARRAY['individual']
FROM tax_rules tr,
     jsonb_array_elements(tr.rule_data->'brackets') as bracket
WHERE tr.title = 'Individual Income Tax Brackets 2024';

-- Sample Form Schema
INSERT INTO form_schemas (schema_type, version, schema_data, ui_schema, is_active, generation_method)
VALUES (
    'income_tax',
    '1.0.0',
    '{
        "type": "object",
        "properties": {
            "annualIncome": {
                "type": "number",
                "title": "Annual Income (LKR)",
                "minimum": 0
            },
            "deductions": {
                "type": "object",
                "title": "Deductions",
                "properties": {
                    "medicalExpenses": {"type": "number", "title": "Medical Expenses", "minimum": 0},
                    "donations": {"type": "number", "title": "Donations", "minimum": 0},
                    "lifeInsurance": {"type": "number", "title": "Life Insurance Premiums", "minimum": 0}
                }
            }
        },
        "required": ["annualIncome"]
    }',
    '{
        "annualIncome": {"ui:placeholder": "Enter your total annual income"},
        "deductions": {
            "ui:order": ["medicalExpenses", "donations", "lifeInsurance"]
        }
    }',
    true,
    'manual'
);
```

## 🔍 Sample Queries

### Common Query Patterns

```sql
-- Search for tax-related content
SELECT * FROM search_similar_chunks(
    '[0.1, 0.2, 0.3, ...]'::vector(768), -- Query embedding
    0.8, -- Similarity threshold
    5    -- Max results
);

-- Get all active income tax rules with brackets
SELECT 
    tr.title,
    tr.description,
    tb.min_income,
    tb.max_income,
    tb.tax_rate,
    tb.bracket_order
FROM tax_rules tr
JOIN tax_brackets tb ON tr.id = tb.rule_id
WHERE tr.rule_type = 'income_tax'
AND tr.is_active = true
AND tr.validation_status = 'validated'
ORDER BY tb.bracket_order;

-- Get document processing summary
SELECT 
    d.filename,
    d.status,
    d.total_chunks,
    COUNT(dc.id) as actual_chunks,
    COUNT(dc.id) FILTER (WHERE dc.embedding IS NOT NULL) as chunks_with_embeddings,
    AVG(dc.relevance_score) as avg_relevance
FROM documents d
LEFT JOIN document_chunks dc ON d.id = dc.document_id
GROUP BY d.id, d.filename, d.status, d.total_chunks
ORDER BY d.upload_date DESC;

-- Find most relevant chunks for a document
SELECT 
    dc.id,
    dc.chunk_sequence,
    dc.chunk_type,
    dc.relevance_score,
    LEFT(dc.chunk_text, 200) as preview
FROM document_chunks dc
WHERE dc.document_id = 'your-document-id'
AND dc.relevance_score > 0.7
ORDER BY dc.relevance_score DESC;
```

## 🔧 Maintenance Scripts

### Cleanup and Optimization

```sql
-- Clean up old failed processing attempts
DELETE FROM document_chunks 
WHERE processing_status = 'failed' 
AND created_at < NOW() - INTERVAL '7 days';

-- Update document statistics
SELECT update_document_processing_stats(id) 
FROM documents 
WHERE processed = false;

-- Refresh materialized views (if any are created)
-- REFRESH MATERIALIZED VIEW document_processing_analytics;

-- Vacuum and analyze for performance
VACUUM ANALYZE documents;
VACUUM ANALYZE document_chunks;
VACUUM ANALYZE tax_rules;
VACUUM ANALYZE tax_brackets;
```

## 📝 Notes

- Vector embeddings use 768 dimensions for Gemini text-embedding-004 model
- All timestamps are in UTC
- JSON schemas follow React JSON Schema Form specification
- RLS policies ensure secure access based on user roles
- Use parameterized queries to prevent SQL injection
- Regular maintenance of vector indexes recommended for optimal performance

## 🆘 Troubleshooting

### Common Issues

1. **Vector extension not enabled**: Run `CREATE EXTENSION IF NOT EXISTS vector;`
2. **RLS blocking queries**: Check policies and user authentication
3. **Storage bucket permissions**: Verify storage policies are correctly set
4. **Slow vector searches**: Ensure proper indexing with `ivfflat`
5. **Connection limits**: Monitor and optimize connection pooling

### Performance Monitoring

```sql
-- Check index usage
SELECT schemaname, tablename, indexname, idx_scan, idx_tup_read, idx_tup_fetch
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC;

-- Monitor vector search performance
SELECT 
    query,
    mean_exec_time,
    calls,
    total_exec_time
FROM pg_stat_statements
WHERE query LIKE '%vector%'
ORDER BY mean_exec_time DESC;
```
