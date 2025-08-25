export async function GET(req) {
  try {
    const base = process.env.NEXT_PUBLIC_API_BASE || 'http://localhost:5000';
    const { searchParams } = new URL(req.url);
    const docId = searchParams.get('docId') || '';
    const status = searchParams.get('status') || '';
  const schemaType = searchParams.get('schemaType') || '';
    const url = new URL(`${base}/api/v1/admin/proposals`);
    if (docId) url.searchParams.set('docId', docId);
    if (status) url.searchParams.set('status', status);
  if (schemaType) url.searchParams.set('schemaType', schemaType);
    const upstream = await fetch(url, { cache: 'no-store' });
    const contentType = upstream.headers.get('content-type') || 'application/json';
    const text = await upstream.text();
    return new Response(text, { status: upstream.status, headers: { 'content-type': contentType } });
  } catch (e) {
    return Response.json({ success: false, error: e?.message || 'Proposals proxy failed' }, { status: 500 });
  }
}

