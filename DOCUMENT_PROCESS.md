# Document Processing Implementation Guide

## Overview

This document provides a comprehensive guide for implementing the complete document processing pipeline for the Sri Lankan Tax Calculation Application. The process transforms uploaded government tax documents into structured, searchable data using RAG (Retrieval-Augmented Generation) principles with intelligent chunking and parallel processing.

## Complete Document Processing Pipeline

### Phase 1: Document Upload & Validation ✅ (Implemented)

**Current Implementation**: `document_service.bal` - `/documents/upload`

**Features Implemented:**
- Multipart form validation
- File type validation (.pdf, .doc, .docx)
- File size validation (max 10MB)
- Filename extraction
- Document ID generation
- Metadata creation

**Next Steps:**
- Supabase Storage integration
- Database persistence
- File integrity validation

---

### Phase 2: File Storage & Metadata Persistence

#### 2.1 Supabase Storage Integration

**Implementation Pattern:**
```ballerina
import ballerina/http;
import ballerina/io;

// Supabase Storage Client
type SupabaseStorageClient client object {
    isolated resource function post storage/v1/object/[string bucket]/[string path](
        byte[] fileContent,
        map<string> headers = {}
    ) returns json|error;
    
    isolated resource function get storage/v1/object/[string bucket]/[string path]() 
        returns byte[]|error;
    
    isolated resource function delete storage/v1/object/[string bucket]/[string path]() 
        returns json|error;
};

// File upload to Supabase Storage
function uploadToSupabaseStorage(byte[] fileContent, string storagePath, string contentType) 
    returns json|error {
    
    SupabaseStorageClient storageClient = check new (supabaseUrl + "/storage/v1", {
        auth: {
            token: supabaseServiceKey
        }
    });
    
    map<string> headers = {
        "Content-Type": contentType,
        "x-upsert": "true"
    };
    
    return storageClient->/object/documents/[storagePath].post(fileContent, headers);
}
```

#### 2.2 Database Schema Implementation

**Required Tables:**
```sql
-- Main documents table
CREATE TABLE documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    filename TEXT NOT NULL,
    file_path TEXT NOT NULL,
    content_type TEXT NOT NULL,
    file_size INTEGER NOT NULL,
    upload_date TIMESTAMPTZ DEFAULT NOW(),
    processed BOOLEAN DEFAULT FALSE,
    processing_status TEXT DEFAULT 'uploaded',
    total_chunks INTEGER DEFAULT 0,
    processing_started_at TIMESTAMPTZ,
    processing_completed_at TIMESTAMPTZ,
    error_message TEXT,
    created_by UUID REFERENCES auth.users(id),
    CONSTRAINT valid_status CHECK (processing_status IN ('uploaded', 'processing', 'chunking', 'extracting', 'completed', 'failed'))
);

-- Document chunks table for intelligent chunking
CREATE TABLE document_chunks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id UUID NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    chunk_sequence INTEGER NOT NULL,
    chunk_type TEXT NOT NULL DEFAULT 'semantic', -- 'semantic', 'section', 'table', 'list'
    start_position INTEGER NOT NULL,
    end_position INTEGER NOT NULL,
    chunk_text TEXT NOT NULL,
    chunk_size INTEGER NOT NULL,
    context_before TEXT, -- Previous chunk overlap
    context_after TEXT,  -- Next chunk overlap
    processing_status TEXT DEFAULT 'pending',
    processing_time_ms INTEGER,
    chunk_confidence DECIMAL(3,2), -- 0.00-1.00 confidence score
    context_keywords TEXT[], -- Extracted keywords for filtering
    section_header TEXT, -- Document section this chunk belongs to
    embedding VECTOR(768), -- For semantic search
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT valid_chunk_status CHECK (processing_status IN ('pending', 'processing', 'completed', 'failed')),
    CONSTRAINT unique_document_sequence UNIQUE(document_id, chunk_sequence)
);

-- Tax rules extracted from chunks
CREATE TABLE tax_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id UUID NOT NULL REFERENCES documents(id),
    chunk_id UUID NOT NULL REFERENCES document_chunks(id),
    chunk_sequence INTEGER NOT NULL,
    rule_type TEXT NOT NULL, -- 'income_tax', 'vat', 'paye', 'wht', 'nbt', 'sscl'
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    rule_data JSONB NOT NULL, -- Structured rule data
    effective_date DATE,
    expiry_date DATE,
    source_text TEXT NOT NULL, -- Original text from document
    extraction_confidence DECIMAL(3,2), -- LLM confidence score
    embedding VECTOR(768), -- For semantic search
    validation_status TEXT DEFAULT 'pending', -- 'pending', 'validated', 'rejected'
    validated_by UUID REFERENCES auth.users(id),
    validated_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT valid_rule_type CHECK (rule_type IN ('income_tax', 'vat', 'paye', 'wht', 'nbt', 'sscl')),
    CONSTRAINT valid_validation_status CHECK (validation_status IN ('pending', 'validated', 'rejected'))
);

-- Chunk processing analytics
CREATE TABLE chunk_processing_stats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id UUID NOT NULL REFERENCES documents(id),
    chunk_id UUID NOT NULL REFERENCES document_chunks(id),
    processing_start_time TIMESTAMPTZ NOT NULL,
    processing_end_time TIMESTAMPTZ,
    processing_duration_ms INTEGER,
    llm_tokens_used INTEGER,
    llm_model_used TEXT,
    rules_extracted INTEGER DEFAULT 0,
    quality_score DECIMAL(3,2), -- Processing quality assessment
    error_details JSONB, -- Any errors encountered
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX idx_documents_status ON documents(processing_status);
CREATE INDEX idx_documents_upload_date ON documents(upload_date DESC);
CREATE INDEX idx_chunks_document_sequence ON document_chunks(document_id, chunk_sequence);
CREATE INDEX idx_chunks_processing_status ON document_chunks(processing_status);
CREATE INDEX idx_chunks_type ON document_chunks(chunk_type);
CREATE INDEX idx_chunks_keywords ON document_chunks USING GIN(context_keywords);
CREATE INDEX idx_tax_rules_chunk ON tax_rules(chunk_id);
CREATE INDEX idx_tax_rules_type ON tax_rules(rule_type);
CREATE INDEX idx_tax_rules_date ON tax_rules(effective_date, expiry_date);

-- Vector similarity search indexes
CREATE INDEX ON document_chunks USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);
CREATE INDEX ON tax_rules USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);
```

---

### Phase 3: Text Extraction & Document Analysis with Java Interop

#### 3.1 Java Library Integration Setup

