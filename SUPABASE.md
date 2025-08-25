# Supabase Database Schema & Configuration

## Overview

This document contains the complete database schema, configuration, and setup instructions for the Sri Lankan Tax Calculation Application using Supabase as the backend database and storage solution.


## 📊 Complete Database Schema

### 1. Documents Table

Main table for storing document metadata and processing status.
```sql
create table public.documents (
  id text not null,
  filename text not null,
  file_path text not null,
  content_type text not null,
  upload_date timestamp without time zone null default CURRENT_TIMESTAMP,
  processed boolean null default false,
  status text null default 'uploaded'::text,
  total_chunks integer null default 0,
  file_size bigint null,
  document_type text null,
  processing_start_time timestamp without time zone null,
  processing_end_time timestamp without time zone null,
  processing_duration_ms integer null,
  error_message text null,
  created_at timestamp without time zone null default CURRENT_TIMESTAMP,
  updated_at timestamp without time zone null default CURRENT_TIMESTAMP,
  source_authority text null,
  source_rank integer null,
  constraint documents_pkey primary key (id),
  constraint valid_document_type check (
    (
      document_type = any (
        array[
          'pdf'::text,
          'docx'::text,
          'doc'::text,
          'txt'::text,
          'html'::text,
          'xml'::text,
          'tax_document'::text
        ]
      )
    )
  ),
  constraint valid_source_authority check (
    (
      source_authority = any (
        array[
          'Act'::text,
          'Gazette'::text,
          'Regulation'::text,
          'Circular'::text,
          'Ruling'::text,
          'Guideline'::text,
          'Notice'::text,
          'Other'::text
        ]
      )
    )
  ),
  constraint valid_status check (
    (
      status = any (
        array[
          'uploaded'::text,
          'processing'::text,
          'chunking'::text,
          'extracting'::text,
          'embedded'::text,
          'completed'::text,
          'failed'::text
        ]
      )
    )
  )
) TABLESPACE pg_default;

create index IF not exists idx_documents_status on public.documents using btree (status) TABLESPACE pg_default;

create index IF not exists idx_documents_processed on public.documents using btree (processed) TABLESPACE pg_default;

create index IF not exists idx_documents_upload_date on public.documents using btree (upload_date) TABLESPACE pg_default;

create index IF not exists idx_documents_document_type on public.documents using btree (document_type) TABLESPACE pg_default;

create index IF not exists idx_documents_source_authority on public.documents using btree (source_authority) TABLESPACE pg_default;

create index IF not exists idx_documents_source_rank on public.documents using btree (source_rank) TABLESPACE pg_default;

create trigger update_documents_updated_at BEFORE
update on documents for EACH row
execute FUNCTION update_updated_at_column ();
```


### 2. Document Chunks Table

Table for storing intelligent document chunks with embeddings for semantic search.

```sql
create table public.document_chunks (
  id text not null,
  document_id text null,
  chunk_sequence integer not null,
  start_position integer null,
  end_position integer null,
  chunk_text text not null,
  chunk_size integer null,
  token_count integer null,
  chunk_type text null default 'paragraph'::text,
  processing_status text null default 'created'::text,
  relevance_score numeric(5, 4) null,
  context_keywords text[] null,
  embedding public.vector null,
  embedding_model text null default 'text-embedding-004'::text,
  embedding_provider text null default 'google_gemini'::text,
  embedding_generated_at timestamp without time zone null,
  created_at timestamp without time zone null default CURRENT_TIMESTAMP,
  updated_at timestamp without time zone null default CURRENT_TIMESTAMP,
  constraint document_chunks_pkey primary key (id),
  constraint unique_document_sequence unique (document_id, chunk_sequence),
  constraint document_chunks_document_id_fkey foreign KEY (document_id) references documents (id) on delete CASCADE deferrable initially DEFERRED,
  constraint valid_chunk_type check (
    (
      chunk_type = any (
        array[
          'paragraph'::text,
          'table'::text,
          'header'::text,
          'list'::text,
          'formula'::text,
          'definition'::text,
          'example'::text
        ]
      )
    )
  ),
  constraint valid_processing_status check (
    (
      processing_status = any (
        array[
          'created'::text,
          'scored'::text,
          'validated'::text,
          'embedded'::text,
          'stored'::text,
          'failed'::text
        ]
      )
    )
  ),
  constraint valid_relevance_score check (
    (
      (relevance_score >= 0.0)
      and (relevance_score <= 1.0)
    )
  )
) TABLESPACE pg_default;

create index IF not exists idx_document_chunks_document_id on public.document_chunks using btree (document_id) TABLESPACE pg_default;

create index IF not exists idx_document_chunks_sequence on public.document_chunks using btree (chunk_sequence) TABLESPACE pg_default;

create index IF not exists idx_document_chunks_processing_status on public.document_chunks using btree (processing_status) TABLESPACE pg_default;

create index IF not exists idx_document_chunks_relevance_score on public.document_chunks using btree (relevance_score) TABLESPACE pg_default;

create index IF not exists idx_document_chunks_embedding_cosine on public.document_chunks using ivfflat (embedding vector_cosine_ops)
with
  (lists = '100') TABLESPACE pg_default;

create trigger update_document_chunks_updated_at BEFORE
update on document_chunks for EACH row
execute FUNCTION update_updated_at_column ();
```

