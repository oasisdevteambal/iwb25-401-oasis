# Gemini 1.5 Flash Tokenizer Service

A fast and accurate Node.js microservice for text tokenization using **Gemini 1.5 Flash** API with tiktoken fallback.

## Features

- ✅ **Accurate Tokenization** - Uses Gemini 1.5 Flash API for exact token counting
- ✅ **Smart Fallback** - tiktoken estimation when Gemini API is unavailable
- ✅ **Batch Processing** - Tokenize multiple texts efficiently
- ✅ **Chunk Analysis** - Analyze if text chunks fit within token limits
- ✅ **High Performance** - Optimized for tax document processing
- ✅ **Rate Limit Aware** - Respects Gemini's 15 req/min free tier limits
- ✅ **Security** - Helmet, CORS, and compression middleware

## Quick Start

### 1. Install Dependencies
```bash
npm install
```

### 2. Setup Environment
```bash
# Copy environment template
cp .env.example .env

# Edit .env and add your Gemini API key
GEMINI_API_KEY=your-actual-api-key-here
```

### 3. Get Gemini API Key
1. Visit [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Create a new API key
3. Copy it to your `.env` file

### 4. Start the Service
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
Returns Gemini 1.5 Flash model details and features.

### Single Text Tokenization
```
POST /tokenize
Content-Type: application/json

{
  "text": "Income tax rates in Sri Lanka are progressive, ranging from 6% to 36%.",
  "method": "auto",
  "includeFallback": true
}
```

**Methods:**
- `"auto"` - Try Gemini API first, fallback to tiktoken (default)
- `"gemini"` - Use Gemini API only
- `"estimation"` - Use tiktoken estimation only

**Response:**
```json
{
  "tokenCount": 18,
  "model": "gemini-1.5-flash",
  "methodUsed": "gemini-api",
  "success": true,
  "statistics": {
    "characterCount": 78,
    "averageCharsPerToken": 4.33,
    "processingTimeMs": 245
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
  ],
  "method": "auto"
}
```

### Chunk Analysis
```
POST /analyze-chunks
Content-Type: application/json

{
  "chunks": ["Chunk 1 text", "Chunk 2 text"],
  "maxTokens": 1000,
  "method": "auto"
}
```

## Integration with Ballerina

Update your Ballerina service to use the new Gemini tokenizer:

```ballerina
// In your document_service.bal
http:Client tokenizerClient = check new("http://localhost:3001");

function getAccurateTokenCount(string text) returns int|error {
    json payload = {
        "text": text,
        "method": "auto"  // Try Gemini API first, fallback to estimation
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
        "maxTokens": 1000,
        "method": "auto"
    };
    
    http:Response response = check tokenizerClient->post("/analyze-chunks", payload);
    return response.getJsonPayload();
}
```

## Gemini 1.5 Flash Benefits

- **Accuracy**: Exact tokenization matching Gemini's processing
- **Context Window**: 1M tokens (perfect for entire tax documents)
- **Rate Limits**: 15 requests/minute (sufficient for document processing)
- **Cost**: Free tier available
- **Speed**: Optimized for fast processing

## Error Handling & Fallback

The service automatically handles Gemini API issues:

1. **API Key Missing**: Falls back to tiktoken estimation
2. **Rate Limit Hit**: Falls back to tiktoken estimation
3. **Network Issues**: Falls back to tiktoken estimation
4. **Service Down**: Falls back to tiktoken estimation

Example with fallback:
```json
{
  "tokenCount": 18,
  "model": "gemini-1.5-flash",
  "methodUsed": "tiktoken-estimation",
  "fallbackReason": "Rate limit exceeded",
  "warning": "Used tiktoken estimation due to Gemini API unavailability",
  "success": true
}
```

## Performance

- **Gemini API**: ~200-500ms per request (network dependent)
- **tiktoken**: ~1-5ms per text (local processing)
- **Batch Processing**: Optimized for multiple texts
- **Memory**: Efficient with proper cleanup

## Environment Variables

- `GEMINI_API_KEY`: Your Gemini API key (required for accurate counting)
- `PORT`: Service port (default: 3001)
- `NODE_ENV`: Environment (development/production)

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

## Rate Limits & Best Practices

**Gemini 1.5 Flash Free Tier:**
- 15 requests per minute
- 1M tokens per minute
- Use batch endpoints for multiple texts
- Automatic fallback prevents service interruption

**Recommendations:**
- Use `method: "auto"` for reliability
- Batch similar-sized texts together
- Monitor the `methodUsed` field in responses
- Set up monitoring for API key usage

## Deployment

### Docker
```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
EXPOSE 3001
CMD ["npm", "start"]
```

### Environment Setup
```bash
# Production environment
NODE_ENV=production
GEMINI_API_KEY=your-production-api-key
PORT=3001
```

This service provides the perfect balance of accuracy (Gemini API) and reliability (tiktoken fallback) for your tax document processing needs!
