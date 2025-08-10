const express = require('express');
const { get_encoding } = require('tiktoken');
const cors = require('cors');
const compression = require('compression');
const helmet = require('helmet');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3001;

// Initialize tiktoken with cl100k_base encoding (most modern and accurate)
// cl100k_base is used by GPT-4, GPT-3.5-turbo, and modern embedding models
const encoding = get_encoding('cl100k_base');

// Middleware
app.use(helmet()); // Security headers
app.use(compression()); // Gzip compression
app.use(cors()); // Enable CORS
app.use(express.json({ limit: '50mb' })); // Support large documents
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    service: 'tiktoken-tokenizer-service',
    encoding: 'cl100k_base',
    version: '1.0.0',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

// Get model information endpoint
app.get('/model', (req, res) => {
  res.json({
    encoding: 'cl100k_base',
    features: [
      'Fast local token counting using tiktoken',
      'cl100k_base encoding (GPT-4/3.5-turbo compatible)',
      'Unicode support for international text',
      'No API dependencies or rate limits'
    ],
    compatibleWith: [
      'GPT-4', 'GPT-3.5-turbo', 'text-embedding-ada-002'
    ],
    advantages: [
      'No network latency',
      'No rate limits',
      'Consistent results',
      'High throughput'
    ],
    description: 'Fast tiktoken-based tokenizer using cl100k_base encoding'
  });
});

// Main tokenization endpoint - Uses tiktoken cl100k_base encoding
app.post('/tokenize', async (req, res) => {
  const startTime = Date.now();
  
  try {
    const { text } = req.body;
    
    // Validate input
    if (!text || typeof text !== 'string') {
      return res.status(400).json({
        error: 'Invalid input',
        message: 'Text field is required and must be a string',
        success: false
      });
    }
    
    if (text.length === 0) {
      return res.status(400).json({
        error: 'Empty text',
        message: 'Text cannot be empty',
        success: false
      });
    }
    
    // Tokenize using cl100k_base encoding
    const tokens = encoding.encode(text);
    const tokenCount = tokens.length;
    
    // Calculate statistics
    const processingTime = Date.now() - startTime;
    const charCount = text.length;
    const avgCharsPerToken = charCount > 0 ? (charCount / tokenCount).toFixed(2) : 0;
    
    // Prepare response
    const response = {
      tokenCount,
      encoding: 'cl100k_base',
      success: true,
      statistics: {
        characterCount: charCount,
        averageCharsPerToken: parseFloat(avgCharsPerToken),
        processingTimeMs: processingTime
      },
      metadata: {
        timestamp: new Date().toISOString(),
        textPreview: text.length > 100 ? text.substring(0, 100) + '...' : text
      }
    };
    
    res.json(response);
    
  } catch (error) {
    console.error('Tokenization error:', error);
    res.status(500).json({
      error: 'Tokenization failed',
      message: error.message,
      success: false,
      timestamp: new Date().toISOString()
    });
  }
});

// Batch tokenization endpoint - Uses tiktoken cl100k_base encoding
app.post('/tokenize/batch', async (req, res) => {
  const startTime = Date.now();
  
  try {
    const { texts } = req.body;
    
    // Validate input
    if (!texts || !Array.isArray(texts)) {
      return res.status(400).json({
        error: 'Invalid input',
        message: 'texts field is required and must be an array',
        success: false
      });
    }
    
    if (texts.length === 0) {
      return res.status(400).json({
        error: 'Empty array',
        message: 'texts array cannot be empty',
        success: false
      });
    }
    
    if (texts.length > 100) {
      return res.status(400).json({
        error: 'Too many texts',
        message: 'Maximum 100 texts allowed in batch',
        success: false
      });
    }
    
    // Process each text using tiktoken
    const results = [];
    let totalTokens = 0;
    let totalChars = 0;
    let successCount = 0;
    
    for (let i = 0; i < texts.length; i++) {
      const text = texts[i];
      
      if (typeof text !== 'string') {
        results.push({
          index: i,
          error: 'Invalid text type, must be string',
          success: false
        });
        continue;
      }
      
      try {
        const tokens = encoding.encode(text);
        const tokenCount = tokens.length;
        const charCount = text.length;
        
        results.push({
          index: i,
          tokenCount,
          characterCount: charCount,
          averageCharsPerToken: charCount > 0 ? parseFloat((charCount / tokenCount).toFixed(2)) : 0,
          success: true
        });
        
        totalTokens += tokenCount;
        totalChars += charCount;
        successCount++;
        
      } catch (error) {
        results.push({
          index: i,
          error: error.message,
          success: false
        });
      }
    }
    
    const processingTime = Date.now() - startTime;
    
    res.json({
      results,
      summary: {
        totalTexts: texts.length,
        totalTokens,
        totalCharacters: totalChars,
        averageTokensPerText: texts.length > 0 ? parseFloat((totalTokens / texts.length).toFixed(2)) : 0,
        averageCharsPerToken: totalChars > 0 ? parseFloat((totalChars / totalTokens).toFixed(2)) : 0,
        successfulCount: successCount,
        failedCount: texts.length - successCount
      },
      encoding: 'cl100k_base',
      processingTimeMs: processingTime,
      success: true,
      timestamp: new Date().toISOString()
    });
    
  } catch (error) {
    console.error('Batch tokenization error:', error);
    res.status(500).json({
      error: 'Batch tokenization failed',
      message: error.message,
      success: false,
      timestamp: new Date().toISOString()
    });
  }
});

