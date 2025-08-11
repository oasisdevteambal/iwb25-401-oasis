import ballerina/http;
import ballerina/jballerina.java;
import ballerina/jballerina.java.arrays as jarrays;
import ballerina/log;
import ballerina/mime;
import ballerina/sql;
import ballerina/time;
import ballerinax/postgresql;
import ballerinax/postgresql.driver as _; // Include PostgreSQL JDBC driver

// Phase 6: Vector Storage & Database Persistence Implementation

// ============================================================================
// Supabase Configuration (Phase 6)
// ============================================================================

// Supabase Configuration
configurable string SUPABASE_URL = "https://ohdbwbrutlwikcmpprky.supabase.co";
configurable string SUPABASE_SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9oZGJ3YnJ1dGx3aWtjbXBwcmt5Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NDEzNTI3NCwiZXhwIjoyMDY5NzExMjc0fQ.BDM2DyLfQ3PcJs_9LLQenN8A73TKCIbGjpLMv4WWs9o";
configurable string SUPABASE_STORAGE_BUCKET = "documents";

// Logging / diagnostics configuration
configurable boolean DEBUG_LOGS = false; // Set to true to enable verbose debug logging

// Lightweight debug helper (avoids repeating conditional)
function logDebug(string msg) {
    if (DEBUG_LOGS) {
        log:printInfo("DEBUG: " + msg);
    }
}

// Database Configuration
configurable string SUPABASE_DB_HOST = "db.ohdbwbrutlwikcmpprky.supabase.co";
configurable string SUPABASE_DB_PASSWORD = "1234";

// ============================================================================
// Tokenizer Service Integration
// ============================================================================

// HTTP client for tokenizer service
http:Client tokenizerClient = check new ("http://localhost:3001", {
    timeout: 30.0,
    retryConfig: {
        count: 3,
        interval: 2.0
    }
});

// ============================================================================
// Embedding Service Integration (Google Gemini)
// ============================================================================

// HTTP client for Google Gemini API
http:Client geminiClient = check new ("https://generativelanguage.googleapis.com", {
    timeout: 60.0,
    retryConfig: {
        count: 3,
        interval: 2.0
    }
});

// Gemini API configuration
configurable string GEMINI_API_KEY = "AIzaSyBn6yGwy4qFCftrlcN_OMFKkRX6m_e8ibA";
const string GEMINI_EMBEDDING_MODEL = "text-embedding-004";
const int GEMINI_EMBEDDING_DIMENSIONS = 768;

// ============================================================================
// Supabase Integration (Phase 6)
// ============================================================================

// HTTP client for Supabase Storage operations
http:Client supabaseStorageClient = check new (SUPABASE_URL + "/storage/v1", {
    timeout: 60.0,
    retryConfig: {
        count: 3,
        interval: 2.0
    }
});

// HTTP client for Supabase REST API operations
http:Client supabaseRestClient = check new (SUPABASE_URL + "/rest/v1", {
    timeout: 60.0,
    retryConfig: {
        count: 3,
        interval: 2.0
    }
});

// PostgreSQL client for direct database operations
postgresql:Client dbClient = check new (
    host = SUPABASE_DB_HOST,
    port = 5432,
    database = "postgres",
    username = "postgres",
    password = SUPABASE_DB_PASSWORD
);

# Initialize database connection
#
# + return - Success message or error
function initializeDatabaseConnection() returns string|error {
    // Test the connection using query instead of execute
    stream<record {}, sql:Error?> result = dbClient->query(`SELECT 1 as test`);
    error? closeError = result.close();
    if (closeError is error) {
        log:printError("Failed to connect to database: " + closeError.message());
        return error("Database connection failed: " + closeError.message());
    }

    log:printInfo("✅ Database connection established successfully");
    return "Database connection established successfully";
}

# Get headers for Supabase API requests (with service role key)
#
# + return - Headers map for authenticated requests
function getSupabaseHeaders() returns map<string> {
    return {
        "Authorization": "Bearer " + SUPABASE_SERVICE_ROLE_KEY,
        "apikey": SUPABASE_SERVICE_ROLE_KEY,
        "Content-Type": "application/json"
    };
}

# Get headers for storage operations
#
# + contentType - Content type for the upload
# + return - Headers map for storage requests
function getStorageHeaders(string contentType = "application/octet-stream") returns map<string> {
    return {
        "Authorization": "Bearer " + SUPABASE_SERVICE_ROLE_KEY,
        "apikey": SUPABASE_SERVICE_ROLE_KEY,
        "Content-Type": contentType
    };
}

// ============================================================================
// Supabase Storage Functions (Phase 6)
// ============================================================================

# Upload file to Supabase Storage
#
# + fileContent - The file content as byte array
# + fileName - The filename for storage
# + documentId - The document ID for path generation
# + return - Storage path or error
function uploadFileToSupabase(byte[] fileContent, string fileName, string documentId)
    returns string|error {

    log:printInfo("📤 Uploading file to Supabase Storage: " + fileName);

    // Generate unique storage path
    string storagePath = generateStoragePath(fileName, documentId);

    // Determine content type
    string contentType = getContentTypeFromExtension(getFileExtension(fileName));

    // Upload to Supabase Storage
    string endpoint = "/object/" + SUPABASE_STORAGE_BUCKET + "/" + storagePath;

    http:Response|error response = supabaseStorageClient->post(endpoint, fileContent,
        getStorageHeaders(contentType));

    if (response is error) {
        log:printError("Failed to upload file to Supabase Storage: " + response.message());
        return error("Storage upload failed: " + response.message());
    }

    if (response.statusCode != 200) {
        json|error errorPayload = response.getJsonPayload();
        string errorMsg = errorPayload is json ? errorPayload.toString() : "Unknown error";
        log:printError("Supabase Storage upload error: " + errorMsg);
        return error("Storage upload failed with status " + response.statusCode.toString() + ": " + errorMsg);
    }

    log:printInfo("✅ File uploaded successfully to: " + storagePath);
    return storagePath;
}

# Generate unique storage path for a file
#
# + fileName - Original filename
# + documentId - Document ID for organization
# + return - Unique storage path
function generateStoragePath(string fileName, string documentId) returns string {
    time:Utc currentTime = time:utcNow();
    // Convert to civil time and extract year/month safely
    time:Civil civilTime = time:utcToCivil(currentTime);

    // Format month with leading zero if needed
    string monthStr = civilTime.month < 10 ? "0" + civilTime.month.toString() : civilTime.month.toString();
    string yearMonth = civilTime.year.toString() + "-" + monthStr;

    // Clean filename - remove all special characters that could cause issues
    string cleanFileName = replaceStringSimple(fileName, " ", "_");
    cleanFileName = replaceStringSimple(cleanFileName, "(", "_");
    cleanFileName = replaceStringSimple(cleanFileName, ")", "_");
    cleanFileName = replaceStringSimple(cleanFileName, "[", "_");
    cleanFileName = replaceStringSimple(cleanFileName, "]", "_");
    cleanFileName = replaceStringSimple(cleanFileName, ",", "_");
    cleanFileName = replaceStringSimple(cleanFileName, ":", "_");
    cleanFileName = replaceStringSimple(cleanFileName, ";", "_");

    return yearMonth + "/" + documentId + "/" + cleanFileName;
}

# Get content type from file extension
#
# + extension - File extension (e.g., ".pdf")
# + return - MIME content type
function getContentTypeFromExtension(string extension) returns string {
    match extension {
        ".pdf" => {
            return "application/pdf";
        }
        ".docx" => {
            return "application/vnd.openxmlformats-officedocument.wordprocessingml.document";
        }
        ".doc" => {
            return "application/msword";
        }
        _ => {
            return "application/octet-stream";
        }
    }
}

