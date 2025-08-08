# Sri Lankan Tax Calculation Application - Development Guide

## Project Overview

This is a comprehensive web-based tax calculation application specifically designed for Sri Lanka, enabling administrators to manage government tax documentation and end users to easily determine their tax liabilities. The system combines modern web technologies with AI-powered document processing to create dynamic, adaptive tax calculation forms.

## Architecture Overview

### Technology Stack

**Frontend:**
- Next.js with React for responsive UI
- React JSON Schema Form for dynamic form generation
- Tailwind CSS for styling
- TypeScript for type safety

**Backend:**
- Ballerina for API orchestration and business logic
- RESTful API endpoints
- File parsing and document processing

**Data Storage:**
- Supabase (Free tier) for PostgreSQL database with real-time features
- pgvector extension for semantic embeddings
- Supabase Storage for document files

**AI/ML:**
- Google Gemini API (Free tier) for document analysis
- Gemini embeddings for semantic search
- Ollama (local) for offline LLM processing

## Sri Lankan Tax System Context

The application handles multiple types of Sri Lankan taxes:

### Primary Tax Types
1. **Income Tax** - Progressive taxation on individual and corporate income
2. **Value Added Tax (VAT)** - Consumption tax on goods and services  
3. **Pay As You Earn (PAYE)** - Withholding tax on employment income
4. **Withholding Tax (WHT)** - Tax deducted at source on various payments
5. **Nation Building Tax (NBT)** - Additional tax on certain transactions
6. **Social Security Contribution Levy (SSCL)** - Employer and employee contributions

### Key Features for Sri Lankan Context
- Support for multiple tax brackets and rates
- Handling of various deductions and exemptions
- Accommodation for different taxpayer categories (individual, corporate, non-resident)
- Multi-language support (English, Sinhala, Tamil)

## Project Structure

```
tax-app/
├── frontend/                 # Next.js application (App Router)
│   ├── app/                 # App Router directory
│   │   ├── layout.tsx       # Root layout
│   │   ├── page.tsx         # Home page
│   │   ├── admin/           # Admin routes
│   │   │   ├── page.tsx     # Admin dashboard
│   │   │   └── documents/   # Document management
│   │   ├── calculate/       # Tax calculation routes
│   │   │   ├── page.tsx     # Tax calculation form
│   │   │   └── results/     # Results pages
│   │   ├── chat/            # Chat interface
│   │   │   └── page.tsx     # Chat page
│   │   └── api/             # API routes
│   │       ├── documents/   # Document endpoints
│   │       ├── calculate/   # Calculation endpoints
│   │       └── forms/       # Form schema endpoints
│   ├── components/          # React components
│   ├── lib/                 # Utility functions and configurations
│   ├── styles/              # CSS and styling
│   └── types/               # TypeScript definitions
├── backend/                 # Ballerina services
│   ├── libs/               # Java library dependencies (PDFBox, Apache POI)
│   ├── services/           # API services
│   ├── modules/            # Business logic modules
│   ├── config/             # Configuration files
│   └── tests/              # Test files
├── database/               # Database schemas and migrations
├── docs/                   # Documentation
└── deployment/             # Deployment configurations
```

## Development Setup

### Prerequisites

1. **Node.js** (v18 or higher)
2. **Ballerina** (latest version with Java 17+ support)
3. **Java Development Kit (JDK 17 or higher)** - Required for Java interop libraries
4. **Supabase account** (free tier)
5. **Google AI Studio** account for Gemini API (free tier)
6. **Git** for version control
7. **curl** or **wget** - For downloading Java library dependencies

### Environment Setup

1. **Clone the repository:**
```bash
git clone <repository-url>
cd tax-app
```

2. **Install frontend dependencies:**
```bash
cd frontend
npm install
```

3. **Set up Ballerina backend with Java interop libraries:**
```bash
cd backend

# Create libs directory for Java dependencies
mkdir libs

# Download required Java libraries for document processing
# PDFBox for PDF processing
curl -L "https://repo1.maven.org/maven2/org/apache/pdfbox/pdfbox-app/3.0.0/pdfbox-app-3.0.0.jar" -o libs/pdfbox-app-3.0.0.jar

# Apache POI for Office document processing
curl -L "https://repo1.maven.org/maven2/org/apache/poi/poi/5.2.4/poi-5.2.4.jar" -o libs/poi-5.2.4.jar
curl -L "https://repo1.maven.org/maven2/org/apache/poi/poi-ooxml/5.2.4/poi-ooxml-5.2.4.jar" -o libs/poi-ooxml-5.2.4.jar

# Required dependencies
curl -L "https://repo1.maven.org/maven2/commons-logging/commons-logging/1.2/commons-logging-1.2.jar" -o libs/commons-logging-1.2.jar

# Configure Ballerina.toml with Java classpath
echo '[platform.java17]' >> Ballerina.toml
echo 'path = "./libs/pdfbox-app-3.0.0.jar:./libs/poi-5.2.4.jar:./libs/poi-ooxml-5.2.4.jar:./libs/commons-logging-1.2.jar"' >> Ballerina.toml

# Build the project with Java dependencies
bal build
```

4. **Database setup:**
```bash
# No local database needed - using Supabase
# Create project at https://supabase.com
# Get your project URL and anon key
# Enable pgvector extension in SQL editor:
CREATE EXTENSION IF NOT EXISTS vector;

# Run migrations via Supabase dashboard or CLI
```

5. **Environment configuration:**
Create `.env` files in both frontend and backend directories:

**Frontend (.env.local):**
```
NEXT_PUBLIC_SUPABASE_URL=your_supabase_url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_supabase_anon_key
```

**Backend (.env):**
```
SUPABASE_URL=your_supabase_url
SUPABASE_SERVICE_KEY=your_supabase_service_key
GEMINI_API_KEY=your_gemini_api_key
```

## Core Components Development

### 1. Document Upload and Processing Service

**Backend (Ballerina):**
```ballerina
// Document upload endpoint using Supabase Storage
service /api/documents on new http:Listener(8080) {
    resource function post upload(http:Caller caller, http:Request req) returns error? {
        // Handle file upload to Supabase Storage
        // Trigger document processing pipeline
        // Return processing status
    }
    
    resource function post process/[string documentId](http:Caller caller, http:Request req) returns error? {
        // Parse document text using text_extractor module
        // Perform intelligent chunking with overlap strategy
        // Process each chunk through Gemini LLM in parallel
        // Extract and validate tax rules from chunks
        // Store structured rules with chunk references in Supabase
        // Generate per-chunk semantic embeddings with pgvector
        // Aggregate and validate cross-chunk rule consistency
    }
}
```

