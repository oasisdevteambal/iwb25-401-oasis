import ballerina/http;
import ballerina/lang.value as v;
import ballerina/log;
import ballerina/sql;

// Chat service: strictly scoped to our tax knowledge base (database only).
// - No user info or chat history is stored.
// - Answers only use our DB: tax_rules, tax_brackets, form_schemas, documents.
// - Rejects out-of-scope topics (politics, sports, etc.).
// - If unknown, reply transparently that we don't know and will look into it.

// NOTE:
// - httpListener and dbClient are defined at module scope in other files.
// - This file must compile without redefining those symbols.

// Feature flag to use LLM for natural language answers (facts still come only from DB)
configurable boolean USE_CHAT_LLM = true;
configurable decimal CHAT_LLM_TIMEOUT = 20.0;
const int CHAT_LLM_FACTS_CHAR_CAP = 8000;

// Feature flag to use LLM for intent detection (more flexible than hardcoded patterns)
configurable boolean USE_LLM_INTENT_DETECTION = true;

// Dedicated Gemini client for chat summarization (separate from admin flows)
http:Client geminiTextClientChat = check new (GEMINI_BASE_URL, {
    timeout: CHAT_LLM_TIMEOUT,
    retryConfig: {count: 1, interval: 1.0}
});

type ChatRequest record {
    string question;
    string? schemaType?; // one of: income_tax | paye | vat
    string? date?; // YYYY-MM-DD (optional)
    string? variable?; // optional explicit variable name for provenance queries
};

type ChatResponse record {
    boolean success;
    string intent;
    string answer;
    json? evidence?;
};

// --- Public HTTP API ---
service /api/v1/chat on httpListener {
    resource function post ask(@http:Payload json payload)
    returns json|http:BadRequest|http:InternalServerError {
        if (!(payload is map<json>)) {
            return <http:BadRequest>{body: <json>{"success": false, "error": "INVALID_PAYLOAD"}};
        }
        map<json> p = <map<json>>payload;

        string question = (p["question"] is string) ? <string>p["question"] : "";
        if (question.trim().length() == 0) {
            return <http:BadRequest>{body: <json>{"success": false, "error": "question required"}};
        }
        string calcType = inferCalcType(p["schemaType"]);
        // If not provided, infer type from the question text
        if (calcType.length() == 0) {
            string inferred = inferCalcTypeFromText(question);
            if (inferred.length() > 0) {
                calcType = inferred;
            }
        }
        string? dateOpt = p["date"] is string && (<string>p["date"]).trim().length() > 0 ? <string>p["date"] : ();
        string variable = p["variable"] is string ? <string>p["variable"] : "";

        // Extract conversation context for contextual questions
        string conversationContext = p["conversationContext"] is string ? <string>p["conversationContext"] : "";
        string conversationSummary = p["conversationSummary"] is string ? <string>p["conversationSummary"] : ""; // Scope guard: reject out-of-scope topics early
        if (isOutOfScope(question)) {
            return <json>{
                "success": false,
                "intent": "rejected_out_of_scope",
                "answer": "I can only help with Sri Lankan tax rules and our tax forms. Please ask a tax-related question."
            };
        }

        // Classify intent using LLM (more flexible) or rule-based (faster)
        string intent;
        if (USE_LLM_INTENT_DETECTION) {
            intent = detectIntentWithLLM(question, conversationContext);
        } else {
            intent = detectIntent(question);
        }

        // Resolve target date (optional); if missing, we may use latest aggregated rule where needed
        string? targetDate = dateOpt is string ? <string>dateOpt : ();

        // Route by intent
        if (intent == "calculation") {
            json|error res = handleCalculation(calcType, targetDate, question, conversationContext);
            return finalize("calculation", question, calcType, res, conversationContext, conversationSummary);
        } else if (intent == "formulas") {
            json|error res = handleFormulas(calcType, targetDate);
            return finalize("formulas", question, calcType, res, conversationContext, conversationSummary);
        } else if (intent == "rates_brackets") {
            json|error res2 = handleRatesAndBrackets(calcType, targetDate);
            return finalize("rates_brackets", question, calcType, res2, conversationContext, conversationSummary);
        } else if (intent == "variable_source") {
            json|error res3 = handleVariableProvenance(calcType, targetDate, question, variable);
            return finalize("variable_source", question, calcType, res3, conversationContext, conversationSummary);
        } else if (intent == "variables_list") {
            json|error res4 = handleVariablesList(calcType, targetDate);
            return finalize("variables_list", question, calcType, res4, conversationContext, conversationSummary);
        } else {
            // General guidance: if a type can be inferred, include type-specific facts from DB; else generic facts
            json facts;
            if (calcType.length() > 0) {
                json|error tf = buildTypeFacts(calcType);
                if (tf is json) {
                    facts = tf;
                } else {
                    facts = buildGeneralFacts(question, calcType);
                }
            } else {
                facts = buildGeneralFacts(question, calcType);
            }
            return finalize("general", question, calcType, facts, conversationContext, conversationSummary);
        }
    }
}

