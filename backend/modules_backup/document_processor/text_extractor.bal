import ballerina/jballerina.java;
import ballerina/log;
import ballerina/time;

// ============================================================================
// Java Interop Functions for Document Extractor Library - Fixed Version
// ============================================================================
// This module provides Ballerina bindings for the comprehensive Java document
// extraction library optimized for Sri Lankan tax documents.
//
// Uses handle return types and anydata for problematic Java-Ballerina mappings
// ============================================================================

// ============================================================================
// Primary Document Extraction Functions
// ============================================================================

# Extract content from any supported document format using InteropBridge
# This is the recommended method for document processing
#
# + documentData - The document content as handle (byte array)
# + fileName - The filename with extension for format detection as handle (string)
# + return - Handle to DocumentExtractionResult or error for critical failures
public isolated function extractDocumentContentInternal(handle documentData, handle fileName)
    returns handle|error = @java:Method {
    'class: "com.oasis.document.extractor.InteropBridge",
    name: "extractContent"
} external;

# Extract content from any supported document format (convenience wrapper)
# This is the recommended method for document processing
#
# + documentData - The document content as byte array
# + fileName - The filename with extension for format detection
# + return - Handle to DocumentExtractionResult or error for critical failures
public isolated function extractDocumentContent(byte[] documentData, string fileName)
    returns handle|error {
    handle dataHandle = java:fromString(documentData.toString());
    handle nameHandle = java:fromString(fileName);
    return extractDocumentContentInternal(dataHandle, nameHandle);
}

# Extract content specifically from PDF documents
#
# + pdfData - PDF document content as byte array
# + fileName - PDF filename for metadata
# + return - Handle to DocumentExtractionResult or error
public isolated function extractFromPDF(byte[] pdfData, string fileName)
    returns handle|error {
    handle dataHandle = java:fromString(pdfData.toString());
    handle nameHandle = java:fromString(fileName);
    return extractFromPDFInternal(dataHandle, nameHandle);
}

# Internal PDF extraction with handle types
#
# + pdfData - PDF data as handle
# + fileName - Filename as handle  
# + return - Handle to DocumentExtractionResult or error
public isolated function extractFromPDFInternal(handle pdfData, handle fileName)
    returns handle|error = @java:Method {
    'class: "com.oasis.document.extractor.InteropBridge",
    name: "extractFromPDF"
} external;

# Extract content specifically from Word documents (.doc/.docx)
#
# + wordData - Word document content as byte array
# + fileName - Word filename for metadata
# + return - Handle to DocumentExtractionResult or error
public isolated function extractFromWord(byte[] wordData, string fileName)
    returns handle|error {
    handle dataHandle = java:fromString(wordData.toString());
    handle nameHandle = java:fromString(fileName);
    return extractFromWordInternal(dataHandle, nameHandle);
}

# Internal Word extraction with handle types
#
# + wordData - Word data as handle
# + fileName - Filename as handle
# + return - Handle to DocumentExtractionResult or error
public isolated function extractFromWordInternal(handle wordData, handle fileName)
    returns handle|error = @java:Method {
    'class: "com.oasis.document.extractor.InteropBridge",
    name: "extractFromWord"
} external;

# Check if a file format is supported by the extraction library (internal)
#
# + fileName - The filename to check as handle
# + return - true if format is supported, false otherwise
public isolated function isSupportedFormatInternal(handle fileName) returns boolean = @java:Method {
    'class: "com.oasis.document.extractor.InteropBridge",
    name: "isSupportedFormat"
} external;

# Check if a file format is supported by the extraction library (convenience wrapper)
#
# + fileName - The filename to check
# + return - true if format is supported, false otherwise
public isolated function isSupportedFormat(string fileName) returns boolean {
    handle nameHandle = java:fromString(fileName);
    return isSupportedFormatInternal(nameHandle);
}

// ============================================================================
// DocumentExtractionResult Accessor Functions - Using anydata return types
// ============================================================================

# Get the extracted text content from the result
#
# + result - Handle to DocumentExtractionResult
# + return - Handle to Java String
public isolated function getExtractedText(handle result) returns handle = @java:Method {
    'class: "com.oasis.document.extractor.DocumentExtractionResult",
    name: "getExtractedText"
} external;

# Get the document structure information
#
# + result - Handle to DocumentExtractionResult
# + return - Handle to DocumentStructure with metadata
public isolated function getDocumentStructure(handle result) returns handle = @java:Method {
    'class: "com.oasis.document.extractor.DocumentExtractionResult",
    name: "getStructure"
} external;

# Get the detected content type (MIME type)
#
# + result - Handle to DocumentExtractionResult
# + return - Handle to Java String
public isolated function getContentType(handle result) returns handle = @java:Method {
    'class: "com.oasis.document.extractor.DocumentExtractionResult",
    name: "getContentType"
} external;

# Get extracted table data from the document
#
# + result - Handle to DocumentExtractionResult
# + return - Handle to TableData array
public isolated function getTableData(handle result) returns handle = @java:Method {
    'class: "com.oasis.document.extractor.DocumentExtractionResult",
    name: "getTables"
} external;

# Get image metadata from the document
#
# + result - Handle to DocumentExtractionResult
# + return - Handle to ImageData array
public isolated function getImageData(handle result) returns handle = @java:Method {
    'class: "com.oasis.document.extractor.DocumentExtractionResult",
    name: "getImages"
} external;

# Get document metadata (author, creation date, etc.)
#
# + result - Handle to DocumentExtractionResult
# + return - Handle to metadata map
public isolated function getMetadata(handle result) returns handle = @java:Method {
    'class: "com.oasis.document.extractor.DocumentExtractionResult",
    name: "getMetadata"
} external;