**Enhanced Processing Pipeline with Java Interop Integration:**

1. **File validation and storage** (Supabase Storage)
2. **Advanced text extraction** (Java PDFBox/Apache POI for professional document parsing)
3. **Intelligent chunking** (Semantic segmentation with context overlap)
4. **Parallel chunk processing** (Multiple Gemini API calls)
5. **LLM-based rule extraction** (Per-chunk rule identification)
6. **Data structure validation** (Cross-chunk consistency checks)
7. **Supabase database persistence** (With chunk metadata and references)
8. **Per-chunk embedding generation** (pgvector for semantic search)
9. **Quality assurance** (Rule validation and error handling)

### 1.1. Document Chunking Implementation

**Chunking Strategy for Sri Lankan Tax Documents:**

```ballerina
// text_extractor.bal - Intelligent chunking implementation
import ballerina/log;
import ballerina/regex;

type ChunkConfig record {
    int maxTokens = 1500;
    int minTokens = 500;
    int overlapWords = 200;
    string chunkType = "semantic"; // "semantic", "fixed", "hybrid"
};

type DocumentChunk record {
    string id;
    int sequence;
    string text;
    int startPosition;
    int endPosition;
    string chunkType; // "header", "content", "table", "formula"
    int tokenCount;
    string[] contextKeywords;
    decimal confidence;
};

// Main chunking function for tax documents
function chunkTaxDocument(string documentText, string documentId) returns DocumentChunk[]|error {
    ChunkConfig config = {maxTokens: 1500, overlapWords: 200};
    
    // Step 1: Identify document structure (headers, sections, tables)
    DocumentStructure structure = check analyzeDocumentStructure(documentText);
    
    // Step 2: Apply semantic chunking based on tax document patterns
    DocumentChunk[] chunks = check performSemanticChunking(documentText, structure, config);
    
    // Step 3: Validate chunk quality and apply overlap strategy
    DocumentChunk[] validatedChunks = check validateAndOverlapChunks(chunks, config);
    
    // Step 4: Generate chunk metadata and store in database
    check storeChunkMetadata(validatedChunks, documentId);
    
    return validatedChunks;
}

// Semantic chunking specifically designed for Sri Lankan tax documents
function performSemanticChunking(string text, DocumentStructure structure, ChunkConfig config) 
    returns DocumentChunk[]|error {
    
    DocumentChunk[] chunks = [];
    
    // Identify tax-specific patterns
    string[] patterns = [
        "Income Tax", "VAT", "PAYE", "Withholding Tax", "NBT", "SSCL",
        "Tax Brackets", "Deductions", "Exemptions", "Rates", "Thresholds"
    ];
    
    // Split by major sections while preserving complete tax rules
    foreach var section in structure.sections {
        if (section.text.length() > config.maxTokens * 4) {
            // Large section - split by subsections or paragraphs
            DocumentChunk[] sectionChunks = check splitLargeSection(section, config);
            chunks.push(...sectionChunks);
        } else {
            // Section fits in single chunk
            chunks.push(createChunkFromSection(section));
        }
    }
    
    return chunks;
}

// Overlap strategy to maintain context between chunks
function validateAndOverlapChunks(DocumentChunk[] chunks, ChunkConfig config) 
    returns DocumentChunk[]|error {
    
    DocumentChunk[] processedChunks = [];
    
    foreach int i in 0..<chunks.length() {
        DocumentChunk chunk = chunks[i];
        
        // Add overlap from previous chunk
        if (i > 0) {
            string previousOverlap = extractOverlapText(chunks[i-1], config.overlapWords);
            chunk.text = previousOverlap + "\n\n" + chunk.text;
        }
        
        // Add overlap for next chunk
        if (i < chunks.length() - 1) {
            string nextOverlap = extractOverlapText(chunk, config.overlapWords);
            // Next chunk will include this overlap
        }
        
        processedChunks.push(chunk);
    }
    
    return processedChunks;
}
```

**Chunk Processing Pipeline:**

```ballerina
// Parallel chunk processing with Gemini API
function processChunksInParallel(DocumentChunk[] chunks, string documentId) returns error? {
    
    // Process chunks in batches to respect API rate limits
    int batchSize = 3; // Process 3 chunks simultaneously
    
    foreach int batchStart in 0..<chunks.length() by batchSize {
        DocumentChunk[] batch = chunks.slice(batchStart, batchStart + batchSize);
        
        // Create parallel workers for each chunk in batch
        worker[] workers = [];
        
        foreach var chunk in batch {
            worker chunkWorker = start processChunkWithLLM(chunk, documentId);
            workers.push(chunkWorker);
        }
        
        // Wait for all workers to complete
        foreach var worker in workers {
            check wait worker;
        }
        
        // Small delay between batches for API rate limiting
        check waitForSeconds(2);
    }
}

function processChunkWithLLM(DocumentChunk chunk, string documentId) returns error? {
    log:printInfo("Processing chunk " + chunk.sequence.toString() + " for document " + documentId);
    
    try {
        // Call Gemini API for rule extraction
        TaxRule[] extractedRules = check extractRulesFromChunk(chunk);
        
        // Generate embeddings for the chunk
        float[] embedding = check generateChunkEmbedding(chunk.text);
        
        // Store rules with chunk references
        foreach var rule in extractedRules {
            rule.chunkId = chunk.id;
            rule.chunkSequence = chunk.sequence;
            rule.embedding = embedding;
            check storeRuleInSupabase(rule);
        }
        
        // Update chunk processing status
        check updateChunkStatus(chunk.id, "completed", extractedRules.length());
        
    } on fail error e {
        log:printError("Failed to process chunk " + chunk.id + ": " + e.message());
        check updateChunkStatus(chunk.id, "failed", 0, e.message());
    }
}
```

### 1.2. Java Interop Integration for Enhanced Document Processing

**Implementation of Professional PDF/Office Document Processing:**

The system leverages Ballerina's Java interoperability to integrate industry-standard document processing libraries for superior text extraction capabilities.

#### Java Library Integration Setup

**Required Dependencies:**
- **Apache PDFBox 3.0.0** - Professional PDF text extraction, layout preservation, table detection
- **Apache POI 5.2.4** - Microsoft Office document processing (Word, Excel, PowerPoint)
- **Commons Logging 1.2** - Logging framework dependency