**Java Dependencies Management:**
```bash
# Create libs directory for Java dependencies
mkdir backend/libs

# Download Apache Tika for unified document processing
curl -L "https://repo1.maven.org/maven2/org/apache/tika/tika-app/2.9.1/tika-app-2.9.1.jar" -o backend/libs/tika-app-2.9.1.jar

# Download Tika core and parsers (more modular approach)
curl -L "https://repo1.maven.org/maven2/org/apache/tika/tika-core/2.9.1/tika-core-2.9.1.jar" -o backend/libs/tika-core-2.9.1.jar
curl -L "https://repo1.maven.org/maven2/org/apache/tika/tika-parsers-standard-package/2.9.1/tika-parsers-standard-package-2.9.1.jar" -o backend/libs/tika-parsers-standard-package-2.9.1.jar

# Download required dependencies for Tika
curl -L "https://repo1.maven.org/maven2/commons-logging/commons-logging/1.2/commons-logging-1.2.jar" -o backend/libs/commons-logging-1.2.jar
curl -L "https://repo1.maven.org/maven2/org/apache/commons/commons-compress/1.21/commons-compress-1.21.jar" -o backend/libs/commons-compress-1.21.jar
curl -L "https://repo1.maven.org/maven2/org/slf4j/slf4j-api/1.7.36/slf4j-api-1.7.36.jar" -o backend/libs/slf4j-api-1.7.36.jar
curl -L "https://repo1.maven.org/maven2/org/slf4j/slf4j-simple/1.7.36/slf4j-simple-1.7.36.jar" -o backend/libs/slf4j-simple-1.7.36.jar
```

**Ballerina.toml Configuration:**
```toml
[platform.java17]
path = "./libs/tika-app-2.9.1.jar:./libs/tika-core-2.9.1.jar:./libs/tika-parsers-standard-package-2.9.1.jar:./libs/commons-logging-1.2.jar:./libs/commons-compress-1.21.jar:./libs/slf4j-api-1.7.36.jar:./libs/slf4j-simple-1.7.36.jar"
```

#### 3.2 Enhanced Document Processing with Apache Tika

**Unified Document Processing Implementation:**
```ballerina
import ballerina/jballerina.java;
import ballerina/http;
import ballerina/log;
import ballerina/time;

type DocumentExtractionResult record {
    string extractedText;
    DocumentStructure structure;
    string contentType;
    string[] detectedLanguages;
    TableData[] tables;
    ImageData[] images;
    map<string> metadata;
    TikaExtractionInfo extractionInfo;
};

type TikaExtractionInfo record {
    string parsedBy; // Parser class used by Tika
    string mediaType; // MIME type detected by Tika
    boolean hasImages;
    boolean hasTables;
    int estimatedWordCount;
    string encoding;
};

type DocumentStructure record {
    string title;
    string[] headers;
    string[] sections;
    string author;
    string subject;
    string creationDate;
    string modificationDate;
    map<string> metadata;
};

// Java interop functions for Apache Tika
function createTikaParser() returns handle = @java:Constructor {
    'class: "org.apache.tika.parser.AutoDetectParser"
} external;

function createTikaMetadata() returns handle = @java:Constructor {
    'class: "org.apache.tika.metadata.Metadata"
} external;

function createTikaParseContext() returns handle = @java:Constructor {
    'class: "org.apache.tika.parser.ParseContext"
} external;

function createContentHandler() returns handle = @java:Constructor {
    'class: "org.apache.tika.sax.BodyContentHandler",
    paramTypes: ["int"]
} external;

function parseDocumentWithTika(handle parser, handle contentHandler, handle metadata, 
    byte[] documentContent, handle parseContext) returns error? = @java:Method {
    'class: "org.apache.tika.parser.Parser",
    name: "parse",
    paramTypes: ["java.io.InputStream", "org.xml.sax.ContentHandler", "org.apache.tika.metadata.Metadata", "org.apache.tika.parser.ParseContext"]
} external;

function getContentHandlerText(handle contentHandler) returns string = @java:Method {
    'class: "org.apache.tika.sax.BodyContentHandler",
    name: "toString"
} external;

function getMetadataValue(handle metadata, string key) returns string? = @java:Method {
    'class: "org.apache.tika.metadata.Metadata",
    name: "get",
    paramTypes: ["java.lang.String"]
} external;

function getMetadataNames(handle metadata) returns string[] = @java:Method {
    'class: "org.apache.tika.metadata.Metadata",
    name: "names"
} external;

function detectLanguage(string text) returns string = @java:Method {
    'class: "org.apache.tika.language.detect.LanguageDetector",
    name: "detect"
} external;

// Main document extraction function using Apache Tika
function extractDocumentContent(byte[] documentContent, string fileName) 
    returns DocumentExtractionResult|error {
    log:printInfo("Starting document extraction using Apache Tika for: " + fileName);
    
    // Initialize Tika components
    handle parser = createTikaParser();
    handle metadata = createTikaMetadata();
    handle parseContext = createTikaParseContext();
    handle contentHandler = createContentHandler(-1); // -1 for unlimited content
    
    do {
        // Parse document with Tika
        check parseDocumentWithTika(parser, contentHandler, metadata, documentContent, parseContext);
        
        // Extract text content
        string extractedText = getContentHandlerText(contentHandler);
        
        // Extract metadata
        DocumentStructure structure = check extractDocumentMetadata(metadata);
        
        // Detect content type and other information
        string? contentType = getMetadataValue(metadata, "Content-Type");
        string? parsedBy = getMetadataValue(metadata, "X-Parsed-By");
        
        // Detect languages in the text
        string[] detectedLanguages = [];
        if (extractedText.length() > 100) {
            string primaryLanguage = detectLanguage(extractedText);
            detectedLanguages.push(primaryLanguage);
        }
        
        // Extract structural elements
        TableData[] tables = check extractTablesFromText(extractedText);
        ImageData[] images = check extractImageReferences(metadata);
        
        // Create extraction info
        TikaExtractionInfo extractionInfo = {
            parsedBy: parsedBy ?: "Unknown",
            mediaType: contentType ?: "application/octet-stream",
            hasImages: images.length() > 0,
            hasTables: tables.length() > 0,
            estimatedWordCount: estimateWordCount(extractedText),
            encoding: getMetadataValue(metadata, "Content-Encoding") ?: "UTF-8"
        };
        
        return {
            extractedText: extractedText,
            structure: structure,
            contentType: contentType ?: "application/octet-stream",
            detectedLanguages: detectedLanguages,
            tables: tables,
            images: images,
            metadata: extractAllMetadata(metadata),
            extractionInfo: extractionInfo
        };
        
    } on fail error e {
        log:printError("Document extraction failed: " + e.message());
        return error("Document extraction failed: " + e.message());
    }
}

function extractDocumentMetadata(handle metadata) returns DocumentStructure|error {
    map<string> metadataMap = extractAllMetadata(metadata);
    
    return {
        title: getMetadataValue(metadata, "title") ?: getMetadataValue(metadata, "dc:title") ?: "Untitled",
        headers: extractHeaders(metadataMap),
        sections: extractSections(metadataMap),
        author: getMetadataValue(metadata, "Author") ?: getMetadataValue(metadata, "dc:creator") ?: "Unknown",
        subject: getMetadataValue(metadata, "Subject") ?: getMetadataValue(metadata, "dc:subject") ?: "",
        creationDate: getMetadataValue(metadata, "Creation-Date") ?: getMetadataValue(metadata, "dcterms:created") ?: "",
        modificationDate: getMetadataValue(metadata, "Last-Modified") ?: getMetadataValue(metadata, "dcterms:modified") ?: "",
        metadata: metadataMap
    };
}

function extractAllMetadata(handle metadata) returns map<string> {
    map<string> metadataMap = {};
    string[] metadataNames = getMetadataNames(metadata);
    
    foreach string name in metadataNames {
        string? value = getMetadataValue(metadata, name);
        if (value is string) {
            metadataMap[name] = value;
        }
    }
    
    return metadataMap;
}
```

