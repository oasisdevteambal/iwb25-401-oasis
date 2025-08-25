export async function GET() {
  try {
    const base = process.env.NEXT_PUBLIC_API_BASE || "http://localhost:5000";
    const types = [
      { id: 'income_tax', title: 'Income Tax', description: 'Personal income tax calculations and deductions' },
      { id: 'paye', title: 'PAYE', description: 'Pay As You Earn tax calculations' },
      { id: 'vat', title: 'VAT', description: 'Value Added Tax calculations and returns' },
    ];

  const results = await Promise.all(types.map(async t => {
      const url = `${base}/api/v1/forms/current?schemaType=${encodeURIComponent(t.id)}`;
      const res = await fetch(url, { cache: 'no-store' });
      console.log(`Fetching schema for ${t.id} from ${url}`);
      if (!res.ok) return null;
      const data = await res.json().catch(() => null);
      const schema = data?.schema?.schema_data || data?.schema?.schema || data?.schema_data || data?.schema;
      const version = data?.schema?.version ?? data?.version ?? null;
      const generatedAt = schema?.metadata?.generatedAt ?? null;
      console.log(`Fetched schema for ${t.id} at ${generatedAt} , ${JSON.stringify(schema)}, ${version}, ${data}`);
      // Normalize generatedAt to ISO string if possible (backend may return "[seconds,nanos]")
      let lastUpdated = null;
      if (typeof generatedAt === 'string') {
        // Try ISO parse first
        const iso = Date.parse(generatedAt);
        if (!Number.isNaN(iso)) {
          lastUpdated = new Date(iso).toISOString();
        } else {
          // Try bracketed epoch format: [1234567890,0.123456789]
          const m = generatedAt.match(/^\[(\d+),(\d+(?:\.\d+)?)\]$/);
          if (m) {
            const sec = Number(m[1]);
            if (Number.isFinite(sec)) {
              lastUpdated = new Date(sec * 1000).toISOString();
            }
          }
        }
      } else if (typeof generatedAt === 'number') {
        // Assume seconds since epoch if < 10^12 else ms
        const ms = generatedAt < 1e12 ? generatedAt * 1000 : generatedAt;
        lastUpdated = new Date(ms).toISOString();
      }
      return {
        href: `/forms/${t.id}`,
        id: t.id,
        title: t.title,
        description: t.description,
        version: version ? `v${version}` : 'active',
        lastUpdated,
        status: 'active'
      };
    }));

    const forms = results.filter(Boolean);
    return Response.json({ success: true, forms });
  } catch (e) {
    return Response.json({ success: false, error: e?.message || 'Failed to load forms' }, { status: 500 });
  }
}
