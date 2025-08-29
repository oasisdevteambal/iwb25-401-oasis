import ballerina/http;
import ballerina/lang.value as v;
import ballerina/log;
import ballerina/sql;
import ballerina/time;

// Types are public in tax_api_types.bal

// Dynamic calculation types
type DynamicCalculationResult record {
    decimal finalAmount;
    Step[] breakdown;
    FormulaRef[] formulasUsed;
};

type CalculationContext record {
    map<decimal> variables;
    map<json> inputs;
    string calcType;
    string targetDate;
    string execId;
};

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

        // Determine target date (YYYY-MM-DD)
        string? dateOpt = getOptionalStringFromMap(pmap, "date");
        string targetDate = calcResolveTargetDate(dateOpt);

        // DYNAMIC CALCULATION: Use LLM-generated formulas from database
        DynamicCalculationResult|error calcResult = performDynamicCalculation(schema, calcType, normalized, targetDate, execId);
        if (calcResult is error) {
            logCalculationError(execId, calcType, schema, normalized, calcResult.message());
            return <http:InternalServerError>{body: {success: false, code: "CALCULATION_FAILED", message: calcResult.message()}};
        }

        return buildCalcResponse(schema, calcType, calcResult.finalAmount, calcResult.breakdown, normalized, execId, calcResult.formulasUsed);
    }
}

// ============================================================================
// DYNAMIC CALCULATION ENGINE - Uses LLM-generated formulas from database only
// ============================================================================

// Main dynamic calculation function that uses LLM-aggregated formulas
function performDynamicCalculation(json schema, string calcType, map<json> inputs, string targetDate, string execId)
returns DynamicCalculationResult|error {

    // Extract calculation rules from schema
    json|error calculationRules = extractCalculationRulesFromSchema(schema);
    if (calculationRules is error) {
        return error("No calculation rules found in schema: " + calculationRules.message());
    }

    if (!(calculationRules is json[])) {
        return error("Calculation rules must be an array");
    }

    json[] formulas = <json[]>calculationRules;
    if (formulas.length() == 0) {
        return error("No formulas found in calculation rules");
    }

    // Initialize calculation context
    CalculationContext context = {
        variables: {},
        inputs: inputs,
        calcType: calcType,
        targetDate: targetDate,
        execId: execId
    };

    // Convert inputs to variables (all input values become available as variables)
    foreach var entry in inputs.entries() {
        string key = entry[0];
        json value = entry[1];
        if (value is decimal) {
            context.variables[key] = value;
        } else if (value is int) {
            context.variables[key] = <decimal>value;
        } else if (value is float) {
            context.variables[key] = <decimal>value;
        }
    }

    // Sort formulas by order (LLM should provide ordered formulas)
    json[] sortedFormulas = sortFormulasByOrderLocal(formulas);

    // Execute formulas in order
    Step[] breakdown = [];
    FormulaRef[] formulasUsed = [];
    decimal finalAmount = 0.0d;

    foreach json formulaJson in sortedFormulas {
        if (!(formulaJson is map<json>)) {
            continue;
        }

        map<json> formula = <map<json>>formulaJson;

        // Extract formula details
        string formulaId = getStringFromFormula(formula, "id");
        string formulaName = getStringFromFormula(formula, "name");
        string expression = getStringFromFormula(formula, "expression");
        string outputField = getStringFromFormula(formula, "output_field");

        if (expression.trim().length() == 0) {
            continue;
        }

        // Execute the formula
        decimal|error result = executeFormulaExpression(expression, context, calcType, targetDate);
        if (result is error) {
            return error("Formula execution failed for '" + formulaId + "': " + result.message());
        }

        decimal formulaResult = result;

        // Store result as variable for subsequent formulas
        // Use output_field if available, otherwise fall back to formulaId
        string variableName = outputField.length() > 0 ? outputField : formulaId;
        context.variables[variableName] = formulaResult;

        // Create substituted expression for display
        string substituted = substituteVariablesInExpression(expression, context);

        // Add to breakdown
        breakdown.push({
            name: formulaId,
            expression: expression,
            substituted: substituted,
            result: formulaResult
        });

        // Add to formulas used
        formulasUsed.push({
            name: formulaName.length() > 0 ? formulaName : formulaId,
            expression: expression
        });

        // The last formula typically represents the final tax amount
        finalAmount = formulaResult;
    }

    return {
        finalAmount: finalAmount,
        breakdown: breakdown,
        formulasUsed: formulasUsed
    };
}