#### Enhanced PDF Processing with Java Interop

```ballerina
// pdf_parser.bal - Enhanced with Java PDFBox integration
import ballerina/jballerina.java;
import ballerina/log;

// Java interop functions for PDFBox integration
function extractTextWithPDFBox(byte[] pdfContent) returns string|error = @java:Method {
    'class: "org.apache.pdfbox.pdmodel.PDDocument",
    name: "load"
} external;

function extractLayoutPreservingText(byte[] pdfContent) returns DocumentExtractionResult|error {
    log:printInfo("Using Java PDFBox for professional PDF extraction");
    
    // Use Java interop for advanced PDF processing
    string extractedText = check extractTextWithPDFBox(pdfContent);
    
    // Additional processing with PDFBox capabilities
    TableData[] tables = check extractTablesWithPDFBox(pdfContent);
    DocumentStructure structure = check parseDocumentStructure(pdfContent);
    
    return {
        extractedText: extractedText,
        structure: structure,
        tables: tables,
        totalPages: check getPageCount(pdfContent),
        sections: check extractSections(extractedText),
        images: check extractImages(pdfContent),
        metadata: check extractMetadata(pdfContent)
    };
}

// Enhanced table extraction using PDFBox
function extractTablesWithPDFBox(byte[] pdfContent) returns TableData[]|error = @java:Method {
    'class: "org.apache.pdfbox.text.PDFTextStripperByArea"
} external;

// Layout-aware text extraction preserving document structure
function parseDocumentStructure(byte[] pdfContent) returns DocumentStructure|error = @java:Method {
    'class: "org.apache.pdfbox.pdmodel.PDDocument"
} external;
```

#### Office Document Processing with Apache POI

```ballerina
// word_processor.bal - Enhanced with Apache POI integration
import ballerina/jballerina.java;

// Java interop for Word document processing
function extractTextFromWord(byte[] wordContent) returns DocumentExtractionResult|error = @java:Method {
    'class: "org.apache.poi.xwpf.usermodel.XWPFDocument",
    name: "getText"
} external;

// Excel spreadsheet processing for tax tables
function extractTextFromExcel(byte[] excelContent) returns DocumentExtractionResult|error = @java:Method {
    'class: "org.apache.poi.xssf.usermodel.XSSFWorkbook"
} external;

// PowerPoint presentation processing
function extractTextFromPowerPoint(byte[] pptContent) returns DocumentExtractionResult|error = @java:Method {
    'class: "org.apache.poi.xslf.usermodel.XMLSlideShow"
} external;
```

#### Benefits of Java Interop Approach

**1. Professional Document Processing:**
- Industry-standard libraries with proven reliability
- Advanced layout preservation and structure detection
- Support for complex PDF features (forms, annotations, embedded content)
- Native handling of password-protected documents

**2. Enhanced Tax Document Analysis:**
- Accurate extraction of tax tables and bracket information
- Preservation of mathematical formulas and calculations
- Detection of form fields and structured data
- Support for scanned documents with OCR capabilities

**3. Comprehensive Format Support:**
- PDF documents (all versions, including complex layouts)
- Microsoft Word documents (.docx, .doc)
- Excel spreadsheets (.xlsx, .xls) for tax tables
- PowerPoint presentations (.pptx, .ppt)

**4. Error Handling and Resilience:**
- Robust handling of corrupted or malformed documents
- Comprehensive error reporting and logging
- Memory-efficient processing of large documents

**5. Integration Architecture:**
```
┌─────────────────────────────────────────────────────────────────┐
│                    Ballerina Service Layer                      │
├─────────────────────────────────────────────────────────────────┤
│ document_service.bal │ pdf_parser.bal │ word_processor.bal     │
└─────────────┬───────────────────────────────────────────────────┘
              │ Java Interop Calls
┌─────────────▼───────────────────────────────────────────────────┐
│                      Java Library Layer                         │
├─────────────────────────────────────────────────────────────────┤
│ Apache PDFBox        │ Apache POI       │ Commons Logging       │
│ - PDF Processing     │ - Office Docs    │ - Error Handling      │
│ - Layout Analysis    │ - Table Extract  │ - Performance Monitor │
└─────────────────────────────────────────────────────────────────┘
```

### 2. Tax Rule Management

