import ballerina/http;
import ballerina/sql;
import ballerina/time;

// Typed rows for strict handling
type RuleRow record {
    string id;
    string rule_type;
    string rule_category;
    string title;
    string? description;
    json rule_data;
    string? effective_date;
    string? expiry_date;
};

type BracketRow record {
    string id;
    string rule_id;
    decimal? min_income;
    decimal? max_income;
    decimal rate;
    decimal? fixed_amount;
    int bracket_order;
};

// Public function to generate and activate a form schema for a given type and optional date
// Strict: fails if rules are incomplete/conflicting; does not activate on failure.
public function generateAndActivateFormSchema(string schemaType, string? date)
returns json|error {
    string calcType = schemaType.toLowerAscii();
    if (!(calcType == "income_tax" || calcType == "vat" || calcType == "paye")) {
        return error("Unsupported schemaType: " + schemaType);
    }

    // Resolve target date
    string targetDate = date is string && date.trim().length() > 0 ? date : time:utcToCivil(time:utcNow()).year.toString() + "-" +
        ((time:utcToCivil(time:utcNow()).month < 10 ? "0" : "") + time:utcToCivil(time:utcNow()).month.toString()) + "-" +
        ((time:utcToCivil(time:utcNow()).day < 10 ? "0" : "") + time:utcToCivil(time:utcNow()).day.toString());

    // 1) Select active rules for the date
    record {RuleRow[] rules; map<BracketRow[]> bracketsByRule;} rulesBundle =
    check fetchActiveRules(calcType, targetDate);

    // 2) Build schema strictly from rules
    json schemaData = check buildJsonSchema(calcType, rulesBundle, targetDate);

    // 3) Persist versioned and activate atomically (single active per type)
    json persisted = check persistAndActivate(calcType, schemaData);

    return persisted;
}

// GET current schema endpoint (read-only)
service /api/v1/forms on httpListener {
    resource function get current(string schemaType, string? date)
    returns json|http:BadRequest|http:InternalServerError {
        do {
            string calcType = schemaType.toLowerAscii();
            if (!(calcType == "income_tax" || calcType == "vat" || calcType == "paye")) {
                return <http:BadRequest>{body: {"success": false, "error": "Unsupported schemaType"}};
            }
            boolean hasDate = date is string && date.trim().length() > 0;

            // If date provided, try to generate-on-the-fly without activation; else fetch active
            if (hasDate) {
                string td = <string>date; // safe due to hasDate
                json|error built = buildCurrentWithoutActivating(calcType, td);
                if (built is error) {
                    return <http:InternalServerError>{body: {"success": false, "error": built.message()}};
                }
                return {"success": true, "schemaType": calcType, "schema": built};
            }

            // Fetch active
            json|error active = fetchActiveSchema(calcType);
            if (active is error) {
                return <http:InternalServerError>{body: {"success": false, "error": active.message()}};
            }
            return {"success": true, "schemaType": calcType, "schema": active};
        } on fail error e {
            return <http:InternalServerError>{body: {"success": false, "error": e.message()}};
        }
    }
}

function buildCurrentWithoutActivating(string calcType, string targetDate) returns json|error {
    record {RuleRow[] rules; map<BracketRow[]> bracketsByRule;} rulesBundle =
    check fetchActiveRules(calcType, targetDate);
    json schemaData = check buildJsonSchema(calcType, rulesBundle, targetDate);
    return schemaData;
}