# Check if extraction was successful
#
# + result - Handle to DocumentExtractionResult
# + return - true if extraction completed successfully
public isolated function isExtractionSuccessful(handle result) returns boolean = @java:Method {
    'class: "com.oasis.document.extractor.DocumentExtractionResult",
    name: "isExtractionSuccessful"
} external;

# Get error message if extraction failed
#
# + result - Handle to DocumentExtractionResult
# + return - Error message as handle
public isolated function getErrorMessage(handle result) returns handle = @java:Method {
    'class: "com.oasis.document.extractor.DocumentExtractionResult",
    name: "getErrorMessage"
} external;

// ============================================================================
// DocumentStructure Accessor Functions - Using anydata return types
// ============================================================================

# Get document title from structure
#
# + structure - Handle to DocumentStructure
# + return - Document title as anydata
public isolated function getStructureTitle(handle structure) returns handle = @java:Method {
    'class: "com.oasis.document.extractor.DocumentStructure",
    name: "getTitle"
} external;

# Get document author
#
# + structure - Handle to DocumentStructure
# + return - Author name as anydata
public isolated function getStructureAuthor(handle structure) returns handle = @java:Method {
    'class: "com.oasis.document.extractor.DocumentStructure",
    name: "getAuthor"
} external;

# Get document subject
#
# + structure - Handle to DocumentStructure
# + return - Document subject as anydata
public isolated function getStructureSubject(handle structure) returns handle = @java:Method {
    'class: "com.oasis.document.extractor.DocumentStructure",
    name: "getSubject"
} external;

# Get document creation date
#
# + structure - Handle to DocumentStructure
# + return - Creation date as anydata
public isolated function getStructureCreationDate(handle structure) returns handle = @java:Method {
    'class: "com.oasis.document.extractor.DocumentStructure",
    name: "getCreationDate"
} external;

# Get document modification date
#
# + structure - Handle to DocumentStructure
# + return - Modification date as anydata
public isolated function getStructureModificationDate(handle structure) returns handle = @java:Method {
    'class: "com.oasis.document.extractor.DocumentStructure",
    name: "getModificationDate"
} external;

// ============================================================================
// TableData Accessor Functions
// ============================================================================

# Get table cell data as 2D array
#
# + tableData - Handle to TableData
# + return - Handle to 2D string array of cells
public isolated function getTableCells(handle tableData) returns handle = @java:Method {
    'class: "com.oasis.document.extractor.TableData",
    name: "getData"
} external;

# Get table row count
#
# + tableData - Handle to TableData
# + return - Number of rows in table
public isolated function getTableRowCount(handle tableData) returns int = @java:Method {
    'class: "com.oasis.document.extractor.TableData",
    name: "getRowCount"
} external;

# Get table column count
#
# + tableData - Handle to TableData
# + return - Number of columns in table
public isolated function getTableColumnCount(handle tableData) returns int = @java:Method {
    'class: "com.oasis.document.extractor.TableData",
    name: "getColumnCount"
} external;

# Get table title
#
# + tableData - Handle to TableData
# + return - Table title as anydata
public isolated function getTableTitle(handle tableData) returns handle = @java:Method {
    'class: "com.oasis.document.extractor.TableData",
    name: "getTableTitle"
} external;

// ============================================================================
// ImageData Accessor Functions
// ============================================================================

# Get image ID
#
# + image - Handle to ImageData
# + return - Image identifier as anydata
public isolated function getImageId(handle image) returns handle = @java:Method {
    'class: "com.oasis.document.extractor.ImageData",
    name: "getImageId"
} external;

# Get image type
#
# + image - Handle to ImageData
# + return - Image type as anydata
public isolated function getImageType(handle image) returns handle = @java:Method {
    'class: "com.oasis.document.extractor.ImageData",
    name: "getImageType"
} external;

# Get image width
#
# + image - Handle to ImageData
# + return - Image width in pixels
public isolated function getImageWidth(handle image) returns int = @java:Method {
    'class: "com.oasis.document.extractor.ImageData",
    name: "getWidth"
} external;

# Get image height
#
# + image - Handle to ImageData
# + return - Image height in pixels
public isolated function getImageHeight(handle image) returns int = @java:Method {
    'class: "com.oasis.document.extractor.ImageData",
    name: "getHeight"
} external;

# Get image description
#
# + image - Handle to ImageData
# + return - Image description as anydata
public isolated function getImageDescription(handle image) returns handle = @java:Method {
    'class: "com.oasis.document.extractor.ImageData",
    name: "getDescription"
} external;

// ============================================================================
// Safe Helper Functions
// ============================================================================

# Convert anydata to string safely
#
# + data - The anydata value from Java interop
# + return - String representation or empty string
public function toStringSafe(anydata data) returns string {
    if data is string {
        return data;
    } else if data is () {
        return "";
    } else {
        return data.toString();
    }
}

# Validate if a file can be processed by the library
#
# + fileName - The filename to validate
# + return - Validation result with details
public function validateDocument(string fileName) returns ValidationResult {
    log:printInfo("Validating document: " + fileName);

    boolean supported = isSupportedFormat(fileName);

    return {
        isValid: supported,
        fileName: fileName,
        supportedFormats: [], // Basic validation without detailed format list
        message: supported ? "Document format is supported" : "Unsupported document format"
    };
}

# Validation result for document format checking
public type ValidationResult record {
    # Whether the document format is valid/supported
    boolean isValid;
    # The filename that was validated
    string fileName;
    # List of supported file formats
    string[] supportedFormats;
    # Validation message with details
    string message;
};