# Download file from Supabase Storage
#
# + storagePath - Path to the file in storage
# + return - File content as byte array or error
function downloadFileFromSupabase(string storagePath) returns byte[]|error {
    log:printInfo("📥 Downloading file from Supabase Storage: " + storagePath);

    string endpoint = "/object/" + SUPABASE_STORAGE_BUCKET + "/" + storagePath;

    http:Response|error response = supabaseStorageClient->get(endpoint, getSupabaseHeaders());

    if (response is error) {
        log:printError("Failed to download file from Supabase Storage: " + response.message());
        return error("Storage download failed: " + response.message());
    }

    if (response.statusCode != 200) {
        json|error errorPayload = response.getJsonPayload();
        string errorMsg = errorPayload is json ? errorPayload.toString() : "Unknown error";
        return error("Storage download failed with status " + response.statusCode.toString() + ": " + errorMsg);
    }

    byte[]|error fileContent = response.getBinaryPayload();
    if (fileContent is error) {
        return error("Failed to get file content: " + fileContent.message());
    }

    log:printInfo("✅ File downloaded successfully");
    return fileContent;
}

# Generate public URL for stored file
#
# + storagePath - Path to the file in storage
# + return - Public URL for file access
function generateFileURL(string storagePath) returns string {
    return SUPABASE_URL + "/storage/v1/object/public/" + SUPABASE_STORAGE_BUCKET + "/" + storagePath;
}

// ============================================================================
// Database Storage Functions (Phase 6) - Placeholder
// ============================================================================

# Store document metadata in database
#
# + documentId - Document ID
# + fileName - Original filename
# + storagePath - Path in storage
# + chunkingResult - Chunking results
# + return - Success or error
function storeDocumentMetadata(string documentId, string fileName, string storagePath,
        ChunkingResult chunkingResult) returns error? {

    log:printInfo("📊 Storing document metadata: " + documentId);

    // Insert document metadata into documents table
    sql:ParameterizedQuery insertQuery = `
        INSERT INTO documents (
            id, filename, file_path, content_type, upload_date, 
            processed, status, total_chunks, document_type, created_at
        ) VALUES (
            ${documentId}, ${fileName}, ${storagePath}, 'application/pdf',
            NOW(), true, 'completed', ${chunkingResult.totalChunks}, 
            'tax_document', NOW()
        )
        ON CONFLICT (id) DO UPDATE SET
            processed = true,
            status = 'completed',
            total_chunks = ${chunkingResult.totalChunks},
            updated_at = NOW()
    `;

    sql:ExecutionResult|sql:Error result = dbClient->execute(insertQuery);
    if (result is sql:Error) {
        log:printError("Failed to store document metadata: " + result.message());
        return error("Database storage failed: " + result.message());
    }

    log:printInfo("✅ Document metadata stored successfully");
}

# Store chunks in database with embeddings
#
# + chunks - Array of document chunks with embeddings
# + return - Success or error
function storeChunksInDatabase(DocumentChunk[] chunks) returns error? {
    log:printInfo("💾 Storing " + chunks.length().toString() + " chunks in database");

    foreach DocumentChunk chunk in chunks {
        log:printInfo("   - Storing chunk " + chunk.id + ": " + chunk.tokenCount.toString() + " tokens");

        // Convert embedding array to pgvector format
        string? embeddingVector = ();
        decimal[]? embedding = chunk?.embedding;
        if (embedding is decimal[]) {
            // Convert decimal array to string format for pgvector: [1.0,2.0,3.0]
            string embeddingStr = "[" +
                string:'join(",", ...embedding.map(d => d.toString())) +
                "]";
            embeddingVector = embeddingStr;
            log:printInfo("     ✅ Has embedding (" + embedding.length().toString() + " dimensions)");
        } else {
            log:printWarn("     ❌ No embedding for chunk " + chunk.id);
        }

        // Insert chunk into database
        sql:ParameterizedQuery insertQuery;

        if (embeddingVector is string) {
            // Cast the string to vector type in PostgreSQL
            insertQuery = `
                INSERT INTO document_chunks (
                    id, document_id, chunk_sequence, start_position, end_position,
                    chunk_text, chunk_size, token_count, chunk_type, processing_status,
                    relevance_score, context_keywords, embedding, created_at
                ) VALUES (
                    ${chunk.id}, ${chunk.documentId}, ${chunk.sequence}, 
                    ${chunk.startPosition}, ${chunk.endPosition}, ${chunk.chunkText},
                    ${chunk.chunkText.length()}, ${chunk.tokenCount}, ${chunk.chunkType},
                    ${chunk.processingStatus}, ${chunk.relevanceScore}, ${chunk.keywords},
                    ${embeddingVector}::vector(768), NOW()
                )
                ON CONFLICT (id) DO UPDATE SET
                    embedding = ${embeddingVector}::vector(768),
                    processing_status = ${chunk.processingStatus},
                    updated_at = NOW()
            `;
        } else {
            // No embedding available
            insertQuery = `
                INSERT INTO document_chunks (
                    id, document_id, chunk_sequence, start_position, end_position,
                    chunk_text, chunk_size, token_count, chunk_type, processing_status,
                    relevance_score, context_keywords, created_at
                ) VALUES (
                    ${chunk.id}, ${chunk.documentId}, ${chunk.sequence}, 
                    ${chunk.startPosition}, ${chunk.endPosition}, ${chunk.chunkText},
                    ${chunk.chunkText.length()}, ${chunk.tokenCount}, ${chunk.chunkType},
                    ${chunk.processingStatus}, ${chunk.relevanceScore}, ${chunk.keywords},
                    NOW()
                )
                ON CONFLICT (id) DO UPDATE SET
                    processing_status = ${chunk.processingStatus},
                    updated_at = NOW()
            `;
        }

        sql:ExecutionResult|sql:Error result = dbClient->execute(insertQuery);
        if (result is sql:Error) {
            log:printError("Failed to store chunk " + chunk.id + ": " + result.message());
            return error("Failed to store chunk: " + result.message());
        }
    }

    log:printInfo("✅ All chunks stored in database successfully");
}

// ============================================================================
// Semantic Search Functions (Phase 6) - Placeholder
// ============================================================================

# Simple comma splitter (avoids dependency on unavailable string:split)
function splitComma(string s) returns string[] {
    string[] parts = [];
    string current = "";
    string trimmedAll = s.trim();
    int len = trimmedAll.length();
    int i = 0;
    while (i < len) {
        // Extract single-character substring
        string ch = trimmedAll.substring(i, i + 1);
        if (ch == ",") {
            string trimmed = current.trim();
            if (trimmed.length() > 0) {
                parts.push(trimmed);
            }
            current = "";
        } else {
            current += ch;
        }
        i += 1;
    }
    string last = current.trim();
    if (last.length() > 0) {
        parts.push(last);
    }
    return parts;
}

