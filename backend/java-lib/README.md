# Custom Document Extractor Library for Ballerina

A specialized Java library designed for seamless integration with **Ballerina** applications, providing comprehensive document text extraction using Apache Tika 2.9.1, specifically optimized for Sri Lankan tax document processing.

## 🎯 Purpose & Ballerina Integration

This library is purpose-built as a **custom Java interop library** for Ballerina applications, showcasing the power of Ballerina's Java interoperability capabilities. It demonstrates how to create specialized Java libraries that integrate seamlessly with Ballerina's type system and error handling.

## Features

### Core Capabilities
- **Ballerina-Optimized**: Designed specifically for Ballerina Java interop with `InteropBridge`
- **Unified Processing**: Uses Apache Tika 2.9.1 for comprehensive document extraction across multiple formats
- **Multi-Format Support**: PDF, Word (.doc/.docx), Excel (.xls/.xlsx), PowerPoint, and other formats
- **Advanced Metadata**: Extracts comprehensive document metadata including author, creation date, language detection
- **Structure Analysis**: Identifies headers, sections, tables, and document organization
- **Table Extraction**: Advanced table detection and extraction from HTML output
- **Image Detection**: Identifies and catalogs embedded images and graphics
- **Language Detection**: Automatic language detection for multilingual documents
- **Tax Document Analysis**: Specialized processing for Sri Lankan tax documents

### Ballerina Integration Features
- **InteropBridge**: Dedicated bridge class for seamless Ballerina-Java communication
- **Type Safety**: Java types designed to work with Ballerina's type system
- **Error Handling**: Proper exception handling that integrates with Ballerina error handling
- **Memory Efficiency**: Optimized for Ballerina's memory management

### Sri Lankan Tax Optimization
- **Document Type Detection**: Automatic identification of Income Tax, VAT, PAYE, WHT, NBT, SSCL documents
- **Multilingual Support**: Handles both English and Sinhala tax documents
- **Structure Recognition**: Identifies common tax document patterns and sections
- **Critical Application Mode**: Explicit failure handling for corrupted or unsupported documents

## Architecture

### Core Classes

#### InteropBridge (Ballerina Integration Layer)
- **Primary interface for Ballerina applications**
- Provides type-safe method signatures for Ballerina Java interop
- Handles object conversion between Ballerina and Java types
- Methods: `extractContentFromBytes()`, `isSupportedFormatString()`

#### TikaDocumentExtractor
- Main extraction engine using Apache Tika
- Handles all document formats through unified API
- Provides comprehensive extraction with metadata, structure, and content analysis

#### UnifiedDocumentExtractor
- High-level interface for document processing
- Provides format-specific optimizations (`extractFromPDF`, `extractFromWord`, `extractFromExcel`)
- Includes Sri Lankan tax document enhancements
- Critical application mode with explicit error handling

#### Format-Specific Extractors
- **PDFTextExtractor**: PDF-focused extraction (delegates to TikaDocumentExtractor)
- **WordTextExtractor**: Word document extraction (delegates to TikaDocumentExtractor)

#### Data Models
- **DocumentExtractionResult**: Comprehensive extraction results
- **DocumentStructure**: Document organization and metadata
- **TikaExtractionInfo**: Technical extraction details
- **TableData**: Structured table information
- **ImageData**: Image metadata and references

## Critical Application Mode

This library is designed for critical tax applications where accuracy is paramount. Unlike typical document extractors that provide fallback content when processing fails, this library follows a **fail-fast approach**:

### Key Principles
- **Explicit Failures**: When document processing encounters errors, the library throws `IOException` with detailed error messages
- **No Fallback Content**: No partial or generic content is returned when extraction fails
- **User Notification**: Clear error messages inform users about document issues (corruption, password protection, unsupported formats)
- **Process Integrity**: The application can decide how to handle failures rather than receiving potentially incomplete data

### Error Scenarios
The library will explicitly fail and stop processing when encountering:
- Corrupted documents
- Password-protected files
- Unsupported formats
- Invalid file structures
- Extraction engine failures

### Benefits for Tax Applications
- **Data Accuracy**: Ensures only complete, accurate content is processed
- **Compliance**: Maintains data integrity for regulatory requirements
- **Reliability**: Prevents processing of potentially corrupted tax data
- **Transparency**: Clear visibility into document processing status

## Quick Start

### Prerequisites

- Java 17 or higher
- Maven 3.6 or higher

### Building the Library

```bash
# Navigate to the library directory
cd java-lib

# Build with Maven
mvn clean package

# This creates:
# - target/document-extractor-1.0.0.jar (library only)
# - target/document-extractor-optimized.jar (shaded JAR with dependencies)
```

### Using in Ballerina

1. Copy the optimized JAR to your Ballerina libs directory:
```bash
copy target\document-extractor-optimized.jar ..\libs\document-extractor.jar
```

2. Update your `Ballerina.toml`:
```toml
[[platform.java21.dependency]]
path = "./libs/document-extractor.jar"
```

