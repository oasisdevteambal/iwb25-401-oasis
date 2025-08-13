# Sri Lankan Tax Calculation Application - Architect
┌─────────────────────────────────────────────────────────────────┐
│                        Data Layer                               │
├─────────────────────────────────────────────────────────────────┤
│  Supabase DB       │  pgvector       │  Supabase       │  Cache │
│  - Tax Rules       │  - Embeddings   │  Storage        │  - Redis│
│  - Calculations    │  - Semantic     │  - Documents    │  - Session│
│  - User Data       │  - Search       │  - Files        │  - Results│
└─────────────────────────────────────────────────────────────────┘mentation

## System Overview

The Sri Lankan Tax Calculation Application is a modern, AI-powered web application designed to automate tax rule extraction from government documents and provide dynamic tax calculation services. The system employs a microservices-oriented architecture with clear separation of concerns between presentation, business logic, and data layers.

## Architecture Principles

### Core Design Principles
1. **Separation of Concerns** - Clear boundaries between UI, business logic, and data layers
2. **Scalability** - Horizontal scaling capabilities for high-load scenarios
3. **Maintainability** - Modular design for easy updates and modifications
4. **Extensibility** - Plugin-based architecture for adding new tax types
5. **Data Integrity** - ACID compliance and consistency across all operations
6. **Security First** - Built-in security measures at every layer

### Architectural Patterns
- **Layered Architecture** - Clear separation between presentation, business, and data layers
- **Repository Pattern** - Data access abstraction
- **Service Layer Pattern** - Business logic encapsulation
- **Event-Driven Architecture** - Asynchronous processing for document handling
- **CQRS Pattern** - Separate read and write models for complex queries

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Presentation Layer                       │
├─────────────────────────────────────────────────────────────────┤
│  Next.js Frontend  │  Admin Dashboard  │  Mobile Interface     │
│  - Tax Forms       │  - Document Mgmt  │  - Responsive UI      │
│  - Results Display │  - Rule Management│  - Progressive Web    │
│  - Chat Interface  │  - Analytics      │  - Offline Support    │
└─────────────┬───────────────────────────────────────────────────┘
              │ REST API / GraphQL
┌─────────────▼───────────────────────────────────────────────────┐
│                       API Gateway Layer                         │
├─────────────────────────────────────────────────────────────────┤
│  - Authentication    │  - Rate Limiting   │  - Request Routing  │
│  - Authorization     │  - Caching         │  - Load Balancing   │
│  - Input Validation  │  - Monitoring      │  - CORS Handling    │
└─────────────┬───────────────────────────────────────────────────┘
              │
┌─────────────▼───────────────────────────────────────────────────┐
│                      Business Logic Layer                       │
├─────────────────────────────────────────────────────────────────┤
│  Document Service  │  Tax Engine    │  Form Generator  │  Chat  │
│  - File Upload     │  - Calculations│  - Schema Gen    │  - NLP │
│  - Text Extract    │  - Rule Engine │  - Validation    │  - AI  │
│  - LLM Processing  │  - Brackets    │  - Dynamic Forms │  - RAG │
└─────────────┬───────────────────────────────────────────────────┘
              │