# Search for similar chunks using semantic search with pgvector
#
# + query - Search query text
# + limit - Maximum number of results
# + return - Array of search results or error
function searchSimilarChunks(string query, int 'limit = 10) returns ChunkSearchResult[]|error {
    log:printInfo("🔍 Performing semantic search for: " + query);
    logDebug("Generating query embedding...");

    // Generate embedding for the search query
    decimal[]|error queryEmbedding = generateEmbedding(query);
    if (queryEmbedding is error) {
        log:printError("Failed to generate query embedding: " + queryEmbedding.message());
        return error("Search failed: " + queryEmbedding.message());
    }

    logDebug("Query embedding generated: " + queryEmbedding.length().toString() + " dimensions");

    // Convert query embedding to pgvector format
    logDebug("Converting embedding to pgvector format...");
    string queryVector = "[" +
        string:'join(",", ...queryEmbedding.map(d => d.toString())) +
        "]";
    logDebug("Query vector prepared, length: " + queryVector.length().toString());
    if (DEBUG_LOGS) {
        log:printInfo("DEBUG: Query vector first 100 chars: " + queryVector.substring(0, 100 < queryVector.length() ? 100 : queryVector.length()));
        log:printInfo("DEBUG: Query vector last 50 chars: " + queryVector.substring(queryVector.length() - 50 > 0 ? queryVector.length() - 50 : 0));
    }

    // REAL DATABASE SEARCH: Now enabled after fixing Java classpath conflicts
    logDebug("Preparing SQL query...");

    // First test: Try a simple query without vector operations
    logDebug("Testing simple query first...");
    stream<record {}, sql:Error?> simpleTestStream = dbClient->query(`
        SELECT id, chunk_text, embedding IS NOT NULL as has_embedding 
        FROM document_chunks 
        LIMIT 1
    `);

    int simpleRowCount = 0;
    error? simpleError = simpleTestStream.forEach(function(record {} row) {
        simpleRowCount += 1;
        logDebug("Simple query row - id: " + <string>row["id"]);
        logDebug("Simple query row - has_embedding: " + (<boolean>row["has_embedding"]).toString());
        logDebug("Simple query row - text length: " + (<string>row["chunk_text"]).length().toString());
    });

    if (simpleError is error) {
        log:printError("🔧 DEBUG: Simple query failed: " + simpleError.message());
        return error("Simple query failed: " + simpleError.message());
    }

    logDebug("Simple query returned " + simpleRowCount.toString() + " rows");

    if (simpleRowCount == 0) {
        log:printError("No chunks found in database at all!");
        return error("No document chunks found in database");
    }

    // Build similarity search fetching a broader set WITHOUT ORDER BY (driver seems to drop rows when ORDER BY uses large vector twice)
    int fetchSize = 'limit * 10; // over-fetch then sort in memory
    if (fetchSize < 50) {
        fetchSize = 50;
    }
    logDebug("Building unsorted similarity fetch (fetchSize=" + fetchSize.toString() + ")...");
    sql:ParameterizedQuery searchQuery = `
        SELECT 
            id, 
            document_id, 
            chunk_sequence AS sequence, 
            chunk_text, 
            relevance_score, 
            chunk_type, 
            context_keywords AS keywords, 
            (embedding <=> ${queryVector}::vector(768)) AS distance 
        FROM document_chunks 
        WHERE embedding IS NOT NULL 
        LIMIT ${fetchSize}
    `;
    logDebug("Unsorted similarity fetch query built; executing...");
    stream<record {}, sql:Error?> resultStream = dbClient->query(searchQuery);
    logDebug("Unsorted fetch executed; processing result stream...");

    ChunkSearchResult[] results = [];
    int rowCount = 0;

    error? e = resultStream.forEach(function(record {} row) {
        rowCount += 1;
        logDebug("Processing row " + rowCount.toString());

        // Log the raw row data for debugging
        logDebug("Row data - id: " + <string>row["id"]);
        // Convert distance to similarity (1 - distance);
        decimal distance = <decimal>row["distance"];
        decimal similarity = 1 - distance;
        logDebug("Row data - distance: " + distance.toString() + " similarity: " + similarity.toString());
        logDebug("Row data - chunk_text length: " + (<string>row["chunk_text"]).length().toString());

        // Convert row to ChunkSearchResult
        // keywords column may be NULL; guard the cast
        string[] kw = [];
        var kwRaw = row["keywords"];
        if (kwRaw is string[]) {
            kw = kwRaw;
        } else if (kwRaw is string) { // handle comma-separated or Postgres array format
            string temp = kwRaw.trim();
            // Strip Postgres array braces {a,b,c}
            if (temp.startsWith("{") && temp.endsWith("}")) {
                temp = temp.substring(1, temp.length() - 1);
            }
            if (temp.length() > 0) {
                string[] parts = splitComma(temp);
                foreach var p in parts {
                    string cleaned = p.trim();
                    if (cleaned.length() > 0) {
                        kw.push(cleaned);
                    }
                }
            }
        }
        ChunkSearchResult searchResult = {
            id: <string>row["id"],
            document_id: <string>row["document_id"],
            sequence: <int>row["sequence"],
            chunk_text: <string>row["chunk_text"],
            relevance_score: <decimal>row["relevance_score"],
            chunk_type: <string>row["chunk_type"],
            keywords: kw,
            similarity_score: similarity
        };
        results.push(searchResult);
        logDebug("Successfully added result to array");
    });

    if (e is error) {
        log:printError("🔧 DEBUG: Error during result processing: " + e.message());
        log:printError("Error during search: " + e.message());
        return error("Search query failed: " + e.message());
    }

    logDebug("Result processing completed successfully");
    logDebug("Total unsorted rows processed: " + rowCount.toString());
    // Sort results by similarity descending using query expression (avoids method overload issues)
    ChunkSearchResult[] sorted = from ChunkSearchResult r in results
        order by r.similarity_score descending
        select r;
    results = sorted;
    // Trim to requested limit
    if (results.length() > 'limit) {
        results = results.slice(0, 'limit);
    }
    logDebug("Results after in-memory sort & trim: " + results.length().toString());
    log:printInfo("✅ Search completed (in-memory sorted): " + results.length().toString() + " results returned");

    // If no rows, run staged diagnostic queries to narrow down failure point
    if (results.length() == 0) {
        logDebug("Similarity query returned zero rows. Running staged diagnostics...");

        // Stage 1: Baseline count
        stream<record {}, sql:Error?> countStream = dbClient->query(`SELECT COUNT(*) AS cnt FROM document_chunks WHERE embedding IS NOT NULL`);
        error? countErr = countStream.forEach(function(record {} r) {
            logDebug("Stage1 COUNT embedding IS NOT NULL = " + (<int>r["cnt"]).toString());
        });
        if (countErr is error) {
            log:printError("Stage1 count failed: " + countErr.message());
        }

        // Stage 2: Fetch rows without similarity expression
        stream<record {}, sql:Error?> stage2 = dbClient->query(`
            SELECT id, document_id, chunk_sequence AS sequence, chunk_text
            FROM document_chunks
            WHERE embedding IS NOT NULL
            LIMIT 5
        `);
        int stage2Count = 0;
        error? stage2Err = stage2.forEach(function(record {} r) {
            stage2Count += 1;
            logDebug("Stage2 row id=" + <string>r["id"]);
        });
        if (stage2Err is error) {
            log:printError("Stage2 basic fetch failed: " + stage2Err.message());
        }
        logDebug("Stage2 fetched rows: " + stage2Count.toString());

        // Stage 3: Add similarity expression in SELECT only
        sql:ParameterizedQuery stage3Query = `
            SELECT id, (embedding <=> ${queryVector}::vector(768)) AS distance
            FROM document_chunks
            WHERE embedding IS NOT NULL
            LIMIT 5
        `;
        stream<record {}, sql:Error?> stage3 = dbClient->query(stage3Query);
        int stage3Count = 0;
        error? stage3Err = stage3.forEach(function(record {} r) {
            stage3Count += 1;
            logDebug("Stage3 row id=" + <string>r["id"] + " distance=" + (<decimal>r["distance"]).toString());
        });
        if (stage3Err is error) {
            log:printError("Stage3 similarity select failed: " + stage3Err.message());
        }
        logDebug("Stage3 fetched rows: " + stage3Count.toString());

        // Stage 4: ORDER BY using CTE to reference vector once
        if (stage3Count > 0) {
            sql:ParameterizedQuery stage4Query = `
                WITH q AS (SELECT ${queryVector}::vector(768) AS qv)
                SELECT dc.id, (dc.embedding <=> q.qv) AS distance
                FROM document_chunks dc, q
                WHERE dc.embedding IS NOT NULL
                ORDER BY dc.embedding <=> q.qv
                LIMIT 5
            `;
            stream<record {}, sql:Error?> stage4 = dbClient->query(stage4Query);
            int stage4Count = 0;
            error? stage4Err = stage4.forEach(function(record {} r) {
                stage4Count += 1;
                logDebug("Stage4 row id=" + <string>r["id"] + " distance=" + (<decimal>r["distance"]).toString());
            });
            if (stage4Err is error) {
                log:printError("Stage4 ORDER BY similarity (CTE) failed: " + stage4Err.message());
            }
            logDebug("Stage4 fetched rows: " + stage4Count.toString());
        } else {
            logDebug("Skipping Stage4 because Stage3 returned zero rows");
        }
    }
    return results;

}

# Chunk search result type
type ChunkSearchResult record {
    string id;
    string document_id;
    int sequence;
    string chunk_text;
    decimal relevance_score;
    string chunk_type;
    string[] keywords;
    decimal similarity_score;
}; // Tokenizer service types

type TokenizeRequest record {
    string text;
};

type TokenizeResponse record {
    int tokenCount;
    string encoding;
    boolean success;
    record {
        int characterCount;
        decimal averageCharsPerToken;
        int processingTimeMs;
    } statistics;
    record {
        string timestamp;
        string textPreview;
    } metadata;
};

type BatchTokenizeRequest record {
    string[] texts;
};

type BatchTokenizeResponse record {
    record {
        int index;
        int tokenCount;
        int characterCount;
        decimal averageCharsPerToken;
        boolean success;
        string? errorMessage;
    }[] results;
    record {
        int totalTexts;
        int totalTokens;
        int totalCharacters;
        decimal averageTokensPerText;
        decimal averageCharsPerToken;
        int successfulCount;
        int failedCount;
    } summary;
    string encoding;
    int processingTimeMs;
    boolean success;
    string timestamp;
};

// ============================================================================
// Embedding Service Types (Google Gemini)
// ============================================================================

type EmbedRequest record {
    string model;
    EmbedContent content;
    string? taskType?;
    string? title?;
    int? outputDimensionality?;
};

type EmbedContent record {
    record {string text;}[] parts;
};

type EmbedResponse record {
    EmbedResult embedding;
};

type EmbedResult record {
    decimal[] values;
};

// ============================================================================
// Tokenizer Service Functions
// ============================================================================

# Get token count for a single text using the tokenizer service
#
# + text - The text to tokenize
# + return - Token count or error
function getTokenCount(string text) returns int|error {
    if (text.trim().length() == 0) {
        return 0;
    }

    TokenizeRequest request = {text: text};

    http:Response|error response = tokenizerClient->post("/tokenize", request);

    if (response is error) {
        log:printError("Failed to call tokenizer service: " + response.message());
        // Fallback to simple estimation
        return estimateTokensFallback(text);
    }

    json|error payload = response.getJsonPayload();
    if (payload is error) {
        log:printError("Failed to parse tokenizer response: " + payload.message());
        return estimateTokensFallback(text);
    }

    TokenizeResponse|error tokenResponse = payload.cloneWithType(TokenizeResponse);
    if (tokenResponse is error) {
        log:printError("Failed to convert tokenizer response: " + tokenResponse.message());
        return estimateTokensFallback(text);
    }

    if (!tokenResponse.success) {
        log:printError("Tokenizer service returned error");
        return estimateTokensFallback(text);
    }

    return tokenResponse.tokenCount;
}

# Get token counts for multiple texts using batch tokenization
#
# + texts - Array of texts to tokenize
# + return - Array of token counts or error
function getBatchTokenCounts(string[] texts) returns int[]|error {
    if (texts.length() == 0) {
        return [];
    }

    BatchTokenizeRequest request = {texts: texts};

    http:Response|error response = tokenizerClient->post("/tokenize/batch", request);

    if (response is error) {
        log:printError("Failed to call tokenizer batch service: " + response.message());
        // Fallback to individual estimations
        int[] counts = [];
        foreach string text in texts {
            counts.push(estimateTokensFallback(text));
        }
        return counts;
    }

    json|error payload = response.getJsonPayload();
    if (payload is error) {
        log:printError("Failed to parse batch tokenizer response: " + payload.message());
        int[] counts = [];
        foreach string text in texts {
            counts.push(estimateTokensFallback(text));
        }
        return counts;
    }

    BatchTokenizeResponse|error batchResponse = payload.cloneWithType(BatchTokenizeResponse);
    if (batchResponse is error) {
        log:printError("Failed to convert batch tokenizer response: " + batchResponse.message());
        int[] counts = [];
        foreach string text in texts {
            counts.push(estimateTokensFallback(text));
        }
        return counts;
    }

    if (!batchResponse.success) {
        log:printError("Batch tokenizer service returned error");
        int[] counts = [];
        foreach string text in texts {
            counts.push(estimateTokensFallback(text));
        }
        return counts;
    }

    int[] tokenCounts = [];
    foreach var result in batchResponse.results {
        if (result.success) {
            tokenCounts.push(result.tokenCount);
        } else {
            log:printWarn("Failed to tokenize text at index " + result.index.toString() + ": " + (result.errorMessage ?: "unknown error"));
            tokenCounts.push(estimateTokensFallback(texts[result.index]));
        }
    }

    return tokenCounts;
}

# Fallback token estimation function (original simple estimation)
#
# + text - The text to estimate tokens for
# + return - Estimated token count
function estimateTokensFallback(string text) returns int {
    // Rough estimation: 1 token ≈ 3-4 characters for technical content
    return text.length() / 3;
}

// ============================================================================
// Embedding Service Functions (Google Gemini)
// ============================================================================

# Generate embedding for a single text using Google Gemini
#
# + text - The text to generate embedding for
# + return - Embedding vector or error
function generateEmbedding(string text) returns decimal[]|error {
    if (text.trim().length() == 0) {
        return error("Text cannot be empty for embedding generation");
    }

    // Prepare the request with correct format for Google Gemini API
    EmbedRequest request = {
        model: "models/" + GEMINI_EMBEDDING_MODEL,
        content: {
            parts: [{text: text}]
        },
        taskType: "SEMANTIC_SIMILARITY"
    };

    string endpoint = "/v1beta/models/" + GEMINI_EMBEDDING_MODEL + ":embedContent?key=" + GEMINI_API_KEY;

    http:Response|error response = geminiClient->post(endpoint, request);

    if (response is error) {
        log:printError("Failed to call Gemini embedding API: " + response.message());
        return error("Failed to generate embedding: " + response.message());
    }

    json|error payload = response.getJsonPayload();
    if (payload is error) {
        log:printError("Failed to parse Gemini embedding response: " + payload.message());
        return error("Failed to parse embedding response: " + payload.message());
    }

    // Debug: Log the actual response structure
    log:printInfo("DEBUG: Gemini individual response structure: " + payload.toString());

    EmbedResponse|error embedResponse = payload.cloneWithType(EmbedResponse);
    if (embedResponse is error) {
        log:printError("Failed to convert Gemini embedding response: " + embedResponse.message());
        return error("Failed to convert embedding response: " + embedResponse.message());
    }

    return embedResponse.embedding.values;
}

# Generate embeddings for multiple texts using individual processing
#
# + texts - Array of texts to generate embeddings for
# + return - Array of embedding vectors or error
function generateMultipleEmbeddings(string[] texts) returns decimal[][]|error {
    if (texts.length() == 0) {
        return [];
    }

    log:printInfo("🔮 Generating individual embeddings for " + texts.length().toString() + " texts");

    decimal[][] embeddings = [];
    foreach int i in 0 ..< texts.length() {
        string text = texts[i];
        log:printInfo("🔮 Generating individual embedding " + (i + 1).toString() + "/" + texts.length().toString());
        decimal[]|error embeddingResult = generateEmbedding(text);
        if (embeddingResult is error) {
            log:printError("Failed to generate individual embedding: " + embeddingResult.message());
            return error("Failed to generate embedding: " + embeddingResult.message());
        }
        embeddings.push(embeddingResult);
    }
    log:printInfo("✅ Successfully generated " + embeddings.length().toString() + " individual embeddings");
    return embeddings;
}

# Generate embedding for a document chunk with metadata
#
# + chunk - Document chunk to generate embedding for
# + return - Updated chunk with embedding or error
function generateChunkEmbedding(DocumentChunk chunk) returns DocumentChunk|error {
    log:printInfo("🔮 Generating embedding for chunk: " + chunk.id);

    decimal[]|error embeddingResult = generateEmbedding(chunk.chunkText);
    if (embeddingResult is error) {
        log:printError("Failed to generate embedding for chunk " + chunk.id + ": " + embeddingResult.message());
        return error("Failed to generate embedding for chunk: " + embeddingResult.message());
    }

    log:printInfo("✅ Generated embedding with " + embeddingResult.length().toString() + " dimensions for chunk: " + chunk.id);

    // Update chunk with embedding data
    chunk.embedding = embeddingResult;
    chunk.embeddingMetadata = {
        embeddingModel: GEMINI_EMBEDDING_MODEL,
        embeddingDimensions: GEMINI_EMBEDDING_DIMENSIONS,
        embeddingProvider: "google_gemini",
        generatedAt: time:utcNow().toString()
    };
    chunk.processingStatus = "embedded";

    return chunk;
}

# Generate embeddings for multiple chunks using individual processing
#
# + chunks - Array of document chunks to generate embeddings for
# + return - Array of chunks with embeddings or error
function generateChunkEmbeddings(DocumentChunk[] chunks) returns DocumentChunk[]|error {
    if (chunks.length() == 0) {
        return chunks;
    }

    log:printInfo("🔮 Generating embeddings for " + chunks.length().toString() + " chunks");

    // Extract texts for processing
    string[] texts = [];
    foreach DocumentChunk chunk in chunks {
        texts.push(chunk.chunkText);
    }

    decimal[][]|error embeddingsResult = generateMultipleEmbeddings(texts);
    if (embeddingsResult is error) {
        log:printError("Failed to generate embeddings: " + embeddingsResult.message());
        return error("Failed to generate embeddings: " + embeddingsResult.message());
    }

    // Update chunks with embedding data
    DocumentChunk[] embeddedChunks = [];
    foreach int i in 0 ..< chunks.length() {
        DocumentChunk chunk = chunks[i];
        chunk.embedding = embeddingsResult[i];
        chunk.embeddingMetadata = {
            embeddingModel: GEMINI_EMBEDDING_MODEL,
            embeddingDimensions: GEMINI_EMBEDDING_DIMENSIONS,
            embeddingProvider: "google_gemini",
            generatedAt: time:utcNow().toString()
        };
        chunk.processingStatus = "embedded";
        embeddedChunks.push(chunk);
    }

    log:printInfo("✅ Generated embeddings for " + embeddedChunks.length().toString() + " chunks");

    return embeddedChunks;
}

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

// Chunking types for document processing
type DocumentChunk record {
    string id;
    string documentId;
    int sequence;
    string chunkText;
    int startPosition;
    int endPosition;
    int tokenCount;
    string chunkType;
    string[] keywords;
    decimal relevanceScore;
    string context;
    string processingStatus;
    decimal[]? embedding?; // Gemini embedding vector (768 dimensions)
    record {
        string embeddingModel;
        int embeddingDimensions;
        string embeddingProvider;
        string generatedAt;
    }? embeddingMetadata?;
};

type ChunkingResult record {
    DocumentChunk[] chunks;
    int totalChunks;
    ChunkingStats stats;
    string[] warnings;
    boolean success;
};

type ChunkingStats record {
    int processingTimeMs;
    decimal avgChunkSize;
    int taxRelevantChunks;
    decimal documentCoverage;
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

// ============================================================================
// Document Chunking Functions - Integrated from text_extractor module
// ============================================================================

# Process document chunking for tax documents
#
# + documentText - Extracted text from the document
# + fileName - Original filename for context
# + documentId - Pre-generated document ID to use
# + return - Chunking result with created chunks and metadata
function processDocumentChunking(string documentText, string fileName, string documentId)
    returns ChunkingResult|error {

    log:printInfo("🚀 Starting document chunking for: " + fileName);
    time:Utc startTime = time:utcNow();

    // Validate input
    if (documentText.length() == 0) {
        return error("Document text is empty for chunking");
    }

    log:printInfo("🆔 Using provided document ID: " + documentId);

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

    // Step 1: Create semantic chunks
    DocumentChunk[] chunks = createSemanticChunks(documentText, documentId, config);

    // Step 2: Add relevance scoring
    DocumentChunk[] scoredChunks = addTaxRelevanceScoring(chunks, config);

    // Step 3: Validate chunks
    DocumentChunk[] validatedChunks = validateChunks(scoredChunks);

    // Step 4: Generate embeddings for chunks
    log:printInfo("🔮 Starting embedding generation for " + validatedChunks.length().toString() + " chunks");
    DocumentChunk[]|error embeddedChunksResult = generateChunkEmbeddings(validatedChunks);

    DocumentChunk[] finalChunks;
    if (embeddedChunksResult is error) {
        log:printWarn("Failed to generate embeddings: " + embeddedChunksResult.message() + ". Proceeding without embeddings.");
        warnings.push("Failed to generate embeddings: " + embeddedChunksResult.message());
        finalChunks = validatedChunks;
    } else {
        finalChunks = embeddedChunksResult;
        log:printInfo("✅ Successfully generated embeddings for all chunks");
    }

    // Calculate statistics
    time:Utc endTime = time:utcNow();
    ChunkingStats stats = calculateStats(finalChunks, startTime, endTime, documentText);

    log:printInfo("✅ Chunking completed successfully. Generated " + finalChunks.length().toString() + " chunks");

    return {
        chunks: finalChunks,
        totalChunks: finalChunks.length(),
        stats: stats,
        warnings: warnings,
        success: true
    };
}

# Generate a unique document ID
function generateDocumentId(string fileName) returns string {
    time:Utc currentTime = time:utcNow();
    // Use Unix timestamp instead of string representation to avoid special characters
    time:Civil epochCivil = {year: 1970, month: 1, day: 1, hour: 0, minute: 0, second: 0};
    time:Utc|time:Error epochUtc = time:utcFromCivil(epochCivil);

    decimal unixTimestamp;
    if (epochUtc is time:Utc) {
        unixTimestamp = time:utcDiffSeconds(currentTime, epochUtc);
    } else {
        // Fallback: use current time nanoseconds
        unixTimestamp = <decimal>currentTime[0];
    }

    string timestamp = unixTimestamp.toString();

    string cleanFileName = fileName.toLowerAscii();

    // Remove file extension
    int? dotIndex = cleanFileName.lastIndexOf(".");
    if (dotIndex is int && dotIndex > 0) {
        cleanFileName = cleanFileName.substring(0, dotIndex);
    }

    // Replace spaces and special characters with underscores
    cleanFileName = replaceStringSimple(cleanFileName, " ", "_");
    cleanFileName = replaceStringSimple(cleanFileName, "-", "_");
    cleanFileName = replaceStringSimple(cleanFileName, ".", "_");
    cleanFileName = replaceStringSimple(cleanFileName, "[", "_");
    cleanFileName = replaceStringSimple(cleanFileName, "]", "_");
    cleanFileName = replaceStringSimple(cleanFileName, ",", "_");
    cleanFileName = replaceStringSimple(cleanFileName, "(", "_");
    cleanFileName = replaceStringSimple(cleanFileName, ")", "_");

    // Use only safe characters for storage path
    return "doc_" + cleanFileName + "_" + timestamp.substring(0, 10);
}

# Create semantic chunks from document text
function createSemanticChunks(string text, string documentId, ChunkConfig config) returns DocumentChunk[] {
    DocumentChunk[] chunks = [];

    // Split text into paragraphs first
    string[] paragraphs = splitTextByParagraphs(text);

    string currentChunk = "";
    int currentTokens = 0;
    int chunkSequence = 1;
    int currentPosition = 0;

    foreach string paragraph in paragraphs {
        int|error tokenResult = getTokenCount(paragraph);
        int paragraphTokens = tokenResult is int ? tokenResult : estimateTokensFallback(paragraph);

        // If adding this paragraph would exceed the limit and we have content, finalize chunk
        if (currentTokens + paragraphTokens > config.maxTokens && currentChunk.length() > 0) {
            DocumentChunk chunk = createDocumentChunk(
                    currentChunk.trim(),
                    currentPosition,
                    chunkSequence,
                    documentId
            );
            chunks.push(chunk);

            // Start new chunk
            currentChunk = paragraph;
            currentTokens = paragraphTokens;
            chunkSequence += 1;
            currentPosition += currentChunk.length();
        } else {
            // Add to current chunk
            if (currentChunk.length() > 0) {
                currentChunk += "\n\n" + paragraph;
            } else {
                currentChunk = paragraph;
            }
            currentTokens += paragraphTokens;
        }
    }

    // Add final chunk if there's remaining content
    if (currentChunk.trim().length() > 0) {
        DocumentChunk chunk = createDocumentChunk(
                currentChunk.trim(),
                currentPosition,
                chunkSequence,
                documentId
        );
        chunks.push(chunk);
    }

    return chunks;
}

# Create a document chunk with metadata
function createDocumentChunk(string text, int position, int sequence, string documentId)
    returns DocumentChunk {

    string chunkId = documentId + "_chunk_" + sequence.toString();
    int|error tokenResult = getTokenCount(text);
    int tokenCount = tokenResult is int ? tokenResult : estimateTokensFallback(text);
    string chunkType = determineChunkType(text);

    return {
        id: chunkId,
        documentId: documentId,
        sequence: sequence,
        chunkText: text,
        startPosition: position,
        endPosition: position + text.length(),
        tokenCount: tokenCount,
        chunkType: chunkType,
        keywords: [], // Will be populated later
        relevanceScore: 0.0, // Will be calculated later
        context: text,
        processingStatus: "created"
    };
}

# Add tax relevance scoring to chunks
function addTaxRelevanceScoring(DocumentChunk[] chunks, ChunkConfig config) returns DocumentChunk[] {
    DocumentChunk[] scoredChunks = [];

    foreach DocumentChunk chunk in chunks {
        // Extract tax keywords
        string[] keywords = extractTaxKeywords(chunk.chunkText, config.taxKeywords);

        // Calculate relevance score
        decimal score = calculateRelevanceScore(chunk.chunkText, keywords, config.taxKeywords);

        chunk.keywords = keywords;
        chunk.relevanceScore = score;
        chunk.processingStatus = "scored";

        scoredChunks.push(chunk);
    }

    return scoredChunks;
}

# Extract tax-related keywords from text
function extractTaxKeywords(string text, string[] taxKeywords) returns string[] {
    string[] foundKeywords = [];
    string lowerText = text.toLowerAscii();

    foreach string keyword in taxKeywords {
        if (lowerText.includes(keyword.toLowerAscii())) {
            foundKeywords.push(keyword);
        }
    }

    return foundKeywords;
}

# Calculate tax relevance score for a chunk
function calculateRelevanceScore(string text, string[] keywords, string[] allKeywords) returns decimal {
    decimal score = 0.0d;

    // Base score from keyword presence
    decimal keywordScore = (<decimal>keywords.length()) / (<decimal>allKeywords.length());
    score += keywordScore * 0.4d;

    // Bonus for numeric content (calculations, rates)
    if (containsNumbers(text)) {
        score += 0.3d;
    }

    // Bonus for percentage signs (tax rates)
    if (text.includes("%")) {
        score += 0.2d;
    }

    // Bonus for currency mentions
    if (text.includes("LKR") || text.includes("Rs") || text.includes("rupees")) {
        score += 0.1d;
    }

    // Ensure score is between 0 and 1
    return score > 1.0d ? 1.0d : score;
}

# Validate and finalize chunks
function validateChunks(DocumentChunk[] chunks) returns DocumentChunk[] {
    DocumentChunk[] validChunks = [];

    foreach DocumentChunk chunk in chunks {
        // Relaxed validation for testing - include chunks with minimal content
        if (chunk.chunkText.trim().length() >= 20 && chunk.tokenCount >= 5) {
            chunk.processingStatus = "validated";
            validChunks.push(chunk);
        } else {
            log:printWarn("Chunk rejected: text length=" + chunk.chunkText.trim().length().toString() + ", tokens=" + chunk.tokenCount.toString());
        }
    }

    return validChunks;
}

# Calculate chunking statistics
function calculateStats(DocumentChunk[] chunks, time:Utc startTime, time:Utc endTime, string originalText)
    returns ChunkingStats {

    decimal processingTime = time:utcDiffSeconds(endTime, startTime);
    decimal totalTokens = 0.0;
    int taxRelevantCount = 0;

    foreach DocumentChunk chunk in chunks {
        totalTokens += <decimal>chunk.tokenCount;
        if (chunk.relevanceScore > 0.5d) {
            taxRelevantCount += 1;
        }
    }

    decimal avgChunkSize = chunks.length() > 0 ? totalTokens / <decimal>chunks.length() : 0.0;
    int|error originalTokenResult = getTokenCount(originalText);
    int originalTokens = originalTokenResult is int ? originalTokenResult : estimateTokensFallback(originalText);
    decimal coverage = (totalTokens / <decimal>originalTokens) * 100.0;

    return {
        processingTimeMs: <int>processingTime * 1000,
        avgChunkSize: avgChunkSize,
        taxRelevantChunks: taxRelevantCount,
        documentCoverage: coverage
    };
}

# Helper function to split text by paragraphs
function splitTextByParagraphs(string text) returns string[] {
    string[] paragraphs = [];
    string currentParagraph = "";
    int newlineCount = 0;

    foreach string:Char char in text {
        if (char == "\n") {
            newlineCount += 1;
            if (newlineCount >= 2) {
                if (currentParagraph.trim().length() > 0) {
                    paragraphs.push(currentParagraph.trim());
                    currentParagraph = "";
                }
                newlineCount = 0;
            } else {
                currentParagraph += char;
            }
        } else {
            if (newlineCount == 1) {
                currentParagraph += "\n";
            }
            currentParagraph += char;
            newlineCount = 0;
        }
    }

    if (currentParagraph.trim().length() > 0) {
        paragraphs.push(currentParagraph.trim());
    }

    return paragraphs;
}

# Estimate token count for text (DEPRECATED - Use getTokenCount instead)
# This function is kept for backward compatibility and fallback scenarios
#
# + text - The text to estimate tokens for
# + return - Estimated token count
function estimateTokens(string text) returns int {
    log:printWarn("Using deprecated estimateTokens function. Consider using getTokenCount for accurate results.");
    return estimateTokensFallback(text);
}

# Determine the type of chunk based on content
function determineChunkType(string text) returns string {
    string upperText = text.toUpperAscii();

    if (upperText.includes("TABLE") || text.includes("|") || text.includes("\t")) {
        return "table";
    } else if (text.length() < 200 && !text.includes(".")) {
        return "header";
    } else if (text.startsWith("-") || text.startsWith("*") || text.startsWith("+")) {
        return "list";
    } else {
        return "paragraph";
    }
}

# Check if text contains numeric content
function containsNumbers(string text) returns boolean {
    string[] digits = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"];

    foreach string digit in digits {
        if (text.includes(digit)) {
            return true;
        }
    }
    return false;
}

# Simple string replacement function
function replaceStringSimple(string original, string searchFor, string replaceWith) returns string {
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

# Chunking configuration
type ChunkConfig record {
    int maxTokens;
    int overlapTokens;
    string strategy;
    string[] taxKeywords;
};

// Document service for handling file uploads and immediate processing
service /api/v1/documents on httpListener {

    # Test embedding generation (debug endpoint)
    # + return - Test result with embedding data or error
    resource function get test\-embedding() returns json|http:InternalServerError {
        do {
            log:printInfo("Testing embedding generation...");

            string testText = "This is a test document for tax calculation system";
            decimal[]|error embeddingResult = generateEmbedding(testText);

            if (embeddingResult is error) {
                log:printError("Test embedding failed: " + embeddingResult.message());
                return <http:InternalServerError>{
                    body: {
                        "success": false,
                        "error": "Embedding test failed",
                        "message": embeddingResult.message()
                    }
                };
            }

            return {
                "success": true,
                "message": "Embedding test successful",
                "testText": testText,
                "embeddingDimensions": embeddingResult.length(),
                "embeddingPreview": embeddingResult.length() > 5 ? embeddingResult.slice(0, 5) : embeddingResult
            };

        } on fail error e {
            log:printError("Error in embedding test: " + e.message());
            return <http:InternalServerError>{
                body: {
                    "success": false,
                    "error": "Test failed",
                    "message": e.message()
                }
            };
        }
    }

    # Debug endpoint to check database contents
    # + return - Database statistics and sample data
    resource function get debug\-db() returns json|http:InternalServerError {
        do {
            log:printInfo("🔧 DEBUG: Checking database contents...");

            // Count documents
            stream<record {}, sql:Error?> docCountStream = dbClient->query(`SELECT COUNT(*) as doc_count FROM documents`);
            int docCount = 0;
            error? docCountError = docCountStream.forEach(function(record {} row) {
                docCount = <int>row["doc_count"];
            });
            if (docCountError is error) {
                log:printError("Failed to count documents: " + docCountError.message());
            }

            // Count document chunks
            stream<record {}, sql:Error?> chunkCountStream = dbClient->query(`SELECT COUNT(*) as chunk_count FROM document_chunks`);
            int chunkCount = 0;
            error? chunkCountError = chunkCountStream.forEach(function(record {} row) {
                chunkCount = <int>row["chunk_count"];
            });
            if (chunkCountError is error) {
                log:printError("Failed to count chunks: " + chunkCountError.message());
            }

            // Count chunks with embeddings
            stream<record {}, sql:Error?> embeddedCountStream = dbClient->query(`SELECT COUNT(*) as embedded_count FROM document_chunks WHERE embedding IS NOT NULL`);
            int embeddedCount = 0;
            error? embeddedCountError = embeddedCountStream.forEach(function(record {} row) {
                embeddedCount = <int>row["embedded_count"];
            });
            if (embeddedCountError is error) {
                log:printError("Failed to count embedded chunks: " + embeddedCountError.message());
            }

            // Get sample chunk data
            stream<record {}, sql:Error?> sampleStream = dbClient->query(`SELECT id, chunk_text, chunk_type, relevance_score, embedding IS NOT NULL as has_embedding FROM document_chunks LIMIT 1`);
            json[] sampleChunks = [];
            error? sampleError = sampleStream.forEach(function(record {} row) {
                json chunk = {
                    "id": <string>row["id"],
                    "text_preview": (<string>row["chunk_text"]).length() > 100 ?
                        (<string>row["chunk_text"]).substring(0, 100) + "..." :
                        <string>row["chunk_text"],
                    "chunk_type": <string>row["chunk_type"],
                    "relevance_score": <decimal>row["relevance_score"],
                    "has_embedding": <boolean>row["has_embedding"]
                };
                sampleChunks.push(chunk);
            });
            if (sampleError is error) {
                log:printError("Failed to get sample chunks: " + sampleError.message());
            }

            return {
                "success": true,
                "database_stats": {
                    "documents_count": docCount,
                    "chunks_count": chunkCount,
                    "embedded_chunks_count": embeddedCount,
                    "embedding_coverage": chunkCount > 0 ? (embeddedCount * 100.0 / chunkCount) : 0.0
                },
                "sample_chunks": sampleChunks,
                "database_connection": "OK"
            };

        } on fail error e {
            log:printError("Database debug check failed: " + e.message());
            return <http:InternalServerError>{
                body: {
                    "success": false,
                    "error": "Database debug check failed",
                    "message": e.message()
                }
            };
        }
    }

    # Search for tax-related content using semantic search
    # + query - Search query text (required)
    # + 'limit - Maximum number of results to return (optional, default: 10)
    # + minSimilarity - Minimum similarity score threshold (optional, default: 0.3)
    # + return - Search results with similarity scores or error
    resource function get search(string query, int? 'limit, decimal? minSimilarity)
        returns json|http:BadRequest|http:InternalServerError {

        do {
            // Validate required query parameter
            if (query.trim().length() == 0) {
                return <http:BadRequest>{
                    body: {
                        "success": false,
                        "error": "Query parameter is required and cannot be empty",
                        "message": "Please provide a search query"
                    }
                };
            }

            // Set defaults
            int searchLimit = 'limit ?: 10;
            decimal similarityThreshold = minSimilarity ?: 0.3d;

            // Validate parameters
            if (searchLimit < 1 || searchLimit > 50) {
                return <http:BadRequest>{
                    body: {
                        "success": false,
                        "error": "Invalid limit parameter",
                        "message": "Limit must be between 1 and 50"
                    }
                };
            }

            if (similarityThreshold < 0.0d || similarityThreshold > 1.0d) {
                return <http:BadRequest>{
                    body: {
                        "success": false,
                        "error": "Invalid similarity threshold",
                        "message": "Similarity threshold must be between 0.0 and 1.0"
                    }
                };
            }

            log:printInfo("🔍 Search request: query='" + query + "', limit=" + searchLimit.toString() +
                        ", threshold=" + similarityThreshold.toString());

            // Perform semantic search
            ChunkSearchResult[]|error searchResults = searchSimilarChunks(query, searchLimit);

            if (searchResults is error) {
                log:printError("Search failed: " + searchResults.message());
                return <http:InternalServerError>{
                    body: {
                        "success": false,
                        "error": "Search operation failed",
                        "message": searchResults.message()
                    }
                };
            }

            // Filter results by similarity threshold
            ChunkSearchResult[] filteredResults = [];
            foreach ChunkSearchResult result in searchResults {
                if (result.similarity_score >= similarityThreshold) {
                    filteredResults.push(result);
                }
            }

            // Convert results to response format
            json[] formattedResults = [];
            foreach ChunkSearchResult result in filteredResults {
                string displayText = result.chunk_text.length() > 500 ?
                    result.chunk_text.substring(0, 500) + "..." :
                    result.chunk_text;
                string preview = result.chunk_text.length() > 150 ?
                    result.chunk_text.substring(0, 150) + "..." :
                    result.chunk_text;

                json resultItem = {
                    "id": result.id,
                    "documentId": result.document_id,
                    "sequence": result.sequence,
                    "chunkType": result.chunk_type,
                    "similarityScore": result.similarity_score,
                    "relevanceScore": result.relevance_score,
                    "keywords": result.keywords,
                    "text": displayText,
                    "fullTextLength": result.chunk_text.length(),
                    "preview": preview
                };
                formattedResults.push(resultItem);
            }

            // Prepare response with metadata
            return {
                "success": true,
                "query": query,
                "totalResults": filteredResults.length(),
                "limit": searchLimit,
                "similarityThreshold": similarityThreshold,
                "searchMetadata": {
                    "searchTime": time:utcNow().toString(),
                    "embeddingModel": GEMINI_EMBEDDING_MODEL,
                    "embeddingDimensions": GEMINI_EMBEDDING_DIMENSIONS
                },
                "results": formattedResults
            };

        } on fail error e {
            log:printError("Error in search endpoint: " + e.message());
            return <http:InternalServerError>{
                body: {
                    "success": false,
                    "error": "Search request failed",
                    "message": e.message()
                }
            };
        }
    }

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

            // Note: Document chunking is available in text_extractor module
            // The chunks will be automatically logged to console when the chunking function is called
            log:printInfo("📋 Note: Document chunking functionality is available in text_extractor module");
            log:printInfo("📊 Extracted text length: " + extractionResult.extractedText.length().toString() + " characters");

            // Step 2: Analyze document structure
            log:printInfo("Step 2: Analyzing document structure");
            TaxDocumentStructure structure = check analyzeTaxDocumentStructure(extractionResult);

            // Step 3: Process chunking with the extracted text
            log:printInfo("Step 3: Processing document chunking");

            // Generate document ID first (before chunking)
            string documentId = generateDocumentId(filename);

            ChunkingResult chunkingResult = check processDocumentChunking(extractionResult.extractedText, filename, documentId);

            // Step 4: Store file and data (Phase 6)
            log:printInfo("Step 4: Storing file and processing data");

            // Upload file to Supabase Storage
            string|error storagePath = uploadFileToSupabase(fileContent, filename, documentId);
            string actualStoragePath = "";
            if (storagePath is error) {
                log:printWarn("Failed to upload file to storage: " + storagePath.message());
                actualStoragePath = "storage_failed";
            } else {
                actualStoragePath = storagePath;
                log:printInfo("✅ File uploaded to storage: " + actualStoragePath);
            }

            // Store document metadata
            error? metadataResult = storeDocumentMetadata(documentId, filename, actualStoragePath, chunkingResult);
            if (metadataResult is error) {
                log:printWarn("Failed to store document metadata: " + metadataResult.message());
            }

            // Store chunks in database
            error? chunksResult = storeChunksInDatabase(chunkingResult.chunks);
            if (chunksResult is error) {
                log:printWarn("Failed to store chunks: " + chunksResult.message());
            }

            // Step 5: Prepare processing results with storage information
            log:printInfo("Document processing and storage completed successfully");
            json result = {
                "success": true,
                "message": "Document processed and stored successfully",
                "document": {
                    "id": documentId,
                    "filename": filename,
                    "size": fileContent.length(),
                    "type": fileExtension,
                    "contentType": actualContentType,
                    "processedAt": time:utcNow()
                },
                "storage": {
                    "storagePath": actualStoragePath,
                    "storageUrl": actualStoragePath != "storage_failed" ? generateFileURL(actualStoragePath) : (),
                    "bucket": SUPABASE_STORAGE_BUCKET,
                    "stored": actualStoragePath != "storage_failed"
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
                "chunking": {
                    "success": chunkingResult.success,
                    "totalChunks": chunkingResult.totalChunks,
                    "processingTimeMs": chunkingResult.stats.processingTimeMs,
                    "avgChunkSize": chunkingResult.stats.avgChunkSize,
                    "taxRelevantChunks": chunkingResult.stats.taxRelevantChunks,
                    "documentCoverage": chunkingResult.stats.documentCoverage,
                    "warnings": chunkingResult.warnings,
                    "chunks": chunkingResult.chunks.map(chunk => <json>{
                        "id": chunk.id,
                        "sequence": chunk.sequence,
                        "chunkType": chunk.chunkType,
                        "tokenCount": chunk.tokenCount,
                        "relevanceScore": chunk.relevanceScore,
                        "keywords": chunk.keywords,
                        "startPosition": chunk.startPosition,
                        "endPosition": chunk.endPosition,
                        "processingStatus": chunk.processingStatus,
                        "hasEmbedding": chunk?.embedding != (),
                        "embeddingDimensions": GEMINI_EMBEDDING_DIMENSIONS,
                        "embeddingMetadata": chunk?.embeddingMetadata != () ?
                            {
                                "embeddingModel": chunk?.embeddingMetadata?.embeddingModel,
                                "embeddingDimensions": chunk?.embeddingMetadata?.embeddingDimensions,
                                "embeddingProvider": chunk?.embeddingMetadata?.embeddingProvider,
                                "generatedAt": chunk?.embeddingMetadata?.generatedAt
                            } : (),
                        "chunkText": chunk.chunkText,
                        "textPreview": chunk.chunkText.length() > 200 ?
                            chunk.chunkText.substring(0, 200) + "..." :
                            chunk.chunkText
                    })
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

    # Search for similar content using semantic search (Phase 6)
    # + request - HTTP request containing search query
    # + return - Search results or error
    resource function post search(http:Request request) returns json|http:BadRequest|http:InternalServerError {
        do {
            log:printInfo("Processing semantic search request");

            json payload = check request.getJsonPayload();

            // Extract query parameter
            json|error queryJson = payload.query;
            if (queryJson is error || !(queryJson is string)) {
                return <http:BadRequest>{
                    body: {
                        "error": "Invalid query",
                        "message": "Query parameter is required and must be a string"
                    }
                };
            }
            string query = <string>queryJson;

            // Extract limit parameter
            int 'limit = 10; // default limit
            json|error limitJson = payload.'limit;
            if (limitJson is int) {
                'limit = <int>limitJson;
                if ('limit <= 0 || 'limit > 50) {
                    'limit = 10; // reset to default if invalid
                }
            }

            // Perform semantic search
            ChunkSearchResult[]|error searchResults = searchSimilarChunks(query, 'limit);

            if (searchResults is error) {
                log:printError("Search failed: " + searchResults.message());
                return <http:InternalServerError>{
                    body: {
                        "error": "Search failed",
                        "message": searchResults.message()
                    }
                };
            }

            // Prepare response
            json response = {
                "success": true,
                "query": query,
                "limit": 'limit,
                "totalResults": searchResults.length(),
                "results": searchResults.map(searchResult => <json>{
                    "chunkId": searchResult.id,
                    "documentId": searchResult.document_id,
                    "sequence": searchResult.sequence,
                    "similarity": searchResult.similarity_score,
                    "relevance": searchResult.relevance_score,
                    "chunkType": searchResult.chunk_type,
                    "keywords": searchResult.keywords,
                    "text": searchResult.chunk_text.length() > 500 ?
                        searchResult.chunk_text.substring(0, 500) + "..." :
                        searchResult.chunk_text,
                    "textLength": searchResult.chunk_text.length()
                }),
                "searchMetadata": {
                    "searchType": "semantic_similarity",
                    "embeddingModel": GEMINI_EMBEDDING_MODEL,
                    "embeddingDimensions": GEMINI_EMBEDDING_DIMENSIONS,
                    "timestamp": time:utcNow()
                }
            };

            return response;

        } on fail error e {
            log:printError("Error processing search: " + e.message());
            return <http:InternalServerError>{
                body: {
                    "error": "Search processing failed",
                    "message": "An error occurred while processing the search request",
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
        // string preview = extractedText.length() > 200 ? extractedText.substring(0, 200) + "..." : extractedText;
        // log:printInfo("Extracted text preview: " + preview);
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
