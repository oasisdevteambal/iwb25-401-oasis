package com.oasis.document.extractor;

import java.io.IOException;

/**
 * PDF text extraction using comprehensive Tika-based extractor
 * Delegates to TikaDocumentExtractor for unified processing
 */
public class PDFTextExtractor {
    
    private static final TikaDocumentExtractor tikaExtractor = new TikaDocumentExtractor();

    /**
     * Extract text from PDF using Apache Tika
     * @param pdfData The PDF content as byte array
     * @return DocumentExtractionResult with comprehensive extraction data
     */
    public static DocumentExtractionResult extractText(byte[] pdfData) throws IOException {
        return extractText(pdfData, "document.pdf");
    }

    /**
     * Extract text from PDF with filename context
     * @param pdfData The PDF content as byte array
     * @param fileName The original filename for context
     * @return DocumentExtractionResult with comprehensive extraction data
     * @throws IOException if document processing fails or document is corrupted
     */
    public static DocumentExtractionResult extractText(byte[] pdfData, String fileName) throws IOException {
        if (pdfData == null || pdfData.length == 0) {
            throw new IOException("Document processing failed: PDF data is null or empty for file: " + fileName);
        }

        try {
            return tikaExtractor.extractContent(pdfData, fileName);
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
