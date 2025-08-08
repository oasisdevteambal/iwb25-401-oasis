package com.oasis.document.extractor;

import org.apache.tika.Tika;
import org.apache.tika.metadata.Metadata;
import org.apache.tika.metadata.TikaCoreProperties;
import org.apache.tika.parser.AutoDetectParser;
import org.apache.tika.parser.ParseContext;
import org.apache.tika.parser.Parser;
import org.apache.tika.sax.BodyContentHandler;
import org.apache.tika.sax.ToHTMLContentHandler;
import org.apache.tika.language.detect.LanguageDetector;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.util.*;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Comprehensive document extractor using Apache Tika
 * Supports multiple document formats with unified processing
 * Optimized for Sri Lankan tax document analysis
 */
public class TikaDocumentExtractor {
    private static final Logger logger = LoggerFactory.getLogger(TikaDocumentExtractor.class);

    private final Parser parser;
    private final Tika tika;
    private final LanguageDetector languageDetector;

    public TikaDocumentExtractor() {
        this.parser = new AutoDetectParser();
        this.tika = new Tika();

        // Initialize language detector
        LanguageDetector detector = null;
        try {
            detector = LanguageDetector.getDefaultLanguageDetector();
            detector.loadModels();
        } catch (Exception e) {
            logger.warn("Could not initialize language detector: {}", e.getMessage());
        }
        this.languageDetector = detector;
    }

