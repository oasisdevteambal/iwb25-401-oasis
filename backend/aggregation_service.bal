import ballerina/http;
import ballerina/lang.value as v;
import ballerina/log;
import ballerina/sql;
import ballerina/time;

// NOTE: GEMINI_* configurables and geminiTextClient are defined once in the module (admin_service.bal / config/gemini_config.bal)

// Local type aliases used throughout this file to keep shapes consistent
type TaxRule record {
    string id;
    string title;
    string description;
    json rule_data;
    string created_at;
    string source_authority;
    int source_rank;
    string effective_date;
    string expiry_date;
};

type ConflictValue record {
    string id;
    json value;
};

type RuleConflict record {
    string fieldName;
    string conflictType;
    string description;
    string resolution;
    ConflictValue[] conflictingRules;
};

// Aggregate rules and then rebuild+activate form schema for the given type/date
function runAggregationAndActivateForms(string calcType, string targetDate) returns json|error {
    json agg = check aggregateRulesFor(calcType, targetDate);
    json|error schema = generateAndActivateFormSchema(calcType, targetDate);
    if (schema is error) {
        return <json>{"aggregation": agg, "formActivation": {"success": false, "error": schema.message()}};
    }
    return <json>{"aggregation": agg, "formActivation": {"success": true, "schema": schema}};
}