# Safe extraction wrapper that handles critical application requirements
#
# + documentData - Document content as byte array
# + fileName - Document filename
# + return - Extraction success status with details
public function safeExtractDocument(byte[] documentData, string fileName)
    returns ExtractionStatus {

    log:printInfo("Starting safe document extraction: " + fileName);

    // Step 1: Validate format
    ValidationResult validation = validateDocument(fileName);
    if (!validation.isValid) {
        return {
            success: false,
            errorType: "UNSUPPORTED_FORMAT",
            message: "Document format not supported: " + fileName,
            extractedContent: ()
        };
    }

    // Step 2: Attempt extraction
    handle|error extractionResult = extractDocumentContent(documentData, fileName);

    if (extractionResult is error) {
        log:printError("Document extraction failed: " + extractionResult.message());
        return {
            success: false,
            errorType: "EXTRACTION_FAILED",
            message: "Failed to extract document content: " + extractionResult.message(),
            extractedContent: ()
        };
    }

    // Step 3: Verify extraction success
    boolean successful = isExtractionSuccessful(extractionResult);
    if (!successful) {
        handle errorMsgData = getErrorMessage(extractionResult);
        string errorMsg = java:toString(errorMsgData) ?: "";
        log:printError("Extraction unsuccessful: " + errorMsg);
        return {
            success: false,
            errorType: "EXTRACTION_INCOMPLETE",
            message: "Document extraction was incomplete: " + errorMsg,
            extractedContent: ()
        };
    }

    log:printInfo("Document extraction completed successfully: " + fileName);
    return {
        success: true,
        errorType: (),
        message: "Document extracted successfully",
        extractedContent: extractionResult
    };
}

# Get extracted text as string safely
#
# + extractionResult - Handle to DocumentExtractionResult  
# + return - Extracted text or empty string if error
public function getExtractedTextSafe(handle extractionResult) returns string {
    handle textData = getExtractedText(extractionResult);
    return java:toString(textData) ?: "";
}

# Get content type as string safely
#
# + extractionResult - Handle to DocumentExtractionResult
# + return - Content type or empty string if error  
public function getContentTypeSafe(handle extractionResult) returns string {
    handle contentTypeData = getContentType(extractionResult);
    return java:toString(contentTypeData) ?: "";
}

# Extraction status for safe extraction operations
public type ExtractionStatus record {
    # Whether the extraction was successful
    boolean success;
    # Type of error if extraction failed (e.g., "UNSUPPORTED_FORMAT", "EXTRACTION_FAILED")
    string? errorType;
    # Human-readable message describing the result
    string message;
    # Handle to extracted content if successful, null if failed
    handle? extractedContent;
};

// ============================================================================
// Document Chunking Implementation for Sri Lankan Tax Documents
// ============================================================================

# Document chunk with metadata for tax documents
public type DocumentChunk record {
    # Unique identifier for the chunk
    string id;
    # Parent document identifier
    string documentId;
    # Sequential position of chunk in document
    int sequence;
    # The text content of this chunk
    string chunkText;
    # Starting character position in original document
    int startPosition;
    # Ending character position in original document
    int endPosition;
    # Estimated token count for this chunk
    int tokenCount;
    # Type of chunk: "semantic", "table", "header", "paragraph", "list"
    string chunkType;
    # Tax-related keywords found in this chunk
    string[] keywords;
    # Relevance score for tax content (0.0 - 1.0)
    decimal relevanceScore;
    # Surrounding context for overlap with adjacent chunks
    string context;
    # Processing metadata
    string processingStatus = "pending";
};

# Chunking configuration optimized for tax documents
public type ChunkConfig record {
    # Maximum tokens per chunk (optimized for Gemini 1.5 Flash)
    int maxTokens = 1000;
    # Overlap tokens between chunks for context preservation
    int overlapTokens = 150;
    # Chunking strategy: "semantic", "fixed", "hybrid"
    string strategy = "semantic";
    # Sri Lankan tax-specific keywords for relevance scoring
    string[] taxKeywords = [
        "income tax",
        "VAT",
        "PAYE",
        "deduction",
        "bracket",
        "rate",
        "exemption",
        "allowance",
        "threshold",
        "liability",
        "refund",
        "withholding tax",
        "advance payment",
        "instalment",
        "penalty",
        "interest",
        "assessment",
        "appeal",
        "rebate",
        "credit"
    ];
};

# Document structure analysis result
public type DocumentStructure record {
    # Detected sections in the document
    string[] sections;
    # Detected tables and their positions
    TablePosition[] tables;
    # Detected headers and their levels
    HeaderInfo[] headers;
    # Total document length
    int totalLength;
    # Document type classification
    string documentType;
};

# Table position information
public type TablePosition record {
    int startPos;
    int endPos;
    string title;
    int rowCount;
    int colCount;
};

# Header information
public type HeaderInfo record {
    string text;
    int level;
    int position;
};

# Chunking result with statistics
public type ChunkingResult record {
    # Successfully created chunks
    DocumentChunk[] chunks;
    # Total number of chunks created
    int totalChunks;
    # Processing statistics
    ChunkingStats stats;
    # Any warnings during chunking
    string[] warnings;
    # Overall success status
    boolean success;
};

# Chunking statistics
public type ChunkingStats record {
    # Total processing time in milliseconds
    int processingTimeMs;
    # Average chunk size in tokens
    decimal avgChunkSize;
    # Number of tax-relevant chunks
    int taxRelevantChunks;
    # Coverage percentage of original document
    decimal documentCoverage;
};

