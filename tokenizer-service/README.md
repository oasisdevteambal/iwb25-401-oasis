# TikToken Tokenizer Service

A fast and reliable Node.js microservice for text tokenization using **tiktoken cl100k_base** encoding for accurate token counting.

## Features

- ✅ **Fast Tokenization** - Uses tiktoken cl100k_base encoding for instant token counting
- ✅ **No API Dependencies** - Completely local processing, no external API calls
- ✅ **Batch Processing** - Tokenize multiple texts efficiently
- ✅ **Chunk Analysis** - Analyze if text chunks fit within token limits
- ✅ **High Performance** - Optimized for tax document processing with no rate limits
- ✅ **GPT-4 Compatible** - Uses cl100k_base encoding (same as GPT-4, GPT-3.5-turbo)
- ✅ **Security** - Helmet, CORS, and compression middleware

## Quick Start

### 1. Install Dependencies
```bash
npm install
```

### 2. Setup Environment (Optional)
```bash
# Copy environment template (optional - service works without env vars)
cp .env.example .env

# Edit .env for custom configuration
PORT=3001
NODE_ENV=development
```

### 3. Start the Service
```bash
# Development mode with auto-reload
npm run dev

# Production mode
npm start
```

The service will start on port 3001.

## API Endpoints

### Health Check
```
GET /health
```
Returns service status and configuration info.

### Model Information
```
GET /model
```
Returns tiktoken cl100k_base encoding details and features.

### Single Text Tokenization
```
POST /tokenize
Content-Type: application/json

{
  "text": "Income tax rates in Sri Lanka are progressive, ranging from 6% to 36%."
}
```

**Response:**
```json
{
  "tokenCount": 18,
  "encoding": "cl100k_base",
  "success": true,
  "statistics": {
    "characterCount": 78,
    "averageCharsPerToken": 4.33,
    "processingTimeMs": 2
  },
  "metadata": {
    "timestamp": "2025-01-09T10:00:00.000Z",
    "textPreview": "Income tax rates in Sri Lanka are progressive, ranging from 6% to 36%."
  }
}
```

### Batch Tokenization
```
POST /tokenize/batch
Content-Type: application/json

{
  "texts": [
    "First tax document chunk",
    "Second tax document chunk",
    "Third tax document chunk"
  ]
}
```

### Chunk Analysis
```
POST /analyze-chunks
Content-Type: application/json

{
  "chunks": ["Chunk 1 text", "Chunk 2 text"],
  "maxTokens": 1000
}
```

## Integration with Ballerina

Update your Ballerina service to use the tiktoken tokenizer:

```ballerina
// In your document_service.bal
http:Client tokenizerClient = check new("http://localhost:3001");

function getAccurateTokenCount(string text) returns int|error {
    json payload = {
        "text": text
    };
    
    http:Response response = check tokenizerClient->post("/tokenize", payload);
    json result = check response.getJsonPayload();
    
    if (result.success == true) {
        return <int>result.tokenCount;
    } else {
        return error("Tokenization failed: " + result.error.toString());
    }
}

// For batch processing chunks
function analyzeChunks(string[] chunks) returns json|error {
    json payload = {
        "chunks": chunks,
        "maxTokens": 1000
    };
    
    http:Response response = check tokenizerClient->post("/analyze-chunks", payload);
    return response.getJsonPayload();
}
```

## TikToken cl100k_base Benefits

- **Speed**: Lightning-fast local processing (~1-5ms per request)
- **Reliability**: No network dependencies or API failures
- **Compatibility**: Uses cl100k_base encoding (same as GPT-4, GPT-3.5-turbo)
- **Accuracy**: Precise token counting for modern language models
- **No Rate Limits**: Process unlimited text without restrictions
- **Cost**: Completely free - no API costs

## Performance & Reliability

The service provides consistent, fast performance:

- **No External Dependencies**: Pure local processing
- **No Rate Limits**: Unlimited tokenization capacity
- **No Network Issues**: Always available when service is running
- **Consistent Results**: Same input always produces same output

## Performance

- **Local Processing**: ~1-5ms per text (no network latency)
- **Batch Processing**: Optimized for multiple texts
- **Memory Efficient**: Proper cleanup and resource management
- **High Throughput**: No rate limits or API restrictions

## Environment Variables

- `PORT`: Service port (default: 3001)
- `NODE_ENV`: Environment (development/production)
- `MAX_BATCH_SIZE`: Maximum texts in batch request (default: 100)

## Testing

```bash
# Test the service
curl -X POST http://localhost:3001/tokenize \
  -H "Content-Type: application/json" \
  -d '{"text": "Income tax calculation for Sri Lankan residents"}'

# Test health
curl http://localhost:3001/health

# Test model info
curl http://localhost:3001/model
```

## Best Practices

**Recommendations:**
- Use batch endpoints for multiple texts to improve performance
- Monitor processing times for performance optimization
- Set appropriate `MAX_BATCH_SIZE` for your use case
- Use compression for large text payloads


### Environment Setup
```bash
# Production environment
NODE_ENV=production
PORT=3001
MAX_BATCH_SIZE=100
```

This service provides fast, reliable, and cost-free token counting using tiktoken cl100k_base encoding - perfect for your tax document processing needs!