#### 3.3 Advanced Tika Features for Tax Documents

**Enhanced Table and Structure Extraction:**
```ballerina
// Advanced Tika features for better content extraction
function createTableExtractionHandler() returns handle = @java:Constructor {
    'class: "org.apache.tika.sax.ToHTMLContentHandler"
} external;

function createStructuredContentHandler() returns handle = @java:Constructor {
    'class: "org.apache.tika.sax.ToXMLContentHandler"
} external;

function extractTablesFromText(string extractedText) returns TableData[]|error {
    // Enhanced table detection using Tika's structured output
    TableData[] tables = [];
    
    // Use regex patterns to identify table structures in extracted text
    string:RegExp tablePattern = re `(?m)^\s*([|\+\-=]+\s*)+$`;
    string:RegExp rowPattern = re `(?m)^\s*\|.*\|\s*$`;
    
    // Implement table parsing logic based on Tika's HTML output
    return tables;
}

function extractImageReferences(handle metadata) returns ImageData[]|error {
    ImageData[] images = [];
    
    // Extract image metadata if present
    string? imageCount = getMetadataValue(metadata, "meta:image-count");
    if (imageCount is string) {
        // Process image information
    }
    
    return images;
}

function estimateWordCount(string text) returns int {
    // Simple word count estimation
    string[] words = regex:split(text, re `\s+`);
    return words.length();
}

// Specialized processing for different document types
function processDocumentByType(byte[] documentContent, string fileName, string contentType) 
    returns DocumentExtractionResult|error {
    
    // Use Tika's auto-detection or specific content type handling
    match contentType {
        "application/pdf" => {
            return extractDocumentContent(documentContent, fileName);
        }
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document" |
        "application/msword" => {
            return extractDocumentContent(documentContent, fileName);
        }
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" |
        "application/vnd.ms-excel" => {
            return extractDocumentContent(documentContent, fileName);
        }
        _ => {
            // Use Tika's auto-detection for unknown types
            return extractDocumentContent(documentContent, fileName);
        }
    }
}
```

#### 3.4 Document Structure Analysis with Tika Integration

**Tax Document Structure Recognition:**
```ballerina
type TaxDocumentStructure record {
    string documentType; // "income_tax", "vat", "regulations"
    string[] mainSections;
    TaxSection[] sections;
    string[] definitions;
    string[] exemptions;
    TaxRate[] rates;
    CalculationRule[] calculations;
    TikaStructuralInfo structuralInfo;
};

type TikaStructuralInfo record {
    string[] headingLevels;
    int tableCount;
    int listCount;
    string documentLanguage;
    boolean hasFormulas;
    string[] detectedFormats; // PDF forms, Excel formulas, etc.
};

type TaxSection record {
    string sectionNumber;
    string title;
    string content;
    string[] subsections;
    int startPosition;
    int endPosition;
    string structuralLevel; // H1, H2, etc. from Tika's HTML output
};

function analyzeTaxDocumentStructure(DocumentExtractionResult extractionResult) 
    returns TaxDocumentStructure|error {
    
    // Analyze document structure for Sri Lankan tax patterns using Tika's enhanced metadata
    string text = extractionResult.extractedText;
    map<string> metadata = extractionResult.metadata;
    
    // Use Tika's language detection and structural analysis
    string documentLanguage = extractionResult.detectedLanguages.length() > 0 ? 
        extractionResult.detectedLanguages[0] : "en";
    
    // Pattern matching for Sri Lankan tax document sections (enhanced with Tika metadata)
    string:RegExp sectionPattern = re `(?i)(section|part|chapter|clause)\s+(\d+(?:\.\d+)*)\s*[-–]\s*(.+)`;
    string:RegExp ratePattern = re `(?i)(\d+(?:\.\d+)?)\s*%\s*(?:rate|tax)`;
    string:RegExp exemptionPattern = re `(?i)(exempt(?:ion)?|deduct(?:ion)?|allowance)`;
    
    // Extract structural information from Tika's analysis
    TikaStructuralInfo structuralInfo = {
        headingLevels: extractHeadingLevels(metadata),
        tableCount: extractionResult.tables.length(),
        listCount: countLists(text),
        documentLanguage: documentLanguage,
        hasFormulas: detectFormulas(text, metadata),
        detectedFormats: extractFormatInfo(metadata)
    };
    
    return {
        documentType: determineDocumentType(text, metadata),
        mainSections: extractMainSections(text),
        sections: extractDetailedSections(text, extractionResult.structure),
        definitions: extractDefinitions(text),
        exemptions: extractExemptions(text),
        rates: extractTaxRates(text),
        calculations: extractCalculationRules(text),
        structuralInfo: structuralInfo
    };
}

function extractHeadingLevels(map<string> metadata) returns string[] {
    string[] headings = [];
    
    // Extract heading information from Tika's structured metadata
    foreach var [key, value] in metadata.entries() {
        if (key.startsWith("heading") || key.includes("H1") || key.includes("H2")) {
            headings.push(value);
        }
    }
    
    return headings;
}

function detectFormulas(string text, map<string> metadata) returns boolean {
    // Check for mathematical formulas and calculations
    string:RegExp formulaPattern = re `(?i)(calculate|formula|=\s*\d+|rate\s*[×*]\s*amount|\$\s*\d+)`;
    boolean hasTextFormulas = formulaPattern.isFullMatch(text);
    
    // Check Tika metadata for Excel formulas or PDF form fields
    boolean hasMetadataFormulas = metadata.hasKey("formula") || 
                                  metadata.hasKey("calculation") ||
                                  metadata.hasKey("form-field");
    
    return hasTextFormulas || hasMetadataFormulas;
}

function extractFormatInfo(map<string> metadata) returns string[] {
    string[] formats = [];
    
    // Extract format-specific information from Tika
    if (metadata.hasKey("pdf-version")) {
        formats.push("PDF-" + (metadata["pdf-version"] ?: ""));
    }
    
    if (metadata.hasKey("Application-Name")) {
        formats.push(metadata["Application-Name"] ?: "");
    }
    
    if (metadata.hasKey("Content-Type")) {
        formats.push(metadata["Content-Type"] ?: "");
    }
    
    return formats;
}

function countLists(string text) returns int {
    // Count numbered and bulleted lists
    string:RegExp listPattern = re `(?m)^\s*(?:\d+\.|•|\*|\-)\s+`;
    regex:Span[] listItems = listPattern.findAll(text);
    return listItems.length();
}

// Enhanced document type detection using Tika's comprehensive analysis
function determineDocumentType(string text, map<string> metadata) returns string {
    string title = metadata["title"] ?: metadata["dc:title"] ?: "";
    string subject = metadata["subject"] ?: metadata["dc:subject"] ?: "";
    string content = (title + " " + subject + " " + text).toLowerAscii();
    
    // Sri Lankan tax document type detection
    if (content.includes("income tax") || content.includes("ආදායම් බදු")) {
        return "income_tax";
    } else if (content.includes("vat") || content.includes("value added tax") || content.includes("වැඩි වටිනාකම් බදු")) {
        return "vat";
    } else if (content.includes("paye") || content.includes("pay as you earn")) {
        return "paye";
    } else if (content.includes("withholding tax") || content.includes("wht")) {
        return "withholding_tax";
    } else if (content.includes("nbt") || content.includes("nation building tax")) {
        return "nbt";
    } else if (content.includes("sscl") || content.includes("social security")) {
        return "sscl";
    } else if (content.includes("regulation") || content.includes("act") || content.includes("amendment")) {
        return "regulation";
    } else {
        return "general_tax_document";
    }
}
```

