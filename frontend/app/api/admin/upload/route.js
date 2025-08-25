export const dynamic = 'force-dynamic';

export async function POST(request) {
  try {
    const formData = await request.formData();
    const file = formData.get('file');
    const filename = formData.get('filename') || (file && file.name) || 'document.pdf';
  const schemaType = formData.get('schemaType');
    if (!file) {
      return new Response(JSON.stringify({ success: false, error: 'No file provided' }), { status: 400 });
    }

  const backendBase = process.env.NEXT_PUBLIC_API_BASE || 'http://localhost:5000';
  const backendUrl = `${backendBase}/api/v1/documents/upload`;

    const upstream = new FormData();
    upstream.append('file', file);
    upstream.append('filename', filename);
  if (schemaType) upstream.append('schemaType', schemaType);

    const res = await fetch(backendUrl, { method: 'POST', body: upstream });
    const text = await res.text();

    let data;
    try { data = JSON.parse(text); } catch { data = { raw: text }; }

    return new Response(JSON.stringify(data), { status: res.status, headers: { 'content-type': 'application/json' } });
  } catch (e) {
    return new Response(JSON.stringify({ success: false, error: e.message || 'Upload failed' }), { status: 500 });
  }
}
