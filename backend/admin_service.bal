import ballerina/http;
import ballerina/lang.value as v;
import ballerina/log;
import ballerina/sql;
import ballerina/time;

configurable string GEMINI_BASE_URL = "https://generativelanguage.googleapis.com";
configurable string GEMINI_TEXT_MODEL = "gemini-1.5-flash";

// Conservative caps to bound LLM latency
final int CUE_LIMIT = 300; // max number of chunks to include as cues
final int CUE_CHAR_CAP = 12000; // cap for concatenated cue text length

service /api/v1/admin on httpListener {
    # Preflight aggregation check: returns counts of evidence rules and aggregated rules for a type/date
    # + schemaType - One of income_tax, vat, paye
    # + date - Optional YYYY-MM-DD; defaults to today (UTC)
    # + return - JSON with evidenceCount and aggregatedCount
    resource function get preflight(string schemaType, string? date)
            returns json|http:BadRequest|http:InternalServerError {
        string calcType = schemaType.toLowerAscii();
        if (!(calcType == "income_tax" || calcType == "vat" || calcType == "paye")) {
            return <http:BadRequest>{body: {"success": false, "error": "Unsupported schemaType"}};
        }
        string targetDate;
        if (date is string && date.trim().length() > 0) {
            targetDate = date;
        } else {
            time:Civil civ = time:utcToCivil(time:utcNow());
            string month = civ.month < 10 ? ("0" + civ.month.toString()) : civ.month.toString();
            string day = civ.day < 10 ? ("0" + civ.day.toString()) : civ.day.toString();
            targetDate = civ.year.toString() + "-" + month + "-" + day;
        }

        int evidenceCount = 0;
        int aggregatedCount = 0;
        // Count evidence rules valid for date
        stream<record {}, sql:Error?> rs1 = dbClient->query(`
            SELECT COUNT(*) AS c FROM tax_rules r
            WHERE r.rule_category = ${calcType}
              AND NOT (r.rule_type ILIKE 'aggregated%')
              AND (r.effective_date IS NULL OR r.effective_date <= ${targetDate}::date)
              AND (r.expiry_date IS NULL OR r.expiry_date >= ${targetDate}::date)`);
        error? e1 = rs1.forEach(function(record {} row) {
            evidenceCount = <int>row["c"];
        });
        if (e1 is error) {
            return <http:InternalServerError>{body: {"success": false, "error": e1.message()}};
        }
        // Count aggregated rule exactly for date
        stream<record {}, sql:Error?> rs2 = dbClient->query(`
            SELECT COUNT(*) AS c FROM tax_rules r
            WHERE r.rule_category = ${calcType}
              AND r.rule_type ILIKE 'aggregated%'
              AND r.effective_date = ${targetDate}::date`);
        error? e2 = rs2.forEach(function(record {} row) {
            aggregatedCount = <int>row["c"];
        });
        if (e2 is error) {
            return <http:InternalServerError>{body: {"success": false, "error": e2.message()}};
        }

        return {
            "success": true,
            "schemaType": calcType,
            "date": targetDate,
            "evidenceCount": evidenceCount,
            "aggregatedCount": aggregatedCount,
            "aggregatedExists": aggregatedCount > 0
        };
    }

    // Aggregate rules for a given schemaType and date, then generate+activate form schema
    resource function post aggregate(@http:Payload json payload)
            returns json|http:BadRequest|http:InternalServerError {
        if (!(payload is map<json>)) {
            return <http:BadRequest>{body: {"success": false, "error": "INVALID_PAYLOAD"}};
        }
        map<json> p = <map<json>>payload;
        string calcType = "";
        json? stJ = p["schemaType"];
        if (stJ is string) {
            calcType = stJ.toLowerAscii();
        } else {
            return <http:BadRequest>{body: {"success": false, "error": "schemaType required"}};
        }
        if (!(calcType == "income_tax" || calcType == "vat" || calcType == "paye")) {
            return <http:BadRequest>{body: {"success": false, "error": "Unsupported schemaType"}};
        }
        string targetDate;
        json? dj = p["date"];
        if (dj is string && dj.trim().length() > 0) {
            targetDate = dj;
        } else {
            time:Civil civ = time:utcToCivil(time:utcNow());
            string month = civ.month < 10 ? ("0" + civ.month.toString()) : civ.month.toString();
            string day = civ.day < 10 ? ("0" + civ.day.toString()) : civ.day.toString();
            targetDate = civ.year.toString() + "-" + month + "-" + day;
        }

        json|error res = aggregateRulesFor(calcType, targetDate);
        if (res is error) {
            return <http:InternalServerError>{body: {"success": false, "error": res.message()}};
        }
        json ok = {"success": true, "schemaType": calcType, "date": targetDate, "aggregation": res};
        return ok;
    }

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

    // Offline LLM extraction entry: POST /api/v1/admin/extract-metadata?docId=...&schemaType=...
    // Gathers deterministic cues, calls LLM text model with strict prompt, stores a batch and proposals.
    resource function post extract\-metadata(string docId, string schemaType)
            returns json|http:BadRequest|http:InternalServerError {
        string calcType = schemaType.toLowerAscii();
        if (!(calcType == "income_tax" || calcType == "vat" || calcType == "paye")) {
            return <http:BadRequest>{body: {"success": false, "error": "Unsupported schemaType"}};
        }

        // 1) Collect cues deterministically
        record {string id; int seq; string kind; string text;}[] cues = checkpanic collectCuesForDocument(docId);
        if (cues.length() == 0) {
            return <http:BadRequest>{body: {"success": false, "error": "No cues found for document"}};
        }

        // 2) Call LLM offline with strict prompt
        json|error llm = runStrictMetadataLLM(calcType, cues);
        if (llm is error) {
            log:printError("[extract-metadata] LLM processing failed: " + llm.message());
            return <http:InternalServerError>{body: {"success": false, "error": llm.message()}};
        }
        log:printInfo("[extract-metadata] LLM JSON received");

        // 3) Validate JSON shape (fail closed)
        json|error valid = validateMetadataJson(llm);
        if (valid is error) {
            return <http:BadRequest>{body: {"success": false, "error": valid.message()}};
        }
        log:printInfo("[extract-metadata] Metadata JSON validated");

        // 4) Canonical registry check: warn on unknown keys but do not block extraction
        string[] varIds = extractAllVariableIds(llm);
        error? regErr = ensureAllVariablesExist(varIds);
        if (regErr is error) {
            log:printWarn("[extract-metadata] Unknown canonical ids detected; proceeding to create proposals. Details: " + regErr.message());
        } else {
            log:printInfo("[extract-metadata] Canonical IDs verified count=" + varIds.length().toString());
        }

        // 5) Persist batch + proposals
        json saved = checkpanic persistLlmBatchAndProposals(docId, calcType, llm, cues);
        log:printInfo("[extract-metadata] Persisted proposals OK");
        return {"success": true, "result": saved};
    }

    // Apply approved metadata to evidence rule(s) for a document: POST /api/v1/admin/apply-metadata
    // payload: { docId, schemaType }
    resource function post apply\-metadata(@http:Payload json payload)
            returns json|http:BadRequest|http:InternalServerError {
        if (!(payload is map<json>)) {
            return <http:BadRequest>{body: {"success": false, "error": "INVALID_PAYLOAD"}};
        }
        map<json> p = <map<json>>payload;
        string docId = (<string>(p["docId"] ?: "")).trim();
        string calcType = (<string>(p["schemaType"] ?: "")).trim().toLowerAscii();
        if (docId.length() == 0 || calcType.length() == 0) {
            return <http:BadRequest>{body: {"success": false, "error": "docId and schemaType required"}};
        }

        // Load the most recent completed batch and its approved/mapped items
        json|error merged = mergeApprovedMetadataForDocument(docId, calcType);
        if (merged is error) {
            return <http:InternalServerError>{body: {"success": false, "error": merged.message()}};
        }

        // Persist onto the latest evidence rule for this type/date window
        json|error res = upsertMetadataIntoEvidenceRule(docId, calcType, <json>merged);
        if (res is error) {
            return <http:InternalServerError>{body: {"success": false, "error": res.message()}};
        }
        return {"success": true, "updated": res};
    }

    // List LLM proposals for a document: GET /api/v1/admin/proposals?docId=...&status=pending[&schemaType=...]
    resource function get proposals(string docId, string? status, string? schemaType) returns json|http:InternalServerError|http:BadRequest {
        string st = status is string && status.length() > 0 ? status : "pending";
        if (!(st == "pending" || st == "approved" || st == "rejected" || st == "mapped")) {
            return <http:BadRequest>{body: {"success": false, "error": "invalid status"}};
        }
        // Latest batch for doc
        string batchId = "";
        if (schemaType is string && schemaType.length() > 0) {
            stream<record {}, sql:Error?> r1 = dbClient->query(`SELECT id FROM llm_extraction_batches WHERE source_document_id = ${docId} AND tax_type = ${schemaType} ORDER BY created_at DESC LIMIT 1`);
            error? e1 = r1.forEach(function(record {} row) {
                batchId = <string>row["id"];
            });
            if (e1 is error) {
                return <http:InternalServerError>{body: {"success": false, "error": e1.message()}};
            }
        } else {
            stream<record {}, sql:Error?> r1 = dbClient->query(`SELECT id FROM llm_extraction_batches WHERE source_document_id = ${docId} ORDER BY created_at DESC LIMIT 1`);
            error? e1 = r1.forEach(function(record {} row) {
                batchId = <string>row["id"];
            });
            if (e1 is error) {
                return <http:InternalServerError>{body: {"success": false, "error": e1.message()}};
            }
        }
        if (batchId.length() == 0) {
            return {"success": true, "items": []};
        }
        // Proposals
        json[] items = [];
        stream<record {}, sql:Error?> r2 = dbClient->query(`
            SELECT id, term, suggested_variable_key, suggested_metadata, status, mapped_variable_id
            FROM llm_extraction_proposals
            WHERE batch_id = ${batchId}::uuid AND status = ${st}
            ORDER BY created_at`);
        error? e2 = r2.forEach(function(record {} row) {
            json svk = row["suggested_variable_key"] is () ? () : <json>row["suggested_variable_key"];
            json smd = row["suggested_metadata"] is () ? () : <json>row["suggested_metadata"];
            // If DB driver returns JSONB as string, parse it into a JSON value for clients
            if (smd is string) {
                json|error parsed = parseJsonStrictLocal(<string>smd);
                if (parsed is json) {
                    smd = parsed;
                }
            }
            json mvid = row["mapped_variable_id"] is () ? () : <json>row["mapped_variable_id"];
            items.push({
                "id": <string>row["id"],
                "term": <string>row["term"],
                "suggested_variable_key": svk,
                "suggested_metadata": smd,
                "status": <string>row["status"],
                "mapped_variable_id": mvid
            });
        });
        if (e2 is error) {
            return <http:InternalServerError>{body: {"success": false, "error": e2.message()}};
        }
        return {"success": true, "items": items};
    }

    // Approve/map a proposal: POST /api/v1/admin/proposals/approve { proposalId, variableKey }
    resource function post proposals/approve(@http:Payload json payload) returns json|http:BadRequest|http:InternalServerError {
        if (!(payload is map<json>)) {
            return <http:BadRequest>{body: {"success": false, "error": "INVALID_PAYLOAD"}};
        }
        map<json> p = <map<json>>payload;
        string propId = <string>(p["proposalId"] ?: "");
        string varKey = <string>(p["variableKey"] ?: "");
        if (propId.length() == 0 || varKey.length() == 0) {
            return <http:BadRequest>{body: {"success": false, "error": "proposalId and variableKey required"}};
        }
        // Resolve canonical_variables.id
        string varId = "";
        stream<record {}, sql:Error?> r = dbClient->query(`SELECT id FROM canonical_variables WHERE key = ${varKey} AND is_active = true LIMIT 1`);
        error? e = r.forEach(function(record {} row) {
            varId = <string>row["id"];
        });
        if (e is error) {
            return <http:InternalServerError>{body: {"success": false, "error": e.message()}};
        }
        if (varId.length() == 0) {
            return <http:BadRequest>{body: {"success": false, "error": "Unknown canonical key"}};
        }
        // Update proposal
        var up = dbClient->execute(`UPDATE llm_extraction_proposals SET status = 'approved', mapped_variable_id = ${varId}::uuid, decided_at = NOW() WHERE id = ${propId}::uuid`);
        if (up is sql:Error) {
            return <http:InternalServerError>{body: {"success": false, "error": up.message()}};
        }
        return {"success": true, "proposalId": propId, "mapped_variable_id": varId};
    }

    // Reject a proposal: POST /api/v1/admin/proposals/reject { proposalId }
    resource function post proposals/reject(@http:Payload json payload) returns json|http:BadRequest|http:InternalServerError {
        if (!(payload is map<json>)) {
            return <http:BadRequest>{body: {"success": false, "error": "INVALID_PAYLOAD"}};
        }
        map<json> p = <map<json>>payload;
        string propId = <string>(p["proposalId"] ?: "");
        if (propId.length() == 0) {
            return <http:BadRequest>{body: {"success": false, "error": "proposalId required"}};
        }
        var up = dbClient->execute(`UPDATE llm_extraction_proposals SET status = 'rejected', mapped_variable_id = NULL, decided_at = NOW() WHERE id = ${propId}::uuid`);
        if (up is sql:Error) {
            return <http:InternalServerError>{body: {"success": false, "error": up.message()}};
        }
        return {"success": true, "proposalId": propId, "status": "rejected"};
    }

    // Upsert canonical variable: POST /api/v1/admin/canonical_variables/upsert { key, label?, dataType?, unit?, title?, category?, isActive? }
    resource function post canonical_variables/upsert(@http:Payload json payload)
            returns json|http:BadRequest|http:InternalServerError {
        if (!(payload is map<json>)) {
            return <http:BadRequest>{body: {"success": false, "error": "INVALID_PAYLOAD"}};
        }
        map<json> p = <map<json>>payload;
        string key = <string>(p["key"] ?: "");
        if (key.length() == 0) {
            return <http:BadRequest>{body: {"success": false, "error": "key required"}};
        }
        // Optional fields, with safe defaults for NOT NULL columns
        string label = "";
        var lbl = p["label"] ?: p["title"] ?: ();
        if (lbl is string && lbl.length() > 0) {
            label = lbl;
        } else {
            label = key; // default label to key
        }
        string dataType = "";
        var dt = p["dataType"] ?: p["type"] ?: ();
        if (dt is string) {
            string dts = dt.toLowerAscii();
            if (dts == "string" || dts == "number" || dts == "integer" || dts == "boolean" || dts == "date" || dts == "currency" || dts == "percent") {
                dataType = dts;
            }
        }
        if (dataType.length() == 0) {
            dataType = "string"; // schema constraint allows this
        }
        // Try to find existing
        string id = "";
        stream<record {}, sql:Error?> r1 = dbClient->query(`SELECT id FROM canonical_variables WHERE key = ${key} LIMIT 1`);
        error? e1 = r1.forEach(function(record {} row) {
            id = <string>row["id"];
        });
        if (e1 is error) {
            return <http:InternalServerError>{body: {"success": false, "error": e1.message()}};
        }
        if (id.length() == 0) {
            // Insert with required NOT NULL columns present (key, label, data_type)
            var ins = dbClient->execute(`INSERT INTO canonical_variables (key, label, data_type, is_active) VALUES (${key}, ${label}, ${dataType}, true)`);
            if (ins is sql:Error) {
                return <http:InternalServerError>{body: {"success": false, "error": ins.message()}};
            }
        } else {
            // Ensure active and update label/data_type if provided
            var up = dbClient->execute(`UPDATE canonical_variables SET is_active = true, label = COALESCE(${label}, label), data_type = COALESCE(${dataType}, data_type) WHERE id = ${id}::uuid`);
            if (up is sql:Error) {
                return <http:InternalServerError>{body: {"success": false, "error": up.message()}};
            }
        }
        // Fetch id again
        id = "";
        stream<record {}, sql:Error?> r2 = dbClient->query(`SELECT id, is_active FROM canonical_variables WHERE key = ${key} LIMIT 1`);
        boolean active = true;
        error? e2 = r2.forEach(function(record {} row) {
            id = <string>row["id"];
            var a = row["is_active"];
            active = a is boolean ? <boolean>a : true;
        });
        if (e2 is error || id.length() == 0) {
            return <http:InternalServerError>{body: {"success": false, "error": "Failed to upsert canonical variable"}};
        }
        return {"success": true, "id": id, "key": key, "is_active": active};
    }
}

