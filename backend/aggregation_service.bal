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
    string systemPrompt = "You are a Sri Lankan tax calculation expert who creates UNIFIED executable tax systems from multiple government documents. Your goal is to merge different documents into ONE coherent calculation flow that produces a working tax calculator.\n\n" +
        "UNIVERSAL DOCUMENT PROCESSING:\n" +
        "You will receive documents in UNKNOWN formats and structures. Your task is to:\n" +
        "1. ANALYZE each document's content intelligently (regardless of format)\n" +
        "2. EXTRACT tax-relevant information (rates, brackets, formulas, variables)\n" +
        "3. CLASSIFY documents by their role: Tax Tables, Policy Documents, Examples, Instructions\n" +
        "4. MERGE all extracted information into ONE unified calculation system\n" +
        "5. ENSURE the output works with the existing calculation engine\n\n" +
        "DOCUMENT CLASSIFICATION (Auto-detect):\n" +
        "- TAX TABLES: Contains bracket structures, rate percentages, income thresholds\n" +
        "- POLICY DOCUMENTS: Contains calculation formulas, variable definitions, methodology\n" +
        "- WORKED EXAMPLES: Contains sample calculations showing input→output flows\n" +
        "- INSTRUCTION SHEETS: Contains procedural steps, definitions, clarifications\n" +
        "- MIXED DOCUMENTS: Contains multiple types of information\n" +
        "Your task: AUTO-DETECT document types and extract ALL relevant tax information";

    string constraints = "UNIVERSAL COMPATIBILITY RULES:\n" +
        "1. CALCULATION ENGINE COMPATIBILITY:\n" +
        "   - Output MUST work with existing tax_calculation_service.bal\n" +
        "   - Formulas MUST use supported constructs: +, -, *, /, parentheses, if-then-else\n" +
        "   - Additionally allowed helpers (supported by the engine): progressiveTax(var), pct(var)*value, max(...), min(...)\n" +
        "   - Variable names MUST be consistent and calculable\n" +
        "   - Progressive tax logic MUST use complete nested if-then-else structure (no ellipsis)\n" +
        "   - Each formula MUST have 'output_field' for variable chaining\n\n" +
        "2. FUTURE-PROOF DOCUMENT HANDLING:\n" +
        "   - NEVER assume document structure or format\n" +
        "   - Extract tax information from ANY content format (tables, paragraphs, lists, examples)\n" +
        "   - Handle partial information gracefully (fill gaps intelligently)\n" +
        "   - Combine information from multiple document types\n" +
        "   - Preserve ALL extracted tax rules and rates\n\n" +
        "3. INPUT vs CALCULATED FIELD CLASSIFICATION:\n" +
        "   - USER INPUTS: Only values the user must provide (salary, allowances, reliefs)\n" +
        "   - CALCULATED VALUES: Results derived from formulas (annual_gross, taxable_income, tax_amount)\n" +
        "   - NEVER include calculated values in required_variables\n" +
        "   - Example: If annual_gross = monthly_salary × 12, then only monthly_salary is a user input\n\n" +
        "4. ROBUST FORMULA DEPENDENCY CHAIN:\n" +
        "   - Create logical calculation sequence: user_inputs → intermediate_calculations → final_result\n" +
        "   - Handle missing intermediate steps by inferring them\n" +
        "   - Ensure each formula only references previously calculated values or user inputs\n" +
        "   - Support complex multi-step calculations with proper ordering\n\n" +
        "5. COMPREHENSIVE BRACKET INTEGRATION:\n" +
        "   - CRITICAL: Create COMPLETE bracket coverage starting from 0 income\n" +
        "   - Merge partial bracket information from multiple documents\n" +
        "   - ALWAYS include first bracket starting at min_income: 0\n" +
        "   - Brackets must be contiguous and non-overlapping; define explicit lower/upper bounds.\n" +
        "   - Handle gaps by merging from higher-authority/recency sources; do NOT invent new rates.\n" +
        "   - Support both simple rate brackets AND complex fixed-amount brackets\n" +
        "   - Convert ALL bracket systems to unified if-then-else formulas\n\n" +
        "6. INTELLIGENT CONFLICT RESOLUTION:\n" +
        "   - Auto-resolve conflicts between different document sources\n" +
        "   - Prioritize: Specific over general, Recent over old, Complete over partial\n" +
        "   - Merge conflicting bracket systems into unified coverage\n" +
        "   - Document all resolution decisions for transparency\n\n" +
        "7. DATA INTEGRITY & VALIDATION:\n" +
        "   - Use ONLY data from provided documents (no external assumptions)\n" +
        "   - Validate formula chains for mathematical consistency\n" +
        "   - Ensure output is executable by calculation service\n" +
        "   - Preserve source traceability for all extracted data\n" +
        "   - CRITICAL: Use EXACT RULE IDs from the provided reference list in source_refs (do not modify or add suffixes)";

    string domainGuidance = "ADAPTIVE TAX CALCULATION CONTEXT:\n" +
        "Process ANY document type and extract tax-relevant information:\n\n";
    if (calcType == "income_tax") {
        domainGuidance += "INCOME TAX - Universal Processing:\n" +
            "- Extract: Progressive brackets, personal relief amounts, tax rates, calculation formulas\n" +
            "- Document Types: Tax tables, policy documents, examples, instruction sheets\n" +
            "- Required Flow: annual_income → taxable_income → bracket_lookup → tax_amount\n" +
            "- Auto-detect USER INPUTS vs CALCULATED values from any document format\n" +
            "- Handle: Rate-only brackets, fixed-amount brackets, mixed systems\n" +
            "- Ensure: Complete bracket coverage from 0 to maximum income\n" +
            "- Output: Both brackets array AND progressive_tax_logic formula\n" +
            "- Calculation Service Compatibility: Use if-then-else for progressive logic (no ellipsis)";
    } else if (calcType == "paye") {
        domainGuidance += "PAYE TAX - Universal Processing:\n" +
            "- Extract: Monthly/annual conversions, progressive brackets, personal relief, tax rates\n" +
            "- Document Types: Salary tax tables, PAYE policies, worked examples, calculation guides\n" +
            "- Required Flow: monthly_salary → annual_gross → taxable_income → bracket_lookup → tax_amount\n" +
            "- Auto-detect: Monthly vs annual calculations, required conversions\n" +
            "- Handle: Partial bracket systems, missing 0-income brackets, complex rate structures\n" +
            "- CRITICAL REQUIREMENTS:\n" +
            "  * ALWAYS start brackets from 0 income (even if documents don't show it)\n" +
            "  * Merge partial bracket systems into complete coverage\n" +
            "  * If doc shows 150K-233K bracket, infer 0-150K bracket with appropriate rate\n" +
            "  * Prioritize brackets with fixed_amount deductions over simple rates\n" +
            "  * Create seamless bracket transitions without gaps\n" +
            "- USER INPUTS (typical): monthly_regular_profits_from_employment, personal_relief\n" +
            "- CALCULATED (typical): annual_gross, taxable_income, tax_amount\n" +
            "- NEVER ask user for: tax_rate, bracket_rate (comes from bracket lookup)\n" +
            "- Output Format: Complete brackets array + executable progressive_tax_logic\n" +
            "- Calculation Service Requirements: Nested if-then-else with proper variable names";
    } else if (calcType == "vat") {
        domainGuidance += "VAT TAX - Universal Processing:\n" +
            "- Extract: VAT rates, input/output calculations, registration thresholds, exemptions\n" +
            "- Document Types: VAT rate tables, calculation guides, examples, policy documents\n" +
            "- Required Flow: taxable_supplies → output_tax → net_VAT (after input_tax_credit)\n" +
            "- Auto-detect: Standard vs reduced rates, threshold calculations\n" +
            "- USER INPUTS (typical): taxable_supplies, input_tax_credit\n" +
            "- CALCULATED (typical): output_tax, net_VAT_payable\n" +
            "- Handle: Multiple VAT rates, exemption rules, threshold calculations";
    }

    domainGuidance += "\n\nUNIVERSAL EXTRACTION RULES:\n" +
        "1. DOCUMENT ANALYSIS:\n" +
        "   - Scan for: Numbers, percentages, income ranges, formulas, examples\n" +
        "   - Identify: Tax rates, bracket boundaries, calculation steps, variable definitions\n" +
        "   - Extract: All tax-relevant data regardless of presentation format\n" +
        "   - Infer: Missing information from context and examples\n\n" +
        "2. BRACKET RECONSTRUCTION:\n" +
        "   - From tables: Extract rates and income ranges directly\n" +
        "   - From text: Parse narrative descriptions of tax brackets\n" +
        "   - From examples: Reverse-engineer bracket structure from calculations\n" +
        "   - Fill gaps: Infer missing brackets for complete coverage\n" +
        "   - Validate: Ensure no income ranges are uncovered\n\n" +
        "3. FORMULA EXTRACTION:\n" +
        "   - From policy docs: Extract calculation methodology\n" +
        "   - From examples: Derive formulas from worked calculations\n" +
        "   - From instructions: Convert steps into executable formulas\n" +
        "   - Validate: Ensure formulas are mathematically consistent\n\n" +
        "4. CALCULATION SERVICE COMPATIBILITY:\n" +
        "   - All formulas must use: +, -, *, /, parentheses, if-then-else\n" +
        "   - Progressive tax: Convert to nested if-then-else structure\n" +
        "   - Variable naming: Use consistent, calculable variable names\n" +
        "   - Output fields: Every formula needs 'output_field' for chaining\n" +
        "   - Test vectors: Include validation examples for each formula";

    // Build rules summary for LLM
    string rulesSummary = buildRulesSummaryForLlm(allRules, calcType);

    // Phase 3: Add detected conflicts to LLM prompt
    string conflictDetails = buildConflictDetailsForLlm(detectedConflicts);

    string conflictAnalysis = "INTELLIGENT INTEGRATION AND CONFLICT RESOLUTION:\n" +
        "Handle ANY combination of document types and resolve conflicts automatically:\n\n" +
        "1. UNIVERSAL DOCUMENT INTEGRATION STRATEGY:\n" +
        "   - PRIMARY SOURCE PRIORITY: More specific data overrides general data\n" +
        "   - COMPLETENESS PRIORITY: Complete bracket systems override partial ones\n" +
        "   - RECENCY PRIORITY: Newer effective dates override older dates\n" +
        "   - AUTHORITY PRIORITY: Higher source_rank documents override lower rank\n" +
        "   - MERGE STRATEGY: Combine complementary information from multiple sources\n\n" +
        "2. BRACKET CONFLICT RESOLUTION (Universal):\n" +
        "   - MISSING FIRST BRACKET: If documents start from non-zero income, infer 0-start bracket\n" +
        "   - OVERLAPPING BRACKETS: Use more specific brackets (with fixed amounts) over simple rates\n" +
        "   - BRACKET GAPS: Fill missing ranges by interpolating or extending adjacent brackets\n" +
        "   - CONFLICTING RATES: Prioritize by document authority and recency\n" +
        "   - EXAMPLE RESOLUTION:\n" +
        "     * Doc A (Authority=5): 0-1M@6%, 1M-1.5M@18%, 1.5M-2M@24% [simple rates]\n" +
        "     * Doc B (Authority=8): 150K-233K@6%(-9K), 233K-275K@18%(-37K) [with fixed amounts]\n" +
        "     * UNIFIED RESULT: 0-150K@6%, 150K-233K@6%(-9K), 233K-275K@18%(-37K), 275K-316K@24%(-53K), 316K+@30%(-72K)\n" +
        "     * LOGIC: Use Doc B's specific brackets, fill gaps with Doc A's rates, infer fixed amounts\n\n" +
        "3. FORMULA CONFLICT RESOLUTION:\n" +
        "   - METHODOLOGY CONFLICTS: Policy documents override calculation examples\n" +
        "   - VARIABLE CONFLICTS: Use most complete variable definitions\n" +
        "   - CALCULATION STEP CONFLICTS: Merge steps into comprehensive calculation chain\n" +
        "   - MISSING FORMULAS: Infer from examples and bracket structures\n\n" +
        "4. FIELD METADATA RESOLUTION:\n" +
        "   - TYPE CONFLICTS: Use most specific type definition\n" +
        "   - TITLE CONFLICTS: Use most descriptive title\n" +
        "   - VALIDATION CONFLICTS: Merge validation rules (use most restrictive)\n" +
        "   - MISSING METADATA: Infer from usage context and examples\n\n" +
        "5. VARIABLE CLASSIFICATION RESOLUTION:\n" +
        "   - INPUT vs CALCULATED: Analyze formula dependencies to classify correctly\n" +
        "   - REQUIRED vs OPTIONAL: Use most comprehensive requirements list\n" +
        "   - MISSING VARIABLES: Infer from calculation chain and examples\n\n" +
        "6. PROGRESSIVE TAX LOGIC CONSTRUCTION:\n" +
        "   - UNIVERSAL BRACKET CONVERSION: Convert ANY bracket system to if-then-else logic\n" +
        "   - MISSING BRACKETS: Infer complete bracket coverage from partial data\n" +
        "   - COMPLEX FORMULAS: Handle multi-step progressive calculations\n" +
        "   - VALIDATION: Ensure mathematical consistency across all brackets\n\n" +
        "7. CALCULATION SERVICE INTEGRATION:\n" +
        "   - FORMULA COMPATIBILITY: Ensure all expressions work with tax_calculation_service.bal\n" +
        "   - VARIABLE NAMING: Use consistent naming that matches calculation engine\n" +
        "   - OUTPUT STRUCTURE: Provide both brackets (for forms) AND formulas (for calculation)\n" +
        "   - ERROR HANDLING: Validate that output is mathematically executable\n\n" +
        "8. FUTURE-PROOF PROCESSING:\n" +
        "   - UNKNOWN FORMATS: Handle any document structure or presentation\n" +
        "   - PARTIAL INFORMATION: Work with incomplete data and fill gaps intelligently\n" +
        "   - NEW TAX TYPES: Adapt to unknown tax calculation requirements\n" +
        "   - VALIDATION: Ensure output always works with existing calculation system";

    string outputSchema = buildAggregationOutputSchema();

    string validationInstructions = "\n\nCRITICAL VALIDATION REQUIREMENTS:\n" +
        "Before submitting your response, verify UNIVERSAL COMPATIBILITY:\n\n" +
        "1. CALCULATION SERVICE COMPATIBILITY CHECK:\n" +
        "   ✓ Can the tax_calculation_service.bal execute all formulas?\n" +
        "   ✓ Are all formulas using supported constructs: +, -, *, /, parentheses, if-then-else?\n" +
        "   ✓ Helpers allowed: progressiveTax(var), pct(var)*value, max(...), min(...)\n" +
        "   ✓ Is progressive_tax_logic in proper nested if-then-else format?\n" +
        "   ✓ Does each formula have proper 'output_field' for variable chaining?\n" +
        "   ✓ Are variable names consistent and calculable?\n\n" +
        "2. INPUT CLASSIFICATION VALIDATION:\n" +
        "   ✓ Can you calculate the final tax amount using ONLY fields in required_variables?\n" +
        "   ✓ Are ALL fields in required_variables things only a user can provide?\n" +
        "   ✓ Are calculated values (annual_gross, taxable_income, tax_amount) NOT in required_variables?\n" +
        "   ✓ Is each calculated field marked with is_calculated: true?\n\n" +
        "3. FORMULA CHAIN VALIDATION:\n" +
        "   ✓ Are formulas ordered so each step only uses previous results or user inputs?\n" +
        "   ✓ Is the calculation dependency chain logical and complete?\n" +
    "   ✓ Does each formula's input_dependencies contain only valid previous outputs or user inputs?\n" +
    "   ✓ Are all intermediate calculations included in the formula chain?\n" +
    "   ✓ Do not use ellipsis (no '...'); provide complete executable expressions only.\n\n" +
        "4. BRACKET SYSTEM VALIDATION:\n" +
        "   ✓ Does bracket coverage start from 0 income (no gaps at the beginning)?\n" +
        "   ✓ Is there complete coverage with no income ranges left uncovered?\n" +
        "   ✓ Are brackets properly ordered by bracket_order?\n" +
        "   ✓ Does progressive_tax_logic match the brackets array structure?\n" +
    "   ✓ Are both rate_percent AND rate_fraction provided for compatibility?\n" +
    "   ✓ Bracket bounds must be contiguous and non-overlapping; define explicit lower/upper bounds.\n\n" +
        "5. SOURCE INTEGRITY VALIDATION:\n" +
    "   ✓ Do all source_refs use the exact rule IDs from the provided reference list?\n" +
        "   ✓ Is all data traceable to provided documents (no external assumptions)?\n" +
        "   ✓ Are conflicts properly resolved and documented?\n\n" +
        "6. FUTURE-PROOF VALIDATION:\n" +
        "   ✓ Will this work with unknown future document formats?\n" +
        "   ✓ Is the output robust against partial or missing information?\n" +
        "   ✓ Can the system handle new tax types with this structure?\n\n" +
        "EXAMPLE VALIDATION for PAYE (Universal Pattern):\n" +
        "✓ User provides: monthly_regular_profits_from_employment, personal_relief\n" +
        "✓ Calculate: annual_gross = monthly_regular_profits_from_employment × 12\n" +
        "✓ Calculate: taxable_income = annual_gross - personal_relief\n" +
        "✓ Calculate: tax_amount = progressive_bracket_calculation(taxable_income)\n" +
        "✓ Brackets: Start from 0, complete coverage, proper if-then-else logic\n" +
        "✓ Compatibility: Works with tax_calculation_service.bal operators\n" +
        "✗ Do NOT ask user for: annual_gross, taxable_income, tax_rate, tax_amount\n\n" +
    "FORMULA COMPATIBILITY EXAMPLES:\n" +
    "✓ GOOD: if (taxable_income <= 150000) then 0 else if (taxable_income <= 233333) then (taxable_income * 0.06) - 9000 else if (taxable_income <= 275000) then (taxable_income * 0.18) - 37000 else (taxable_income * 0.24) - 53000\n" +
        "✓ GOOD: 12 * monthly_regular_profits_from_employment\n" +
        "✓ GOOD: annual_gross - personal_relief\n" +
    "✓ GOOD (helpers): progressiveTax(taxable_income), pct(rate_var) * base_var, max(a, b), min(a, b)\n" +
    "✗ BAD: undefined functions, external references, unsupported operators\n\n" +
    "MISSING BRACKET HANDLING:\n" +
    "If documents show partial brackets (e.g., 150K-233K), ALWAYS infer complete coverage:\n" +
    "✓ Add 0-150K bracket (min_income: 0) using only rates present in the provided sources; do NOT fabricate new rates. If a rate is not stated, set rate_percent and rate_fraction to null and document in consolidation_notes.\n" +
        "✓ Ensure seamless transitions between all brackets\n" +
        "✓ Document inference decisions in consolidation_notes";

    string fullPrompt = systemPrompt + "\n\n" + constraints + "\n\n" + domainGuidance + "\n\n" +
                        conflictAnalysis + "\n\nDETECTED CONFLICTS:\n" + conflictDetails +
                        "\n\nRULES TO AGGREGATE:\n" + rulesSummary +
                        "\n\nOUTPUT SCHEMA:\n" + outputSchema + validationInstructions +
                        "\n\nIMPORTANT OUTPUT DIRECTIVE:\n" +
                        "Return ONLY a single valid JSON object that matches the output schema. Do not include markdown fences, explanations, or extra text. Ensure bracket continuity without inventing new rates; use rates from provided sources when merging. If a detail cannot be determined from the sources, resolve via documented conflict strategy and add a note to consolidation_notes.";

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
    string summary = "UNIVERSAL DOCUMENT ANALYSIS FRAMEWORK:\n" +
        "Process each document regardless of format or structure. Extract ALL tax-relevant information:\n\n" +
        "ADAPTIVE DOCUMENT CLASSIFICATION:\n" +
        "Auto-detect document types based on content analysis:\n" +
        "- TAX TABLES: Contains numerical brackets, rate percentages, income thresholds, structured data\n" +
        "- POLICY DOCUMENTS: Contains calculation methodology, variable definitions, procedural steps\n" +
        "- WORKED EXAMPLES: Contains input-output calculations, sample scenarios, validation data\n" +
        "- INSTRUCTION GUIDES: Contains definitions, explanations, procedural guidance\n" +
        "- MIXED DOCUMENTS: Contains multiple types of information requiring comprehensive extraction\n\n" +
        "EXTRACTION STRATEGY (Universal):\n" +
        "- SCAN for: Numbers, percentages, ranges, formulas, variables, examples\n" +
        "- IDENTIFY: Tax rates, bracket boundaries, calculation steps, input requirements\n" +
        "- EXTRACT: All tax-relevant data regardless of presentation format\n" +
        "- INFER: Missing information from context, examples, and logical deduction\n" +
        "- VALIDATE: Ensure extracted data is mathematically consistent\n\n" +
        "INTEGRATION METHODOLOGY:\n" +
        "- COMBINE: Complementary information from multiple document types\n" +
        "- RESOLVE: Conflicts using authority, recency, and completeness priorities\n" +
        "- FILL GAPS: Infer missing bracket boundaries, rates, or calculation steps\n" +
        "- OUTPUT: Both structured brackets AND executable formulas for calculation service\n\n";

    summary += "RULE ID REFERENCE LIST (use these exact IDs in source_refs):\n";
    foreach var rule in rules {
        summary += "- " + rule.id + " (Authority: " + rule.source_rank.toString() + ")\n";
    }
    summary += "\nCRITICAL: Use the EXACT RULE IDs listed above in source_refs (do not add/remove suffixes).\n\n";

    summary += "COMPREHENSIVE DOCUMENT ANALYSIS:\n";
    int ruleIndex = 1;

    foreach var rule in rules {
        summary += "=== DOCUMENT " + ruleIndex.toString() + " ===\n";
        summary += "RULE ID: " + rule.id + "\n";

        // Enhanced document type detection
        string docTypeAnalysis = "UNKNOWN";
        if (rule.id.includes("table") || rule.id.includes("bracket") || rule.id.includes("rate")) {
            docTypeAnalysis = "TAX TABLE (extract brackets/rates for authoritative tax structure)";
        } else if (rule.id.includes("policy") || rule.id.includes("procedure") || rule.id.includes("guide")) {
            docTypeAnalysis = "POLICY DOCUMENT (extract formulas/logic for calculation methodology)";
        } else if (rule.id.includes("example") || rule.id.includes("sample") || rule.id.includes("worked")) {
            docTypeAnalysis = "WORKED EXAMPLE (extract calculation patterns and validation data)";
        } else if (rule.id.includes("instruction") || rule.id.includes("manual") || rule.id.includes("definition")) {
            docTypeAnalysis = "INSTRUCTION GUIDE (extract definitions and procedural steps)";
        } else {
            docTypeAnalysis = "MIXED/UNKNOWN (analyze content to determine extraction strategy)";
        }

        summary += "Document Classification: " + docTypeAnalysis + "\n";
        summary += "Title: " + rule.title + "\n";
        summary += "Authority Level: " + rule.source_rank.toString() + " (" + rule.source_authority + ")\n";
        summary += "Effective Date: " + rule.effective_date + "\n";
        summary += "Created: " + rule.created_at + "\n";

        // Enhanced content analysis for any document format
        json ruleData = rule.rule_data;
        if (ruleData is map<json>) {
            map<json> rd = <map<json>>ruleData;
            summary += "\nContent Analysis (Extract ALL tax information):\n";

            // Analyze brackets (structured tax rate data)
            var brackets = rd["brackets"];
            if (brackets is json[] && brackets.length() > 0) {
                summary += "- TAX BRACKETS FOUND: " + brackets.length().toString() + " bracket definitions (PRESERVE AND MERGE)\n";
                summary += "  BRACKET ANALYSIS:\n";
                foreach json bracket in brackets {
                    if (bracket is map<json>) {
                        var minIncome = bracket["min_income"];
                        var maxIncome = bracket["max_income"];
                        var rate = bracket["rate_percent"] ?: bracket["rate_fraction"];
                        var fixedAmount = bracket["fixed_amount"];
                        var bracketOrderVal = bracket["bracket_order"];

                        string bracketDesc = "  * Bracket " + (bracketOrderVal ?: "?").toString() + ": ";
                        bracketDesc += (minIncome ?: "0").toString() + " to " + (maxIncome ?: "∞").toString();
                        bracketDesc += " @ " + (rate ?: "0").toString() + "%";
                        if (fixedAmount is int|float|decimal && fixedAmount != 0) {
                            bracketDesc += " (Fixed: " + fixedAmount.toString() + ")";
                        }
                        summary += bracketDesc + "\n";
                    }
                }
                summary += "  EXTRACTION PRIORITY: High (authoritative bracket structure)\n";
            } else {
                summary += "- No structured brackets found - SCAN for numerical ranges and rates in content\n";
            }

            // Analyze formulas (calculation logic)
            var formulas = rd["formulas"];
            if (formulas is json[] && formulas.length() > 0) {
                summary += "- CALCULATION FORMULAS FOUND: " + formulas.length().toString() + " formula definitions (USE FOR LOGIC)\n";
                summary += "  FORMULA ANALYSIS:\n";
                foreach json formula in formulas {
                    if (formula is map<json>) {
                        var id = formula["id"];
                        var name = formula["name"];
                        var expr = formula["expression"];
                        var outputField = formula["output_field"];
                        var dependencies = formula["input_dependencies"];

                        summary += "  * " + (id ?: "unknown").toString() + ": " + (name ?: "unnamed").toString() + "\n";
                        summary += "    Expression: " + (expr ?: "not specified").toString() + "\n";
                        if (outputField is string) {
                            summary += "    Outputs: " + outputField + "\n";
                        }
                        if (dependencies is json[]) {
                            summary += "    Depends on: " + dependencies.toString() + "\n";
                        }
                    }
                }
                summary += "  EXTRACTION PRIORITY: High (calculation methodology)\n";
            } else {
                summary += "- No structured formulas found - SCAN for calculation patterns and mathematical expressions\n";
            }

            // Analyze field metadata (variable definitions)
            var fieldMeta = rd["field_metadata"];
            if (fieldMeta is map<json>) {
                summary += "- FIELD DEFINITIONS FOUND: " + (<map<json>>fieldMeta).length().toString() + " field definitions\n";
                summary += "  FIELD ANALYSIS:\n";
                foreach var [fieldName, fieldData] in (<map<json>>fieldMeta).entries() {
                    if (fieldData is map<json>) {
                        var fieldType = fieldData["type"];
                        var fieldTitle = fieldData["title"];
                        var isCalculated = fieldData["is_calculated"];
                        summary += "  * " + fieldName + ": " + (fieldTitle ?: "untitled").toString();
                        summary += " (" + (fieldType ?: "unknown").toString() + ")";
                        if (isCalculated is boolean && isCalculated) {
                            summary += " [CALCULATED]";
                        } else {
                            summary += " [USER INPUT]";
                        }
                        summary += "\n";
                    }
                }
            } else {
                summary += "- No structured field metadata - INFER variable types from usage context\n";
            }

            // Analyze required variables (user inputs)
            var reqVars = rd["required_variables"];
            if (reqVars is json[]) {
                summary += "- REQUIRED INPUTS FOUND: " + reqVars.length().toString() + " user input variables\n";
                summary += "  INPUT VARIABLES: " + reqVars.toString() + "\n";
            } else {
                summary += "- No required variables specified - INFER from calculation dependencies\n";
            }

            // Analyze UI order (form structure)
            var uiOrder = rd["ui_order"];
            if (uiOrder is json[]) {
                summary += "- UI STRUCTURE FOUND: Form field ordering specified\n";
                summary += "  FIELD ORDER: " + uiOrder.toString() + "\n";
            }

            // Check for any other tax-relevant data
            string[] otherKeys = [];
            foreach var [key, _] in rd.entries() {
                if (key != "brackets" && key != "formulas" && key != "field_metadata" &&
                    key != "required_variables" && key != "ui_order") {
                    otherKeys.push(key);
                }
            }
            if (otherKeys.length() > 0) {
                summary += "- OTHER TAX DATA FOUND: " + otherKeys.toString() + " (analyze for additional information)\n";
            }

        } else {
            summary += "\nContent Analysis: Non-standard format - SCAN raw content for tax information\n";
        }

        summary += "\nRaw Document Data: " + rule.rule_data.toString() + "\n";
        summary += "\nEXTRACTION INSTRUCTIONS:\n";
        summary += "- SCAN this document for ANY tax-relevant information\n";
        summary += "- EXTRACT rates, brackets, formulas, variables, examples\n";
        summary += "- INFER missing information from context and patterns\n";
        summary += "- INTEGRATE with other documents to create complete system\n";
        summary += "- PRESERVE source traceability using rule ID: " + rule.id + "\n\n";

        ruleIndex += 1;
    }

    summary += "INTEGRATION REQUIREMENTS:\n";
    summary += "1. MERGE all extracted bracket information into complete coverage (0 to maximum)\n";
    summary += "2. COMBINE all calculation logic into coherent formula chain\n";
    summary += "3. RESOLVE conflicts using authority, recency, and completeness priorities\n";
    summary += "4. ENSURE output works with existing tax_calculation_service.bal\n";
    summary += "5. VALIDATE mathematical consistency across all extracted data\n";
    summary += "6. DOCUMENT all integration decisions and conflict resolutions\n";

    return summary;
}

