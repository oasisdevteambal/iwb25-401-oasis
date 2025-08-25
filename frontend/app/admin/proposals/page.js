"use client";
import { useEffect, useState } from 'react';

export default function ProposalsInbox() {
  const [docId, setDocId] = useState('');
  const [items, setItems] = useState([]);
  const [status, setStatus] = useState('pending');
  const [schemaType, setSchemaType] = useState('');
  const [loading, setLoading] = useState(false);
  const [msg, setMsg] = useState('');
  const [keyEdits, setKeyEdits] = useState({}); // { [proposalId]: editedKey }

  const load = async () => {
    if (!docId) { setItems([]); return; }
    setLoading(true); setMsg('');
    try {
      const params = new URLSearchParams({ docId, status });
      if (schemaType) params.set('schemaType', schemaType);
      const url = `/api/admin/proposals?${params.toString()}`;
      const res = await fetch(url, { cache: 'no-store' });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) { setMsg(data?.error || 'Failed to load'); setItems([]); }
      else setItems(data?.proposals || data?.items || []);
    } catch (e) { setMsg('Failed to load'); }
    finally { setLoading(false); }
  };

  useEffect(() => { load(); /* eslint-disable-next-line */ }, [status, schemaType]);

  const approve = async (proposalId, variableKey) => {
    setMsg('');
    try {
      const res = await fetch('/api/admin/proposals/approve', {
        method: 'POST', headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ proposalId, variableKey })
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) setMsg(data?.error || 'Approve failed');
      else { setMsg('Approved'); load(); }
    } catch { setMsg('Approve failed'); }
  };

  const reject = async (proposalId) => {
    setMsg('');
    try {
      const res = await fetch('/api/admin/proposals/reject', {
        method: 'POST', headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ proposalId })
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) setMsg(data?.error || 'Reject failed');
      else { setMsg('Rejected'); load(); }
    } catch { setMsg('Reject failed'); }
  };

  const createKey = async (proposalId) => {
    setMsg('');
    const key = keyEdits[proposalId];
    const finalKey = key && key.trim().length > 0 ? key : (items.find(x => (x.id || x.proposal_id) === proposalId)?.suggested_variable_key || '');
    if (!finalKey) { setMsg('No key to create'); return; }
    try {
      const res = await fetch('/api/admin/canonical-variables/upsert', {
        method: 'POST', headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ key: finalKey })
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok || !data?.success) setMsg(data?.error || 'Create key failed');
      else setMsg(`Key '${finalKey}' ready`);
    } catch { setMsg('Create key failed'); }
  };

  return (
    <div className="p-6 space-y-4">
      <h1 className="text-2xl font-bold">Proposals Inbox</h1>
      <div className="grid grid-cols-1 md:grid-cols-4 gap-2 items-end">
        <div className="md:col-span-2">
          <label className="text-sm text-gray-700">Document ID</label>
          <input className="form-field" value={docId} onChange={e => setDocId(e.target.value)} placeholder="e.g. 42" />
        </div>
        <div>
          <label className="text-sm text-gray-700">Schema Type</label>
          <select className="form-field" value={schemaType} onChange={e => setSchemaType(e.target.value)}>
            <option value="">Any</option>
            <option value="income_tax">Income Tax</option>
            <option value="vat">VAT</option>
            <option value="paye">PAYE</option>
          </select>
        </div>
        <div>
          <label className="text-sm text-gray-700">Status</label>
          <select className="form-field" value={status} onChange={e => setStatus(e.target.value)}>
            <option value="pending">Pending</option>
            <option value="approved">Approved</option>
            <option value="rejected">Rejected</option>
          </select>
        </div>
        <button className="btn btn-primary" onClick={load} disabled={!docId || loading}>Refresh</button>
      </div>

      {msg && <div className="text-xs text-gray-600">{msg}</div>}

      <div className="card">
        <h3 className="text-lg font-medium mb-3">Proposals</h3>
        <div className="space-y-3">
          {items.length === 0 && <div className="text-sm text-gray-500">No items</div>}
          {items.map(p => (
            <div key={p.id || p.proposal_id} className="p-3 bg-gray-50 rounded border border-gray-200">
              <div className="flex justify-between items-start">
                <div>
                  <div className="font-medium text-gray-900">{p.term || p.suggested_variable_key || 'Proposal'}</div>
                  <div className="text-xs text-gray-600">{p.suggested_variable_key ? `Suggested key: ${p.suggested_variable_key}` : ''}</div>
                </div>
                {status === 'pending' && (
                  <div className="flex gap-2">
                    <input
                      className="form-field"
                      placeholder="canonical variable key"
                      value={keyEdits[p.id || p.proposal_id] ?? (p.suggested_variable_key || '')}
                      onChange={(e) => setKeyEdits(prev => ({ ...prev, [p.id || p.proposal_id]: e.target.value }))}
                      onKeyDown={(e) => {
                        if (e.key === 'Enter') {
                          const val = keyEdits[p.id || p.proposal_id] ?? (p.suggested_variable_key || '');
                          approve(p.id || p.proposal_id, val);
                        }
                      }}
                    />
                    <button
                      className="btn btn-secondary"
                      onClick={() => {
                        const val = keyEdits[p.id || p.proposal_id] ?? (p.suggested_variable_key || '');
                        approve(p.id || p.proposal_id, val);
                      }}
                    >Approve</button>
                    <button className="btn" onClick={() => createKey(p.id || p.proposal_id)}>Create key</button>
                    <button className="btn btn-danger" onClick={() => reject(p.id || p.proposal_id)}>Reject</button>
                  </div>
                )}
              </div>
              {p.suggested_metadata && (
                <pre className="mt-2 text-xs bg-white p-2 rounded overflow-auto max-h-40">{JSON.stringify(p.suggested_metadata, null, 2)}</pre>
              )}
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