    /**
     * Extract content from document bytes
     * 
     * @param documentContent The document content as byte array
     * @param fileName        The original filename for context
     * @return DocumentExtractionResult with comprehensive extraction data
     */
    public DocumentExtractionResult extractContent(byte[] documentContent, String fileName) {
        if (documentContent == null || documentContent.length == 0) {
            return new DocumentExtractionResult("Document content is empty or null");
        }

        try {
            logger.info("Starting document extraction for: {}", fileName);

            // Create input stream from byte array
            InputStream inputStream = new ByteArrayInputStream(documentContent);

            // Initialize Tika components
            Metadata metadata = new Metadata();
            metadata.set(TikaCoreProperties.RESOURCE_NAME_KEY, fileName);

            ParseContext parseContext = new ParseContext();
            parseContext.set(Parser.class, parser);

            // Create content handlers
            BodyContentHandler textHandler = new BodyContentHandler(-1); // No limit
            ToHTMLContentHandler htmlHandler = new ToHTMLContentHandler();

            logger.info("Created content handlers with no size limit");

            // Parse document for text content
            parser.parse(inputStream, textHandler, metadata, parseContext);

            // Parse again for HTML structure (reset stream)
            inputStream = new ByteArrayInputStream(documentContent);
            parser.parse(inputStream, htmlHandler, metadata, parseContext);

            // Extract basic information
            String extractedText = textHandler.toString();
            String htmlContent = htmlHandler.toString();
            String contentType = metadata.get(Metadata.CONTENT_TYPE);

            logger.info("Extraction completed - Text length: {}, Content type: {}",
                    extractedText.length(), contentType);

            // Debug logging for text extraction issues
            if (extractedText.trim().isEmpty()) {
                System.out.println("DEBUG: Empty text extracted! Debugging information:");
                System.out.println("DEBUG: - Document size: " + documentContent.length + " bytes");
                System.out.println("DEBUG: - Content type detected: " + contentType);
                System.out.println("DEBUG: - HTML content length: " + htmlContent.length());
                System.out.println("DEBUG: - First 500 chars of HTML: " +
                        (htmlContent.length() > 500 ? htmlContent.substring(0, 500) + "..." : htmlContent));

                // Log all metadata for debugging
                System.out.println("DEBUG: Document metadata:");
                for (String name : metadata.names()) {
                    System.out.println("DEBUG: - Metadata " + name + ": " + metadata.get(name));
                }

                // Try alternative extraction method using Tika.parseToString
                System.out.println("DEBUG: Attempting alternative extraction with Tika.parseToString...");
                try {
                    InputStream altStream = new ByteArrayInputStream(documentContent);
                    String altText = tika.parseToString(altStream);
                    System.out.println("DEBUG: Alternative extraction result: " + altText.length() + " characters");
                    if (!altText.trim().isEmpty()) {
                        System.out.println("DEBUG: Alternative method succeeded! Using alternative text.");
                        System.out.println("DEBUG: First 200 chars: " +
                                (altText.length() > 200 ? altText.substring(0, 200) + "..." : altText));
                        extractedText = altText;
                    } else {
                        System.out.println("DEBUG: Alternative method also returned empty text");

                        // Try third method - manual PDF parsing with AutoDetectParser and different
                        // handler
                        System.out.println("DEBUG: Attempting third method with different parser configuration...");
                        try {
                            InputStream thirdStream = new ByteArrayInputStream(documentContent);
                            BodyContentHandler thirdHandler = new BodyContentHandler(10 * 1024 * 1024); // 10MB limit
                            Metadata thirdMeta = new Metadata();
                            ParseContext thirdContext = new ParseContext();

                            AutoDetectParser autoParser = new AutoDetectParser();
                            autoParser.parse(thirdStream, thirdHandler, thirdMeta, thirdContext);

                            String thirdText = thirdHandler.toString();
                            System.out.println("DEBUG: Third method result: " + thirdText.length() + " characters");
                            if (!thirdText.trim().isEmpty()) {
                                System.out.println("DEBUG: Third method succeeded! Using third method text.");
                                System.out.println("DEBUG: First 200 chars: " +
                                        (thirdText.length() > 200 ? thirdText.substring(0, 200) + "..." : thirdText));
                                extractedText = thirdText;
                            } else {
                                System.out.println(
                                        "DEBUG: All three methods returned empty text - this is likely an image-based PDF");
                            }
                        } catch (Exception thirdEx) {
                            System.out.println("DEBUG: Third extraction method failed: " + thirdEx.getMessage());
                            thirdEx.printStackTrace();
                        }
                    }
                } catch (Exception altEx) {
                    System.out.println("DEBUG: Alternative extraction failed: " + altEx.getMessage());
                    altEx.printStackTrace();
                }
            } else {
                System.out.println("DEBUG: Successfully extracted " + extractedText.length() + " characters of text");
                System.out.println("DEBUG: Text preview (first 200 chars): " +
                        (extractedText.length() > 200 ? extractedText.substring(0, 200) + "..." : extractedText));
            }

            if (extractedText.trim().isEmpty()) {
                // Don't immediately fail - provide more information about why extraction failed
                System.out.println("DEBUG: No text content extracted. Document may be image-based or encrypted.");
                System.out.println("DEBUG: Document metadata: " + metadata.toString());

                // Create a result with empty text but still provide metadata
                Map<String, String> metadataMap = convertMetadataToMap(metadata);
                DocumentStructure emptyStructure = new DocumentStructure();

                return new DocumentExtractionResult(
                        "", // Empty text
                        emptyStructure,
                        contentType,
                        new String[0], // No languages detected
                        new TableData[0], // No tables
                        new ImageData[0], // No images
                        metadataMap,
                        new TikaExtractionInfo());
            }

            // Detect languages
            String[] detectedLanguages = detectLanguages(extractedText);

            // Extract document structure
            DocumentStructure structure = extractDocumentStructure(metadata, extractedText);

            // Extract tables from HTML content
            TableData[] tables = extractTables(htmlContent);

            // Extract image references
            ImageData[] images = extractImageReferences(metadata, htmlContent);

            // Convert metadata to map
            Map<String, String> metadataMap = convertMetadataToMap(metadata);

            // Create extraction info
            TikaExtractionInfo extractionInfo = createExtractionInfo(metadata, extractedText, tables, images);

            System.out.println("DEBUG: Successfully extracted content from: " + fileName + " (size: " +
                    extractedText.length() + " chars, tables: " + tables.length + ", images: " + images.length + ")");

            return new DocumentExtractionResult(
                    extractedText, structure, contentType, detectedLanguages,
                    tables, images, metadataMap, extractionInfo);

        } catch (Exception e) {
            System.out.println("DEBUG: Error extracting content from document: " + fileName + " - " + e.getMessage());
            e.printStackTrace();
            return new DocumentExtractionResult("Extraction failed: " + e.getMessage());
        }
    }

