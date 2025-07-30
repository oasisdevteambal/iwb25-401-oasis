# Sri Lankan Tax Calculation Application - Development Guide

## Project Overview

This is a comprehensive web-based tax calculation application specifically designed for Sri Lanka, enabling administrators to manage government tax documentation and end users to easily determine their tax liabilities. The system combines modern web technologies with AI-powered document processing to create dynamic, adaptive tax calculation forms.

## Architecture Overview

### Technology Stack

**Frontend:**
- Next.js with React for responsive UI
- React JSON Schema Form for dynamic form generation
- Tailwind CSS for styling
- TypeScript for type safety

**Backend:**
- Ballerina for API orchestration and business logic
- RESTful API endpoints
- File parsing and document processing

**Data Storage:**
- Supabase (Free tier) for PostgreSQL database with real-time features
- pgvector extension for semantic embeddings
- Supabase Storage for document files

**AI/ML:**
- Google Gemini API (Free tier) for document analysis
- Gemini embeddings for semantic search
- Ollama (local) for offline LLM processing

## Sri Lankan Tax System Context

The application handles multiple types of Sri Lankan taxes:

### Primary Tax Types
1. **Income Tax** - Progressive taxation on individual and corporate income
2. **Value Added Tax (VAT)** - Consumption tax on goods and services  
3. **Pay As You Earn (PAYE)** - Withholding tax on employment income
4. **Withholding Tax (WHT)** - Tax deducted at source on various payments
5. **Nation Building Tax (NBT)** - Additional tax on certain transactions
6. **Social Security Contribution Levy (SSCL)** - Employer and employee contributions

### Key Features for Sri Lankan Context
- Support for multiple tax brackets and rates
- Handling of various deductions and exemptions
- Accommodation for different taxpayer categories (individual, corporate, non-resident)
- Multi-language support (English, Sinhala, Tamil)

## Project Structure

```
tax-app/
├── frontend/                 # Next.js application (App Router)
│   ├── app/                 # App Router directory
│   │   ├── layout.tsx       # Root layout
│   │   ├── page.tsx         # Home page
│   │   ├── admin/           # Admin routes
│   │   │   ├── page.tsx     # Admin dashboard
│   │   │   └── documents/   # Document management
│   │   ├── calculate/       # Tax calculation routes
│   │   │   ├── page.tsx     # Tax calculation form
│   │   │   └── results/     # Results pages
│   │   ├── chat/            # Chat interface
│   │   │   └── page.tsx     # Chat page
│   │   └── api/             # API routes
│   │       ├── documents/   # Document endpoints
│   │       ├── calculate/   # Calculation endpoints
│   │       └── forms/       # Form schema endpoints
│   ├── components/          # React components
│   ├── lib/                 # Utility functions and configurations
│   ├── styles/              # CSS and styling
│   └── types/               # TypeScript definitions
├── backend/                 # Ballerina services
│   ├── services/           # API services
│   ├── modules/            # Business logic modules
│   ├── config/             # Configuration files
│   └── tests/              # Test files
├── database/               # Database schemas and migrations
├── docs/                   # Documentation
└── deployment/             # Deployment configurations
```

## Development Setup

### Prerequisites

1. **Node.js** (v18 or higher)
2. **Ballerina** (latest version)
3. **Supabase account** (free tier)
4. **Google AI Studio** account for Gemini API (free tier)
5. **Git** for version control

### Environment Setup

1. **Clone the repository:**
```bash
git clone <repository-url>
cd tax-app
```

2. **Install frontend dependencies:**
```bash
cd frontend
npm install
```

3. **Set up Ballerina backend:**
```bash
cd backend
bal build
```

4. **Database setup:**
```bash
# No local database needed - using Supabase
# Create project at https://supabase.com
# Get your project URL and anon key
# Enable pgvector extension in SQL editor:
CREATE EXTENSION IF NOT EXISTS vector;

# Run migrations via Supabase dashboard or CLI
```

