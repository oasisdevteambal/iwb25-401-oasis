import ballerina/log;

// Google Gemini API Configuration
// 
// This file contains configuration for Google Gemini API integration
// including API keys and model settings for embeddings and text generation.

// Google Gemini API Configuration
configurable string GEMINI_API_KEY = "AIzaSyBn6yGwy4qFCftrlcN_OMFKkRX6m_e8ibA";
configurable string GEMINI_BASE_URL = "https://generativelanguage.googleapis.com";
configurable string GEMINI_EMBEDDING_MODEL = "text-embedding-004";
configurable int GEMINI_EMBEDDING_DIMENSIONS = 768;
configurable string GEMINI_TEXT_MODEL = "gemini-1.5-flash";

// Embedding generation settings
configurable int EMBEDDING_BATCH_SIZE = 10;
configurable decimal EMBEDDING_TIMEOUT = 60.0;
configurable int EMBEDDING_RETRY_COUNT = 3;

# Initialize Gemini configuration and validate settings
#
# + return - true if configuration is valid, false otherwise
public function initializeGeminiConfig() returns boolean {
    if (GEMINI_API_KEY.length() == 0) {
        log:printError("❌ GEMINI_API_KEY is not configured. Please set the API key in Config.toml");
        return false;
    }

    log:printInfo("✅ Gemini API configuration initialized");
    log:printInfo("🔧 Embedding Model: " + GEMINI_EMBEDDING_MODEL);
    log:printInfo("🔧 Embedding Dimensions: " + GEMINI_EMBEDDING_DIMENSIONS.toString());
    log:printInfo("🔧 Text Model: " + GEMINI_TEXT_MODEL);

    return true;
}

# Get the full API endpoint for embedding generation
#
# + return - Complete API endpoint URL
public function getEmbeddingEndpoint() returns string {
    return GEMINI_BASE_URL + "/v1beta/models/" + GEMINI_EMBEDDING_MODEL + ":embedContent?key=" + GEMINI_API_KEY;
}

# Get the full API endpoint for batch embedding generation
#
# + return - Complete batch API endpoint URL
public function getBatchEmbeddingEndpoint() returns string {
    return GEMINI_BASE_URL + "/v1beta/models/" + GEMINI_EMBEDDING_MODEL + ":batchEmbedContents?key=" + GEMINI_API_KEY;
}

# Get the full API endpoint for text generation
#
# + return - Complete text generation API endpoint URL
public function getTextGenerationEndpoint() returns string {
    return GEMINI_BASE_URL + "/v1beta/models/" + GEMINI_TEXT_MODEL + ":generateContent?key=" + GEMINI_API_KEY;
}