---

### Phase 4: Intelligent Chunking Strategy

#### 4.1 Semantic Chunking Implementation

**Chunking Configuration:**
```ballerina
type ChunkConfig record {
    int maxTokens = 1500; // Maximum tokens per chunk
    int overlapTokens = 200; // Overlap between chunks for context
    string chunkType = "semantic"; // "semantic", "fixed", "hybrid"
    boolean preserveSections = true; // Keep document sections intact
    boolean preserveTables = true; // Don't split tables
    boolean preserveLists = true; // Keep numbered/bulleted lists together
    decimal minChunkSize = 0.3; // Minimum chunk size as fraction of maxTokens
};

type DocumentChunk record {
    string id;
    int sequence;
    string chunkType; // "text", "table", "list", "header", "definition"
    int startPosition;
    int endPosition;
    string content;
    string contextBefore; // Overlap from previous chunk
    string contextAfter; // Overlap to next chunk
    string sectionHeader; // Document section this belongs to
    string[] keywords; // Extracted keywords
    decimal confidence; // Chunking quality score
    map<string> metadata; // Additional chunk metadata
};
```

**Semantic Chunking Implementation:**
```ballerina
import ballerina/regex;
import ballerina/lang.array;

function performSemanticChunking(string documentText, TaxDocumentStructure structure, 
    ChunkConfig config) returns DocumentChunk[]|error {
    
    DocumentChunk[] chunks = [];
    int currentPosition = 0;
    int chunkSequence = 1;
    
    // Use Tika's structural information for better chunking
    TikaStructuralInfo structuralInfo = structure.structuralInfo;
    
    // Process each section separately to maintain semantic coherence
    foreach TaxSection section in structure.sections {
        string sectionText = documentText.substring(section.startPosition, section.endPosition);
        
        // Split section into semantic units using Tika's structural analysis
        DocumentChunk[] sectionChunks = check chunkSectionWithTikaInfo(
            sectionText, 
            section, 
            config, 
            chunkSequence,
            section.startPosition,
            structuralInfo
        );
        
        chunks.push(...sectionChunks);
        chunkSequence += sectionChunks.length();
    }
    
    // Add overlap context between chunks
    return addOverlapContext(chunks, config);
}

function chunkSectionWithTikaInfo(string sectionText, TaxSection section, ChunkConfig config, 
    int startSequence, int globalOffset, TikaStructuralInfo structuralInfo) 
    returns DocumentChunk[]|error {
    
    DocumentChunk[] chunks = [];
    
    // Enhanced break point detection using Tika's structural information
    int[] breakPoints = findSemanticBreakPointsWithTika(sectionText, structuralInfo);
    
    int currentStart = 0;
    int sequence = startSequence;
    
    foreach int breakPoint in breakPoints {
        string chunkText = sectionText.substring(currentStart, breakPoint);
        
        // Check if chunk size is within limits
        if (estimateTokenCount(chunkText) <= config.maxTokens) {
            chunks.push({
                id: generateChunkId(),
                sequence: sequence,
                chunkType: determineChunkTypeWithTika(chunkText, structuralInfo),
                startPosition: globalOffset + currentStart,
                endPosition: globalOffset + breakPoint,
                content: chunkText.trim(),
                contextBefore: "",
                contextAfter: "",
                sectionHeader: section.title,
                keywords: extractKeywords(chunkText),
                confidence: calculateChunkQualityWithTika(chunkText, structuralInfo),
                metadata: {
                    "sectionNumber": section.sectionNumber,
                    "sectionTitle": section.title,
                    "structuralLevel": section.structuralLevel,
                    "documentLanguage": structuralInfo.documentLanguage,
                    "hasFormulas": structuralInfo.hasFormulas.toString()
                }
            });
            
            currentStart = breakPoint;
            sequence += 1;
        }
    }
    
    return chunks;
}

function findSemanticBreakPointsWithTika(string text, TikaStructuralInfo structuralInfo) 
    returns int[] {
    int[] breakPoints = [];
    
    // Enhanced break point detection using Tika's structural analysis
    
    // Find heading breaks using Tika's heading detection
    if (structuralInfo.headingLevels.length() > 0) {
        foreach string heading in structuralInfo.headingLevels {
            string:RegExp headingPattern = re `(?i)${re:escape(heading)}`;
            regex:Span[] headingSpans = headingPattern.findAll(text);
            foreach regex:Span span in headingSpans {
                breakPoints.push(span.startIndex);
            }
        }
    }
    
    // Find paragraph breaks
    string:RegExp paragraphBreak = re `\n\s*\n`;
    regex:Span[] paragraphSpans = paragraphBreak.findAll(text);
    foreach regex:Span span in paragraphSpans {
        breakPoints.push(span.endIndex);
    }
    
    // Find list item breaks (enhanced with Tika's list detection)
    string:RegExp listBreak = re `\n\s*(?:\d+\.|\w+\)|\•|\*|\-)\s+`;
    regex:Span[] listSpans = listBreak.findAll(text);
    foreach regex:Span span in listSpans {
        breakPoints.push(span.startIndex);
    }
    
    // Find table boundaries if tables are detected
    if (structuralInfo.tableCount > 0) {
        string:RegExp tableBreak = re `(?m)^\s*([|\+\-=]+\s*)+$`;
        regex:Span[] tableSpans = tableBreak.findAll(text);
        foreach regex:Span span in tableSpans {
            breakPoints.push(span.startIndex);
            breakPoints.push(span.endIndex);
        }
    }
    
    // Find sentence breaks (for fine-grained chunking)
    string:RegExp sentenceBreak = re `[.!?]\s+(?=[A-Z])`;
    regex:Span[] sentenceSpans = sentenceBreak.findAll(text);
    foreach regex:Span span in sentenceSpans {
        breakPoints.push(span.endIndex);
    }
    
    // Sort and deduplicate break points
    return breakPoints.sort().distinct();
}

function determineChunkTypeWithTika(string chunkText, TikaStructuralInfo structuralInfo) 
    returns string {
    
    // Enhanced chunk type detection using Tika's analysis
    
    // Check for tables using Tika's table detection
    if (structuralInfo.tableCount > 0 && chunkText.includes("|")) {
        return "table";
    }
    
    // Check for lists using Tika's list detection
    if (structuralInfo.listCount > 0 && regex:matches(chunkText, re `^\s*(?:\d+\.|\w+\)|\•|\*)\s+`)) {
        return "list";
    }
    
    // Check for formulas using Tika's formula detection
    if (structuralInfo.hasFormulas && regex:matches(chunkText, re `(?i)(calculate|formula|=\s*\d+)`)) {
        return "calculation";
    }
    
    // Check for headings using Tika's heading detection
    foreach string heading in structuralInfo.headingLevels {
        if (chunkText.includes(heading)) {
            return "header";
        }
    }
    
    // Check for definitions
    if (regex:matches(chunkText, re `(?i)(means|defined as|shall mean|interpretation)`)) {
        return "definition";
    }
    
    return "text";
}

function calculateChunkQualityWithTika(string chunkText, TikaStructuralInfo structuralInfo) 
    returns decimal {
    
    decimal qualityScore = 0.5; // Base score
    
    // Bonus for having clear structure
    if (structuralInfo.headingLevels.length() > 0) {
        qualityScore += 0.2;
    }
    
    // Bonus for being in detected language
    if (structuralInfo.documentLanguage == "en" || structuralInfo.documentLanguage == "si") {
        qualityScore += 0.1;
    }
    
    // Bonus for having formulas (important for tax calculations)
    if (structuralInfo.hasFormulas) {
        qualityScore += 0.1;
    }
    
    // Penalty for very short or very long chunks
    int wordCount = chunkText.split(re `\s+`).length();
    if (wordCount < 10) {
        qualityScore -= 0.2;
    } else if (wordCount > 500) {
        qualityScore -= 0.1;
    }
    
    return decimal:max(0.0, decimal:min(1.0, qualityScore));
}

function findSemanticBreakPoints(string text) returns int[] {
    int[] breakPoints = [];
    
    // Find paragraph breaks
    string:RegExp paragraphBreak = re `\n\s*\n`;
    regex:Span[] paragraphSpans = paragraphBreak.findAll(text);
    foreach regex:Span span in paragraphSpans {
        breakPoints.push(span.endIndex);
    }
    
    // Find list item breaks
    string:RegExp listBreak = re `\n\s*(?:\d+\.|\w+\)|\•|\*)\s+`;
    regex:Span[] listSpans = listBreak.findAll(text);
    foreach regex:Span span in listSpans {
        breakPoints.push(span.startIndex);
    }
    
    // Find sentence breaks (for fine-grained chunking)
    string:RegExp sentenceBreak = re `[.!?]\s+(?=[A-Z])`;
    regex:Span[] sentenceSpans = sentenceBreak.findAll(text);
    foreach regex:Span span in sentenceSpans {
        breakPoints.push(span.endIndex);
    }
    
    // Sort and deduplicate break points
    return breakPoints.sort().distinct();
}

function addOverlapContext(DocumentChunk[] chunks, ChunkConfig config) 
    returns DocumentChunk[] {
    
    foreach int i in 0 ..< chunks.length() {
        // Add context from previous chunk
        if (i > 0) {
            string prevContent = chunks[i - 1].content;
            int overlapStart = int:max(0, prevContent.length() - config.overlapTokens * 4);
            chunks[i].contextBefore = prevContent.substring(overlapStart);
        }
        
        // Add context from next chunk
        if (i < chunks.length() - 1) {
            string nextContent = chunks[i + 1].content;
            int overlapEnd = int:min(nextContent.length(), config.overlapTokens * 4);
            chunks[i].contextAfter = nextContent.substring(0, overlapEnd);
        }
    }
    
    return chunks;
}
```

