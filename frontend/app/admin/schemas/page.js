"use client";
import { useEffect, useState } from "react";

export default function SchemasPage() {
  const [selectedSchema, setSelectedSchema] = useState("income_tax");
  const [activeTab, setActiveTab] = useState("overview");
  const [schemas, setSchemas] = useState([]);
  const [fields, setFields] = useState([]);
  const [versionInfo, setVersionInfo] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    let cancelled = false;
    async function load() {
      setLoading(true); setError("");
      try {
  const base = '';
        const types = [
          { id: 'income_tax', name: 'Income Tax' },
          { id: 'paye', name: 'PAYE' },
          { id: 'vat', name: 'VAT' },
        ];
        const results = await Promise.all(types.map(async t => {
          const res = await fetch(`${base}/api/forms/schema?schemaType=${t.id}`, { cache: 'no-store' });
          if (!res.ok) return { id: t.id, name: t.name, activeVersion: '—', status: 'draft', fieldCount: 0, lastUpdated: null };
          const data = await res.json().catch(() => null);
          const schema = data?.schema?.schema_data || data?.schema?.schema || data?.schema_data || data?.schema;
          const props = schema?.jsonSchema?.properties || {};
          const fieldCount = Object.keys(props).length;
          const lastUpdated = schema?.metadata?.generatedAt || null;
          const version = data?.schema?.version ?? data?.version ?? null;
          return { id: t.id, name: t.name, activeVersion: version ? `v${version}` : 'active', status: 'stable', fieldCount, lastUpdated };
        }));
        if (!cancelled) setSchemas(results);
      } catch (e) {
        if (!cancelled) setError('Failed to load schemas');
      } finally {
        if (!cancelled) setLoading(false);
      }
    }
    load();
    return () => { cancelled = true; };
  }, []);

  useEffect(() => {
    let cancelled = false;
    async function loadDetails() {
      setFields([]); setVersionInfo([]);
      try {
  const base = '';
  const res = await fetch(`${base}/api/forms/schema?schemaType=${selectedSchema}`, { cache: 'no-store' });
        if (!res.ok) return;
        const data = await res.json().catch(() => null);
        const schema = data?.schema?.schema_data || data?.schema?.schema || data?.schema_data || data?.schema;
        const props = schema?.jsonSchema?.properties || {};
        const req = schema?.jsonSchema?.required || [];
        const fieldsArr = Object.entries(props).map(([name, meta]) => ({
          name,
          type: meta?.type || 'string',
          required: req.includes(name),
          validation: meta?.minimum !== undefined ? `minimum: ${meta.minimum}` : (meta?.pattern ? `pattern: ${meta.pattern}` : ''),
          sourceRule: (schema?.metadata?.sourceRuleIds || []).join(', '),
          confidence: 1
        }));
        if (!cancelled) setFields(fieldsArr);
        const ver = data?.schema?.version ?? data?.version ?? null;
        if (!cancelled) setVersionInfo([{ version: ver ? `v${ver}` : 'active', date: schema?.metadata?.generatedAt || '', author: 'system', description: 'Auto-generated from aggregated rules', isActive: true, confidenceScore: 1 }]);
      } catch {}
    }
    loadDetails();
    return () => { cancelled = true; };
  }, [selectedSchema]);

  const selectedSchemaData = schemas.find(s => s.id === selectedSchema);

  const formatDate = (dateString) => {
    return new Date(dateString).toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  };

  const getStatusBadge = (status) => {
    const classes = {
      stable: 'badge-success',
      beta: 'badge-warning',
      draft: 'badge-gray'
    };
    return `badge ${classes[status] || 'badge-gray'}`;
  };

  const getConfidenceColor = (score) => {
    if (score >= 0.9) return 'text-green-600';
    if (score >= 0.75) return 'text-yellow-600';
    return 'text-red-600';
  };

  return (
    <div className="p-6">
      {/* Page Header */}
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-gray-900">Schema Management</h1>
        <p className="text-gray-600">Manage form schemas and their versions</p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-4 gap-6">
        {/* Schema List */}
        <div className="lg:col-span-1">
          <div className="card">
            <h3 className="text-lg font-medium text-gray-900 mb-4">Schema Types</h3>
            <div className="space-y-2">
              {schemas.map((schema) => (
                <button
                  key={schema.id}
                  onClick={() => setSelectedSchema(schema.id)}
                  className={`w-full p-3 text-left rounded-lg transition-colors ${
                    selectedSchema === schema.id
                      ? 'bg-blue-50 border-2 border-blue-200'
                      : 'hover:bg-gray-50 border-2 border-transparent'
                  }`}
                >
                  <div className="flex justify-between items-start mb-1">
                    <span className="font-medium text-gray-900">{schema.name}</span>
                    <span className={getStatusBadge(schema.status)}>
                      {schema.activeVersion}
                    </span>
                  </div>
                  <div className="text-xs text-gray-500">
                    {schema.fieldCount} fields • Updated {formatDate(schema.lastUpdated)}
                  </div>
                  <div className="mt-2 flex items-center gap-2">
                    <div className="flex-1 bg-gray-200 rounded-full h-1">
                      <div 
                        className="bg-blue-500 h-1 rounded-full"
                        style={{ width: `${schema.confidenceScore * 100}%` }}
                      />
                    </div>
                    <span className={`text-xs font-medium ${getConfidenceColor(schema.confidenceScore)}`}>
                      {Math.round(schema.confidenceScore * 100)}%
                    </span>
                  </div>
                </button>
              ))}
            </div>
          </div>
        </div>

        {/* Schema Details */}
        <div className="lg:col-span-3">
          {selectedSchemaData && (
            <div className="card">
              {/* Schema Header */}
              <div className="border-b border-gray-200 pb-4 mb-6">
                <div className="flex items-center justify-between">
                  <div>
                    <h2 className="text-xl font-bold text-gray-900">
                      {selectedSchemaData.name}
                    </h2>
                    <p className="text-gray-600">
                      Active version {selectedSchemaData.activeVersion} • 
                      {selectedSchemaData.fieldCount} fields • 
                      Confidence {Math.round(selectedSchemaData.confidenceScore * 100)}%
                    </p>
                  </div>
                  <div className="flex items-center gap-2">
                    <span className={getStatusBadge(selectedSchemaData.status)}>
                      {selectedSchemaData.status}
                    </span>
                    <button className="btn btn-secondary">Edit</button>
                    <button className="btn btn-danger">Rollback</button>
                    <button className="btn btn-primary">Export</button>
                  </div>
                </div>
              </div>

              {/* Tabs */}
              <div className="flex border-b border-gray-200 mb-6">
                <button
                  onClick={() => setActiveTab("overview")}
                  className={`px-4 py-2 font-medium text-sm border-b-2 ${
                    activeTab === "overview"
                      ? "border-blue-500 text-blue-600"
                      : "border-transparent text-gray-500 hover:text-gray-700"
                  }`}
                >
                  Overview
                </button>
                <button
                  onClick={() => setActiveTab("fields")}
                  className={`px-4 py-2 font-medium text-sm border-b-2 ${
                    activeTab === "fields"
                      ? "border-blue-500 text-blue-600"
                      : "border-transparent text-gray-500 hover:text-gray-700"
                  }`}
                >
                  Fields
                </button>
                <button
                  onClick={() => setActiveTab("history")}
                  className={`px-4 py-2 font-medium text-sm border-b-2 ${
                    activeTab === "history"
                      ? "border-blue-500 text-blue-600"
                      : "border-transparent text-gray-500 hover:text-gray-700"
                  }`}
                >
                  Version History
                </button>
                <button
                  onClick={() => setActiveTab("diff")}
                  className={`px-4 py-2 font-medium text-sm border-b-2 ${
                    activeTab === "diff"
                      ? "border-blue-500 text-blue-600"
                      : "border-transparent text-gray-500 hover:text-gray-700"
                  }`}
                >
                  Compare Versions
                </button>
              </div>

              {/* Tab Content */}
              {activeTab === "overview" && (
                <div className="space-y-6">
                  <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                    <div className="p-4 bg-blue-50 rounded-lg">
                      <div className="text-2xl font-bold text-blue-600">
                        {selectedSchemaData.fieldCount}
                      </div>
                      <div className="text-blue-700 text-sm">Total Fields</div>
                    </div>
                    <div className="p-4 bg-green-50 rounded-lg">
                      <div className="text-2xl font-bold text-green-600">
                        {Math.round(selectedSchemaData.confidenceScore * 100)}%
                      </div>
                      <div className="text-green-700 text-sm">Confidence Score</div>
                    </div>
                    <div className="p-4 bg-purple-50 rounded-lg">
                      <div className="text-2xl font-bold text-purple-600">
                        {versionInfo.length}
                      </div>
                      <div className="text-purple-700 text-sm">Total Versions</div>
                    </div>
                  </div>
                  
                  <div>
                    <h4 className="text-lg font-medium text-gray-900 mb-3">Schema Statistics</h4>
                    <div className="bg-gray-50 p-4 rounded-lg">
                      <div className="grid grid-cols-2 gap-4 text-sm">
                        <div>
                          <span className="text-gray-600">Last Updated:</span>
                          <span className="ml-2 font-medium">{formatDate(selectedSchemaData.lastUpdated)}</span>
                        </div>
                        <div>
                          <span className="text-gray-600">Status:</span>
                          <span className="ml-2 font-medium capitalize">{selectedSchemaData.status}</span>
                        </div>
                        <div>
                          <span className="text-gray-600">Required Fields:</span>
                          <span className="ml-2 font-medium">{(fields.filter(f => f.required)).length}</span>
                        </div>
                        <div>
                          <span className="text-gray-600">Optional Fields:</span>
                          <span className="ml-2 font-medium">{(fields.filter(f => !f.required)).length}</span>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              )}

              {activeTab === "fields" && (
                <div>
                  <div className="overflow-x-auto">
                    <table className="min-w-full">
                      <thead>
                        <tr className="border-b border-gray-200">
                          <th className="text-left py-2 text-sm font-medium text-gray-500">Field Name</th>
                          <th className="text-left py-2 text-sm font-medium text-gray-500">Type</th>
                          <th className="text-left py-2 text-sm font-medium text-gray-500">Required</th>
                          <th className="text-left py-2 text-sm font-medium text-gray-500">Validation</th>
                          <th className="text-left py-2 text-sm font-medium text-gray-500">Confidence</th>
                          <th className="text-left py-2 text-sm font-medium text-gray-500">Source Rule</th>
                        </tr>
                      </thead>
                      <tbody className="divide-y divide-gray-200">
                        {fields.map((field) => (
                          <tr key={field.name} className="hover:bg-gray-50">
                            <td className="py-3 text-sm">
                              <div className="font-medium text-gray-900">{field.name}</div>
                              {field.conditional && (
                                <div className="text-xs text-gray-500">Conditional: {field.conditional}</div>
                              )}
                            </td>
                            <td className="py-3 text-sm text-gray-600">{field.type}</td>
                            <td className="py-3 text-sm">
                              {field.required ? (
                                <span className="text-red-600 font-medium">Required</span>
                              ) : (
                                <span className="text-gray-500">Optional</span>
                              )}
                            </td>
                            <td className="py-3 text-sm text-gray-600 font-mono">{field.validation}</td>
                            <td className="py-3 text-sm">
                              <span className={getConfidenceColor(field.confidence)}>
                                {Math.round(field.confidence * 100)}%
                              </span>
                            </td>
                            <td className="py-3 text-sm text-gray-600">{field.sourceRule}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                </div>
              )}

              {activeTab === "history" && (
                <div className="space-y-4">
                  {versionInfo.map((version) => (
                    <div key={version.version} className={`p-4 rounded-lg border ${
                      version.isActive ? 'border-green-200 bg-green-50' : 'border-gray-200'
                    }`}>
                      <div className="flex items-center justify-between mb-2">
                        <div className="flex items-center gap-3">
                          <span className="font-bold text-lg">{version.version}</span>
                          {version.isActive && (
                            <span className="badge badge-success">Active</span>
                          )}
                          <span className={`text-sm font-medium ${getConfidenceColor(version.confidenceScore)}`}>
                            {Math.round(version.confidenceScore * 100)}% confidence
                          </span>
                        </div>
                        <div className="flex items-center gap-2">
                          {!version.isActive && (
                            <button className="btn btn-secondary text-sm">Rollback</button>
                          )}
                          <button className="btn btn-secondary text-sm">View Diff</button>
                        </div>
                      </div>
                      <p className="text-gray-700 mb-2">{version.description}</p>
                      <div className="text-sm text-gray-500">
                        {formatDate(version.date)} • {version.author}
                      </div>
                    </div>
                  ))}
                </div>
              )}

              {activeTab === "diff" && (
                <div className="text-center py-8">
                  <div className="text-gray-500 mb-4">
                    <svg className="mx-auto w-12 h-12" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
                    </svg>
                  </div>
                  <h3 className="text-lg font-medium text-gray-900 mb-2">Version Comparison</h3>
                  <p className="text-gray-600 mb-4">
                    Select two versions to compare their differences
                  </p>
                  <div className="flex gap-4 justify-center">
                    <select className="form-field">
                      <option>Select version 1</option>
                      <option>v2.1</option>
                      <option>v2.0</option>
                      <option>v1.9</option>
                    </select>
                    <select className="form-field">
                      <option>Select version 2</option>
                      <option>v2.1</option>
                      <option>v2.0</option>
                      <option>v1.9</option>
                    </select>
                    <button className="btn btn-primary">Compare</button>
                  </div>
                </div>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