// Enhanced aggregation v2: gather ALL evidence rules for intelligent processing
function aggregateRulesFor(string calcType, string targetDate) returns json|error {
    // Phase 1: Gather ALL evidence rules active on targetDate
    log:printInfo("Starting enhanced aggregation for type=" + calcType + ", date=" + targetDate);

    // Collect all evidence rules with metadata priority
    record {string id; string title; string description; json rule_data; string created_at; string source_authority; int source_rank; string effective_date; string expiry_date;}[] allRules = [];

    sql:ParameterizedQuery qr = `
        SELECT tr.id, tr.title, COALESCE(tr.description, '') as description, tr.rule_data, 
               COALESCE(tr.created_at::text, '') as created_at,
               COALESCE(d.source_authority, '') as source_authority,
               COALESCE(d.source_rank, 0) as source_rank,
               COALESCE(tr.effective_date::text, '') as effective_date,
               COALESCE(tr.expiry_date::text, '') as expiry_date
        FROM tax_rules tr
        LEFT JOIN documents d ON tr.document_source_id = d.id
        WHERE tr.rule_category = ${calcType}
          AND NOT (tr.rule_type ILIKE 'aggregated%')
          AND (tr.effective_date IS NULL OR tr.effective_date <= ${targetDate}::date)
          AND (tr.expiry_date IS NULL OR tr.expiry_date >= ${targetDate}::date)
        ORDER BY 
          CASE WHEN (jsonb_exists(tr.rule_data, 'field_metadata') OR jsonb_exists(tr.rule_data, 'required_variables')) THEN 1 ELSE 2 END,
          COALESCE(d.source_rank, 0) DESC,
          COALESCE(tr.updated_at, tr.created_at) DESC,
          tr.created_at DESC
    `;

    stream<record {}, sql:Error?> rs = dbClient->query(qr);
    error? e = rs.forEach(function(record {} row) {
        allRules.push({
            id: <string>row["id"],
            title: <string>row["title"],
            description: <string>row["description"],
            rule_data: <json>row["rule_data"],
            created_at: <string>row["created_at"],
            source_authority: <string>row["source_authority"],
            source_rank: <int>row["source_rank"],
            effective_date: <string>row["effective_date"],
            expiry_date: <string>row["expiry_date"]
        });
    });

    if (e is error) {
        return error("Failed to query evidence rules: " + e.message());
    }

    if (allRules.length() == 0) {
        return error("No evidence rules found for " + calcType + " on " + targetDate);
    }

    log:printInfo("Found " + allRules.length().toString() + " evidence rules for aggregation");

    // Phase 3: Conflict detection and resolution tracking
    json[] detectedConflicts = [];
    if (allRules.length() > 1) {
        detectedConflicts = detectConflictsBetweenRules(allRules, calcType);
        log:printInfo("Detected " + detectedConflicts.length().toString() + " conflicts between rules");
    }

    // Phase 2: Intelligent multi-rule aggregation using LLM when multiple rules exist
    // Primary selection details (declared up-front)
    string primaryId = "";
    string primaryDesc = "";
    json primaryRuleData = {};
    string[] sourceRuleIds = [];
    string aggregationMethod = "";

    if (allRules.length() == 1) {
        // Single rule: use it directly (no LLM needed)
        var singleRule = allRules[0];
        primaryId = singleRule.id;
        primaryDesc = singleRule.description;
        primaryRuleData = singleRule.rule_data;
        sourceRuleIds = [primaryId];
        aggregationMethod = "single_rule_direct";
        log:printInfo("Single rule aggregation: " + primaryId);
    } else {
        // Multiple rules: use LLM for intelligent merging
        log:printInfo("Multiple rules detected, using LLM for intelligent aggregation");
        json|error llmResult = runLlmIntelligentAggregation(calcType, targetDate, allRules, detectedConflicts);

        if (llmResult is error) {
            // Fallback to best single rule if LLM fails (no new data added)
            log:printWarn("LLM aggregation failed, falling back to single best rule: " + llmResult.message());
            var selectedRule = selectBestRule(allRules, calcType, targetDate);
            primaryId = selectedRule.id;
            primaryDesc = selectedRule.description;
            primaryRuleData = selectedRule.rule_data;
            sourceRuleIds = [primaryId];
            aggregationMethod = "fallback_single_best";
        } else {
            // Use LLM-aggregated result
            primaryId = calcType + "_llm_merged_" + targetDate;
            primaryDesc = "LLM-aggregated rule from " + allRules.length().toString() + " evidence sources";
            primaryRuleData = llmResult;
            sourceRuleIds = getAllRuleIds(allRules);
            aggregationMethod = "llm_intelligent_merge";
            log:printInfo("LLM aggregation completed successfully");
        }
    } // For bracket-based taxes, require brackets on primary (only for non-LLM paths)
    int bracketCount = 0;
    boolean isBracketBased = calcType == "income_tax" || calcType == "paye" || calcType == "vat";
    if (isBracketBased && aggregationMethod != "llm_intelligent_merge") {
        stream<record {}, sql:Error?> brs = dbClient->query(`
            SELECT COUNT(*) AS c FROM tax_brackets WHERE rule_id = ${primaryId}
        `);
        error? be = brs.forEach(function(record {} row) {
            bracketCount = <int>row["c"];
        });
        if (be is error) {
            return error("Failed counting brackets: " + be.message());
        }
        if (bracketCount == 0) {
            return error("Primary rule has no brackets; cannot aggregate " + calcType);
        }
    }

    // Cleanup any existing aggregated rule for same type+date
    var delBr = dbClient->execute(`
        DELETE FROM tax_brackets WHERE rule_id IN (
            SELECT id FROM tax_rules WHERE rule_category = ${calcType} AND rule_type ILIKE 'aggregated%' AND effective_date = ${targetDate}::date
        )`);
    if (delBr is sql:Error) {
        log:printWarn("Aggregation cleanup brackets failed: " + delBr.message());
    }
    var delRu = dbClient->execute(`
        DELETE FROM tax_rules WHERE rule_category = ${calcType} AND rule_type ILIKE 'aggregated%' AND effective_date = ${targetDate}::date`);
    if (delRu is sql:Error) {
        log:printWarn("Aggregation cleanup rules failed: " + delRu.message());
    }

    // Insert aggregated rule
    string aggId = calcType + "_aggregated_" + targetDate + "_" + time:utcNow().toString();
    string title = "Aggregated rules for " + calcType + " (" + targetDate + ")";
    // Parse rule_data if it arrived as string to carry forward metadata
    if (primaryRuleData is string) {
        var pj = v:fromJsonString(<string>primaryRuleData);
        if (pj is json) {
            primaryRuleData = pj;
        }
    }
    json rd = primaryRuleData is map<json> ? primaryRuleData : {};
    map<json> rdm = rd is map<json> ? <map<json>>rd : {};
    rdm["aggregated_from"] = sourceRuleIds;
    rdm["aggregation_date"] = targetDate;
    rdm["aggregation_strategy"] = aggregationMethod;
    rdm["total_evidence_rules"] = allRules.length();

    // Phase 3: Add conflict tracking metadata
    rdm["conflict_analysis"] = {
        "conflicts_detected": detectedConflicts.length(),
        "conflict_summary": buildConflictSummary(detectedConflicts),
        "resolution_strategy": determineResolutionStrategy(detectedConflicts, aggregationMethod)
    };

    if (aggregationMethod == "llm_intelligent_merge") {
        rdm["llm_merge_metadata"] = {
            "source_count": allRules.length(),
            "merge_timestamp": time:utcNow().toString(),
            "data_source": "government_documents_only",
            "conflicts_resolved": detectedConflicts.length()
        };
    } else if (aggregationMethod == "single_rule_direct" || aggregationMethod == "fallback_single_best") {
        // For single rule scenarios, use the first rule or selected rule
        var referenceRule = (aggregationMethod == "single_rule_direct") ? allRules[0] : selectBestRule(allRules, calcType, targetDate);
        rdm["selected_rule_metadata"] = getSelectionCriteria(referenceRule);
    }
    string ruleDataStr = (<json>rdm).toString();
    sql:ParameterizedQuery ins = `
        INSERT INTO tax_rules (id, rule_type, rule_category, title, description, rule_data, effective_date, created_at)
    VALUES (${aggId}, ${"aggregated_" + calcType}, ${calcType}, ${title}, ${primaryDesc}, ${ruleDataStr}::jsonb, ${targetDate}::date, NOW())
    `;
    var insRes = dbClient->execute(ins);
    if (insRes is sql:Error) {
        return error("Failed to insert aggregated rule: " + insRes.message());
    }

    // Copy brackets for bracket-based types (income_tax, paye, vat)
    int copied = 0;
    if (isBracketBased) {
        if (aggregationMethod == "llm_intelligent_merge") {
            // For LLM-merged rules, extract brackets from the aggregated rule_data
            copied = extractAndCreateBracketsFromLlmResult(aggId, primaryRuleData);
        } else {
            // For single rule cases, copy brackets from the primary rule
            stream<record {}, sql:Error?> brs2 = dbClient->query(`
                SELECT id, min_income, max_income, rate, fixed_amount, bracket_order FROM tax_brackets WHERE rule_id = ${primaryId} ORDER BY bracket_order`);
            error? e2 = brs2.forEach(function(record {} row) {
                copied += 1;
                string bid = aggId + "_b" + (<int>row["bracket_order"]).toString();
                decimal? minI = row["min_income"] is () ? () : <decimal>row["min_income"];
                decimal? maxI = row["max_income"] is () ? () : <decimal>row["max_income"];
                decimal rt = <decimal>row["rate"];
                decimal? fx = row["fixed_amount"] is () ? () : <decimal>row["fixed_amount"];
                var ir = dbClient->execute(`
                    INSERT INTO tax_brackets (id, rule_id, min_income, max_income, rate, fixed_amount, bracket_order)
                    VALUES (${bid}, ${aggId}, ${minI}, ${maxI}, ${rt}, ${fx}, ${<int>row["bracket_order"]})`);
                if (ir is sql:Error) {
                    log:printWarn("Failed to copy bracket: " + ir.message());
                }
            });
            if (e2 is error) {
                return error("Failed reading source brackets: " + e2.message());
            }
        }
    }

    // Enhanced provenance tracking for all source rules
    foreach var rule in allRules {
        var prov = dbClient->execute(`
            INSERT INTO aggregated_rule_sources (aggregated_rule_id, evidence_rule_id, created_at)
            VALUES (${aggId}, ${rule.id}, NOW())`);
        if (prov is sql:Error) {
            log:printWarn("Provenance insert failed for rule " + rule.id + ": " + prov.message());
        }
    }

    // Phase 3: Store conflict resolution records
    foreach var rc in detectedConflicts {
        if (rc is map<json>) {
            map<json> conflictMap = <map<json>>rc;
            // Extract values as strings to satisfy sql:Value expectations
            string fieldNameStr = "";
            var t1 = conflictMap["fieldName"];
            if (t1 is ()) {
                t1 = conflictMap["field"];
            }
            if (t1 is string) {
                fieldNameStr = t1;
            } else if (!(t1 is ())) {
                fieldNameStr = t1.toString();
            }

            string conflictTypeStr = "";
            var t2 = conflictMap["conflictType"];
            if (t2 is ()) {
                t2 = conflictMap["conflict_type"];
            }
            if (t2 is string) {
                conflictTypeStr = t2;
            } else if (!(t2 is ())) {
                conflictTypeStr = t2.toString();
            }

            string descriptionStr = "";
            var t3 = conflictMap["description"];
            if (t3 is string) {
                descriptionStr = t3;
            } else if (!(t3 is ())) {
                descriptionStr = t3.toString();
            }

            string resolutionStr = "";
            var t4 = conflictMap["resolution"];
            if (t4 is ()) {
                t4 = conflictMap["resolution_method"];
            }
            if (t4 is string) {
                resolutionStr = t4;
            } else if (!(t4 is ())) {
                resolutionStr = t4.toString();
            }

            var conflictRecord = dbClient->execute(`
                INSERT INTO rule_conflicts (aggregated_rule_id, tax_type, target_date, aspect, field_name, conflict_type, description, resolution_method, created_at)
                VALUES (${aggId}, ${calcType}, ${targetDate}::date, 'aggregation', ${fieldNameStr}, ${conflictTypeStr}, ${descriptionStr}, ${resolutionStr}, NOW())`);
            if (conflictRecord is sql:Error) {
                log:printWarn("Conflict record insert failed for field " + (conflictMap["fieldName"] ?: "unknown").toString() + ": " + conflictRecord.message());
            }
        }
    }

    // Record enhanced aggregation run details
    map<json> details = {
        "aggregatedRuleId": aggId,
        "primaryRuleId": primaryId,
        "totalEvidenceRules": allRules.length(),
        "allSourceRuleIds": sourceRuleIds,
        "bracketsCopied": copied,
        "aggregationMethod": aggregationMethod,
        "dataIntegrity": "government_documents_only",
        "conflictsDetected": detectedConflicts.length(),
        "conflictResolutions": buildConflictResolutionSummary(detectedConflicts)
    };
    string detailsStr = (<json>details).toString();
    var run = dbClient->execute(`
        INSERT INTO aggregation_runs (tax_type, target_date, inputs_count, outputs_count, conflicts_count, status, details, started_at)
        VALUES (${calcType}, ${targetDate}::date, ${allRules.length()}, ${1}, ${detectedConflicts.length()}, 'completed', ${detailsStr}::jsonb, NOW())`);
    if (run is sql:Error) {
        log:printWarn("Aggregation run insert failed: " + run.message());
    }

    return {
        "aggregatedRuleId": aggId,
        "primaryRuleId": primaryId,
        "totalEvidenceRules": allRules.length(),
        "sourceRuleIds": sourceRuleIds,
        "bracketsCopied": copied,
        "aggregationMethod": aggregationMethod,
        "dataIntegrity": "government_documents_only",
        "conflictsDetected": detectedConflicts.length(),
        "conflictAnalysis": buildConflictAnalysisReport(detectedConflicts)
    };
}