┌─────────────▼───────────────────────────────────────────────────┐
│                        Data Layer                               │
├─────────────────────────────────────────────────────────────────┤
│  PostgreSQL        │  Vector DB      │  Blob Storage   │  Cache │
│  - Tax Rules       │  - Embeddings   │  - Documents    │  - Redis│
│  - Calculations    │  - Semantic     │  - Files        │  - Session│
│  - User Data       │  - Search       │  - Assets       │  - Results│
└─────────────────────────────────────────────────────────────────┘
```

## Component Architecture

### Frontend Layer (Next.js/React)

#### Component Structure
```
frontend/
├── app/                      # Next.js App Router
│   ├── layout.tsx           # Root layout
│   ├── page.tsx             # Home page
│   ├── loading.tsx          # Global loading UI
│   ├── error.tsx            # Global error boundary
│   ├── not-found.tsx        # 404 page
│   ├── globals.css          # Global styles
│   ├── admin/               # Admin routes
│   │   ├── layout.tsx       # Admin layout
│   │   ├── page.tsx         # Admin dashboard
│   │   ├── documents/       # Document management routes
│   │   │   ├── page.tsx
│   │   │   └── upload/
│   │   │       └── page.tsx
│   │   └── rules/           # Rule management routes
│   │       ├── page.tsx
│   │       └── [id]/
│   │           └── page.tsx
│   ├── calculate/           # Tax calculation routes
│   │   ├── layout.tsx       # Calculation layout
│   │   ├── page.tsx         # Main calculation form
│   │   ├── loading.tsx      # Calculation loading
│   │   └── results/         # Results routes
│   │       └── page.tsx
│   ├── chat/                # Chat interface routes
│   │   ├── page.tsx         # Chat page
│   │   └── loading.tsx      # Chat loading
│   └── api/                 # API routes (App Router)
│       ├── documents/
│       │   ├── route.ts     # Document endpoints
│       │   └── [id]/
│       │       └── route.ts
│       ├── calculate/
│       │   └── route.ts     # Calculation endpoints
│       └── forms/
│           └── schema/
│               └── route.ts # Schema endpoints
├── components/              # Reusable React components
│   ├── ui/                  # Base UI components
│   │   ├── Button.tsx
│   │   ├── Modal.tsx
│   │   └── LoadingSpinner.tsx
│   ├── forms/               # Form-related components
│   │   ├── TaxCalculationForm.tsx
│   │   ├── FormFieldRenderer.tsx
│   │   └── ValidationDisplay.tsx
│   ├── admin/               # Administrative components
│   │   ├── DocumentUpload.tsx
│   │   ├── RuleManager.tsx
│   │   └── AdminDashboard.tsx
│   └── results/             # Results display components
│       ├── TaxBreakdown.tsx
│       ├── CalculationSummary.tsx
│       └── ExportOptions.tsx
├── lib/                     # Utility functions and configurations
│   ├── supabase.ts         # Supabase client
│   ├── gemini.ts           # Gemini API client
│   ├── validators.ts       # Form validators
│   ├── formatters.ts       # Data formatters
│   └── constants.ts        # App constants
├── hooks/                   # Custom React hooks
│   ├── useTaxCalculation.ts
│   ├── useFormSchema.ts
│   └── useDocumentUpload.ts
├── store/                   # State management
│   ├── taxStore.ts
│   ├── userStore.ts
│   └── appStore.ts
└── types/                   # TypeScript definitions
    ├── tax.ts
    ├── document.ts
    └── api.ts
```
```
frontend/
├── components/
│   ├── common/           # Reusable UI components
│   │   ├── Button.tsx
│   │   ├── Modal.tsx
│   │   └── LoadingSpinner.tsx
│   ├── forms/            # Form-related components
│   │   ├── TaxCalculationForm.tsx
│   │   ├── FormFieldRenderer.tsx
│   │   └── ValidationDisplay.tsx
│   ├── admin/            # Administrative components
│   │   ├── DocumentUpload.tsx
│   │   ├── RuleManager.tsx
│   │   └── AdminDashboard.tsx
│   └── results/          # Results display components
│       ├── TaxBreakdown.tsx
│       ├── CalculationSummary.tsx
│       └── ExportOptions.tsx
├── pages/                # Next.js pages
│   ├── api/              # API routes (if using Next.js API)
│   ├── admin/            # Admin interface pages
│   ├── calculate/        # Tax calculation pages
│   └── chat/             # Chat interface pages
├── hooks/                # Custom React hooks
│   ├── useTaxCalculation.ts
│   ├── useFormSchema.ts
│   └── useDocumentUpload.ts
├── services/             # API service layer
│   ├── taxService.ts
│   ├── documentService.ts
│   └── authService.ts
├── store/                # State management
│   ├── taxStore.ts
│   ├── userStore.ts
│   └── appStore.ts
└── utils/                # Utility functions
    ├── validators.ts
    ├── formatters.ts
    └── constants.ts
```

#### State Management Architecture
```
┌─────────────────────────────────┐
│         App Router State        │
├─────────────────────────────────┤
│  Server State     │  Client State│
│  - Server Comp    │  - React State│
│  - Database       │  - Context API│
│  - Cache          │  - Zustand    │
└─────────────┬───────────────────┘
              │