**Database Schema (Supabase/PostgreSQL with pgvector):**
```sql
-- Enable vector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Document chunks table for intelligent document segmentation
CREATE TABLE document_chunks (
    id SERIAL PRIMARY KEY,
    document_id INTEGER REFERENCES documents(id) ON DELETE CASCADE,
    chunk_sequence INTEGER NOT NULL,
    start_position INTEGER,
    end_position INTEGER,
    chunk_text TEXT NOT NULL,
    chunk_size INTEGER,
    chunk_type VARCHAR(50) DEFAULT 'content', -- 'content', 'table', 'header', 'formula'
    overlap_with_previous INTEGER DEFAULT 0,
    overlap_with_next INTEGER DEFAULT 0,
    processing_status VARCHAR(50) DEFAULT 'pending', -- 'pending', 'processing', 'completed', 'failed'
    gemini_tokens_used INTEGER,
    error_message TEXT,
    context_keywords TEXT[], -- Tax-related keywords found in chunk
    confidence_score DECIMAL(3,2), -- Processing confidence 0.00-1.00
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    processed_at TIMESTAMP,
    
    -- Ensure unique sequence per document
    UNIQUE(document_id, chunk_sequence)
);

-- Enhanced tax rules table with chunk tracking
CREATE TABLE tax_rules (
    id SERIAL PRIMARY KEY,
    rule_type VARCHAR(50) NOT NULL, -- 'income_tax', 'vat', 'paye', etc.
    rule_category VARCHAR(100),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    rule_data JSONB NOT NULL, -- Structured rule definition
    embedding vector(768), -- Gemini embeddings per chunk
    effective_date DATE NOT NULL,
    expiry_date DATE,
    document_source_id INTEGER REFERENCES documents(id),
    chunk_id INTEGER REFERENCES document_chunks(id), -- Source chunk reference
    chunk_sequence INTEGER, -- Position within document
    chunk_confidence DECIMAL(3,2), -- Extraction confidence
    extraction_context TEXT, -- Surrounding text context
    cross_chunk_refs INTEGER[], -- References to related chunks
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Chunk processing analytics for monitoring
CREATE TABLE chunk_processing_stats (
    id SERIAL PRIMARY KEY,
    chunk_id INTEGER REFERENCES document_chunks(id),
    processing_start_time TIMESTAMP,
    processing_end_time TIMESTAMP,
    gemini_api_calls INTEGER DEFAULT 0,
    rules_extracted INTEGER DEFAULT 0,
    processing_errors INTEGER DEFAULT 0,
    quality_score DECIMAL(3,2), -- Overall chunk processing quality
    retry_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Enable Row Level Security
ALTER TABLE tax_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE document_chunks ENABLE ROW LEVEL SECURITY;
ALTER TABLE chunk_processing_stats ENABLE ROW LEVEL SECURITY;

-- Tax brackets table
CREATE TABLE tax_brackets (
    id SERIAL PRIMARY KEY,
    rule_id INTEGER REFERENCES tax_rules(id),
    min_income DECIMAL(15,2),
    max_income DECIMAL(15,2),
    rate DECIMAL(5,4) NOT NULL,
    fixed_amount DECIMAL(15,2) DEFAULT 0,
    bracket_order INTEGER
);

-- Form schemas table
CREATE TABLE form_schemas (
    id SERIAL PRIMARY KEY,
    schema_type VARCHAR(50) NOT NULL,
    version INTEGER NOT NULL,
    schema_data JSONB NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Enable RLS for form schemas
ALTER TABLE form_schemas ENABLE ROW LEVEL SECURITY;

-- Comprehensive indexing strategy for chunking and vector search
-- Vector similarity search index
CREATE INDEX ON tax_rules USING ivfflat (embedding vector_cosine_ops)
WITH (lists = 100);

-- Chunk-specific indexes for efficient querying
CREATE INDEX idx_chunks_document_sequence ON document_chunks(document_id, chunk_sequence);
CREATE INDEX idx_chunks_processing_status ON document_chunks(processing_status);
CREATE INDEX idx_chunks_type ON document_chunks(chunk_type);
CREATE INDEX idx_chunks_keywords ON document_chunks USING GIN(context_keywords);

-- Tax rules chunk relationship indexes
CREATE INDEX idx_tax_rules_chunk ON tax_rules(chunk_id);
CREATE INDEX idx_tax_rules_chunk_sequence ON tax_rules(chunk_sequence);
CREATE INDEX idx_tax_rules_confidence ON tax_rules(chunk_confidence);

-- Processing analytics indexes
CREATE INDEX idx_chunk_stats_processing_time ON chunk_processing_stats(processing_start_time, processing_end_time);
CREATE INDEX idx_chunk_stats_quality ON chunk_processing_stats(quality_score);

-- Composite indexes for common query patterns
CREATE INDEX idx_rules_type_chunk ON tax_rules(rule_type, chunk_id);
CREATE INDEX idx_chunks_doc_status ON document_chunks(document_id, processing_status);
```

### 3. Dynamic Form Generation

**Schema Generation Service:**
```ballerina
import ballerina/http;
import supabase/supabase;

service /api/forms on new http:Listener(8080) {
    resource function get schema/[string taxType](http:Caller caller, http:Request req) returns json|error {
        // Connect to Supabase
        // Retrieve latest tax rules for specified type
        // Generate JSON Schema based on current rules
        // Include validation rules and conditional logic
        // Return schema for frontend form rendering
    }
}
```

**Frontend Form Component (App Router):**
```tsx
"use client";
import { useState, useEffect } from "react";
import Form from "@rjsf/core";
import validator from "@rjsf/validator-ajv8";

const TaxCalculationForm: React.FC = () => {
  const [schema, setSchema] = useState(null);
  const [formData, setFormData] = useState({});

  useEffect(() => {
    // Fetch latest schema from backend
    fetchFormSchema().then(setSchema);
  }, []);

  const handleSubmit = async (data: any) => {
    // Submit form data for tax calculation
    const result = await calculateTax(data.formData);
    // Display results
  };

  return (
    <Form
      schema={schema}
      formData={formData}
      validator={validator}
      onSubmit={handleSubmit}
      onChange={({ formData }) => setFormData(formData)}
    />
  );
};
```

### 4. Tax Calculation Engine

**Calculation Service:**
```ballerina
import ballerina/http;
import supabase/supabase;

service /api/calculate on new http:Listener(8080) {
    resource function post tax(http:Caller caller, http:Request req) returns json|error {
        json userInput = check req.getJsonPayload();
        
        // Connect to Supabase and retrieve applicable tax rules
        // Apply income tax calculations
        // Calculate VAT if applicable
        // Apply deductions and exemptions
        // Generate detailed breakdown
        // Store calculation in Supabase for history
        // Return calculation results with explanations
    }
}
```

**Calculation Logic Examples:**

1. **Income Tax Calculation:**
```ballerina
function calculateIncomeTax(decimal income, TaxBracket[] brackets) returns TaxCalculation {
    decimal totalTax = 0;
    decimal remainingIncome = income;
    TaxBracketCalculation[] bracketCalculations = [];
    
    foreach TaxBracket bracket in brackets {
        if (remainingIncome <= 0) {
            break;
        }
        
        decimal taxableInThisBracket = math:min(remainingIncome, bracket.maxIncome - bracket.minIncome);
        decimal taxForBracket = taxableInThisBracket * bracket.rate + bracket.fixedAmount;
        
        totalTax += taxForBracket;
        remainingIncome -= taxableInThisBracket;
        
        bracketCalculations.push({
            bracket: bracket,
            taxableAmount: taxableInThisBracket,
            taxAmount: taxForBracket
        });
    }
    
    return {
        totalTax: totalTax,
        breakdowns: bracketCalculations
    };
}
```

### 5. Chat Interface (Optional Enhancement)

**Chat Service:**
```ballerina
import ballerina/http;
import supabase/supabase;

service /api/chat on new http:Listener(8080) {
    resource function post message(http:Caller caller, http:Request req) returns json|error {
        json message = check req.getJsonPayload();
        
        // Process user query
        // Use pgvector similarity search for relevant tax information
        // Call Gemini API for contextual response generation
        // Return chat response with relevant forms/calculations
    }
}
```

## API Endpoints

### Document Management
- `POST /api/documents/upload` - Upload tax documents
- `POST /api/documents/process/{documentId}` - Process uploaded document
- `GET /api/documents/{documentId}/status` - Check processing status

### Form Schema
- `GET /api/forms/schema/{taxType}` - Get form schema for tax type
- `GET /api/forms/schema/latest` - Get latest combined schema

