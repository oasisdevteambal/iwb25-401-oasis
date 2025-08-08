package com.oasis.document.extractor;

import java.util.List;
import java.util.Map;

/**
 * Comprehensive result object for document extraction operations using Apache
 * Tika
 * Optimized for Ballerina Java interop with enhanced metadata and structural
 * information
 */
public class DocumentExtractionResult {
    private final String extractedText;
    private final DocumentStructure structure;
    private final String contentType;
    private final String[] detectedLanguages;
    private final TableData[] tables;
    private final ImageData[] images;
    private final Map<String, String> metadata;
    private final TikaExtractionInfo extractionInfo;
    private final boolean extractionSuccessful;
    private final String errorMessage;

    // Constructor for successful extraction
    public DocumentExtractionResult(String extractedText, DocumentStructure structure,
            String contentType, String[] detectedLanguages,
            TableData[] tables, ImageData[] images,
            Map<String, String> metadata, TikaExtractionInfo extractionInfo) {
        this.extractedText = extractedText != null ? extractedText : "";
        this.structure = structure != null ? structure : new DocumentStructure();
        this.contentType = contentType != null ? contentType : "application/octet-stream";
        this.detectedLanguages = detectedLanguages != null ? detectedLanguages : new String[0];
        this.tables = tables != null ? tables : new TableData[0];
        this.images = images != null ? images : new ImageData[0];
        this.metadata = metadata;
        this.extractionInfo = extractionInfo != null ? extractionInfo : new TikaExtractionInfo();
        // Consider extraction successful if Tika ran without throwing exceptions
        // Empty text doesn't mean failure - could be image-based PDF
        this.extractionSuccessful = true;
        this.errorMessage = null;
    }

    // Constructor for failed extraction
    public DocumentExtractionResult(String errorMessage) {
        this.extractedText = "";
        this.structure = new DocumentStructure();
        this.contentType = "application/octet-stream";
        this.detectedLanguages = new String[0];
        this.tables = new TableData[0];
        this.images = new ImageData[0];
        this.metadata = Map.of();
        this.extractionInfo = new TikaExtractionInfo();
        this.extractionSuccessful = false;
        this.errorMessage = errorMessage;
    }

    // Getter methods for Ballerina interop
    public String getExtractedText() {
        return extractedText;
    }

    public DocumentStructure getStructure() {
        return structure;
    }

    public String getContentType() {
        return contentType;
    }

    public String[] getDetectedLanguages() {
        return detectedLanguages;
    }

    public TableData[] getTables() {
        return tables;
    }

    public ImageData[] getImages() {
        return images;
    }

    public Map<String, String> getMetadata() {
        return metadata;
    }

    public TikaExtractionInfo getExtractionInfo() {
        return extractionInfo;
    }

    public boolean isExtractionSuccessful() {
        return extractionSuccessful;
    }

    public String getErrorMessage() {
        return errorMessage;
    }

    @Override
    public String toString() {
        return String.format(
                "DocumentExtractionResult{success=%s, contentType='%s', textLength=%d, tables=%d, images=%d}",
                extractionSuccessful, contentType, extractedText.length(), tables.length, images.length);
    }
}
