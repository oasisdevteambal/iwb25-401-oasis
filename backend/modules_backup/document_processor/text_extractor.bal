import ballerina/jballerina.java;
import ballerina/log;

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