### 3. Tax Rules Table

Table for storing extracted tax rules linked to document chunks.

```sql
create table public.tax_rules (
  id text not null,
  rule_type text not null,
  rule_category text null,
  title text not null,
  description text null,
  rule_data jsonb not null,
  embedding public.vector null,
  effective_date date null,
  expiry_date date null,
  document_source_id text null,
  created_at timestamp without time zone null default CURRENT_TIMESTAMP,
  updated_at timestamp without time zone null default CURRENT_TIMESTAMP,
  chunk_id text null,
  chunk_sequence integer null,
  chunk_confidence numeric(3, 2) null,
  extraction_context text null,
  cross_chunk_refs integer null default 0,
  calculation_formula text null,
  dependent_variables text[] null,
  calculation_order integer null default 0,
  validation_status text null default 'pending'::text,
  source_kind text null default 'evidence'::text,
  constraint tax_rules_pkey primary key (id),
  constraint tax_rules_chunk_id_fkey foreign KEY (chunk_id) references document_chunks (id) on delete set null deferrable initially DEFERRED,
  constraint tax_rules_document_source_id_fkey foreign KEY (document_source_id) references documents (id) on delete set null deferrable initially DEFERRED,
  constraint valid_date_range check (
    (
      (expiry_date is null)
      or (expiry_date >= effective_date)
    )
  ),
  constraint valid_source_kind check (
    (
      source_kind = any (array['evidence'::text, 'aggregated'::text])
    )
  ),
  constraint valid_validation_status check (
    (
      validation_status = any (
        array[
          'pending'::text,
          'validated'::text,
          'failed'::text,
          'deprecated'::text
        ]
      )
    )
  )
) TABLESPACE pg_default;

create index IF not exists idx_tax_rules_embedding_cosine on public.tax_rules using ivfflat (embedding vector_cosine_ops)
with
  (lists = '100') TABLESPACE pg_default;

create index IF not exists idx_tax_rules_rule_type on public.tax_rules using btree (rule_type) TABLESPACE pg_default;

create index IF not exists idx_tax_rules_effective_date on public.tax_rules using btree (effective_date) TABLESPACE pg_default;

create index IF not exists idx_tax_rules_document_source on public.tax_rules using btree (document_source_id) TABLESPACE pg_default;

create index IF not exists idx_tax_rules_calculation_order on public.tax_rules using btree (calculation_order) TABLESPACE pg_default;

create index IF not exists idx_tax_rules_validation_status on public.tax_rules using btree (validation_status) TABLESPACE pg_default;

create index IF not exists idx_tax_rules_dependent_variables on public.tax_rules using gin (dependent_variables) TABLESPACE pg_default;

create index IF not exists idx_tax_rules_source_kind on public.tax_rules using btree (source_kind) TABLESPACE pg_default;

create index IF not exists idx_tax_rules_rule_data_gin on public.tax_rules using gin (rule_data) TABLESPACE pg_default;

create index IF not exists idx_tax_rules_rule_category on public.tax_rules using btree (rule_category) TABLESPACE pg_default;

create trigger update_tax_rules_updated_at BEFORE
update on tax_rules for EACH row
execute FUNCTION update_updated_at_column ();
```