┌─────────────▼───────────────────┐
│        Feature States           │
├─────────────────────────────────┤
│  Tax Calculation │  Document    │
│  - Form Data     │  - Upload    │
│  - Results       │  - Status    │
│  - History       │  - Progress  │
│  - Server Cache  │  - Real-time │
└─────────────────────────────────┘
```

#### App Router Features
- **Server Components** - Default server rendering for better performance
- **Client Components** - Interactive components marked with "use client"
- **Streaming UI** - Progressive rendering with loading.tsx and Suspense
- **Error Handling** - Automatic error boundaries with error.tsx
- **Nested Layouts** - Shared UI across route segments
- **Route Groups** - Organize routes without affecting URL structure
- **Parallel Routes** - Display multiple active routes simultaneously
- **Intercepting Routes** - Override routes in certain contexts

### Backend Layer (Ballerina)

#### Service Architecture
```
backend/
├── services/
│   ├── document_service.bal      # Document processing
│   ├── tax_calculation_service.bal # Tax calculations
│   ├── form_schema_service.bal   # Dynamic form generation
│   ├── admin_service.bal         # Administrative functions
│   └── chat_service.bal          # Chat/AI interactions
├── modules/
│   ├── tax_engine/               # Core tax calculation logic
│   │   ├── income_tax.bal
│   │   ├── vat_calculator.bal
│   │   └── paye_calculator.bal
│   ├── document_processor/       # Document handling with Java interop
│   │   ├── pdf_parser.bal        # Enhanced with Java PDFBox integration
│   │   ├── word_processor.bal    # Enhanced with Java Apache POI integration
│   │   └── text_extractor.bal    # Intelligent chunking with Java support
│   ├── llm_integration/          # AI/LLM integration
│   │   ├── gemini_client.bal
│   │   ├── embedding_generator.bal
│   │   └── rule_extractor.bal
│   └── data_access/              # Data layer abstraction
│       ├── supabase_client.bal
│       ├── vector_db_client.bal
│       └── storage_client.bal
├── types/                        # Type definitions
│   ├── tax_types.bal
│   ├── document_types.bal
│   └── api_types.bal
├── config/                       # Configuration
│   ├── supabase_config.bal
│   ├── api_config.bal
│   └── environment_config.bal
└── tests/                        # Test files
    ├── unit/
    ├── integration/
    └── e2e/
```

#### Service Interaction Flow
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Document      │    │   Tax Engine    │    │   Form Schema   │
│   Service       │    │   Service       │    │   Service       │
├─────────────────┤    ├─────────────────┤    ├─────────────────┤
│ - Upload Files  │    │ - Calculate Tax │    │ - Generate      │
│ - Extract Text  │    │ - Apply Rules   │    │   Schema        │
│ - Process LLM   │    │ - Validate Data │    │ - Validate      │
│ - Store Rules   │◄──►│ - Format Result │◄──►│   Rules         │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Data Access Layer                           │
├─────────────────────────────────────────────────────────────────┤
│  Repository Pattern Implementation                              │
│  - TaxRuleRepository    - DocumentRepository                   │
│  - CalculationRepository - UserRepository                      │
│  - SchemaRepository     - AuditRepository                      │
│  (All using Supabase client with Row Level Security)          │
└─────────────────────────────────────────────────────────────────┘
```

### Java Interop Integration for Enhanced Document Processing

**Architecture Decision: Java Library Integration**

The system utilizes Ballerina's Java interoperability features to integrate professional-grade PDF and document processing libraries for superior text extraction capabilities.

#### Document Processing Architecture with Java Interop
```
┌─────────────────────────────────────────────────────────────────┐
│                   Document Processing Layer                     │
├─────────────────────────────────────────────────────────────────┤
│  Ballerina Services    │  Java Interop Layer │  External APIs   │
│  - document_service    │  - PDFBox Integration│  - Fallback     │
│  - pdf_parser         │  - Apache POI        │  - Gemini API    │
│  - word_processor     │  - Text Extraction   │  - File Storage  │
│  - text_extractor     │  - Layout Parsing    │  - Supabase      │
└─────────────┬───────────────────────────────────────────────────┘
              │
┌─────────────▼───────────────────────────────────────────────────┐
│                 Java Library Integration                        │
├─────────────────────────────────────────────────────────────────┤
│  PDFBox (PDF Processing)     │  Apache POI (Office Docs)        │
│  - Text extraction           │  - Word document processing      │
│  - Layout preservation       │  - Excel spreadsheet parsing     │
│  - Table detection          │  - PowerPoint extraction          │
│  - Metadata extraction      │  - Format preservation            │
│  - Embedded content         │  - Complex layouts                │
│                              │                                  │
│  Benefits:                   │  Benefits:                       │
│  - Professional PDF parsing │  - Complete Office support        │
│  - Complex layout handling  │  - Native format understanding    │
│  - Compressed content       │  - Advanced text extraction       │
│  - Scanned document OCR     │  - Metadata preservation          │
└─────────────────────────────────────────────────────────────────┘
```

#### Implementation Strategy

**1. JAR Dependencies Management:**
```
backend/
├── libs/                        # Java library dependencies
│   ├── pdfbox-app-3.0.0.jar    # Apache PDFBox for PDF processing
│   ├── poi-5.2.4.jar           # Apache POI for Office documents
│   ├── poi-ooxml-5.2.4.jar     # POI OOXML support
│   └── commons-logging-1.2.jar  # Required dependencies
├── modules/
│   └── document_processor/
│       ├── pdf_parser.bal       # Enhanced with Java interop
│       └── java_interop.bal     # Java integration utilities
```

