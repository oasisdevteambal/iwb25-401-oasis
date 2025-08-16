// Module-wide types for the tax calculation API

public type CalculationRequest record {
    string schemaType;
    int? schemaVersion?;
    string? date?;
    json data;
    string? executionId?;
};

public type Step record {
    string name;
    string expression;
    string substituted;
    decimal result;
};

public type FormulaRef record {
    string name;
    string expression;
};

public type CalculationResult record {
    boolean success;
    string schemaId;
    int schemaVersion;
    string calculationType;
    decimal result;
    Step[] breakdown;
    map<json> inputs;
    FormulaRef[] formulasUsed;
    string executionId;
    string createdAt;
};

public type ErrorResponse record {
    boolean success;
    string code;
    string message;
    json? details?;
};