### 4. Tax Brackets Table

Table for storing specific tax bracket information linked to tax rules.

```sql
create table public.tax_brackets (
  id text not null,
  rule_id text null,
  min_income numeric(15, 2) null,
  max_income numeric(15, 2) null,
  rate numeric(5, 4) not null,
  fixed_amount numeric(15, 2) null default 0,
  bracket_order integer not null,
  constraint tax_brackets_pkey primary key (id),
  constraint unique_rule_bracket_order unique (rule_id, bracket_order),
  constraint tax_brackets_rule_id_fkey foreign KEY (rule_id) references tax_rules (id) on delete CASCADE deferrable initially DEFERRED
) TABLESPACE pg_default;
```

### 5. Form Schemas Table

Table for storing dynamic form schemas generated from tax rules.

```sql
create table public.form_schemas (
  id text not null,
  schema_type text not null,
  version integer not null,
  schema_data jsonb not null,
  is_active boolean null default false,
  created_at timestamp without time zone null default CURRENT_TIMESTAMP,
  calculation_rules jsonb null,
  required_variables text[] null,
  validation_test_cases jsonb null,
  schema_metadata jsonb null,
  constraint form_schemas_pkey primary key (id),
  constraint unique_active_schema_type unique (schema_type, is_active) deferrable initially DEFERRED
) TABLESPACE pg_default;

create index IF not exists idx_form_schemas_calculation_rules on public.form_schemas using gin (calculation_rules) TABLESPACE pg_default;

create index IF not exists idx_form_schemas_required_variables on public.form_schemas using gin (required_variables) TABLESPACE pg_default;
```

### 6. Tax Calculations Table

Table for storing user tax calculation results and history.

```sql
create table public.calculations (
  id text not null,
  user_id text null,
  calculation_type text not null,
  input_data jsonb not null,
  result_data jsonb not null,
  total_tax numeric(15, 2) null,
  created_at timestamp without time zone null default CURRENT_TIMESTAMP,
  constraint calculations_pkey primary key (id),
  constraint valid_calculation_type check (
    (
      calculation_type = any (
        array[
          'income_tax'::text,
          'vat'::text,
          'paye'::text,
          'wht'::text,
          'nbt'::text,
          'sscl'::text,
          'combined'::text
        ]
      )
    )
  )
) TABLESPACE pg_default;

create index IF not exists idx_calculations_user_date on public.calculations using btree (user_id, created_at desc) TABLESPACE pg_default;

create index IF not exists idx_calculations_type on public.calculations using btree (calculation_type) TABLESPACE pg_default;
```

### 7. Chunk Processing Statistics Table

Table for monitoring and analytics of document processing performance.

```sql
create table public.chunk_processing_stats (
  id text not null,
  chunk_id text null,
  processing_start_time timestamp without time zone null,
  processing_end_time timestamp without time zone null,
  gemini_api_calls integer null default 0,
  rules_extracted integer null default 0,
  processing_errors integer null default 0,
  quality_score numeric(3, 2) null,
  retry_count integer null default 0,
  created_at timestamp without time zone null default CURRENT_TIMESTAMP,
  constraint chunk_processing_stats_pkey primary key (id),
  constraint chunk_processing_stats_chunk_id_fkey foreign KEY (chunk_id) references document_chunks (id) on delete CASCADE deferrable initially DEFERRED,
  constraint valid_quality_score check (
    (
      (quality_score >= 0.00)
      and (quality_score <= 1.00)
    )
  )
) TABLESPACE pg_default;
```

### 8. User Management Tables (Optional)

If implementing user authentication and management:

```sql
create table public.user_profiles (
  id text not null,
  email text null,
  full_name text null,
  role text null default 'user'::text,
  created_at timestamp without time zone null default CURRENT_TIMESTAMP,
  updated_at timestamp without time zone null default CURRENT_TIMESTAMP,
  constraint user_profiles_pkey primary key (id),
  constraint user_profiles_email_key unique (email),
  constraint valid_role check (
    (
      role = any (
        array['admin'::text, 'user'::text, 'viewer'::text]
      )
    )
  )
) TABLESPACE pg_default;

create trigger update_user_profiles_updated_at BEFORE
update on user_profiles for EACH row
execute FUNCTION update_updated_at_column ();
```

