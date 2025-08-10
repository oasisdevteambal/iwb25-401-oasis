import ballerina/http;
import ballerina/log;

// Supabase Configuration
// 
// This file contains configuration for Supabase database and storage integration
// including connection settings and client initialization.

// Supabase Configuration
configurable string SUPABASE_URL = "https://ohdbwbrutlwikcmpprky.supabase.co";
configurable string SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9oZGJ3YnJ1dGx3aWtjbXBwcmt5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQxMzUyNzQsImV4cCI6MjA2OTcxMTI3NH0.t_H3kE7fliAXbjp8BFQIeS0i_orI-OYhbvQxsL65rW4";
configurable string SUPABASE_SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9oZGJ3YnJ1dGx3aWtjbXBwcmt5Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NDEzNTI3NCwiZXhwIjoyMDY5NzExMjc0fQ.BDM2DyLfQ3PcJs_9LLQenN8A73TKCIbGjpLMv4WWs9o";

// Storage Configuration
configurable string SUPABASE_STORAGE_BUCKET = "documents";
configurable int SUPABASE_CONNECTION_TIMEOUT = 60;
configurable int SUPABASE_RETRY_COUNT = 3;

// Database Configuration
configurable string SUPABASE_DB_HOST = "db.ohdbwbrutlwikcmpprky.supabase.co";
configurable string SUPABASE_DB_NAME = "postgres";
configurable string SUPABASE_DB_USER = "postgres";
configurable string SUPABASE_DB_PASSWORD = "1234";
configurable int SUPABASE_DB_PORT = 5432;

# Initialize Supabase configuration and validate settings
#
# + return - true if configuration is valid, false otherwise
public function initializeSupabaseConfig() returns boolean {
    if (SUPABASE_URL.length() == 0) {
        log:printError("❌ SUPABASE_URL is not configured");
        return false;
    }

    if (SUPABASE_SERVICE_ROLE_KEY.length() == 0) {
        log:printError("❌ SUPABASE_SERVICE_ROLE_KEY is not configured");
        return false;
    }

    log:printInfo("✅ Supabase configuration initialized");
    log:printInfo("🔧 Supabase URL: " + SUPABASE_URL);
    log:printInfo("🔧 Storage Bucket: " + SUPABASE_STORAGE_BUCKET);
    log:printInfo("🔧 Database Host: " + SUPABASE_DB_HOST);

    return true;
}

# Get Supabase Storage API endpoint
#
# + return - Complete storage API endpoint URL
public function getStorageEndpoint() returns string {
    return SUPABASE_URL + "/storage/v1";
}

# Get Supabase REST API endpoint
#
# + return - Complete REST API endpoint URL
public function getRestEndpoint() returns string {
    return SUPABASE_URL + "/rest/v1";
}

# Get headers for Supabase API requests (with service role key)
#
# + return - Headers map for authenticated requests
public function getServiceHeaders() returns map<string> {
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
public function getStorageHeaders(string contentType = "application/octet-stream") returns map<string> {
    return {
        "Authorization": "Bearer " + SUPABASE_SERVICE_ROLE_KEY,
        "apikey": SUPABASE_SERVICE_ROLE_KEY,
        "Content-Type": contentType
    };
}

# Get database connection parameters
#
# + return - Database connection configuration
public function getDatabaseConfig() returns record {
    string host;
    string database;
    string username;
    string password;
    int port;
} {
    return {
        host: SUPABASE_DB_HOST,
        database: SUPABASE_DB_NAME,
        username: SUPABASE_DB_USER,
        password: SUPABASE_DB_PASSWORD,
        port: SUPABASE_DB_PORT
    };
}