// Extract calculation rules from schema
function extractCalculationRulesFromSchema(json schema) returns json|error {
    if (!(schema is map<json>)) {
        return error("Schema must be an object");
    }

    map<json> schemaMap = <map<json>>schema;

    // Try to get calculationRules from schema_data
    json? schemaData = schemaMap["schema_data"];
    if (schemaData is string) {
        // Parse the JSON string
        json|error parsed = v:fromJsonString(<string>schemaData);
        if (parsed is error) {
            return error("Failed to parse schema_data JSON string: " + parsed.message());
        }
        if (parsed is map<json>) {
            map<json> dataMap = <map<json>>parsed;
            json? calcRules = dataMap["calculationRules"];
            if (calcRules is json[]) {
                return calcRules;
            }
        }
    } else if (schemaData is map<json>) {
        map<json> dataMap = <map<json>>schemaData;
        json? calcRules = dataMap["calculationRules"];
        if (calcRules is json[]) {
            return calcRules;
        }
    }

    // Fallback: try direct calculationRules
    json? directRules = schemaMap["calculationRules"];
    if (directRules is json[]) {
        return directRules;
    }

    return error("No calculationRules found in schema");
}

// Execute a formula expression with dynamic variable substitution
function executeFormulaExpression(string expression, CalculationContext context, string calcType, string targetDate)
returns decimal|error {

    string expr = expression.trim();

    // Handle special functions
    if (expr.includes("progressiveTax(")) {
        return executeProgressiveTaxFunction(expr, context, calcType, targetDate);
    }

    if (expr.includes("pct(")) {
        return executePercentageFunction(expr, context);
    }

    if (expr.includes("max(")) {
        return executeMaxFunction(expr, context);
    }

    if (expr.includes("min(")) {
        return executeMinFunction(expr, context);
    }

    // Handle arithmetic expressions
    return evaluateArithmeticExpression(expr, context);
}

// Execute progressive tax function using database brackets
function executeProgressiveTaxFunction(string expression, CalculationContext context, string calcType, string targetDate)
returns decimal|error {
    // Parse progressiveTax(<variable>)
    int idxStart = findIndexAt(expression, "progressiveTax(", 0);
    if (idxStart < 0) {
        return error("Invalid progressiveTax function syntax");
    }
    int open = idxStart + "progressiveTax(".length();
    int end = findIndexAt(expression, ")", open);
    if (end < 0) {
        return error("Invalid progressiveTax function syntax");
    }
    string variableName = expression.substring(open, end).trim();

    // Get the taxable amount
    decimal? taxableAmount = context.variables[variableName];
    if (taxableAmount is ()) {
        return error("Variable '" + variableName + "' not found for progressiveTax calculation");
    }

    // Use existing function to compute progressive tax from database
    return computeProgressiveTaxFromDb(taxableAmount, calcType, targetDate);
}

// Execute percentage function pct(rate) * value
function executePercentageFunction(string expression, CalculationContext context) returns decimal|error {
    // Parse pct(rateVar) * valueVar
    int idxPct = findIndexAt(expression, "pct(", 0);
    if (idxPct < 0) {
        return error("Invalid pct function syntax");
    }
    int open = idxPct + 4;
    int close = findIndexAt(expression, ")", open);
    if (close < 0) {
        return error("Invalid pct function syntax");
    }
    string rateVar = expression.substring(open, close).trim();

    int star = findIndexAt(expression, "*", close);
    if (star < 0) {
        return error("Invalid pct function syntax: missing '*'");
    }
    string valueVar = expression.substring(star + 1).trim();

    decimal? rate = context.variables[rateVar];
    decimal? value = context.variables[valueVar];

    if (rate is () || value is ()) {
        return error("Variables not found for percentage calculation");
    }

    return (<decimal>rate / 100.0d) * <decimal>value;
}