3. Use in your Ballerina code:
```ballerina
import ballerina/jballerina.java;

// Primary extraction method using InteropBridge (recommended)
function extractDocumentContent(byte[] documentData, string fileName) 
    returns handle|error = @java:Method {
    'class: "com.oasis.document.extractor.InteropBridge",
    name: "extractContentFromBytes"
} external;

// Check if format is supported
function isSupportedFormat(string fileName) 
    returns boolean = @java:Method {
    'class: "com.oasis.document.extractor.InteropBridge",
    name: "isSupportedFormatString"
} external;

// Access extraction result data
function getExtractedText(handle result) returns string = @java:Method {
    'class: "com.oasis.document.extractor.DocumentExtractionResult",
    name: "getExtractedText"
} external;

function getContentType(handle result) returns string = @java:Method {
    'class: "com.oasis.document.extractor.DocumentExtractionResult",
    name: "getContentType"
} external;

function getDetectedLanguages(handle result) returns handle = @java:Method {
    'class: "com.oasis.document.extractor.DocumentExtractionResult",
    name: "getDetectedLanguages"
} external;

function isExtractionSuccessful(handle result) returns boolean = @java:Method {
    'class: "com.oasis.document.extractor.DocumentExtractionResult", 
    name: "isExtractionSuccessful"
} external;
```

## API Reference

### InteropBridge (Primary Ballerina Interface)

#### Methods
- `extractContentFromBytes(byte[] documentData, String fileName)` - Main extraction method optimized for Ballerina
- `isSupportedFormatString(String fileName)` - Check if format is supported (Ballerina-friendly)
- `extractContent(Object documentData, Object fileName)` - Legacy method with Object parameters
- `extractFromPDF(Object pdfData, Object fileName)` - PDF-specific extraction (legacy)
- `extractFromWord(Object wordData, Object fileName)` - Word-specific extraction (legacy)

### UnifiedDocumentExtractor (Core Engine)

#### Methods
- `extractContent(byte[] documentContent, String fileName)` - Universal document extraction
- `extractFromPDF(byte[] pdfData, String fileName)` - PDF-specific extraction
- `extractFromWord(byte[] wordData, String fileName)` - Word-specific extraction
- `extractFromExcel(byte[] excelData, String fileName)` - Excel-specific extraction
- `isSupportedFormat(String fileName)` - Check if format is supported
- `getSupportedExtensions()` - Get list of supported file extensions

### TikaDocumentExtractor (Core Engine)

#### Methods
- `extractContent(byte[] documentContent, String fileName)` - Core Tika-based extraction

### Format-Specific Extractors

#### PDFTextExtractor
- `extractText(byte[] pdfData)` - Extract from PDF with default filename
- `extractText(byte[] pdfData, String fileName)` - Extract from PDF with custom filename

#### WordTextExtractor  
- `extractText(byte[] wordData)` - Extract from Word with default filename
- `extractText(byte[] wordData, String fileName)` - Extract from Word with custom filename

### DocumentExtractionResult

#### Properties
- `extractedText: String` - Full extracted text content
- `structure: DocumentStructure` - Document organization metadata
- `contentType: String` - MIME type of the document
- `detectedLanguages: String[]` - Array of detected languages
- `tables: TableData[]` - Extracted table data
- `images: ImageData[]` - Image metadata
- `metadata: Map<String, String>` - Document metadata
- `extractionInfo: TikaExtractionInfo` - Technical extraction details
- `extractionSuccessful: boolean` - Success status
- `errorMessage: String` - Error message if extraction failed

### DocumentStructure

#### Properties
- `title: String` - Document title
- `headers: String[]` - Extracted headers
- `sections: String[]` - Document sections
- `author: String` - Document author
- `subject: String` - Document subject
- `creationDate: String` - Creation timestamp
- `modificationDate: String` - Last modification timestamp
- `metadata: Map<String, String>` - Additional metadata

### TikaExtractionInfo

#### Properties
- `parsedBy: String` - Parser class used by Tika
- `mediaType: String` - MIME type detected by Tika
- `hasImages: boolean` - Whether document contains images
- `hasTables: boolean` - Whether document contains tables
- `estimatedWordCount: int` - Estimated word count
- `encoding: String` - Text encoding used

### TableData

#### Properties
- `data: String[][]` - Table cell data
- `headers: String[]` - Table headers (if detected)
- `rowCount: int` - Number of rows
- `columnCount: int` - Number of columns
- `tableTitle: String` - Table title (if available)

### ImageData

#### Properties
- `imageId: String` - Unique image identifier
- `imageType: String` - Image format/type
- `width: int` - Image width (if available)
- `height: int` - Image height (if available)
- `description: String` - Image description/alt text
- `location: String` - Image location in document
- `extractTextFromPages(byte[] pdfData, int startPage, int endPage)` - Extract from specific pages

### WordTextExtractor

- `extractText(byte[] wordData)` - Extract text (auto-detects .doc/.docx)

## Dependencies

## Usage Examples

### Basic Document Extraction

