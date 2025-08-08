package com.oasis.document.extractor;

/**
 * Table information extracted from documents
 * Represents structured data found in PDF or Word documents
 */
public class TableInfo {
    private final int page;
    private final String[][] data;
    private final String[] headers;
    private final int rowCount;
    private final int columnCount;

    public TableInfo(int page, String[][] data) {
        this.page = page;
        this.data = data != null ? data : new String[0][0];
        this.rowCount = this.data.length;
        this.columnCount = this.rowCount > 0 ? this.data[0].length : 0;
        this.headers = this.rowCount > 0 ? this.data[0] : new String[0];
    }

    public TableInfo(int page, String[][] data, String[] headers) {
        this.page = page;
        this.data = data != null ? data : new String[0][0];
        this.headers = headers != null ? headers : new String[0];
        this.rowCount = this.data.length;
        this.columnCount = this.headers.length;
    }

    // Getter methods for Ballerina interop
    public int getPage() {
        return page;
    }

    public String[][] getData() {
        return data;
    }

    public String[] getHeaders() {
        return headers;
    }

    public int getRowCount() {
        return rowCount;
    }

    public int getColumnCount() {
        return columnCount;
    }

    public String getCell(int row, int column) {
        if (row >= 0 && row < rowCount && column >= 0 && column < columnCount) {
            return data[row][column];
        }
        return "";
    }

    @Override
    public String toString() {
        return String.format("TableInfo{page=%d, rows=%d, columns=%d}", page, rowCount, columnCount);
    }
}
