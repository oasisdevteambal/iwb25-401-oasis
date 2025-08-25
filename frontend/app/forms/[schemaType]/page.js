import FormRenderer from "@/components/FormRenderer";
import FormErrorState from "@/components/FormErrorState";

async function fetchSchema(schemaType) {
  const url = `${process.env.NEXT_PUBLIC_API_BASE || "http://localhost:5000"}/api/v1/forms/current?schemaType=${encodeURIComponent(schemaType)}`;
  const res = await fetch(url, { cache: "no-store" });
  if (!res.ok) {
    throw new Error(`Failed to load schema: ${res.status}`);
  }
  console.log(res);
  const data = await res.json();
  const raw = data?.schema?.schema_data;
  const schemaBlob = typeof raw === "string" ? JSON.parse(raw) : raw;
  const meta = schemaBlob?.metadata || {};
  return { schemaBlob, meta };
}

export default async function Page({ params }) {
  const { schemaType } = await params;
  try {
    const { schemaBlob, meta } = await fetchSchema(schemaType);
    const ver = meta?.version ?? "—";
    const genAt = meta?.generatedAt || "—";
    const tgt = meta?.targetDate || "—";
    
    return (
      <div className="bg-gray-50 min-h-screen">
        <div className="mx-auto max-w-4xl">
          {/* Form Header */}
          <div className="bg-white border-b border-gray-200 px-6 py-4">
            <div className="flex items-center justify-between">
              <div>
                <nav className="text-sm text-gray-500 mb-1">
                  <a href="/" className="hover:text-blue-600">Home</a> / 
                  <a href="/forms" className="hover:text-blue-600"> Forms</a> / 
                  <span className="capitalize"> {schemaType.replaceAll("_", " ")}</span>
                </nav>
                <h1 className="text-2xl font-bold text-gray-900 capitalize">
                  {schemaType.replaceAll("_", " ")} Tax Return
                </h1>
                
                {/* Progress indicator removed (no dummy data) */}
              </div>
              
              <div className="flex items-center gap-3">
                <button className="btn btn-secondary text-sm">Save Draft</button>
                <button className="btn btn-secondary text-sm">Exit</button>
              </div>
            </div>
          </div>

          {/* Schema Version Notice */}
          <div className="bg-blue-50 border-b border-blue-200 px-6 py-3">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-4 text-sm">
                <div className="flex items-center gap-2">
                  <div className="w-2 h-2 bg-green-500 rounded-full"></div>
                  <span className="font-medium text-blue-900">Active Schema v{ver}</span>
                </div>
                <span className="text-blue-700">Generated {genAt}</span>
                <span className="text-blue-700">Target date {tgt}</span>
              </div>
              
              <div className="flex items-center gap-2">
                <span className="badge badge-success text-xs">High Confidence</span>
                <button className="text-blue-600 hover:text-blue-800 text-sm font-medium">
                  Schema Details
                </button>
              </div>
            </div>
          </div>

          <div className="p-6">
            <FormRenderer
              schemaBlob={schemaBlob}
              schemaType={schemaType}
              targetDate={tgt}
              apiBase={process.env.NEXT_PUBLIC_API_BASE || "http://localhost:5000"}
            />
          </div>
        </div>
      </div>
    );
  } catch (e) {
    return <FormErrorState schemaType={schemaType} error={e} />;
  }
}