// --- Intent & scope ---
function detectIntent(string q) returns string {
    string s = q.toLowerAscii();

    // Check for calculation requests first (questions asking for specific tax calculations)
    if (containsAny(s, [
                "how much tax",
                "calculate my tax",
                "tax calculation",
                "calculate tax",
                "compute tax",
                "monthly income",
                "annual income",
                "yearly income",
                "salary",
                "earnings",
                "what do i pay",
                "how much do i pay",
                "how much should i pay",
                "what should i pay",
                "tax amount",
                "tax liability",
                "total tax",
                "tax due",
                "tax owed",
                "my tax is",
                "i earn",
                "i make",
                "my salary is",
                "income is",
                "if i earn",
                "if my income",
                "with income",
                "earning",
                "monthly salary"
            ])) {
        return "calculation";
    }

    // Check for contextual questions (questions about specific terms/variables)
    if (containsAny(s, [
                "what does",
                "what is",
                "what means",
                "meaning of",
                "define",
                "definition of",
                "explain",
                "what's",
                "whats",
                "tell me about",
                "describe",
                "clarify",
                "what do you mean",
                "what is meant by",
                "can you explain",
                "help me understand"
            ])) {
        return "general"; // Handle as contextual question with conversation context
    }

    // Check for formula requests
    if (containsAny(s, [
                "formula",
                "formulas",
                "equation",
                "equations",
                "calculation method",
                "how is",
                "how do you calculate",
                "how to calculate",
                "how do i calculate",
                "calculated",
                "derive",
                "computation",
                "method",
                "steps",
                "show me the formula",
                "what's the formula",
                "formula for",
                "mathematical",
                "expression",
                "calculate using",
                "step by step"
            ])) {
        return "formulas";
    }

    // Check for rates and brackets requests
    if (containsAny(s, [
                "rate",
                "rates",
                "tax rate",
                "tax rates",
                "percentage rate",
                "bracket",
                "brackets",
                "tax bracket",
                "tax brackets",
                "income bracket",
                "slab",
                "slabs",
                "tax slab",
                "income slab",
                "percentage",
                "%",
                "percent",
                "tax percentage",
                "threshold",
                "thresholds",
                "income threshold",
                "limit",
                "limits",
                "band",
                "bands",
                "tax band",
                "income band"
            ])) {
        return "rates_brackets";
    }

    // Check for variable source/provenance requests
    if (containsAny(s, ["which document", "from which document", "source", "where did you get", "provenance", "reference"]) ||
    (containsAny(s, ["variable", "field", "value", "data", "information"]) &&
    containsAny(s, ["from", "which", "source", "document", "where", "origin", "came from"]))) {
        return "variable_source";
    }

    // Check for variables list requests
    if (containsAny(s, [
                "variables",
                "fields",
                "inputs",
                "parameters",
                "values",
                "what variables",
                "list variables",
                "show variables",
                "required fields",
                "input fields",
                "what inputs",
                "what parameters",
                "what values",
                "what data",
                "required data",
                "needed information",
                "required information"
            ])) {
        return "variables_list";
    }

    return "general";
}

// LLM-based intent detection for more flexible and accurate classification
function detectIntentWithLLM(string question, string conversationContext) returns string {
    string systemPrompt = "You are an intent classifier for a Sri Lankan tax assistant. " +
        "Analyze the user's question and classify it into one of these intents: " +
        "calculation (for tax calculations with numbers), " +
        "formulas (for asking about tax formulas or equations), " +
        "rates_brackets (for tax rates or brackets), " +
        "variable_source (for document sources), " +
        "variables_list (for required variables), " +
        "general (for definitions or explanations). " +
        "Respond with ONLY the intent name.";

    string userPrompt = "Question: " + question;
    if (conversationContext.trim().length() > 0) {
        userPrompt += " Context: " + conversationContext;
    }

    // Debug: Log the prompt being sent
    log:printInfo("[intent-llm] System prompt: " + systemPrompt);
    log:printInfo("[intent-llm] User prompt: " + userPrompt);

    json body = {
        "contents": [
            {"role": "user", "parts": [{"text": systemPrompt + "\n\n" + userPrompt}]}
        ],
        "generationConfig": {
            "temperature": 0.1,
            "topP": 0.8,
            "topK": 20,
            "candidateCount": 1,
            "maxOutputTokens": 20
        }
    };

    string path = "/v1beta/models/" + GEMINI_TEXT_MODEL + ":generateContent?key=" + GEMINI_API_KEY;
    http:Response|error resp = geminiTextClientChat->post(path, body);

    if (resp is error) {
        log:printWarn("[intent-llm] LLM call failed, falling back to rule-based: " + resp.message());
        return detectIntent(question); // Fallback to hardcoded rules
    }

    json|error payload = resp.getJsonPayload();
    if (payload is error) {
        log:printWarn("[intent-llm] LLM response parse failed, falling back to rule-based: " + payload.message());
        return detectIntent(question);
    }

    // Debug: Log the full LLM response
    log:printInfo("[intent-llm] Full LLM response: " + payload.toString());

    // Extract intent from LLM response
    string detectedIntent = "";
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
                                        detectedIntent = txt.trim().toLowerAscii();
                                        break;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Validate the detected intent
    string[] validIntents = ["calculation", "formulas", "rates_brackets", "variable_source", "variables_list", "general"];
    foreach string validIntent in validIntents {
        if (detectedIntent == validIntent) {
            log:printInfo("[intent-llm] Detected intent: " + detectedIntent);
            return detectedIntent;
        }
    }

    // If LLM returned invalid intent, fallback to rule-based
    log:printWarn("[intent-llm] Invalid intent '" + detectedIntent + "', falling back to rule-based");
    return detectIntent(question);
}