### Tax Calculation
- `POST /api/calculate/tax` - Calculate tax based on user input
- `POST /api/calculate/estimate` - Get tax estimate
- `GET /api/calculate/brackets/{taxType}` - Get current tax brackets

### Administration
- `GET /api/admin/rules` - List all tax rules
- `PUT /api/admin/rules/{ruleId}` - Update tax rule
- `DELETE /api/admin/rules/{ruleId}` - Delete tax rule
- `GET /api/admin/documents` - List processed documents

## Frontend Development

### Key Components

1. **DocumentUpload.tsx** - Admin document upload interface
2. **TaxCalculationForm.tsx** - Dynamic tax calculation form  
3. **ResultsDisplay.tsx** - Tax calculation results and breakdown
4. **ChatInterface.tsx** - Optional chat-based interaction
5. **AdminDashboard.tsx** - Administrative interface for rule management

### App Router Structure
```
app/
├── layout.tsx              # Root layout with providers
├── page.tsx                # Landing/home page
├── loading.tsx             # Global loading UI
├── error.tsx               # Global error UI
├── not-found.tsx           # 404 page
├── admin/
│   ├── layout.tsx          # Admin layout
│   ├── page.tsx            # Admin dashboard
│   ├── documents/
│   │   ├── page.tsx        # Document management
│   │   └── upload/
│   │       └── page.tsx    # Document upload
│   └── rules/
│       ├── page.tsx        # Rule management
│       └── [id]/
│           └── page.tsx    # Edit specific rule
├── calculate/
│   ├── layout.tsx          # Calculation layout
│   ├── page.tsx            # Tax calculation form
│   ├── loading.tsx         # Calculation loading
│   └── results/
│       └── page.tsx        # Results display
├── chat/
│   ├── page.tsx            # Chat interface
│   └── loading.tsx         # Chat loading
└── api/                    # API routes
    ├── documents/
    │   ├── route.ts         # POST /api/documents
    │   ├── upload/
    │   │   └── route.ts     # POST /api/documents/upload
    │   └── [id]/
    │       ├── route.ts     # GET /api/documents/[id]
    │       └── process/
    │           └── route.ts # POST /api/documents/[id]/process
    ├── calculate/
    │   ├── route.ts         # POST /api/calculate
    │   └── brackets/
    │       └── [type]/
    │           └── route.ts # GET /api/calculate/brackets/[type]
    └── forms/
        └── schema/
            ├── route.ts     # GET /api/forms/schema
            └── [type]/
                └── route.ts # GET /api/forms/schema/[type]
```

### State Management
Use React Context, Zustand, or Redux Toolkit for managing:
- User session and authentication
- Form data and validation states
- Tax calculation results
- Document processing status

**Example with App Router Context:**
```tsx
// app/providers.tsx
"use client";
import { createContext, useContext, useReducer } from 'react';

const AppContext = createContext();

export function AppProviders({ children }: { children: React.ReactNode }) {
  const [state, dispatch] = useReducer(appReducer, initialState);
  
  return (
    <AppContext.Provider value={{ state, dispatch }}>
      {children}
    </AppContext.Provider>
  );
}

// app/layout.tsx
import { AppProviders } from './providers';

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <AppProviders>
          {children}
        </AppProviders>
      </body>
    </html>
  );
}
```

### Responsive Design
- Mobile-first approach
- Support for tablets and desktops
- Accessibility compliance (WCAG 2.1)
- Multi-language support

### App Router Features
- **Server Components** - Default server rendering for better performance
- **Client Components** - Interactive components with "use client" directive
- **Streaming** - Progressive rendering with loading.tsx
- **Error Boundaries** - Automatic error handling with error.tsx
- **Nested Layouts** - Shared UI across route groups
- **Route Groups** - Organize routes without affecting URL structure
- **Parallel Routes** - Display multiple pages simultaneously
- **Intercepting Routes** - Override routes in certain contexts

## Database Design

### Core Tables
1. **tax_rules** - Store extracted tax rules with vector embeddings
2. **tax_brackets** - Tax bracket definitions
3. **form_schemas** - JSON schemas for dynamic forms
4. **documents** - Metadata for uploaded documents (Supabase Storage refs)
5. **calculations** - Historical tax calculations
6. **users** - User management with Supabase Auth

### Database Features
- Row Level Security (RLS) for data protection
- Real-time subscriptions for live updates
- Built-in authentication and authorization
- Vector similarity search with pgvector
- Automatic API generation

## Vector Database Integration

### Embedding Generation with Gemini
```ballerina
import ballerina/http;

function generateEmbeddings(string text) returns float[]|error {
    // Call Gemini embeddings API
    http:Client geminiClient = check new("https://generativelanguage.googleapis.com");
    
    json payload = {
        "content": {
            "parts": [{"text": text}]
        }
    };
    
    http:Response response = check geminiClient->post("/v1/models/embedding-001:embedText", payload);
    // Process response and return vector representation
    return []; // Return actual embedding vector
}
```

### Semantic Search with pgvector
```ballerina
function semanticSearch(string query, int limit = 10) returns SearchResult[]|error {
    // Generate query embedding using Gemini
    float[] queryVector = check generateEmbeddings(query);
    
    // Search Supabase using pgvector similarity with chunk context
    // SELECT tr.*, dc.chunk_text, dc.chunk_sequence,
    //        tr.embedding <-> $1 as distance 
    // FROM tax_rules tr
    // JOIN document_chunks dc ON tr.chunk_id = dc.id
    // WHERE tr.effective_date <= CURRENT_DATE
    // ORDER BY distance 
    // LIMIT $2
    
    // Return ranked results with chunk context and relevance scores
    return [];
}

// Enhanced search with chunk-aware context
function chunkAwareSemanticSearch(string query, string? taxType = (), int limit = 10) 
    returns ChunkSearchResult[]|error {
    
    float[] queryVector = check generateEmbeddings(query);
    
    // Multi-level search: document level + chunk level
    // 1. Find relevant chunks first
    ChunkSearchResult[] chunkResults = check searchRelevantChunks(queryVector, taxType, limit * 2);
    
    // 2. Include neighboring chunks for context
    ChunkSearchResult[] enrichedResults = check includeChunkContext(chunkResults, limit);
    
    return enrichedResults;
}
```

## Document Chunking Strategy & Implementation

### Chunking Architecture for Sri Lankan Tax Documents

