export async function POST(req) {
  try {
    const payload = await req.json();
    const base = process.env.NEXT_PUBLIC_API_BASE || "http://localhost:5000";
    const upstream = `${base}/api/v1/admin/aggregate`;

    const res = await fetch(upstream, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });

    const contentType = res.headers.get("content-type") || "application/json";
    const text = await res.text();
    return new Response(text, {
      status: res.status,
      headers: { "content-type": contentType },
    });
  } catch (e) {
    return Response.json(
      { success: false, code: "PROXY_ERROR", message: e?.message || "Proxy failed" },
      { status: 500 }
    );
  }
}