# Main chunking function for Sri Lankan tax documents
#
# + documentText - Extracted text from the document
# + documentId - Unique identifier for the document
# + fileName - Original filename for context
# + return - Chunking result with created chunks and metadata
public function chunkTaxDocument(string documentText, string documentId, string fileName)
    returns ChunkingResult|error {

    log:printInfo("Starting intelligent chunking for tax document: " + fileName);
    time:Utc startTime = time:utcNow();

    // Validate input
    if (documentText.length() == 0) {
        return error("Document text is empty for chunking");
    }

    // Initialize chunking configuration
    ChunkConfig config = {
        maxTokens: 1000,
        overlapTokens: 150,
        strategy: "semantic",
        taxKeywords: [
            "income tax",
            "VAT",
            "PAYE",
            "deduction",
            "bracket",
            "rate",
            "exemption",
            "allowance",
            "threshold",
            "liability",
            "refund",
            "withholding tax",
            "advance payment",
            "instalment",
            "penalty",
            "interest",
            "assessment",
            "appeal",
            "rebate",
            "credit",
            "Sri Lanka",
            "LKR",
            "rupees",
            "commissioner",
            "inland revenue"
        ]
    };

    string[] warnings = [];

    // Step 1: Analyze document structure
    log:printInfo("Analyzing document structure for semantic chunking");
    DocumentStructure structure = analyzeDocumentStructure(documentText);

    // Step 2: Perform semantic chunking based on structure
    DocumentChunk[] rawChunks = check performSemanticChunking(documentText, structure, config, documentId);

    // Step 3: Add context overlap between chunks
    DocumentChunk[] chunksWithOverlap = addContextOverlap(rawChunks, config);

    // Step 4: Calculate relevance scores for tax content
    DocumentChunk[] scoredChunks = calculateTaxRelevance(chunksWithOverlap, config);

    // Step 5: Validate and finalize chunks
    DocumentChunk[] finalChunks = validateAndFinalizeChunks(scoredChunks, documentId);

    // Calculate statistics
    time:Utc endTime = time:utcNow();
    ChunkingStats stats = calculateChunkingStats(finalChunks, startTime, endTime, documentText);

    log:printInfo("Chunking completed successfully. Generated " + finalChunks.length().toString() + " chunks");

    // Print chunks to console for debugging
    printChunksToConsole(finalChunks, fileName);

    return {
        chunks: finalChunks,
        totalChunks: finalChunks.length(),
        stats: stats,
        warnings: warnings,
        success: true
    };
}

# Analyze document structure for intelligent chunking
#
# + text - Document text to analyze
# + return - Document structure information
function analyzeDocumentStructure(string text) returns DocumentStructure {
    log:printInfo("Analyzing document structure for chunking optimization");

    // Detect sections based on common patterns in tax documents
    string[] sections = detectDocumentSections(text);

    // Detect tables (important for tax brackets and calculations)
    TablePosition[] tables = detectTables(text);

    // Detect headers and subheaders
    HeaderInfo[] headers = detectHeaders(text);

    // Classify document type
    string docType = classifyDocumentType(text);

    return {
        sections: sections,
        tables: tables,
        headers: headers,
        totalLength: text.length(),
        documentType: docType
    };
}

# Detect document sections based on tax document patterns
function detectDocumentSections(string text) returns string[] {
    string[] sections = [];

    // Common section patterns in Sri Lankan tax documents
    string[] sectionPatterns = [
        "CHAPTER",
        "SECTION",
        "PART",
        "SCHEDULE",
        "APPENDIX",
        "INCOME TAX",
        "VALUE ADDED TAX",
        "PAY AS YOU EARN",
        "DEDUCTIONS",
        "EXEMPTIONS",
        "RATES",
        "BRACKETS"
    ];

    string[] lines = splitStringByNewlines(text);

    foreach string line in lines {
        string upperLine = line.toUpperAscii().trim();
        foreach string pattern in sectionPatterns {
            if (upperLine.includes(pattern)) {
                sections.push(line.trim());
                break;
            }
        }
    }

    return sections;
}

# Detect tables in the document text
function detectTables(string text) returns TablePosition[] {
    TablePosition[] tables = [];

    // Simple table detection based on patterns
    string[] lines = splitStringByNewlines(text);

    int i = 0;
    while (i < lines.length()) {
        string line = lines[i].trim();

        // Check if line looks like a table header or data row
        if (isTableRow(line)) {
            int startPos = getLinePosition(text, i);
            int tableLines = countTableLines(lines, i);
            int endPos = getLinePosition(text, i + tableLines);

            tables.push({
                startPos: startPos,
                endPos: endPos,
                title: extractTableTitle(lines, i),
                rowCount: tableLines,
                colCount: countColumns(line)
            });

            i += tableLines;
        } else {
            i += 1;
        }
    }

    return tables;
}

# Check if a line appears to be part of a table
function isTableRow(string line) returns boolean {
    // Look for multiple columns separated by whitespace or specific characters
    if (line.includes("|") || line.includes("\t") || hasMultipleSpaces(line)) {
        // Check for numeric content or currency symbols
        if (containsNumericContent(line)) {
            return true;
        }
    }

    return false;
}

# Detect headers and their hierarchy levels
function detectHeaders(string text) returns HeaderInfo[] {
    HeaderInfo[] headers = [];
    string[] lines = splitStringByNewlines(text);

    foreach int i in 0 ..< lines.length() {
        string line = lines[i].trim();

        if (line.length() > 0) {
            int level = determineHeaderLevel(line);
            if (level > 0) {
                headers.push({
                    text: line,
                    level: level,
                    position: getLinePosition(text, i)
                });
            }
        }
    }

    return headers;
}

# Perform semantic chunking based on document structure
function performSemanticChunking(string text, DocumentStructure structure, ChunkConfig config, string documentId)
    returns DocumentChunk[]|error {

    log:printInfo("Performing semantic chunking with strategy: " + config.strategy);

    DocumentChunk[] chunks = [];

    if (config.strategy == "semantic") {
        chunks = performStructureBasedChunking(text, structure, config, documentId);
    } else if (config.strategy == "fixed") {
        chunks = performFixedSizeChunking(text, config, documentId);
    } else {
        // Hybrid approach
        chunks = performHybridChunking(text, structure, config, documentId);
    }

    return chunks;
}