5. **Environment configuration:**
Create `.env` files in both frontend and backend directories:

**Frontend (.env.local):**
```
NEXT_PUBLIC_SUPABASE_URL=your_supabase_url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_supabase_anon_key
```

**Backend (.env):**
```
SUPABASE_URL=your_supabase_url
SUPABASE_SERVICE_KEY=your_supabase_service_key
GEMINI_API_KEY=your_gemini_api_key
```

## Core Components Development

### 1. Document Upload and Processing Service

**Backend (Ballerina):**
```ballerina
// Document upload endpoint using Supabase Storage
service /api/documents on new http:Listener(8080) {
    resource function post upload(http:Caller caller, http:Request req) returns error? {
        // Handle file upload to Supabase Storage
        // Trigger document processing pipeline
        // Return processing status
    }
    
    resource function post process/[string documentId](http:Caller caller, http:Request req) returns error? {
        // Parse document text
        // Segment content for Gemini LLM processing
        // Extract tax rules using Gemini API
        // Store structured rules in Supabase
        // Generate semantic embeddings with pgvector
    }
}
```

**Key Processing Steps:**
1. File validation and storage
2. Text extraction (PDF/Word)
3. Content segmentation
4. LLM-based rule extraction using Gemini
5. Data structure validation
6. Supabase database persistence
7. pgvector embedding generation and storage

### 2. Tax Rule Management

**Database Schema (Supabase/PostgreSQL with pgvector):**
```sql
-- Enable vector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Tax rules table
CREATE TABLE tax_rules (
    id SERIAL PRIMARY KEY,
    rule_type VARCHAR(50) NOT NULL, -- 'income_tax', 'vat', 'paye', etc.
    rule_category VARCHAR(100),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    rule_data JSONB NOT NULL, -- Structured rule definition
    embedding vector(768), -- Gemini embeddings
    effective_date DATE NOT NULL,
    expiry_date DATE,
    document_source_id INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Enable Row Level Security
ALTER TABLE tax_rules ENABLE ROW LEVEL SECURITY;

-- Tax brackets table
CREATE TABLE tax_brackets (
    id SERIAL PRIMARY KEY,
    rule_id INTEGER REFERENCES tax_rules(id),
    min_income DECIMAL(15,2),
    max_income DECIMAL(15,2),
    rate DECIMAL(5,4) NOT NULL,
    fixed_amount DECIMAL(15,2) DEFAULT 0,
    bracket_order INTEGER
);

-- Form schemas table
CREATE TABLE form_schemas (
    id SERIAL PRIMARY KEY,
    schema_type VARCHAR(50) NOT NULL,
    version INTEGER NOT NULL,
    schema_data JSONB NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Enable RLS for form schemas
ALTER TABLE form_schemas ENABLE ROW LEVEL SECURITY;

-- Create index for vector similarity search
CREATE INDEX ON tax_rules USING ivfflat (embedding vector_cosine_ops)
WITH (lists = 100);
```

### 3. Dynamic Form Generation

**Schema Generation Service:**
```ballerina
import ballerina/http;
import supabase/supabase;

service /api/forms on new http:Listener(8080) {
    resource function get schema/[string taxType](http:Caller caller, http:Request req) returns json|error {
        // Connect to Supabase
        // Retrieve latest tax rules for specified type
        // Generate JSON Schema based on current rules
        // Include validation rules and conditional logic
        // Return schema for frontend form rendering
    }
}
```

**Frontend Form Component (App Router):**
```tsx
"use client";
import { useState, useEffect } from "react";
import Form from "@rjsf/core";
import validator from "@rjsf/validator-ajv8";

const TaxCalculationForm: React.FC = () => {
  const [schema, setSchema] = useState(null);
  const [formData, setFormData] = useState({});

  useEffect(() => {
    // Fetch latest schema from backend
    fetchFormSchema().then(setSchema);
  }, []);

  const handleSubmit = async (data: any) => {
    // Submit form data for tax calculation
    const result = await calculateTax(data.formData);
    // Display results
  };

  return (
    <Form
      schema={schema}
      formData={formData}
      validator={validator}
      onSubmit={handleSubmit}
      onChange={({ formData }) => setFormData(formData)}
    />
  );
};
```