// Execute max function
function executeMaxFunction(string expression, CalculationContext context) returns decimal|error {
    // Parse max(arg1, arg2, ...)
    int idxStart = findIndexAt(expression, "max(", 0);
    if (idxStart < 0) {
        return error("Invalid max function syntax");
    }
    int open = idxStart + 4;
    int end = findIndexAt(expression, ")", open);
    if (end < 0) {
        return error("Invalid max function syntax");
    }
    string content = expression.substring(open, end);

    // Split by comma
    string[] parts = splitByChar(content, ",");
    if (parts.length() < 2) {
        return error("max function requires at least 2 arguments");
    }

    // Initialize with first value
    decimal|error firstVal = evaluateArithmeticExpression(parts[0].trim(), context);
    if (firstVal is error) {
        return firstVal;
    }
    decimal maxValue = firstVal;

    foreach int i in 1 ..< parts.length() {
        decimal|error val = evaluateArithmeticExpression(parts[i].trim(), context);
        if (val is error) {
            return val;
        }
        if (val > maxValue) {
            maxValue = val;
        }
    }

    return maxValue;
}

// Execute min function  
function executeMinFunction(string expression, CalculationContext context) returns decimal|error {
    // Parse min(arg1, arg2, ...)
    int idxStart = findIndexAt(expression, "min(", 0);
    if (idxStart < 0) {
        return error("Invalid min function syntax");
    }
    int open = idxStart + 4;
    int end = findIndexAt(expression, ")", open);
    if (end < 0) {
        return error("Invalid min function syntax");
    }
    string content = expression.substring(open, end);

    // Split by comma
    string[] parts = splitByChar(content, ",");
    if (parts.length() < 2) {
        return error("min function requires at least 2 arguments");
    }

    // Initialize with first value
    decimal|error firstVal = evaluateArithmeticExpression(parts[0].trim(), context);
    if (firstVal is error) {
        return firstVal;
    }
    decimal minValue = firstVal;

    foreach int i in 1 ..< parts.length() {
        decimal|error val = evaluateArithmeticExpression(parts[i].trim(), context);
        if (val is error) {
            return val;
        }
        if (val < minValue) {
            minValue = val;
        }
    }

    return minValue;
}

// Evaluate arithmetic expressions (addition, subtraction, multiplication, division)
function evaluateArithmeticExpression(string expression, CalculationContext context) returns decimal|error {
    string expr = expression.trim();

    // Handle conditional expressions (if-then-else)
    if (expr.startsWith("if ")) {
        return evaluateConditionalExpression(expr, context);
    }

    // Handle parentheses by recursively evaluating inner expressions
    if (expr.startsWith("(") && expr.endsWith(")")) {
        string inner = expr.substring(1, expr.length() - 1).trim();
        return evaluateArithmeticExpression(inner, context);
    }

    // Handle expressions with parentheses in the middle
    if (expr.includes("(")) {
        return evaluateExpressionWithParentheses(expr, context);
    }

    // Handle simple variable lookup
    if (isSimpleVariable(expr)) {
        decimal? value = context.variables[expr];
        if (value is ()) {
            return error("Variable '" + expr + "' not found");
        }
        return value;
    }

    // Handle simple numeric literal
    decimal|error numResult = decimal:fromString(expr);
    if (numResult is decimal) {
        return numResult;
    }

    // Handle arithmetic operations with proper precedence
    // First, handle multiplication and division (higher precedence)
    string[] mulDivParts = [];
    string currentPart = "";
    boolean inMulDiv = false;

    int i = 0;
    while (i < expr.length()) {
        string char = expr.substring(i, i + 1);

        if (char == "*" || char == "/") {
            if (currentPart.length() > 0) {
                mulDivParts.push(currentPart.trim());
                mulDivParts.push(char);
                currentPart = "";
                inMulDiv = true;
            }
        } else if ((char == "+" || char == "-") && inMulDiv) {
            // End of multiplication/division group
            if (currentPart.length() > 0) {
                mulDivParts.push(currentPart.trim());
            }

            // Evaluate the multiplication/division group
            decimal|error mulDivResult = evaluateMultiplicationDivision(mulDivParts, context);
            if (mulDivResult is error) {
                return mulDivResult;
            }

            // Continue with addition/subtraction
            string remainingExpr = expr.substring(i);
            decimal|error addSubResult = evaluateAdditionSubtraction(mulDivResult.toString() + remainingExpr, context);
            return addSubResult;

        } else {
            currentPart += char;
        }
        i += 1;
    }

    // If we have multiplication/division operations
    if (inMulDiv) {
        if (currentPart.length() > 0) {
            mulDivParts.push(currentPart.trim());
        }
        return evaluateMultiplicationDivision(mulDivParts, context);
    }

    // Handle simple addition/subtraction
    if (expr.includes("+") || expr.includes("-")) {
        return evaluateAdditionSubtraction(expr, context);
    }

    return error("Unable to evaluate expression: " + expr);
}