// ===================== Helper functions (module scope) =====================

// Dedicated Gemini text client with conservative timeout to avoid long hangs
http:Client geminiTextClient = check new (GEMINI_BASE_URL, {
    timeout: 25.0,
    retryConfig: {count: 1, interval: 1.0}
});

type Cue record {
    string id;
    int seq;
    string kind;
    string text;
};

function collectCuesForDocument(string docId) returns Cue[]|error {
    Cue[] out = [];
    // Headings, tables, and lines that include numbers or definition keywords
    stream<record {}, sql:Error?> rs = dbClient->query(`
                SELECT id, chunk_sequence AS seq, chunk_type, chunk_text
                FROM document_chunks
                WHERE document_id = ${docId}
                    AND (chunk_type = 'header' OR chunk_type = 'table' OR chunk_text ~ '[0-9]' OR chunk_text ILIKE '%definition%')
                ORDER BY chunk_sequence
                LIMIT ${CUE_LIMIT}
        `);
    error? e = rs.forEach(function(record {} row) {
        out.push({id: <string>row["id"], seq: <int>row["seq"], kind: <string>row["chunk_type"], text: <string>row["chunk_text"]});
    });
    if (e is error) {
        return error("Cue collection failed: " + e.message());
    }
    return out;
}

function runStrictMetadataLLM(string calcType, Cue[] cues) returns json|error {
    // Build a compact prompt with explicit JSON schema and constraints.
    string sys = "You are an expert tax metadata extractor. Output ONLY strict JSON with canonical ids; never invent numbers.";
    string schema = "{\n  \"required_variables\": [string],\n  \"field_metadata\": { [key: string]: {\n    \"type\": \"number|string|integer|boolean|date\",\n    \"title\": string,\n    \"minimum\"?: number,\n    \"maximum\"?: number,\n    \"unit\"?: string,\n    \"source_refs\": [{\"chunkId\": string, \"line\": number}]\n  } },\n  \"ui_order\": [string],\n  \"formulas\": [ ]\n}";
    string cueText = "";
    int cueCount = cues.length();
    foreach Cue c in cues {
        cueText += "\n# [" + c.seq.toString() + "] (" + c.kind + ")\n" + c.text;
    }
    // Hard cap prompt size to keep request bounded
    if (cueText.length() > CUE_CHAR_CAP) {
        cueText = cueText.substring(0, CUE_CHAR_CAP);
    }
    log:printInfo("[extract-metadata] LLM request start: type=" + calcType + ", cues=" + cueCount.toString() + ", promptChars=" + cueText.length().toString());
    json body = {
        "contents": [
            {"role": "user", "parts": [{"text": sys + "\nTax type: " + calcType + "\nJSON schema:" + schema + "\nCues:" + cueText + "\nRespond with JSON only."}]}
        ]
    };
    string path = "/v1beta/models/" + GEMINI_TEXT_MODEL + ":generateContent?key=" + GEMINI_API_KEY;
    log:printInfo("[extract-metadata] Sending request to Gemini model '" + GEMINI_TEXT_MODEL + "'");
    http:Response|error resp = geminiTextClient->post(path, body);
    if (resp is error) {
        return error("LLM call failed: " + resp.message());
    }
    log:printInfo("[extract-metadata] LLM responded");
    json|error payload = resp.getJsonPayload();
    if (payload is error) {
        return error("LLM response parse failed: " + payload.message());
    }
    // Extract text from candidates
    string out = "";
    if (payload is map<json> && payload.hasKey("candidates")) {
        var candJ = (<map<json>>payload)["candidates"];
        if (candJ is json[] && candJ.length() > 0) {
            json c0 = candJ[0];
            if (c0 is map<json>) {
                var content = c0["content"];
                if (content is map<json>) {
                    var parts = content["parts"];
                    if (parts is json[] && parts.length() > 0) {
                        json p0 = parts[0];
                        if (p0 is map<json>) {
                            var txt = p0["text"];
                            if (txt is string) {
                                out = txt;
                            }
                        }
                    }
                }
            }
        }
    }
    if (out.length() == 0) {
        return error("LLM returned empty content");
    }
    // Sanitize potential Markdown code fences/backticks and extract the JSON core
    string cleaned = sanitizeLlmJsonString(out);
    log:printInfo("[extract-metadata] LLM text length=" + out.length().toString() + ", cleaned length=" + cleaned.length().toString());
    log:printInfo("[extract-metadata] Cleaned preview=" + shortPreview(cleaned, 200));
    log:printInfo("[extract-metadata] Parsing cleaned JSON locally (strict parser)...");
    json|error parsed = parseJsonStrictLocal(cleaned);
    if (parsed is error) {
        return error("Invalid JSON from LLM: " + parsed.message());
    }
    json|error normalized = normalizeLlmJson(<json>parsed);
    if (normalized is error) {
        return error("Invalid LLM JSON shape: " + normalized.message());
    }
    log:printInfo("[extract-metadata] LLM JSON normalized OK");
    return <json>normalized;
}