### 4. Tax Calculation Engine

**Calculation Service:**
```ballerina
import ballerina/http;
import supabase/supabase;

service /api/calculate on new http:Listener(8080) {
    resource function post tax(http:Caller caller, http:Request req) returns json|error {
        json userInput = check req.getJsonPayload();
        
        // Connect to Supabase and retrieve applicable tax rules
        // Apply income tax calculations
        // Calculate VAT if applicable
        // Apply deductions and exemptions
        // Generate detailed breakdown
        // Store calculation in Supabase for history
        // Return calculation results with explanations
    }
}
```

**Calculation Logic Examples:**

1. **Income Tax Calculation:**
```ballerina
function calculateIncomeTax(decimal income, TaxBracket[] brackets) returns TaxCalculation {
    decimal totalTax = 0;
    decimal remainingIncome = income;
    TaxBracketCalculation[] bracketCalculations = [];
    
    foreach TaxBracket bracket in brackets {
        if (remainingIncome <= 0) {
            break;
        }
        
        decimal taxableInThisBracket = math:min(remainingIncome, bracket.maxIncome - bracket.minIncome);
        decimal taxForBracket = taxableInThisBracket * bracket.rate + bracket.fixedAmount;
        
        totalTax += taxForBracket;
        remainingIncome -= taxableInThisBracket;
        
        bracketCalculations.push({
            bracket: bracket,
            taxableAmount: taxableInThisBracket,
            taxAmount: taxForBracket
        });
    }
    
    return {
        totalTax: totalTax,
        breakdowns: bracketCalculations
    };
}
```

### 5. Chat Interface (Optional Enhancement)

**Chat Service:**
```ballerina
import ballerina/http;
import supabase/supabase;

service /api/chat on new http:Listener(8080) {
    resource function post message(http:Caller caller, http:Request req) returns json|error {
        json message = check req.getJsonPayload();
        
        // Process user query
        // Use pgvector similarity search for relevant tax information
        // Call Gemini API for contextual response generation
        // Return chat response with relevant forms/calculations
    }
}
```

## API Endpoints

### Document Management
- `POST /api/documents/upload` - Upload tax documents
- `POST /api/documents/process/{documentId}` - Process uploaded document
- `GET /api/documents/{documentId}/status` - Check processing status

### Form Schema
- `GET /api/forms/schema/{taxType}` - Get form schema for tax type
- `GET /api/forms/schema/latest` - Get latest combined schema

### Tax Calculation
- `POST /api/calculate/tax` - Calculate tax based on user input
- `POST /api/calculate/estimate` - Get tax estimate
- `GET /api/calculate/brackets/{taxType}` - Get current tax brackets

### Administration
- `GET /api/admin/rules` - List all tax rules
- `PUT /api/admin/rules/{ruleId}` - Update tax rule
- `DELETE /api/admin/rules/{ruleId}` - Delete tax rule
- `GET /api/admin/documents` - List processed documents

## Frontend Development

### Key Components

1. **DocumentUpload.tsx** - Admin document upload interface
2. **TaxCalculationForm.tsx** - Dynamic tax calculation form  
3. **ResultsDisplay.tsx** - Tax calculation results and breakdown
4. **ChatInterface.tsx** - Optional chat-based interaction
5. **AdminDashboard.tsx** - Administrative interface for rule management

