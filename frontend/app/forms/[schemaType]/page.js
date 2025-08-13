import FormRenderer from "@/components/FormRenderer";

async function fetchSchema(schemaType) {
  const url = `${process.env.NEXT_PUBLIC_API_BASE || "http://localhost:5000"}/api/v1/forms/current?schemaType=${encodeURIComponent(schemaType)}`;
  const res = await fetch(url, { cache: "no-store" });
  if (!res.ok) {
    throw new Error(`Failed to load schema: ${res.status}`);
  }
  const data = await res.json();
  const raw = data?.schema?.schema_data;
  const schemaBlob = typeof raw === "string" ? JSON.parse(raw) : raw;
  const meta = schemaBlob?.metadata || {};
  return { schemaBlob, meta };
}

export default async function Page({ params }) {
  const { schemaType } = await params;
  const { schemaBlob, meta } = await fetchSchema(schemaType);
  return (
    <div className="mx-auto max-w-3xl p-6">
      <h1 className="mb-2 text-2xl font-semibold capitalize">{schemaType.replaceAll("_", " ")} form</h1>
      <p className="mb-6 text-sm text-gray-600">
        Versioned dynamic form • Target date: {meta.targetDate || "—"} • Generated at: {meta.generatedAt || "—"}
      </p>
      <FormRenderer schemaBlob={schemaBlob} />
    </div>
  );
}