// Evaluate multiplication and division operations
function evaluateMultiplicationDivision(string[] parts, CalculationContext context) returns decimal|error {
    if (parts.length() < 3 || parts.length() % 2 == 0) {
        return error("Invalid multiplication/division expression");
    }

    // Start with first operand
    decimal result = check evaluateOperand(parts[0], context);

    // Process operator-operand pairs
    int i = 1;
    while (i < parts.length()) {
        string operator = parts[i];
        if (i + 1 >= parts.length()) {
            return error("Missing operand after operator: " + operator);
        }
        string operandStr = parts[i + 1];
        decimal operand = check evaluateOperand(operandStr, context);

        if (operator == "*") {
            result = result * operand;
        } else if (operator == "/") {
            if (operand == 0d) {
                return error("Division by zero");
            }
            result = result / operand;
        } else {
            return error("Invalid operator in multiplication/division: " + operator);
        }

        i += 2;
    }

    return result;
}

// Evaluate addition and subtraction operations
function evaluateAdditionSubtraction(string expr, CalculationContext context) returns decimal|error {
    // Split by + and - while keeping the operators
    string[] parts = [];
    string[] operators = [];
    string currentPart = "";

    int i = 0;
    while (i < expr.length()) {
        string char = expr.substring(i, i + 1);

        if (char == "+" || char == "-") {
            if (currentPart.length() > 0) {
                parts.push(currentPart.trim());
                operators.push(char);
                currentPart = "";
            } else if (char == "-" && i == 0) {
                // Handle negative number at start
                currentPart += char;
            }
        } else {
            currentPart += char;
        }
        i += 1;
    }

    if (currentPart.length() > 0) {
        parts.push(currentPart.trim());
    }

    if (parts.length() == 0) {
        return error("No operands found in expression");
    }

    // Start with first operand
    decimal result = check evaluateOperand(parts[0], context);

    // Apply operators
    foreach int idx in 0 ..< operators.length() {
        if (idx + 1 >= parts.length()) {
            return error("Missing operand for operator: " + operators[idx]);
        }

        decimal operand = check evaluateOperand(parts[idx + 1], context);

        if (operators[idx] == "+") {
            result = result + operand;
        } else if (operators[idx] == "-") {
            result = result - operand;
        }
    }

    return result;
}

// Evaluate a single operand (variable or number)
function evaluateOperand(string operand, CalculationContext context) returns decimal|error {
    string op = operand.trim();

    // Check if it's a variable
    if (isSimpleVariable(op)) {
        decimal? value = context.variables[op];
        if (value is ()) {
            return error("Variable '" + op + "' not found");
        }
        return value;
    }

    // Try to parse as decimal
    decimal|error numResult = decimal:fromString(op);
    if (numResult is decimal) {
        return numResult;
    }

    return error("Cannot evaluate operand: " + op);
}

// Check if string is a simple variable name
function isSimpleVariable(string expr) returns boolean {
    if (expr.length() == 0) {
        return false;
    }
    // Disallow operators and punctuation common in expressions
    string[] disallowed = [" ", "(", ")", "+", "-", "*", "/", ",", "."];
    foreach string d in disallowed {
        if (expr.includes(d)) {
            return false;
        }
    }
    // First character must not be a digit
    string first = expr.substring(0, 1);
    if (first >= "0" && first <= "9") {
        return false;
    }
    return true;
}

// Substitute variables in expression for display purposes
function substituteVariablesInExpression(string expression, CalculationContext context) returns string {
    string result = expression;
    foreach var entry in context.variables.entries() {
        string varName = entry[0];
        string replacement = entry[1].toString();
        result = replaceWholeWord(result, varName, replacement);
    }
    return result;
}

// ---- String helpers (no regex) ----

function splitByChar(string s, string sep) returns string[] {
    string[] parts = [];
    int startPos = 0;
    int seplen = sep.length();
    while true {
        int idx = findIndexAt(s, sep, startPos);
        if (idx < 0) {
            parts.push(s.substring(startPos));
            break;
        }
        parts.push(s.substring(startPos, idx));
        startPos = idx + seplen;
    }
    return parts;
}