// Remove Markdown fences and isolate the JSON body (object or array)
function sanitizeLlmJsonString(string s) returns string {
    string t = s.trim();
    // Strip starting triple backticks with optional language tag
    if (t.startsWith("```")) {
        // Remove the first line (``` or ```json)
        int? nl = t.indexOf("\n");
        if (nl is int) {
            int nli = <int>nl;
            if (nli >= 0 && nli + 1 <= t.length()) {
                t = t.substring(nli + 1);
            } else {
                // No newline; just drop fences
                t = removeAllOccurrences(t, "```");
            }
        } else {
            // No newline; just drop fences
            t = removeAllOccurrences(t, "```");
        }
    }
    // Strip trailing fence if present
    if (t.endsWith("```")) {
        int len = t.length();
        if (len >= 3) {
            t = t.substring(0, len - 3).trim();
        }
    }
    // Remove stray backticks
    t = removeAllOccurrences(t, "`");
    // If the model prefixed with 'json' as a word, drop that token at the start
    if (t.startsWith("json\n") || t.startsWith("JSON\n")) {
        int? nl2 = t.indexOf("\n");
        if (nl2 is int) {
            int nl2i = <int>nl2;
            if (nl2i >= 0 && nl2i + 1 <= t.length()) {
                t = t.substring(nl2i + 1);
            }
        }
    }
    // Extract the first JSON object or array if extra prose slipped in
    int? objStart = t.indexOf("{");
    int? objEnd = t.lastIndexOf("}");
    int? arrStart = t.indexOf("[");
    int? arrEnd = t.lastIndexOf("]");
    if (objStart is int && objEnd is int && objEnd >= objStart) {
        int objStartIdx = <int>objStart;
        int objEndIdx = <int>objEnd;
        return t.substring(objStartIdx, objEndIdx + 1);
    }
    if (arrStart is int && arrEnd is int && arrEnd >= arrStart) {
        int arrStartIdx = <int>arrStart;
        int arrEndIdx = <int>arrEnd;
        return t.substring(arrStartIdx, arrEndIdx + 1);
    }
    return t;
}