// Helper function to select the best rule from available evidence rules
function selectBestRule(record {string id; string title; string description; json rule_data; string created_at; string source_authority; int source_rank; string effective_date; string expiry_date;}[] rules, string calcType, string targetDate) returns record {string id; string title; string description; json rule_data; string created_at; string source_authority; int source_rank; string effective_date; string expiry_date;} {
    // Phase 1: Simple selection based on priority criteria
    // Future phases will implement more sophisticated selection logic

    // Priority order:
    // 1. Rules with LLM metadata (field_metadata or required_variables)
    // 2. Higher source_rank (authority level)
    // 3. More recent effective_date
    // 4. More recent created_at

    record {string id; string title; string description; json rule_data; string created_at; string source_authority; int source_rank; string effective_date; string expiry_date;} bestRule = rules[0];

    foreach var rule in rules {
        boolean ruleHasMetadata = hasLlmMetadata(rule.rule_data);
        boolean bestHasMetadata = hasLlmMetadata(bestRule.rule_data);

        // Prefer rules with LLM metadata
        if (ruleHasMetadata && !bestHasMetadata) {
            bestRule = rule;
            continue;
        }

        if (!ruleHasMetadata && bestHasMetadata) {
            continue;
        }

        // Both have same metadata status, compare source rank
        if (rule.source_rank > bestRule.source_rank) {
            bestRule = rule;
            continue;
        }

        if (rule.source_rank < bestRule.source_rank) {
            continue;
        }

        // Same source rank, prefer more recent rule by created_at
        // Since ORDER BY in SQL already sorted by these criteria, first rule should be best
    }

    log:printInfo("Selected rule: " + bestRule.id + " (rank=" + bestRule.source_rank.toString() + ", hasMetadata=" + hasLlmMetadata(bestRule.rule_data).toString() + ")");
    return bestRule;
}

// Helper function to check if rule has LLM metadata
function hasLlmMetadata(json ruleData) returns boolean {
    if (!(ruleData is map<json>)) {
        return false;
    }
    map<json> data = <map<json>>ruleData;
    return data.hasKey("field_metadata") || data.hasKey("required_variables");
}

// Helper function to extract all rule IDs
function getAllRuleIds(record {string id; string title; string description; json rule_data; string created_at; string source_authority; int source_rank; string effective_date; string expiry_date;}[] rules) returns string[] {
    string[] ids = [];
    foreach var rule in rules {
        ids.push(rule.id);
    }
    return ids;
}

// Helper function to get selection criteria for the chosen rule
function getSelectionCriteria(record {string id; string title; string description; json rule_data; string created_at; string source_authority; int source_rank; string effective_date; string expiry_date;} rule) returns map<json> {
    return {
        "hasLlmMetadata": hasLlmMetadata(rule.rule_data),
        "sourceRank": rule.source_rank,
        "sourceAuthority": rule.source_authority,
        "effectiveDate": rule.effective_date,
        "createdAt": rule.created_at
    };
}

