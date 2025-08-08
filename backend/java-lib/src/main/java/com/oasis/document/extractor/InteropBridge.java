package com.oasis.document.extractor;

import java.io.IOException;

/**
 * Ballerina-Java interop bridge for type conversion
 */
public class InteropBridge {

    // Simple method that accepts byte[] directly from Ballerina
    public static DocumentExtractionResult extractContentFromBytes(byte[] documentData, String fileName)
            throws IOException {
        return UnifiedDocumentExtractor.extractContent(documentData, fileName);
    }

    // Simple method that accepts String directly from Ballerina
    public static boolean isSupportedFormatString(String fileName) {
        return UnifiedDocumentExtractor.isSupportedFormat(fileName);
    }

    // Original methods with Object parameters for backward compatibility
    public static DocumentExtractionResult extractContent(Object documentData, Object fileName) throws IOException {
        byte[] data = (byte[]) documentData;
        String name = (String) fileName;
        return UnifiedDocumentExtractor.extractContent(data, name);
    }

    public static DocumentExtractionResult extractFromPDF(Object pdfData, Object fileName) throws IOException {
        byte[] data = (byte[]) pdfData;
        String name = (String) fileName;
        return UnifiedDocumentExtractor.extractFromPDF(data, name);
    }

    public static DocumentExtractionResult extractFromWord(Object wordData, Object fileName) throws IOException {
        byte[] data = (byte[]) wordData;
        String name = (String) fileName;
        return UnifiedDocumentExtractor.extractFromWord(data, name);
    }

    public static boolean isSupportedFormat(Object fileName) {
        String name = (String) fileName;
        return UnifiedDocumentExtractor.isSupportedFormat(name);
    }

    // New methods with exact types for Ballerina interop
    public static DocumentExtractionResult extractContent(byte[] documentData, String fileName) throws IOException {
        return UnifiedDocumentExtractor.extractContent(documentData, fileName);
    }

    public static boolean isSupportedFormat(String fileName) {
        return UnifiedDocumentExtractor.isSupportedFormat(fileName);
    }
}
