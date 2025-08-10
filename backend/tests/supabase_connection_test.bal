// import ballerina/test;
// import ballerina/http;
// import ballerina/log;

// // Test configuration - hardcoded for initial testing
// string supabaseUrl = "https://ohdbwbrutlwikcmpprky.supabase.co";
// string supabaseServiceKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9oZGJ3YnJ1dGx3aWtjbXBwcmt5Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NDEzNTI3NCwiZXhwIjoyMDY5NzExMjc0fQ.BDM2DyLfQ3PcJs_9LLQenN8A73TKCIbGjpLMv4WWs9o";

// // HTTP client for Supabase REST API
// http:Client supabaseClient = check new (supabaseUrl);

// // Helper function to get standard Supabase headers
// function getSupabaseHeaders() returns map<string> {
//     return {
//         "apikey": supabaseServiceKey,
//         "Authorization": "Bearer " + supabaseServiceKey,
//         "Content-Type": "application/json"
//     };
// }

// @test:Config {}
// function testSupabaseConnection() returns error? {
//     log:printInfo("Testing Supabase connection...");
//     log:printInfo("Using URL: " + supabaseUrl);
    
//     // Test connection with proper Supabase headers
//     http:Response response = check supabaseClient->get("/rest/v1/tax_rules?limit=1", getSupabaseHeaders());
    
//     log:printInfo("Response status: " + response.statusCode.toString());
    
//     if (response.statusCode == 200) {
//         log:printInfo("✅ Supabase connection successful!");
//         json responsePayload = check response.getJsonPayload();
//         log:printInfo("Response: " + responsePayload.toString());
//     } else {
//         log:printError("❌ Connection failed with status: " + response.statusCode.toString());
//         string responseText = check response.getTextPayload();
//         log:printError("Error response: " + responseText);
//     }
    
//     test:assertEquals(response.statusCode, 200, "Supabase connection should return 200");
// }

// @test:Config {
//     dependsOn: [testSupabaseConnection]
// }
// function testTaxRulesTable() returns error? {
//     log:printInfo("Testing tax_rules table access...");
    
//     // Test reading from tax_rules table with proper headers
//     http:Response response = check supabaseClient->get("/rest/v1/tax_rules?select=id,rule_type,title", getSupabaseHeaders());
    
//     test:assertEquals(response.statusCode, 200, "Should be able to read from tax_rules table");
    
//     json responsePayload = check response.getJsonPayload();
//     test:assertTrue(responsePayload is json[], "Response should be a JSON array");
    
//     if responsePayload is json[] {
//         log:printInfo("✅ Tax rules table access successful!");
//         log:printInfo("Found " + responsePayload.length().toString() + " tax rules");
//     }
// }

// @test:Config {
//     dependsOn: [testSupabaseConnection]
// }
// function testTaxBracketsTable() returns error? {
//     log:printInfo("Testing tax_brackets table access...");
    
//     // Test reading from tax_brackets table with proper headers
//     http:Response response = check supabaseClient->get("/rest/v1/tax_brackets?select=id,rule_id,min_income,max_income,rate", getSupabaseHeaders());
    
//     test:assertEquals(response.statusCode, 200, "Should be able to read from tax_brackets table");
    
//     json responsePayload = check response.getJsonPayload();
//     test:assertTrue(responsePayload is json[], "Response should be a JSON array");
    
//     if responsePayload is json[] {
//         log:printInfo("✅ Tax brackets table access successful!");
//         log:printInfo("Found " + responsePayload.length().toString() + " tax brackets");
//     }
// }

// @test:Config {
//     dependsOn: [testSupabaseConnection]
// }
// function testFormSchemasTable() returns error? {
//     log:printInfo("Testing form_schemas table access...");
    
//     // Test reading from form_schemas table with proper headers
//     http:Response response = check supabaseClient->get("/rest/v1/form_schemas?select=id,schema_type,version,is_active", getSupabaseHeaders());
    
//     test:assertEquals(response.statusCode, 200, "Should be able to read from form_schemas table");
    
//     json responsePayload = check response.getJsonPayload();
//     test:assertTrue(responsePayload is json[], "Response should be a JSON array");
    
//     if responsePayload is json[] {
//         log:printInfo("✅ Form schemas table access successful!");
//         log:printInfo("Found " + responsePayload.length().toString() + " form schemas");
//     }
// }

// @test:Config {
//     dependsOn: [testTaxRulesTable, testTaxBracketsTable]
// }
// function testTaxRulesWithBrackets() returns error? {
//     log:printInfo("Testing tax rules with brackets join...");
    
//     // Test joining tax_rules with tax_brackets with proper headers
//     string query = "/rest/v1/tax_rules?select=id,rule_type,title,tax_brackets(min_income,max_income,rate,bracket_order)&rule_type=eq.income_tax";
//     http:Response response = check supabaseClient->get(query, getSupabaseHeaders());
    
//     test:assertEquals(response.statusCode, 200, "Should be able to join tax_rules with tax_brackets");
    
//     json responsePayload = check response.getJsonPayload();
//     test:assertTrue(responsePayload is json[], "Response should be a JSON array");
    
//     if responsePayload is json[] {
//         json[] rules = responsePayload;
//         if (rules.length() > 0) {
//             json firstRule = rules[0];
//             test:assertTrue(firstRule.tax_brackets is json[], "Should have tax_brackets array");
//             log:printInfo("✅ Tax rules with brackets join successful!");
//         } else {
//             log:printWarn("⚠️ No income tax rules found - make sure sample data is inserted");
//         }
//     }
// }

