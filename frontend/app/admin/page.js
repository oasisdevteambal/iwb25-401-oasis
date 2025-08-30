"use client";
import { useState, useEffect } from "react";

export default function AdminDashboard() {
  const [stats, setStats] = useState({
    totalDocuments: 0,
    successfulExtractions: 0,
    activeSchemas: 0,
    pendingProcessing: 0
  });

  const [recentActivity] = useState([]);

  const [systemHealth] = useState([
  { name: 'API Server', status: 'healthy', uptime: '—' },
  { name: 'Database', status: 'healthy', uptime: '—' },
  { name: 'Document Processor', status: 'healthy', uptime: '—' },
  { name: 'Schema Generator', status: 'healthy', uptime: '—' }
  ]);

  const formatTime = (timestamp) => {
    return new Date(timestamp).toLocaleTimeString('en-US', {
      hour: '2-digit',
      minute: '2-digit'
    });
  };

  const getActivityIcon = (type) => {
    const icons = {
      document_uploaded: (
        <svg className="w-4 h-4 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
        </svg>
      ),
      schema_generated: (
        <svg className="w-4 h-4 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
        </svg>
      ),
      rules_extracted: (
        <svg className="w-4 h-4 text-purple-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 10h16M4 14h16M4 18h16" />
        </svg>
      ),
      user_registered: (
        <svg className="w-4 h-4 text-indigo-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
        </svg>
      )
    };
    return icons[type] || icons.document_uploaded;
  };

  const [schemaType, setSchemaType] = useState('income_tax');
  const [targetDate, setTargetDate] = useState(() => new Date().toISOString().slice(0,10));
  const [actionMsg, setActionMsg] = useState('');
  const [loading, setLoading] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [uploadMsg, setUploadMsg] = useState('');
  const [selectedFile, setSelectedFile] = useState(null);
  const [uploadCategory, setUploadCategory] = useState('income_tax');
  const [docId, setDocId] = useState('');
  const [preflight, setPreflight] = useState({ ok: true, evidenceCount: 0, aggregatedExists: false });
  useEffect(() => {
    let cancelled = false;
    async function load() {
      try {
        const res = await fetch('/api/admin/summary', { cache: 'no-store' });
        if (!res.ok) return;
        const data = await res.json();
        if (!cancelled) setStats({
          totalDocuments: data.totalDocuments || 0,
          successfulExtractions: data.successfulExtractions || 0,
          activeSchemas: data.activeSchemas || 0,
          pendingProcessing: data.pendingProcessing || 0
        });
      } catch {}
    }
    load();
    return () => { cancelled = true; };
  }, []);

  // Refresh preflight whenever schemaType or date changes
  useEffect(() => {
    let cancelled = false;
    async function check() {
      try {
        const res = await fetch(`/api/admin/preflight?schemaType=${encodeURIComponent(schemaType)}&date=${encodeURIComponent(targetDate)}`, { cache: 'no-store' });
        if (!res.ok) {
          if (!cancelled) setPreflight({ ok: false, evidenceCount: 0, aggregatedExists: false });
          return;
        }
        const data = await res.json();
        if (!cancelled) setPreflight({ ok: true, evidenceCount: data?.evidenceCount || 0, aggregatedExists: !!data?.aggregatedExists });
      } catch {
        if (!cancelled) setPreflight({ ok: false, evidenceCount: 0, aggregatedExists: false });
      }
    }
    check();
    return () => { cancelled = true; };
  }, [schemaType, targetDate]);

  const runAggregation = async () => {
    setActionMsg('');
    setLoading(true);
    try {
      const response = await fetch('/api/admin/aggregate', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ schemaType, date: targetDate })
      });
      const data = await response.json().catch(() => ({}));
      if (response.ok) {
        setActionMsg(`Aggregated ${schemaType} for ${targetDate}`);
      } else {
        setActionMsg(data?.error || 'Aggregation failed');
      }
    } catch (error) {
      setActionMsg('Aggregation failed');
    } finally {
      setLoading(false);
    }
  };

  const runGenerateSchema = async () => {
    setActionMsg('');
    setLoading(true);
    try {
  const response = await fetch('/api/admin/generate-schema', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ schemaType, date: targetDate })
      });
      const data = await response.json().catch(() => ({}));
      if (response.ok) {
        setActionMsg(`Generated schema for ${schemaType} on ${targetDate}`);
      } else {
        setActionMsg(data?.error || 'Schema generation failed');
      }
    } catch (e) {
      setActionMsg('Schema generation failed');
    } finally {
      setLoading(false);
    }
  };

  const runExtractMetadata = async () => {
    if (!docId) { setActionMsg('Enter a document ID'); return; }
    setActionMsg('');
    setLoading(true);
    try {
      const res = await fetch('/api/admin/extract-metadata', {
        method: 'POST', headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ docId, schemaType })
      });
      const data = await res.json().catch(() => ({}));
      if (res.ok) setActionMsg('Extraction batch created'); else setActionMsg(data?.error || 'Extraction failed');
    } catch (e) {
      setActionMsg('Extraction failed');
    } finally { setLoading(false); }
  };

  const runApplyMetadata = async () => {
    if (!docId) { setActionMsg('Enter a document ID'); return; }
    setActionMsg(''); setLoading(true);
    try {
      const res = await fetch('/api/admin/apply-metadata', {
        method: 'POST', headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ docId, schemaType })
      });
      const data = await res.json().catch(() => ({}));
      if (res.ok) setActionMsg('Metadata applied to evidence rules'); else setActionMsg(data?.error || 'Apply failed');
    } catch (e) { setActionMsg('Apply failed'); }
    finally { setLoading(false); }
  };

  const onFileChange = (e) => {
    setUploadMsg('');
    const f = e.target.files?.[0];
    setSelectedFile(f || null);
  };

  const uploadDocument = async () => {
    if (!selectedFile) {
      setUploadMsg('Select a file first');
      return;
    }
    setUploading(true);
    setUploadMsg('');
    try {
      const form = new FormData();
      form.append('file', selectedFile);
      form.append('filename', selectedFile.name);
  form.append('schemaType', uploadCategory);
      const res = await fetch('/api/admin/upload', { method: 'POST', body: form });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) {
        setUploadMsg(data?.error || 'Upload failed');
      } else {
        setUploadMsg('Upload and processing started');
        // refresh stats
        try {
          const sres = await fetch('/api/admin/summary', { cache: 'no-store' });
          const sdata = await sres.json();
          setStats(prev => ({
            ...prev,
            totalDocuments: sdata.totalDocuments || prev.totalDocuments,
            pendingProcessing: sdata.pendingProcessing || prev.pendingProcessing,
          }));
        } catch {}
      }
    } catch (e) {
      setUploadMsg('Upload failed');
    } finally {
      setUploading(false);
      setSelectedFile(null);
    }
  };

  return (
    <div className="p-6 space-y-6">
      {/* Page Header */}
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Admin Dashboard</h1>
        <p className="text-gray-600">System overview and management tools</p>
      </div>

      {/* Stats Overview */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <div className="card bg-blue-50 border-blue-200">
          <div className="flex items-center">
            <div className="p-3 bg-blue-500 rounded-lg">
              <svg className="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
              </svg>
            </div>
            <div className="ml-4">
              <h3 className="text-2xl font-bold text-blue-600">{stats.totalDocuments}</h3>
              <p className="text-blue-700 font-medium">Total Documents</p>
            </div>
          </div>
        </div>

        <div className="card bg-green-50 border-green-200">
          <div className="flex items-center">
            <div className="p-3 bg-green-500 rounded-lg">
              <svg className="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
              </svg>
            </div>
            <div className="ml-4">
              <h3 className="text-2xl font-bold text-green-600">{stats.successfulExtractions}</h3>
              <p className="text-green-700 font-medium">Successful Extractions</p>
            </div>
          </div>
        </div>

        <div className="card bg-purple-50 border-purple-200">
          <div className="flex items-center">
            <div className="p-3 bg-purple-500 rounded-lg">
              <svg className="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 5a1 1 0 011-1h14a1 1 0 011 1v2a1 1 0 01-1 1H5a1 1 0 01-1-1V5zM4 13a1 1 0 011-1h6a1 1 0 011 1v6a1 1 0 01-1 1H5a1 1 0 01-1-1v-6zM16 13a1 1 0 011-1h2a1 1 0 011 1v6a1 1 0 01-1 1h-2a1 1 0 01-1-1v-6z" />
              </svg>
            </div>
            <div className="ml-4">
              <h3 className="text-2xl font-bold text-purple-600">{stats.activeSchemas}</h3>
              <p className="text-purple-700 font-medium">Active Schemas</p>
            </div>
          </div>
        </div>

        <div className="card bg-orange-50 border-orange-200">
          <div className="flex items-center">
            <div className="p-3 bg-orange-500 rounded-lg">
              <svg className="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </div>
            <div className="ml-4">
              <h3 className="text-2xl font-bold text-orange-600">{stats.pendingProcessing}</h3>
              <p className="text-orange-700 font-medium">Pending Processing</p>
            </div>
          </div>
        </div>
      </div>

      {/* Step-by-Step Guided Workflow */}
      <div className="card">
        <h3 className="text-xl font-semibold text-gray-900 mb-6">📋 Step-by-Step Document Processing Guide</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
          {/* Step 1: Upload */}
          <div className="relative">
            <div className="flex items-center justify-center w-12 h-12 bg-blue-100 border-2 border-blue-500 rounded-full mx-auto mb-4">
              <span className="text-blue-600 font-bold">1</span>
            </div>
            <div className="text-center">
              <h4 className="font-semibold text-gray-900 mb-2">📄 Upload Document</h4>
              <p className="text-sm text-gray-600 mb-4">
                Upload tax documents (PDF, DOC, DOCX) for processing. Select the appropriate category.
              </p>
              <div className="bg-blue-50 border border-blue-200 rounded-lg p-3">
                <div className="text-xs text-blue-700 font-medium mb-2">✅ What to do:</div>
                <ul className="text-xs text-blue-600 space-y-1">
                  <li>• Choose file from computer</li>
                  <li>• Select tax category (Income Tax, PAYE, VAT)</li>
                  <li>• Click "Upload + Process"</li>
                  <li>• Wait for confirmation</li>
                </ul>
              </div>
            </div>
            {/* Connector arrow */}
            <div className="hidden md:block absolute top-6 left-full w-6 h-0.5 bg-gray-300 transform translate-x-0"></div>
          </div>

          {/* Step 2: Extract */}
          <div className="relative">
            <div className="flex items-center justify-center w-12 h-12 bg-orange-100 border-2 border-orange-500 rounded-full mx-auto mb-4">
              <span className="text-orange-600 font-bold">2</span>
            </div>
            <div className="text-center">
              <h4 className="font-semibold text-gray-900 mb-2">🔍 Extract Metadata</h4>
              <p className="text-sm text-gray-600 mb-4">
                Extract tax rules and metadata from uploaded documents using AI processing.
              </p>
              <div className="bg-orange-50 border border-orange-200 rounded-lg p-3">
                <div className="text-xs text-orange-700 font-medium mb-2">✅ What to do:</div>
                <ul className="text-xs text-orange-600 space-y-1">
                  <li>• Note the document ID from upload</li>
                  <li>• Enter ID in "Document ID" field</li>
                  <li>• Click "Run Extract"</li>
                  <li>• Monitor processing status</li>
                </ul>
              </div>
            </div>
            {/* Connector arrow */}
            <div className="hidden md:block absolute top-6 left-full w-6 h-0.5 bg-gray-300 transform translate-x-0"></div>
          </div>

          {/* Step 3: Approve */}
          <div className="relative">
            <div className="flex items-center justify-center w-12 h-12 bg-purple-100 border-2 border-purple-500 rounded-full mx-auto mb-4">
              <span className="text-purple-600 font-bold">3</span>
            </div>
            <div className="text-center">
              <h4 className="font-semibold text-gray-900 mb-2">✅ Review & Approve</h4>
              <p className="text-sm text-gray-600 mb-4">
                Review extracted rules and metadata, then approve or modify proposals.
              </p>
              <div className="bg-purple-50 border border-purple-200 rounded-lg p-3">
                <div className="text-xs text-purple-700 font-medium mb-2">✅ What to do:</div>
                <ul className="text-xs text-purple-600 space-y-1">
                  <li>• Open "Proposals Inbox"</li>
                  <li>• Review extracted rules</li>
                  <li>• Approve or modify</li>
                  <li>• Click "Apply Approved"</li>
                </ul>
              </div>
            </div>
            {/* Connector arrow */}
            <div className="hidden md:block absolute top-6 left-full w-6 h-0.5 bg-gray-300 transform translate-x-0"></div>
          </div>

          {/* Step 4: Generate Forms */}
          <div className="relative">
            <div className="flex items-center justify-center w-12 h-12 bg-green-100 border-2 border-green-500 rounded-full mx-auto mb-4">
              <span className="text-green-600 font-bold">4</span>
            </div>
            <div className="text-center">
              <h4 className="font-semibold text-gray-900 mb-2">📋 Generate Forms</h4>
              <p className="text-sm text-gray-600 mb-4">
                Aggregate rules and generate dynamic tax forms for end users.
              </p>
              <div className="bg-green-50 border border-green-200 rounded-lg p-3">
                <div className="text-xs text-green-700 font-medium mb-2">✅ What to do:</div>
                <ul className="text-xs text-green-600 space-y-1">
                  <li>• Select tax type & date</li>
                  <li>• Click "Aggregate" button</li>
                  <li>• Click "Generate Schema"</li>
                  <li>• Forms are now available!</li>
                </ul>
              </div>
            </div>
          </div>
        </div>

        {/* Process Status Indicators */}
        <div className="mt-8 border-t pt-6">
          <h4 className="font-semibold text-gray-900 mb-4">📊 Current Process Status</h4>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div className="bg-gray-50 border border-gray-200 rounded-lg p-4">
              <div className="flex items-center gap-3 mb-2">
                <div className="w-3 h-3 bg-blue-500 rounded-full"></div>
                <span className="font-medium text-gray-900">Documents Uploaded</span>
              </div>
              <div className="text-2xl font-bold text-blue-600">{stats.totalDocuments}</div>
              <div className="text-xs text-gray-500">Ready for processing</div>
            </div>
            
            <div className="bg-gray-50 border border-gray-200 rounded-lg p-4">
              <div className="flex items-center gap-3 mb-2">
                <div className="w-3 h-3 bg-orange-500 rounded-full"></div>
                <span className="font-medium text-gray-900">Pending Processing</span>
              </div>
              <div className="text-2xl font-bold text-orange-600">{stats.pendingProcessing}</div>
              <div className="text-xs text-gray-500">Awaiting extraction/approval</div>
            </div>
            
            <div className="bg-gray-50 border border-gray-200 rounded-lg p-4">
              <div className="flex items-center gap-3 mb-2">
                <div className="w-3 h-3 bg-green-500 rounded-full"></div>
                <span className="font-medium text-gray-900">Active Schemas</span>
              </div>
              <div className="text-2xl font-bold text-green-600">{stats.activeSchemas}</div>
              <div className="text-xs text-gray-500">Forms available to users</div>
            </div>
          </div>
        </div>

        {/* Quick Tips */}
        <div className="mt-6 bg-blue-50 border border-blue-200 rounded-lg p-4">
          <h5 className="font-semibold text-blue-900 mb-2">💡 Quick Tips for Success</h5>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm text-blue-700">
            <div>
              <strong>📄 Document Upload:</strong>
              <ul className="mt-1 ml-4 space-y-1">
                <li>• Use clear, readable documents</li>
                <li>• Ensure correct tax category selection</li>
                <li>• Wait for upload confirmation</li>
              </ul>
            </div>
            <div>
              <strong>🔍 Processing:</strong>
              <ul className="mt-1 ml-4 space-y-1">
                <li>• Always review extracted rules</li>
                <li>• Approve only accurate metadata</li>
                <li>• Test generated forms before publishing</li>
              </ul>
            </div>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Activity Feed */}
        <div className="lg:col-span-2">
          <div className="card">
            <h3 className="text-lg font-medium text-gray-900 mb-4">Recent Activity</h3>
            <div className="space-y-4">
              {recentActivity.map((activity) => (
                <div key={activity.id} className="flex items-start gap-3 p-3 bg-gray-50 rounded-lg">
                  <div className="mt-1">{getActivityIcon(activity.type)}</div>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm text-gray-900">{activity.message}</p>
                    <div className="flex items-center gap-4 mt-1 text-xs text-gray-500">
                      <span>{formatTime(activity.timestamp)}</span>
                      <span>•</span>
                      <span>{activity.user}</span>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* Quick Actions & System Health */}
        <div className="space-y-6">
          {/* Quick Actions */}
          <div className="card">
            <h3 className="text-lg font-medium text-gray-900 mb-4">⚡ Quick Actions</h3>
            <div className="space-y-4">
              {/* Step 1: Admin Upload */}
              <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
                <div className="flex items-center gap-2 mb-3">
                  <div className="w-6 h-6 bg-blue-500 text-white rounded-full flex items-center justify-center text-sm font-bold">1</div>
                  <h4 className="font-semibold text-blue-900">Upload Document</h4>
                </div>
                <div className="space-y-2">
                  <label className="block text-sm font-medium text-gray-700">Select Document</label>
                  <input type="file" accept=".pdf,.doc,.docx" onChange={onFileChange} className="form-field" />
                  <select className="form-field" value={uploadCategory} onChange={e => setUploadCategory(e.target.value)}>
                    <option value="income_tax">Income Tax Documents</option>
                    <option value="paye">PAYE Documents</option>
                    <option value="vat">VAT Documents</option>
                  </select>
                  <button onClick={uploadDocument} disabled={uploading || !selectedFile} className="btn btn-primary w-full">
                    <div className="flex items-center justify-center gap-2">
                      <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
                      </svg>
                      {uploading ? 'Uploading & Processing...' : 'Upload + Process Document'}
                    </div>
                  </button>
                  {uploadMsg && (
                    <div className={`text-sm p-2 rounded ${uploadMsg.includes('failed') ? 'bg-red-100 text-red-700' : 'bg-green-100 text-green-700'}`}>
                      {uploadMsg}
                    </div>
                  )}
                </div>
              </div>

              {/* Step 2: Extract Metadata */}
              <div className="bg-orange-50 border border-orange-200 rounded-lg p-4">
                <div className="flex items-center gap-2 mb-3">
                  <div className="w-6 h-6 bg-orange-500 text-white rounded-full flex items-center justify-center text-sm font-bold">2</div>
                  <h4 className="font-semibold text-orange-900">Extract & Apply Metadata</h4>
                </div>
                <div className="space-y-2">
                  <label className="block text-sm font-medium text-gray-700">Document ID (from upload step)</label>
                  <input className="form-field" placeholder="e.g. 42" value={docId} onChange={e => setDocId(e.target.value)} />
                  <div className="grid grid-cols-2 gap-2">
                    <button className="btn btn-secondary" disabled={loading || !docId} onClick={runExtractMetadata}>
                      <div className="flex items-center justify-center gap-1">
                        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                        </svg>
                        Extract Rules
                      </div>
                    </button>
                    <button className="btn btn-secondary" disabled={loading || !docId} onClick={runApplyMetadata}>
                      <div className="flex items-center justify-center gap-1">
                        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                        </svg>
                        Apply Approved
                      </div>
                    </button>
                  </div>
                  <a className="block text-center text-sm bg-purple-100 text-purple-700 py-2 px-3 rounded border border-purple-200 hover:bg-purple-200 transition-colors" href="/admin/proposals" rel="nofollow">
                    📋 Open Proposals Inbox for Review
                  </a>
                </div>
              </div>

              {/* Step 3 & 4: Aggregate & Generate */}
              <div className="bg-green-50 border border-green-200 rounded-lg p-4">
                <div className="flex items-center gap-2 mb-3">
                  <div className="w-6 h-6 bg-green-500 text-white rounded-full flex items-center justify-center text-sm font-bold">3</div>
                  <h4 className="font-semibold text-green-900">Generate Forms</h4>
                </div>
                <div className="space-y-2">
                  <div className="grid grid-cols-2 gap-2">
                    <select className="form-field" value={schemaType} onChange={e => setSchemaType(e.target.value)}>
                      <option value="income_tax">Income Tax</option>
                      <option value="paye">PAYE</option>
                      <option value="vat">VAT</option>
                    </select>
                    <input type="date" className="form-field" value={targetDate} onChange={e => setTargetDate(e.target.value)} />
                  </div>
                  <div className="grid grid-cols-2 gap-2">
                    <button 
                      onClick={runAggregation}
                      disabled={loading || preflight.evidenceCount === 0}
                      className={`btn btn-primary ${preflight.evidenceCount === 0 ? 'opacity-60 cursor-not-allowed' : ''}`}
                    >
                      <div className="flex items-center justify-center gap-1">
                        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                        </svg>
                        {loading ? 'Aggregating...' : 'Aggregate'}
                      </div>
                    </button>
                    <button 
                      onClick={runGenerateSchema}
                      disabled={loading}
                      className="btn btn-secondary"
                    >
                      <div className="flex items-center justify-center gap-1">
                        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                        </svg>
                        {loading ? 'Generating...' : 'Generate Schema'}
                      </div>
                    </button>
                  </div>
                  {actionMsg && (
                    <div className={`text-sm p-2 rounded ${actionMsg.includes('failed') ? 'bg-red-100 text-red-700' : 'bg-green-100 text-green-700'}`}>
                      {actionMsg}
                    </div>
                  )}
                  {preflight.ok && preflight.evidenceCount === 0 && (
                    <div className="text-sm text-orange-700 bg-orange-100 border border-orange-200 rounded p-3">
                      ⚠️ No evidence rules found for <strong>{schemaType}</strong> on <strong>{targetDate}</strong>. 
                      <br />Please upload and process a relevant document first.
                    </div>
                  )}
                </div>
              </div>

              {/* System Maintenance */}
              <div className="bg-gray-50 border border-gray-200 rounded-lg p-4">
                <h4 className="font-semibold text-gray-900 mb-3">🔧 System Maintenance</h4>
                <div className="space-y-2">
                  <button className="btn btn-secondary w-full">
                    <div className="flex items-center justify-center gap-2">
                      <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                      </svg>
                      Clear System Cache
                    </div>
                  </button>
                  
                  <button className="btn btn-secondary w-full">
                    <div className="flex items-center justify-center gap-2">
                      <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                      </svg>
                      Export System Data
                    </div>
                  </button>
                </div>
              </div>
            </div>
          </div>

          {/* System Health */}
          <div className="card">
            <h3 className="text-lg font-medium text-gray-900 mb-4">System Health</h3>
            <div className="space-y-3">
              {systemHealth.map((service) => (
                <div key={service.name} className="flex items-center justify-between">
                  <div className="flex items-center gap-3">
                    <div className={`w-3 h-3 rounded-full ${
                      service.status === 'healthy' ? 'bg-green-500' :
                      service.status === 'warning' ? 'bg-yellow-500' : 'bg-red-500'
                    }`} />
                    <span className="text-sm font-medium text-gray-900">{service.name}</span>
                  </div>
                  <span className="text-xs text-gray-500">{service.uptime}</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