# Structure-based chunking that respects document semantics
function performStructureBasedChunking(string text, DocumentStructure structure, ChunkConfig config, string documentId)
    returns DocumentChunk[] {

    DocumentChunk[] chunks = [];
    string currentChunk = "";
    int currentTokens = 0;
    int chunkSequence = 1;
    int currentPosition = 0;

    // Split text into semantic units (paragraphs, sections, etc.)
    string[] units = splitIntoSemanticUnits(text, structure);

    foreach string unit in units {
        int unitTokens = estimateTokenCount(unit);

        // If adding this unit would exceed the limit and we have content, finalize chunk
        if (currentTokens + unitTokens > config.maxTokens && currentChunk.length() > 0) {
            DocumentChunk chunk = createChunk(
                    currentChunk.trim(),
                    currentPosition,
                    chunkSequence,
                    config,
                    documentId
            );
            chunks.push(chunk);

            // Start new chunk with current unit
            currentChunk = unit;
            currentTokens = unitTokens;
            chunkSequence += 1;
            currentPosition += currentChunk.length();
        } else {
            // Add to current chunk
            if (currentChunk.length() > 0) {
                currentChunk += "\n\n" + unit;
            } else {
                currentChunk = unit;
            }
            currentTokens += unitTokens;
        }
    }

    // Add final chunk if there's remaining content
    if (currentChunk.trim().length() > 0) {
        DocumentChunk chunk = createChunk(
                currentChunk.trim(),
                currentPosition,
                chunkSequence,
                config,
                documentId
        );
        chunks.push(chunk);
    }

    return chunks;
}

# Split text into semantic units preserving meaning
function splitIntoSemanticUnits(string text, DocumentStructure structure) returns string[] {
    string[] units = [];

    // Simple approach: split by double newlines (paragraph breaks)
    string[] sections = splitStringByDoubleNewlines(text);

    foreach string section in sections {
        // Further split each section by single newlines if too large
        if (section.length() > 2000) {
            string[] paragraphs = splitStringByNewlines(section.trim());
            foreach string paragraph in paragraphs {
                string cleanParagraph = paragraph.trim();
                if (cleanParagraph.length() > 0) {
                    units.push(cleanParagraph);
                }
            }
        } else {
            string cleanSection = section.trim();
            if (cleanSection.length() > 0) {
                units.push(cleanSection);
            }
        }
    }

    return units;
}

# Split string by double newlines (simple paragraph detection)
function splitStringByDoubleNewlines(string text) returns string[] {
    string[] sections = [];
    string currentSection = "";
    int newlineCount = 0;

    foreach string:Char char in text {
        if (char == "\n") {
            newlineCount += 1;
            if (newlineCount >= 2) {
                if (currentSection.trim().length() > 0) {
                    sections.push(currentSection.trim());
                    currentSection = "";
                }
                newlineCount = 0;
            } else {
                currentSection += char;
            }
        } else {
            if (newlineCount == 1) {
                currentSection += "\n";
            }
            currentSection += char;
            newlineCount = 0;
        }
    }

    if (currentSection.trim().length() > 0) {
        sections.push(currentSection.trim());
    }

    return sections;
}

# Create a document chunk with metadata
function createChunk(string text, int position, int sequence, ChunkConfig config, string documentId)
    returns DocumentChunk {

    string chunkId = documentId + "_chunk_" + sequence.toString();
    int tokenCount = estimateTokenCount(text);
    string chunkType = determineChunkType(text);
    string[] keywords = extractKeywords(text, config.taxKeywords);

    return {
        id: chunkId,
        documentId: documentId,
        sequence: sequence,
        chunkText: text,
        startPosition: position,
        endPosition: position + text.length(),
        tokenCount: tokenCount,
        chunkType: chunkType,
        keywords: keywords,
        relevanceScore: 0.0, // Will be calculated later
        context: text, // Will be enhanced with overlap later
        processingStatus: "created"
    };
}

# Estimate token count for text (rough approximation)
function estimateTokenCount(string text) returns int {
    // Rough estimation: 1 token ≈ 4 characters for English text
    // Adjust for tax documents which may have more technical terms
    return (text.length() / 3); // More conservative estimate for technical content
}

# Determine the type of chunk based on content
function determineChunkType(string text) returns string {
    string upperText = text.toUpperAscii();

    if (upperText.includes("TABLE") || isTableContent(text)) {
        return "table";
    } else if (isHeaderContent(text)) {
        return "header";
    } else if (upperText.includes("LIST") || isListContent(text)) {
        return "list";
    } else {
        return "paragraph";
    }
}

# Extract tax-related keywords from text
function extractKeywords(string text, string[] taxKeywords) returns string[] {
    string[] foundKeywords = [];
    string lowerText = text.toLowerAscii();

    foreach string keyword in taxKeywords {
        if (lowerText.includes(keyword.toLowerAscii())) {
            foundKeywords.push(keyword);
        }
    }

    return foundKeywords;
}

# Add context overlap between adjacent chunks
function addContextOverlap(DocumentChunk[] chunks, ChunkConfig config) returns DocumentChunk[] {
    if (chunks.length() <= 1) {
        return chunks;
    }

    DocumentChunk[] overlappedChunks = [];

    foreach int i in 0 ..< chunks.length() {
        DocumentChunk chunk = chunks[i];

        // Build context with overlap from adjacent chunks
        string context = chunk.chunkText;

        // Add overlap from previous chunk
        if (i > 0) {
            string previousContext = getLastTokens(chunks[i - 1].chunkText, config.overlapTokens / 2);
            context = "[PREV: " + previousContext + "] " + context;
        }

        // Add overlap from next chunk
        if (i < chunks.length() - 1) {
            string nextContext = getFirstTokens(chunks[i + 1].chunkText, config.overlapTokens / 2);
            context = context + " [NEXT: " + nextContext + "]";
        }

        chunk.context = context;
        overlappedChunks.push(chunk);
    }

    return overlappedChunks;
}