```java
// Java usage
byte[] documentBytes = Files.readAllBytes(Paths.get("tax-document.pdf"));
DocumentExtractionResult result = UnifiedDocumentExtractor.extractContent(documentBytes, "tax-document.pdf");

if (result.isExtractionSuccessful()) {
    String text = result.getExtractedText();
    String contentType = result.getContentType();
    String[] languages = result.getDetectedLanguages();
    TableData[] tables = result.getTables();
    
    System.out.println("Extracted " + text.length() + " characters");
    System.out.println("Content type: " + contentType);
    System.out.println("Languages: " + String.join(", ", languages));
    System.out.println("Tables found: " + tables.length);
}
```

```ballerina
// Ballerina usage with InteropBridge (recommended)
byte[] documentContent = check io:fileReadBytes("tax-document.pdf");
handle result = check extractDocumentContent(documentContent, "tax-document.pdf");

if (isExtractionSuccessful(result)) {
    string extractedText = getExtractedText(result);
    string contentType = getContentType(result);

    log:printInfo(string `Extracted ${extractedText.length()} characters from ${contentType} document`);
} else {
    log:printError("Document extraction failed");
}
```

### Sri Lankan Tax Document Processing

```java
// Specialized processing for Sri Lankan tax documents
DocumentExtractionResult result = UnifiedDocumentExtractor.extractContent(documentBytes, "income-tax-act.pdf");

Map<String, String> metadata = result.getMetadata();
String taxType = metadata.get("sri-lanka-tax-type");

if ("income_tax".equals(taxType)) {
    // Process income tax document
    DocumentStructure structure = result.getStructure();
    String[] sections = structure.getSections();
    // ... process income tax specific content
}
```

## Dependencies

### Core Dependencies
- Apache Tika 2.9.1 (Core, Parsers, Language Detection)
- SLF4J 1.7.36 (API and Simple implementation)
- Apache Commons Compress 1.21

### Test Dependencies
- JUnit 4.13.2

## Development

### Building the Library

```bash
# Clean and compile
mvn clean compile

# Run tests
mvn test

# Package with dependencies
mvn package

# Install to local repository
mvn install
```

### Generating Optimized JAR

The Maven Shade plugin creates an optimized JAR with:
- All dependencies included
- Conflicting classes relocated to avoid conflicts
- Metadata cleaned up
- Optimized for Ballerina interop

### Project Structure

```
java-lib/
├── pom.xml
├── src/
│   ├── main/java/com/oasis/document/extractor/
│   │   ├── InteropBridge.java                  # Ballerina integration bridge
│   │   ├── TikaDocumentExtractor.java         # Core Tika engine
│   │   ├── UnifiedDocumentExtractor.java      # High-level interface
│   │   ├── PDFTextExtractor.java              # PDF-specific wrapper
│   │   ├── WordTextExtractor.java             # Word-specific wrapper
│   │   ├── DocumentExtractionResult.java      # Result model
│   │   ├── DocumentStructure.java             # Structure model
│   │   ├── TikaExtractionInfo.java            # Extraction metadata
│   │   ├── TableData.java                     # Table model
│   │   ├── TableInfo.java                     # Table information
│   │   ├── ImageData.java                     # Image model
│   │   └── WordExtractionResult.java          # Word-specific result
│   └── test/java/com/oasis/document/extractor/
│       └── DocumentExtractorTest.java
└── target/
    ├── document-extractor-1.0.0.jar           # Library only
    └── document-extractor-optimized.jar       # With dependencies
```

## Benefits of This Ballerina-Java Integration

### Advantages for Ballerina Applications
1. **Seamless Interop**: Custom InteropBridge designed specifically for Ballerina type system
2. **Type Safety**: Java types that map cleanly to Ballerina types
3. **Error Handling**: Proper exception handling that integrates with Ballerina's error model
4. **Performance**: Direct byte array processing without unnecessary conversions
5. **Maintainability**: Single JAR dependency with all required libraries included

### Technical Benefits
1. **Unified API**: Single interface for all document formats through Apache Tika
2. **Better Metadata**: Comprehensive document metadata extraction  
3. **Language Detection**: Automatic language identification for multilingual documents
4. **Format Detection**: Automatic file type detection
5. **Structure Analysis**: Better document structure recognition
6. **Table Extraction**: Enhanced table detection and extraction
7. **Extensibility**: Easy to add new format support through Tika
8. **Maintenance**: Single dependency instead of multiple format-specific libraries

### Sri Lankan Tax Document Optimization
1. **Multilingual Support**: Handles English and Sinhala documents
2. **Document Type Detection**: Automatic tax document classification
3. **Structure Recognition**: Identifies common tax document patterns
4. **Metadata Enhancement**: Adds tax-specific metadata
5. **Critical Application Mode**: Explicit error handling without fallbacks for maximum accuracy

This comprehensive approach provides superior document processing capabilities specifically optimized for Ballerina applications processing Sri Lankan tax documents while showcasing the powerful Java interoperability features of the Ballerina language.
