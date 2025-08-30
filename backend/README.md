# Sri Lankan Tax Calculation API - Backend

A comprehensive Ballerina-based backend service for automated Sri Lankan tax calculations, document processing, and AI-powered tax assistance.

## 🏗️ Architecture Overview

This backend is built with **Ballerina**, a cloud-native programming language designed for integration and API development. The architecture follows a modular service-oriented design with specialized components for different aspects of tax processing.

### Core Technology Stack

- **Ballerina 2201.12.7** - Primary backend language
- **PostgreSQL** - Database with pgvector for embeddings
- **Custom Java Library** - Document extraction capabilities
- **Google Gemini API** - AI/LLM integration
- **Supabase** - Database hosting and storage

## 📁 Service Architecture

```
backend/
├── main.bal                    # Main HTTP listener and health endpoints
├── document_service.bal        # Document upload, processing, and storage
├── tax_calculation_service.bal # Dynamic tax calculations
├── chat_service.bal           # AI-powered tax assistant
├── form_schema_service.bal    # Dynamic form generation
├── admin_service.bal          # Admin operations and analytics
├── aggregation_service.bal    # Data aggregation services
├── gemini_config.bal          # LLM configuration
├── tax_api_types.bal          # Shared type definitions
├── java-lib/                  # Custom document extractor library
├── config/                    # Configuration modules
└── types/                     # Type definitions
```

## 🔧 Core Services

### 1. Document Service (`document_service.bal`)
**Primary responsibility**: Document upload, text extraction, and AI-powered rule extraction

**Key Features:**
- Multi-format document processing (PDF, Word, Excel)
- **Ballerina-Java Interop** with custom document extractor
- Vector embeddings for semantic search
- Supabase storage integration
- AI-powered tax rule extraction

**Endpoints:**
- `POST /api/documents/upload` - Upload tax documents
- `GET /api/documents` - List documents
- `POST /api/documents/{id}/process` - Process with AI
- `GET /api/documents/{id}/content` - Get extracted content

### 2. Tax Calculation Service (`tax_calculation_service.bal`)
**Primary responsibility**: Dynamic tax calculations based on extracted rules

**Key Features:**
- Real-time tax calculations
- Support for Income Tax, VAT, PAYE, WHT, NBT, SSCL
- Dynamic formula execution
- Calculation history and audit trails

**Endpoints:**
- `POST /api/v1/tax/calculate` - Calculate tax liability
- `GET /api/v1/tax/brackets/{type}` - Get tax brackets
- `POST /api/v1/tax/estimate` - Quick estimation

### 3. Chat Service (`chat_service.bal`)
**Primary responsibility**: AI-powered tax assistance and query resolution

**Key Features:**
- Natural language tax queries
- RAG (Retrieval Augmented Generation) using vector search
- Intent detection and classification
- Context-aware responses using database facts

**Endpoints:**
- `POST /api/v1/chat/message` - Send chat message
- `GET /api/v1/chat/history` - Get conversation history

### 4. Form Schema Service (`form_schema_service.bal`)
**Primary responsibility**: Dynamic form generation based on extracted rules

**Key Features:**
- JSON Schema generation
- React JSON Schema Form compatibility
- Dynamic validation rules
- Multi-language support

**Endpoints:**
- `GET /api/v1/forms/schema` - Get latest schema
- `GET /api/v1/forms/schema/{type}` - Get type-specific schema
- `POST /api/v1/forms/validate` - Validate form data

### 5. Admin Service (`admin_service.bal`)
**Primary responsibility**: Administrative operations and analytics

**Key Features:**
- Document management
- Rule validation and editing
- System analytics
- User management

**Endpoints:**
- `GET /api/v1/admin/dashboard` - Analytics dashboard
- `PUT /api/v1/admin/rules/{id}` - Update tax rules
- `GET /api/v1/admin/logs` - System logs

## 🔄 Custom Ballerina-Java Integration

### Document Extractor Library (`java-lib/`)

One of the key innovations in this backend is the **custom Java library** that seamlessly integrates with Ballerina through Java interop capabilities. This demonstrates Ballerina's powerful language features for polyglot programming.

#### Why Custom Java Library?

- **Performance**: Java's mature document processing ecosystem (Apache Tika)
- **Ballerina Integration**: Purpose-built for Ballerina's type system
- **Tax Document Optimization**: Specialized for Sri Lankan tax documents

#### Architecture