**Strategic Approach:**
Sri Lankan tax documents follow specific patterns that require intelligent chunking to preserve regulatory context and ensure accurate rule extraction.

#### Document Types and Chunking Strategies

**1. Income Tax Documents:**
- **Structure**: Chapters → Sections → Subsections → Tax brackets
- **Chunking**: Preserve complete tax bracket tables within chunks
- **Overlap**: Include previous bracket for threshold context

**2. VAT Regulations:**
- **Structure**: Rate schedules → Exemption lists → Calculation methods
- **Chunking**: Keep rate tables intact, separate exemption categories
- **Overlap**: Include rate context for exemption decisions

**3. PAYE Guidelines:**
- **Structure**: Calculation formulas → Deduction tables → Filing requirements
- **Chunking**: Preserve mathematical formulas and their explanations
- **Overlap**: Include formula context for deduction calculations

#### Implementation Guidelines

**Chunk Size Optimization:**
```ballerina
// Optimal chunk sizes for different content types
const map<int> CHUNK_SIZES = {
    "tax_brackets": 800,      // Preserve complete bracket tables
    "exemptions": 600,        // List-based content
    "formulas": 1000,         // Mathematical content with explanations
    "procedures": 1200,       // Step-by-step processes
    "definitions": 400        // Terminology sections
};

// Context overlap based on content complexity
const map<int> OVERLAP_SIZES = {
    "tax_brackets": 150,      // Previous bracket context
    "exemptions": 100,        // Category context
    "formulas": 200,          // Formula derivation context
    "procedures": 180,        // Process flow context
    "definitions": 80         // Term relationship context
};
```

**Error Handling and Recovery:**
```ballerina
function robustChunkProcessing(DocumentChunk[] chunks, string documentId) returns ProcessingResult|error {
    ProcessingResult result = {successCount: 0, failureCount: 0, retryQueue: []};
    
    foreach var chunk in chunks {
        try {
            check processChunkWithRetry(chunk, documentId, maxRetries = 3);
            result.successCount += 1;
        } on fail error e {
            log:printError("Chunk processing failed after retries: " + chunk.id);
            result.failureCount += 1;
            result.retryQueue.push(chunk);
            
            // Mark chunk for manual review
            check markChunkForReview(chunk.id, e.message());
        }
    }
    
    return result;
}

function processChunkWithRetry(DocumentChunk chunk, string documentId, int maxRetries) returns error? {
    int attempts = 0;
    
    while (attempts < maxRetries) {
        try {
            return check processChunkWithLLM(chunk, documentId);
        } on fail error e {
            attempts += 1;
            if (attempts >= maxRetries) {
                return e;
            }
            
            // Exponential backoff for API rate limiting
            int delay = attempts * attempts * 2;
            check waitForSeconds(delay);
        }
    }
}
```

**Quality Assurance for Chunk Processing:**
```ballerina
function validateChunkQuality(DocumentChunk chunk, TaxRule[] extractedRules) returns QualityScore {
    QualityScore score = {overall: 0.0, factors: {}};
    
    // Factor 1: Rule completeness (0.0 - 1.0)
    decimal completenessScore = calculateRuleCompleteness(extractedRules);
    score.factors["completeness"] = completenessScore;
    
    // Factor 2: Context preservation (0.0 - 1.0)
    decimal contextScore = calculateContextPreservation(chunk, extractedRules);
    score.factors["context"] = contextScore;
    
    // Factor 3: Cross-chunk consistency (0.0 - 1.0)
    decimal consistencyScore = calculateCrossChunkConsistency(chunk, extractedRules);
    score.factors["consistency"] = consistencyScore;
    
    // Factor 4: Tax-specific keyword coverage (0.0 - 1.0)
    decimal keywordScore = calculateTaxKeywordCoverage(chunk.text, extractedRules);
    score.factors["keywords"] = keywordScore;
    
    // Weighted overall score
    score.overall = (completenessScore * 0.3) + (contextScore * 0.25) + 
                   (consistencyScore * 0.25) + (keywordScore * 0.2);
    
    return score;
}
```

**Performance Monitoring for Chunking:**
```ballerina
function monitorChunkProcessingPerformance(string documentId) returns PerformanceMetrics|error {
    // Query chunk processing statistics
    map<anydata> params = {"document_id": documentId};
    
    // Get processing metrics from database
    json metricsQuery = {
        "query": `
            SELECT 
                COUNT(*) as total_chunks,
                AVG(EXTRACT(EPOCH FROM (processed_at - created_at))) as avg_processing_time,
                SUM(gemini_tokens_used) as total_tokens,
                SUM(rules_extracted) as total_rules,
                AVG(quality_score) as avg_quality_score,
                COUNT(CASE WHEN processing_status = 'failed' THEN 1 END) as failed_chunks
            FROM document_chunks dc
            LEFT JOIN chunk_processing_stats cps ON dc.id = cps.chunk_id
            WHERE dc.document_id = $1
        `,
        "params": [documentId]
    };
    
    json result = check supabaseClient->query(metricsQuery);
    return mapToPerformanceMetrics(result);
}
```

## Testing Strategy

### Unit Tests

**Core Functionality:**
- Test individual calculation functions
- Validate form schema generation
- Test document processing pipeline

