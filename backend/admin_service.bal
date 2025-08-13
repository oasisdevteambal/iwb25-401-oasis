import ballerina/http;
import ballerina/log;
import ballerina/sql;

service /api/v1/admin on httpListener {

    // Backfill embeddings for tax_rules where embedding IS NULL
    // batchSize - number of rules to process in one pass (default 25)
    resource function post backfill\-embeddings(int? batchSize) returns json|http:InternalServerError {
        int size = batchSize ?: 25;
        if (size < 1) {
            size = 1;
        }
        if (size > 200) {
            size = 200;
        }

        log:printInfo("Starting tax_rules embedding backfill, batchSize=" + size.toString());
        int processed = 0;
        int updated = 0;
        int failed = 0;

        // Fetch candidates
        stream<record {}, sql:Error?> rs = dbClient->query(`
			SELECT id, title, description, rule_data
			FROM tax_rules
			WHERE embedding IS NULL
			ORDER BY updated_at NULLS LAST, created_at
			LIMIT ${size}
		`);

        json[] items = [];
        error? err = rs.forEach(function(record {} row) {
            processed += 1;
            string id = <string>row["id"];
            string title = <string>row["title"];
            var descRaw = row["description"];
            string desc = descRaw is string ? descRaw : "";
            json data = <json>row["rule_data"];

            // Create embedding text
            string text = title + (desc.length() > 0 ? (" — " + desc) : "");
            text += "\nrule_data: " + data.toString();

            // Generate embedding
            decimal[]|error emb = generateEmbedding(text);
            if (emb is decimal[]) {
                string embStr = "[";
                int idx = 0;
                foreach decimal v in emb {
                    if (idx > 0) {
                        embStr += ",";
                    }
                    embStr += v.toString();
                    idx += 1;
                }
                embStr += "]";

                sql:ParameterizedQuery upd = `
					UPDATE tax_rules
					SET embedding = ${embStr}::vector(768), updated_at = NOW()
					WHERE id = ${id}
				`;
                var res = dbClient->execute(upd);
                if (res is sql:Error) {
                    failed += 1;
                    log:printWarn("Backfill update failed for rule " + id + ": " + res.message());
                } else {
                    updated += 1;
                }
            } else {
                failed += 1;
                log:printWarn("Embedding generation failed for rule " + id + ": " + emb.message());
            }

            items.push({"id": id, "title": title});
        });

        if (err is error) {
            log:printError("Backfill query/iteration failed: " + err.message());
            return <http:InternalServerError>{
                body: {"success": false, "error": err.message()}
            };
        }

        if (failed > 0) {
            return <http:InternalServerError>{
                body: {
                    "success": false,
                    "requestedBatchSize": size,
                    "processed": processed,
                    "updated": updated,
                    "failed": failed,
                    "items": items,
                    "message": "One or more embeddings failed to backfill"
                }
            };
        }

        return {
            "success": true,
            "requestedBatchSize": size,
            "processed": processed,
            "updated": updated,
            "failed": failed,
            "items": items
        };
    }

    // Manual trigger to (re)generate and activate a form schema for a given type and optional date
    // schemaType examples: "income_tax" (currently supported). date format: YYYY-MM-DD (optional; defaults to today)
    resource function post generate\-schema(string schemaType, string? date)
            returns json|http:BadRequest|http:InternalServerError {
        do {
            json|error gen = generateAndActivateFormSchema(schemaType, date);
            if (gen is error) {
                // If generation failed, surface as 500 with reason
                return <http:InternalServerError>{
                    body: {
                        "success": false,
                        "error": gen.message()
                    }
                };
            }
            return {
                "success": true,
                "schemaType": schemaType,
                "result": gen
            };
        } on fail error e {
            return <http:InternalServerError>{
                body: {"success": false, "error": e.message()}
            };
        }
    }
}

