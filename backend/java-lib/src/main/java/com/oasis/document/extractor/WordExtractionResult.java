package com.oasis.document.extractor;

import java.util.List;
import java.util.Map;

/**
 * Word extraction result
 */
public class WordExtractionResult {
    public final String extractedText;
    public final int estimatedPages;
    public final WordDocumentStructure structure;
    public final List<WordParagraphInfo> paragraphs;
    public final Map<String, String> metadata;
    public final boolean success;
    public final String message;

    public WordExtractionResult(String extractedText, int estimatedPages,
            WordDocumentStructure structure, List<WordParagraphInfo> paragraphs,
            Map<String, String> metadata, boolean success, String message) {
        this.extractedText = extractedText;
        this.estimatedPages = estimatedPages;
        this.structure = structure;
        this.paragraphs = paragraphs;
        this.metadata = metadata;
        this.success = success;
        this.message = message;
    }

    @Override
    public String toString() {
        return String.format("WordExtractionResult{success=%s, pages=%d, textLength=%d}",
                success, estimatedPages, extractedText.length());
    }
}

/**
 * Word document structure
 */
class WordDocumentStructure {
    public final String title;
    public final String[] headers;
    public final String[] sections;

    public WordDocumentStructure(String title, String[] headers, String[] sections) {
        this.title = title;
        this.headers = headers;
        this.sections = sections;
    }
}

/**
 * Word paragraph information
 */
class WordParagraphInfo {
    public final int index;
    public final String text;
    public final String style;
    public final int runCount;

    public WordParagraphInfo(int index, String text, String style, int runCount) {
        this.index = index;
        this.text = text;
        this.style = style;
        this.runCount = runCount;
    }
}