// Safe short preview for logs
function shortPreview(string s, int maxLen) returns string {
    int n = s.length();
    if (n <= maxLen) {
        return s;
    }
    string head = s.substring(0, maxLen);
    return head + "...<" + (n - maxLen).toString() + " more chars>";
}

// Parse a JSON string strictly via PostgreSQL cast to jsonb and return as Ballerina json
function parseJsonStrict(string text) returns json|error {
    json out = {};
    stream<record {}, sql:Error?> prs = dbClient->query(`SELECT ${text}::jsonb AS js`);
    error? pe = prs.forEach(function(record {} row) {
        out = <json>row["js"];
    });
    if (pe is error) {
        return error("JSON parse failed: " + pe.message());
    }
    return out;
}

// Local strict JSON parsing without DB round-trip
function parseJsonStrictLocal(string text) returns json|error {
    // v:fromJsonString throws on invalid JSON
    var r = v:fromJsonString(text);
    if (r is error) {
        return error("JSON parse failed: " + r.message());
    }
    // Ensure result is a json typed value
    json j = <json>r;
    return j;
}

// Normalize LLM output to a single JSON object: accept an object, or array with first object, or a JSON string
function normalizeLlmJson(json data) returns json|error {
    // Already an object
    if (data is map<json>) {
        return data;
    }
    // If array, pick first object element
    if (data is json[]) {
        json[] arr = <json[]>data;
        foreach json item in arr {
            if (item is map<json>) {
                return item;
            }
        }
        return error("array contains no JSON object");
    }
    // If string containing JSON, parse once more
    if (data is string) {
        string s = <string>data;
        string c2 = sanitizeLlmJsonString(s);
        json|error p2 = parseJsonStrict(c2);
        if (p2 is error) {
            return error("embedded JSON parse failed: " + p2.message());
        }
        return normalizeLlmJson(<json>p2);
    }
    return error("unsupported JSON type");
}