function isWordChar(string ch) returns boolean {
    if (ch.length() != 1) {
        return false;
    }
    string c = ch;
    if ((c >= "a" && c <= "z") || (c >= "A" && c <= "Z") || (c >= "0" && c <= "9") || c == "_") {
        return true;
    }
    return false;
}

function replaceWholeWord(string text, string word, string replacement) returns string {
    if (word.length() == 0) {
        return text;
    }
    string out = "";
    int pos = 0;
    while true {
        int idx = findIndexAt(text, word, pos);
        if (idx < 0) {
            out = out + text.substring(pos);
            break;
        }
        // Check boundaries
        boolean startOk = idx == 0 || !isWordChar(text.substring(idx - 1, idx));
        int endIdx = idx + word.length();
        boolean endOk = endIdx >= text.length() || !isWordChar(text.substring(endIdx, endIdx + 1));
        if (startOk && endOk) {
            out = out + text.substring(pos, idx) + replacement;
            pos = endIdx;
        } else {
            // Not a whole word; keep as-is and continue after this index
            out = out + text.substring(pos, idx + 1);
            pos = idx + 1;
        }
    }
    return out;
}

// Find substring index from a starting offset; returns -1 if not found
function findIndexAt(string s, string sub, int fromIndex) returns int {
    int|() idx = s.indexOf(sub, fromIndex);
    if (idx is int) {
        return idx;
    }
    return -1;
}

// Helper to get string from formula map
function getStringFromFormula(map<json> formula, string key) returns string {
    json? value = formula[key];
    if (value is string) {
        return value;
    } else if (value is ()) {
        return "";
    }
    return value.toString();
}

// Sort formulas by order field (copied from form_schema_service.bal for reuse)
function sortFormulasByOrderLocal(json[] formulas) returns json[] {
    // Simple bubble sort by order field
    json[] sorted = formulas.clone();
    int n = sorted.length();

    foreach int i in 0 ..< n - 1 {
        foreach int j in 0 ..< n - i - 1 {
            json current = sorted[j];
            json next = sorted[j + 1];

            int currentOrder = 0;
            int nextOrder = 0;

            if (current is map<json>) {
                map<json> currentMap = <map<json>>current;
                json? orderVal = currentMap["order"];
                if (orderVal is int) {
                    currentOrder = orderVal;
                }
            }

            if (next is map<json>) {
                map<json> nextMap = <map<json>>next;
                json? orderVal = nextMap["order"];
                if (orderVal is int) {
                    nextOrder = orderVal;
                }
            }

            if (currentOrder > nextOrder) {
                sorted[j] = next;
                sorted[j + 1] = current;
            }
        }
    }

    return sorted;
}

// ============================================================================
// REMAINING HELPER FUNCTIONS - Keep existing functionality that works
// ============================================================================

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