# Calculate tax relevance scores for chunks
function calculateTaxRelevance(DocumentChunk[] chunks, ChunkConfig config) returns DocumentChunk[] {
    DocumentChunk[] scoredChunks = [];

    foreach DocumentChunk chunk in chunks {
        decimal score = 0.0d;

        // Base score from keyword presence
        decimal keywordScore = (<decimal>chunk.keywords.length()) / (<decimal>config.taxKeywords.length());
        score += keywordScore * 0.4d;

        // Bonus for numeric content (likely calculations)
        if (containsNumericContent(chunk.chunkText)) {
            score += 0.3d;
        }

        // Bonus for table content
        if (chunk.chunkType == "table") {
            score += 0.2d;
        }

        // Bonus for header content
        if (chunk.chunkType == "header") {
            score += 0.1d;
        }

        // Ensure score is between 0 and 1
        chunk.relevanceScore = score > 1.0d ? 1.0d : score;
        scoredChunks.push(chunk);
    }

    return scoredChunks;
}

# Print chunks to console for debugging and monitoring
#
# + chunks - Array of document chunks to display
# + fileName - Original document filename for context
function printChunksToConsole(DocumentChunk[] chunks, string fileName) {
    log:printInfo("===============================================");
    log:printInfo("📄 DOCUMENT CHUNKING RESULTS");
    log:printInfo("===============================================");
    log:printInfo("Document: " + fileName);
    log:printInfo("Total Chunks: " + chunks.length().toString());
    log:printInfo("===============================================");

    foreach int i in 0 ..< chunks.length() {
        DocumentChunk chunk = chunks[i];

        log:printInfo("");
        log:printInfo("🔹 CHUNK #" + chunk.sequence.toString() + " (ID: " + chunk.id + ")");
        log:printInfo("├─ Type: " + chunk.chunkType);
        log:printInfo("├─ Token Count: " + chunk.tokenCount.toString());
        log:printInfo("├─ Relevance Score: " + chunk.relevanceScore.toString());
        log:printInfo("├─ Position: " + chunk.startPosition.toString() + " - " + chunk.endPosition.toString());
        log:printInfo("├─ Status: " + chunk.processingStatus);

        // Print keywords if any
        if (chunk.keywords.length() > 0) {
            string keywordList = "";
            foreach int j in 0 ..< chunk.keywords.length() {
                keywordList += chunk.keywords[j];
                if (j < chunk.keywords.length() - 1) {
                    keywordList += ", ";
                }
            }
            log:printInfo("├─ Tax Keywords: " + keywordList);
        } else {
            log:printInfo("├─ Tax Keywords: None");
        }

        // Print first 200 characters of chunk text
        string previewText = chunk.chunkText.length() > 200 ?
            chunk.chunkText.substring(0, 200) + "..." :
            chunk.chunkText;

        // Clean up text for better console display
        string cleanText = previewText.trim();
        cleanText = replaceString(cleanText, "\n", " ");
        cleanText = replaceString(cleanText, "\t", " ");
        // Remove multiple spaces
        while (cleanText.includes("  ")) {
            cleanText = replaceString(cleanText, "  ", " ");
        }

        log:printInfo("└─ Preview: " + cleanText);

        // Add separator between chunks
        if (i < chunks.length() - 1) {
            log:printInfo("│");
        }
    }

    log:printInfo("");
    log:printInfo("===============================================");
    log:printInfo("✅ CHUNKING SUMMARY COMPLETED");
    log:printInfo("===============================================");
}

# Simple string replacement function
function replaceString(string original, string searchFor, string replaceWith) returns string {
    string result = "";
    int searchLen = searchFor.length();
    int i = 0;

    while (i < original.length()) {
        if (i + searchLen <= original.length() &&
            original.substring(i, i + searchLen) == searchFor) {
            result += replaceWith;
            i += searchLen;
        } else {
            result += original.substring(i, i + 1);
            i += 1;
        }
    }

    return result;
}

# Public function to process document with chunking and console output
#
# + documentData - Document content as byte array
# + fileName - Document filename
# + return - Chunking result with detailed console output
public function processDocumentWithChunking(byte[] documentData, string fileName)
    returns ChunkingResult|error {

    log:printInfo("🚀 Starting document processing with chunking for: " + fileName);

    // Step 1: Extract text from document
    ExtractionStatus extraction = safeExtractDocument(documentData, fileName);
    if (!extraction.success) {
        log:printError("❌ Document extraction failed: " + extraction.message);
        return error("Document extraction failed: " + extraction.message);
    }

    log:printInfo("✅ Document text extraction completed successfully");

    // Step 2: Get extracted text
    string extractedText = getExtractedTextSafe(extraction.extractedContent ?: java:createNull());
    if (extractedText.length() == 0) {
        log:printError("❌ No text extracted from document");
        return error("No text content extracted from document");
    }

    log:printInfo("📊 Extracted text length: " + extractedText.length().toString() + " characters");

    // Step 3: Generate document ID
    string documentId = generateDocumentId(fileName);
    log:printInfo("🆔 Generated document ID: " + documentId);

    // Step 4: Perform chunking with console output
    ChunkingResult|error chunkingResult = chunkTaxDocument(extractedText, documentId, fileName);

    if (chunkingResult is error) {
        log:printError("❌ Chunking failed: " + chunkingResult.message());
        return chunkingResult;
    }

    log:printInfo("🎯 Document processing completed successfully!");
    log:printInfo("📈 Processing Statistics:");
    log:printInfo("   ├─ Total Chunks: " + chunkingResult.totalChunks.toString());
    log:printInfo("   ├─ Tax Relevant Chunks: " + chunkingResult.stats.taxRelevantChunks.toString());
    log:printInfo("   ├─ Average Chunk Size: " + chunkingResult.stats.avgChunkSize.toString() + " tokens");
    log:printInfo("   ├─ Processing Time: " + chunkingResult.stats.processingTimeMs.toString() + "ms");
    log:printInfo("   └─ Document Coverage: " + chunkingResult.stats.documentCoverage.toString() + "%");

    return chunkingResult;
}

