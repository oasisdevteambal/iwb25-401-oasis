import ballerina/http;
import ballerina/log;
import ballerina/sql;
import ballerina/time;

// Types are public in tax_api_types.bal

// Note: Uses dbClient declared in document_service.bal (same module)

// Service: Tax calculation API
service /api/v1/tax on httpListener {

    // Calculate tax based on active schema and submitted form data
    resource function post calculate(@http:Payload json payload)
    returns json|http:BadRequest|http:InternalServerError {
        // Parse and validate basic fields from payload
        CalculationRequest|error reqOrErr = payload.cloneWithType(CalculationRequest);
        if (reqOrErr is error) {
            return <http:BadRequest>{body: {success: false, code: "INVALID_REQUEST", message: reqOrErr.message()}};
        }
        CalculationRequest req = reqOrErr;

        string calcType = req.schemaType.toLowerAscii();
        if (!(calcType == "income_tax" || calcType == "vat" || calcType == "paye")) {
            return <http:BadRequest>{body: {success: false, code: "UNSUPPORTED_TYPE", message: "Unsupported schemaType"}};
        }

        // Resolve schema: active (or by version/date in future)
        json|error schema = fetchActiveSchema(calcType);
        if (schema is error) {
            return <http:InternalServerError>{body: {success: false, code: "NO_ACTIVE_SCHEMA", message: schema.message()}};
        }

        // Work with payload as map
        map<json> pmap;
        if (payload is map<json>) {
            pmap = <map<json>>payload;
        } else {
            return <http:BadRequest>{body: {success: false, code: "INVALID_REQUEST", message: "payload must be an object"}};
        }

        // Normalize inputs to decimals where applicable
        map<json> inputMap;
        json? dataJ = pmap["data"];
        if (!(dataJ is map<json>)) {
            return <http:BadRequest>{body: {success: false, code: "INVALID_DATA", message: "data must be an object"}};
        }
        inputMap = <map<json>>dataJ;
        map<json> normalized = normalizeNumericInputs(inputMap);

        // Execution ID now, to use in error logging if needed
        string execId = getOptionalStringFromMap(pmap, "executionId") ?: generateExecutionId();

        // Currently implement income_tax only (precise via DB brackets). Others: 501 Not Implemented
        if (calcType != "income_tax") {
            return <http:BadRequest>{body: {success: false, code: "NOT_IMPLEMENTED", message: "Only income_tax is implemented at the moment"}};
        }

        // Compute taxable income deterministically from provided fields
        decimal employment = getDecimal(normalized, "employment_income");
        decimal business = getDecimal(normalized, "business_income");
        decimal rental = getDecimal(normalized, "rental_income");
        decimal interest = getDecimal(normalized, "interest_income");
        decimal dividend = getDecimal(normalized, "dividend_income");
        decimal capitalGains = getDecimal(normalized, "capital_gains");
        decimal deductions = getDecimal(normalized, "deductions");

        decimal gross = employment + business + rental + interest + dividend + capitalGains;
        decimal taxableIncome = maxDecimal(0.0d, gross - deductions);

        // Determine target date (YYYY-MM-DD)
        string? dateOpt = getOptionalStringFromMap(pmap, "date");
        string targetDate = resolveTargetDate(dateOpt);

        // Compute progressive tax using DB tax_brackets for active rules
        decimal|error taxOrErr = computeProgressiveTaxFromDb(taxableIncome, "income_tax", targetDate);
        if (taxOrErr is error) {
            // Attempt to log error into calculation_errors (best effort)
            logCalculationError(execId, calcType, schema, normalized, taxOrErr.message());
            return <http:InternalServerError>{body: {success: false, code: "CALCULATION_FAILED", message: taxOrErr.message()}};
        }
        decimal taxAmount = taxOrErr;

        // Build breakdown
        Step[] breakdown = [
            {name: "gross", expression: "sum(incomes)", substituted: gross.toString(), result: gross},
            {name: "taxable", expression: "max(0, gross - deductions)", substituted: "max(0, " + gross.toString() + " - " + deductions.toString() + ")", result: taxableIncome},
            {name: "tax", expression: "progressiveTax(taxableIncome)", substituted: taxableIncome.toString(), result: taxAmount}
        ];

        // Build response
        string schemaId = "";
        int schemaVersion = 0;
        if (schema is map<json>) {
            json jId = (<map<json>>schema)["id"] ?: "";
            if (jId is string) {
                schemaId = jId;
            }
            json jVer = (<map<json>>schema)["version"] ?: 0;
            if (jVer is int) {
                schemaVersion = jVer;
            }
        }
        // execId already resolved above

        CalculationResult result = {
            success: true,
            schemaId,
            schemaVersion,
            calculationType: calcType,
            result: taxAmount,
            breakdown,
            inputs: normalized,
            formulasUsed: [
                {name: "taxable", expression: "max(0, gross - deductions)"},
                {name: "tax", expression: "progressiveTax(taxableIncome)"}
            ],
            executionId: execId,
            createdAt: time:utcNow().toString()
        };

        // Best-effort audit insert
        logCalculationAudit(result);

        // Build JSON response explicitly for type-compatibility
        json[] breakdownJson = [];
        foreach Step s in breakdown {
            breakdownJson.push({
                name: s.name,
                expression: s.expression,
                substituted: s.substituted,
                result: s.result
            });
        }
        json[] formulasJson = [
            {name: "taxable", expression: "max(0, gross - deductions)"},
            {name: "tax", expression: "progressiveTax(taxableIncome)"}
        ];

        json response = {
            success: true,
            schemaId: schemaId,
            schemaVersion: schemaVersion,
            calculationType: calcType,
            result: taxAmount,
            breakdown: breakdownJson,
            inputs: normalized,
            formulasUsed: formulasJson,
            executionId: execId,
            createdAt: time:utcNow().toString()
        };
        return response;
    }
}

