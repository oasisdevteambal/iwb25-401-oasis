package com.oasis.document.extractor;

import java.util.Map;

/**
 * Enhanced document structure information for extracted documents using Apache
 * Tika
 * Provides comprehensive metadata about document organization and content
 */
public class DocumentStructure {
    private final String title;
    private final String[] headers;
    private final String[] sections;
    private final String author;
    private final String subject;
    private final String creationDate;
    private final String modificationDate;
    private final Map<String, String> metadata;

    // Default constructor
    public DocumentStructure() {
        this("", new String[0], new String[0], "", "", "", "", Map.of());
    }

    // Full constructor
    public DocumentStructure(String title, String[] headers, String[] sections,
            String author, String subject, String creationDate,
            String modificationDate, Map<String, String> metadata) {
        this.title = title != null ? title : "";
        this.headers = headers != null ? headers : new String[0];
        this.sections = sections != null ? sections : new String[0];
        this.author = author != null ? author : "";
        this.subject = subject != null ? subject : "";
        this.creationDate = creationDate != null ? creationDate : "";
        this.modificationDate = modificationDate != null ? modificationDate : "";
        this.metadata = metadata != null ? metadata : Map.of();
    }

    // Simplified constructor for backward compatibility
    public DocumentStructure(String title, String[] headers) {
        this(title, headers, new String[0], "", "", "", "", Map.of());
    }

    // Getter methods for Ballerina interop
    public String getTitle() {
        return title;
    }

    public String[] getHeaders() {
        return headers;
    }

    public String[] getSections() {
        return sections;
    }

    public String getAuthor() {
        return author;
    }

    public String getSubject() {
        return subject;
    }

    public String getCreationDate() {
        return creationDate;
    }

    public String getModificationDate() {
        return modificationDate;
    }

    public Map<String, String> getMetadata() {
        return metadata;
    }

    // Utility methods
    public int getHeaderCount() {
        return headers.length;
    }

    public int getSectionCount() {
        return sections.length;
    }

    public boolean hasAuthor() {
        return !author.isEmpty();
    }

    public boolean hasSubject() {
        return !subject.isEmpty();
    }

    @Override
    public String toString() {
        return String.format("DocumentStructure{title='%s', headers=%d, sections=%d, author='%s'}",
                title, headers.length, sections.length, author);
    }
}