function isOutOfScope(string q) returns boolean {
    string s = q.toLowerAscii();
    // If any disallowed topic appears, reject. We do not use web data or non-tax topics.
    string[] disallowed = ["politic", "election", "president", "minister", "cricket", "football", "sports", "movie", "series", "weather", "traffic", "stock market", "music", "celebrity"];
    foreach string k in disallowed {
        if (s.indexOf(k) is int) {
            return true;
        }
    }
    return false;
}

function containsAny(string s, string[] keys) returns boolean {
    foreach string k in keys {
        if (s.indexOf(k) is int) {
            return true;
        }
    }
    return false;
}

function inferCalcType(json? schemaType) returns string {
    if (schemaType is string) {
        string t = schemaType.toLowerAscii();
        if (t == "income_tax" || t == "paye" || t == "vat") {
            return t;
        }
    }
    return ""; // unknown / not constrained
}

// Infer tax type from free-form question text
function inferCalcTypeFromText(string q) returns string {
    string s = q.toLowerAscii();
    if (s.indexOf("paye") is int) {
        return "paye";
    }
    if (s.indexOf("income tax") is int || s.indexOf("income-tax") is int || s.indexOf("personal income") is int) {
        return "income_tax";
    }
    if (s.indexOf("vat") is int || s.indexOf("value added tax") is int) {
        return "vat";
    }
    return "";
}

// --- Handlers ---
function handleFormulas(string calcType, string? dateOpt) returns json|error {
    // Prefer active form schema for formulas; fallback to aggregated rule_data.formulas
    string t = calcType;
    if (!isSupportedTypeOrEmpty(t)) {
        return error("Unsupported or missing schemaType. Provide one of income_tax, paye, vat.");
    }
    json|error schemaJ = fetchActiveFormSchemaMaybe(t);
    if (schemaJ is json) {
        map<json> out = {"answer": "Here are the detailed formulas for " + calcType + " calculations from our active form schema.", "source": "form_schemas.active"};
        if (schemaJ is map<json>) {
            map<json> sm = <map<json>>schemaJ;
            json? rules = sm["calculationRules"];
            if (rules is json[]) {
                out["formulas"] = rules;
                // Include formula details in the answer for LLM processing
                out["formula_details"] = buildFormulaDetailsText(<json[]>rules);
                return <json>out;
            }
            json? alt = sm["schema_data"];
            if (alt is map<json>) {
                json? r2 = (<map<json>>alt)["calculationRules"] ?: (<map<json>>alt)["calculation_rules"];
                if (r2 is json[]) {
                    out["formulas"] = r2;
                    out["formula_details"] = buildFormulaDetailsText(<json[]>r2);
                    return <json>out;
                }
            }
        }
    }
    // Try aggregated rule
    json|error agg = fetchAggregatedRule(t, dateOpt);
    if (agg is json) {
        map<json> am = <map<json>>agg;
        json? rd = am["rule_data"];
        if (rd is map<json>) {
            json? f = (<map<json>>rd)["formulas"];
            if (f is json[]) {
                map<json> out = {"answer": "Here are the detailed formulas for " + calcType + " calculations from our aggregated tax rules.", "source": "tax_rules.aggregated"};
                out["formulas"] = f;
                out["formula_details"] = buildFormulaDetailsText(<json[]>f);
                return <json>out;
            }
        }
    }
    return error("No formulas found in our current knowledge base.");
}