```
java-lib/
├── src/main/java/com/oasis/document/extractor/
│   ├── InteropBridge.java          # Ballerina interop bridge
│   ├── UnifiedDocumentExtractor.java # Main extractor
│   ├── TikaDocumentExtractor.java    # Apache Tika integration
│   ├── DocumentExtractionResult.java # Result types
│   └── DocumentStructure.java       # Document structure analysis
├── pom.xml                         # Maven configuration
└── target/
    └── document-extractor.jar      # Compiled library
```

#### Ballerina Integration Example

```ballerina
import ballerina/jballerina.java;

// Direct integration with custom Java library
function extractDocumentContent(byte[] documentData, string fileName) 
    returns DocumentExtractionResult|error = @java:Method {
    'class: "com.oasis.document.extractor.InteropBridge",
    name: "extractContentFromBytes"
} external;
```

#### Library Features

- **Multi-format Support**: PDF, Word, Excel, PowerPoint
- **Metadata Extraction**: Author, creation date, language detection
- **Structure Analysis**: Headers, sections, tables
- **Tax Document Optimization**: Sri Lankan tax document patterns
- **Fail-fast Approach**: Explicit error handling for critical applications

## 🚀 Getting Started

### Prerequisites

- **Ballerina 2201.12.7** or higher
- **Java 17** or higher (for custom library)
- **PostgreSQL** with pgvector extension
- **Node.js** (for tokenizer service)

### Installation

1. **Clone and navigate to backend**:
```bash
cd backend
```

2. **Build custom Java library**:
```bash
cd java-lib
./build.bat  # Windows
# or
mvn clean package  # Cross-platform
cd ..
```

3. **Configure environment**:
```bash
cp Config.toml.sample Config.toml
# Edit Config.toml with your settings
```

4. **Build and run**:
```bash
bal build
bal run
```

The server will start on port 5000.

### Configuration

#### Required Configuration (`Config.toml`)

```toml
[backend]
SUPABASE_URL = "your_supabase_url"
SUPABASE_SERVICE_ROLE_KEY = "your_service_key"
GEMINI_API_KEY = "your_gemini_key"
DEBUG_LOGS = false
USE_CHAT_LLM = true
USE_LLM_INTENT_DETECTION = true
```

#### Database Setup

1. Create Supabase project
2. Enable pgvector extension
3. Run database migrations (see `INTEGRATION_GUIDE.md`)

## 🔧 Ballerina Dependencies

### External Dependencies
```toml
[[dependency]]
org = "ballerinax"
name = "postgresql"
version = "1.16.1"

[[dependency]]
org = "ballerinax"
name = "postgresql.driver" 
version = "1.6.0"
```

### Platform Java Dependencies
```toml
[[platform.java21.dependency]]
path = "./libs/document-extractor.jar"
```

## 🏃‍♂️ Development

### Building Java Library
```bash
cd java-lib
mvn clean package
cp target/document-extractor-optimized.jar ../libs/document-extractor.jar
```

### Running Tests
```bash
bal test
```

### Hot Reload Development
```bash
bal run --observability-included
```

## 📊 Performance Features

- **Connection Pooling**: PostgreSQL connection optimization
- **Async Processing**: Non-blocking document processing
- **Vector Search**: Optimized embedding queries
- **Caching**: Strategic caching for frequent operations
- **Batch Processing**: Efficient bulk operations

## 🔍 Monitoring & Observability

- **Health Checks**: `/api/health` endpoint
- **Structured Logging**: Comprehensive log levels
- **Metrics**: Built-in Ballerina observability
- **Error Tracking**: Detailed error responses
- **Performance Monitoring**: Request/response timing

## 🔐 Security

- **Input Validation**: Comprehensive data validation
- **SQL Injection Prevention**: Parameterized queries
- **CORS Configuration**: Proper cross-origin setup
- **Rate Limiting**: API throttling
- **Authentication**: Service-to-service security

## 🌟 Ballerina Language Features Showcase

This backend demonstrates advanced Ballerina capabilities:

- **Java Interop**: Seamless integration with custom Java libraries
- **HTTP Services**: RESTful API design with Ballerina's HTTP module
- **Database Integration**: Native PostgreSQL support
- **Error Handling**: Ballerina's built-in error handling
- **Type Safety**: Strong typing with union types and records
- **Async Processing**: Non-blocking I/O operations
- **Configuration Management**: Flexible configuration system

## 📈 Scalability

- **Horizontal Scaling**: Stateless service design
- **Database Optimization**: Efficient query patterns
- **Resource Management**: Proper connection lifecycle
- **Async Architecture**: Non-blocking operations
- **Microservice Ready**: Independent service components

This backend showcases the power of Ballerina for building modern, cloud-native APIs with seamless Java integration capabilities, making it an ideal choice for complex document processing and AI-powered applications.