// Phase 2: LLM-powered intelligent aggregation for multiple rules (Enhanced for Phase 3)
function runLlmIntelligentAggregation(string calcType, string targetDate, record {string id; string title; string description; json rule_data; string created_at; string source_authority; int source_rank; string effective_date; string expiry_date;}[] allRules, json[] detectedConflicts) returns json|error {
    log:printInfo("Starting LLM intelligent aggregation for " + allRules.length().toString() + " rules with " + detectedConflicts.length().toString() + " detected conflicts");

    // Build comprehensive prompt for LLM aggregation
    string systemPrompt = "You are a Sri Lankan tax law aggregation specialist. You must consolidate multiple evidence rules from government documents into a single coherent rule. CRITICAL: Use ONLY information explicitly present in the provided rules. Do not add, interpolate, or invent any data not found in the source documents.";

    string constraints = "CONSTRAINTS:\n" +
        "- Data Integrity: Use ONLY data from the provided government documents\n" +
        "- No Interpolation: Do not fill gaps with assumed or calculated values\n" +
        "- Conflict Resolution: When rules conflict, prefer newer effective dates, higher source authority ranks\n" +
        "- Variable Consistency: Merge field_metadata and required_variables from all sources\n" +
        "- Formula Integration: Combine formulas while maintaining mathematical validity\n" +
        "- Bracket Consolidation: For progressive taxes, merge bracket schedules intelligently\n" +
        "- Source Tracking: Maintain source_refs for all merged elements\n" +
        "- CRITICAL: In ALL source_refs, use COMPLETE RULE IDs (ending with _evidence), NOT document IDs\n" +
        "- CRITICAL: Rule IDs are provided in the rules section - use them exactly as shown";

    string domainGuidance = "";
    if (calcType == "income_tax") {
        domainGuidance = "Focus on: taxable_income calculation, progressive tax brackets, annual tax computation";
    } else if (calcType == "paye") {
        domainGuidance = "Focus on: monthly taxable income, PAYE brackets, monthly tax computation";
    } else if (calcType == "vat") {
        domainGuidance = "Focus on: taxable supplies, output tax, input tax credit, net VAT payable";
    }

    // Build rules summary for LLM
    string rulesSummary = buildRulesSummaryForLlm(allRules, calcType);

    // Phase 3: Add detected conflicts to LLM prompt
    string conflictDetails = buildConflictDetailsForLlm(detectedConflicts);

    string conflictAnalysis = "CONFLICT RESOLUTION PRIORITY:\n" +
        "1. Effective Date: Newer dates override older dates\n" +
        "2. Source Authority: Higher source_rank values have precedence\n" +
        "3. Completeness: Rules with more complete metadata preferred\n" +
        "4. Government documents only - no external assumptions";

    string outputSchema = buildAggregationOutputSchema();

    string fullPrompt = systemPrompt + "\n\n" + constraints + "\n\n" + domainGuidance + "\n\n" +
                        conflictAnalysis + "\n\nDETECTED CONFLICTS:\n" + conflictDetails +
                        "\n\nRULES TO AGGREGATE:\n" + rulesSummary +
                        "\n\nOUTPUT SCHEMA:\n" + outputSchema +
                        "\n\nReturn the consolidated rule in the specified JSON format.";

    // Call Gemini LLM for intelligent aggregation
    json|error llmResult = callGeminiForAggregation(fullPrompt, calcType);
    if (llmResult is error) {
        return error("LLM aggregation failed: " + llmResult.message());
    }

    // Validate the LLM result to ensure data integrity
    json|error validated = validateAggregatedRule(llmResult, allRules);
    if (validated is error) {
        return error("LLM result validation failed: " + validated.message());
    }

    log:printInfo("LLM intelligent aggregation completed successfully");
    return validated;
}

// Build a comprehensive summary of all rules for LLM processing
function buildRulesSummaryForLlm(record {string id; string title; string description; json rule_data; string created_at; string source_authority; int source_rank; string effective_date; string expiry_date;}[] rules, string calcType) returns string {
    string summary = "IMPORTANT: When referencing sources, use the RULE ID (the full ID with _evidence suffix), NOT the document ID.\n\n";

    summary += "VALID RULE IDs TO REFERENCE:\n";
    foreach var rule in rules {
        summary += "- " + rule.id + "\n";
    }
    summary += "\nDO NOT use document IDs like 'doc_temp_paye_doc_1756446524' - use RULE IDs like 'doc_temp_paye_doc_1756446524_paye_evidence'\n\n";

    int ruleIndex = 1;

    foreach var rule in rules {
        summary += "=== RULE " + ruleIndex.toString() + " ===\n";
        summary += "RULE ID (use this for source_refs): " + rule.id + "\n";
        summary += "Title: " + rule.title + "\n";
        summary += "Description: " + rule.description + "\n";
        summary += "Source Authority: " + rule.source_authority + "\n";
        summary += "Source Rank: " + rule.source_rank.toString() + "\n";
        summary += "Effective Date: " + rule.effective_date + "\n";
        summary += "Expiry Date: " + rule.expiry_date + "\n";
        summary += "Rule Data: " + rule.rule_data.toString() + "\n\n";
        ruleIndex += 1;
    }

    return summary;
}

// Build the expected output schema for LLM
function buildAggregationOutputSchema() returns string {
    return "{\n" +
            "  \"required_variables\": [string],\n" +
            "  \"field_metadata\": { [key: string]: {\n" +
            "    \"type\": \"number|string|integer|boolean|date\",\n" +
            "    \"title\": string,\n" +
            "    \"minimum\"?: number,\n" +
            "    \"maximum\"?: number,\n" +
            "    \"unit\"?: string,\n" +
            "    \"source_refs\": [{\"ruleId\": \"FULL_RULE_ID_WITH_EVIDENCE_SUFFIX\", \"fieldName\": string}]\n" +
            "  }},\n" +
            "  \"ui_order\": [string],\n" +
            "  \"formulas\": [{\n" +
            "    \"id\": string,\n" +
            "    \"name\": string,\n" +
            "    \"expression\": string,\n" +
            "    \"order\": number,\n" +
            "    \"source_refs\": [{\"ruleId\": \"FULL_RULE_ID_WITH_EVIDENCE_SUFFIX\", \"formulaId\": string}],\n" +
            "    \"testVectors\": [{\n" +
            "      \"inputs\": { [var: string]: number|string },\n" +
            "      \"expectedResult\": number,\n" +
            "      \"tolerance\"?: number\n" +
            "    }]\n" +
            "  }],\n" +
            "  \"brackets\"?: [{\n" +
            "    \"min_income\"?: number,\n" +
            "    \"max_income\"?: number|null,\n" +
            "    \"rate_percent\"?: number,\n" +
            "    \"rate_fraction\"?: number,\n" +
            "    \"fixed_amount\"?: number,\n" +
            "    \"bracket_order\"?: integer,\n" +
            "    \"source_refs\": [{\"ruleId\": \"FULL_RULE_ID_WITH_EVIDENCE_SUFFIX\", \"bracketIndex\": number}]\n" +
            "  }],\n" +
            "  \"consolidation_notes\": [string],\n" +
            "  \"conflicts_resolved\": [{\n" +
            "    \"field\": string,\n" +
            "    \"resolution\": string,\n" +
            "    \"reason\": string\n" +
            "  }]\n" +
            "}\n\n" +
            "CRITICAL: In ALL source_refs, use the complete RULE ID (ending with _evidence), NOT document IDs!\n" +
            "Example: Use 'doc_temp_paye_doc_1756446524_paye_evidence' NOT 'doc_temp_paye_doc_1756446524'";
}