// Simple helper to remove all occurrences of a substring (no regex)
function removeAllOccurrences(string src, string sub) returns string {
    if (sub.length() == 0) {
        return src;
    }
    string out = "";
    int i = 0;
    int n = src.length();
    int subLen = sub.length();
    while (i < n) {
        string rest = src.substring(i);
        int? rel = rest.indexOf(sub);
        if (rel is int && rel >= 0) {
            int idx = i + <int>rel;
            // append up to idx (exclusive)
            out += src.substring(i, idx);
            i = idx + subLen;
        } else {
            // append rest and break
            out += rest;
            break;
        }
    }
    return out;
}

function validateMetadataJson(json data) returns json|error {
    if (!(data is map<json>)) {
        return error("Invalid metadata: not an object");
    }
    map<json> m = <map<json>>data;
    if (!(m.hasKey("required_variables") && m.hasKey("field_metadata") && m.hasKey("ui_order") && m.hasKey("formulas"))) {
        return error("Invalid metadata: missing required keys");
    }
    return data;
}

function extractAllVariableIds(json data) returns string[] {
    string[] ids = [];
    if (data is map<json>) {
        map<json> m = <map<json>>data;
        var rv = m["required_variables"];
        if (rv is json[]) {
            foreach var v in rv {
                if (v is string) {
                    ids.push(v);
                }
            }
        }
        var fm = m["field_metadata"];
        if (fm is map<json>) {
            foreach var k in fm.keys() {
                ids.push(k);
            }
        }
        var ui = m["ui_order"];
        if (ui is json[]) {
            foreach var v in ui {
                if (v is string) {
                    ids.push(v);
                }
            }
        }
    }
    // dedupe
    string[] outIds = [];
    map<boolean> seen = {};
    foreach string id in ids {
        if (!seen.hasKey(id)) {
            seen[id] = true;
            outIds.push(id);
        }
    }
    return outIds;
}

function ensureAllVariablesExist(string[] ids) returns error? {
    if (ids.length() == 0) {
        return;
    }
    // Query canonical_variables by key
    sql:ParameterizedQuery q = `SELECT key FROM canonical_variables WHERE key = ANY(${ids}) AND is_active = true`;
    map<boolean> present = {};
    stream<record {}, sql:Error?> rs = dbClient->query(q);
    error? e = rs.forEach(function(record {} row) {
        present[<string>row["key"]] = true;
    });
    if (e is error) {
        return error("Registry lookup failed: " + e.message());
    }
    foreach string id in ids {
        if (!present.hasKey(id)) {
            return error("Unknown canonical id: " + id);
        }
    }
}