function calcResolveTargetDate(string? date) returns string {
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
    // Strict: use only aggregated rule for the exact target date; no fallback
    sql:ParameterizedQuery q = `
        SELECT b.min_income, b.max_income, b.rate, b.fixed_amount, b.bracket_order
        FROM tax_brackets b
        JOIN tax_rules r ON r.id = b.rule_id
        WHERE r.rule_category = ${calcType}
          AND r.rule_type ILIKE 'aggregated%'
          AND r.effective_date = ${targetDate}::date
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
        return error("No aggregated brackets found for " + calcType + " on " + targetDate + ". Run aggregation first.");
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

// Build a uniform JSON response and audit record
// Generate user-friendly explanations for calculation breakdown using LLM
function generateFriendlyExplanations(Step[] breakdown, string calcType, map<json> inputs, decimal finalAmount) returns json[]|error {
    if (breakdown.length() == 0) {
        return [];
    }

    // Build context for LLM
    string calculationType = calcType == "paye" ? "PAYE Tax" :
            calcType == "income_tax" ? "Income Tax" :
                calcType == "vat" ? "VAT" : calcType;

    string inputsText = "";
    foreach var entry in inputs.entries() {
        string key = entry[0];
        json value = entry[1];
        string friendlyKey = makeFriendlyFieldName(key);
        inputsText += "- " + friendlyKey + ": " + value.toString() + "\n";
    }

    string breakdownText = "";
    foreach Step step in breakdown {
        breakdownText += "Step: " + step.name + "\n";
        breakdownText += "Formula: " + step.expression + "\n";
        breakdownText += "Substituted: " + step.substituted + "\n";
        breakdownText += "Result: " + step.result.toString() + "\n\n";
    }

    string prompt = "You are a tax calculation assistant helping users understand their " + calculationType + " calculation in Sri Lanka.\n\n" +
        "USER INPUTS:\n" + inputsText + "\n" +
        "TECHNICAL CALCULATION BREAKDOWN:\n" + breakdownText +
        "FINAL RESULT: LKR " + finalAmount.toString() + "\n\n" +
        "Please convert this technical breakdown into simple, user-friendly explanations that a regular person can easily understand. " +
        "For each calculation step, provide:\n" +
        "1. A clear title (not technical field names)\n" +
        "2. A simple explanation of what was calculated\n" +
        "3. The calculation in human-readable format\n" +
        "4. The result with proper currency formatting\n\n" +
        "For complex tax bracket calculations, explain which tax bracket applies and why. " +
        "Use simple language and avoid technical jargon. " +
        "Format the response as a JSON array with this structure:\n" +
        "[\n" +
        "  {\n" +
        "    \"title\": \"Simple step name\",\n" +
        "    \"description\": \"What this step calculates in simple terms\",\n" +
        "    \"calculation\": \"Human-readable calculation (e.g., 'Monthly salary × 12 months')\",\n" +
        "    \"amount\": \"LKR 1,800,000.00\",\n" +
        "    \"explanation\": \"Additional context if needed (optional)\"\n" +
        "  }\n" +
        "]\n\n" +
        "IMPORTANT: Return only the JSON array, no other text.";

    // Call Gemini LLM
    json|error llmResponse = callGeminiForExplanation(prompt);
    if (llmResponse is error) {
        return error("Failed to generate friendly explanations: " + llmResponse.message());
    }

    // Parse and validate response
    if (llmResponse is json[]) {
        return llmResponse;
    } else {
        log:printWarn("LLM returned unexpected format for friendly explanations");
        return [];
    }
}

// Convert technical field names to user-friendly names
function makeFriendlyFieldName(string fieldName) returns string {
    if (fieldName == "monthly_regular_profits_from_employment") {
        return "Monthly Salary";
    } else if (fieldName == "personal_relief") {
        return "Personal Relief Amount";
    } else if (fieldName == "annual_gross") {
        return "Annual Gross Income";
    } else if (fieldName == "taxable_income") {
        return "Taxable Income";
    } else if (fieldName == "tax_amount") {
        return "Tax Amount";
    } else {
        // Convert snake_case to Title Case
        string[] parts = [];
        string current = "";
        int i = 0;
        while (i < fieldName.length()) {
            string char = fieldName.substring(i, i + 1);
            if (char == "_") {
                if (current.length() > 0) {
                    parts.push(current);
                    current = "";
                }
            } else {
                current += char;
            }
            i += 1;
        }
        if (current.length() > 0) {
            parts.push(current);
        }

        string result = "";
        foreach int idx in 0 ..< parts.length() {
            if (idx > 0) {
                result += " ";
            }
            string part = parts[idx];
            if (part.length() > 0) {
                result += part.substring(0, 1).toUpperAscii() + part.substring(1).toLowerAscii();
            }
        }
        return result;
    }
}

// Call Gemini LLM for explanation generation
function callGeminiForExplanation(string prompt) returns json|error {
    json body = {
        "contents": [
            {"role": "user", "parts": [{"text": prompt}]}
        ],
        "generationConfig": {
            "temperature": 0.3, // Moderate creativity for user-friendly explanations
            "topP": 0.8,
            "topK": 40,
            "candidateCount": 1,
            "maxOutputTokens": 2048,
            "response_mime_type": "application/json"
        }
    };

    string path = "/v1beta/models/" + GEMINI_TEXT_MODEL + ":generateContent?key=" + GEMINI_API_KEY;

    http:Response|error resp = geminiTextClient->post(path, body);
    if (resp is error) {
        return error("LLM call failed: " + resp.message());
    }

    json|error payload = resp.getJsonPayload();
    if (payload is error) {
        return error("Failed to parse LLM response: " + payload.message());
    }

    if (!(payload is map<json>)) {
        return error("Invalid LLM response format");
    }

    map<json> response = <map<json>>payload;
    json? candidates = response["candidates"];
    if (!(candidates is json[])) {
        return error("No candidates in LLM response");
    }

    json[] candidateArray = <json[]>candidates;
    if (candidateArray.length() == 0) {
        return error("Empty candidates array");
    }

    json firstCandidate = candidateArray[0];
    if (!(firstCandidate is map<json>)) {
        return error("Invalid candidate format");
    }

    map<json> candidate = <map<json>>firstCandidate;
    json? content = candidate["content"];
    if (!(content is map<json>)) {
        return error("No content in candidate");
    }

    map<json> contentMap = <map<json>>content;
    json? parts = contentMap["parts"];
    if (!(parts is json[])) {
        return error("No parts in content");
    }

    json[] partsArray = <json[]>parts;
    if (partsArray.length() == 0) {
        return error("Empty parts array");
    }

    json firstPart = partsArray[0];
    if (!(firstPart is map<json>)) {
        return error("Invalid part format");
    }

    map<json> part = <map<json>>firstPart;
    json? text = part["text"];
    if (!(text is string)) {
        return error("No text in part");
    }

    string responseText = <string>text;

    // Parse the JSON response
    json|error parsed = v:fromJsonString(responseText);
    if (parsed is error) {
        return error("Failed to parse LLM JSON response: " + parsed.message());
    }

    return parsed;
}

function buildCalcResponse(json schema, string calcType, decimal finalAmount, Step[] breakdown, map<json> inputs, string execId, FormulaRef[] formulas) returns json {
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

    CalculationResult calcResultRec = {
        success: true,
        schemaId: schemaId,
        schemaVersion: schemaVersion,
        calculationType: calcType,
        result: finalAmount,
        breakdown: breakdown,
        inputs: inputs,
        formulasUsed: formulas,
        executionId: execId,
        createdAt: time:utcNow().toString()
    };

    // Best-effort audit insert
    logCalculationAudit(calcResultRec);

    // Convert breakdown to JSON for response
    json[] breakdownJson = [];
    foreach Step s in breakdown {
        breakdownJson.push({name: s.name, expression: s.expression, substituted: s.substituted, result: s.result});
    }
    json[] formulasJson = [];
    foreach FormulaRef f in formulas {
        formulasJson.push({name: f.name, expression: f.expression});
    }

    // Generate user-friendly explanations using LLM
    json[] friendlyBreakdown = [];
    json[]|error _friendlyBreakdownResult = generateFriendlyExplanations(breakdown, calcType, inputs, finalAmount);
    if (_friendlyBreakdownResult is json[]) {
        friendlyBreakdown = _friendlyBreakdownResult;
    } else if (_friendlyBreakdownResult is error) {
        log:printWarn("Failed to generate friendly explanations: " + _friendlyBreakdownResult.message());
    }

    return {
        success: true,
        schemaId: schemaId,
        schemaVersion: schemaVersion,
        calculationType: calcType,
        result: finalAmount,
        breakdown: breakdownJson,
        friendlyBreakdown: friendlyBreakdown,
        inputs: inputs,
        formulasUsed: formulasJson,
        executionId: execId,
        createdAt: time:utcNow().toString()
    };
}

// Handle expressions with parentheses like (a * b) - c
function evaluateExpressionWithParentheses(string expression, CalculationContext context) returns decimal|error {
    string expr = expression.trim();

    // Find and evaluate innermost parentheses first
    while (expr.includes("(")) {
        // Find the last opening parenthesis (innermost)
        int lastOpen = -1;
        int i = 0;
        while (i < expr.length()) {
            if (expr.substring(i, i + 1) == "(") {
                lastOpen = i;
            }
            i += 1;
        }

        if (lastOpen < 0) {
            break;
        }

        // Find the matching closing parenthesis
        int matchingClose = -1;
        i = lastOpen + 1;
        while (i < expr.length()) {
            if (expr.substring(i, i + 1) == ")") {
                matchingClose = i;
                break;
            }
            i += 1;
        }

        if (matchingClose < 0) {
            return error("Mismatched parentheses in expression: " + expression);
        }

        // Extract and evaluate the content inside parentheses
        string innerExpr = expr.substring(lastOpen + 1, matchingClose);
        decimal|error innerResult = evaluateArithmeticExpression(innerExpr, context);
        if (innerResult is error) {
            return innerResult;
        }

        // Replace the parenthetical expression with its result
        string before = expr.substring(0, lastOpen);
        string after = expr.substring(matchingClose + 1);
        expr = before + innerResult.toString() + after;
    }

    // Now evaluate the expression without parentheses
    return evaluateArithmeticExpression(expr, context);
}

// Evaluate conditional expressions (if-then-else)
function evaluateConditionalExpression(string expression, CalculationContext context) returns decimal|error {
    string expr = expression.trim();

    // Parse if-then-else chain
    // Format: if (condition) then (value) else if (condition) then (value) else (value)

    // Find the first 'if' condition
    int ifPos = findIndexAt(expr, "if ", 0);
    if (ifPos != 0) {
        return error("Invalid conditional expression: must start with 'if'");
    }

    // Parse the chain of conditions
    return parseIfThenElseChain(expr, context);
}

function parseIfThenElseChain(string expr, CalculationContext context) returns decimal|error {
    string remaining = expr.trim();

    while (remaining.startsWith("if ")) {
        // Extract condition between 'if' and 'then'
        int ifStart = findIndexAt(remaining, "if ", 0);
        int thenPos = findIndexAt(remaining, " then ", 0);
        if (thenPos <= ifStart) {
            return error("Invalid conditional: missing 'then' after 'if'");
        }

        string conditionStr = remaining.substring(ifStart + 3, thenPos).trim();

        // Evaluate condition
        boolean|error conditionResult = evaluateCondition(conditionStr, context);
        if (conditionResult is error) {
            return conditionResult;
        }

        if (conditionResult) {
            // Condition is true, evaluate the 'then' part
            int thenStart = thenPos + 6; // Skip " then "
            int elsePos = findNextElse(remaining, thenStart);

            string thenExpr;
            if (elsePos > 0) {
                thenExpr = remaining.substring(thenStart, elsePos).trim();
            } else {
                thenExpr = remaining.substring(thenStart).trim();
            }

            // Don't automatically remove parentheses - let the arithmetic evaluator handle them
            return evaluateArithmeticExpression(thenExpr, context);
        } else {
            // Condition is false, move to else part
            int elsePos = findNextElse(remaining, thenPos + 6);
            if (elsePos <= 0) {
                return error("Invalid conditional: missing 'else' part");
            }

            remaining = remaining.substring(elsePos + 5).trim(); // Skip " else "

            // Check if this is another 'if' or final value
            if (!remaining.startsWith("if ")) {
                // Final else value - don't automatically remove parentheses
                return evaluateArithmeticExpression(remaining, context);
            }
            // Continue loop for next 'else if'
        }
    }

    return error("Invalid conditional expression structure");
}

function findNextElse(string expr, int startPos) returns int {
    // Find " else " that's not part of a nested expression
    int pos = startPos;
    int parenCount = 0;

    while (pos < expr.length() - 4) {
        string char = expr.substring(pos, pos + 1);

        if (char == "(") {
            parenCount += 1;
        } else if (char == ")") {
            parenCount -= 1;
        } else if (parenCount == 0 && expr.substring(pos, pos + 5) == " else") {
            return pos;
        }

        pos += 1;
    }

    return -1;
}

function evaluateCondition(string condition, CalculationContext context) returns boolean|error {
    string cond = condition.trim();

    // Remove outer parentheses if present
    if (cond.startsWith("(") && cond.endsWith(")")) {
        cond = cond.substring(1, cond.length() - 1).trim();
    }

    // Handle comparison operators
    string[] comparisonOps = ["<=", ">=", "<", ">", "==", "!="];

    foreach string op in comparisonOps {
        int opPos = findIndexAt(cond, op, 0);
        if (opPos > 0) {
            string leftStr = cond.substring(0, opPos).trim();
            string rightStr = cond.substring(opPos + op.length()).trim();

            decimal|error leftVal = evaluateArithmeticExpression(leftStr, context);
            decimal|error rightVal = evaluateArithmeticExpression(rightStr, context);

            if (leftVal is error) {
                return leftVal;
            }
            if (rightVal is error) {
                return rightVal;
            }

            decimal left = leftVal;
            decimal right = rightVal;

            if (op == "<=") {
                return left <= right;
            } else if (op == ">=") {
                return left >= right;
            } else if (op == "<") {
                return left < right;
            } else if (op == ">") {
                return left > right;
            } else if (op == "==") {
                return left == right;
            } else if (op == "!=") {
                return left != right;
            }
        }
    }

    return error("Invalid condition: " + condition);
}

