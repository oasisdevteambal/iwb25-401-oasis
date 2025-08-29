import { NextResponse } from 'next/server';

const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:9090';

export async function POST(request) {
  try {
    const body = await request.json();
    
    // Validate request body
    if (!body.question || typeof body.question !== 'string') {
      return NextResponse.json(
        { success: false, error: 'Question is required' },
        { status: 400 }
      );
    }

    const backendUrl = `${BACKEND_URL}/api/v1/chat/ask`;
    console.log('Attempting to connect to:', backendUrl);

    // Forward request to Ballerina backend
    const response = await fetch(backendUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        question: body.question,
        schemaType: body.schemaType || null,
        date: body.date || null,
        variable: body.variable || null,
        conversationContext: body.conversationContext || "",
        conversationSummary: body.conversationSummary || "",
      }),
    });

    if (!response.ok) {
      console.error('Backend response error:', response.status, response.statusText);
      const errorText = await response.text();
      console.error('Backend error details:', errorText);
      
      return NextResponse.json(
        { 
          success: false, 
          error: `Backend service error: ${response.status}`,
          intent: 'error',
          answer: 'Sorry, I encountered an error. Please try again.',
          details: errorText
        },
        { status: response.status }
      );
    }

    const data = await response.json();
    console.log('Backend response success:', data);
    return NextResponse.json(data);
  } catch (error) {
    console.error('Chat API error:', error);
    
    // More specific error messages
    let errorMessage = 'Internal server error';
    let userMessage = 'Sorry, I encountered a connection error. Please try again later.';
    
    if (error.code === 'ECONNREFUSED') {
      errorMessage = 'Backend service is not running';
      userMessage = 'The chat service is currently unavailable. Please make sure the backend is running on port 5000.';
    } else if (error.name === 'TypeError' && error.message.includes('fetch failed')) {
      errorMessage = 'Network connection failed';
      userMessage = 'Unable to connect to the chat service. Please check your network connection.';
    }
    
    return NextResponse.json(
      { 
        success: false, 
        error: errorMessage,
        intent: 'error',
        answer: userMessage,
        debug: {
          backendUrl: BACKEND_URL,
          errorCode: error.code,
          errorMessage: error.message
        }
      },
      { status: 500 }
    );
  }
}