### App Router Structure
```
app/
├── layout.tsx              # Root layout with providers
├── page.tsx                # Landing/home page
├── loading.tsx             # Global loading UI
├── error.tsx               # Global error UI
├── not-found.tsx           # 404 page
├── admin/
│   ├── layout.tsx          # Admin layout
│   ├── page.tsx            # Admin dashboard
│   ├── documents/
│   │   ├── page.tsx        # Document management
│   │   └── upload/
│   │       └── page.tsx    # Document upload
│   └── rules/
│       ├── page.tsx        # Rule management
│       └── [id]/
│           └── page.tsx    # Edit specific rule
├── calculate/
│   ├── layout.tsx          # Calculation layout
│   ├── page.tsx            # Tax calculation form
│   ├── loading.tsx         # Calculation loading
│   └── results/
│       └── page.tsx        # Results display
├── chat/
│   ├── page.tsx            # Chat interface
│   └── loading.tsx         # Chat loading
└── api/                    # API routes
    ├── documents/
    │   ├── route.ts         # POST /api/documents
    │   ├── upload/
    │   │   └── route.ts     # POST /api/documents/upload
    │   └── [id]/
    │       ├── route.ts     # GET /api/documents/[id]
    │       └── process/
    │           └── route.ts # POST /api/documents/[id]/process
    ├── calculate/
    │   ├── route.ts         # POST /api/calculate
    │   └── brackets/
    │       └── [type]/
    │           └── route.ts # GET /api/calculate/brackets/[type]
    └── forms/
        └── schema/
            ├── route.ts     # GET /api/forms/schema
            └── [type]/
                └── route.ts # GET /api/forms/schema/[type]
```

### State Management
Use React Context, Zustand, or Redux Toolkit for managing:
- User session and authentication
- Form data and validation states
- Tax calculation results
- Document processing status

**Example with App Router Context:**
```tsx
// app/providers.tsx
"use client";
import { createContext, useContext, useReducer } from 'react';

const AppContext = createContext();

export function AppProviders({ children }: { children: React.ReactNode }) {
  const [state, dispatch] = useReducer(appReducer, initialState);
  
  return (
    <AppContext.Provider value={{ state, dispatch }}>
      {children}
    </AppContext.Provider>
  );
}

// app/layout.tsx
import { AppProviders } from './providers';

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <AppProviders>
          {children}
        </AppProviders>
      </body>
    </html>
  );
}
```

### Responsive Design
- Mobile-first approach
- Support for tablets and desktops
- Accessibility compliance (WCAG 2.1)
- Multi-language support

### App Router Features
- **Server Components** - Default server rendering for better performance
- **Client Components** - Interactive components with "use client" directive
- **Streaming** - Progressive rendering with loading.tsx
- **Error Boundaries** - Automatic error handling with error.tsx
- **Nested Layouts** - Shared UI across route groups
- **Route Groups** - Organize routes without affecting URL structure
- **Parallel Routes** - Display multiple pages simultaneously
- **Intercepting Routes** - Override routes in certain contexts

## Database Design

### Core Tables
1. **tax_rules** - Store extracted tax rules with vector embeddings
2. **tax_brackets** - Tax bracket definitions
3. **form_schemas** - JSON schemas for dynamic forms
4. **documents** - Metadata for uploaded documents (Supabase Storage refs)
5. **calculations** - Historical tax calculations
6. **users** - User management with Supabase Auth

### Database Features
- Row Level Security (RLS) for data protection
- Real-time subscriptions for live updates
- Built-in authentication and authorization
- Vector similarity search with pgvector
- Automatic API generation

## Vector Database Integration

### Embedding Generation with Gemini
```ballerina
import ballerina/http;

function generateEmbeddings(string text) returns float[]|error {
    // Call Gemini embeddings API
    http:Client geminiClient = check new("https://generativelanguage.googleapis.com");
    
    json payload = {
        "content": {
            "parts": [{"text": text}]
        }
    };
    
    http:Response response = check geminiClient->post("/v1/models/embedding-001:embedText", payload);
    // Process response and return vector representation
    return []; // Return actual embedding vector
}
```

