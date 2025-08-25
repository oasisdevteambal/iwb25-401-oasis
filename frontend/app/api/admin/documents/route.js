export async function GET(req) {
  try {
    const base = process.env.NEXT_PUBLIC_API_BASE || 'http://localhost:5000';
    const { searchParams } = new URL(req.url);
    const limit = searchParams.get('limit') || '';
    const offset = searchParams.get('offset') || '';
    const q = searchParams.get('q') || '';
    const url = new URL(`${base}/api/v1/documents/list`);
    if (limit) url.searchParams.set('limit', limit);
    if (offset) url.searchParams.set('offset', offset);
    if (q) url.searchParams.set('q', q);

    const upstream = await fetch(url, { cache: 'no-store' });
    const contentType = upstream.headers.get('content-type') || 'application/json';
    const text = await upstream.text();
    return new Response(text, { status: upstream.status, headers: { 'content-type': contentType } });
  } catch (e) {
    return Response.json({ success: false, error: e?.message || 'Documents proxy failed' }, { status: 500 });
  }
}