**Chunking-Specific Tests:**
```ballerina
@test:Config {}
function testSemanticChunking() returns error? {
    // Test tax document chunking
    string testDocument = loadTestTaxDocument("income_tax_sample.txt");
    DocumentChunk[] chunks = check chunkTaxDocument(testDocument, "test-doc-1");
    
    // Validate chunk count and sizes
    test:assertTrue(chunks.length() > 0, "Should generate at least one chunk");
    test:assertTrue(chunks.length() <= 20, "Should not generate excessive chunks");
    
    // Validate chunk overlap
    foreach int i in 1..<chunks.length() {
        string previousEnd = getLastWords(chunks[i-1].text, 50);
        string currentStart = getFirstWords(chunks[i].text, 50);
        test:assertTrue(hasOverlap(previousEnd, currentStart), "Chunks should have overlap");
    }
}

@test:Config {}
function testChunkProcessingWithGemini() returns error? {
    DocumentChunk testChunk = createTestChunk("income_tax_brackets");
    TaxRule[] rules = check extractRulesFromChunk(testChunk);
    
    test:assertTrue(rules.length() > 0, "Should extract at least one tax rule");
    test:assertTrue(rules[0].ruleType == "income_tax", "Should identify correct rule type");
}

@test:Config {}
function testChunkQualityValidation() returns error? {
    DocumentChunk chunk = createTestChunk("vat_rates");
    TaxRule[] rules = check extractRulesFromChunk(chunk);
    QualityScore score = validateChunkQuality(chunk, rules);
    
    test:assertTrue(score.overall >= 0.7, "Quality score should be acceptable");
    test:assertTrue(score.factors.hasKey("completeness"), "Should have completeness factor");
}

@test:Config {}
function testParallelChunkProcessing() returns error? {
    DocumentChunk[] chunks = createTestChunks(5);
    check processChunksInParallel(chunks, "test-doc-parallel");
    
    // Verify all chunks were processed
    foreach var chunk in chunks {
        string status = check getChunkProcessingStatus(chunk.id);
        test:assertTrue(status == "completed" || status == "failed", 
                       "Chunk should have final status");
    }
}

@test:Config {}
function testChunkErrorRecovery() returns error? {
    DocumentChunk failingChunk = createFailingTestChunk();
    
    try {
        check processChunkWithRetry(failingChunk, "test-doc-error", 2);
        test:assertFail("Should have failed after retries");
    } on fail error e {
        // Expected failure - verify retry logic worked
        int retryCount = check getChunkRetryCount(failingChunk.id);
        test:assertEquals(retryCount, 2, "Should have attempted 2 retries");
    }
}
```

### Integration Tests

**Core Integration:**
- End-to-end API testing
- Database operation testing
- File upload and processing workflows

**Chunking Integration Tests:**
```ballerina
@test:Config {}
function testEndToEndDocumentProcessing() returns error? {
    // Upload test document
    string documentId = check uploadTestDocument("sri_lanka_income_tax_2024.pdf");
    
    // Trigger processing
    check processDocument(documentId);
    
    // Wait for processing completion
    check waitForProcessingCompletion(documentId, timeoutSeconds = 300);
    
    // Validate chunks were created
    DocumentChunk[] chunks = check getDocumentChunks(documentId);
    test:assertTrue(chunks.length() > 0, "Should create document chunks");
    
    // Validate rules were extracted from chunks
    TaxRule[] rules = check getTaxRulesForDocument(documentId);
    test:assertTrue(rules.length() > 0, "Should extract tax rules from chunks");
    
    // Validate chunk-to-rule mapping
    foreach var rule in rules {
        test:assertTrue(rule.chunkId != (), "Rule should reference source chunk");
        DocumentChunk sourceChunk = check getChunkById(rule.chunkId);
        test:assertTrue(sourceChunk.processingStatus == "completed", 
                       "Source chunk should be processed");
    }
}

@test:Config {}
function testVectorSearchWithChunks() returns error? {
    // Setup test data with multiple chunks
    string documentId = check setupTestDocumentWithChunks();
    
    // Perform semantic search
    SearchResult[] results = check chunkAwareSemanticSearch("income tax brackets");
    
    test:assertTrue(results.length() > 0, "Should find relevant chunks");
    test:assertTrue(results[0].distance < 0.3, "Should have high relevance");
    
    // Verify chunk context is included
    test:assertTrue(results[0].chunkContext != (), "Should include chunk context");
}

@test:Config {}
function testChunkProcessingPerformance() returns error? {
    string documentId = check uploadLargeTestDocument();
    
    time:Utc startTime = time:utcNow();
    check processDocument(documentId);
    time:Utc endTime = time:utcNow();
    
    decimal processingTime = time:diffSeconds(endTime, startTime);
    test:assertTrue(processingTime < 600.0, "Should process within 10 minutes");
    
    // Validate performance metrics
    PerformanceMetrics metrics = check monitorChunkProcessingPerformance(documentId);
    test:assertTrue(metrics.avgProcessingTime < 60.0, "Average chunk time < 60 seconds");
    test:assertTrue(metrics.totalTokens < 100000, "Should stay within token limits");
}
```

### UI Tests
- Component rendering tests
- Form validation testing
- User interaction flows

## Local Development

### Running the Application Locally

1. **Start Supabase project:**
```bash
# No local database needed
# Access your Supabase dashboard at https://supabase.com
# Your database is automatically running in the cloud
```

2. **Start the Ballerina backend:**
```bash
cd backend
bal run
# Backend will run on http://localhost:8080
```

3. **Start the frontend development server:**
```bash
cd frontend
npm run dev
# Frontend will run on http://localhost:3000
```

4. **Access the application:**
   - Frontend: http://localhost:3000
   - Backend API: http://localhost:8080
   - Supabase Dashboard: https://supabase.com/dashboard
   - Database: Managed by Supabase (no local access needed)

### Development Workflow
1. Make changes to your code
2. Both frontend and backend support hot reloading
3. Test your changes locally
4. Run tests before committing changes

## Local Security Considerations

### Development Security
- Use environment variables for API keys and secrets
- Never commit sensitive data to version control
- Use HTTPS for external API calls even in development
- Validate all inputs to prevent injection attacks

### Local Environment Variables
Create `.env.local` files for:
- Supabase project URL and keys
- Gemini API keys (free tier)
- Supabase Storage bucket configuration
- Local development settings

## Local Development Monitoring

### Development Debugging
- Use console.log() for frontend debugging
- Use Ballerina's built-in logging for backend
- Use Supabase dashboard for database monitoring
- Monitor Gemini API usage and quotas
- Test Supabase Storage uploads and retrievals
- Validate pgvector similarity searches manually

### Local Testing
- Run unit tests: `npm test` (frontend) and `bal test` (backend)
- Use Postman or similar tools for API testing
- Test database connections with Supabase client
- Validate Gemini API responses and rate limits
- Check Supabase Storage file operations

## Local Development Maintenance

### Code Organization
- Keep components modular and reusable
- Follow consistent naming conventions
- Document complex business logic
- Maintain clean git commit history

### Local Tax Rule Updates
- Test rule changes with sample data
- Validate schema generation after rule updates
- Ensure backward compatibility during development
- Keep test data synchronized with rule changes

## Local Development Optimization

### Frontend Development Tips
- Use React Developer Tools for debugging
- Enable source maps for easier debugging
- Use hot module replacement for faster development
- Keep bundle sizes reasonable for development speed

### Backend Development Tips
- Use Supabase connection pooling for development
- Implement proper error handling for Gemini API calls
- Test with realistic data volumes in Supabase
- Profile expensive vector operations locally

## Local Development Documentation

