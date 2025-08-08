# Document Upload API Testing Guide

## Available Endpoints

### 1. Health Check
- **URL**: `http://localhost:5000/api/health`
- **Method**: GET
- **Description**: Check if the API is running

### 2. Document Upload & Text Extraction
- **URL**: `http://localhost:5000/api/v1/documents/upload`
- **Method**: POST
- **Content-Type**: `multipart/form-data`
- **Description**: Upload PDF or Word documents for tax text extraction

## Testing Methods

### Method 1: Using curl (if available)
```bash
curl -X POST "http://localhost:5000/api/v1/documents/upload" \
  -F "file=@your-document.pdf" \
  -F "filename=tax-document.pdf"
```

### Method 2: Using PowerShell (Windows)
```powershell
# Test health endpoint first
Invoke-RestMethod -Uri "http://localhost:5000/api/health" -Method GET

# Upload document (you need to adjust the file path)
$boundary = [System.Guid]::NewGuid().ToString()
$filePath = "C:\path\to\your\document.pdf"
$fileName = "tax-document.pdf"

$bodyContent = @"
--$boundary
Content-Disposition: form-data; name="filename"

$fileName
--$boundary
Content-Disposition: form-data; name="file"; filename="$fileName"
Content-Type: application/pdf

--$boundary--
"@

# This is a simplified example - for real file upload, use a proper multipart form
```

### Method 3: Using Postman
1. Open Postman
2. Create new POST request: `http://localhost:5000/api/v1/documents/upload`
3. Go to "Body" tab
4. Select "form-data"
5. Add two fields:
   - Key: `filename`, Value: `tax-document.pdf` (text)
   - Key: `file`, Value: [Select File] (file)
6. Click Send

### Method 4: Using a simple HTML form (Browser)
Create an HTML file and open in browser:

```html
<!DOCTYPE html>
<html>
<head>
    <title>Tax Document Upload</title>
</head>
<body>
    <h1>Upload Tax Document for Text Extraction</h1>
    <form action="http://localhost:5000/api/v1/documents/upload" method="post" enctype="multipart/form-data">
        <label for="filename">Filename:</label>
        <input type="text" id="filename" name="filename" value="tax-document.pdf" required><br><br>
        
        <label for="file">Choose PDF or Word file:</label>
        <input type="file" id="file" name="file" accept=".pdf,.doc,.docx" required><br><br>
        
        <input type="submit" value="Upload Document">
    </form>
</body>
</html>
```

## Expected Response

The API will return a JSON response with:

```json
{
  "success": true,
  "message": "Document processing completed successfully",
  "data": {
    "documentId": "unique-document-id",
    "fileName": "tax-document.pdf",
    "fileSize": 12345,
    "extractedText": "Sample extracted text from the document...",
    "documentType": "INCOME_TAX",
    "sections": ["Introduction", "Tax Rates", "Exemptions"],
    "definitions": ["List of tax definitions found"],
    "exemptions": ["List of tax exemptions found"],
    "taxRatesCount": 4,
    "calculationsCount": 2
  },
  "steps": [
    {"step": "text_extraction", "status": "completed"},
    {"step": "document_analysis", "status": "completed"},
    {"step": "structure_analysis", "status": "completed"}
  ]
}
```

## Current Implementation Features

1. **Text Extraction**: Extracts text from PDF and Word documents
2. **Document Type Recognition**: Identifies if document is Income Tax, VAT, PAYE, or Unknown
3. **Structure Analysis**: Analyzes document sections, headers, and structure
4. **Tax Elements Extraction**: Finds tax rates, definitions, exemptions, and calculation rules

## File Type Support

- PDF files (.pdf)
- Word documents (.doc, .docx)
- Maximum file size: Not explicitly limited (depends on server configuration)

## Notes

- Real PDF/Word processing would require external API integration
- The service runs on port 5000 by default
- All extracted data is temporarily processed (not stored permanently yet)