### 9. calculation audit table

```sql
create table public.calculation_audit (
  id uuid not null default gen_random_uuid (),
  schema_id text not null,
  input_data jsonb not null,
  calculation_result jsonb not null,
  execution_time_ms integer null,
  rules_version text null,
  execution_id uuid not null,
  user_id text null,
  calculation_type text not null,
  final_amount numeric(15, 2) null,
  created_at timestamp without time zone null default now(),
  constraint calculation_audit_pkey primary key (id),
  constraint calculation_audit_schema_id_fkey foreign KEY (schema_id) references form_schemas (id),
  constraint valid_execution_time check ((execution_time_ms >= 0)),
  constraint valid_final_amount check ((final_amount >= (0)::numeric))
) TABLESPACE pg_default;

create index IF not exists idx_calculation_audit_schema_id on public.calculation_audit using btree (schema_id) TABLESPACE pg_default;

create index IF not exists idx_calculation_audit_created_at on public.calculation_audit using btree (created_at desc) TABLESPACE pg_default;

create index IF not exists idx_calculation_audit_user_id on public.calculation_audit using btree (user_id) TABLESPACE pg_default;

create index IF not exists idx_calculation_audit_type on public.calculation_audit using btree (calculation_type) TABLESPACE pg_default;

create index IF not exists idx_calculation_audit_execution_id on public.calculation_audit using btree (execution_id) TABLESPACE pg_default;
```


### 10. rule test cases table

```sql
create table public.rule_test_cases (
  id uuid not null default gen_random_uuid (),
  rule_id text not null,
  test_name text not null,
  input_data jsonb not null,
  expected_output jsonb not null,
  test_description text null,
  is_active boolean null default true,
  created_at timestamp without time zone null default now(),
  updated_at timestamp without time zone null default now(),
  constraint rule_test_cases_pkey primary key (id),
  constraint unique_rule_test_name unique (rule_id, test_name),
  constraint rule_test_cases_rule_id_fkey foreign KEY (rule_id) references tax_rules (id) on delete CASCADE
) TABLESPACE pg_default;

create index IF not exists idx_rule_test_cases_rule_id on public.rule_test_cases using btree (rule_id) TABLESPACE pg_default;

create index IF not exists idx_rule_test_cases_active on public.rule_test_cases using btree (is_active) TABLESPACE pg_default;

create trigger update_rule_test_cases_updated_at BEFORE
update on rule_test_cases for EACH row
execute FUNCTION update_updated_at_column ();
```



### 11. calculation errors table

```sql
create table public.calculation_errors (
  id uuid not null default gen_random_uuid (),
  execution_id uuid not null,
  schema_id text null,
  error_type text not null,
  error_message text not null,
  error_stack text null,
  input_data jsonb null,
  failed_step text null,
  retry_count integer null default 0,
  resolved boolean null default false,
  created_at timestamp without time zone null default now(),
  constraint calculation_errors_pkey primary key (id),
  constraint calculation_errors_schema_id_fkey foreign KEY (schema_id) references form_schemas (id),
  constraint valid_error_type check (
    (
      error_type = any (
        array[
          'formula_parse_error'::text,
          'variable_missing'::text,
          'calculation_overflow'::text,
          'rule_validation_failed'::text,
          'database_error'::text,
          'unknown_error'::text
        ]
      )
    )
  ),
  constraint valid_retry_count check ((retry_count >= 0))
) TABLESPACE pg_default;

create index IF not exists idx_calculation_errors_execution_id on public.calculation_errors using btree (execution_id) TABLESPACE pg_default;

create index IF not exists idx_calculation_errors_schema_id on public.calculation_errors using btree (schema_id) TABLESPACE pg_default;

create index IF not exists idx_calculation_errors_type on public.calculation_errors using btree (error_type) TABLESPACE pg_default;

create index IF not exists idx_calculation_errors_resolved on public.calculation_errors using btree (resolved) TABLESPACE pg_default;

create index IF not exists idx_calculation_errors_created_at on public.calculation_errors using btree (created_at desc) TABLESPACE pg_default;
```



### 12. form field mappings table