// Build the expected output schema for LLM with enhanced guidance
function buildAggregationOutputSchema() returns string {
    return "UNIVERSAL OUTPUT SCHEMA (Compatible with tax_calculation_service.bal):\n" +
            "{\n" +
            "  \"required_variables\": [string], // ONLY user inputs - never calculated fields\n" +
            "  \"field_metadata\": { [key: string]: {\n" +
            "    \"type\": \"number|string|integer|boolean|date\",\n" +
            "    \"title\": string,\n" +
            "    \"minimum\"?: number,\n" +
            "    \"maximum\"?: number,\n" +
            "    \"unit\"?: string,\n" +
            "    \"is_calculated\"?: boolean, // true for derived fields, false/undefined for user inputs\n" +
            "    \"source_refs\": [{\"ruleId\": \"EXACT_RULE_ID_FROM_LIST\", \"fieldName\": string}]\n" +
            "  }},\n" +
            "  \"ui_order\": [string], // Order for user input fields only (not calculated fields)\n" +
            "  \"brackets\": [{ // REQUIRED: Complete bracket structure starting from 0\n" +
            "    \"min_income\": number?, // Start first bracket at 0\n" +
            "    \"max_income\": number?, // null for highest bracket\n" +
            "    \"rate_percent\": number, // As percentage (e.g., 6 for 6%)\n" +
            "    \"rate_fraction\": number, // As decimal (e.g., 0.06 for 6%)\n" +
            "    \"fixed_amount\": number?, // Fixed deduction amount (0 if none)\n" +
            "    \"bracket_order\": number, // Sequential order starting from 1\n" +
            "    \"source_refs\": [{\"ruleId\": \"EXACT_RULE_ID_FROM_LIST\", \"bracketId\": string}]\n" +
            "  }],\n" +
            "  \"formulas\": [{ // Calculation chain in dependency order\n" +
            "    \"id\": string, // Unique formula identifier\n" +
            "    \"name\": string, // Human-readable name\n" +
            "    \"expression\": string, // MUST use: +, -, *, /, parentheses, if-then-else only; helpers allowed: progressiveTax(), pct(), max(), min()\n" +
            "    \"order\": number, // Calculation sequence order (1, 2, 3...)\n" +
            "    \"output_field\": string, // REQUIRED: What variable this formula creates\n" +
            "    \"input_dependencies\": [string], // What inputs this formula needs\n" +
            "    \"source_refs\": [{\"ruleId\": \"EXACT_RULE_ID_FROM_LIST\", \"formulaId\": string}],\n" +
            "    \"testVectors\": [{ // Validation examples\n" +
            "      \"inputs\": { [var: string]: number|string },\n" +
            "      \"expectedResult\": number,\n" +
            "      \"tolerance\"?: number\n" +
            "    }]\n" +
            "  }],\n" +
            "  \"calculation_flow\": [{ // Step-by-step calculation sequence\n" +
            "    \"step\": number,\n" +
            "    \"description\": string,\n" +
            "    \"formula_id\": string,\n" +
            "    \"depends_on\": [string] // Previous steps or user inputs\n" +
            "  }],\n" +
            "  \"progressive_tax_logic\": string, // REQUIRED: Complete if-then-else formula for brackets\n" +
            "  \"consolidation_notes\": [string], // Document integration decisions\n" +
            "  \"conflicts_resolved\": [{ // Document conflict resolutions\n" +
            "    \"field\": string,\n" +
            "    \"resolution\": string,\n" +
            "    \"reason\": string\n" +
            "  }]\n" +
            "}\n\n" +
            "CRITICAL COMPATIBILITY REQUIREMENTS:\n" +
            "1. CALCULATION SERVICE INTEGRATION:\n" +
            "   - All expressions MUST use ONLY: +, -, *, /, parentheses, if-then-else; helpers allowed: progressiveTax(), pct(), max(), min()\n" +
            "   - Variable names MUST be consistent and reference-able\n" +
            "   - Progressive tax logic MUST be complete nested if-then-else\n" +
            "   - Each formula MUST have 'output_field' for variable chaining\n\n" +
            "2. BRACKETS FIELD REQUIREMENTS:\n" +
            "   - ALWAYS include 'brackets' array with complete structure\n" +
            "   - MUST start from min_income: 0 (even if documents don't show it)\n" +
            "   - Include both rate_percent (6) and rate_fraction (0.06)\n" +
            "   - Ensure complete coverage with no income gaps; bounds must be contiguous and non-overlapping\n\n" +
            "3. FORMULA CHAIN REQUIREMENTS:\n" +
            "   - Order formulas by dependency: user inputs → intermediates → final result\n" +
            "   - Each formula's output_field becomes available for subsequent formulas\n" +
            "   - input_dependencies MUST only reference previous outputs or user inputs\n" +
            "   - Final formula MUST calculate the main tax amount\n\n" +
            "4. VARIABLE CLASSIFICATION:\n" +
            "   - required_variables: ONLY what user must provide\n" +
            "   - field_metadata: Mark calculated fields with is_calculated: true\n" +
            "   - ui_order: ONLY user input fields (not calculated fields)\n\n" +
            "UNIVERSAL EXAMPLES (Adaptable to any tax type):\n" +
            "\n" +
            "PAYE Example Structure:\n" +
            "{\n" +
            "  \"required_variables\": [\"monthly_regular_profits_from_employment\", \"personal_relief\"],\n" +
            "  \"brackets\": [\n" +
            "    {\"min_income\": 0, \"max_income\": 150000, \"rate_percent\": 0, \"rate_fraction\": 0, \"fixed_amount\": 0, \"bracket_order\": 1},\n" +
            "    {\"min_income\": 150001, \"max_income\": 233333, \"rate_percent\": 6, \"rate_fraction\": 0.06, \"fixed_amount\": 9000, \"bracket_order\": 2}\n" +
            "  ],\n" +
            "  \"formulas\": [\n" +
            "    {\"id\": \"annual_gross_calculation\", \"name\": \"Annual Gross\", \"expression\": \"12 * monthly_regular_profits_from_employment\", \"order\": 1, \"output_field\": \"annual_gross\", \"input_dependencies\": [\"monthly_regular_profits_from_employment\"]},\n" +
            "    {\"id\": \"taxable_income_calculation\", \"name\": \"Taxable Income\", \"expression\": \"annual_gross - personal_relief\", \"order\": 2, \"output_field\": \"taxable_income\", \"input_dependencies\": [\"annual_gross\", \"personal_relief\"]},\n" +
            "    {\"id\": \"tax_amount_calculation\", \"name\": \"Tax Amount\", \"expression\": \"if (taxable_income <= 150000) then 0 else if (taxable_income <= 233333) then (taxable_income * 0.06) - 9000 else...\", \"order\": 3, \"output_field\": \"tax_amount\", \"input_dependencies\": [\"taxable_income\"]}\n" +
            "  ],\n" +
            "  \"progressive_tax_logic\": \"if (taxable_income <= 150000) then 0 else if (taxable_income <= 233333) then (taxable_income * 0.06) - 9000 else if (taxable_income <= 275000) then (taxable_income * 0.18) - 37000 else...\"\n" +
            "}\n" +
            "\n" +
            "FORMULA SYNTAX VALIDATION:\n" +
            "✓ SUPPORTED: +, -, *, /, parentheses, if-then-else, variable names, numbers\n" +
            "✓ EXAMPLE: if (income <= 100000) then (income * 0.05) else (income * 0.10) - 5000\n" +
            "✗ UNSUPPORTED: functions, external references, complex operators, undefined variables\n" +
            "\n" +
            "BRACKET COVERAGE VALIDATION:\n" +
            "✓ COMPLETE: 0-150K, 150K-233K, 233K-275K, 275K+ (no gaps)\n" +
            "✗ INCOMPLETE: 150K-233K, 275K+ (missing 0-150K and 233K-275K)\n" +
            "\n" +
            "SOURCE REFERENCE VALIDATION:\n" +
            "✓ CORRECT: Use exactly the RULE IDs provided in the reference list above.\n" +
            "✗ INCORRECT: Altering IDs (adding/removing suffixes) or using unrelated document IDs.\n" +
            "\n" +
            "FUTURE-PROOF GUIDELINES:\n" +
            "- Structure output to work with ANY future document format\n" +
            "- Ensure backward compatibility with existing calculation service\n" +
            "- Make intelligent inferences for missing data\n" +
            "- Document all assumptions and inferences clearly\n" +
            "- Validate mathematical consistency across all formulas";
}