**2. Ballerina Configuration:**
```toml
# Ballerina.toml
[platform.java17]
path = "./libs/pdfbox-app-3.0.0.jar:./libs/poi-5.2.4.jar:./libs/poi-ooxml-5.2.4.jar"
```

**3. Enhanced Processing Capabilities:**
- **Superior PDF Extraction**: Professional-grade parsing of complex PDF layouts, tables, and embedded content
- **Office Document Support**: Native processing of Word, Excel, and PowerPoint documents
- **Layout Preservation**: Maintain document structure and formatting context
- **Metadata Extraction**: Access document properties, creation dates, and authorship information
- **Error Resilience**: Robust handling of corrupted or password-protected documents
- **Performance Optimization**: Efficient processing of large document collections

**4. Fallback Strategy:**
- Primary: Java interop with PDFBox/Apache POI
- Secondary: External PDF extraction services
- Tertiary: Basic Ballerina string parsing for development/testing

## Data Architecture

### Database Design

#### Entity Relationship Diagram with Chunking Support
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Documents     │    │ Document Chunks │    │   Tax Rules     │
├─────────────────┤    ├─────────────────┤    ├─────────────────┤
│ id (PK)         │    │ id (PK)         │    │ id (PK)         │
│ filename        │◄──►│ document_id(FK) │◄──►│ chunk_id (FK)   │
│ file_path       │    │ chunk_sequence  │    │ rule_type       │
│ content_type    │    │ start_position  │    │ title           │
│ upload_date     │    │ end_position    │    │ description     │
│ processed       │    │ chunk_text      │    │ rule_data       │
│ status          │    │ chunk_size      │    │ embedding(768)  │
│ total_chunks    │    │ processing_stat │    │ effective_date  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Tax Brackets   │    │ Form Schemas    │    │  Calculations   │
├─────────────────┤    ├─────────────────┤    ├─────────────────┤
│ id (PK)         │    │ id (PK)         │    │ id (PK)         │
│ rule_id (FK)    │    │ schema_type     │    │ user_id (FK)    │
│ min_income      │    │ version         │    │ input_data      │
│ max_income      │    │ schema_data     │    │ result_data     │
│ tax_rate        │    │ is_active       │    │ tax_amount      │
│ fixed_amount    │    │ chunk_sources   │    │ created_at      │
│ bracket_order   │    │ created_at      │    │ chunk_refs      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

#### Chunking Data Model

**Core Chunking Tables:**

```sql
-- Document chunks table for managing document segmentation
CREATE TABLE document_chunks (
    id SERIAL PRIMARY KEY,
    document_id INTEGER REFERENCES documents(id) ON DELETE CASCADE,
    chunk_sequence INTEGER NOT NULL,
    start_position INTEGER,
    end_position INTEGER,
    chunk_text TEXT NOT NULL,
    chunk_size INTEGER,
    chunk_type VARCHAR(50) DEFAULT 'content', -- 'content', 'table', 'header'
    overlap_with_previous INTEGER DEFAULT 0,
    overlap_with_next INTEGER DEFAULT 0,
    processing_status VARCHAR(50) DEFAULT 'pending',
    gemini_tokens_used INTEGER,
    error_message TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    processed_at TIMESTAMP,
    
    -- Ensure unique sequence per document
    UNIQUE(document_id, chunk_sequence)
);

-- Enhanced tax_rules table with chunk references
ALTER TABLE tax_rules ADD COLUMN chunk_id INTEGER REFERENCES document_chunks(id);
ALTER TABLE tax_rules ADD COLUMN chunk_sequence INTEGER;
ALTER TABLE tax_rules ADD COLUMN chunk_confidence DECIMAL(3,2); -- 0.00-1.00
ALTER TABLE tax_rules ADD COLUMN extraction_context TEXT; -- Surrounding text context

-- Indexing for chunk-based queries
CREATE INDEX idx_chunks_document_sequence ON document_chunks(document_id, chunk_sequence);
CREATE INDEX idx_chunks_processing_status ON document_chunks(processing_status);
CREATE INDEX idx_tax_rules_chunk ON tax_rules(chunk_id);
CREATE INDEX idx_chunks_type ON document_chunks(chunk_type);
```

**Chunk Processing Metadata:**