function handleRatesAndBrackets(string calcType, string? dateOpt) returns json|error {
    string t = calcType;
    if (!isSupportedTypeOrEmpty(t)) {
        return error("Unsupported or missing schemaType. Provide one of income_tax, paye, vat.");
    }
    json|error agg = fetchAggregatedRule(t, dateOpt);
    if (agg is error) {
        return error(agg.message());
    }
    map<json> a = <map<json>>agg;
    string ruleId = <string>a["id"];
    // Fetch brackets if any
    json[] brackets = [];
    stream<record {}, sql:Error?> rs = dbClient->query(`
		SELECT min_income, max_income, rate, fixed_amount, bracket_order
		FROM tax_brackets
		WHERE rule_id = ${ruleId}
		ORDER BY bracket_order`);
    error? e = rs.forEach(function(record {} row) {
        map<json> item = {};
        var mi = row["min_income"];
        item["min_income"] = toJsonNum(mi);
        var ma = row["max_income"];
        item["max_income"] = toJsonNum(ma);
        var rt = row["rate"];
        item["rate_fraction"] = toJsonNum(rt);
        var fx = row["fixed_amount"];
        item["fixed_amount"] = toJsonNum(fx);
        var bo = row["bracket_order"];
        item["order"] = toJsonNum(bo);
        brackets.push(<json>item);
    });
    if (e is error) {
        return error("Failed to read brackets: " + e.message());
    }
    if (brackets.length() == 0) {
        // Try to read embedded brackets from rule_data if present
        json? rd = a["rule_data"];
        if (rd is map<json>) {
            json? bj = (<map<json>>rd)["brackets"];
            if (bj is json[]) {
                return <json>{"answer": "Here are the current brackets (from aggregated rule_data).", "brackets": bj, "source": "tax_rules.rule_data"};
            }
        }
        return <json>{"answer": "No bracket schedule stored for this tax type/date in our system.", "brackets": [], "source": "tax_rules"};
    }
    return <json>{"answer": "Here are the current brackets we use.", "brackets": brackets, "source": "tax_brackets"};
}

function handleVariableProvenance(string calcType, string? dateOpt, string question, string explicitVar) returns json|error {
    string t = calcType;
    if (!isSupportedTypeOrEmpty(t)) {
        return error("Unsupported or missing schemaType. Provide one of income_tax, paye, vat.");
    }
    json|error agg = fetchAggregatedRule(t, dateOpt);
    if (agg is error) {
        return error(agg.message());
    }
    map<json> a = <map<json>>agg;
    string aggRuleId = <string>a["id"];
    json? rd = a["rule_data"];
    if (!(rd is map<json>)) {
        return error("No rule_data found for aggregated rule");
    }
    map<json> rdm = <map<json>>rd;
    // Determine the variable to look up
    string varName = selectVariableName(rdm, explicitVar, question);
    if (varName.length() == 0) {
        return error("Could not determine the variable name from your question.");
    }
    // Lookup field_metadata[varName].source_refs[*].ruleId
    json? fmJ = rdm["field_metadata"];
    if (!(fmJ is map<json>)) {
        return error("No field metadata found in aggregated rule to trace sources.");
    }
    json? vJ = (<map<json>>fmJ)[varName];
    if (!(vJ is map<json>)) {
        return error("Variable not found in field metadata: " + varName);
    }
    json? sref = (<map<json>>vJ)["source_refs"];
    string[] evidenceRuleIds = [];
    if (sref is json[]) {
        foreach json sr in sref {
            if (sr is map<json>) {
                var r = sr["ruleId"] ?: ();
                if (r is string && r.length() > 0) {
                    evidenceRuleIds.push(r);
                }
            }
        }
    }
    // Map evidence rule IDs to documents
    json[] sources = [];
    if (evidenceRuleIds.length() > 0) {
        foreach string evId in evidenceRuleIds {
            string docId = "";
            string fileName = "";
            // Get document for evidence rule
            stream<record {}, sql:Error?> r1 = dbClient->query(`SELECT document_source_id FROM tax_rules WHERE id = ${evId} LIMIT 1`);
            error? e1 = r1.forEach(function(record {} row) {
                var d = row["document_source_id"];
                docId = d is string ? <string>d : "";
            });
            if (!(e1 is ())) {
            }
            if (docId.length() > 0) {
                stream<record {}, sql:Error?> r2 = dbClient->query(`SELECT id, filename FROM documents WHERE id = ${docId} LIMIT 1`);
                error? e2 = r2.forEach(function(record {} row) {
                    fileName = <string>row["filename"];
                });
                if (!(e2 is ())) {
                }
            }
            map<json> s = {"evidence_rule_id": evId, "document_id": docId, "filename": fileName};
            sources.push(<json>s);
        }
    } else {
        // Fallback to all provenance for this aggregated rule
        stream<record {}, sql:Error?> r3 = dbClient->query(`
			SELECT d.id AS document_id, d.filename, ars.evidence_rule_id
			FROM aggregated_rule_sources ars
			JOIN tax_rules ev ON ev.id = ars.evidence_rule_id
			LEFT JOIN documents d ON d.id = ev.document_source_id
			WHERE ars.aggregated_rule_id = ${aggRuleId}
		`);
        error? e3 = r3.forEach(function(record {} row) {
            map<json> s = {};
            s["evidence_rule_id"] = <json>row["evidence_rule_id"];
            s["document_id"] = <json>row["document_id"];
            s["filename"] = <json>row["filename"];
            sources.push(<json>s);
        });
        if (e3 is error) {
            log:printWarn("Provenance fallback failed: " + e3.message());
        }
    }

    if (sources.length() == 0) {
        return error("No source documents recorded for variable '" + varName + "' in our system.");
    }
    return <json>{"answer": "Provenance for variable '" + varName + "'", "variable": varName, "sources": sources, "aggregated_rule_id": aggRuleId};
}