// Call Gemini LLM with aggregation prompt
function callGeminiForAggregation(string prompt, string calcType) returns json|error {
    // Reuse the existing Gemini client from admin_service.bal
    json body = {
        "contents": [
            {"role": "user", "parts": [{"text": prompt}]}
        ],
        "generationConfig": {
            "temperature": 0.1,
            "topP": 0.1,
            "topK": 40,
            "candidateCount": 1,
            "response_mime_type": "application/json"
        }
    };

    string path = "/v1beta/models/" + GEMINI_TEXT_MODEL + ":generateContent?key=" + GEMINI_API_KEY;
    log:printInfo("Calling Gemini for intelligent aggregation");

    http:Response|error resp = geminiTextClient->post(path, body);
    if (resp is error) {
        return error("LLM call failed: " + resp.message());
    }

    json|error payload = resp.getJsonPayload();
    if (payload is error) {
        return error("LLM response parse failed: " + payload.message());
    }

    // Extract and parse LLM response (similar to existing extraction logic)
    string resultText = extractGeminiResponseText(payload);
    if (resultText.length() == 0) {
        return error("Empty LLM response");
    }

    // Clean and parse JSON
    string cleaned = sanitizeLlmJsonString(resultText);
    json|error parsed = parseJsonStrictLocal(cleaned);
    if (parsed is error) {
        return error("Invalid JSON from LLM: " + parsed.message());
    }

    return parsed;
}

