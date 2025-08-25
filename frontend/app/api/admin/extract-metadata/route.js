export const runtime = 'nodejs';

export async function POST(req) {
  try {
    const base = process.env.NEXT_PUBLIC_API_BASE || 'http://localhost:5000';
    const body = await req.json().catch(() => ({}));
    const { docId, schemaType } = body || {};
    if (!docId || !schemaType) {
      return Response.json({ success: false, error: 'docId and schemaType required' }, { status: 400 });
    }
    const url = new URL(`${base}/api/v1/admin/extract-metadata`);
    url.searchParams.set('docId', String(docId));
    url.searchParams.set('schemaType', String(schemaType));

  const controller = new AbortController();
  const timeoutMs = Number.parseInt(process.env.ADMIN_EXTRACT_TIMEOUT_MS || '60000', 10) || 60000;
    const to = setTimeout(() => controller.abort(), timeoutMs);
    const started = Date.now();
  const upstreamRes = await fetch(url, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({}),
      signal: controller.signal
    }).finally(() => clearTimeout(to));
    const elapsed = Date.now() - started;
    if (elapsed > 25000) {
      console.warn(`[extract-metadata] Slow upstream response: ${elapsed}ms`);
    }
    const contentType = upstreamRes.headers.get('content-type') || 'application/json';
    const text = await upstreamRes.text();
    return new Response(text, { status: upstreamRes.status, headers: { 'content-type': contentType } });
  } catch (e) {
    const name = e?.name || 'Error';
    const msg = e?.message || 'Extraction proxy failed';
    const isAbort = name === 'AbortError' || msg.includes('aborted');
    if (isAbort) {
      console.error('[extract-metadata] Proxy aborted:', { name, msg });
      return Response.json({ success: false, error: 'Proxy timeout waiting for backend' }, { status: 504 });
    }
    console.error('[extract-metadata] Proxy error:', name, msg);
    return Response.json({ success: false, error: msg }, { status: 500 });
  }
}