---

### Phase 5: Parallel LLM Processing

#### 5.1 LLM Processing Configuration

**Gemini API Integration:**
```ballerina
import ballerina/http;

type GeminiClient client object {
    isolated resource function post v1/models/[string model]:generateContent(
        GenerateContentRequest request,
        map<string> headers = {}
    ) returns GenerateContentResponse|error;
};

type GenerateContentRequest record {
    Content[] contents;
    GenerationConfig generationConfig?;
    SafetySetting[] safetySettings?;
};

type Content record {
    string role;
    Part[] parts;
};

type Part record {
    string text;
};

type GenerationConfig record {
    decimal temperature = 0.1; // Low temperature for factual extraction
    int maxOutputTokens = 2048;
    int topK = 40;
    decimal topP = 0.95;
};

// Initialize Gemini client
GeminiClient geminiClient = check new ("https://generativelanguage.googleapis.com", {
    auth: {
        token: geminiApiKey
    }
});
```

#### 5.2 Parallel Chunk Processing

**Worker-based Parallel Processing:**
```ballerina
import ballerina/lang.runtime;

type ChunkProcessingResult record {
    string chunkId;
    TaxRule[] extractedRules;
    string[] entities;
    decimal confidence;
    int processingTimeMs;
    string? errorMessage;
};

function processChunksInParallel(DocumentChunk[] chunks, string documentId) 
    returns ChunkProcessingResult[]|error {
    
    int maxWorkers = 5; // Limit concurrent API calls
    int batchSize = int:min(chunks.length(), maxWorkers);
    
    ChunkProcessingResult[] results = [];
    int processedCount = 0;
    
    while (processedCount < chunks.length()) {
        // Process chunks in batches
        DocumentChunk[] batch = chunks.slice(processedCount, 
            int:min(processedCount + batchSize, chunks.length()));
        
        // Start workers for each chunk in batch
        future<ChunkProcessingResult>[] futures = [];
        foreach DocumentChunk chunk in batch {
            future<ChunkProcessingResult> futureResult = start processChunkWithLLM(chunk, documentId);
            futures.push(futureResult);
        }
        
        // Wait for all workers to complete
        foreach future<ChunkProcessingResult> futureResult in futures {
            ChunkProcessingResult result = wait futureResult;
            results.push(result);
        }
        
        processedCount += batch.length();
        
        // Small delay to respect API rate limits
        runtime:sleep(1.0);
    }
    
    return results;
}

function processChunkWithLLM(DocumentChunk chunk, string documentId) 
    returns ChunkProcessingResult {
    
    int startTime = time:currentTime();
    ChunkProcessingResult result = {
        chunkId: chunk.id,
        extractedRules: [],
        entities: [],
        confidence: 0.0,
        processingTimeMs: 0
    };
    
    do {
        // Prepare context-aware prompt
        string prompt = buildTaxRuleExtractionPrompt(chunk);
        
        // Call Gemini API
        GenerateContentRequest request = {
            contents: [{
                role: "user",
                parts: [{ text: prompt }]
            }],
            generationConfig: {
                temperature: 0.1,
                maxOutputTokens: 2048
            }
        };
        
        GenerateContentResponse response = check geminiClient->/v1/models/gemini-1.5-pro:generateContent(request);
        
        // Parse LLM response
        string responseText = response.candidates[0].content.parts[0].text;
        TaxRule[] rules = check parseExtractedRules(responseText, chunk);
        
        result.extractedRules = rules;
        result.entities = extractEntities(responseText);
        result.confidence = calculateExtractionConfidence(responseText, chunk);
        
    } on fail error e {
        result.errorMessage = e.message();
    }
    
    result.processingTimeMs = time:currentTime() - startTime;
    return result;
}
```

