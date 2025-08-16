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
            list[list.length()] = b;
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

    // Strict check: for income tax, ensure at least one bracket exists (to keep calculator grounded)
    if (calcType == "income_tax") {
        int totalBrackets = 0;
        foreach RuleRow r in rules {
            BracketRow[] br = rulesBundle.bracketsByRule[r.id] ?: [];
            totalBrackets += br.length();
        }
        if (totalBrackets == 0) {
            return error("No tax brackets found for income tax on " + targetDate);
        }
    }

    // Aggregators built from LLM-extracted rule_data
    map<json> properties = {};
    string[] reqVars = [];
    string[] uiOrderAgg = [];
    json[] formulasAgg = [];

    // Collect across all active rules
    foreach RuleRow r in rules {
        json rdJ = r.rule_data;
        if (!(rdJ is map<json>)) {
            continue;
        }
        map<json> rd = <map<json>>rdJ;

        // required_variables
        json? rv = rd["required_variables"];
        if (rv is json[]) {
            foreach json it in rv {
                if (it is string) {
                    reqVars = addUniqueString(reqVars, it);
                }
            }
        }

        // field_metadata -> properties
        json? fm = rd["field_metadata"];
        if (fm is map<json>) {
            foreach var entry in fm.entries() {
                string fname = entry[0];
                json metaJ = entry[1];
                if (!(metaJ is map<json>)) {
                    continue;
                }
                map<json> meta = <map<json>>metaJ;

                map<json> prop = {};
                json? t = meta["type"];
                if (t is string) {
                    prop["type"] = t;
                }
                json? ttl = meta["title"];
                if (ttl is string) {
                    prop["title"] = ttl;
                }
                json? min = meta["minimum"];
                if (min is int|float|decimal) {
                    prop["minimum"] = min;
                }
                json? pat = meta["pattern"];
                if (pat is string) {
                    prop["pattern"] = pat;
                }
                json? desc = meta["description"];
                if (desc is string) {
                    prop["description"] = desc;
                }
                json? en = meta["enum"];
                if (en is json[]) {
                    prop["enum"] = en;
                }

                // Basic defaulting if type missing
                if (prop["type"] is ()) {
                    // Heuristic: income-like fields -> number; else string
                    prop["type"] = hasSuffix(fname, "_income") || fname == "deductions" || fname == "gross_pay" || fname == "taxable_turnover" ? "number" : "string";
                }
                if (prop["type"] is string && <string>prop["type"] == "number" && prop["minimum"] is ()) {
                    prop["minimum"] = 0;
                }

                // Apply into properties if not already present; if present, shallow-merge to preserve first seen
                if (properties[fname] is ()) {
                    properties[fname] = prop;
                } else if (properties[fname] is map<json>) {
                    map<json> existing = <map<json>>properties[fname];
                    foreach var kv in prop.entries() {
                        existing[kv[0]] = kv[1];
                    }
                    properties[fname] = existing;
                }
            }
        }

        // ui_order
        json? uo = rd["ui_order"];
        if (uo is json[]) {
            foreach json it in uo {
                if (it is string) {
                    uiOrderAgg = addUniqueString(uiOrderAgg, it);
                }
            }
        }

        // formulas
        json? fml = rd["formulas"];
        if (fml is json[]) {
            foreach json f in fml {
                if (f is map<json>) {
                    map<json> fmMap = <map<json>>f;
                    // Normalize keys id,name,expression,order
                    json idJ = fmMap["id"] ?: (fmMap["name"] ?: "");
                    json nmJ = fmMap["name"] ?: (fmMap["id"] ?: "");
                    json exJ = fmMap["expression"] ?: "";
                    json ordJ = fmMap["order"] ?: 0;
                    formulasAgg[formulasAgg.length()] = {"id": idJ, "name": nmJ, "expression": exJ, "order": ordJ};
                }
            }
        }
    }

    // If field_metadata missing, attempt to synthesize from required variables
    if (isEmptyMap(properties) && reqVars.length() > 0) {
        foreach string v in reqVars {
            map<json> prop = {"type": (hasSuffix(v, "_income") || v == "deductions" || v == "gross_pay" || v == "taxable_turnover") ? "number" : "string"};
            if (<string>prop["type"] == "number") {
                prop["minimum"] = 0;
            }
            prop["title"] = titleCase(replaceAllStr(v, "_", " "));
            properties[v] = prop;
        }
    }

    if (isEmptyMap(properties)) {
        return error("Unable to build schema: no field metadata or required variables present in rule_data");
    }

    // Build required list from reqVars intersecting with properties
    string[] required = [];
    foreach string rvn in reqVars {
        if (!(properties[rvn] is ())) {
            required[required.length()] = rvn;
        }
    }

    // Build ui:order - prefer provided; else required first then the rest alphabetically
    string[] uiOrder = [];
    if (uiOrderAgg.length() > 0) {
        foreach string n in uiOrderAgg {
            if (!(properties[n] is ())) {
                uiOrder = addUniqueString(uiOrder, n);
            }
        }
        // append any missing fields
        foreach var ent in properties.entries() {
            string k = ent[0];
            boolean seen = false;
            foreach string x in uiOrder {
                if (x == k) {
                    seen = true;
                    break;
                }
            }
            if (!seen) {
                uiOrder[uiOrder.length()] = k;
            }
        }
    } else {
        // required first
        foreach string n in required {
            uiOrder[uiOrder.length()] = n;
        }
        // then others alphabetically
        string[] others = [];
        foreach var ent in properties.entries() {
            string k = ent[0];
            boolean inReq = false;
            foreach string r in required {
                if (r == k) {
                    inReq = true;
                    break;
                }
            }
            if (!inReq) {
                others[others.length()] = k;
            }
        }
        others = sortStrings(others);
        foreach string k in others {
            uiOrder[uiOrder.length()] = k;
        }
    }

    // Sort formulas by 'order' if present
    formulasAgg = sortFormulasByOrder(formulasAgg);

    // Compose jsonSchema and uiSchema
    json jsonSchema = {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "title": titleForCalcType(calcType),
        "type": "object",
        "properties": properties,
        "required": required,
        "additionalProperties": false
    };
    json uiSchema = {"ui:order": uiOrder};

    // Schema metadata including provenance
    json[] srcIds = [];
    foreach RuleRow r in rules {
        srcIds[srcIds.length()] = r.id;
    }
    json metadata = {
        "schemaType": calcType,
        "generatedAt": time:utcNow().toString(),
        "targetDate": targetDate,
        "sourceRuleIds": srcIds
    };

    return {jsonSchema: jsonSchema, uiSchema: uiSchema, metadata: metadata, calculationRules: formulasAgg, requiredVariables: reqVars};
}

