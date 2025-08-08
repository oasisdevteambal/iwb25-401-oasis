import ballerina/http;
import ballerina/jballerina.java;
import ballerina/jballerina.java.arrays as jarrays;
import ballerina/log;
import ballerina/mime;
import ballerina/time;

// No storage needed - documents are processed immediately

// Document extraction result types
type DocumentExtractionResult record {
    string extractedText;
    DocumentStructure structure;
    int totalPages;
    string[] sections;
    TableData[] tables;
    ImageData[] images;
    map<string> metadata;
};

type DocumentStructure record {
    string title;
    string[] headers;
    string[] sections;
    int[] pageBreaks;
    map<string> metadata;
};

type TableData record {
    string[][] cells;
    string[] headers;
    int startPage;
    int endPage;
    map<string> metadata;
};

type ImageData record {
    string imageId;
    string format;
    int width;
    int height;
    int page;
    map<string> metadata;
};

// Document structure analysis types
type TaxDocumentStructure record {
    TaxDocumentType documentType;
    string[] mainSections;
    TaxSection[] sections;
    string[] definitions;
    string[] exemptions;
    TaxRate[] rates;
    CalculationRule[] calculations;
    map<string> metadata;
};

enum TaxDocumentType {
    INCOME_TAX = "income_tax",
    VAT = "vat",
    PAYE = "paye",
    WHT = "withholding_tax",
    NBT = "nation_building_tax",
    SSCL = "social_security_levy",
    REGULATIONS = "regulations",
    CIRCULAR = "circular",
    UNKNOWN = "unknown"
}

type TaxSection record {
    string sectionNumber;
    string title;
    string content;
    string[] subsections;
    int startPosition;
    int endPosition;
    map<string> metadata;
};

type TaxRate record {
    string rateType;
    decimal percentage;
    string currency;
    string description;
    string? conditions;
    string? effectiveDate;
};

type CalculationRule record {
    string ruleId;
    string title;
    string formula;
    string description;
    string[] variables;
    map<string> metadata;
};

// ============================================================================
// Java Interop Functions for Document Extractor Library
// ============================================================================

# Extract content from any supported document format using InteropBridge
#
# + documentData - The document content as handle  
# + fileName - The filename as handle
# + return - Handle to DocumentExtractionResult or error
public isolated function extractDocumentContentInternal(handle documentData, handle fileName)
    returns handle|error = @java:Method {
    'class: "com.oasis.document.extractor.InteropBridge",
    name: "extractContent",
    paramTypes: ["java.lang.Object", "java.lang.Object"]
} external;