#### 5.3 Tax Rule Extraction Prompts

**Structured Prompts for Sri Lankan Tax Rules:**
```ballerina
function buildTaxRuleExtractionPrompt(DocumentChunk chunk) returns string {
    string basePrompt = string `
You are an expert in Sri Lankan tax law. Analyze the following text excerpt from a government tax document and extract structured tax rules.

CONTEXT:
Document Section: ${chunk.sectionHeader}
Previous Context: ${chunk.contextBefore}
Next Context: ${chunk.contextAfter}

TEXT TO ANALYZE:
${chunk.content}

INSTRUCTIONS:
1. Extract all tax rules, rates, calculations, exemptions, and conditions
2. Identify the tax type (Income Tax, VAT, PAYE, WHT, NBT, SSCL)
3. For each rule, provide:
   - Rule title and description
   - Applicable tax rates or amounts
   - Conditions and eligibility criteria
   - Effective dates (if mentioned)
   - Calculation formulas (if any)
   - Related sections or references

OUTPUT FORMAT:
Return a JSON object with the following structure:
{
  "rules": [
    {
      "title": "Rule title",
      "description": "Detailed description",
      "tax_type": "income_tax|vat|paye|wht|nbt|sscl",
      "rule_data": {
        "rates": [...],
        "conditions": [...],
        "calculations": [...],
        "exemptions": [...]
      },
      "effective_date": "YYYY-MM-DD or null",
      "confidence": 0.95,
      "source_text": "Original text excerpt"
    }
  ],
  "entities": {
    "tax_rates": [...],
    "amounts": [...],
    "dates": [...],
    "references": [...]
  }
}

IMPORTANT: 
- Only extract explicit tax rules, not general information
- Ensure all amounts include currency (LKR) and format
- Mark confidence level based on clarity of the rule
- Include exact source text for verification
`;

    return basePrompt;
}

function parseExtractedRules(string llmResponse, DocumentChunk chunk) 
    returns TaxRule[]|error {
    
    json parsedResponse = check json:fromJsonString(llmResponse);
    json[] rulesJson = check parsedResponse.rules;
    
    TaxRule[] rules = [];
    
    foreach json ruleJson in rulesJson {
        TaxRule rule = {
            id: generateRuleId(),
            chunkId: chunk.id,
            chunkSequence: chunk.sequence,
            ruleType: check ruleJson.tax_type,
            title: check ruleJson.title,
            description: check ruleJson.description,
            ruleData: check ruleJson.rule_data.cloneWithType(),
            effectiveDate: parseEffectiveDate(ruleJson.effective_date),
            sourceText: check ruleJson.source_text,
            extractionConfidence: check ruleJson.confidence,
            validationStatus: "pending"
        };
        
        rules.push(rule);
    }
    
    return rules;
}
```

---

### Phase 6: Embedding Generation & Vector Storage

#### 6.1 Embedding Generation

**Gemini Embedding API Integration:**
```ballerina
import ballerina/ai;

type EmbeddingRequest record {
    string model = "models/embedding-001";
    Content content;
};

type EmbeddingResponse record {
    Embedding embedding;
};

type Embedding record {
    decimal[] values;
};

function generateEmbeddings(DocumentChunk[] chunks, TaxRule[] rules) 
    returns error? {
    
    // Generate embeddings for chunks
    foreach DocumentChunk chunk in chunks {
        string textForEmbedding = chunk.content + " " + chunk.contextBefore + " " + chunk.contextAfter;
        decimal[] embedding = check generateTextEmbedding(textForEmbedding);
        
        // Store chunk embedding
        check updateChunkEmbedding(chunk.id, embedding);
    }
    
    // Generate embeddings for extracted rules
    foreach TaxRule rule in rules {
        string ruleText = rule.title + " " + rule.description + " " + rule.sourceText;
        decimal[] embedding = check generateTextEmbedding(ruleText);
        
        // Store rule embedding
        check updateRuleEmbedding(rule.id, embedding);
    }
}

function generateTextEmbedding(string text) returns decimal[]|error {
    http:Client embeddingClient = check new ("https://generativelanguage.googleapis.com", {
        auth: {
            token: geminiApiKey
        }
    });
    
    EmbeddingRequest request = {
        model: "models/embedding-001",
        content: {
            parts: [{ text: text }]
        }
    };
    
    EmbeddingResponse response = check embeddingClient->/v1/models/embedding-001:embedContent(request);
    return response.embedding.values;
}
```

#### 6.2 Vector Storage in Supabase

**Database Operations:**
```ballerina
import ballerinax/postgresql;

function updateChunkEmbedding(string chunkId, decimal[] embedding) returns error? {
    postgresql:Client dbClient = check new (
        host = supabaseHost,
        username = "postgres",
        password = supabasePassword,
        database = "postgres",
        port = 5432
    );
    
    _ = check dbClient->execute(`
        UPDATE document_chunks 
        SET embedding = $1::vector,
            processing_status = 'completed'
        WHERE id = $2
    `, embedding, chunkId);
    
    check dbClient.close();
}

function updateRuleEmbedding(string ruleId, decimal[] embedding) returns error? {
    postgresql:Client dbClient = check new (
        host = supabaseHost,
        username = "postgres", 
        password = supabasePassword,
        database = "postgres",
        port = 5432
    );
    
    _ = check dbClient->execute(`
        UPDATE tax_rules 
        SET embedding = $1::vector
        WHERE id = $2
    `, embedding, ruleId);
    
    check dbClient.close();
}
```

---

### Phase 7: Complete Integration & Error Handling

#### 7.1 Enhanced Processing Service