```sql
-- Chunk processing analytics
CREATE TABLE chunk_processing_stats (
    id SERIAL PRIMARY KEY,
    chunk_id INTEGER REFERENCES document_chunks(id),
    processing_start_time TIMESTAMP,
    processing_end_time TIMESTAMP,
    gemini_api_calls INTEGER DEFAULT 0,
    rules_extracted INTEGER DEFAULT 0,
    processing_errors INTEGER DEFAULT 0,
    quality_score DECIMAL(3,2), -- Overall chunk processing quality
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### Data Storage Strategy with Chunking
```
┌─────────────────────────────────────────────────────────────────┐
│                      Storage Layer                              │
├─────────────────────────────────────────────────────────────────┤
│  Structured Data    │  Chunk Data       │  Vector Data          │
│  (Supabase)         │  (Supabase)       │  (pgvector extension) │
│                     │                   │                       │
├─────────────────────────────────────────────────────────────────┤
│ • Tax Rules         │ • Document Chunks │ • Per-Chunk Embeds    │
│ • Tax Brackets      │ • Chunk Metadata  │ • Semantic Vectors    │
│ • User Data         │ • Processing Stats│ • Search Indices      │
│ • Calculations      │ • Chunk Relations │ • Similarity Scores   │
│ • Form Schemas      │ • Overlap Data    │ • Query Vectors       │
│ • Audit Logs        │ • Error Tracking  │ • Context Embeddings  │
├─────────────────────────────────────────────────────────────────┤
│  Unstructured Data  │  Chunk Processing │  Performance Layer    │
│  (Supabase Storage) │  Pipeline         │  (Redis Cache)        │
├─────────────────────────────────────────────────────────────────┤
│ • Original PDFs     │ • Parallel Proc   │ • Chunk Cache         │
│ • Word Documents    │ • Error Recovery  │ • Vector Cache        │
│ • Images/Tables     │ • Progress Track  │ • Processing Queue    │
│ • Backup Files      │ • Quality Control │ • Session Data        │
└─────────────────────────────────────────────────────────────────┘
```

**Chunking Storage Considerations:**

1. **Chunk Size Management**
   - Original document: Supabase Storage
   - Processed chunks: PostgreSQL TEXT columns
   - Large chunks (>8KB): Split into sub-chunks automatically

2. **Vector Storage Optimization**
   - Individual embeddings per chunk for precise semantic search
   - Batch embedding generation to optimize Gemini API usage
   - Hierarchical indexing for document-level and chunk-level searches

3. **Processing State Management**
   - Chunk processing queue in Redis for parallel processing
   - Error state tracking for failed chunk processing
   - Progress indicators for large document processing

4. **Chunk Relationship Preservation**
   - Overlap data maintains context between chunks
   - Sequence tracking ensures proper document reconstruction
   - Cross-chunk rule references for complex tax regulations

### Caching Strategy

#### Multi-Level Caching Architecture
```
┌─────────────────────────────────────────────────────────────────┐
│                        Cache Layers                             │
├─────────────────────────────────────────────────────────────────┤
│  Browser Cache     │  CDN Cache        │  Application Cache     │
│  - Static Assets   │  - Images         │  - API Responses       │
│  - Page Cache      │  - CSS/JS         │  - Query Results       │
│  - Local Storage   │  - Documents      │  - Session Data        │
├─────────────────────────────────────────────────────────────────┤
│                    Redis Cache Layer                            │
├─────────────────────────────────────────────────────────────────┤
│ • Tax Calculation Results    • Form Schemas                     │
│ • User Sessions             • Document Processing Status        │
│ • API Rate Limiting         • Frequently Accessed Rules         │
│ • Temporary File Storage    • Chat Conversation History         │
└─────────────────────────────────────────────────────────────────┘
```

## API Architecture

### RESTful API Design

#### API Versioning Strategy (App Router)
```
app/api/v1/
├── documents/
│   ├── route.ts             # GET, POST /api/v1/documents
│   ├── upload/
│   │   └── route.ts         # POST /api/v1/documents/upload
│   └── [id]/
│       ├── route.ts         # GET, PUT, DELETE /api/v1/documents/[id]
│       ├── status/
│       │   └── route.ts     # GET /api/v1/documents/[id]/status
│       └── process/
│           └── route.ts     # POST /api/v1/documents/[id]/process
├── tax/
│   ├── calculate/
│   │   └── route.ts         # POST /api/v1/tax/calculate
│   ├── estimate/
│   │   └── route.ts         # POST /api/v1/tax/estimate
│   └── brackets/
│       └── [type]/
│           └── route.ts     # GET /api/v1/tax/brackets/[type]
├── forms/
│   └── schema/
│       ├── route.ts         # GET /api/v1/forms/schema
│       ├── latest/
│       │   └── route.ts     # GET /api/v1/forms/schema/latest
│       └── [type]/
│           └── route.ts     # GET /api/v1/forms/schema/[type]
├── admin/
│   └── rules/
│       ├── route.ts         # GET, POST /api/v1/admin/rules
│       └── [id]/
│           └── route.ts     # GET, PUT, DELETE /api/v1/admin/rules/[id]
└── chat/
    ├── message/
    │   └── route.ts         # POST /api/v1/chat/message
    └── history/
        └── route.ts         # GET /api/v1/chat/history