    /**
     * Detect languages in the document text
     */
    private String[] detectLanguages(String text) {
        if (languageDetector == null || text.length() < 50) {
            return new String[] { "en" }; // Default to English
        }

        try {
            org.apache.tika.language.detect.LanguageResult result = languageDetector.detect(text);
            return new String[] { result.getLanguage() };
        } catch (Exception e) {
            logger.warn("Language detection failed: {}", e.getMessage());
            return new String[] { "en" };
        }
    }

    /**
     * Extract document structure from metadata and text
     */
    private DocumentStructure extractDocumentStructure(Metadata metadata, String text) {
        String title = getMetadataValue(metadata, TikaCoreProperties.TITLE.getName(), "");
        String author = getMetadataValue(metadata, TikaCoreProperties.CREATOR.getName(), "");
        String subject = getMetadataValue(metadata, TikaCoreProperties.SUBJECT.getName(), "");
        String creationDate = getMetadataValue(metadata, TikaCoreProperties.CREATED.getName(), "");
        String modificationDate = getMetadataValue(metadata, TikaCoreProperties.MODIFIED.getName(), "");

        // Extract headers using regex patterns
        String[] headers = extractHeaders(text);

        // Extract sections using patterns common in tax documents
        String[] sections = extractSections(text);

        // Convert metadata to map
        Map<String, String> metadataMap = convertMetadataToMap(metadata);

        return new DocumentStructure(title, headers, sections, author, subject,
                creationDate, modificationDate, metadataMap);
    }

    /**
     * Extract headers from text using regex patterns
     */
    private String[] extractHeaders(String text) {
        List<String> headers = new ArrayList<>();

        // Pattern for common header formats in tax documents
        Pattern headerPattern = Pattern.compile(
                "(?m)^\\s*((?:SECTION|PART|CHAPTER|CLAUSE)\\s+[\\d\\.]+\\s*[-–]?\\s*.+?)$",
                Pattern.CASE_INSENSITIVE);

        Matcher matcher = headerPattern.matcher(text);
        while (matcher.find() && headers.size() < 50) { // Limit to avoid excessive headers
            headers.add(matcher.group(1).trim());
        }

        return headers.toArray(new String[0]);
    }

    /**
     * Extract sections from text
     */
    private String[] extractSections(String text) {
        List<String> sections = new ArrayList<>();

        // Split by common section delimiters
        String[] paragraphs = text.split("\\n\\s*\\n");

        for (String paragraph : paragraphs) {
            paragraph = paragraph.trim();
            if (paragraph.length() > 50 && paragraph.length() < 500) {
                // Filter for meaningful sections
                if (paragraph.matches(".*(?i)(tax|rate|income|deduction|exemption|calculation).*")) {
                    sections.add(paragraph);
                    if (sections.size() >= 20)
                        break; // Limit sections
                }
            }
        }

        return sections.toArray(new String[0]);
    }

    /**
     * Extract table data from HTML content
     */
    private TableData[] extractTables(String htmlContent) {
        List<TableData> tables = new ArrayList<>();

        // Simple table extraction from HTML
        Pattern tablePattern = Pattern.compile("<table[^>]*>(.*?)</table>", Pattern.DOTALL | Pattern.CASE_INSENSITIVE);
        Matcher tableMatcher = tablePattern.matcher(htmlContent);

        int tableIndex = 0;
        while (tableMatcher.find() && tableIndex < 10) { // Limit to 10 tables
            String tableHtml = tableMatcher.group(1);
            TableData table = parseHtmlTable(tableHtml, "Table " + (tableIndex + 1));
            if (table.getRowCount() > 0) {
                tables.add(table);
                tableIndex++;
            }
        }

        return tables.toArray(new TableData[0]);
    }