**Updated document_service.bal process endpoint:**
```ballerina
resource function post process/[string documentId]() 
    returns json|http:NotFound|http:InternalServerError {
    
    do {
        log:printInfo("Starting comprehensive document processing: " + documentId);
        
        // 1. Get document from database
        Document? document = check getDocumentById(documentId);
        if (document is ()) {
            return <http:NotFound>{
                body: {
                    "error": "Document not found",
                    "message": "Document with ID '" + documentId + "' does not exist"
                }
            };
        }
        
        // 2. Update processing status
        check updateDocumentStatus(documentId, "processing");
        
        // 3. Download file from Supabase Storage
        byte[] fileContent = check downloadFromSupabaseStorage(document.filePath);
        
        // 4. Extract text based on file type
        PDFExtractionResult extractionResult = check extractTextByFileType(
            fileContent, 
            document.contentType
        );
        
        // 5. Analyze document structure
        TaxDocumentStructure structure = check analyzeTaxDocumentStructure(extractionResult);
        
        // 6. Perform intelligent chunking
        check updateDocumentStatus(documentId, "chunking");
        ChunkConfig config = {
            maxTokens: 1500,
            overlapTokens: 200,
            chunkType: "semantic"
        };
        DocumentChunk[] chunks = check performSemanticChunking(
            extractionResult.extractedText, 
            structure, 
            config
        );
        
        // 7. Store chunks in database
        check storeDocumentChunks(documentId, chunks);
        check updateDocumentTotalChunks(documentId, chunks.length());
        
        // 8. Process chunks with LLM in parallel
        check updateDocumentStatus(documentId, "extracting");
        ChunkProcessingResult[] results = check processChunksInParallel(chunks, documentId);
        
        // 9. Store extracted tax rules
        TaxRule[] allRules = [];
        foreach ChunkProcessingResult result in results {
            allRules.push(...result.extractedRules);
        }
        check storeTaxRules(allRules);
        
        // 10. Generate and store embeddings
        check generateEmbeddings(chunks, allRules);
        
        // 11. Update final status
        check updateDocumentStatus(documentId, "completed");
        check updateDocumentProcessingTime(documentId);
        
        // 12. Generate processing summary
        json summary = {
            "documentId": documentId,
            "status": "completed",
            "processing": {
                "totalChunks": chunks.length(),
                "rulesExtracted": allRules.length(),
                "processingTime": calculateProcessingTime(documentId),
                "averageConfidence": calculateAverageConfidence(results)
            },
            "breakdown": {
                "textExtraction": "completed",
                "chunking": "completed", 
                "llmProcessing": "completed",
                "embedding": "completed",
                "storage": "completed"
            }
        };
        
        log:printInfo("Document processing completed successfully: " + documentId);
        return {
            "success": true,
            "message": "Document processing completed successfully",
            "result": summary
        };
        
    } on fail error e {
        // Error handling and cleanup
        log:printError("Error processing document " + documentId + ": " + e.message());
        
        error? updateResult = updateDocumentStatus(documentId, "failed");
        if (updateResult is error) {
            log:printError("Failed to update document status: " + updateResult.message());
        }
        
        return <http:InternalServerError>{
            body: {
                "error": "Processing failed",
                "message": "An error occurred while processing the document",
                "details": e.message(),
                "documentId": documentId
            }
        };
    }
}
```

#### 7.2 Progress Tracking & Real-time Updates

**WebSocket Integration for Real-time Progress:**
```ballerina
import ballerina/websocket;

service /ws/processing on new websocket:Listener(9090) {
    resource function get [string documentId](http:Request req) 
        returns websocket:Service|websocket:UpgradeError {
        
        return new ProcessingWebSocketService(documentId);
    }
}

service class ProcessingWebSocketService {
    *websocket:Service;
    private string documentId;
    
    function init(string documentId) {
        self.documentId = documentId;
    }
    
    remote function onOpen(websocket:Caller caller) {
        log:printInfo("WebSocket connection opened for document: " + self.documentId);
        // Start sending periodic updates
        _ = start sendProcessingUpdates(caller, self.documentId);
    }
    
    remote function onTextMessage(websocket:Caller caller, string text) {
        // Handle client messages if needed
    }
    
    remote function onClose(websocket:Caller caller, int statusCode, string reason) {
        log:printInfo("WebSocket connection closed for document: " + self.documentId);
    }
}

function sendProcessingUpdates(websocket:Caller caller, string documentId) {
    while (true) {
        // Get current processing status
        json|error status = getDocumentProcessingStatus(documentId);
        if (status is json) {
            error? result = caller->writeTextMessage(status.toString());
            if (result is error) {
                log:printError("Error sending WebSocket update: " + result.message());
                break;
            }
            
            // Check if processing is complete
            if (status.status == "completed" || status.status == "failed") {
                break;
            }
        }
        
        // Wait before next update
        runtime:sleep(2.0);
    }
}
```

---

### Phase 8: Quality Assurance & Validation

#### 8.1 Rule Validation Service

**Automated Quality Checks:**
```ballerina
type ValidationResult record {
    boolean isValid;
    decimal qualityScore;
    ValidationIssue[] issues;
    string[] suggestions;
};

type ValidationIssue record {
    string issueType; // "missing_data", "inconsistent_rate", "unclear_condition"
    string description;
    string severity; // "low", "medium", "high"
    string suggestedFix?;
};

function validateExtractedRules(TaxRule[] rules, DocumentChunk[] chunks) 
    returns ValidationResult {
    
    ValidationIssue[] allIssues = [];
    decimal totalScore = 0.0;
    
    foreach TaxRule rule in rules {
        // Validate rule completeness
        ValidationIssue[] completenessIssues = validateRuleCompleteness(rule);
        allIssues.push(...completenessIssues);
        
        // Validate rule consistency
        ValidationIssue[] consistencyIssues = validateRuleConsistency(rule, rules);
        allIssues.push(...consistencyIssues);
        
        // Validate against chunk context
        DocumentChunk? sourceChunk = getChunkById(rule.chunkId, chunks);
        if (sourceChunk is DocumentChunk) {
            ValidationIssue[] contextIssues = validateRuleContext(rule, sourceChunk);
            allIssues.push(...contextIssues);
        }
        
        totalScore += rule.extractionConfidence;
    }
    
    decimal averageScore = rules.length() > 0 ? totalScore / rules.length() : 0.0;
    boolean isValid = allIssues.filter(issue => issue.severity == "high").length() == 0;
    
    return {
        isValid: isValid,
        qualityScore: averageScore,
        issues: allIssues,
        suggestions: generateValidationSuggestions(allIssues)
    };
}
```

#### 8.2 Human Review Interface

**Admin Validation Endpoints:**
```ballerina
// Admin service for rule validation
service /admin/validation on httpListener {
    
    # Get rules pending validation
    resource function get rules/pending() returns json|error {
        TaxRule[] pendingRules = check getPendingValidationRules();
        return {
            "rules": pendingRules,
            "total": pendingRules.length()
        };
    }
    
    # Validate or reject a specific rule
    resource function post rules/[string ruleId]/validate(json validationData) 
        returns json|http:NotFound|error {
        
        string action = check validationData.action; // "approve" or "reject"
        string? feedback = validationData.feedback;
        string userId = check validationData.userId;
        
        check updateRuleValidationStatus(ruleId, action, userId, feedback);
        
        return {
            "success": true,
            "message": "Rule validation updated",
            "ruleId": ruleId,
            "action": action
        };
    }
}
```

---

### Phase 9: Deployment Configuration

#### 9.1 Environment Configuration