// Chunk analysis endpoint - Uses tiktoken cl100k_base encoding
app.post('/analyze-chunks', async (req, res) => {
  const startTime = Date.now();
  
  try {
    const { chunks, maxTokens = 1000 } = req.body;
    
    // Validate input
    if (!chunks || !Array.isArray(chunks)) {
      return res.status(400).json({
        error: 'Invalid input',
        message: 'chunks field is required and must be an array',
        success: false
      });
    }
    
    if (chunks.length > 100) {
      return res.status(400).json({
        error: 'Too many chunks',
        message: 'Maximum 100 chunks allowed per analysis',
        success: false
      });
    }
    
    // Analyze each chunk using tiktoken
    const analysis = [];
    let totalTokens = 0;
    let chunksOverLimit = 0;
    let successCount = 0;
    
    for (let i = 0; i < chunks.length; i++) {
      const chunk = chunks[i];
      
      if (typeof chunk !== 'string') {
        analysis.push({
          chunkIndex: i,
          error: 'Invalid chunk type, must be string',
          tokenCount: 0,
          withinLimit: false,
          success: false
        });
        continue;
      }
      
      try {
        const tokens = encoding.encode(chunk);
        const tokenCount = tokens.length;
        const withinLimit = tokenCount <= maxTokens;
        
        if (!withinLimit) {
          chunksOverLimit++;
        }
        
        analysis.push({
          chunkIndex: i,
          tokenCount,
          characterCount: chunk.length,
          withinLimit,
          utilizationPercent: parseFloat(((tokenCount / maxTokens) * 100).toFixed(1)),
          averageCharsPerToken: chunk.length > 0 ? parseFloat((chunk.length / tokenCount).toFixed(2)) : 0,
          success: true
        });
        
        totalTokens += tokenCount;
        successCount++;
        
      } catch (error) {
        analysis.push({
          chunkIndex: i,
          error: error.message,
          tokenCount: 0,
          withinLimit: false,
          success: false
        });
      }
    }
    
    const processingTime = Date.now() - startTime;
    
    res.json({
      analysis,
      summary: {
        totalChunks: chunks.length,
        totalTokens,
        chunksOverLimit,
        chunksWithinLimit: chunks.length - chunksOverLimit,
        averageTokensPerChunk: chunks.length > 0 ? parseFloat((totalTokens / chunks.length).toFixed(2)) : 0,
        maxTokenLimit: maxTokens,
        complianceRate: parseFloat(((chunks.length - chunksOverLimit) / chunks.length * 100).toFixed(1)),
        successfulCount: successCount,
        failedCount: chunks.length - successCount
      },
      encoding: 'cl100k_base',
      processingTimeMs: processingTime,
      success: true,
      timestamp: new Date().toISOString()
    });
    
  } catch (error) {
    console.error('Chunk analysis error:', error);
    res.status(500).json({
      error: 'Chunk analysis failed',
      message: error.message,
      success: false,
      timestamp: new Date().toISOString()
    });
  }
});

// Error handling middleware
app.use((error, req, res, next) => {
  console.error('Unhandled error:', error);
  res.status(500).json({
    error: 'Internal server error',
    message: 'An unexpected error occurred',
    success: false,
    timestamp: new Date().toISOString()
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    error: 'Not found',
    message: `Endpoint ${req.method} ${req.path} not found`,
    availableEndpoints: [
      'GET /health',
      'GET /model',
      'POST /tokenize',
      'POST /tokenize/batch',
      'POST /analyze-chunks'
    ],
    success: false
  });
});

// Start server
app.listen(PORT, () => {
  console.log(`🚀 Tiktoken Tokenizer Service running on port ${PORT}`);
  console.log(`🤖 Encoding: cl100k_base (GPT-4/3.5-turbo compatible)`);
  console.log(`📊 Health check: http://localhost:${PORT}/health`);
  console.log(`🔍 Model info: http://localhost:${PORT}/model`);
  console.log(`⚡ Ready to tokenize with tiktoken cl100k_base encoding!`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('🛑 Received SIGTERM, shutting down gracefully');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('🛑 Received SIGINT, shutting down gracefully');
  process.exit(0);
});

module.exports = app;
