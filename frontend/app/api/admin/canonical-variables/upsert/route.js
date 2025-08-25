export async function POST(req) {
  try {
    const base = process.env.NEXT_PUBLIC_API_BASE || 'http://localhost:5000';
    const body = await req.json().catch(() => ({}));
  const upstream = await fetch(`${base}/api/v1/admin/canonical_variables/upsert`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(body || {}),
    });
    const contentType = upstream.headers.get('content-type') || 'application/json';
    const text = await upstream.text();
    return new Response(text, { status: upstream.status, headers: { 'content-type': contentType } });
  } catch (e) {
    return Response.json({ success: false, error: e?.message || 'Upsert proxy failed' }, { status: 500 });
  }
}

export function GET() {
  return Response.json({ success: false, error: 'Method Not Allowed' }, { status: 405 });
}