```sql
create table public.form_field_mappings (
  id uuid not null default gen_random_uuid (),
  from_schema_id text not null,
  to_schema_id text not null,
  from_field_name text not null,
  to_field_name text not null,
  mapping_type text not null,
  mapping_rules jsonb null,
  is_active boolean null default true,
  created_at timestamp without time zone null default now(),
  constraint form_field_mappings_pkey primary key (id),
  constraint unique_field_mapping unique (from_schema_id, to_schema_id, from_field_name),
  constraint form_field_mappings_from_schema_id_fkey foreign KEY (from_schema_id) references form_schemas (id),
  constraint form_field_mappings_to_schema_id_fkey foreign KEY (to_schema_id) references form_schemas (id),
  constraint valid_mapping_type check (
    (
      mapping_type = any (
        array[
          'direct'::text,
          'rename'::text,
          'split'::text,
          'combine'::text,
          'default'::text,
          'remove'::text
        ]
      )
    )
  )
) TABLESPACE pg_default;

create index IF not exists idx_form_field_mappings_from_schema on public.form_field_mappings using btree (from_schema_id) TABLESPACE pg_default;

create index IF not exists idx_form_field_mappings_to_schema on public.form_field_mappings using btree (to_schema_id) TABLESPACE pg_default;

create index IF not exists idx_form_field_mappings_type on public.form_field_mappings using btree (mapping_type) TABLESPACE pg_default;

create index IF not exists idx_form_field_mappings_active on public.form_field_mappings using btree (is_active) TABLESPACE pg_default;
```


### 13. system config table

```sql
create table public.system_config (
  key text not null,
  value jsonb not null,
  description text null,
  config_type text not null,
  is_active boolean null default true,
  created_at timestamp without time zone null default now(),
  updated_at timestamp without time zone null default now(),
  constraint system_config_pkey primary key (key),
  constraint valid_config_type check (
    (
      config_type = any (
        array[
          'calculation_engine'::text,
          'rounding_rules'::text,
          'tax_constants'::text,
          'validation_rules'::text,
          'api_settings'::text
        ]
      )
    )
  )
) TABLESPACE pg_default;

create index IF not exists idx_system_config_type on public.system_config using btree (config_type) TABLESPACE pg_default;

create index IF not exists idx_system_config_active on public.system_config using btree (is_active) TABLESPACE pg_default;

create trigger update_system_config_updated_at BEFORE
update on system_config for EACH row
execute FUNCTION update_updated_at_column ();
```


### 14. active calculation schemas table

```sql
create view public.active_calculation_schemas as
select
  fs.id,
  fs.schema_type,
  fs.version,
  fs.schema_data,
  fs.calculation_rules,
  fs.required_variables,
  fs.created_at,
  count(ca.id) as calculation_count,
  max(ca.created_at) as last_used_at
from
  form_schemas fs
  left join calculation_audit ca on fs.id = ca.schema_id
where
  fs.is_active = true
group by
  fs.id,
  fs.schema_type,
  fs.version,
  fs.schema_data,
  fs.calculation_rules,
  fs.required_variables,
  fs.created_at;
```

### 15. calculation stats table

```sql
create view public.calculation_stats as
select
  schema_id,
  calculation_type,
  count(*) as total_calculations,
  avg(execution_time_ms) as avg_execution_time,
  min(final_amount) as min_amount,
  max(final_amount) as max_amount,
  avg(final_amount) as avg_amount,
  date_trunc('day'::text, created_at) as calculation_date
from
  calculation_audit
group by
  schema_id,
  calculation_type,
  (date_trunc('day'::text, created_at));
```

### 16. aggregated rule sources table

```sql
create table public.aggregated_rule_sources (
  id uuid not null default gen_random_uuid (),
  aggregated_rule_id text not null,
  evidence_rule_id text not null,
  precedence_reason text null,
  weight numeric(6, 3) null,
  created_at timestamp without time zone null default now(),
  constraint aggregated_rule_sources_pkey primary key (id),
  constraint aggregated_rule_sources_unique unique (aggregated_rule_id, evidence_rule_id),
  constraint aggregated_rule_sources_aggregated_fk foreign KEY (aggregated_rule_id) references tax_rules (id) on delete CASCADE deferrable initially DEFERRED,
  constraint aggregated_rule_sources_evidence_fk foreign KEY (evidence_rule_id) references tax_rules (id) on delete CASCADE deferrable initially DEFERRED
) TABLESPACE pg_default;

create index IF not exists idx_agg_sources_aggregated on public.aggregated_rule_sources using btree (aggregated_rule_id) TABLESPACE pg_default;

create index IF not exists idx_agg_sources_evidence on public.aggregated_rule_sources using btree (evidence_rule_id) TABLESPACE pg_default;
```

