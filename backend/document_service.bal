import ballerina/http;
import ballerina/log;
import ballerina/mime;
import ballerina/time;
import ballerina/uuid;

// Document service for handling file uploads, processing, and management
service /documents on httpListener {

    # Upload a document (PDF or Word) for tax rule extraction
    # + request - HTTP request containing the file upload
    # + return - Upload confirmation with document ID
    resource function post upload(http:Request request) returns json|http:BadRequest|http:InternalServerError {
        do {
            log:printInfo("Processing document upload request");

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

            // Process the first file
            mime:Entity filePart = bodyParts[0];

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
            string? filename = extractFilename(contentDisposition);

            if (filename is ()) {
                return <http:BadRequest>{
                    body: {
                        "error": "Filename not found",
                        "message": "Could not extract filename from upload"
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

            // Generate unique document ID and storage path
            string documentId = uuid:createType1AsString();
            string storagePath = "documents/" + documentId + "_" + filename;

            // TODO: Upload to Supabase Storage
            // For now, we'll simulate the upload and create a database record

            // Create document record in database
            json documentRecord = {
                "id": documentId,
                "filename": filename,
                "file_path": storagePath,
                "content_type": filePart.getContentType(),
                "file_size": fileContent.length(),
                "upload_date": time:utcNow(),
                "processed": false,
                "processing_status": "uploaded"
            };

            // TODO: Insert into Supabase database

            log:printInfo("Document uploaded successfully: " + documentId);

            return {
                "success": true,
                "message": "Document uploaded successfully",
                "document": {
                    "id": documentId,
                    "filename": filename,
                    "size": fileContent.length(),
                    "type": fileExtension,
                    "status": "uploaded",
                    "uploadTime": time:utcNow()
                }
            };

        } on fail error e {
            log:printError("Error processing file upload: " + e.message());
            return <http:InternalServerError>{
                body: {
                    "error": "Upload failed",
                    "message": "An error occurred while processing the upload",
                    "details": e.message()
                }
            };
        }
    }

    # Process an uploaded document to extract tax rules
    # + documentId - The ID of the document to process
    # + return - Processing result
    resource function post process/[string documentId]() returns json|http:NotFound|http:InternalServerError {
        do {
            log:printInfo("Processing document: " + documentId);

            // TODO: Get document from database
            // For now, we'll simulate the processing

            // Validate document exists
            if (documentId.length() == 0) {
                return <http:NotFound>{
                    body: {
                        "error": "Document not found",
                        "message": "Document with ID '" + documentId + "' does not exist"
                    }
                };
            }

            // TODO: Download file from Supabase Storage
            // TODO: Extract text based on file type
            // TODO: Process with Gemini API
            // TODO: Store extracted rules in database

            // Simulate processing steps
            json processingResult = {
                "documentId": documentId,
                "status": "processing",
                "steps": [
                    {"step": "download", "status": "completed", "timestamp": time:utcNow()},
                    {"step": "text_extraction", "status": "in_progress", "timestamp": time:utcNow()},
                    {"step": "llm_processing", "status": "pending"},
                    {"step": "rule_storage", "status": "pending"}
                ]
            };

            log:printInfo("Document processing initiated for: " + documentId);

            return {
                "success": true,
                "message": "Document processing initiated",
                "processing": processingResult
            };

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

    # Get the processing status of a document
    # + documentId - The ID of the document
    # + return - Document status and processing information
    resource function get [string documentId]/status() returns json|http:NotFound {
        log:printInfo("Getting status for document: " + documentId);

        // TODO: Query database for document status
        // For now, we'll return a mock status

        if (documentId.length() == 0) {
            return <http:NotFound>{
                body: {
                    "error": "Document not found",
                    "message": "Document with ID '" + documentId + "' does not exist"
                }
            };
        }

        return {
            "documentId": documentId,
            "status": "uploaded",
            "filename": "sample_tax_document.pdf",
            "uploadDate": time:utcNow(),
            "processed": false,
            "processing": {
                "status": "pending",
                "progress": 0,
                "steps": [
                    {"step": "upload", "status": "completed"},
                    {"step": "text_extraction", "status": "pending"},
                    {"step": "llm_processing", "status": "pending"},
                    {"step": "rule_storage", "status": "pending"}
                ]
            }
        };
    }

    # List all uploaded documents
    # + return - List of documents with their metadata
    resource function get .() returns json {
        log:printInfo("Retrieving all documents");

        // TODO: Query database for all documents
        // For now, we'll return a mock list

        return {
            "documents": [
                {
                    "id": "sample-doc-1",
                    "filename": "income_tax_rules_2024.pdf",
                    "uploadDate": time:utcNow(),
                    "status": "processed",
                    "rulesExtracted": 15
                },
                {
                    "id": "sample-doc-2",
                    "filename": "vat_regulations_2024.pdf",
                    "uploadDate": time:utcNow(),
                    "status": "processing",
                    "rulesExtracted": 0
                }
            ],
            "total": 2,
            "processed": 1,
            "pending": 1
        };
    }

    # Delete a document and its associated data
    # + documentId - The ID of the document to delete
    # + return - Deletion confirmation
    resource function delete [string documentId]() returns json|http:NotFound|http:InternalServerError {
        do {
            log:printInfo("Deleting document: " + documentId);

            if (documentId.length() == 0) {
                return <http:NotFound>{
                    body: {
                        "error": "Document not found",
                        "message": "Document with ID '" + documentId + "' does not exist"
                    }
                };
            }

            // TODO: Delete from Supabase Storage
            // TODO: Delete from database
            // TODO: Delete associated tax rules

            log:printInfo("Document deleted successfully: " + documentId);

            return {
                "success": true,
                "message": "Document deleted successfully",
                "documentId": documentId,
                "deletedAt": time:utcNow()
            };

        } on fail error e {
            log:printError("Error deleting document: " + e.message());
            return <http:InternalServerError>{
                body: {
                    "error": "Deletion failed",
                    "message": "An error occurred while deleting the document",
                    "details": e.message()
                }
            };
        }
    }
}

// Helper function to extract filename from Content-Disposition header
function extractFilename(string contentDisposition) returns string? {
    string:RegExp semicolonRegex = re `;`;
    string[] parts = semicolonRegex.split(contentDisposition);
    foreach string part in parts {
        string trimmedPart = part.trim();
        if (trimmedPart.startsWith("filename=")) {
            string filename = trimmedPart.substring(9);
            // Remove quotes if present
            if (filename.startsWith("\"") && filename.endsWith("\"")) {
                filename = filename.substring(1, filename.length() - 1);
            }
            return filename;
        }
    }
    return ();
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
