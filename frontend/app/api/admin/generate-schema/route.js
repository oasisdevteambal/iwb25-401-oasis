export async function POST(req) {
  try {
    const base = process.env.NEXT_PUBLIC_API_BASE || 'http://localhost:5000';
    const body = await req.json().catch(() => ({}));
    const schemaType = body?.schemaType || body?.type || '';
    const date = body?.date || '';
    const url = new URL(`${base}/api/v1/admin/generate-schema`);
    if (schemaType) url.searchParams.set('schemaType', schemaType);
    if (date) url.searchParams.set('date', date);

    // Backend expects query params; body can be empty
    const upstream = await fetch(url, { method: 'POST' });
    const contentType = upstream.headers.get('content-type') || 'application/json';
    const text = await upstream.text();
    return new Response(text, { status: upstream.status, headers: { 'content-type': contentType } });
  } catch (e) {
    return Response.json({ success: false, error: e?.message || 'Generate schema proxy failed' }, { status: 500 });
  }
}