### 17. calculation stats table

```sql
create table public.aggregation_runs (
  id uuid not null default gen_random_uuid (),
  tax_type text not null,
  target_date date not null,
  inputs_count integer not null default 0,
  outputs_count integer not null default 0,
  conflicts_count integer not null default 0,
  status text not null default 'completed'::text,
  details jsonb null,
  started_at timestamp without time zone null default now(),
  finished_at timestamp without time zone null,
  constraint aggregation_runs_pkey primary key (id),
  constraint valid_aggregation_status check (
    (
      status = any (
        array[
          'queued'::text,
          'running'::text,
          'completed'::text,
          'failed'::text
        ]
      )
    )
  )
) TABLESPACE pg_default;

create index IF not exists idx_aggregation_runs_lookup on public.aggregation_runs using btree (tax_type, target_date desc) TABLESPACE pg_default;

create index IF not exists idx_aggregation_runs_status on public.aggregation_runs using btree (status) TABLESPACE pg_default;
```


### 18. rule conflicts table

```sql
create table public.rule_conflicts (
  id uuid not null default gen_random_uuid (),
  tax_type text not null,
  target_date date not null,
  aspect text not null,
  status text not null default 'open'::text,
  details jsonb null,
  created_at timestamp without time zone null default now(),
  resolved_at timestamp without time zone null,
  constraint rule_conflicts_pkey primary key (id),
  constraint valid_conflict_aspect check (
    (
      aspect = any (
        array[
          'brackets'::text,
          'thresholds'::text,
          'definitions'::text,
          'formulas'::text,
          'units'::text,
          'inputs'::text,
          'other'::text
        ]
      )
    )
  ),
  constraint valid_conflict_status check (
    (
      status = any (
        array[
          'open'::text,
          'under_review'::text,
          'resolved'::text,
          'dismissed'::text
        ]
      )
    )
  )
) TABLESPACE pg_default;

create index IF not exists idx_rule_conflicts_lookup on public.rule_conflicts using btree (tax_type, target_date desc) TABLESPACE pg_default;

create index IF not exists idx_rule_conflicts_status on public.rule_conflicts using btree (status) TABLESPACE pg_default;
```


### 19. canonical variables table


```sql
create table public.canonical_variables (
  id uuid not null default gen_random_uuid (),
  key text not null,
  label text not null,
  description text null,
  data_type text not null,
  unit text null,
  category text null,
  version integer not null default 1,
  is_active boolean not null default true,
  deprecation_info jsonb null,
  created_at timestamp without time zone null default now(),
  updated_at timestamp without time zone null default now(),
  title text null,
  constraint canonical_variables_pkey primary key (id),
  constraint canonical_variables_key_uk unique (key),
  constraint canonical_variables_key_unique unique (key),
  constraint canonical_variables_valid_type check (
    (
      data_type = any (
        array[
          'string'::text,
          'number'::text,
          'integer'::text,
          'boolean'::text,
          'date'::text,
          'currency'::text,
          'percent'::text
        ]
      )
    )
  )
) TABLESPACE pg_default;

create index IF not exists idx_canonical_variables_category on public.canonical_variables using btree (category) TABLESPACE pg_default;

create index IF not exists idx_canonical_variables_active on public.canonical_variables using btree (is_active) TABLESPACE pg_default;

create trigger update_canonical_variables_updated_at BEFORE
update on canonical_variables for EACH row
execute FUNCTION update_updated_at_column ();
```

### 20. canonical variable synonyms table


