export async function GET() {
  try {
    const base = process.env.NEXT_PUBLIC_API_BASE || "http://localhost:5000";
    const [docRes, formsIncome] = await Promise.all([
      fetch(`${base}/api/v1/documents/summary`, { cache: 'no-store' }),
      fetch(`${base}/api/v1/forms/current?schemaType=income_tax`, { cache: 'no-store' })
    ]);

    let totalDocuments = 0;
    let successfulExtractions = 0;
    let activeSchemas = 0;
    let pendingProcessing = 0;

    if (docRes.ok) {
      const d = await docRes.json().catch(() => null);
      totalDocuments = d?.totalDocuments || 0;
      successfulExtractions = d?.processedDocuments || 0;
      pendingProcessing = d?.pendingDocuments || 0;
    }
    if (formsIncome.ok) {
      const s = await formsIncome.json().catch(() => null);
      activeSchemas = s?.schema ? 1 : 0;
    }

    return Response.json({ success: true, totalDocuments, successfulExtractions, activeSchemas, pendingProcessing });
  } catch (e) {
    return Response.json({ success: false, error: e?.message || 'Failed to load admin summary' }, { status: 500 });
  }
}