# Generate a unique document ID
function generateDocumentId(string fileName) returns string {
    // Simple ID generation based on filename and timestamp
    time:Utc currentTime = time:utcNow();
    string timestamp = currentTime.toString();
    string cleanFileName = fileName.toLowerAscii();

    // Remove file extension and special characters
    if (cleanFileName.includes(".")) {
        int? dotIndex = cleanFileName.lastIndexOf(".");
        if (dotIndex is int && dotIndex > 0) {
            cleanFileName = cleanFileName.substring(0, dotIndex);
        }
    }

    // Replace spaces and special characters with underscores
    cleanFileName = replaceString(cleanFileName, " ", "_");
    cleanFileName = replaceString(cleanFileName, "-", "_");
    cleanFileName = replaceString(cleanFileName, ".", "_");

    return "doc_" + cleanFileName + "_" + timestamp.substring(0, 19);
}

# Validate and finalize chunks
function validateAndFinalizeChunks(DocumentChunk[] chunks, string documentId) returns DocumentChunk[] {
    DocumentChunk[] validChunks = [];

    foreach DocumentChunk chunk in chunks {
        // Validate chunk meets minimum requirements
        if (chunk.chunkText.trim().length() >= 50 && chunk.tokenCount >= 10) {
            chunk.processingStatus = "validated";
            validChunks.push(chunk);
        } else {
            log:printWarn("Skipping chunk " + chunk.id + " - too small");
        }
    }

    return validChunks;
}

# Calculate chunking statistics
function calculateChunkingStats(DocumentChunk[] chunks, time:Utc startTime, time:Utc endTime, string originalText)
    returns ChunkingStats {

    decimal processingTime = time:utcDiffSeconds(endTime, startTime);
    decimal totalTokens = 0.0d;
    int taxRelevantCount = 0;

    foreach DocumentChunk chunk in chunks {
        totalTokens += <decimal>chunk.tokenCount;
        if (chunk.relevanceScore > 0.5d) {
            taxRelevantCount += 1;
        }
    }

    decimal avgChunkSize = chunks.length() > 0 ? totalTokens / <decimal>chunks.length() : 0.0d;
    decimal coverage = (totalTokens / <decimal>estimateTokenCount(originalText)) * 100.0d;

    return {
        processingTimeMs: <int>processingTime * 1000,
        avgChunkSize: avgChunkSize,
        taxRelevantChunks: taxRelevantCount,
        documentCoverage: coverage
    };
}

# Helper functions for text processing

# Get the last N tokens from text using simple string splitting
function getLastTokens(string text, int tokenCount) returns string {
    string[] words = splitStringByWhitespace(text.trim());
    if (words.length() <= tokenCount) {
        return text;
    }

    string[] lastWords = words.slice(words.length() - tokenCount);
    return string:'join(" ", ...lastWords);
}

# Get the first N tokens from text using simple string splitting
function getFirstTokens(string text, int tokenCount) returns string {
    string[] words = splitStringByWhitespace(text.trim());
    if (words.length() <= tokenCount) {
        return text;
    }

    string[] firstWords = words.slice(0, tokenCount);
    return string:'join(" ", ...firstWords);
}

# Split text by whitespace (simple replacement for regex split)
function splitStringByWhitespace(string text) returns string[] {
    string[] parts = [];
    string currentPart = "";

    foreach string:Char char in text {
        if (char == " " || char == "\t" || char == "\n") {
            if (currentPart.length() > 0) {
                parts.push(currentPart);
                currentPart = "";
            }
        } else {
            currentPart += char;
        }
    }

    if (currentPart.length() > 0) {
        parts.push(currentPart);
    }

    return parts;
}

# Split text by newlines
function splitStringByNewlines(string text) returns string[] {
    string[] lines = [];
    string currentLine = "";

    foreach string:Char char in text {
        if (char == "\n") {
            lines.push(currentLine);
            currentLine = "";
        } else {
            currentLine += char;
        }
    }

    if (currentLine.length() > 0) {
        lines.push(currentLine);
    }

    return lines;
}

# Check if text contains numeric content using simple string operations
function containsNumericContent(string text) returns boolean {
    string[] indicators = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "%", "LKR", "Rs", "USD"];

    foreach string indicator in indicators {
        if (text.includes(indicator)) {
            return true;
        }
    }
    return false;
}

# Check if text is table content using simple heuristics
function isTableContent(string text) returns boolean {
    // Look for table-like patterns using simple string operations
    return text.includes("|") || text.includes("\t") || hasMultipleSpaces(text);
}

# Check if text has multiple consecutive spaces (table indicator)
function hasMultipleSpaces(string text) returns boolean {
    int spaceCount = 0;
    foreach string:Char char in text {
        if (char == " ") {
            spaceCount += 1;
            if (spaceCount >= 3) {
                return true;
            }
        } else {
            spaceCount = 0;
        }
    }
    return false;
}

# Check if text is header content
function isHeaderContent(string text) returns boolean {
    string[] lines = splitStringByNewlines(text);
    return lines.length() <= 3 && text.length() < 200 && !text.includes(".");
}

# Check if text is list content
function isListContent(string text) returns boolean {
    string trimmed = text.trim();
    return trimmed.startsWith("-") || trimmed.startsWith("*") || trimmed.startsWith("+") ||
            (trimmed.length() > 2 && trimmed.substring(1, 2) == ".");
}

# Determine header level based on simple formatting rules
function determineHeaderLevel(string line) returns int {
    string trimmed = line.trim();

    // Check if all uppercase (main header)
    if (isAllUppercase(trimmed) && trimmed.length() < 100) {
        return 1;
    }

    // Check if starts with number (numbered section)
    if (trimmed.length() > 2 && isDigit(trimmed.substring(0, 1)) && trimmed.substring(1, 2) == ".") {
        return 3;
    }

    // Check if title case (subheader)
    if (isTitleCase(trimmed) && trimmed.length() < 80) {
        return 2;
    }

    return 0;
}