```sql
create table public.canonical_variable_synonyms (
  id uuid not null default gen_random_uuid (),
  variable_id uuid null,
  term text not null,
  normalized_term text not null,
  source text not null default 'llm'::text,
  confidence numeric(3, 2) null,
  status text not null default 'pending'::text,
  created_at timestamp without time zone null default now(),
  decided_at timestamp without time zone null,
  decided_by text null,
  constraint canonical_variable_synonyms_pkey primary key (id),
  constraint canonical_variable_synonyms_variable_id_fkey foreign KEY (variable_id) references canonical_variables (id) on delete set null,
  constraint canonical_variable_synonyms_status check (
    (
      status = any (
        array[
          'pending'::text,
          'approved'::text,
          'rejected'::text
        ]
      )
    )
  )
) TABLESPACE pg_default;

create unique INDEX IF not exists uq_cvs_normalized_term on public.canonical_variable_synonyms using btree (normalized_term) TABLESPACE pg_default;

create index IF not exists idx_cvs_variable_id on public.canonical_variable_synonyms using btree (variable_id) TABLESPACE pg_default;

create index IF not exists idx_cvs_status on public.canonical_variable_synonyms using btree (status) TABLESPACE pg_default;
```

### 21. llm extraction batches table


```sql
create table public.llm_extraction_batches (
  id uuid not null default gen_random_uuid (),
  source_document_id text null,
  tax_type text not null,
  target_date date null,
  tool_version text null,
  status text not null default 'pending'::text,
  proposal_count integer not null default 0,
  approved_count integer not null default 0,
  rejected_count integer not null default 0,
  details jsonb null,
  created_at timestamp without time zone null default now(),
  completed_at timestamp without time zone null,
  constraint llm_extraction_batches_pkey primary key (id),
  constraint llm_extraction_batches_source_document_id_fkey foreign KEY (source_document_id) references documents (id) on delete set null,
  constraint llm_extraction_batches_status check (
    (
      status = any (
        array[
          'pending'::text,
          'completed'::text,
          'failed'::text,
          'discarded'::text
        ]
      )
    )
  )
) TABLESPACE pg_default;

create index IF not exists idx_llm_batches_lookup on public.llm_extraction_batches using btree (tax_type, target_date desc) TABLESPACE pg_default;

create index IF not exists idx_llm_batches_status on public.llm_extraction_batches using btree (status) TABLESPACE pg_default;
```

### 22. llm extraction proposals table


```sql
create table public.llm_extraction_proposals (
  id uuid not null default gen_random_uuid (),
  batch_id uuid not null,
  term text not null,
  context_excerpt text null,
  chunk_id text null,
  suggested_variable_key text null,
  suggested_metadata jsonb null,
  confidence numeric(3, 2) null,
  status text not null default 'pending'::text,
  mapped_variable_id uuid null,
  notes text null,
  created_at timestamp without time zone null default now(),
  decided_at timestamp without time zone null,
  decided_by text null,
  constraint llm_extraction_proposals_pkey primary key (id),
  constraint llm_extraction_proposals_batch_id_fkey foreign KEY (batch_id) references llm_extraction_batches (id) on delete CASCADE,
  constraint llm_extraction_proposals_chunk_id_fkey foreign KEY (chunk_id) references document_chunks (id) on delete set null,
  constraint llm_extraction_proposals_mapped_variable_id_fkey foreign KEY (mapped_variable_id) references canonical_variables (id) on delete set null,
  constraint llm_extraction_proposals_status check (
    (
      status = any (
        array[
          'pending'::text,
          'approved'::text,
          'rejected'::text,
          'mapped'::text
        ]
      )
    )
  )
) TABLESPACE pg_default;

create index IF not exists idx_llm_proposals_batch on public.llm_extraction_proposals using btree (batch_id) TABLESPACE pg_default;

create index IF not exists idx_llm_proposals_status on public.llm_extraction_proposals using btree (status) TABLESPACE pg_default;

create index IF not exists idx_llm_proposals_mapped on public.llm_extraction_proposals using btree (mapped_variable_id) TABLESPACE pg_default;

create index IF not exists idx_llm_proposals_chunk on public.llm_extraction_proposals using btree (chunk_id) TABLESPACE pg_default;

create index IF not exists idx_llm_proposals_metadata_gin on public.llm_extraction_proposals using gin (suggested_metadata) TABLESPACE pg_default;
```

### 23. rule field metadata table


