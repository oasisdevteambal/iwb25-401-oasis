package com.oasis.document.extractor;

/**
 * Information about the Tika extraction process
 * Contains technical details about how the document was processed
 */
public class TikaExtractionInfo {
    private final String parsedBy;
    private final String mediaType;
    private final boolean hasImages;
    private final boolean hasTables;
    private final int estimatedWordCount;
    private final String encoding;

    // Default constructor
    public TikaExtractionInfo() {
        this("Unknown", "application/octet-stream", false, false, 0, "UTF-8");
    }

    // Full constructor
    public TikaExtractionInfo(String parsedBy, String mediaType, boolean hasImages,
            boolean hasTables, int estimatedWordCount, String encoding) {
        this.parsedBy = parsedBy != null ? parsedBy : "Unknown";
        this.mediaType = mediaType != null ? mediaType : "application/octet-stream";
        this.hasImages = hasImages;
        this.hasTables = hasTables;
        this.estimatedWordCount = Math.max(0, estimatedWordCount);
        this.encoding = encoding != null ? encoding : "UTF-8";
    }

    // Getter methods for Ballerina interop
    public String getParsedBy() {
        return parsedBy;
    }

    public String getMediaType() {
        return mediaType;
    }

    public boolean hasImages() {
        return hasImages;
    }

    public boolean hasTables() {
        return hasTables;
    }

    public int getEstimatedWordCount() {
        return estimatedWordCount;
    }

    public String getEncoding() {
        return encoding;
    }

    // Utility methods
    public boolean isPdf() {
        return mediaType.contains("pdf");
    }

    public boolean isWordDocument() {
        return mediaType.contains("word") || mediaType.contains("msword");
    }

    public boolean isExcelDocument() {
        return mediaType.contains("excel") || mediaType.contains("spreadsheet");
    }

    public boolean isPowerPointDocument() {
        return mediaType.contains("powerpoint") || mediaType.contains("presentation");
    }

    @Override
    public String toString() {
        return String.format(
                "TikaExtractionInfo{parsedBy='%s', mediaType='%s', wordCount=%d, hasImages=%s, hasTables=%s}",
                parsedBy, mediaType, estimatedWordCount, hasImages, hasTables);
    }
}