function handleVariablesList(string calcType, string? dateOpt) returns json|error {
    string t = calcType;
    if (!isSupportedTypeOrEmpty(t)) {
        return error("Unsupported or missing schemaType. Provide one of income_tax, paye, vat.");
    }
    json|error schemaJ = fetchActiveFormSchemaMaybe(t);
    if (schemaJ is json) {
        json? req = (schemaJ is map<json>) ? (<map<json>>schemaJ)["requiredVariables"] : ();
        if (req is json[]) {
            return <json>{"answer": "Here are key input variables for the form.", "variables": req};
        }
        json? schemaData = (schemaJ is map<json>) ? (<map<json>>schemaJ)["schema_data"] : ();
        if (schemaData is map<json>) {
            json? req2 = (<map<json>>schemaData)["requiredVariables"] ?: (<map<json>>schemaData)["required_variables"];
            if (req2 is json[]) {
                return <json>{"answer": "Here are key input variables for the form.", "variables": req2};
            }
        }
    }
    // Fallback to aggregated rule_data.field_metadata keys
    json|error agg = fetchAggregatedRule(t, dateOpt);
    if (agg is json) {
        map<json> a = <map<json>>agg;
        json? rd = a["rule_data"];
        if (rd is map<json>) {
            json? fm = (<map<json>>rd)["field_metadata"];
            if (fm is map<json>) {
                string[] keys = [];
                foreach var entry in (<map<json>>fm).entries() {
                    keys.push(entry[0]);
                }
                return <json>{"answer": "Variables inferred from aggregated rule.", "variables": keys};
            }
        }
    }
    return error("Couldn't list variables for this tax type from our knowledge base.");
}

// Handle calculation requests (e.g., "how much tax do I pay with income X")
function handleCalculation(string calcType, string? dateOpt, string question, string conversationContext) returns json|error {
    string t = calcType;
    if (!isSupportedTypeOrEmpty(t)) {
        return error("Unsupported or missing schemaType. Provide one of income_tax, paye, vat.");
    }

    // Get both formulas and tax brackets for calculation
    json|error formulasResult = handleFormulas(t, dateOpt);
    json|error bracketsResult = handleRatesAndBrackets(t, dateOpt);

    map<json> calcData = {
        "answer": "Here's the calculation data for " + t + " tax calculation",
        "calculation_type": "tax_calculation",
        "question": question,
        "conversation_context": conversationContext
    };

    // Include formulas if available
    if (formulasResult is json && formulasResult is map<json>) {
        map<json> fr = <map<json>>formulasResult;
        calcData["formulas"] = fr["formulas"] ?: [];
        calcData["formula_details"] = fr["formula_details"] ?: "";
        calcData["formulas_source"] = fr["source"] ?: "";
    }

    // Include tax brackets if available  
    if (bracketsResult is json && bracketsResult is map<json>) {
        map<json> br = <map<json>>bracketsResult;
        calcData["tax_brackets"] = br["tax_brackets"] ?: [];
        calcData["brackets_details"] = br["brackets_details"] ?: "";
        calcData["brackets_source"] = br["source"] ?: "";
    }

    return <json>calcData;
}

// --- DB helpers ---
function fetchActiveFormSchemaMaybe(string calcType) returns json|error {
    if (calcType.length() == 0) {
        return error("schemaType required to fetch formulas/variables.");
    }
    stream<record {}, sql:Error?> rs = dbClient->query(`
		SELECT id, version, schema_data
		FROM form_schemas
		WHERE schema_type = ${calcType} AND is_active = true
		ORDER BY version DESC
		LIMIT 1`);
    json out = <json>{};
    int count = 0;
    error? e = rs.forEach(function(record {} row) {
        count = 1;
        map<json> m = {};
        m["id"] = <json>row["id"];
        m["version"] = <json>row["version"];
        m["schema_data"] = <json>row["schema_data"];
        out = <json>m;
    });
    if (e is error) {
        return error("Failed to fetch active schema: " + e.message());
    }
    if (count == 0) {
        return error("No active form schema found for " + calcType);
    }
    // Unwrap: schema_data may be stored as json or text; prefer returning the object if parsable.
    json sd = (<map<json>>out)["schema_data"] ?: <json>{};
    if (sd is string) {
        json|error parsed = v:fromJsonString(sd);
        if (parsed is json) {
            sd = parsed;
        }
    }
    return sd;
}