### Semantic Search with pgvector
```ballerina
function semanticSearch(string query, int limit = 10) returns SearchResult[]|error {
    // Generate query embedding using Gemini
    float[] queryVector = check generateEmbeddings(query);
    
    // Search Supabase using pgvector similarity
    // SELECT *, embedding <-> $1 as distance 
    // FROM tax_rules 
    // ORDER BY distance 
    // LIMIT $2
    
    // Return ranked results with relevance scores
    return [];
}
```

## Testing Strategy

### Unit Tests
- Test individual calculation functions
- Validate form schema generation
- Test document processing pipeline

### Integration Tests
- End-to-end API testing
- Database operation testing
- File upload and processing workflows

### UI Tests
- Component rendering tests
- Form validation testing
- User interaction flows

## Local Development

### Running the Application Locally

1. **Start Supabase project:**
```bash
# No local database needed
# Access your Supabase dashboard at https://supabase.com
# Your database is automatically running in the cloud
```

2. **Start the Ballerina backend:**
```bash
cd backend
bal run
# Backend will run on http://localhost:8080
```

3. **Start the frontend development server:**
```bash
cd frontend
npm run dev
# Frontend will run on http://localhost:3000
```

4. **Access the application:**
   - Frontend: http://localhost:3000
   - Backend API: http://localhost:8080
   - Supabase Dashboard: https://supabase.com/dashboard
   - Database: Managed by Supabase (no local access needed)

### Development Workflow
1. Make changes to your code
2. Both frontend and backend support hot reloading
3. Test your changes locally
4. Run tests before committing changes

## Local Security Considerations

### Development Security
- Use environment variables for API keys and secrets
- Never commit sensitive data to version control
- Use HTTPS for external API calls even in development
- Validate all inputs to prevent injection attacks

### Local Environment Variables
Create `.env.local` files for:
- Supabase project URL and keys
- Gemini API keys (free tier)
- Supabase Storage bucket configuration
- Local development settings

## Local Development Monitoring

### Development Debugging
- Use console.log() for frontend debugging
- Use Ballerina's built-in logging for backend
- Use Supabase dashboard for database monitoring
- Monitor Gemini API usage and quotas
- Test Supabase Storage uploads and retrievals
- Validate pgvector similarity searches manually

### Local Testing
- Run unit tests: `npm test` (frontend) and `bal test` (backend)
- Use Postman or similar tools for API testing
- Test database connections with Supabase client
- Validate Gemini API responses and rate limits
- Check Supabase Storage file operations

## Local Development Maintenance

### Code Organization
- Keep components modular and reusable
- Follow consistent naming conventions
- Document complex business logic
- Maintain clean git commit history

### Local Tax Rule Updates
- Test rule changes with sample data
- Validate schema generation after rule updates
- Ensure backward compatibility during development
- Keep test data synchronized with rule changes

## Local Development Optimization

### Frontend Development Tips
- Use React Developer Tools for debugging
- Enable source maps for easier debugging
- Use hot module replacement for faster development
- Keep bundle sizes reasonable for development speed

### Backend Development Tips
- Use Supabase connection pooling for development
- Implement proper error handling for Gemini API calls
- Test with realistic data volumes in Supabase
- Profile expensive vector operations locally

## Local Development Documentation

### Code Documentation
- Comment complex business logic
- Document API endpoints with examples
- Maintain README files for each module
- Keep Supabase schema documentation updated
- Document Gemini API integration patterns
- Note free tier limitations and usage

### Development Notes
- Document known issues and workarounds
- Keep track of configuration changes
- Note dependencies and their purposes
- Maintain a local development changelog

## Development Roadmap

### Core Features to Implement First
1. **Basic Tax Calculation** - Start with simple income tax calculations
2. **Document Upload** - Implement file upload without LLM processing initially
3. **Static Forms** - Create basic forms before making them dynamic
4. **Database CRUD** - Implement basic database operations
5. **API Integration** - Connect frontend to backend APIs