# Check if a file format is supported by the extraction library (internal)
#
# + fileName - The filename to check as handle
# + return - true if format is supported, false otherwise
public isolated function isSupportedFormatInternal(handle fileName) returns boolean = @java:Method {
    'class: "com.oasis.document.extractor.InteropBridge",
    name: "isSupportedFormat",
    paramTypes: ["java.lang.Object"]
} external;

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
# + return - Handle to DocumentStructure
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
# + return - Handle to error message string
public isolated function getErrorMessage(handle result) returns handle = @java:Method {
    'class: "com.oasis.document.extractor.DocumentExtractionResult",
    name: "getErrorMessage"
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

# Get document metadata
#
# + result - Handle to DocumentExtractionResult
# + return - Handle to metadata map
public isolated function getMetadata(handle result) returns handle = @java:Method {
    'class: "com.oasis.document.extractor.DocumentExtractionResult",
    name: "getMetadata"
} external;

// ============================================================================
// Document extraction wrapper functions
// ============================================================================

# Extract content from any supported document format (convenience wrapper)
#
# + documentData - The document content as byte array
# + fileName - The filename for format detection
# + return - Handle to DocumentExtractionResult or error
function extractDocumentContentSafe(byte[] documentData, string fileName)
    returns handle|error {
    // Create Java byte array and string handles
    handle byteArrayHandle = check jarrays:toHandle(documentData, "byte");
    handle stringHandle = java:fromString(fileName);
    return extractDocumentContentInternal(byteArrayHandle, stringHandle);
}

# Check if a file format is supported (convenience wrapper)
#
# + fileName - The filename to check
# + return - true if format is supported, false otherwise
function isSupportedFormat(string fileName) returns boolean {
    handle stringHandle = java:fromString(fileName);
    return isSupportedFormatInternal(stringHandle);
}

# Get extracted text as string safely
#
# + extractionResult - Handle to DocumentExtractionResult
# + return - Extracted text or empty string if error
function getExtractedTextSafe(handle extractionResult) returns string {
    handle textData = getExtractedText(extractionResult);
    return java:toString(textData) ?: "";
}

# Get content type as string safely
#
# + extractionResult - Handle to DocumentExtractionResult
# + return - Content type or empty string if error
function getContentTypeSafe(handle extractionResult) returns string {
    handle contentTypeData = getContentType(extractionResult);
    return java:toString(contentTypeData) ?: "";
}

// Document service for handling file uploads and immediate processing
service /api/v1/documents on httpListener {

    # Upload and immediately process a document (PDF or Word) for tax rule extraction
    # + request - HTTP request containing the file upload
    # + return - Processing result with extracted content
    resource function post upload(http:Request request) returns json|http:BadRequest|http:InternalServerError {
        do {
            log:printInfo("Processing document upload and extraction request");

            // Check content type
            string contentType = request.getContentType();
            if (!contentType.startsWith("multipart/form-data")) {
                return <http:BadRequest>{
                    body: {
                        "error": "Content-Type must be multipart/form-data",
                        "message": "Please upload a file using multipart form data"
                    }
                };
            }

            // Extract multipart entities
            mime:Entity[] bodyParts = check request.getBodyParts();

            if (bodyParts.length() == 0) {
                return <http:BadRequest>{
                    body: {
                        "error": "No file uploaded",
                        "message": "Please select a file to upload"
                    }
                };
            }

            // Find the file part and optional filename part
            mime:Entity? filePart = ();
            string? providedFilename = ();

            foreach mime:Entity part in bodyParts {
                string|mime:HeaderNotFoundError contentDispositionResult = part.getHeader("Content-Disposition");
                if (contentDispositionResult is string) {
                    string contentDisposition = contentDispositionResult;

                    // Check if this is the filename field
                    if (contentDisposition.includes("name=\"filename\"")) {
                        byte[]|mime:ParserError textContent = part.getByteArray();
                        if (textContent is byte[]) {
                            string|error filenameResult = string:fromBytes(textContent);
                            if (filenameResult is string) {
                                providedFilename = filenameResult.trim();
                            }
                        }
                    }
                    // Check if this is the file field
                    else if (contentDisposition.includes("name=\"file\"")) {
                        filePart = part;
                    }
                }
            }

            // If no dedicated file part found, use the first part that has a filename
            if (filePart is ()) {
                foreach mime:Entity part in bodyParts {
                    string|mime:HeaderNotFoundError contentDispositionResult = part.getHeader("Content-Disposition");
                    if (contentDispositionResult is string) {
                        string contentDisposition = contentDispositionResult;
                        if (contentDisposition.includes("filename=")) {
                            filePart = part;
                            break;
                        }
                    }
                }
            }

            if (filePart is ()) {
                return <http:BadRequest>{
                    body: {
                        "error": "No file found",
                        "message": "Could not find file in upload"
                    }
                };
            }

            // Get content disposition to extract filename
            string|mime:HeaderNotFoundError contentDispositionResult = filePart.getHeader("Content-Disposition");
            if (contentDispositionResult is mime:HeaderNotFoundError) {
                return <http:BadRequest>{
                    body: {
                        "error": "Content-Disposition header not found",
                        "message": "Could not find Content-Disposition header in file upload"
                    }
                };
            }
            string contentDisposition = contentDispositionResult;

            // Try to get filename from the provided filename field first, then from Content-Disposition
            string? filename = providedFilename;
            if (filename is ()) {
                filename = extractFilename(contentDisposition);
            }

            if (filename is ()) {
                return <http:BadRequest>{
                    body: {
                        "error": "Filename not found",
                        "message": "Could not extract filename from upload. Please provide filename in form data."
                    }
                };
            }

            // Validate file type
            string fileExtension = getFileExtension(filename);
            if (!isValidFileType(fileExtension)) {
                return <http:BadRequest>{
                    body: {
                        "error": "Invalid file type",
                        "message": "Only PDF and Word documents (.pdf, .doc, .docx) are supported",
                        "supportedTypes": [".pdf", ".doc", ".docx"]
                    }
                };
            }

            // Get file content
            byte[] fileContent = check filePart.getByteArray();

            // Validate file size (max 10MB)
            if (fileContent.length() > 10 * 1024 * 1024) {
                return <http:BadRequest>{
                    body: {
                        "error": "File too large",
                        "message": "File size must be less than 10MB",
                        "maxSize": "10MB"
                    }
                };
            }

            // Get actual content type
            string|mime:HeaderNotFoundError fileContentType = filePart.getContentType();
            string actualContentType = fileContentType is string ? fileContentType : "application/octet-stream";

            log:printInfo("Starting immediate document processing for: " + filename);

            // Step 1: Extract text from document
            log:printInfo("Step 1: Extracting text from document");
            DocumentExtractionResult extractionResult = check extractTextByFileType(fileContent, actualContentType);

            // Step 2: Analyze document structure
            log:printInfo("Step 2: Analyzing document structure");
            TaxDocumentStructure structure = check analyzeTaxDocumentStructure(extractionResult);

            // Step 3: Prepare processing results
            log:printInfo("Document processing completed successfully");

            json result = {
                "success": true,
                "message": "Document processed successfully",
                "document": {
                    "filename": filename,
                    "size": fileContent.length(),
                    "type": fileExtension,
                    "contentType": actualContentType,
                    "processedAt": time:utcNow()
                },
                "extraction": {
                    "totalPages": extractionResult.totalPages,
                    "extractedTextLength": extractionResult.extractedText.length(),
                    "sectionsFound": extractionResult.sections.length(),
                    "tablesFound": extractionResult.tables.length(),
                    "extractedText": extractionResult.extractedText,
                    "extractedTextPreview": extractionResult.extractedText.length() > 200 ?
                        extractionResult.extractedText.substring(0, 200) + "..." :
                        extractionResult.extractedText
                },
                "analysis": {
                    "documentType": structure.documentType,
                    "mainSectionsCount": structure.mainSections.length(),
                    "definitionsFound": structure.definitions.length(),
                    "exemptionsFound": structure.exemptions.length(),
                    "taxRatesFound": structure.rates.length(),
                    "calculationRulesFound": structure.calculations.length(),
                    "mainSections": structure.mainSections,
                    "definitions": structure.definitions,
                    "exemptions": structure.exemptions,
                    "taxRatesCount": structure.rates.length(),
                    "calculationsCount": structure.calculations.length()
                },
                "metadata": extractionResult.metadata
            };

            return result;

        } on fail error e {
            log:printError("Error processing document: " + e.message());
            return <http:InternalServerError>{
                body: {
                    "error": "Processing failed",
                    "message": "An error occurred while processing the document",
                    "details": e.message()
                }
            };
        }
    }
}

// Helper function to extract filename from Content-Disposition header
function extractFilename(string contentDisposition) returns string? {
    // Simple string parsing without regex
    // Look for filename= or filename*= patterns
    int filenamePos = contentDisposition.indexOf("filename=") ?: -1;
    if (filenamePos == -1) {
        // Try filename*= for encoded filenames
        filenamePos = contentDisposition.indexOf("filename*=") ?: -1;
        if (filenamePos == -1) {
            return ();
        }
        filenamePos += "filename*=".length();
    } else {
        filenamePos += "filename=".length();
    }

    // Extract the filename part
    string remainingPart = contentDisposition.substring(filenamePos);

    // Find the end of filename (semicolon or end of string)
    int endPos = remainingPart.indexOf(";") ?: remainingPart.length();
    string filename = remainingPart.substring(0, endPos).trim();

    // Remove quotes if present
    if (filename.startsWith("\"") && filename.endsWith("\"")) {
        filename = filename.substring(1, filename.length() - 1);
    }

    // Handle encoded filenames (basic UTF-8 support)
    if (filename.startsWith("UTF-8''")) {
        filename = filename.substring(7); // Remove UTF-8'' prefix
        // Basic URL decode - just handle %20 for spaces
        int spacePos = filename.indexOf("%20") ?: -1;
        while (spacePos >= 0) {
            string before = filename.substring(0, spacePos);
            string after = filename.substring(spacePos + 3);
            filename = before + " " + after;
            spacePos = filename.indexOf("%20") ?: -1;
        }
    }

    return filename.length() > 0 ? filename : ();
}

// Helper function to get file extension
function getFileExtension(string filename) returns string {
    int? lastDotIndexResult = filename.lastIndexOf(".");
    if (lastDotIndexResult is ()) {
        return "";
    }
    int lastDotIndex = lastDotIndexResult;
    return filename.substring(lastDotIndex).toLowerAscii();
}

// Helper function to validate file type
function isValidFileType(string extension) returns boolean {
    string[] validTypes = [".pdf", ".doc", ".docx"];
    return validTypes.indexOf(extension) != ();
}

// Text extraction functions - Using Real Java Document Extractor Library
function extractTextByFileType(byte[] fileContent, string contentType) returns DocumentExtractionResult|error {
    log:printInfo("Starting REAL document extraction for content type: " + contentType + " (file size: " + fileContent.length().toString() + " bytes)");

    // Determine filename based on content type for the Java library
    string filename = "document.unknown";
    if (contentType.includes("pdf")) {
        filename = "document.pdf";
    } else if (contentType.includes("word") || contentType.includes("officedocument.wordprocessingml")) {
        filename = "document.docx";
    } else if (contentType.includes("msword")) {
        filename = "document.doc";
    } else if (contentType.includes("text")) {
        filename = "document.txt";
    }

    // Step 1: Validate format support
    if (!isSupportedFormat(filename)) {
        return error("Unsupported file format: " + contentType + " (detected as: " + filename + ")");
    }

    // Step 2: Extract using Java library
    handle|error extractionResult = extractDocumentContentSafe(fileContent, filename);

    if (extractionResult is error) {
        log:printError("Java document extraction failed: " + extractionResult.message());
        return error("Document extraction failed: " + extractionResult.message());
    }

    // Step 3: Verify extraction success (Java level success, not content success)
    boolean successful = isExtractionSuccessful(extractionResult);
    if (!successful) {
        handle errorMsgHandle = getErrorMessage(extractionResult);
        string errorMsg = java:toString(errorMsgHandle) ?: "Unknown extraction error";
        log:printError("Java document extraction failed: " + errorMsg);
        return error("Java document extraction failed: " + errorMsg);
    }

    // Step 4: Extract all data from the Java result
    string extractedText = getExtractedTextSafe(extractionResult);
    string detectedContentType = getContentTypeSafe(extractionResult);

    log:printInfo("Successfully extracted " + extractedText.length().toString() + " characters from document");
    log:printInfo("Detected content type: " + detectedContentType);

    // Debug: Print first 200 characters if any text was extracted
    if (extractedText.length() > 0) {
        string preview = extractedText.length() > 200 ? extractedText.substring(0, 200) + "..." : extractedText;
        log:printInfo("Extracted text preview: " + preview);
    } else {
        log:printWarn("No text content was extracted from the document - this might be an image-based PDF or require OCR");
    }

    // Step 5: Build comprehensive result structure
    // Handle case where extraction succeeds but text is empty (common with image-based PDFs)
    if (extractedText.length() == 0) {
        extractedText = "No text content found in document. This might be:\n" +
                        "- An image-based PDF that requires OCR\n" +
                        "- An encrypted or protected document\n" +
                        "- A document with only images/graphics\n" +
                        "File information: " + detectedContentType + " (" + fileContent.length().toString() + " bytes)";
    }
    DocumentExtractionResult result = {
        extractedText: extractedText,
        structure: {
            title: "Extracted Document",
            headers: extractHeaders(extractedText),
            sections: extractSections(extractedText),
            pageBreaks: [1], // Would extract from Java structure
            metadata: {
                "detectedContentType": detectedContentType,
                "originalContentType": contentType,
                "extractionMethod": "java_tika_library",
                "filename": filename
            }
        },
        totalPages: 1, // Would extract from Java structure
        sections: extractSections(extractedText),
        tables: [], // Would parse from Java TableData objects
        images: [], // Would parse from Java ImageData objects
        metadata: {
            "fileSize": fileContent.length().toString(),
            "extractedAt": time:utcNow().toString(),
            "extractionType": "real_java_library",
            "detectedContentType": detectedContentType,
            "textLength": extractedText.length().toString(),
            "processingStatus": "success"
        }
    };

    log:printInfo("Document extraction completed successfully using real Java library");
    return result;
}

// Helper functions for processing extracted text
function extractHeaders(string text) returns string[] {
    string[] headers = [];
    string[] lines = [];

    // Split text into lines
    int currentPos = 0;
    while (currentPos < text.length()) {
        int newlinePos = text.indexOf("\n", currentPos) ?: text.length();
        string line = text.substring(currentPos, newlinePos).trim();
        if (line.length() > 0) {
            lines.push(line);
        }
        currentPos = newlinePos + 1;
        if (lines.length() > 100) { // Limit processing
            break;
        }
    }

    // Extract potential headers (lines that look like titles/headers)
    foreach string line in lines {
        string lowerLine = line.toLowerAscii();
        if (line.length() > 5 && line.length() < 100) {
            if (lowerLine.startsWith("chapter ") ||
                lowerLine.startsWith("section ") ||
                lowerLine.startsWith("part ") ||
                lowerLine.includes("tax") ||
                lowerLine.includes("income") ||
                lowerLine.includes("regulation")) {
                headers.push(line);
            }
        }
        if (headers.length() > 10) { // Limit headers
            break;
        }
    }

    return headers.length() > 0 ? headers : ["Extracted Content"];
}

function extractSections(string text) returns string[] {
    string[] sections = [];

    // Simple section extraction - split by common section indicators
    if (text.includes("CHAPTER ") || text.includes("SECTION ")) {
        // Split by chapters/sections
        string[] parts = [];
        int currentPos = 0;

        while (currentPos < text.length()) {
            int chapterPos = text.indexOf("CHAPTER ", currentPos) ?: -1;
            int sectionPos = text.indexOf("SECTION ", currentPos) ?: -1;

            int nextPos = -1;
            if (chapterPos != -1 && sectionPos != -1) {
                nextPos = chapterPos < sectionPos ? chapterPos : sectionPos;
            } else if (chapterPos != -1) {
                nextPos = chapterPos;
            } else if (sectionPos != -1) {
                nextPos = sectionPos;
            }

            if (nextPos == -1) {
                // Add remaining text
                string remaining = text.substring(currentPos).trim();
                if (remaining.length() > 10) {
                    parts.push(remaining.substring(0, remaining.length() > 200 ? 200 : remaining.length()));
                }
                break;
            }

            if (nextPos > currentPos) {
                string section = text.substring(currentPos, nextPos).trim();
                if (section.length() > 10) {
                    parts.push(section.substring(0, section.length() > 200 ? 200 : section.length()));
                }
            }

            currentPos = nextPos + 8; // Move past "CHAPTER " or "SECTION "
            if (parts.length() > 10) { // Limit sections
                break;
            }
        }

        sections = parts;
    } else {
        // Simple paragraph-based sections
        string[] paragraphs = [];
        int currentPos = 0;

        while (currentPos < text.length()) {
            int doubleNewlinePos = text.indexOf("\n\n", currentPos) ?: text.length();
            string paragraph = text.substring(currentPos, doubleNewlinePos).trim();

            if (paragraph.length() > 20) {
                paragraphs.push(paragraph.substring(0, paragraph.length() > 300 ? 300 : paragraph.length()));
            }

            currentPos = doubleNewlinePos + 2;
            if (paragraphs.length() > 5) { // Limit paragraphs
                break;
            }
        }

        sections = paragraphs.length() > 0 ? paragraphs : ["Main Content"];
    }

    return sections.length() > 0 ? sections : ["Extracted Content"];
}

// ============================================================================
// OLD PLACEHOLDER FUNCTIONS - REPLACED BY REAL JAVA LIBRARY
// These functions are kept for reference but are no longer used
// The real extraction is now handled by extractTextByFileType() above
// ============================================================================

// function extractFromPDF(byte[] pdfContent) returns DocumentExtractionResult|error {
//     log:printInfo("Extracting text from PDF document");
//     // This function has been replaced by the Java library implementation above
//     return error("extractFromPDF function deprecated - use extractTextByFileType instead");
// }

function analyzeTaxDocumentStructure(DocumentExtractionResult extractionResult) returns TaxDocumentStructure|error {
    log:printInfo("Analyzing tax document structure");

    string text = extractionResult.extractedText;

    // Determine document type
    TaxDocumentType docType = determineDocumentType(text);

    // Extract components
    string[] mainSections = extractMainSections(text);
    TaxSection[] sections = extractDetailedSections(text, extractionResult.structure);
    string[] definitions = extractDefinitions(text);
    string[] exemptions = extractExemptions(text);
    TaxRate[] rates = extractTaxRates(text);
    CalculationRule[] calculations = extractCalculationRules(text);

    return {
        documentType: docType,
        mainSections: mainSections,
        sections: sections,
        definitions: definitions,
        exemptions: exemptions,
        rates: rates,
        calculations: calculations,
        metadata: {
            "totalPages": extractionResult.totalPages.toString(),
            "extractedAt": "2025-08-05T10:00:00Z",
            "analysisVersion": "1.0"
        }
    };
}

function determineDocumentType(string text) returns TaxDocumentType {
    string lowerText = text.toLowerAscii();

    if (lowerText.includes("income tax") || lowerText.includes("inland revenue")) {
        return INCOME_TAX;
    } else if (lowerText.includes("value added tax") || lowerText.includes("vat")) {
        return VAT;
    } else if (lowerText.includes("pay as you earn") || lowerText.includes("paye")) {
        return PAYE;
    }

    return UNKNOWN;
}

function extractMainSections(string text) returns string[] {
    string[] sections = [];
    // Simple line extraction using substring and indexOf
    int currentPos = 0;
    while (true) {
        int newlinePos = text.indexOf("\n", currentPos) ?: -1;
        if (newlinePos == -1) {
            // Check last line
            string lastLine = text.substring(currentPos).trim();
            if (lastLine.toLowerAscii().startsWith("chapter ") ||
                lastLine.toLowerAscii().startsWith("section ")) {
                sections.push(lastLine);
            }
            break;
        }

        string line = text.substring(currentPos, newlinePos).trim();
        if (line.toLowerAscii().startsWith("chapter ") ||
            line.toLowerAscii().startsWith("section ")) {
            sections.push(line);
        }

        currentPos = newlinePos + 1;
    }

    return sections;
}

function extractDetailedSections(string text, DocumentStructure structure) returns TaxSection[] {
    TaxSection[] sections = [];

    foreach int i in 0 ..< structure.sections.length() {
        string sectionTitle = structure.sections[i];
        int startPos = text.indexOf(sectionTitle) ?: 0;
        int endPos = text.length();

        if (i < structure.sections.length() - 1) {
            string nextSection = structure.sections[i + 1];
            int nextPos = text.indexOf(nextSection, startPos + sectionTitle.length()) ?: text.length();
            if (nextPos > 0) {
                endPos = nextPos;
            }
        }

        string content = "";
        if (startPos >= 0) {
            content = text.substring(startPos, endPos).trim();
        }

        TaxSection section = {
            sectionNumber: (i + 1).toString(),
            title: sectionTitle,
            content: content,
            subsections: [],
            startPosition: startPos >= 0 ? startPos : 0,
            endPosition: endPos,
            metadata: {"length": content.length().toString()}
        };

        sections.push(section);
    }

    return sections;
}

function extractDefinitions(string text) returns string[] {
    string[] definitions = [];
    // Simple line extraction using substring and indexOf
    int currentPos = 0;
    while (true) {
        int newlinePos = text.indexOf("\n", currentPos) ?: -1;
        if (newlinePos == -1) {
            // Check last line
            string lastLine = text.substring(currentPos).trim();
            if (lastLine.includes("means") && lastLine.includes("\"")) {
                definitions.push(lastLine);
            }
            break;
        }

        string line = text.substring(currentPos, newlinePos).trim();
        if (line.includes("means") && line.includes("\"")) {
            definitions.push(line);
        }

        currentPos = newlinePos + 1;
    }

    return definitions;
}

function extractExemptions(string text) returns string[] {
    string[] exemptions = [];
    // Simple line extraction using substring and indexOf
    int currentPos = 0;
    while (true) {
        int newlinePos = text.indexOf("\n", currentPos) ?: -1;
        if (newlinePos == -1) {
            // Check last line
            string lastLine = text.substring(currentPos).trim();
            string lowerLine = lastLine.toLowerAscii();
            if (lowerLine.includes("exempt") || lowerLine.includes("deduction")) {
                exemptions.push(lastLine);
            }
            break;
        }

        string line = text.substring(currentPos, newlinePos).trim();
        string lowerLine = line.toLowerAscii();
        if (lowerLine.includes("exempt") || lowerLine.includes("deduction")) {
            exemptions.push(line);
        }

        currentPos = newlinePos + 1;
    }

    return exemptions;
}

function extractTaxRates(string text) returns TaxRate[] {
    TaxRate[] rates = [];
    // Simple line extraction using substring and indexOf
    int currentPos = 0;
    while (true) {
        int newlinePos = text.indexOf("\n", currentPos) ?: -1;
        if (newlinePos == -1) {
            // Check last line
            string lastLine = text.substring(currentPos).trim();
            if (lastLine.includes("%")) {
                // Extract percentage from line
                int percentPos = lastLine.indexOf("%") ?: -1;
                if (percentPos > 0) {
                    // Look backwards for the number
                    string beforePercent = lastLine.substring(0, percentPos);
                    int spacePos = beforePercent.lastIndexOf(" ") ?: 0;
                    string numberStr = beforePercent.substring(spacePos).trim();
                    decimal|error percentage = decimal:fromString(numberStr);

                    if (percentage is decimal) {
                        TaxRate rate = {
                            rateType: "percentage",
                            percentage: percentage,
                            currency: "LKR",
                            description: lastLine,
                            conditions: (),
                            effectiveDate: ()
                        };
                        rates.push(rate);
                    }
                }
            }
            break;
        }

        string line = text.substring(currentPos, newlinePos).trim();
        if (line.includes("%")) {
            // Extract percentage from line
            int percentPos = line.indexOf("%") ?: -1;
            if (percentPos > 0) {
                // Look backwards for the number
                string beforePercent = line.substring(0, percentPos);
                int spacePos = beforePercent.lastIndexOf(" ") ?: 0;
                string numberStr = beforePercent.substring(spacePos).trim();
                decimal|error percentage = decimal:fromString(numberStr);

                if (percentage is decimal) {
                    TaxRate rate = {
                        rateType: "percentage",
                        percentage: percentage,
                        currency: "LKR",
                        description: line,
                        conditions: (),
                        effectiveDate: ()
                    };
                    rates.push(rate);
                }
            }
        }

        currentPos = newlinePos + 1;
    }

    return rates;
}

function extractCalculationRules(string text) returns CalculationRule[] {
    CalculationRule[] calculations = [];
    // Simple line extraction using substring and indexOf
    int currentPos = 0;
    while (true) {
        int newlinePos = text.indexOf("\n", currentPos) ?: -1;
        if (newlinePos == -1) {
            // Check last line
            string lastLine = text.substring(currentPos).trim();
            string lowerLine = lastLine.toLowerAscii();
            if (lowerLine.includes("formula") || lowerLine.includes("calculation") || lastLine.includes("=")) {
                CalculationRule rule = {
                    ruleId: "calc_" + calculations.length().toString(),
                    title: "Tax Calculation Rule",
                    formula: lastLine,
                    description: lastLine,
                    variables: ["income", "tax", "rate"],
                    metadata: {"extractedFrom": "document_analysis"}
                };
                calculations.push(rule);
            }
            break;
        }

        string line = text.substring(currentPos, newlinePos).trim();
        string lowerLine = line.toLowerAscii();
        if (lowerLine.includes("formula") || lowerLine.includes("calculation") || line.includes("=")) {
            CalculationRule rule = {
                ruleId: "calc_" + calculations.length().toString(),
                title: "Tax Calculation Rule",
                formula: line,
                description: line,
                variables: ["income", "tax", "rate"],
                metadata: {"extractedFrom": "document_analysis"}
            };
            calculations.push(rule);
        }

        currentPos = newlinePos + 1;
    }

    return calculations;
}