// ---------- Helpers for dynamic schema ----------

function addUniqueString(string[] arr, string v) returns string[] {
    foreach string s in arr {
        if (s == v) {
            return arr;
        }
    }
    arr[arr.length()] = v;
    return arr;
}

function titleCase(string s) returns string {
    // Title-case by capitalizing first character and characters after spaces.
    string out = "";
    boolean cap = true;
    int i = 0;
    int n = s.length();
    while (i < n) {
        string ch = s.substring(i, i + 1);
        if (cap && ch != " ") {
            out += ch.toUpperAscii();
            cap = false;
        } else {
            out += ch.toLowerAscii();
        }
        if (ch == " ") {
            cap = true;
        }
        i = i + 1;
    }
    return out;
}

function titleForCalcType(string calcType) returns string {
    string t = replaceAllStr(calcType, "_", " ");
    return "Sri Lanka " + titleCase(t);
}

function sortFormulasByOrder(json[] formulas) returns json[] {
    // Simple bubble sort for small arrays
    int n = formulas.length();
    int i = 0;
    while (i < n) {
        int j = 0;
        while (j < n - i - 1) {
            json a = formulas[j];
            json b = formulas[j + 1];
            int ao = getOrder(a);
            int bo = getOrder(b);
            if (ao > bo) {
                json temp = formulas[j];
                formulas[j] = formulas[j + 1];
                formulas[j + 1] = temp;
            }
            j = j + 1;
        }
        i = i + 1;
    }
    return formulas;
}

function getOrder(json f) returns int {
    if (f is map<json>) {
        json? o = (<map<json>>f)["order"];
        if (o is int) {
            return o;
        }
        if (o is string) {
            int|error oi = int:fromString(o);
            return oi is int ? oi : 0;
        }
    }
    return 0;
}

function isEmptyMap(map<json> m) returns boolean {
    int c = 0;
    foreach var _ in m.entries() {
        c += 1;
        if (c > 0) {
            return false;
        }
    }
    return true;
}

function replaceAllStr(string original, string searchFor, string replaceWith) returns string {
    if (searchFor.length() == 0) {
        return original;
    }
    string result = "";
    int i = 0;
    int searchLen = searchFor.length();
    int total = original.length();
    while (i < total) {
        boolean isMatch = false;
        if (i + searchLen <= total) {
            string seg = original.substring(i, i + searchLen);
            if (seg == searchFor) {
                isMatch = true;
            }
        }
        if (isMatch) {
            result += replaceWith;
            i = i + searchLen;
        } else {
            result += original.substring(i, i + 1);
            i = i + 1;
        }
    }
    return result;
}

// splitStr helper removed to avoid extra complexity; titleCase rewritten to not depend on it.

function hasSuffix(string s, string suffix) returns boolean {
    int sl = s.length();
    int tl = suffix.length();
    if (tl == 0) {
        return true;
    }
    if (tl > sl) {
        return false;
    }
    string end = s.substring(sl - tl, sl);
    return end == suffix;
}

function sortStrings(string[] xs) returns string[] {
    int n = xs.length();
    int i = 0;
    while (i < n) {
        int j = 0;
        while (j < n - i - 1) {
            string a = xs[j];
            string b = xs[j + 1];
            if (a > b) {
                string tmp = xs[j];
                xs[j] = xs[j + 1];
                xs[j + 1] = tmp;
            }
            j = j + 1;
        }
        i = i + 1;
    }
    return xs;
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