function persistLlmBatchAndProposals(string docId, string calcType, json llm, Cue[] cues) returns json|error {
    // Create batch row
    var ins = dbClient->execute(`
        INSERT INTO llm_extraction_batches (source_document_id, tax_type, status, proposal_count, details, created_at)
        VALUES (${docId}, ${calcType}, 'completed', 0, ${llm.toString()}::jsonb, NOW()) RETURNING id`);
    if (ins is sql:Error) {
        return error("Failed to insert batch: " + ins.message());
    }
    // Fetch id
    string batchId = "";
    stream<record {}, sql:Error?> rs = dbClient->query(`SELECT id FROM llm_extraction_batches WHERE source_document_id = ${docId} ORDER BY created_at DESC LIMIT 1`);
    error? e = rs.forEach(function(record {} row) {
        batchId = <string>row["id"];
    });
    if (e is error || batchId.length() == 0) {
        return error("Failed to retrieve batch id");
    }

    // Insert proposals: one per variable id from required_variables and field_metadata keys
    string[] ids = extractAllVariableIds(llm);
    int count = 0;
    foreach string vid in ids {
        var pr = dbClient->execute(`
            INSERT INTO llm_extraction_proposals (batch_id, term, suggested_variable_key, suggested_metadata, status, created_at)
            VALUES (${batchId}::uuid, ${vid}, ${vid}, ${llm.toString()}::jsonb, 'pending', NOW())`);
        if (pr is sql:Error) {
            log:printWarn("Proposal insert failed for " + vid + ": " + pr.message());
        } else {
            count += 1;
        }
    }
    var up = dbClient->execute(`UPDATE llm_extraction_batches SET proposal_count = ${count} WHERE id = ${batchId}::uuid`);
    if (up is sql:Error) {
        log:printWarn("Batch count update failed: " + up.message());
    }
    return {"batchId": batchId, "proposals": count};
}

function mergeApprovedMetadataForDocument(string docId, string calcType) returns json|error {
    // Find the latest batch for this document and tax type
    string batchId = "";
    stream<record {}, sql:Error?> rs = dbClient->query(`
        SELECT id FROM llm_extraction_batches WHERE source_document_id = ${docId} AND tax_type = ${calcType} ORDER BY created_at DESC LIMIT 1`);
    error? e = rs.forEach(function(record {} row) {
        batchId = <string>row["id"];
    });
    if (e is error || batchId.length() == 0) {
        return error("No extraction batch found");
    }

    // Get the original batch details first (for formulas and ui_order)
    json originalBatch = {"required_variables": [], "field_metadata": {}, "ui_order": [], "formulas": []};
    stream<record {}, sql:Error?> rs2 = dbClient->query(`SELECT details FROM llm_extraction_batches WHERE id = ${batchId}::uuid`);
    error? e2 = rs2.forEach(function(record {} row) {
        originalBatch = <json>row["details"];
    });
    if (e2 is error) {
        return error("Failed to load batch details: " + e2.message());
    }

    // Parse if DB returned JSON as string
    if (originalBatch is string) {
        json|error parsedBatch = parseJsonStrictLocal(<string>originalBatch);
        if (parsedBatch is json) {
            originalBatch = parsedBatch;
        } else {
            log:printWarn("[mergeApprovedMetadataForDocument] Failed to parse batch.details JSON string: " + parsedBatch.message());
        }
    }

    // Now get approved proposals and build metadata from them
    string[] approvedVariables = [];
    map<json> fieldMetadata = {};

    stream<record {}, sql:Error?> proposalStream = dbClient->query(`
        SELECT p.term, p.suggested_metadata, cv.key as canonical_key
        FROM llm_extraction_proposals p
        JOIN canonical_variables cv ON p.mapped_variable_id = cv.id
        WHERE p.batch_id = ${batchId}::uuid 
        AND p.status = 'approved' 
        AND p.mapped_variable_id IS NOT NULL
        ORDER BY p.created_at`);

    error? pe = proposalStream.forEach(function(record {} row) {
        string canonicalKey = <string>row["canonical_key"];
        approvedVariables.push(canonicalKey);

        // Parse the suggested metadata JSON
        var metadataRaw = row["suggested_metadata"];
        if (metadataRaw is string) {
            json|error parsed = parseJsonStrictLocal(<string>metadataRaw);
            if (parsed is json && parsed is map<json>) {
                map<json> metaMap = <map<json>>parsed;
                var fieldMeta = metaMap["field_metadata"];
                if (fieldMeta is map<json>) {
                    map<json> fieldMetaMap = <map<json>>fieldMeta;
                    // Get metadata for this specific field
                    var fieldData = fieldMetaMap[<string>row["term"]];
                    if (fieldData is map<json>) {
                        fieldMetadata[canonicalKey] = fieldData;
                    }
                }
            }
        }
    });

    if (pe is error) {
        return error("Failed to load approved proposals: " + pe.message());
    }

    // Build the final metadata combining approved proposals with original batch data
    map<json> result = {};
    result["required_variables"] = approvedVariables;
    result["field_metadata"] = fieldMetadata;

    // Preserve formulas and ui_order from original batch if available
    if (originalBatch is map<json>) {
        map<json> originalMap = <map<json>>originalBatch;
        // If no approvals exist, fall back to raw LLM variables/metadata to allow apply-metadata to proceed
        // Ballerina maps don't have size(); approximate emptiness by iterating keys
        boolean hasAnyFieldMeta = false;
        foreach var _k in fieldMetadata.keys() {
            hasAnyFieldMeta = true;
            break;
        }
        boolean noApprovals = approvedVariables.length() == 0 && !hasAnyFieldMeta;
        if (noApprovals) {
            if (originalMap.hasKey("required_variables")) {
                result["required_variables"] = originalMap["required_variables"];
            }
            if (originalMap.hasKey("field_metadata")) {
                result["field_metadata"] = originalMap["field_metadata"];
            }
        }
        if (originalMap.hasKey("formulas")) {
            result["formulas"] = originalMap["formulas"];
        } else {
            result["formulas"] = [];
        }
        if (originalMap.hasKey("ui_order")) {
            result["ui_order"] = originalMap["ui_order"];
        } else {
            result["ui_order"] = approvedVariables; // fallback to approved variables order
        }
        // Preserve brackets from original batch so bracket sync can run during apply-metadata
        if (originalMap.hasKey("brackets")) {
            result["brackets"] = originalMap["brackets"];
        }
    } else {
        result["formulas"] = [];
        result["ui_order"] = approvedVariables;
    }

    return <json>result;
}