function fetchAggregatedRule(string calcType, string? dateOpt) returns json|error {
    if (calcType.length() == 0) {
        return error("schemaType required to fetch aggregated rules.");
    }
    sql:ParameterizedQuery q;
    if (dateOpt is string) {
        q = `SELECT id, rule_data, effective_date, title, description
			 FROM tax_rules
			 WHERE rule_category = ${calcType}
			   AND rule_type ILIKE 'aggregated%'
			   AND effective_date = ${<string>dateOpt}::date
			 ORDER BY updated_at DESC NULLS LAST, created_at DESC
			 LIMIT 1`;
    } else {
        q = `SELECT id, rule_data, effective_date, title, description
			 FROM tax_rules
			 WHERE rule_category = ${calcType}
			   AND rule_type ILIKE 'aggregated%'
			 ORDER BY effective_date DESC NULLS LAST, updated_at DESC NULLS LAST, created_at DESC
			 LIMIT 1`;
    }
    json out = <json>{};
    int count = 0;
    stream<record {}, sql:Error?> rs = dbClient->query(q);
    error? e = rs.forEach(function(record {} row) {
        count = 1;
        string id = row["id"] is string ? <string>row["id"] : "";
        string? eff = row["effective_date"] is string ? <string>row["effective_date"] : ();
        string title = row["title"] is string ? <string>row["title"] : "";
        string? desc = row["description"] is string ? <string>row["description"] : ();
        json rdVal = <json>{};
        var rawRd = row["rule_data"];
        if (rawRd is string) {
            json|error pj = v:fromJsonString(rawRd);
            if (pj is json) {
                rdVal = pj;
            }
        } else if (rawRd is map<json> || rawRd is json) {
            rdVal = <json>rawRd;
        }
        map<json> m = {};
        m["id"] = id;
        if (eff is string) {
            m["effective_date"] = eff;
        }
        m["title"] = title;
        if (desc is string) {
            m["description"] = desc;
        }
        m["rule_data"] = rdVal;
        out = <json>m;
    });
    if (e is error) {
        return error("Failed to fetch aggregated rule: " + e.message());
    }
    if (count == 0) {
        return error("No aggregated rule found. Run aggregation for this type/date first.");
    }
    // Ensure rule_data is JSON object
    // rdVal already normalized in the query loop above
    return out;
}

// --- Utilities ---
function isSupportedTypeOrEmpty(string t) returns boolean {
    if (t.length() == 0) {
        return true;
    }
    return t == "income_tax" || t == "paye" || t == "vat";
}

function finalize(string intent, string question, string calcType, json|error result, string conversationContext, string conversationSummary)
returns json|http:InternalServerError {
    if (result is error) {
        // Transparent fallback per requirements
        return <http:InternalServerError>{
            body: <json>{
                "success": false,
                "intent": intent,
                "answer": "Sorry, we don't know that yet. We'll look into it.",
                "details": result.message()
            }
        };
    }
    // Default answer from deterministic handler
    string baseAnswer = (<map<json>>result)["answer"] is string ? <string>(<map<json>>result)["answer"] : "";
    string finalAnswer = baseAnswer;

    if (USE_CHAT_LLM) {
        // Build grounded facts package for LLM; cap size
        map<json> facts = {"intent": intent};
        if (calcType.length() > 0) {
            facts["schemaType"] = calcType;
        }
        facts["data"] = result;
        string factsStr = v:toJsonString(<json>facts);
        if (factsStr.length() > CHAT_LLM_FACTS_CHAR_CAP) {
            factsStr = factsStr.substring(0, CHAT_LLM_FACTS_CHAR_CAP);
        }
        string|error llmAns = runChatAnswerLLM(intent, question, calcType, factsStr, conversationContext, conversationSummary);
        if (llmAns is string && llmAns.trim().length() > 0) {
            finalAnswer = llmAns.trim();
        } else if (llmAns is error) {
            // Non-fatal: keep base answer and log
            log:printWarn("[chat-llm] fallback to base answer: " + llmAns.message());
        }
    }

    return <json>{"success": true, "intent": intent, "answer": finalAnswer, "evidence": result};
}