```

#### App Router API Example
```typescript
// app/api/v1/tax/calculate/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    
    // Connect to Supabase
    const supabase = createClient(
      process.env.SUPABASE_URL!,
      process.env.SUPABASE_SERVICE_KEY!
    );
    
    // Perform tax calculation
    const result = await calculateTax(body, supabase);
    
    return NextResponse.json(result);
  } catch (error) {
    return NextResponse.json(
      { error: 'Internal Server Error' },
      { status: 500 }
    );
  }
}
```

#### Request/Response Flow
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Frontend      │    │   API Gateway   │    │   Backend       │
│   Application   │    │   (Rate Limit,  │    │   Services      │
│                 │    │   Auth, CORS)   │    │                 │
├─────────────────┤    ├─────────────────┤    ├─────────────────┤
│ 1. User Input   │───►│ 2. Validate     │───►│ 3. Process      │
│ 4. Display      │◄───│    Request      │◄───│    Request      │
│    Results      │    │ 5. Format       │    │ 6. Execute      │
│                 │    │    Response     │    │    Business     │
│                 │    │                 │    │    Logic        │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```



## Security Architecture

### Authentication & Authorization

#### Security Layers
```
┌─────────────────────────────────────────────────────────────────┐
│                   Security Architecture                         │
├─────────────────────────────────────────────────────────────────┤
│  Frontend Security  │  Transport        │  Backend Security     │
│  - HTTPS Only       │  - TLS 1.3        │  - JWT Validation     │
│  - CSP Headers      │  - Certificate    │  - Role-Based Access  │
│  - XSS Protection   │  - HSTS           │  - Input Validation   │
│  - CSRF Tokens      │  - Secure Cookies │  - SQL Injection Prev │
├─────────────────────────────────────────────────────────────────┤
│                    Data Security Layer                          │
├─────────────────────────────────────────────────────────────────┤
│ • Encryption at Rest (AES-256)    • Encryption in Transit       │
│ • Database Row-Level Security     • API Rate Limiting           │
│ • Audit Logging                   • Sensitive Data Masking      │
│ • Backup Encryption               • Key Management (Vault)      │
└─────────────────────────────────────────────────────────────────┘
```

#### Authentication Flow
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   User Login    │    │   Auth Service  │    │   Resource      │
│                 │    │                 │    │   Server        │
├─────────────────┤    ├─────────────────┤    ├─────────────────┤
│ 1. Credentials  │───►│ 2. Validate     │    │                 │
│ 4. Store Token  │◄───│    User         │    │                 │
│ 5. API Request  │───►│ 3. Generate JWT │───►│ 6. Validate JWT │
│ 8. Display Data │◄───│ 7. Forward      │◄───│    & Process    │
│                 │    │    Response     │    │    Request      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## AI/ML Architecture

### Large Language Model Integration

#### LLM Processing Pipeline with Intelligent Chunking
```
┌─────────────────────────────────────────────────────────────────┐
│                    Document Processing                          │
├─────────────────────────────────────────────────────────────────┤
│  Document Input  │  Text Extraction │  Intelligent Chunking     │
│  - PDF Files     │  - OCR Processing│  - Semantic Segmentation  │
│  - Word Docs     │  - Layout Parser │  - Context Preservation   │
│  - Text Files    │  - Table Extract │  - Chunk Metadata Gen     │
└─────────────┬───────────────────────────────────────────────────┘
              │
┌─────────────▼───────────────────────────────────────────────────┐
│                    Chunking Strategy                            │
├─────────────────────────────────────────────────────────────────┤
│  Semantic Chunks │  Fixed-Size      │  Chunk Management         │
│  - Header-Based  │  - 500-1500 tok  │  - Overlap Strategy       │
│  - Rule-Based    │  - 200w Overlap  │  - Sequence Tracking      │
│  - Table Preserv │  - Token Limits  │  - Error Recovery         │
└─────────────┬───────────────────────────────────────────────────┘
              │ (Multiple Chunks)
┌─────────────▼───────────────────────────────────────────────────┐
│                    LLM Processing (Gemini Free)                 │
├─────────────────────────────────────────────────────────────────┤
│  Per-Chunk Proc │  Structure       │  Validation & QA           │
│  - Rule Extract  │  - JSON Schema   │  - Rule Consistency       │
│  - Tax Brackets  │  - Field Types   │  - Data Validation        │
│  - Deductions    │  - Relationships │  - Quality Scoring        │
└─────────────┬───────────────────────────────────────────────────┘
              │
┌─────────────▼───────────────────────────────────────────────────┐
│                    Data Storage (Supabase)                      │
├─────────────────────────────────────────────────────────────────┤
│  Structured Data │  Vector Storage  │  Chunk Management         │
│  - Tax Rules DB  │  - pgvector      │  - Chunk Metadata         │
│  - Form Schemas  │  - Per-Chunk     │  - Processing Status      │
│  - Calculations  │  - Embeddings    │  - Audit Trail            │
└─────────────────────────────────────────────────────────────────┘
```