function upsertMetadataIntoEvidenceRule(string docId, string calcType, json meta) returns json|error {
    // Try to locate latest evidence rule for this docId and type
    string rid = "";
    json current = {};
    stream<record {}, sql:Error?> rs = dbClient->query(`
        SELECT id, rule_data FROM tax_rules
        WHERE document_source_id = ${docId}
          AND rule_category = ${calcType}
          AND NOT (rule_type ILIKE 'aggregated%')
        ORDER BY created_at DESC
        LIMIT 1`);
    error? e = rs.forEach(function(record {} row) {
        rid = <string>row["id"];
        current = <json>row["rule_data"];
    });

    // Prepare merged metadata (approved LLM output)
    map<json> mm = meta is map<json> ? <map<json>>meta : {};

    // If no evidence rule exists, create one now using LLM metadata
    if (!(e is error) && rid.length() == 0) {
        string ruleType = calcType + "_evidence";
        string title = "Evidence Rule - " + calcType.toUpperAscii() + " (" + docId + ")";
        string description = "Evidence rule created from LLM-approved metadata";

        // Compose rule_data skeleton
        map<json> data = {
            "schema": 1,
            "type": ruleType,
            "category": calcType,
            "source": {"document_id": docId},
            "parsing": {"method": "llm_offline_v1"},
            "required_variables": mm.hasKey("required_variables") ? mm["required_variables"] : <json>[],
            "field_metadata": mm.hasKey("field_metadata") ? mm["field_metadata"] : <json>{},
            "ui_order": mm.hasKey("ui_order") ? mm["ui_order"] : <json>[],
            "formulas": mm.hasKey("formulas") ? mm["formulas"] : <json>[]
        };
        string dataStr = v:toJsonString(<json>data);

        // Build embedding text and generate embedding vector
        string embText = title + " — " + description + "\nrule_data: " + dataStr;
        decimal[]|error emb = generateEmbedding(embText);
        if (emb is error) {
            return error("Failed to generate embedding for new evidence rule: " + emb.message());
        }
        string embStr = "[";
        int idx = 0;
        foreach decimal vVal in emb {
            if (idx > 0) {
                embStr += ",";
            }
            embStr += vVal.toString();
            idx += 1;
        }
        embStr += "]";

        // Deterministic id based on doc+type; if conflict, let ON CONFLICT update rule_data/embedding
        rid = docId + "_" + calcType + "_evidence";

        sql:ParameterizedQuery ins = `
            INSERT INTO tax_rules (
                id, rule_type, rule_category, title, description, rule_data,
                embedding, document_source_id, extraction_context, source_kind, created_at
            ) VALUES (
                ${rid}, ${ruleType}, ${calcType}, ${title}, ${description}, ${dataStr}::jsonb,
                ${embStr}::vector(768), ${docId}, ${"llm_offline_v1"}, ${"evidence"}, NOW()
            )
            ON CONFLICT (id) DO UPDATE SET
                rule_data = EXCLUDED.rule_data,
                embedding = EXCLUDED.embedding,
                updated_at = NOW()
        `;
        var insRes = dbClient->execute(ins);
        if (insRes is sql:Error) {
            return error("Failed to insert/update evidence rule: " + insRes.message());
        }

        // Optionally sync bracket rows if provided by LLM metadata
        if (mm.hasKey("brackets")) {
            json? bj = mm["brackets"];
            if (bj is json[]) {
                // Clear existing brackets for this rule first to keep order consistent
                var delRes = dbClient->execute(`DELETE FROM tax_brackets WHERE rule_id = ${rid}`);
                if (delRes is sql:Error) {
                    return error("Failed to clear existing tax_brackets: " + delRes.message());
                }
                int ord = 1;
                foreach json it in bj {
                    map<json> m = it is map<json> ? <map<json>>it : {};
                    decimal? minI = ();
                    decimal? maxI = ();
                    decimal rateFrac = 0.0d;
                    decimal fixedAmt = 0.0d;
                    int bOrder = ord;
                    json? v;
                    v = m["min_income"];
                    if (v is decimal) {
                        minI = v;
                    } else if (v is int) {
                        decimal|error t = decimal:fromString((<int>v).toString());
                        if (t is decimal) {
                            minI = t;
                        }
                    }
                    v = m["max_income"];
                    if (v is decimal) {
                        maxI = v;
                    } else if (v is int) {
                        decimal|error t = decimal:fromString((<int>v).toString());
                        if (t is decimal) {
                            maxI = t;
                        }
                    }
                    v = m["fixed_amount"];
                    if (v is decimal) {
                        fixedAmt = v;
                    } else if (v is int) {
                        decimal|error t = decimal:fromString((<int>v).toString());
                        if (t is decimal) {
                            fixedAmt = t;
                        }
                    }
                    // Prefer rate_fraction; else derive from rate_percent
                    v = m["rate_fraction"];
                    if (v is decimal) {
                        rateFrac = v;
                    } else {
                        json? rp = m["rate_percent"];
                        if (rp is decimal) {
                            rateFrac = rp / 100.0d;
                        }
                        else if (rp is int) {
                            decimal|error t = decimal:fromString((<int>rp).toString());
                            if (t is decimal) {
                                rateFrac = t / 100.0d;
                            }
                        }
                    }
                    json? bo = m["bracket_order"];
                    if (bo is int) {
                        bOrder = bo;
                    }

                    string brId = rid + "_b" + bOrder.toString();
                    sql:ParameterizedQuery insBr = `
                        INSERT INTO tax_brackets (
                            id, rule_id, min_income, max_income, rate, fixed_amount, bracket_order
                        ) VALUES (
                            ${brId}, ${rid}, ${minI}, ${maxI}, ${rateFrac}, ${fixedAmt}, ${bOrder}
                        )
                        ON CONFLICT (id) DO UPDATE SET
                            min_income = ${minI},
                            max_income = ${maxI},
                            rate = ${rateFrac},
                            fixed_amount = ${fixedAmt}
                    `;
                    var brRes = dbClient->execute(insBr);
                    if (brRes is sql:Error) {
                        return error("Failed to upsert tax_brackets (" + brId + "): " + brRes.message());
                    }
                    ord += 1;
                }
            }
        }

        // Return created id
        return {"ruleId": rid, "created": true};
    }

    if (e is error) {
        return error("Failed to query existing evidence rule: " + e.message());
    }

    // Evidence rule exists: merge and update
    map<json> cur = current is map<json> ? <map<json>>current : {};
    if (mm.hasKey("required_variables")) {
        cur["required_variables"] = mm["required_variables"];
    }
    if (mm.hasKey("field_metadata")) {
        cur["field_metadata"] = mm["field_metadata"];
    }
    if (mm.hasKey("ui_order")) {
        cur["ui_order"] = mm["ui_order"];
    }
    if (mm.hasKey("formulas")) {
        cur["formulas"] = mm["formulas"];
    }

    // Add provenance
    cur["extraction_provenance"] = {
        "method": "llm_offline_v1",
        "applied_at": time:utcToCivil(time:utcNow()).year.toString() +
        "-" + ((time:utcToCivil(time:utcNow()).month < 10 ? "0" : "") + time:utcToCivil(time:utcNow()).month.toString()) +
        "-" + ((time:utcToCivil(time:utcNow()).day < 10 ? "0" : "") + time:utcToCivil(time:utcNow()).day.toString())
    };

    string mergedStr = v:toJsonString(<json>cur);
    var upd = dbClient->execute(`UPDATE tax_rules SET rule_data = ${mergedStr}::jsonb, updated_at = NOW() WHERE id = ${rid}`);
    if (upd is sql:Error) {
        return error("Failed to update rule_data: " + upd.message());
    }

    // Optionally sync bracket rows if provided by LLM metadata
    if (mm.hasKey("brackets")) {
        json? bj = mm["brackets"];
        if (bj is json[]) {
            var delRes = dbClient->execute(`DELETE FROM tax_brackets WHERE rule_id = ${rid}`);
            if (delRes is sql:Error) {
                return error("Failed to clear existing tax_brackets: " + delRes.message());
            }
            int ord = 1;
            foreach json it in bj {
                map<json> m = it is map<json> ? <map<json>>it : {};
                decimal? minI = ();
                decimal? maxI = ();
                decimal rateFrac = 0.0d;
                decimal fixedAmt = 0.0d;
                int bOrder = ord;
                json? v;
                v = m["min_income"];
                if (v is decimal) {
                    minI = v;
                } else if (v is int) {
                    decimal|error t = decimal:fromString((<int>v).toString());
                    if (t is decimal) {
                        minI = t;
                    }
                }
                v = m["max_income"];
                if (v is decimal) {
                    maxI = v;
                } else if (v is int) {
                    decimal|error t = decimal:fromString((<int>v).toString());
                    if (t is decimal) {
                        maxI = t;
                    }
                }
                v = m["fixed_amount"];
                if (v is decimal) {
                    fixedAmt = v;
                } else if (v is int) {
                    decimal|error t = decimal:fromString((<int>v).toString());
                    if (t is decimal) {
                        fixedAmt = t;
                    }
                }
                v = m["rate_fraction"];
                if (v is decimal) {
                    rateFrac = v;
                } else {
                    json? rp = m["rate_percent"];
                    if (rp is decimal) {
                        rateFrac = rp / 100.0d;
                    }
                    else if (rp is int) {
                        decimal|error t = decimal:fromString((<int>rp).toString());
                        if (t is decimal) {
                            rateFrac = t / 100.0d;
                        }
                    }
                }
                json? bo = m["bracket_order"];
                if (bo is int) {
                    bOrder = bo;
                }

                string brId = rid + "_b" + bOrder.toString();
                sql:ParameterizedQuery insBr = `
                    INSERT INTO tax_brackets (
                        id, rule_id, min_income, max_income, rate, fixed_amount, bracket_order
                    ) VALUES (
                        ${brId}, ${rid}, ${minI}, ${maxI}, ${rateFrac}, ${fixedAmt}, ${bOrder}
                    )
                    ON CONFLICT (id) DO UPDATE SET
                        min_income = ${minI},
                        max_income = ${maxI},
                        rate = ${rateFrac},
                        fixed_amount = ${fixedAmt}
                `;
                var brRes = dbClient->execute(insBr);
                if (brRes is sql:Error) {
                    return error("Failed to upsert tax_brackets (" + brId + "): " + brRes.message());
                }
                ord += 1;
            }
        }
    }

    return {"ruleId": rid, "updated": true};
}