// LLM summarization with strict grounding to provided facts only
function runChatAnswerLLM(string intent, string question, string calcType, string factsJson, string conversationContext, string conversationSummary) returns string|error {
    string sys = "You are a friendly and knowledgeable Sri Lankan tax expert assistant. Your goal is to provide helpful, clear, and engaging explanations about tax matters. Be conversational and educational, but ONLY use the provided Facts - never invent or use external knowledge. If the facts are insufficient to give a good answer, reply exactly: 'Sorry, we don't know that yet. We'll look into it.'";

    string styleGuide = "Style Guidelines:\n- Be conversational and friendly, not robotic\n- Explain concepts clearly as if talking to someone learning about taxes\n- Use examples when formulas or brackets are available\n- Structure longer answers with clear sections\n- Always cite document sources when available\n- Make tax concepts accessible and understandable\n- Be enthusiastic about helping with tax questions\n- Use natural language, avoid technical jargon dumps\n\nFormatting Guidelines:\n- Use relevant emojis to make responses engaging (💰 for money, 📊 for rates, 📋 for forms, ✅ for checkmarks, etc.)\n- Use bullet points (•) for lists and key points\n- Use numbered lists (1., 2., 3.) for step-by-step processes\n- Use **bold text** for important terms or concepts\n- Use line breaks to separate sections clearly\n- For tax brackets, format them clearly with ranges and rates\n- For formulas, present them in a readable format\n- Add section headers when explaining complex topics";

    // Build context-aware instruction
    string contextSection = "";
    if (conversationContext.trim().length() > 0 || conversationSummary.trim().length() > 0) {
        contextSection = "\n\n--- CONVERSATION CONTEXT ---\n";
        if (conversationSummary.trim().length() > 0) {
            contextSection += "Conversation Summary: " + conversationSummary + "\n";
        }
        if (conversationContext.trim().length() > 0) {
            contextSection += "Recent Messages:\n" + conversationContext + "\n";
        }
        contextSection += "IMPORTANT: Use this conversation context to answer the current question. You can and should reference information from previous messages in this conversation, including the user's name if they mentioned it earlier. For references like 'the formula', 'pct', 'it', 'that', 'my name', etc., look for the relevant information in the conversation history above.\n";
    }

    string instr = "User asked: \"" + question + "\"\nIntent: " + intent + (calcType.length() > 0 ? ("\nTax Type: " + calcType) : "") + contextSection + "\n\nIMPORTANT: If the conversation context above contains the user's name or any personal references, you MUST use that information when answering. Do not claim you don't have access to information that is clearly provided in the conversation context.\n\nAvailable Facts:\n" + factsJson + "\n\nProvide a helpful, engaging response using ONLY these facts and the conversation context. Make it conversational and educational with proper formatting.\n\nFor calculation questions (like 'how much tax do I pay with income X'):\n• Extract the income amount from the user's question\n• Use the provided formulas to walk through the calculation step-by-step\n• Apply the tax brackets if available to determine the tax rate\n• Show the actual calculation with numbers\n• Explain each step clearly\n• If personal_relief or other constants are missing, explain what information is needed\n• Make reasonable assumptions only if explicitly stated in the facts\n\nFor contextual questions about terms or variables (like 'what does pct mean'):\n• Use the conversation context to understand what the user is referring to\n• Explain the term based on common mathematical/tax notation\n• Reference the specific context where it appeared\n• For 'pct', explain it typically means 'percentage' and converts rates to decimal form\n\nFor formula questions, explain each formula clearly with:\n• What it calculates\n• The mathematical expression  \n• What each variable means\n• A simple example if possible\n\nExample formula formatting:\n## 🧮 PAYE Calculation Formulas\n\n### 1. **Taxable Income** 📊\n```\nTaxable Income = 12 * monthly_regular_profits_from_employment - personal_relief\n```\nThis calculates your annual taxable income by:\n• Taking your monthly salary and multiplying by 12\n• Subtracting your personal relief allowance\n\nIf facts are insufficient for a good answer, use the exact fallback phrase above.";

    json body = {
        "contents": [
            {"role": "user", "parts": [{"text": sys + "\n\n" + styleGuide + "\n\n" + instr}]}
        ],
        "generationConfig": {
            "temperature": 0.4,
            "topP": 0.9,
            "topK": 40,
            "candidateCount": 1,
            "maxOutputTokens": 1000
        }
    };
    string path = "/v1beta/models/" + GEMINI_TEXT_MODEL + ":generateContent?key=" + GEMINI_API_KEY;
    http:Response|error resp = geminiTextClientChat->post(path, body);
    if (resp is error) {
        return error("LLM call failed: " + resp.message());
    }
    json|error payload = resp.getJsonPayload();
    if (payload is error) {
        return error("LLM response parse failed: " + payload.message());
    }
    // Extract text from candidates
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

// Build grounded facts for general/guidance questions without using external data
function buildGeneralFacts(string question, string calcType) returns json {
    map<json> facts = {};
    facts["answer"] = "This service helps you with Sri Lankan tax questions strictly from our database. You can ask about formulas, rates/brackets, and where a variable came from (source documents).";
    facts["scope"] = "Only Sri Lankan tax rules and our stored forms/rules. No web data. No out-of-scope topics.";
    facts["supportedTypes"] = ["income_tax", "paye", "vat"];
    facts["capabilities"] = [
        "Explain formulas used in our tax forms",
        "List or explain tax rates/brackets we use",
        "Show provenance: which document supports a variable",
        "List required input variables for a form"
    ];
    facts["limitations"] = [
        "If the database lacks information, the answer will say we don't know",
        "We maintain conversation context during your session for contextual questions",
        "We reject out-of-scope topics (politics, sports, etc.)"
    ];
    if (calcType.length() > 0) {
        facts["schemaType"] = calcType;
    }
    facts["question"] = question;
    return <json>facts;
}

// Build grounded facts for a detected schemaType using aggregated rules in DB
function buildTypeFacts(string calcType) returns json|error {
    json|error agg = fetchAggregatedRule(calcType, ());
    if (agg is error) {
        return error(agg.message());
    }
    map<json> a = <map<json>>agg;
    json? rd = a["rule_data"];
    map<json> facts = {};
    facts["schemaType"] = calcType;
    facts["answer"] = "Here is what we currently have in our knowledge base for this tax type.";
    if (a["title"] is string) {
        facts["rule_title"] = <string>a["title"];
    }
    if (a["description"] is string) {
        facts["rule_description"] = <string>a["description"];
    }
    if (rd is map<json>) {
        var f = (<map<json>>rd)["formulas"] ?: ();
        if (f is json[]) {
            facts["formulas_count"] = f.length();
        }
        var b = (<map<json>>rd)["brackets"] ?: ();
        if (b is json[]) {
            facts["has_brackets"] = b.length() > 0;
        }
        var fm = (<map<json>>rd)["field_metadata"] ?: ();
        if (fm is map<json>) {
            facts["variables_count"] = (<map<json>>fm).length();
        }
    }
    facts["source"] = "tax_rules.aggregated";
    facts["supportedTypes"] = ["income_tax", "paye", "vat"];
    facts["capabilities"] = [
        "Explain formulas used in our tax forms",
        "List or explain tax rates/brackets we use",
        "Show provenance: which document supports a variable",
        "List required input variables for a form"
    ];
    return <json>facts;
}

function selectVariableName(map<json> ruleData, string explicitVar, string question) returns string {
    if (explicitVar.trim().length() > 0) {
        return normalizeVar(explicitVar);
    }
    // Try to infer from field_metadata keys by fuzzy contains
    json? fmJ = ruleData["field_metadata"];
    if (!(fmJ is map<json>)) {
        return "";
    }
    string qn = normalizeVar(question);
    string best = "";
    int bestScore = -1;
    foreach var entry in (<map<json>>fmJ).entries() {
        string k = entry[0];
        string kn = normalizeVar(k);
        int sc = similarityScore(qn, kn);
        if (sc > bestScore) {
            bestScore = sc;
            best = k;
        }
    }
    // Require a minimal score to avoid random picks
    if (bestScore < 2) {
        return "";
    }
    return best;
}

function normalizeVar(string s) returns string {
    string t = s.toLowerAscii();
    t = replaceAll(t, "\"", "");
    t = replaceAll(t, "'", "");
    t = replaceAll(t, "-", "_");
    t = replaceAll(t, " ", "_");
    return t;
}

function similarityScore(string a, string b) returns int {
    // Simple token overlap score
    string[] ta = splitByNonAlnum(a);
    string[] tb = splitByNonAlnum(b);
    int score = 0;
    foreach string x in ta {
        foreach string y in tb {
            if (x.length() > 2 && x == y) {
                score += 1;
            }
        }
    }
    return score;
}

function splitByNonAlnum(string s) returns string[] {
    string[] out = [];
    string cur = "";
    int i = 0;
    int n = s.length();
    while (i < n) {
        string ch = s.substring(i, i + 1);
        boolean isAl = (ch >= "a" && ch <= "z") || (ch >= "0" && ch <= "9") || ch == "_";
        if (isAl) {
            cur += ch;
        } else {
            if (cur.length() > 0) {
                out.push(cur);
                cur = "";
            }
        }
        i += 1;
    }
    if (cur.length() > 0) {
        out.push(cur);
    }
    return out;
}

function replaceAll(string s, string what, string with) returns string {
    if (what.length() == 0) {
        return s;
    }
    string out = "";
    int i = 0;
    int n = s.length();
    int wl = what.length();
    while (i < n) {
        boolean m = false;
        if (i + wl <= n) {
            string seg = s.substring(i, i + wl);
            if (seg == what) {
                m = true;
            }
        }
        if (m) {
            out += with;
            i += wl;
        } else {
            out += s.substring(i, i + 1);
            i += 1;
        }
    }
    return out;
}

// Convert SQL anydata numeric to json (number) or return () if null/unsupported
function toJsonNum(anydata v) returns json {
    if (v is ()) {
        return ();
    }
    if (v is int) {
        return <json>v;
    }
    if (v is decimal) {
        return <json>v;
    }
    if (v is float) {
        return <json>v;
    }
    if (v is string) {
        // try parse number-ish strings
        int|error ii = int:fromString(v);
        if (ii is int) {
            return <json>ii;
        }
        decimal|error dd = decimal:fromString(v);
        if (dd is decimal) {
            return <json>dd;
        }
    }
    return ();
}

// Helper function to build detailed formula text for LLM processing
function buildFormulaDetailsText(json[] formulas) returns string {
    string details = "";
    foreach var formula in formulas {
        if (formula is map<json>) {
            map<json> f = <map<json>>formula;
            string name = f["name"] is string ? <string>f["name"] : (f["id"] is string ? <string>f["id"] : "Formula");
            string expr = f["expression"] is string ? <string>f["expression"] : (f["formula"] is string ? <string>f["formula"] : "");
            int ord = f["order"] is int ? <int>f["order"] : 0;

            if (details.length() > 0) {
                details += "\n";
            }
            details += ord.toString() + ". " + name + ": " + expr;
        }
    }
    return details;
}

