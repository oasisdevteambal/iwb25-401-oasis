package com.oasis.document.extractor;

import java.io.IOException;

/**
 * Word document text extraction using comprehensive Tika-based extractor
 * Delegates to TikaDocumentExtractor for unified processing
 */
public class WordTextExtractor {
    
    private static final TikaDocumentExtractor tikaExtractor = new TikaDocumentExtractor();

    /**
     * Extract text from Word document using Apache Tika
     * @param wordData The Word document content as byte array
     * @return DocumentExtractionResult with comprehensive extraction data
     */
    public static DocumentExtractionResult extractText(byte[] wordData) throws IOException {
        return extractText(wordData, "document.docx");
    }

    /**
     * Extract text from Word document with filename context
     * @param wordData The Word document content as byte array
     * @param fileName The original filename for context
     * @return DocumentExtractionResult with comprehensive extraction data
     * @throws IOException if document processing fails or document is corrupted
     */
    public static DocumentExtractionResult extractText(byte[] wordData, String fileName) throws IOException {
        if (wordData == null || wordData.length == 0) {
            throw new IOException("Document processing failed: Word data is null or empty for file: " + fileName);
        }

        try {
            return tikaExtractor.extractContent(wordData, fileName);
        } catch (Exception e) {
            // Critical application: No fallback processing - fail explicitly
            throw new IOException(
                String.format("Document processing failed for file '%s': %s. " +
                             "The document may be corrupted, password-protected, or in an unsupported format. " +
                             "Please verify the document integrity and try again.", 
                             fileName, e.getMessage()), e);
        }
    }
}