# Check if string is all uppercase
function isAllUppercase(string text) returns boolean {
    foreach string:Char char in text {
        if (char >= "a" && char <= "z") {
            return false;
        }
    }
    return text.length() > 0;
}

# Check if character is a digit
function isDigit(string char) returns boolean {
    return char >= "0" && char <= "9";
}

# Check if string is title case (simplified)
function isTitleCase(string text) returns boolean {
    if (text.length() == 0) {
        return false;
    }

    string firstChar = text.substring(0, 1);
    return firstChar >= "A" && firstChar <= "Z";
}

# Get character position of a line in text (simplified)
function getLinePosition(string text, int lineNumber) returns int {
    string[] lines = splitStringByNewlines(text);
    int position = 0;

    foreach int i in 0 ..< lineNumber {
        if (i < lines.length()) {
            position += lines[i].length() + 1; // +1 for newline
        }
    }

    return position;
}

# Count table lines starting from given position
function countTableLines(string[] lines, int startIndex) returns int {
    int count = 0;
    int i = startIndex;

    while (i < lines.length() && isTableRow(lines[i])) {
        count += 1;
        i += 1;
    }

    return count > 0 ? count : 1;
}

# Extract table title from surrounding lines
function extractTableTitle(string[] lines, int tableStartIndex) returns string {
    // Look for title in the lines before the table
    foreach int i in 1 ... 3 {
        int titleIndex = tableStartIndex - i;
        if (titleIndex >= 0 && titleIndex < lines.length()) {
            string line = lines[titleIndex].trim();
            if (line.length() > 0 && !isTableRow(line)) {
                return line;
            }
        }
    }
    return "Table " + tableStartIndex.toString();
}

# Count columns in a table row (simplified)
function countColumns(string row) returns int {
    if (row.includes("|")) {
        return splitStringByPipe(row).length();
    } else if (row.includes("\t")) {
        return splitStringByTab(row).length();
    } else {
        return splitStringByMultipleSpaces(row).length();
    }
}

# Split string by pipe character
function splitStringByPipe(string text) returns string[] {
    string[] parts = [];
    string currentPart = "";

    foreach string:Char char in text {
        if (char == "|") {
            parts.push(currentPart);
            currentPart = "";
        } else {
            currentPart += char;
        }
    }

    if (currentPart.length() > 0) {
        parts.push(currentPart);
    }

    return parts;
}

# Split string by tab character
function splitStringByTab(string text) returns string[] {
    string[] parts = [];
    string currentPart = "";

    foreach string:Char char in text {
        if (char == "\t") {
            parts.push(currentPart);
            currentPart = "";
        } else {
            currentPart += char;
        }
    }

    if (currentPart.length() > 0) {
        parts.push(currentPart);
    }

    return parts;
}

# Split string by multiple spaces
function splitStringByMultipleSpaces(string text) returns string[] {
    string[] parts = [];
    string currentPart = "";
    int spaceCount = 0;

    foreach string:Char char in text {
        if (char == " ") {
            spaceCount += 1;
            if (spaceCount >= 2) {
                if (currentPart.length() > 0) {
                    parts.push(currentPart);
                    currentPart = "";
                }
                spaceCount = 0;
            }
        } else {
            if (spaceCount == 1) {
                currentPart += " ";
            }
            currentPart += char;
            spaceCount = 0;
        }
    }

    if (currentPart.length() > 0) {
        parts.push(currentPart);
    }

    return parts;
}

# Classify document type based on content
function classifyDocumentType(string text) returns string {
    string upperText = text.toUpperAscii();

    if (upperText.includes("INCOME TAX ACT") || upperText.includes("INLAND REVENUE")) {
        return "income_tax_regulation";
    } else if (upperText.includes("VALUE ADDED TAX") || upperText.includes("VAT")) {
        return "vat_regulation";
    } else if (upperText.includes("PAY AS YOU EARN") || upperText.includes("PAYE")) {
        return "paye_regulation";
    } else if (upperText.includes("FORM") || upperText.includes("RETURN")) {
        return "tax_form";
    } else {
        return "general_tax_document";
    }
}

# Fixed-size chunking fallback
function performFixedSizeChunking(string text, ChunkConfig config, string documentId) returns DocumentChunk[] {
    DocumentChunk[] chunks = [];
    int chunkSize = config.maxTokens * 4; // Approximate character count
    int position = 0;
    int sequence = 1;

    while (position < text.length()) {
        int endPos = position + chunkSize;
        if (endPos > text.length()) {
            endPos = text.length();
        }

        string chunkText = text.substring(position, endPos);
        DocumentChunk chunk = createChunk(chunkText, position, sequence, config, documentId);
        chunks.push(chunk);

        position = endPos;
        sequence += 1;
    }

    return chunks;
}

# Hybrid chunking approach
function performHybridChunking(string text, DocumentStructure structure, ChunkConfig config, string documentId)
    returns DocumentChunk[] {
    // Start with semantic chunking, fallback to fixed-size for large sections
    DocumentChunk[] semanticChunks = performStructureBasedChunking(text, structure, config, documentId);
    DocumentChunk[] finalChunks = [];

    foreach DocumentChunk chunk in semanticChunks {
        if (chunk.tokenCount > config.maxTokens * 15 / 10) { // 1.5 times max tokens
            // Split large chunks using fixed-size approach
            DocumentChunk[] subChunks = performFixedSizeChunking(chunk.chunkText, config, chunk.id);
            finalChunks.push(...subChunks);
        } else {
            finalChunks.push(chunk);
        }
    }

    return finalChunks;
}
