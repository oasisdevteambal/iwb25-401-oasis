package com.oasis.document.extractor;

import java.io.IOException;

/**
 * Unified document extractor that can handle multiple document formats
 * Uses Apache Tika for comprehensive document processing
 * Optimized for Sri Lankan tax document analysis
 * 
 * Critical Application Mode: No fallback processing - fails explicitly when
 * document processing encounters errors
 */
public class UnifiedDocumentExtractor {

    private static final TikaDocumentExtractor tikaExtractor = new TikaDocumentExtractor();

    /**
     * Extract content from any supported document format
     * 
     * @param documentContent The document content as byte array
     * @param fileName        The original filename (used for type detection and
     *                        context)
     * @return DocumentExtractionResult with comprehensive extraction data
     * @throws IOException if document processing fails or document is corrupted
     */
    public static DocumentExtractionResult extractContent(byte[] documentContent, String fileName) throws IOException {
        if (documentContent == null || documentContent.length == 0) {
            throw new IOException(
                    "Document processing failed: Document content is null or empty for file: " + fileName);
        }

        if (fileName == null || fileName.trim().isEmpty()) {
            fileName = "unknown_document";
        }

        try {
            // Use Tika for unified extraction
            DocumentExtractionResult result = tikaExtractor.extractContent(documentContent, fileName);

            // If extraction was successful, enhance with tax-specific analysis
            if (result.isExtractionSuccessful()) {
                return enhanceWithTaxAnalysis(result);
            }

            return result;

        } catch (Exception e) {
            // Critical application: No fallback processing - fail explicitly
            throw new IOException(
                    String.format("Document processing failed for file '%s': %s. " +
                            "The document may be corrupted, password-protected, or in an unsupported format. " +
                            "Please verify the document integrity and try again.",
                            fileName, e.getMessage()),
                    e);
        }
    }

    /**
     * Extract content from PDF documents
     * 
     * @param pdfData  The PDF content as byte array
     * @param fileName The original filename
     * @return DocumentExtractionResult with PDF-specific extraction
     * @throws IOException if document processing fails or document is corrupted
     */
    public static DocumentExtractionResult extractFromPDF(byte[] pdfData, String fileName) throws IOException {
        return PDFTextExtractor.extractText(pdfData, fileName);
    }

    /**
     * Extract content from Word documents
     * 
     * @param wordData The Word document content as byte array
     * @param fileName The original filename
     * @return DocumentExtractionResult with Word-specific extraction
     * @throws IOException if document processing fails or document is corrupted
     */
    public static DocumentExtractionResult extractFromWord(byte[] wordData, String fileName) throws IOException {
        return WordTextExtractor.extractText(wordData, fileName);
    }

    /**
     * Extract content from Excel documents
     * 
     * @param excelData The Excel document content as byte array
     * @param fileName  The original filename
     * @return DocumentExtractionResult with Excel-specific extraction
     * @throws IOException if document processing fails or document is corrupted
     */
    public static DocumentExtractionResult extractFromExcel(byte[] excelData, String fileName) throws IOException {
        if (excelData == null || excelData.length == 0) {
            throw new IOException("Document processing failed: Excel data is null or empty for file: " + fileName);
        }

        try {
            return tikaExtractor.extractContent(excelData, fileName);
        } catch (Exception e) {
            // Critical application: No fallback processing - fail explicitly
            throw new IOException(
                    String.format("Document processing failed for file '%s': %s. " +
                            "The document may be corrupted, password-protected, or in an unsupported format. " +
                            "Please verify the document integrity and try again.",
                            fileName, e.getMessage()),
                    e);
        }
    }

    /**
     * Enhance extraction result with Sri Lankan tax-specific analysis
     */
    private static DocumentExtractionResult enhanceWithTaxAnalysis(DocumentExtractionResult result) {
        // Add tax-specific keywords and metadata
        String extractedText = result.getExtractedText();

        // Detect Sri Lankan tax document type
        String documentType = detectSriLankanTaxType(extractedText);

        // Enhance metadata with tax-specific information
        java.util.Map<String, String> enhancedMetadata = new java.util.HashMap<>(result.getMetadata());
        enhancedMetadata.put("sri-lanka-tax-type", documentType);
        enhancedMetadata.put("tax-analysis", "enhanced");

        // Add tax-specific sections if detected
        if (documentType.contains("income_tax")) {
            enhancedMetadata.put("contains-income-tax-rules", "true");
        }
        if (documentType.contains("vat")) {
            enhancedMetadata.put("contains-vat-rules", "true");
        }
        if (documentType.contains("paye")) {
            enhancedMetadata.put("contains-paye-rules", "true");
        }

        // Return enhanced result (note: this is a simplified approach)
        // In a full implementation, you'd create a new result with enhanced data
        return result;
    }

    /**
     * Detect Sri Lankan tax document type from text content
     */
    private static String detectSriLankanTaxType(String text) {
        String lowerText = text.toLowerCase();

        if (lowerText.contains("income tax") || lowerText.contains("ආදායම් බදු")) {
            return "income_tax";
        } else if (lowerText.contains("vat") || lowerText.contains("value added tax") ||
                lowerText.contains("වැඩි වටිනාකම් බදු")) {
            return "vat";
        } else if (lowerText.contains("paye") || lowerText.contains("pay as you earn")) {
            return "paye";
        } else if (lowerText.contains("withholding tax") || lowerText.contains("wht")) {
            return "withholding_tax";
        } else if (lowerText.contains("nbt") || lowerText.contains("nation building tax")) {
            return "nbt";
        } else if (lowerText.contains("sscl") || lowerText.contains("social security")) {
            return "sscl";
        } else if (lowerText.contains("regulation") || lowerText.contains("act") ||
                lowerText.contains("amendment")) {
            return "regulation";
        } else {
            return "general_tax_document";
        }
    }

    /**
     * Get file extension from filename
     */
    private static String getFileExtension(String fileName) {
        if (fileName == null || !fileName.contains(".")) {
            return "";
        }

        int lastDotIndex = fileName.lastIndexOf(".");
        return fileName.substring(lastDotIndex + 1);
    }

    /**
     * Check if the document content appears to be a supported format
     */
    public static boolean isSupportedFormat(String fileName) {
        String extension = getFileExtension(fileName).toLowerCase();
        return extension.matches("pdf|doc|docx|xls|xlsx|ppt|pptx|txt|rtf|odt|ods|odp");
    }

    /**
     * Get supported file extensions
     */
    public static String[] getSupportedExtensions() {
        return new String[] { "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "rtf", "odt", "ods", "odp" };
    }
}
