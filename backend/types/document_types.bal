import ballerina/time;

// Document processing types

public type Document record {
    string id;
    string filename;
    string filePath;
    string contentType;
    int fileSize;
    time:Utc uploadDate;
    boolean processed;
    ProcessingStatus processingStatus;
    int totalChunks?;
    time:Utc? processingStartedAt;
    time:Utc? processingCompletedAt;
    string? errorMessage;
    string? createdBy;
};

public enum ProcessingStatus {
    UPLOADED = "uploaded",
    PROCESSING = "processing",
    EXTRACTING = "extracting",
    CHUNKING = "chunking",
    COMPLETED = "completed",
    FAILED = "failed"
}

// Text extraction types

public type DocumentExtractionResult record {
    string extractedText;
    DocumentStructure structure;
    int totalPages;
    string[] sections;
    TableData[] tables;
    ImageData[] images;
    map<string> metadata;
};

public type DocumentStructure record {
    string title;
    string[] headers;
    string[] sections;
    int[] pageBreaks;
    map<string> metadata;
};

public type TableData record {
    string[][] cells;
    string[] headers;
    int startPage;
    int endPage;
    map<string> metadata;
};

public type ImageData record {
    string imageId;
    string format;
    int width;
    int height;
    int page;
    map<string> metadata;
};

// Tax document structure analysis

public type TaxDocumentStructure record {
    TaxDocumentType documentType;
    string[] mainSections;
    TaxSection[] sections;
    string[] definitions;
    string[] exemptions;
    TaxRate[] rates;
    CalculationRule[] calculations;
    map<string> metadata;
};

public enum TaxDocumentType {
    INCOME_TAX = "income_tax",
    VAT = "vat",
    PAYE = "paye",
    REGULATIONS = "regulations",
    CIRCULAR = "circular",
    UNKNOWN = "unknown"
}

public type TaxSection record {
    string sectionNumber;
    string title;
    string content;
    string[] subsections;
    int startPosition;
    int endPosition;
    map<string> metadata;
};

public type TaxRate record {
    string rateType;
    decimal percentage;
    string currency;
    string description;
    string? conditions;
    string? effectiveDate;
};

public type CalculationRule record {
    string ruleId;
    string title;
    string formula;
    string description;
    string[] variables;
    map<string> metadata;
};

// Processing configuration

public type ExtractionConfig record {
    boolean extractTables = true;
    boolean extractImages = false;
    boolean preserveFormatting = true;
    string language = "en";
    map<string> customSettings = {};
};
