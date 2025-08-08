package com.oasis.document.extractor;

/**
 * Represents image data extracted from documents
 * Contains metadata about images found in the document
 */
public class ImageData {
    private final String imageId;
    private final String imageType;
    private final int width;
    private final int height;
    private final String description;
    private final String location;

    // Constructor
    public ImageData(String imageId, String imageType, int width, int height,
            String description, String location) {
        this.imageId = imageId != null ? imageId : "";
        this.imageType = imageType != null ? imageType : "unknown";
        this.width = Math.max(0, width);
        this.height = Math.max(0, height);
        this.description = description != null ? description : "";
        this.location = location != null ? location : "";
    }

    // Simple constructor
    public ImageData(String imageId, String imageType) {
        this(imageId, imageType, 0, 0, "", "");
    }

    // Getter methods for Ballerina interop
    public String getImageId() {
        return imageId;
    }

    public String getImageType() {
        return imageType;
    }

    public int getWidth() {
        return width;
    }

    public int getHeight() {
        return height;
    }

    public String getDescription() {
        return description;
    }

    public String getLocation() {
        return location;
    }

    // Utility methods
    public boolean hasDescription() {
        return !description.isEmpty();
    }

    public boolean hasLocation() {
        return !location.isEmpty();
    }

    public boolean hasDimensions() {
        return width > 0 && height > 0;
    }

    @Override
    public String toString() {
        return String.format("ImageData{id='%s', type='%s', dimensions=%dx%d, description='%s'}",
                imageId, imageType, width, height, description);
    }
}