#### Document Chunking Strategy

**Why Chunking is Essential:**
- **LLM Token Limitations**: Gemini API has input token limits per request
- **Semantic Granularity**: Smaller chunks create more precise vector embeddings
- **Processing Reliability**: Error isolation and parallel processing capabilities
- **Memory Management**: Prevents memory overflow with large documents

**Optimal Chunk Specifications:**
- **Size**: 500-1500 tokens (300-1000 words) for Sri Lankan tax documents
- **Overlap**: 200-word overlap to maintain context boundaries
- **Structure**: Complete tax rules preserved within chunks

**Chunking Methods for Tax Documents:**

1. **Semantic Chunking** (Primary)
   - Split by document sections (Chapter, Section, Subsection)
   - Preserve complete tax rules and tables
   - Maintain hierarchical document structure
   - Best for structured government documents

2. **Fixed-Size with Overlap** (Fallback)
   - 1000-word chunks with 200-word overlap
   - Ensures no rule is split across boundaries
   - Simpler implementation for unstructured text

3. **Hybrid Approach** (Recommended)
   - Semantic splitting where possible
   - Fixed-size fallback for irregular content
   - Table and formula preservation logic

### Vector Database Architecture

#### Semantic Search System
```
┌─────────────────────────────────────────────────────────────────┐
│                   Vector Search Architecture                    │
├─────────────────────────────────────────────────────────────────┤
│  Query Processing │  Vector Search   │  Result Ranking          │
│  - Text Analysis  │  - Similarity    │  - Relevance Score       │
│  - Embedding Gen  │  - K-NN Search   │  - Context Matching      │
│  - Query Expand   │  - Filtering     │  - Result Fusion         │
├─────────────────────────────────────────────────────────────────┤
│                    Vector Database (pgvector)                   │
├─────────────────────────────────────────────────────────────────┤
│ • Rule Embeddings (768D vectors)    • HNSW Index Structures     │
│ • Document Sections               • Metadata Filtering          │
│ • Query History                   • Performance Optimization    │
│ • User Context                    • Supabase Integration        │
└─────────────────────────────────────────────────────────────────┘
```

## Performance Architecture

### Scalability Design

#### Horizontal Scaling Strategy
```
┌─────────────────────────────────────────────────────────────────┐
│                      Load Distribution                          │
├─────────────────────────────────────────────────────────────────┤
│   Load Balancer   │   API Gateway    │   Service Mesh           │
│   - Round Robin   │   - Rate Limiting│   - Circuit Breaker      │
│   - Health Checks │   - Caching      │   - Retry Logic          │
│   - SSL Term      │   - Auth Proxy   │   - Monitoring           │
└─────────────┬───────────────────────────────────────────────────┘
              │
┌─────────────▼───────────────────────────────────────────────────┐
│                    Service Instances                            │
├─────────────────────────────────────────────────────────────────┤
│  Frontend        │  Backend         │  Database                 │
│  - CDN Deploy    │  - Auto Scaling  │  - Read Replicas          │
│  - Static Assets │  - Container Orch│  - Connection Pool        │
│  - Edge Caching  │  - Health Monitor│  - Query Optimization     │
└─────────────────────────────────────────────────────────────────┘
```

### Performance Monitoring

#### Metrics and Monitoring
```
┌─────────────────────────────────────────────────────────────────┐
│                     Monitoring Stack                            │
├─────────────────────────────────────────────────────────────────┤
│  Application     │  Infrastructure  │  Business Metrics         │
│  - Response Time │  - CPU/Memory    │  - Tax Calculations       │
│  - Error Rates   │  - Disk I/O      │  - Document Processing    │
│  - Throughput    │  - Network       │  - User Engagement        │
│  - Custom Events │  - Database      │  - System Accuracy        │
├─────────────────────────────────────────────────────────────────┤
│                    Alerting & Analytics                         │
├─────────────────────────────────────────────────────────────────┤
│ • Real-time Alerts           • Performance Dashboards           │
│ • SLA Monitoring             • Capacity Planning                │
│ • Anomaly Detection          • Cost Optimization                │
│ • Root Cause Analysis        • Trend Analysis                   │
└─────────────────────────────────────────────────────────────────┘
```