    /**
     * Parse HTML table content into TableData
     */
    private TableData parseHtmlTable(String tableHtml, String title) {
        List<String[]> rows = new ArrayList<>();

        // Extract table rows
        Pattern rowPattern = Pattern.compile("<tr[^>]*>(.*?)</tr>", Pattern.DOTALL | Pattern.CASE_INSENSITIVE);
        Matcher rowMatcher = rowPattern.matcher(tableHtml);

        while (rowMatcher.find()) {
            String rowHtml = rowMatcher.group(1);
            String[] cells = extractTableCells(rowHtml);
            if (cells.length > 0) {
                rows.add(cells);
            }
        }

        if (rows.isEmpty()) {
            return new TableData(new String[0][0], new String[0], title);
        }

        // Convert to 2D array
        String[][] data = rows.toArray(new String[0][]);

        // Use first row as headers if it looks like headers
        String[] headers = new String[0];
        if (data.length > 0 && looksLikeHeaders(data[0])) {
            headers = data[0];
            // Remove header row from data
            String[][] dataWithoutHeaders = new String[data.length - 1][];
            System.arraycopy(data, 1, dataWithoutHeaders, 0, data.length - 1);
            data = dataWithoutHeaders;
        }

        return new TableData(data, headers, title);
    }

    /**
     * Extract cells from table row HTML
     */
    private String[] extractTableCells(String rowHtml) {
        List<String> cells = new ArrayList<>();

        Pattern cellPattern = Pattern.compile("<t[hd][^>]*>(.*?)</t[hd]>", Pattern.DOTALL | Pattern.CASE_INSENSITIVE);
        Matcher cellMatcher = cellPattern.matcher(rowHtml);

        while (cellMatcher.find()) {
            String cellContent = cellMatcher.group(1);
            // Remove HTML tags and clean up
            cellContent = cellContent.replaceAll("<[^>]+>", "").trim();
            cells.add(cellContent);
        }

        return cells.toArray(new String[0]);
    }

    /**
     * Check if a row looks like table headers
     */
    private boolean looksLikeHeaders(String[] row) {
        if (row.length == 0)
            return false;

        // Simple heuristic: headers are usually short and contain common words
        for (String cell : row) {
            if (cell.length() > 50)
                return false; // Headers are usually shorter
        }
        return true;
    }

    /**
     * Extract image references from metadata and HTML
     */
    private ImageData[] extractImageReferences(Metadata metadata, String htmlContent) {
        List<ImageData> images = new ArrayList<>();

        // Check metadata for image count
        String imageCount = metadata.get("meta:image-count");
        if (imageCount != null) {
            try {
                int count = Integer.parseInt(imageCount);
                for (int i = 0; i < Math.min(count, 20); i++) { // Limit to 20 images
                    images.add(new ImageData("image_" + i, "embedded"));
                }
            } catch (NumberFormatException e) {
                // Ignore parsing error
            }
        }

        // Extract images from HTML content
        Pattern imgPattern = Pattern.compile("<img[^>]*>", Pattern.CASE_INSENSITIVE);
        Matcher imgMatcher = imgPattern.matcher(htmlContent);

        int imgIndex = 0;
        while (imgMatcher.find() && imgIndex < 10) {
            images.add(new ImageData("html_img_" + imgIndex, "html_embedded"));
            imgIndex++;
        }

        return images.toArray(new ImageData[0]);
    }

    /**
     * Create extraction info from parsed data
     */
    private TikaExtractionInfo createExtractionInfo(Metadata metadata, String text,
            TableData[] tables, ImageData[] images) {
        String parsedBy = metadata.get("X-Parsed-By");
        String mediaType = metadata.get(Metadata.CONTENT_TYPE);
        boolean hasImages = images.length > 0;
        boolean hasTables = tables.length > 0;
        int wordCount = estimateWordCount(text);
        String encoding = metadata.get(Metadata.CONTENT_ENCODING);

        return new TikaExtractionInfo(parsedBy, mediaType, hasImages, hasTables, wordCount, encoding);
    }

    /**
     * Estimate word count in text
     */
    private int estimateWordCount(String text) {
        if (text == null || text.trim().isEmpty()) {
            return 0;
        }

        String[] words = text.trim().split("\\s+");
        return words.length;
    }

    /**
     * Convert Tika metadata to map
     */
    private Map<String, String> convertMetadataToMap(Metadata metadata) {
        Map<String, String> map = new HashMap<>();

        for (String name : metadata.names()) {
            String value = metadata.get(name);
            if (value != null && !value.trim().isEmpty()) {
                map.put(name, value);
            }
        }

        return map;
    }

    /**
     * Get metadata value with fallback
     */
    private String getMetadataValue(Metadata metadata, String key, String defaultValue) {
        String value = metadata.get(key);
        return value != null ? value : defaultValue;
    }
}