// @test:Config {
//     dependsOn: [testSupabaseConnection]
// }
// function testEnvironmentVariables() returns error? {
//     log:printInfo("Testing environment variables...");
    
//     test:assertNotEquals(supabaseUrl, "", "SUPABASE_URL should not be empty");
//     test:assertNotEquals(supabaseServiceKey, "", "SUPABASE_SERVICE_KEY should not be empty");
    
//     test:assertTrue(supabaseUrl.startsWith("https://"), "SUPABASE_URL should start with https://");
//     test:assertTrue(supabaseUrl.endsWith(".supabase.co"), "SUPABASE_URL should end with .supabase.co");
    
//     log:printInfo("✅ Environment variables are properly configured!");
//     log:printInfo("Supabase URL: " + supabaseUrl);
// }

// @test:Config {
//     dependsOn: [testSupabaseConnection]
// }
// function testSupabaseStorageAccess() returns error? {
//     log:printInfo("Testing Supabase Storage access...");
    
//     // Test storage bucket access with proper headers
//     http:Response response = check supabaseClient->get("/storage/v1/bucket", getSupabaseHeaders());
    
//     test:assertEquals(response.statusCode, 200, "Should be able to access storage buckets");
    
//     json responsePayload = check response.getJsonPayload();
//     test:assertTrue(responsePayload is json[], "Response should be a JSON array");
    
//     log:printInfo("✅ Supabase Storage access successful!");
    
//     // Check if documents bucket exists
//     if responsePayload is json[] {
//         json[] buckets = responsePayload;
//         boolean documentsExists = false;
//         foreach json bucket in buckets {
//             if bucket.name == "documents" {
//                 documentsExists = true;
//                 break;
//             }
//         }
        
//         if documentsExists {
//             log:printInfo("✅ Documents bucket found!");
//         } else {
//             log:printWarn("⚠️ Documents bucket not found - make sure to create it in Supabase Storage");
//         }
//     }
// }

// @test:Config {
//     dependsOn: [testSupabaseConnection]
// }
// function testCreateAndDeleteTestRecord() returns error? {
//     log:printInfo("Testing create and delete operations...");
    
//     // Create a test tax rule
//     json testRule = {
//         "rule_type": "test",
//         "rule_category": "testing",
//         "title": "Test Rule for Ballerina",
//         "description": "This is a test rule created by Ballerina test",
//         "rule_data": {"test": true},
//         "effective_date": "2024-01-01"
//     };
    
//     // Insert test record with proper headers
//     http:Request insertReq = new;
//     insertReq.setJsonPayload(testRule);
//     insertReq.setHeader("Prefer", "return=representation");
//     insertReq.setHeader("apikey", supabaseServiceKey);
//     insertReq.setHeader("Authorization", "Bearer " + supabaseServiceKey);
//     insertReq.setHeader("Content-Type", "application/json");
    
//     http:Response insertResponse = check supabaseClient->post("/rest/v1/tax_rules", insertReq);
//     test:assertEquals(insertResponse.statusCode, 201, "Should be able to create a test record");
    
//     json insertPayload = check insertResponse.getJsonPayload();
//     test:assertTrue(insertPayload is json[], "Insert response should be an array");
    
//     if insertPayload is json[] {
//         json[] createdRecords = insertPayload;
//         test:assertTrue(createdRecords.length() > 0, "Should return the created record");
        
//         json firstRecord = createdRecords[0];
//         if firstRecord is map<json> {
//             json? idValue = firstRecord["id"];
//             if idValue is int {
//                 int testRecordId = idValue;
//                 log:printInfo("✅ Test record created with ID: " + testRecordId.toString());
                
//                 // Delete test record with proper headers
//                 http:Request deleteReq = new;
//                 deleteReq.setHeader("apikey", supabaseServiceKey);
//                 deleteReq.setHeader("Authorization", "Bearer " + supabaseServiceKey);
//                 deleteReq.setHeader("Content-Type", "application/json");
                
//                 http:Response deleteResponse = check supabaseClient->delete("/rest/v1/tax_rules?id=eq." + testRecordId.toString(), deleteReq);
//                 test:assertEquals(deleteResponse.statusCode, 204, "Should be able to delete the test record");
                
//                 log:printInfo("✅ Test record deleted successfully!");
//             }
//         }
//     }
// }

// // Test summary function
// @test:Config {
//     dependsOn: [testSupabaseConnection, testTaxRulesTable, testTaxBracketsTable, testFormSchemasTable, 
//                 testTaxRulesWithBrackets, testEnvironmentVariables, testSupabaseStorageAccess, 
//                 testCreateAndDeleteTestRecord]
// }
// function testSummary() {
//     string separator = "==================================================";
//     log:printInfo(separator);
//     log:printInfo("🎉 ALL SUPABASE TESTS COMPLETED SUCCESSFULLY! 🎉");
//     log:printInfo(separator);
//     log:printInfo("✅ Database connection working");
//     log:printInfo("✅ All tables accessible");
//     log:printInfo("✅ Table relationships working");
//     log:printInfo("✅ Environment variables configured");
//     log:printInfo("✅ Storage access working");
//     log:printInfo("✅ CRUD operations working");
//     log:printInfo(separator);
//     log:printInfo("Your Supabase setup is ready for development! 🚀");
//     log:printInfo(separator);
// }
