package com.oasis.document.extractor;

/**
 * Represents tabular data extracted from documents
 * Optimized for Ballerina Java interop
 */
public class TableData {
    private final String[][] data;
    private final String[] headers;
    private final int rowCount;
    private final int columnCount;
    private final String tableTitle;

    // Constructor with data and headers
    public TableData(String[][] data, String[] headers, String tableTitle) {
        this.data = data != null ? data : new String[0][0];
        this.headers = headers != null ? headers : new String[0];
        this.rowCount = this.data.length;
        this.columnCount = this.data.length > 0 ? this.data[0].length : 0;
        this.tableTitle = tableTitle != null ? tableTitle : "";
    }

    // Simple constructor
    public TableData(String[][] data) {
        this(data, new String[0], "");
    }

    // Getter methods for Ballerina interop
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

    public String getTableTitle() {
        return tableTitle;
    }

    public boolean hasHeaders() {
        return headers.length > 0;
    }

    public boolean hasTitle() {
        return !tableTitle.isEmpty();
    }

    // Utility method to get cell data safely
    public String getCell(int row, int column) {
        if (row >= 0 && row < rowCount && column >= 0 && column < columnCount) {
            return data[row][column] != null ? data[row][column] : "";
        }
        return "";
    }

    @Override
    public String toString() {
        return String.format("TableData{title='%s', rows=%d, columns=%d, hasHeaders=%s}",
                tableTitle, rowCount, columnCount, hasHeaders());
    }
}