// Extract text from Gemini response payload
function extractGeminiResponseText(json payload) returns string {
    string out = "";
    if (payload is map<json>) {
        var candJ = (<map<json>>payload)["candidates"] ?: ();
        if (candJ is json[]) {
            foreach json cand in candJ {
                if (cand is map<json>) {
                    var content = cand["content"] ?: ();
                    if (content is map<json>) {
                        var parts = content["parts"] ?: ();
                        if (parts is json[]) {
                            foreach json part in parts {
                                if (part is map<json>) {
                                    var txt = part["text"] ?: ();
                                    if (txt is string && txt.length() > 0) {
                                        if (out.length() > 0) {
                                            out += "\n";
                                        }
                                        out += txt;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    return out;
}

// Validate aggregated rule to ensure data integrity
function validateAggregatedRule(json llmResult, record {string id; string title; string description; json rule_data; string created_at; string source_authority; int source_rank; string effective_date; string expiry_date;}[] sourceRules) returns json|error {
    // Ensure the result is a valid JSON object
    if (!(llmResult is map<json>)) {
        return error("LLM result is not a JSON object");
    }

    map<json> result = <map<json>>llmResult;

    // Validate required fields
    string[] requiredFields = ["required_variables", "field_metadata", "ui_order", "formulas"];
    foreach string fld in requiredFields {
        if (!result.hasKey(fld)) {
            return error("Missing required field: " + fld);
        }
    }

    // Validate that all data has source references to original rules
    var validationResult = validateSourceReferences(result, sourceRules);
    if (validationResult is error) {
        return error("Source reference validation failed: " + validationResult.message());
    }

    // Add aggregation metadata
    result["aggregation_metadata"] = {
        "method": "llm_intelligent_merge",
        "source_rule_count": sourceRules.length(),
        "aggregation_timestamp": time:utcNow().toString(),
        "data_integrity": "government_documents_only"
    };

    return <json>result;
}

// Validate that all merged data has proper source references
function validateSourceReferences(map<json> result, record {string id; string title; string description; json rule_data; string created_at; string source_authority; int source_rank; string effective_date; string expiry_date;}[] sourceRules) returns error? {
    // Create a set of valid rule IDs for reference checking
    map<boolean> validRuleIds = {};
    foreach var rule in sourceRules {
        validRuleIds[rule.id] = true;
    }

    // Check field_metadata source references
    var fieldMetadata = result["field_metadata"];
    if (fieldMetadata is map<json>) {
        foreach var [_, fieldData] in fieldMetadata.entries() {
            if (fieldData is map<json>) {
                var sourceRefs = fieldData["source_refs"];
                if (sourceRefs is json[]) {
                    foreach json refJson in sourceRefs {
                        if (refJson is map<json>) {
                            var ruleIdJson = refJson["ruleId"] ?: ();
                            if (ruleIdJson is string && !validRuleIds.hasKey(ruleIdJson)) {
                                return error("Invalid source rule ID in field_metadata: " + ruleIdJson);
                            }
                        }
                    }
                }
            }
        }
    }

    // TODO: Validate formulas[].source_refs[*].ruleId and brackets[].source_refs similarly if present

    // Check formulas source references
    var formulas = result["formulas"];
    if (formulas is json[]) {
        foreach json formulaJson in formulas {
            if (formulaJson is map<json>) {
                var sourceRefs = formulaJson["source_refs"];
                if (sourceRefs is json[]) {
                    foreach json refJson in sourceRefs {
                        if (refJson is map<json>) {
                            var ruleIdJson = refJson["ruleId"] ?: ();
                            if (ruleIdJson is string && !validRuleIds.hasKey(ruleIdJson)) {
                                return error("Invalid source rule ID in formulas: " + ruleIdJson);
                            }
                        }
                    }
                }
            }
        }
    }

    // Check brackets source references
    var brackets = result["brackets"];
    if (brackets is json[]) {
        foreach json bracketJson in brackets {
            if (bracketJson is map<json>) {
                var sourceRefs = bracketJson["source_refs"];
                if (sourceRefs is json[]) {
                    foreach json refJson in sourceRefs {
                        if (refJson is map<json>) {
                            var ruleIdJson = refJson["ruleId"] ?: ();
                            if (ruleIdJson is string && !validRuleIds.hasKey(ruleIdJson)) {
                                return error("Invalid source rule ID in brackets: " + ruleIdJson);
                            }
                        }
                    }
                }
            }
        }
    }

    return;
}

// Extract brackets from LLM-merged rule_data and persist into tax_brackets for the aggregated rule (clean version)
function extractAndCreateBracketsFromLlmResult(string aggregatedRuleId, json ruleData) returns int {
    int copied = 0;
    if (!(ruleData is map<json>)) {
        return 0;
    }
    map<json> rd = <map<json>>ruleData;
    json? brJ = rd["brackets"];
    if (!(brJ is json[])) {
        return 0;
    }
    int idx = 0;
    foreach json item in <json[]>brJ {
        if (!(item is map<json>)) {
            continue;
        }
        map<json> m = <map<json>>item;
        decimal? minI = ();
        var mi = m["min_income"];
        if (mi is int) {
            minI = <decimal>mi;
        } else if (mi is float) {
            minI = <decimal>mi;
        } else if (mi is decimal) {
            minI = mi;
        }

        decimal? maxI = ();
        var ma = m["max_income"];
        if (ma is int) {
            maxI = <decimal>ma;
        } else if (ma is float) {
            maxI = <decimal>ma;
        } else if (ma is decimal) {
            maxI = ma;
        }

        decimal? rateP = ();
        var rp = m["rate_percent"];
        if (rp is int) {
            rateP = <decimal>rp / 100.0; // Convert percentage to fraction
        } else if (rp is float) {
            rateP = <decimal>rp / 100.0; // Convert percentage to fraction
        } else if (rp is decimal) {
            rateP = rp / 100.0; // Convert percentage to fraction
        }
        if (rateP is ()) {
            var rf = m["rate_fraction"];
            if (rf is int) {
                rateP = <decimal>rf; // Already a fraction
            } else if (rf is float) {
                rateP = <decimal>rf; // Already a fraction
            } else if (rf is decimal) {
                rateP = rf; // Already a fraction
            }
        }

        // Determine bracket order early (used in validation logs)
        int bracketOrder = idx + 1;
        var bo = m["bracket_order"];
        if (bo is int) {
            bracketOrder = bo;
        }

        // Validate rate fits database constraints: numeric(5,4) max = 9.9999
        if (rateP is decimal && rateP > <decimal>9.9999) {
            log:printWarn("Rate " + rateP.toString() + " exceeds database limit (9.9999), skipping bracket " + bracketOrder.toString());
            idx += 1;
            continue;
        }

        decimal? fixed = ();
        var fx = m["fixed_amount"];
        if (fx is int) {
            fixed = <decimal>fx;
        } else if (fx is float) {
            fixed = <decimal>fx;
        } else if (fx is decimal) {
            fixed = fx;
        }

        // bracketOrder already determined above

        if (rateP is ()) {
            idx += 1;
            continue;
        }
        string bid = aggregatedRuleId + "_b" + bracketOrder.toString();
        var ir = dbClient->execute(`
            INSERT INTO tax_brackets (id, rule_id, min_income, max_income, rate, fixed_amount, bracket_order)
            VALUES (${bid}, ${aggregatedRuleId}, ${minI}, ${maxI}, ${<decimal>rateP}, ${fixed}, ${bracketOrder})`);
        if (ir is sql:Error) {
            log:printWarn("Failed to insert bracket from LLM result: " + ir.message());
        } else {
            copied += 1;
        }
        idx += 1;
    }
    return copied;
}

// Uses parseJsonStrictLocal from admin_service.bal (module-scope)

// ================================
// PHASE 3: CONFLICT DETECTION AND RESOLUTION FUNCTIONS
// ================================

// Main conflict detection function - analyzes all rules for potential conflicts
function detectConflictsBetweenRules(TaxRule[] allRules, string calcType) returns json[] {
    json[] conflicts = [];

    log:printInfo("Starting conflict detection for " + allRules.length().toString() + " rules");

    // 1. Detect formula conflicts
    var formulaConflicts = detectFormulaConflicts(allRules);
    foreach var cf in formulaConflicts {
        conflicts.push(cf);
    }

    // 2. Detect bracket conflicts (for bracket-based tax types)
    if (calcType == "income_tax" || calcType == "paye" || calcType == "vat") {
        var bracketConflicts = detectBracketConflicts(allRules);
        foreach var cf in bracketConflicts {
            conflicts.push(cf);
        }
    }

    // 3. Detect field metadata conflicts
    var fieldConflicts = detectFieldMetadataConflicts(allRules);
    foreach var cf in fieldConflicts {
        conflicts.push(cf);
    }

    // 4. Detect required variables conflicts
    var variableConflicts = detectRequiredVariableConflicts(allRules);
    foreach var cf in variableConflicts {
        conflicts.push(cf);
    }

    // 5. Detect effective date conflicts
    var dateConflicts = detectEffectiveDateConflicts(allRules);
    foreach var cf in dateConflicts {
        conflicts.push(cf);
    }

    log:printInfo("Conflict detection completed: " + conflicts.length().toString() + " conflicts found");
    return conflicts;
}

// Detect conflicts in calculation formulas
function detectFormulaConflicts(record {string id; string title; string description; json rule_data; string created_at; string source_authority; int source_rank; string effective_date; string expiry_date;}[] allRules) returns json[] {
    json[] conflicts = [];
    map<record {string id; json formula;}[]> formulaGroups = {};

    // Group formulas by their purpose/calculation type
    foreach var rule in allRules {
        if (rule.rule_data is map<json>) {
            map<json> ruleData = <map<json>>rule.rule_data;
            var formulasJson = ruleData["formulas"];
            if (formulasJson is json[]) {
                foreach json formulaJson in formulasJson {
                    if (formulaJson is map<json>) {
                        map<json> formula = <map<json>>formulaJson;
                        var nameJson = formula["name"];
                        var exprJson = formula["expression"];
                        if (nameJson is string && exprJson is string) {
                            string formulaKey = nameJson;
                            if (!formulaGroups.hasKey(formulaKey)) {
                                formulaGroups[formulaKey] = [];
                            }
                            var fg = formulaGroups[formulaKey] ?: [];
                            fg.push({id: rule.id, formula: formulaJson});
                            formulaGroups[formulaKey] = fg;
                        }
                    }
                }
            }
        }
    }

    // Detect conflicts within formula groups
    foreach var [formulaName, formulas] in formulaGroups.entries() {
        if (formulas.length() > 1) {
            // Check if expressions are different
            string[] uniqueExpressions = [];
            record {string id; json value;}[] conflictingRules = [];

            foreach var formulaRecord in formulas {
                if (formulaRecord.formula is map<json>) {
                    map<json> f = <map<json>>formulaRecord.formula;
                    var exprJson = f["expression"];
                    if (exprJson is string) {
                        string expr = exprJson;
                        boolean isUnique = true;
                        foreach string existing in uniqueExpressions {
                            if (existing == expr) {
                                isUnique = false;
                                break;
                            }
                        }
                        if (isUnique) {
                            uniqueExpressions.push(expr);
                        }
                        conflictingRules.push({id: formulaRecord.id, value: f});
                    }
                }
            }

            if (uniqueExpressions.length() > 1) {
                conflicts.push(<json>{
                    "field": "formula_" + formulaName,
                    "conflictType": "formula_expression_mismatch",
                    "description": "Multiple rules define different expressions for formula: " + formulaName,
                    "resolution": "prefer_newer_effective_date_then_higher_authority",
                    "conflictingRules": <json>conflictingRules
                });
            }
        }
    }

    return conflicts;
}

// Detect conflicts in tax bracket definitions
function detectBracketConflicts(record {string id; string title; string description; json rule_data; string created_at; string source_authority; int source_rank; string effective_date; string expiry_date;}[] allRules) returns json[] {
    json[] conflicts = [];

    // For bracket conflicts, we need to compare actual bracket data from database
    // This is a simplified detection - in practice would query tax_brackets table
    map<string[]> bracketSignatures = {};

    foreach var rule in allRules {
        if (rule.rule_data is map<json>) {
            map<json> ruleData = <map<json>>rule.rule_data;
            var bracketsJson = ruleData["brackets"];
            if (bracketsJson is json[]) {
                string signature = generateBracketSignature(<json[]>bracketsJson);
                if (!bracketSignatures.hasKey(signature)) {
                    bracketSignatures[signature] = [];
                }
                var bs = bracketSignatures[signature] ?: [];
                bs.push(rule.id);
                bracketSignatures[signature] = bs;
            }
        }
    }

    if (bracketSignatures.length() > 1) {
        record {string id; json value;}[] conflictingRules = [];
        foreach var [_, ruleIds] in bracketSignatures.entries() {
            foreach string ruleId in ruleIds {
                foreach var rule in allRules {
                    if (rule.id == ruleId) {
                        if (rule.rule_data is map<json>) {
                            map<json> ruleData = <map<json>>rule.rule_data;
                            var bracketsJson = ruleData["brackets"];
                            if (bracketsJson is json) {
                                conflictingRules.push({id: ruleId, value: bracketsJson});
                            }
                        }
                        break;
                    }
                }
            }
        }

        if (conflictingRules.length() > 1) {
            conflicts.push(<json>{
                "field": "tax_brackets",
                "conflictType": "bracket_structure_mismatch",
                "description": "Rules define different tax bracket structures",
                "resolution": "prefer_newer_effective_date_then_higher_authority",
                "conflictingRules": <json>conflictingRules
            });
        }
    }

    return conflicts;
}

// Detect conflicts in field metadata definitions
function detectFieldMetadataConflicts(record {string id; string title; string description; json rule_data; string created_at; string source_authority; int source_rank; string effective_date; string expiry_date;}[] allRules) returns json[] {
    json[] conflicts = [];
    map<record {string id; json metadata;}[]> fieldGroups = {};

    // Group field metadata by field name
    foreach var rule in allRules {
        if (rule.rule_data is map<json>) {
            map<json> ruleData = <map<json>>rule.rule_data;
            var fieldMetadataJson = ruleData["field_metadata"];
            if (fieldMetadataJson is map<json>) {
                map<json> fieldMetadata = <map<json>>fieldMetadataJson;
                foreach var [fieldName, metadata] in fieldMetadata.entries() {
                    if (!fieldGroups.hasKey(fieldName)) {
                        fieldGroups[fieldName] = [];
                    }
                    var fg2 = fieldGroups[fieldName] ?: [];
                    fg2.push({id: rule.id, metadata: metadata});
                    fieldGroups[fieldName] = fg2;
                }
            }
        }
    }

    // Detect conflicts within field groups
    foreach var [fieldName, metadataRecords] in fieldGroups.entries() {
        if (metadataRecords.length() > 1) {
            // Check for type conflicts
            string[] uniqueTypes = [];
            record {string id; json value;}[] conflictingRules = [];

            foreach var metadataRecord in metadataRecords {
                if (metadataRecord.metadata is map<json>) {
                    map<json> m = <map<json>>metadataRecord.metadata;
                    var typeJson = m["type"];
                    if (typeJson is string) {
                        string fieldType = typeJson;
                        boolean isUnique = true;
                        foreach string existing in uniqueTypes {
                            if (existing == fieldType) {
                                isUnique = false;
                                break;
                            }
                        }
                        if (isUnique) {
                            uniqueTypes.push(fieldType);
                        }
                        conflictingRules.push({id: metadataRecord.id, value: m});
                    }
                }
            }

            if (uniqueTypes.length() > 1) {
                conflicts.push(<json>{
                    "field": "field_metadata_" + fieldName,
                    "conflictType": "field_type_mismatch",
                    "description": "Multiple rules define different types for field: " + fieldName,
                    "resolution": "prefer_newer_effective_date_then_higher_authority",
                    "conflictingRules": <json>conflictingRules
                });
            }
        }
    }

    return conflicts;
}

// Detect conflicts in required variables
function detectRequiredVariableConflicts(record {string id; string title; string description; json rule_data; string created_at; string source_authority; int source_rank; string effective_date; string expiry_date;}[] allRules) returns json[] {
    json[] conflicts = [];
    map<string[]> variableSets = {};

    foreach var rule in allRules {
        if (rule.rule_data is map<json>) {
            map<json> ruleData = <map<json>>rule.rule_data;
            var requiredVarsJson = ruleData["required_variables"];
            if (requiredVarsJson is json[]) {
                string[] variables = [];
                foreach json varJson in <json[]>requiredVarsJson {
                    if (varJson is string) {
                        variables.push(varJson);
                    }
                }
                string signature = generateVariableSignature(variables);
                if (!variableSets.hasKey(signature)) {
                    variableSets[signature] = [];
                }
                var vs = variableSets[signature] ?: [];
                vs.push(rule.id);
                variableSets[signature] = vs;
            }
        }
    }

    if (variableSets.length() > 1) {
        record {string id; json value;}[] conflictingRules = [];
        foreach var [_, ruleIds] in variableSets.entries() {
            foreach string ruleId in ruleIds {
                foreach var rule in allRules {
                    if (rule.id == ruleId) {
                        if (rule.rule_data is map<json>) {
                            map<json> ruleData = <map<json>>rule.rule_data;
                            var requiredVarsJson = ruleData["required_variables"];
                            if (requiredVarsJson is json) {
                                conflictingRules.push({id: ruleId, value: requiredVarsJson});
                            }
                        }
                        break;
                    }
                }
            }
        }

        if (conflictingRules.length() > 1) {
            conflicts.push(<json>{
                "field": "required_variables",
                "conflictType": "variable_set_mismatch",
                "description": "Rules require different sets of input variables",
                "resolution": "merge_union_of_all_variables",
                "conflictingRules": <json>conflictingRules
            });
        }
    }

    return conflicts;
}

// Detect conflicts in effective dates (overlapping periods)
function detectEffectiveDateConflicts(record {string id; string title; string description; json rule_data; string created_at; string source_authority; int source_rank; string effective_date; string expiry_date;}[] allRules) returns json[] {
    json[] conflicts = [];

    // Check for overlapping date ranges
    foreach int i in 0 ..< allRules.length() {
        foreach int j in (i + 1) ..< allRules.length() {
            var rule1 = allRules[i];
            var rule2 = allRules[j];

            if (datesOverlap(rule1.effective_date, rule1.expiry_date, rule2.effective_date, rule2.expiry_date)) {
                conflicts.push(<json>{
                    fieldName: "effective_date_range",
                    conflictType: "overlapping_effective_periods",
                    description: "Rules have overlapping effective date periods: " + rule1.id + " and " + rule2.id,
                    resolution: "prefer_newer_rule_by_created_date",
                    conflictingRules: [
                        {id: rule1.id, value: {"effective_date": rule1.effective_date, "expiry_date": rule1.expiry_date}},
                        {id: rule2.id, value: {"effective_date": rule2.effective_date, "expiry_date": rule2.expiry_date}}
                    ]
                });
            }
        }
    }

    return conflicts;
}

// Helper function to check if two date ranges overlap
function datesOverlap(string start1, string end1, string start2, string end2) returns boolean {
    // Simplified date comparison - in practice would use proper date parsing
    // For now, assume dates are in ISO format and use string comparison
    // This is a basic implementation that would need enhancement for production
    return !(end1 < start2 || end2 < start1);
}

// Generate signature for bracket structure comparison
function generateBracketSignature(json[] brackets) returns string {
    string signature = "";
    foreach json bracket in brackets {
        if (bracket is map<json>) {
            map<json> b = <map<json>>bracket;
            var minIncome = b["min_income"];
            var maxIncome = b["max_income"];
            var rate = b["rate_percent"] ?: b["rate_fraction"];

            signature += minIncome.toString() + "-" + maxIncome.toString() + "-" + rate.toString() + "|";
        }
    }
    return signature;
}

// Generate signature for variable set comparison
function generateVariableSignature(string[] variables) returns string {
    // Sort variables to ensure consistent signature
    string[] sortedVars = variables.sort();
    string signature = "";
    foreach string variable in sortedVars {
        signature += variable + "|";
    }
    return signature;
}

// Build conflict details for LLM prompt
function buildConflictDetailsForLlm(json[] conflictList) returns string {
    if (conflictList.length() == 0) {
        return "No conflicts detected between rules.";
    }

    string details = "=== DETECTED CONFLICTS ===\n";
    int conflictIndex = 1;

    foreach var cf in conflictList {
        details += "CONFLICT " + conflictIndex.toString() + ":\n";
        if (cf is map<json>) {
            map<json> conflictMap = <map<json>>cf;
            details += "Field: " + (conflictMap["fieldName"] ?: "unknown").toString() + "\n";
            details += "Type: " + (conflictMap["conflictType"] ?: "unknown").toString() + "\n";
            details += "Description: " + (conflictMap["description"] ?: "unknown").toString() + "\n";
            details += "Resolution Strategy: " + (conflictMap["resolution"] ?: "unknown").toString() + "\n";
            details += "Conflicting Rules:\n";
            var conflictingRulesV = conflictMap["conflictingRules"];
            if (conflictingRulesV is json[]) {
                foreach var rule in conflictingRulesV {
                    if (rule is map<json>) {
                        map<json> ruleMap = <map<json>>rule;
                        details += "  - Rule ID: " + (ruleMap["id"] ?: "unknown").toString() + "\n";
                        details += "    Value: " + (ruleMap["value"] ?: {}).toString() + "\n";
                    }
                }
            }
        }
        details += "\n";
        conflictIndex += 1;
    }

    return details;

}

// Build conflict summary for metadata
function buildConflictSummary(json[] conflictList) returns map<json> {
    map<int> conflictTypes = {};
    string[] affectedFields = [];

    foreach var cf in conflictList {
        if (cf is map<json>) {
            map<json> cm = <map<json>>cf;
            // Count conflict types
            string cType = "unknown";
            var ctTmp = cm["conflictType"];
            if (ctTmp is ()) {
                ctTmp = cm["conflict_type"];
            }
            if (ctTmp is string) {
                cType = ctTmp;
            } else if (!(ctTmp is ())) {
                cType = ctTmp.toString();
            }
            conflictTypes[cType] = (conflictTypes[cType] ?: 0) + 1;

            // Track affected fields (support both fieldName and field)
            string fieldNameOnly = "unknown";
            var fTmp = cm["fieldName"];
            if (fTmp is ()) {
                fTmp = cm["field"];
            }
            if (fTmp is string) {
                fieldNameOnly = fTmp;
            } else if (!(fTmp is ())) {
                fieldNameOnly = fTmp.toString();
            }
            affectedFields.push(fieldNameOnly);
        }
    }

    return {
        total_conflicts: conflictList.length(),
        conflict_types: conflictTypes,
        affected_fields: affectedFields
    };
}

// Determine resolution strategy based on conflicts and aggregation method
function determineResolutionStrategy(json[] conflictList, string aggregationMethod) returns string {
    if (conflictList.length() == 0) {
        return "no_conflicts_detected";
    }

    if (aggregationMethod == "llm_intelligent_merge") {
        return "llm_guided_resolution_with_authority_precedence";
    } else {
        return "authority_and_date_precedence_fallback";
    }
}

// Build conflict resolution summary for details
function buildConflictResolutionSummary(json[] conflictList) returns json[] {
    json[] resolutions = [];

    foreach var cf in conflictList {
        if (cf is map<json>) {
            map<json> cm = <map<json>>cf;
            string fieldNameOnly = "unknown";
            var fTmp = cm["fieldName"];
            if (fTmp is ()) {
                fTmp = cm["field"];
            }
            if (fTmp is string) {
                fieldNameOnly = fTmp;
            } else if (!(fTmp is ())) {
                fieldNameOnly = fTmp.toString();
            }

            string cType = "unknown";
            var ctTmp = cm["conflictType"];
            if (ctTmp is ()) {
                ctTmp = cm["conflict_type"];
            }
            if (ctTmp is string) {
                cType = ctTmp;
            } else if (!(ctTmp is ())) {
                cType = ctTmp.toString();
            }

            string res = "unknown";
            var rmTmp = cm["resolution"];
            if (rmTmp is ()) {
                rmTmp = cm["resolution_method"];
            }
            if (rmTmp is string) {
                res = rmTmp;
            } else if (!(rmTmp is ())) {
                res = rmTmp.toString();
            }

            int affected = 0;
            var crJ = cm["conflictingRules"];
            if (crJ is ()) {
                crJ = cm["conflicting_rules"];
            }
            if (crJ is json[]) {
                affected = crJ.length();
            }
            resolutions.push(<json>{
                "field": fieldNameOnly,
                "conflict_type": cType,
                "resolution_method": res,
                "affected_rules": affected
            });
        }
    }

    return resolutions;
}

// Build comprehensive conflict analysis report
function buildConflictAnalysisReport(json[] conflictList) returns map<json> {
    return {
        total_conflicts: conflictList.length(),
        conflict_breakdown: buildConflictSummary(conflictList),
        resolution_summary: buildConflictResolutionSummary(conflictList),
        analysis_timestamp: time:utcNow().toString()
    };
}