// Fetch active rules for a type and date from tax_rules and tax_brackets
function fetchActiveRules(string calcType, string targetDate) returns record {RuleRow[] rules; map<BracketRow[]> bracketsByRule;}|error {
    // For now, income_tax uses rules with rule_type like '%brackets%' and category 'income_tax'
    // Extend for vat/paye later.
    string ruleTypeLike = calcType == "income_tax" ? "%brackets%" : "%";
    sql:ParameterizedQuery q = `
		SELECT r.id, r.rule_type, r.rule_category, r.title, r.description, r.rule_data, r.effective_date, r.expiry_date
		FROM tax_rules r
		WHERE (r.rule_category = ${calcType} OR r.rule_type ILIKE ${ruleTypeLike})
		  AND (r.effective_date IS NULL OR r.effective_date <= ${targetDate}::date)
		  AND (r.expiry_date IS NULL OR r.expiry_date >= ${targetDate}::date)
	`;
    RuleRow[] rules = [];
    stream<record {}, sql:Error?> rs = dbClient->query(q);
    error? e = rs.forEach(function(record {} row) {
        RuleRow item = {
            id: <string>row["id"],
            rule_type: <string>row["rule_type"],
            rule_category: <string>row["rule_category"],
            title: <string>row["title"],
            description: row["description"] is string ? <string>row["description"] : (),
            rule_data: <json>row["rule_data"],
            effective_date: row["effective_date"] is string ? <string>row["effective_date"] : (),
            expiry_date: row["expiry_date"] is string ? <string>row["expiry_date"] : ()
        };
        rules.push(item);
    });
    if (e is error) {
        return error("Failed to fetch rules: " + e.message());
    }
    if (rules.length() == 0) {
        return error("No active rules found for " + calcType + " on " + targetDate);
    }
    // Load brackets for the found rules (income_tax only for now)
    map<BracketRow[]> byRule = {};
    if (calcType == "income_tax") {
        sql:ParameterizedQuery brq = `
			SELECT b.id, b.rule_id, b.min_income, b.max_income, b.rate, b.fixed_amount, b.bracket_order
			FROM tax_brackets b
			JOIN tax_rules r2 ON r2.id = b.rule_id
			WHERE (r2.rule_category = ${calcType} OR r2.rule_type ILIKE ${ruleTypeLike})
			  AND (r2.effective_date IS NULL OR r2.effective_date <= ${targetDate}::date)
			  AND (r2.expiry_date IS NULL OR r2.expiry_date >= ${targetDate}::date)
			ORDER BY b.rule_id, b.bracket_order
		`;
        stream<record {}, sql:Error?> brs = dbClient->query(brq);
        error? be = brs.forEach(function(record {} row) {
            string rid = <string>row["rule_id"];
            BracketRow b = {
                id: <string>row["id"],
                rule_id: rid,
                min_income: row["min_income"] is () ? () : <decimal>row["min_income"],
                max_income: row["max_income"] is () ? () : <decimal>row["max_income"],
                rate: <decimal>row["rate"],
                fixed_amount: row["fixed_amount"] is () ? () : <decimal>row["fixed_amount"],
                bracket_order: <int>row["bracket_order"]
            };
            BracketRow[] list = byRule[rid] ?: [];
            list.push(b);
            byRule[rid] = list;
        });
        if (be is error) {
            return error("Failed to fetch brackets: " + be.message());
        }
    }
    return {rules: rules, bracketsByRule: byRule};
}

// Build JSON Schema + UI schema strictly
function buildJsonSchema(string calcType, record {RuleRow[] rules; map<BracketRow[]> bracketsByRule;} rulesBundle, string targetDate) returns json|error {
    RuleRow[] rules = rulesBundle.rules;
    // Minimal strict checks for income_tax brackets presence
    if (calcType == "income_tax") {
        int totalBrackets = 0;
        foreach RuleRow r in rules {
            BracketRow[] br = rulesBundle.bracketsByRule[r.id] ?: [];
            totalBrackets += br.length();
        }
        if (totalBrackets == 0) {
            return error("No brackets available to generate income tax form");
        }
    }

    // Define core fields for income_tax; extendable later
    json jsonSchema;
    json uiSchema = {};
    if (calcType == "income_tax") {
        jsonSchema = {
            "$schema": "https://json-schema.org/draft/2020-12/schema",
            "title": "Sri Lanka Income Tax",
            "type": "object",
            "properties": {
                "tax_year": {"type": "string", "pattern": "^20[0-9]{2}$", "title": "Tax Year"},
                "residency_status": {"type": "string", "enum": ["resident", "non_resident"], "title": "Residency"},
                "employment_income": {"type": "number", "minimum": 0, "title": "Employment Income (LKR)"},
                "business_income": {"type": "number", "minimum": 0, "title": "Business Income (LKR)"},
                "rental_income": {"type": "number", "minimum": 0, "title": "Rental Income (LKR)"},
                "interest_income": {"type": "number", "minimum": 0, "title": "Interest (LKR)"},
                "dividend_income": {"type": "number", "minimum": 0, "title": "Dividends (LKR)"},
                "capital_gains": {"type": "number", "minimum": 0, "title": "Capital Gains (LKR)"},
                "deductions": {"type": "number", "minimum": 0, "title": "Deductions (LKR)"}
            },
            "required": ["tax_year", "residency_status"],
            "additionalProperties": false
        };
        uiSchema = {
            "ui:order": [
                "tax_year",
                "residency_status",
                "employment_income",
                "business_income",
                "rental_income",
                "interest_income",
                "dividend_income",
                "capital_gains",
                "deductions"
            ]
        };
    } else if (calcType == "paye") {
        jsonSchema = {
            "$schema": "https://json-schema.org/draft/2020-12/schema",
            "title": "Sri Lanka PAYE",
            "type": "object",
            "properties": {
                "pay_period": {"type": "string", "pattern": "^20[0-9]{2}-([0][1-9]|1[0-2])$", "title": "Pay Period (YYYY-MM)"},
                "gross_pay": {"type": "number", "minimum": 0, "title": "Gross Pay (LKR)"},
                "allowances": {"type": "number", "minimum": 0, "title": "Allowances (LKR)"},
                "employee_contributions": {"type": "number", "minimum": 0, "title": "Employee Contributions (LKR)"}
            },
            "required": ["pay_period", "gross_pay"],
            "additionalProperties": false
        };
    } else { // vat
        jsonSchema = {
            "$schema": "https://json-schema.org/draft/2020-12/schema",
            "title": "Sri Lanka VAT",
            "type": "object",
            "properties": {
                "period": {"type": "string", "pattern": "^20[0-9]{2}-([0][1-9]|1[0-2])$", "title": "Period (YYYY-MM)"},
                "taxable_turnover": {"type": "number", "minimum": 0, "title": "Taxable Turnover (LKR)"},
                "zero_rated": {"type": "number", "minimum": 0, "title": "Zero Rated (LKR)"},
                "exempt": {"type": "number", "minimum": 0, "title": "Exempt (LKR)"},
                "input_tax": {"type": "number", "minimum": 0, "title": "Input Tax (LKR)"}
            },
            "required": ["period", "taxable_turnover"],
            "additionalProperties": false
        };
    }

    // Schema metadata including provenance
    // Build sourceRuleIds as json array
    json[] srcIds = [];
    foreach RuleRow r in rules {
        srcIds.push(r.id);
    }
    json metadata = {
        "schemaType": calcType,
        "generatedAt": time:utcNow().toString(),
        "targetDate": targetDate,
        "sourceRuleIds": srcIds
    };

    return {jsonSchema: jsonSchema, uiSchema: uiSchema, metadata: metadata};
}