## Integration Architecture

### External System Integration

#### Third-Party Services
```
┌─────────────────────────────────────────────────────────────────┐
│                   External Integrations                         │
├─────────────────────────────────────────────────────────────────┤
│  AI/ML Services   │  Storage         │  Communication           │
│  - Gemini API     │  - Supabase      │  - Email Service         │
│  - Ollama Local   │  - Supabase      │  - SMS Gateway           │
│  - Hugging Face   │  - Storage       │  - Push Notifications    │
├─────────────────────────────────────────────────────────────────┤
│  Government APIs  │  Payment         │  Analytics               │
│  - Tax Authority  │  - Free Tiers    │  - Google Analytics      │
│  - Document Verify│  - Stripe (dev)  │  - Plausible (free)      │
│  - Compliance     │  - Local Banks   │  - Custom Events         │
└─────────────────────────────────────────────────────────────────┘
```

### API Integration Patterns

#### Integration Patterns
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Synchronous   │    │   Asynchronous  │    │   Event-Driven  │
│   Integration   │    │   Integration   │    │   Integration   │
├─────────────────┤    ├─────────────────┤    ├─────────────────┤
│ • REST APIs     │    │ • Message Queue │    │ • Webhooks      │
│ • GraphQL       │    │ • Background    │    │ • Event Bus     │
│ • RPC Calls     │    │   Jobs          │    │ • Pub/Sub       │
│ • Direct DB     │    │ • Batch Process │    │ • Stream Proc   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Development Architecture

### Development Workflow

#### Development Pipeline
```
┌─────────────────────────────────────────────────────────────────┐
│                    Development Lifecycle                        │
├─────────────────────────────────────────────────────────────────┤
│  Local Dev       │  Version Control │  CI/CD Pipeline           │
│  - Hot Reload    │  - Git Workflow  │  - Automated Tests        │
│  - Dev Database  │  - Branch Policy │  - Code Quality           │
│  - Mock Services │  - Code Review   │  - Security Scans         │
└─────────────┬───────────────────────────────────────────────────┘
              │
┌─────────────▼───────────────────────────────────────────────────┐
│                    Quality Assurance                            │
├─────────────────────────────────────────────────────────────────┤
│  Testing Strategy│  Code Quality    │  Documentation            │
│  - Unit Tests    │  - Linting       │  - API Docs               │
│  - Integration   │  - Type Checking │  - Architecture           │
│  - E2E Tests     │  - Code Coverage │  - User Guides            │
└─────────────────────────────────────────────────────────────────┘
```

### Code Organization

#### Modular Architecture
```
┌─────────────────────────────────────────────────────────────────┐
│                     Code Organization                           │
├─────────────────────────────────────────────────────────────────┤
│  Domain Modules  │  Shared Libraries│  Configuration            │
│  - Tax Engine    │  - Utils         │  - Environment            │
│  - Document Proc │  - Validation    │  - Database               │
│  - User Mgmt     │  - Logging       │  - API Settings           │
│  - Form Builder  │  - Security      │  - Feature Flags          │
├─────────────────────────────────────────────────────────────────┤
│                    Cross-Cutting Concerns                       │
├─────────────────────────────────────────────────────────────────┤
│ • Logging & Monitoring      • Error Handling                    │
│ • Security & Authentication • Caching Strategy                  │
│ • Configuration Management  • Performance Optimization          │
│ • Data Validation          • Internationalization               │
└─────────────────────────────────────────────────────────────────┘
```

## Deployment Architecture

### Container Architecture

#### Containerization Strategy
```
┌─────────────────────────────────────────────────────────────────┐
│                    Container Layout                             │
├─────────────────────────────────────────────────────────────────┤
│  Frontend        │  Backend         │  Database                 │
│  - Next.js App   │  - Ballerina     │  - Supabase (managed)     │
│  - Static Assets │  - API Services  │  - Redis (free tier)      │
│  - Nginx Proxy   │  - Background    │  - pgvector enabled       │
│                  │    Workers       │  - Supabase Storage       │
├─────────────────────────────────────────────────────────────────┤
│                    Orchestration                                │
├─────────────────────────────────────────────────────────────────┤
│ • Container Registry        • Health Checks                     │
│ • Service Discovery         • Auto Scaling                      │
│ • Load Balancing            • Rolling Updates                   │
│ • Secret Management         • Backup & Recovery                 │
└─────────────────────────────────────────────────────────────────┘
```

This architecture documentation provides a comprehensive view of the system design, enabling developers to understand the relationships between components and make informed decisions during development and maintenance phases.
