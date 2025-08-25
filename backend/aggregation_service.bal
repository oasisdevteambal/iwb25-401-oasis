import ballerina/lang.value as v;
import ballerina/log;
import ballerina/sql;
import ballerina/time;

// Aggregate rules and then rebuild+activate form schema for the given type/date
function runAggregationAndActivateForms(string calcType, string targetDate) returns json|error {
    json agg = check aggregateRulesFor(calcType, targetDate);
    json|error schema = generateAndActivateFormSchema(calcType, targetDate);
    if (schema is error) {
        return {"aggregation": agg, "formActivation": {"success": false, "error": schema.message()}};
    }
    return {"aggregation": agg, "formActivation": {"success": true, "schema": schema}};
}

// Deterministic aggregation v1: choose latest evidence rule; copy its brackets; write an aggregated rule for the date.
function aggregateRulesFor(string calcType, string targetDate) returns json|error {
    // Load latest evidence rule active on targetDate
    // First try: prefer rules that already have applied LLM metadata using jsonb_exists to avoid '?' placeholder issues
    sql:ParameterizedQuery qr = `
                SELECT id, title, description, rule_data, created_at
                FROM tax_rules
                WHERE rule_category = ${calcType}
                    AND NOT (rule_type ILIKE 'aggregated%')
                    AND (effective_date IS NULL OR effective_date <= ${targetDate}::date)
                    AND (expiry_date IS NULL OR expiry_date >= ${targetDate}::date)
                    AND (
                                jsonb_exists(rule_data, 'field_metadata') OR jsonb_exists(rule_data, 'required_variables')
                            )
                ORDER BY COALESCE(updated_at, created_at) DESC, created_at DESC
                LIMIT 1
        `;
    string primaryId = "";
    string? primaryDesc = ();
    json primaryRuleData = {};
    int found = 0;
    stream<record {}, sql:Error?> rs = dbClient->query(qr);
    error? e = rs.forEach(function(record {} row) {
        found = 1;
        primaryId = <string>row["id"];
        primaryDesc = row["description"] is string ? <string>row["description"] : ();
        primaryRuleData = <json>row["rule_data"];
    });
    if (e is error) {
        return error("Failed to query evidence rules: " + e.message());
    }
    if (found == 0) {
        // Fallback: no rule with metadata found; pick latest created evidence rule
        log:printWarn("Aggregation: no rules with LLM metadata found; falling back to latest evidence rule for type=" + calcType + ", date=" + targetDate);
        sql:ParameterizedQuery qr2 = `
            SELECT id, title, description, rule_data, created_at
            FROM tax_rules
            WHERE rule_category = ${calcType}
              AND NOT (rule_type ILIKE 'aggregated%')
              AND (effective_date IS NULL OR effective_date <= ${targetDate}::date)
              AND (expiry_date IS NULL OR expiry_date >= ${targetDate}::date)
            ORDER BY created_at DESC
            LIMIT 1
        `;
        stream<record {}, sql:Error?> rs2 = dbClient->query(qr2);
        error? e2 = rs2.forEach(function(record {} row) {
            found = 1;
            primaryId = <string>row["id"];
            primaryDesc = row["description"] is string ? <string>row["description"] : ();
            primaryRuleData = <json>row["rule_data"];
        });
        if (e2 is error) {
            return error("Failed to query fallback evidence rules: " + e2.message());
        }
        if (found == 0) {
            return error("No evidence rules found for " + calcType + " on " + targetDate);
        }
    }

    // For income_tax, require brackets on primary
    int bracketCount = 0;
    if (calcType == "income_tax") {
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
    rdm["aggregated_from"] = [primaryId];
    rdm["aggregation_date"] = targetDate;
    rdm["aggregation_strategy"] = "latest_created";
    string ruleDataStr = (<json>rdm).toString();
    sql:ParameterizedQuery ins = `
        INSERT INTO tax_rules (id, rule_type, rule_category, title, description, rule_data, effective_date, created_at)
        VALUES (${aggId}, ${"aggregated_" + calcType}, ${calcType}, ${title}, ${primaryDesc ?: ()}, ${ruleDataStr}::jsonb, ${targetDate}::date, NOW())
    `;
    var insRes = dbClient->execute(ins);
    if (insRes is sql:Error) {
        return error("Failed to insert aggregated rule: " + insRes.message());
    }

    // Copy brackets if income_tax
    int copied = 0;
    if (calcType == "income_tax") {
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

    // Provenance (best effort)
    var prov = dbClient->execute(`
        INSERT INTO aggregated_rule_sources (aggregated_rule_id, evidence_rule_id, created_at)
        VALUES (${aggId}, ${primaryId}, NOW())`);
    if (prov is sql:Error) {
        log:printWarn("Provenance insert failed: " + prov.message());
    }
    // Record aggregation run (best effort)
    map<json> details = {"aggregatedRuleId": aggId, "sourceRuleId": primaryId, "bracketsCopied": copied};
    string detailsStr = (<json>details).toString();
    var run = dbClient->execute(`
        INSERT INTO aggregation_runs (tax_type, target_date, inputs_count, outputs_count, conflicts_count, status, details, started_at)
        VALUES (${calcType}, ${targetDate}::date, ${1}, ${1}, ${0}, 'completed', ${detailsStr}::jsonb, NOW())`);
    if (run is sql:Error) {
        log:printWarn("Aggregation run insert failed: " + run.message());
    }

    return {"aggregatedRuleId": aggId, "sourceRuleId": primaryId, "bracketsCopied": copied};
}
