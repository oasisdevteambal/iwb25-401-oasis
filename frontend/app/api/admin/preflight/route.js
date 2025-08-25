export async function GET(req) {
  try {
    const { searchParams } = new URL(req.url);
    const schemaType = searchParams.get('schemaType');
    const date = searchParams.get('date');
    if (!schemaType) {
      return Response.json({ success: false, error: 'schemaType required' }, { status: 400 });
    }
    const base = process.env.NEXT_PUBLIC_API_BASE || 'http://localhost:5000';
    const url = new URL(`${base}/api/v1/admin/preflight`);
    url.searchParams.set('schemaType', schemaType);
    if (date) url.searchParams.set('date', date);

    const res = await fetch(url, { cache: 'no-store' });
    const contentType = res.headers.get('content-type') || 'application/json';
    const text = await res.text();
    return new Response(text, { status: res.status, headers: { 'content-type': contentType } });
  } catch (e) {
    return Response.json({ success: false, error: e?.message || 'Preflight failed' }, { status: 500 });
  }
}