// ------------ Helpers ------------

function generateExecutionId() returns string {
    return "exec_" + time:utcNow().toString();
}

// Normalize top-level numeric strings to decimal
function normalizeNumericInputs(map<json> input) returns map<json> {
    map<json> out = {};
    foreach var entry in input.entries() {
        string k = entry[0];
        json v = entry[1];
        if (v is string) {
            string s = v.trim();
            decimal|error d = decimal:fromString(s);
            if (d is decimal) {
                out[k] = d;
            } else {
                out[k] = v; // keep as-is if not numeric
            }
        } else if (v is decimal) {
            out[k] = v;
        } else if (v is int) {
            out[k] = <decimal>v;
        } else if (v is float) { // avoid float errors: convert via string
            decimal|error dv = decimal:fromString(v.toString());
            out[k] = dv is decimal ? dv : 0.0d;
        } else {
            out[k] = v;
        }
    }
    return out;
}

function getDecimal(map<json> m, string key) returns decimal {
    var v = m[key];
    if (v is decimal) {
        return v;
    }
    if (v is int) {
        return <decimal>v;
    }
    if (v is float) {
        decimal|error dv = decimal:fromString(v.toString());
        return dv is decimal ? dv : 0.0d;
    }
    if (v is string) {
        decimal|error d = decimal:fromString(v);
        return d is decimal ? d : 0.0d;
    }
    return 0.0d;
}

function maxDecimal(decimal a, decimal b) returns decimal {
    return a > b ? a : b;
}

function resolveTargetDate(string? date) returns string {
    if (date is string && date.trim().length() > 0) {
        return date;
    }
    time:Civil civ = time:utcToCivil(time:utcNow());
    string month = civ.month < 10 ? ("0" + civ.month.toString()) : civ.month.toString();
    string day = civ.day < 10 ? ("0" + civ.day.toString()) : civ.day.toString();
    return civ.year.toString() + "-" + month + "-" + day;
}

function getOptionalStringFromMap(map<json> m, string key) returns string? {
    json? v = m[key];
    if (v is string) {
        return v;
    }
    return ();
}

// Compute progressive tax using tax_brackets from DB for a calcType and date
function computeProgressiveTaxFromDb(decimal income, string calcType, string targetDate)
returns decimal|error {
    // Fetch brackets joined to rules in effect for date
    sql:ParameterizedQuery q = `
		SELECT b.min_income, b.max_income, b.rate, b.fixed_amount, b.bracket_order
		FROM tax_brackets b
		JOIN tax_rules r ON r.id = b.rule_id
		WHERE (r.rule_category = ${calcType} OR r.rule_type ILIKE ${calcType + "%"})
		  AND (r.effective_date IS NULL OR r.effective_date <= ${targetDate}::date)
		  AND (r.expiry_date IS NULL OR r.expiry_date >= ${targetDate}::date)
		ORDER BY b.bracket_order
	`;
    decimal total = 0.0d;
    boolean foundAny = false;
    stream<record {}, sql:Error?> rs = dbClient->query(q);
    error? e = rs.forEach(function(record {} row) {
        foundAny = true;
        decimal minI = row["min_income"] is () ? 0.0d : <decimal>row["min_income"];
        decimal? maxI = row["max_income"] is () ? () : <decimal>row["max_income"];
        decimal rate = <decimal>row["rate"]; // fraction e.g., 0.06
        decimal fixed = row["fixed_amount"] is () ? 0.0d : <decimal>row["fixed_amount"];

        decimal spanUpper = maxI is decimal ? <decimal>maxI : income; // open-ended: up to income
        decimal taxableInSpan = maxDecimal(0.0d, min(income, spanUpper) - minI);
        if (taxableInSpan > 0.0d) {
            total += taxableInSpan * rate + fixed;
        }
    });
    if (e is error) {
        return error("Failed reading brackets: " + e.message());
    }
    if (!foundAny) {
        return error("No tax brackets found for " + calcType + " on " + targetDate);
    }
    return total;
}

// min helper for decimals
function min(decimal a, decimal b) returns decimal {
    return a < b ? a : b;
}

// ------------- Audit logging (best-effort) -------------

function logCalculationAudit(CalculationResult res) {
    // Attempt insert into calculation_audit if table/columns exist
    json[] breakdownArr = [];
    foreach Step s in res.breakdown {
        breakdownArr.push({name: s.name, expression: s.expression, substituted: s.substituted, result: s.result});
    }
    json[] formulasArr = [];
    foreach FormulaRef f in res.formulasUsed {
        formulasArr.push({name: f.name, expression: f.expression});
    }
    json payload = {
        execution_id: res.executionId,
        schema_id: res.schemaId,
        schema_version: res.schemaVersion,
        calculation_type: res.calculationType,
        inputs: res.inputs,
        formulas: formulasArr,
        breakdown: breakdownArr,
        final_amount: res.result,
        created_at: time:utcNow().toString()
    };
    // If a REST insert or a direct SQL table exists, you can adapt here.
    // For now, write a log only to avoid runtime failures if table isn't ready.
    log:printInfo("AUDIT: " + payload.toString());
}

function logCalculationError(string executionId, string schemaType, json schema, map<json> inputs, string message) {
    json payload = {
        execution_id: executionId,
        schema_type: schemaType,
        schema_info: schema,
        inputs: inputs,
        error_type: "CALCULATION_FAILED",
        message: message,
        created_at: time:utcNow().toString()
    };
    log:printError("CALC_ERROR: " + payload.toString());
}