```sql
create table public.rule_field_metadata (
  id uuid not null default gen_random_uuid (),
  rule_id text not null,
  variable_id uuid not null,
  field_key text not null,
  label text null,
  help_text text null,
  data_type text not null,
  unit text null,
  required boolean not null default false,
  min_value numeric(20, 4) null,
  max_value numeric(20, 4) null,
  enum_options text[] null,
  ui_group text null,
  ui_order integer null default 0,
  effective_date date null,
  status text not null default 'validated'::text,
  source_kind text not null default 'manual'::text,
  created_at timestamp without time zone null default now(),
  updated_at timestamp without time zone null default now(),
  constraint rule_field_metadata_pkey primary key (id),
  constraint rule_field_metadata_unique unique (rule_id, variable_id),
  constraint rule_field_metadata_rule_id_fkey foreign KEY (rule_id) references tax_rules (id) on delete CASCADE,
  constraint rule_field_metadata_variable_id_fkey foreign KEY (variable_id) references canonical_variables (id) on delete RESTRICT,
  constraint rule_field_metadata_status check (
    (
      status = any (
        array[
          'pending'::text,
          'validated'::text,
          'deprecated'::text
        ]
      )
    )
  ),
  constraint rule_field_metadata_source_kind check (
    (
      source_kind = any (
        array[
          'manual'::text,
          'llm_proposed'::text,
          'aggregated'::text,
          'inferred'::text
        ]
      )
    )
  ),
  constraint rule_field_metadata_valid_type check (
    (
      data_type = any (
        array[
          'string'::text,
          'number'::text,
          'integer'::text,
          'boolean'::text,
          'date'::text,
          'currency'::text,
          'percent'::text
        ]
      )
    )
  )
) TABLESPACE pg_default;

create index IF not exists idx_rfm_rule_id on public.rule_field_metadata using btree (rule_id) TABLESPACE pg_default;

create index IF not exists idx_rfm_variable_id on public.rule_field_metadata using btree (variable_id) TABLESPACE pg_default;

create index IF not exists idx_rfm_status on public.rule_field_metadata using btree (status) TABLESPACE pg_default;

create trigger update_rule_field_metadata_updated_at BEFORE
update on rule_field_metadata for EACH row
execute FUNCTION update_updated_at_column ();
```

### 24. rule formulas table


```sql
create table public.rule_formulas (
  id uuid not null default gen_random_uuid (),
  rule_id text not null,
  expression text not null,
  output_variable_id uuid null,
  calculation_order integer not null default 0,
  status text not null default 'validated'::text,
  notes text null,
  created_at timestamp without time zone null default now(),
  updated_at timestamp without time zone null default now(),
  constraint rule_formulas_pkey primary key (id),
  constraint rule_formulas_output_variable_id_fkey foreign KEY (output_variable_id) references canonical_variables (id) on delete set null,
  constraint rule_formulas_rule_id_fkey foreign KEY (rule_id) references tax_rules (id) on delete CASCADE,
  constraint rule_formulas_status check (
    (
      status = any (
        array[
          'pending'::text,
          'validated'::text,
          'deprecated'::text
        ]
      )
    )
  )
) TABLESPACE pg_default;

create index IF not exists idx_rule_formulas_rule on public.rule_formulas using btree (rule_id, calculation_order) TABLESPACE pg_default;

create index IF not exists idx_rule_formulas_status on public.rule_formulas using btree (status) TABLESPACE pg_default;

create trigger update_rule_formulas_updated_at BEFORE
update on rule_formulas for EACH row
execute FUNCTION update_updated_at_column ();
```


### 25. preflight runs table


```sql
create table public.preflight_runs (
  id uuid not null default gen_random_uuid (),
  tax_type text not null,
  target_date date not null,
  evidence_rules_count integer not null default 0,
  aggregated_rules_count integer not null default 0,
  blockers jsonb null,
  status text not null default 'ok'::text,
  created_at timestamp without time zone null default now(),
  constraint preflight_runs_pkey primary key (id),
  constraint preflight_runs_status check (
    (status = any (array['ok'::text, 'blocked'::text]))
  )
) TABLESPACE pg_default;

create index IF not exists idx_preflight_runs_lookup on public.preflight_runs using btree (tax_type, target_date desc) TABLESPACE pg_default;
```


