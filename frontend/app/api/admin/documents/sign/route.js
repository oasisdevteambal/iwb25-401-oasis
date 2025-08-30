export async function GET(req) {
  try {
    const base = process.env.NEXT_PUBLIC_API_BASE || 'http://localhost:5000';
    const { searchParams } = new URL(req.url);
    const file_path = searchParams.get('file_path');
    const expiresIn = searchParams.get('expiresIn') || '';
    if (!file_path) {
      return Response.json({ success: false, error: 'file_path is required' }, { status: 400 });
    }
    const url = new URL(`${base}/api/v1/documents/sign`);
    url.searchParams.set('file_path', file_path);
    if (expiresIn) url.searchParams.set('expiresIn', expiresIn);

    const upstream = await fetch(url, { cache: 'no-store' });
    const contentType = upstream.headers.get('content-type') || 'application/json';
    const text = await upstream.text();
    return new Response(text, { status: upstream.status, headers: { 'content-type': contentType } });
  } catch (e) {
    return Response.json({ success: false, error: e?.message || 'Sign proxy failed' }, { status: 500 });
  }
}
