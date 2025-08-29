import { NextResponse } from 'next/server';

const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:5000';

export async function GET() {
  try {
    const response = await fetch(`${BACKEND_URL}/api/health`, {
      method: 'GET',
      headers: {
        'Accept': 'application/json',
      },
    });

    if (response.ok) {
      const data = await response.json();
      return NextResponse.json({
        healthy: true,
        details: data
      });
    } else {
      return NextResponse.json({
        healthy: false,
        error: `Backend returned ${response.status}: ${response.statusText}`
      }, { status: 503 });
    }
  } catch (error) {
    console.error('Backend health check failed:', error);
    
    let errorMessage = 'Backend service unavailable';
    if (error.code === 'ECONNREFUSED') {
      errorMessage = 'Backend service is not running on port 5000';
    }
    
    return NextResponse.json({
      healthy: false,
      error: errorMessage,
      debug: {
        backendUrl: BACKEND_URL,
        errorCode: error.code,
        errorMessage: error.message
      }
    }, { status: 503 });
  }
}
