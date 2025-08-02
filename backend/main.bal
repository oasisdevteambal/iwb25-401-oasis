import ballerina/http;
import ballerina/io;
import ballerina/time;

// HTTP listener on port 5000 - public to be accessible by other services
public listener http:Listener httpListener = new (5000);

// Health check service
service /api/health on httpListener {

    # Health check endpoint
    # + return - Health status response
    resource function get .() returns json {
        return {
            "status": "healthy",
            "service": "Sri Lankan Tax Calculation API",
            "version": "0.1.0",
            "timestamp": time:utcNow()
        };
    }
}

// Main API service - placeholder for other endpoints
service /api/v1 on httpListener {

    # Welcome endpoint
    # + return - Welcome message
    resource function get .() returns json {
        return {
            "message": "Welcome to Sri Lankan Tax Calculation API",
            "version": "v1",
            "endpoints": [
                "/api/health - Health check",
                "/api/documents - Document management",
                "/api/v1/tax/calculate - Tax calculations",
                "/api/v1/forms/schema - Form schemas",
                "/api/v1/admin - Admin operations"
            ]
        };
    }
}

public function main() {
    io:println("Starting Sri Lankan Tax Calculation API server on port 5000...");
    io:println("Health check endpoint: http://localhost:5000/api/health");
    io:println("API endpoint: http://localhost:5000/api/v1");
    io:println("Press Ctrl+C to stop the server");
}