function persistAndActivate(string calcType, json schemaData) returns json|error {
    // Version: one more than current max for type
    int nextVersion = 1;
    stream<record {}, sql:Error?> vs = dbClient->query(`
		SELECT COALESCE(MAX(version), 0) + 1 as v FROM form_schemas WHERE schema_type = ${calcType}
	`);
    error? ve = vs.forEach(function(record {} row) {
        nextVersion = <int>row["v"];
    });
    if (ve is error) {
        return error("Failed to compute next version: " + ve.message());
    }

    string id = calcType + "_v" + nextVersion.toString();
    string dataStr = schemaData.toString();

    // Insert new row (initially not active)
    sql:ParameterizedQuery ins = `
		INSERT INTO form_schemas (id, schema_type, version, schema_data, is_active, created_at)
		VALUES (${id}, ${calcType}, ${nextVersion}, ${dataStr}::jsonb, false, NOW())
	`;
    var insRes = dbClient->execute(ins);
    if (insRes is sql:Error) {
        return error("Failed to insert schema: " + insRes.message());
    }

    // Deactivate previous actives and activate this one
    var deact = dbClient->execute(`UPDATE form_schemas SET is_active = false WHERE schema_type = ${calcType} AND is_active = true`);
    if (deact is sql:Error) {
        return error("Failed to deactivate previous active schema: " + deact.message());
    }
    var act = dbClient->execute(`UPDATE form_schemas SET is_active = true WHERE id = ${id}`);
    if (act is sql:Error) {
        return error("Failed to activate new schema: " + act.message());
    }

    return {id: id, schema_type: calcType, version: nextVersion, is_active: true, schema_data: schemaData};
}

function fetchActiveSchema(string calcType) returns json|error {
    sql:ParameterizedQuery q = `
		SELECT id, version, schema_data
		FROM form_schemas
		WHERE schema_type = ${calcType} AND is_active = true
		ORDER BY version DESC
		LIMIT 1
	`;
    json out = {};
    stream<record {}, sql:Error?> rs = dbClient->query(q);
    int count = 0;
    error? e = rs.forEach(function(record {} row) {
        count += 1;
        out = {
            id: <string>row["id"],
            version: <int>row["version"],
            schema_data: <json>row["schema_data"]
        };
    });
    if (e is error) {
        return error("Failed to fetch active schema: " + e.message());
    }
    if (count == 0) {
        return error("No active schema found for " + calcType);
    }
    return out;
}