### Code Documentation
- Comment complex business logic
- Document API endpoints with examples
- Maintain README files for each module
- Keep Supabase schema documentation updated
- Document Gemini API integration patterns
- Note free tier limitations and usage

### Development Notes
- Document known issues and workarounds
- Keep track of configuration changes
- Note dependencies and their purposes
- Maintain a local development changelog

## Development Roadmap

### Core Features to Implement First
1. **Basic Tax Calculation** - Start with simple income tax calculations
2. **Document Upload** - Implement file upload without LLM processing initially
3. **Static Forms** - Create basic forms before making them dynamic
4. **Database CRUD** - Implement basic database operations
5. **API Integration** - Connect frontend to backend APIs

### Advanced Features for Later
1. **LLM Integration** - Add Gemini-powered document processing
2. **Dynamic Form Generation** - Implement schema-based forms with Supabase
3. **Vector Database** - Add pgvector semantic search capabilities
4. **Chat Interface** - Build conversational tax assistance with Gemini
5. **Multi-language Support** - Add Sinhala and Tamil support

### Development Phases
- **Phase 1**: Basic functionality with Supabase and core features
- **Phase 2**: Gemini AI integration and advanced features
- **Phase 3**: Polish, optimization, and additional features

## Local Development Troubleshooting

### Common Development Issues

1. **Database Connection Problems**
   - Check Supabase project status and connectivity
   - Verify API keys and project URL in environment variables
   - Ensure Supabase project is not paused (free tier limitation)
   - Test connection using Supabase client libraries

2. **Frontend Build Errors**
   - Clear node_modules and reinstall: `rm -rf node_modules && npm install`
   - Check for TypeScript errors in the console
   - Verify all imports are correct
   - Restart the development server

3. **Ballerina Backend Issues**
   - Check for compilation errors: `bal build`
   - Verify all dependencies are correctly imported
   - Check port conflicts (default 8080)
   - Review Ballerina logs for runtime errors

3.1. **Java Interop Issues**
   - **Missing Java libraries**: Ensure all JAR files are downloaded in `libs/` directory
   - **Classpath configuration**: Verify `Ballerina.toml` has correct `[platform.java17]` path
   - **Java version compatibility**: Ensure JDK 17+ is installed and accessible
   - **Library version conflicts**: Use exact versions specified (PDFBox 3.0.0, POI 5.2.4)
   - **Memory issues with large documents**: Increase JVM heap size if needed
   - **PDFBox extraction errors**: Check document format and corruption
   - **POI Office document errors**: Verify document compatibility and format support
   - **Java interop compilation errors**: Check external function annotations and signatures

   **Common Java Interop Fixes:**
   ```bash
   # Verify Java installation
   java -version
   
   # Check if JAR files exist
   ls -la backend/libs/
   
   # Rebuild with verbose output
   cd backend
   bal build --debug
   
   # Test Java interop functionality
   bal test modules/document_processor
   ```

4. **API Integration Problems**
   - Verify backend is running and accessible
   - Check CORS configuration for cross-origin requests
   - Validate Gemini API key and quotas
   - Check Supabase RLS policies for data access
   - Use browser network tab to debug HTTP requests

5. **Gemini API Issues**
   - Verify API key is valid and has quota remaining
   - Check rate limiting and retry logic
   - Validate request format for Gemini API
   - Monitor API usage in Google AI Studio console

### Development Debug Tools
- **Frontend**: React Developer Tools, browser console
- **Backend**: Ballerina logs, HTTP client tools (Postman/Insomnia)
- **Database**: Supabase Dashboard, SQL Editor, Table Editor
- **Storage**: Supabase Storage interface
- **Network**: Browser developer tools, network monitoring
- **AI**: Google AI Studio for Gemini API testing

### Quick Fixes
- **Port already in use**: Change port in configuration or kill existing process
- **Module not found**: Check import paths and installed dependencies
- **Supabase schema errors**: Use Supabase Dashboard to fix schema issues
- **Environment variables**: Verify .env files are loaded correctly
- **Gemini API errors**: Check API quotas and request formatting

## Local Development Checklist

### Initial Setup
- [ ] Install Node.js, Ballerina
- [ ] Create Supabase account and project
- [ ] Get Gemini API key from Google AI Studio
- [ ] Clone repository and set up project structure
- [ ] Set up Supabase database schema and enable pgvector
- [ ] Configure environment variables for Supabase and Gemini

### Core Development Tasks
- [ ] Set up Supabase database schema for tax rules with pgvector
- [ ] Create document_chunks table with proper indexing
- [ ] Create Supabase Storage bucket for file uploads
- [ ] Implement basic tax calculation logic
- [ ] Build frontend components for tax forms
- [ ] Connect frontend to Supabase and backend APIs
- [ ] Add basic form validation and error handling

### Document Chunking Implementation Tasks
- [ ] Implement intelligent chunking in text_extractor.bal module
- [ ] Set up semantic chunking for tax document structure
- [ ] Implement overlap strategy for context preservation
- [ ] Create parallel chunk processing with Gemini API
- [ ] Add chunk quality validation and scoring
- [ ] Implement error recovery and retry logic for failed chunks
- [ ] Set up chunk processing analytics and monitoring
- [ ] Create chunk-aware semantic search functionality

### Advanced Development Tasks
- [ ] Integrate Gemini API for document processing with chunking
- [ ] Implement dynamic form generation from chunk-derived schemas
- [ ] Set up pgvector semantic search with per-chunk embeddings
- [ ] Add comprehensive error handling and logging for chunk processing
- [ ] Implement chunk processing performance monitoring
- [ ] Create development documentation for chunking strategy
- [ ] Set up chunk processing queue with Redis for scalability

### Testing and Validation
- [ ] Test chunking algorithms with various document types
- [ ] Validate chunk overlap and context preservation
- [ ] Test parallel chunk processing performance
- [ ] Verify chunk-to-rule mapping accuracy
- [ ] Test chunk processing error recovery mechanisms
- [ ] Test semantic search with chunk-aware queries
- [ ] Validate chunk quality scores and metrics
- [ ] Test all API endpoints with chunked document data
- [ ] Validate tax calculations with chunk-derived rules
- [ ] Test file upload and chunk processing workflow
- [ ] Verify form generation from chunk-processed schemas
- [ ] Check chunk processing with Supabase RLS policies
- [ ] Test error handling for chunk processing edge cases

This comprehensive guide now includes detailed chunking implementation using entirely free technologies, optimized for Sri Lankan tax document processing on your development machine.