### Advanced Features for Later
1. **LLM Integration** - Add Gemini-powered document processing
2. **Dynamic Form Generation** - Implement schema-based forms with Supabase
3. **Vector Database** - Add pgvector semantic search capabilities
4. **Chat Interface** - Build conversational tax assistance with Gemini
5. **Multi-language Support** - Add Sinhala and Tamil support

### Development Phases
- **Phase 1**: Basic functionality with Supabase and core features
- **Phase 2**: Gemini AI integration and advanced features
- **Phase 3**: Polish, optimization, and additional features

## Local Development Troubleshooting

### Common Development Issues

1. **Database Connection Problems**
   - Check Supabase project status and connectivity
   - Verify API keys and project URL in environment variables
   - Ensure Supabase project is not paused (free tier limitation)
   - Test connection using Supabase client libraries

2. **Frontend Build Errors**
   - Clear node_modules and reinstall: `rm -rf node_modules && npm install`
   - Check for TypeScript errors in the console
   - Verify all imports are correct
   - Restart the development server

3. **Ballerina Backend Issues**
   - Check for compilation errors: `bal build`
   - Verify all dependencies are correctly imported
   - Check port conflicts (default 8080)
   - Review Ballerina logs for runtime errors

4. **API Integration Problems**
   - Verify backend is running and accessible
   - Check CORS configuration for cross-origin requests
   - Validate Gemini API key and quotas
   - Check Supabase RLS policies for data access
   - Use browser network tab to debug HTTP requests

5. **Gemini API Issues**
   - Verify API key is valid and has quota remaining
   - Check rate limiting and retry logic
   - Validate request format for Gemini API
   - Monitor API usage in Google AI Studio console

### Development Debug Tools
- **Frontend**: React Developer Tools, browser console
- **Backend**: Ballerina logs, HTTP client tools (Postman/Insomnia)
- **Database**: Supabase Dashboard, SQL Editor, Table Editor
- **Storage**: Supabase Storage interface
- **Network**: Browser developer tools, network monitoring
- **AI**: Google AI Studio for Gemini API testing

### Quick Fixes
- **Port already in use**: Change port in configuration or kill existing process
- **Module not found**: Check import paths and installed dependencies
- **Supabase schema errors**: Use Supabase Dashboard to fix schema issues
- **Environment variables**: Verify .env files are loaded correctly
- **Gemini API errors**: Check API quotas and request formatting

## Local Development Checklist

### Initial Setup
- [ ] Install Node.js, Ballerina
- [ ] Create Supabase account and project
- [ ] Get Gemini API key from Google AI Studio
- [ ] Clone repository and set up project structure
- [ ] Set up Supabase database schema and enable pgvector
- [ ] Configure environment variables for Supabase and Gemini

### Core Development Tasks
- [ ] Set up Supabase database schema for tax rules with pgvector
- [ ] Create Supabase Storage bucket for file uploads
- [ ] Implement basic tax calculation logic
- [ ] Build frontend components for tax forms
- [ ] Connect frontend to Supabase and backend APIs
- [ ] Add basic form validation and error handling

### Advanced Development Tasks
- [ ] Integrate Gemini API for document processing
- [ ] Implement dynamic form generation from Supabase schemas
- [ ] Set up pgvector semantic search with embeddings
- [ ] Add comprehensive error handling and logging
- [ ] Implement local testing suite with Supabase local dev
- [ ] Create development documentation for free tier usage

### Testing and Validation
- [ ] Test all API endpoints with sample data using Supabase
- [ ] Validate tax calculations with known test cases
- [ ] Test file upload and processing workflow with Supabase Storage
- [ ] Verify form generation and validation with dynamic schemas
- [ ] Check Supabase operations and data integrity with RLS
- [ ] Test error handling and edge cases with free tier limitations

This guide focuses on local development using entirely free technologies to help you build and test the Sri Lankan tax calculation application on your development machine. Each component uses free tiers and open-source solutions, making it cost-effective for development and testing.