// Call Gemini LLM with aggregation prompt
function callGeminiForAggregation(string prompt, string calcType) returns json|error {
    // Enhanced generation config for consistent logical reasoning with unknown document formats
    json body = {
        "contents": [
            {"role": "user", "parts": [{"text": prompt}]}
        ],
        "generationConfig": {
            "temperature": 0.05, // Very low temperature for maximum consistency
            "topP": 0.05, // Very focused reasoning for document processing
            "topK": 10, // Reduced topK for more deterministic responses
            "candidateCount": 1,
            "maxOutputTokens": 6144, // Increased for complex document analysis
            "response_mime_type": "application/json"
        },
        "safetySettings": [
            {"category": "HARM_CATEGORY_HARASSMENT", "threshold": "BLOCK_NONE"},
            {"category": "HARM_CATEGORY_HATE_SPEECH", "threshold": "BLOCK_NONE"},
            {"category": "HARM_CATEGORY_SEXUALLY_EXPLICIT", "threshold": "BLOCK_NONE"},
            {"category": "HARM_CATEGORY_DANGEROUS_CONTENT", "threshold": "BLOCK_NONE"}
        ]
    };

    string path = "/v1beta/models/" + GEMINI_TEXT_MODEL + ":generateContent?key=" + GEMINI_API_KEY;
    log:printInfo("Calling Gemini for intelligent aggregation with enhanced document processing");

    http:Response|error resp = geminiTextClient->post(path, body);
    if (resp is error) {
        return error("LLM call failed: " + resp.message());
    }

    json|error payload = resp.getJsonPayload();
    if (payload is error) {
        return error("LLM response parse failed: " + payload.message());
    }

    // Extract and parse LLM response
    string resultText = extractGeminiResponseText(payload);
    if (resultText.length() == 0) {
        return error("Empty LLM response");
    }

    // Enhanced JSON cleaning for complex document processing results
    string cleaned = sanitizeLlmJsonString(resultText);
    json|error parsed = parseJsonStrictLocal(cleaned);
    if (parsed is error) {
        log:printWarn("Initial JSON parse failed, attempting recovery: " + parsed.message());
        // Try additional cleaning for malformed JSON from complex document processing
        string recleaned = removeAllOccurrences(removeAllOccurrences(resultText, "```json"), "```").trim();
        json|error reparsed = parseJsonStrictLocal(recleaned);
        if (reparsed is error) {
            return error("Invalid JSON from LLM even after recovery: " + reparsed.message());
        }
        parsed = reparsed;
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

    // Validate required fields for calculation service compatibility
    string[] requiredFields = ["required_variables", "field_metadata", "ui_order", "formulas", "brackets", "progressive_tax_logic"];
    foreach string fld in requiredFields {
        if (!result.hasKey(fld)) {
            log:printWarn("Missing required field: " + fld + " - attempting to infer or provide default");

            // Provide intelligent defaults for missing fields
            if (fld == "brackets" && !result.hasKey("brackets")) {
                // If no brackets, create empty array (for non-bracket tax types)
                result["brackets"] = [];
            } else if (fld == "progressive_tax_logic" && !result.hasKey("progressive_tax_logic")) {
                // If no progressive logic, provide empty string
                result["progressive_tax_logic"] = "";
            } else if (fld == "ui_order" && !result.hasKey("ui_order")) {
                // Infer UI order from required_variables
                var reqVars = result["required_variables"];
                if (reqVars is json[]) {
                    result["ui_order"] = reqVars;
                } else {
                    result["ui_order"] = [];
                }
            } else if (fld == "formulas" && !result.hasKey("formulas")) {
                result["formulas"] = [];
            } else if (fld == "field_metadata" && !result.hasKey("field_metadata")) {
                result["field_metadata"] = {};
            } else if (fld == "required_variables" && !result.hasKey("required_variables")) {
                result["required_variables"] = [];
            }
        }
    }

    // Validate calculation service compatibility
    var compatibilityResult = validateCalculationServiceCompatibility(result);
    if (compatibilityResult is error) {
        return error("Calculation service compatibility validation failed: " + compatibilityResult.message());
    }

    // Validate bracket structure for bracket-based taxes
    var bracketResult = validateBracketStructure(result);
    if (bracketResult is error) {
        return error("Bracket structure validation failed: " + bracketResult.message());
    }

    // Validate formula chain integrity
    var formulaResult = validateFormulaChain(result);
    if (formulaResult is error) {
        return error("Formula chain validation failed: " + formulaResult.message());
    }

    // Validate that all data has source references to original rules
    var validationResult = validateSourceReferences(result, sourceRules);
    if (validationResult is error) {
        log:printWarn("Source reference validation warning: " + validationResult.message());
        // Don't fail on source reference issues - just warn
    }

    // Add comprehensive aggregation metadata
    result["aggregation_metadata"] = {
        "method": "llm_intelligent_merge",
        "source_rule_count": sourceRules.length(),
        "aggregation_timestamp": time:utcNow().toString(),
        "data_integrity": "government_documents_only",
        "validation_status": "passed",
        "compatibility_checked": ["calculation_service", "bracket_structure", "formula_chain"]
    };

    log:printInfo("Aggregated rule validation passed - compatible with calculation service");
    return <json>result;
}

// Validate compatibility with tax_calculation_service.bal
function validateCalculationServiceCompatibility(map<json> result) returns error? {
    // Check formulas for supported operators
    var formulas = result["formulas"];
    if (formulas is json[]) {
        foreach json formulaJson in formulas {
            if (formulaJson is map<json>) {
                var expression = formulaJson["expression"];
                if (expression is string) {
                    // Check for unsupported operators or functions
                    if (expression.includes("sqrt") || expression.includes("pow") || expression.includes("log") ||
                        expression.includes("sin") || expression.includes("cos") || expression.includes("abs")) {
                        return error("Formula contains unsupported functions: " + expression);
                    }

                    // Ensure output_field is present
                    var outputField = formulaJson["output_field"];
                    if (!(outputField is string) || outputField.length() == 0) {
                        return error("Formula missing required output_field: " + (formulaJson["id"] ?: "unknown").toString());
                    }
                }
            }
        }
    }

    // Check progressive_tax_logic for supported syntax
    var progressiveLogic = result["progressive_tax_logic"];
    if (progressiveLogic is string && progressiveLogic.length() > 0) {
        if (!progressiveLogic.includes("if") || !progressiveLogic.includes("then")) {
            return error("Progressive tax logic must use if-then-else structure");
        }
    }

    return;
}

// Validate bracket structure completeness
function validateBracketStructure(map<json> result) returns error? {
    var brackets = result["brackets"];
    if (brackets is json[] && brackets.length() > 0) {
        // Check for complete coverage starting from 0
        json[] bracketArray = <json[]>brackets;

        // Sort brackets by order to validate coverage
        json[] sortedBrackets = [];
        foreach json bracket in bracketArray {
            if (bracket is map<json>) {
                sortedBrackets.push(bracket);
            }
        }

        if (sortedBrackets.length() > 0) {
            // Check first bracket starts at 0 or very low value
            var firstBracket = sortedBrackets[0];
            if (firstBracket is map<json>) {
                var minIncome = firstBracket["min_income"];
                decimal minIncomeDec = 0.0;
                boolean hasMinIncome = false;
                if (minIncome is int) {
                    minIncomeDec = <decimal>minIncome;
                    hasMinIncome = true;
                } else if (minIncome is float) {
                    minIncomeDec = <decimal>minIncome;
                    hasMinIncome = true;
                } else if (minIncome is decimal) {
                    minIncomeDec = minIncome;
                    hasMinIncome = true;
                }
                if (hasMinIncome && minIncomeDec > 10000.0d) {
                    log:printWarn("First bracket should start closer to 0, starts at: " + minIncomeDec.toString());
                    // Don't fail - just warn about potentially incomplete coverage
                }
            }
        }
    }

    return;
}

// Validate formula chain dependencies
function validateFormulaChain(map<json> result) returns error? {
    var formulas = result["formulas"];
    var requiredVariables = result["required_variables"];

    if (formulas is json[] && requiredVariables is json[]) {
        string[] availableVariables = [];

        // Add user inputs to available variables
        foreach json reqVar in <json[]>requiredVariables {
            if (reqVar is string) {
                availableVariables.push(reqVar);
            }
        }

        // Check each formula in order
        foreach json formulaJson in <json[]>formulas {
            if (formulaJson is map<json>) {
                var inputDeps = formulaJson["input_dependencies"];
                var outputField = formulaJson["output_field"];

                // Validate input dependencies are available
                if (inputDeps is json[]) {
                    foreach json dep in <json[]>inputDeps {
                        if (dep is string) {
                            boolean found = false;
                            foreach string availVar in availableVariables {
                                if (availVar == dep) {
                                    found = true;
                                    break;
                                }
                            }
                            if (!found) {
                                return error("Formula dependency not available: " + dep + " in formula " + (formulaJson["id"] ?: "unknown").toString());
                            }
                        }
                    }
                }

                // Add this formula's output to available variables
                if (outputField is string) {
                    availableVariables.push(outputField);
                }
            }
        }
    }

    return;
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