**Config.toml for different environments:**
```toml
[development]
supabase_url = "https://your-dev-project.supabase.co"
supabase_service_key = "your-dev-service-key"
gemini_api_key = "your-dev-gemini-key"
pdf_extraction_api_key = "your-dev-pdf-key"
max_concurrent_workers = 3
chunk_max_tokens = 1000
processing_timeout_minutes = 30

[production]
supabase_url = "https://your-prod-project.supabase.co"
supabase_service_key = "your-prod-service-key"
gemini_api_key = "your-prod-gemini-key"
pdf_extraction_api_key = "your-prod-pdf-key"
max_concurrent_workers = 10
chunk_max_tokens = 1500
processing_timeout_minutes = 60
```

#### 9.2 Error Recovery & Retry Logic

**Resilient Processing with Retry:**
```ballerina
import ballerina/retry;

type RetryConfig record {
    int maxAttempts = 3;
    decimal initialInterval = 1.0;
    decimal backoffFactor = 2.0;
    decimal maxInterval = 30.0;
};

function processChunkWithRetry(DocumentChunk chunk, string documentId) 
    returns ChunkProcessingResult {
    
    RetryConfig retryConfig = {};
    
    retry:RetryManager retryManager = new (
        retryConfig.maxAttempts,
        retryConfig.initialInterval,
        retryConfig.backoffFactor,
        retryConfig.maxInterval
    );
    
    while (retryManager.shouldRetry()) {
        ChunkProcessingResult|error result = processChunkWithLLM(chunk, documentId);
        
        if (result is ChunkProcessingResult) {
            return result;
        } else {
            log:printWarn("Chunk processing failed, retrying: " + result.message());
            retryManager.addFailure(result);
        }
    }
    
    // If all retries failed, return error result
    return {
        chunkId: chunk.id,
        extractedRules: [],
        entities: [],
        confidence: 0.0,
        processingTimeMs: 0,
        errorMessage: "Processing failed after " + retryConfig.maxAttempts.toString() + " attempts"
    };
}
```

---

### Phase 10: Performance Optimization

#### 10.1 Caching Strategy

**Redis Integration for Caching:**
```ballerina
import ballerinax/redis;

redis:Client redisClient = check new (
    connection = {
        host: "localhost",
        port: 6379
    }
);

function cacheExtractedText(string documentId, string extractedText) returns error? {
    string cacheKey = "extracted_text:" + documentId;
    check redisClient->setEx(cacheKey, extractedText, 3600); // Cache for 1 hour
}

function getCachedExtractedText(string documentId) returns string|error? {
    string cacheKey = "extracted_text:" + documentId;
    return redisClient->get(cacheKey);
}

function cacheProcessingResults(string documentId, ChunkProcessingResult[] results) 
    returns error? {
    string cacheKey = "processing_results:" + documentId;
    string resultsJson = check json:fromJsonString(results.toString()).toString();
    check redisClient->setEx(cacheKey, resultsJson, 7200); // Cache for 2 hours
}
```

#### 10.2 Database Optimization

**Connection Pooling and Batch Operations:**
```ballerina
import ballerinax/postgresql;
import ballerina/sql;

// Connection pool configuration
postgresql:ConnectionPool connectionPool = {
    maxOpenConnections: 10,
    maxConnectionLifeTime: 1800,
    minIdleConnections: 2
};

postgresql:Client dbClient = check new (
    host = supabaseHost,
    username = "postgres",
    password = supabasePassword,
    database = "postgres",
    port = 5432,
    connectionPool = connectionPool
);

function batchInsertTaxRules(TaxRule[] rules) returns error? {
    if (rules.length() == 0) {
        return;
    }
    
    sql:ParameterizedQuery[] insertQueries = [];
    
    foreach TaxRule rule in rules {
        sql:ParameterizedQuery query = `
            INSERT INTO tax_rules (
                id, document_id, chunk_id, chunk_sequence, rule_type, 
                title, description, rule_data, effective_date, source_text, 
                extraction_confidence, validation_status, created_at
            ) VALUES (
                ${rule.id}, ${rule.documentId}, ${rule.chunkId}, 
                ${rule.chunkSequence}, ${rule.ruleType}, ${rule.title}, 
                ${rule.description}, ${rule.ruleData}, ${rule.effectiveDate}, 
                ${rule.sourceText}, ${rule.extractionConfidence}, 
                ${rule.validationStatus}, NOW()
            )
        `;
        insertQueries.push(query);
    }
    
    _ = check dbClient->batchExecute(insertQueries);
}
```

---

## Implementation Checklist

### ✅ Phase 1: Foundation (Week 1)
- [ ] Set up Supabase project and database schema
- [ ] Configure Gemini API access
- [ ] Set up external PDF/Word extraction services
- [ ] Basic file upload validation (already implemented)

### ✅ Phase 2: Core Processing (Week 2-3)
- [ ] Implement file storage in Supabase
- [ ] Build text extraction pipeline
- [ ] Create document structure analysis
- [ ] Implement intelligent chunking algorithm

### ✅ Phase 3: LLM Integration (Week 3-4)
- [ ] Set up Gemini API client
- [ ] Create tax rule extraction prompts
- [ ] Implement parallel processing workers
- [ ] Build result parsing and validation

### ✅ Phase 4: Vector Storage (Week 4-5)
- [ ] Implement embedding generation
- [ ] Set up pgvector in Supabase
- [ ] Create semantic search functionality
- [ ] Build vector similarity queries

### ✅ Phase 5: Quality & Validation (Week 5-6)
- [ ] Create validation algorithms
- [ ] Build admin review interface
- [ ] Implement error handling and retry logic
- [ ] Add progress tracking and real-time updates

### ✅ Phase 6: Optimization (Week 6-7)
- [ ] Add Redis caching layer
- [ ] Implement database connection pooling
- [ ] Create performance monitoring
- [ ] Optimize chunk processing speed

### ✅ Phase 7: Testing & Deployment (Week 7-8)
- [ ] Unit tests for all components
- [ ] Integration tests with real documents
- [ ] Load testing for concurrent processing
- [ ] Production deployment configuration

---

## Monitoring & Analytics

### Key Metrics to Track
1. **Processing Performance**
   - Documents processed per hour
   - Average processing time per document
   - Chunk processing success rate
   - LLM API response times

2. **Quality Metrics**
   - Rule extraction accuracy
   - Confidence score distributions
   - Validation success rate
   - Human review feedback

3. **System Health**
   - API error rates
   - Database performance
   - Memory and CPU usage
   - Storage utilization

### Dashboard Integration
```ballerina
// Analytics service for monitoring
service /analytics on httpListener {
    
    resource function get processing/stats() returns json|error {
        return {
            "totalDocuments": check getTotalDocumentCount(),
            "processingRate": check getProcessingRate(),
            "averageConfidence": check getAverageConfidence(),
            "systemHealth": check getSystemHealthMetrics()
        };
    }
}
```

This comprehensive guide provides the complete implementation roadmap for building a production-ready document processing pipeline using Ballerina, with intelligent chunking, parallel LLM processing, and vector storage capabilities.
