"use client";
import { useEffect, useMemo, useState } from 'react';

export default function DocumentsAdminPage() {
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [limit, setLimit] = useState(50);
  const [offset, setOffset] = useState(0);
  const [q, setQ] = useState('');
  const [total, setTotal] = useState(0);

  const params = useMemo(() => new URLSearchParams({ limit: String(limit), offset: String(offset), q }), [limit, offset, q]);

  const load = async () => {
    setLoading(true); setError('');
    try {
      const res = await fetch(`/api/admin/documents?${params.toString()}`, { cache: 'no-store' });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) { setError(data?.error || 'Failed to load'); setItems([]); setTotal(0); }
      else {
        setItems(data?.items || []);
        setTotal(data?.pagination?.total || 0);
      }
    } catch (e) { setError('Failed to load'); setItems([]); setTotal(0); }
    finally { setLoading(false); }
  };

  useEffect(() => { load(); /* eslint-disable-next-line */ }, [limit, offset]);

  const page = Math.floor(offset / limit) + 1;
  const pages = Math.max(1, Math.ceil(total / (limit || 1)));

  const go = (p) => {
    const clamped = Math.max(1, Math.min(p, pages));
    setOffset((clamped - 1) * limit);
  };

  return (
    <div className="p-6 space-y-4">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold">Documents</h1>
          <p className="text-gray-600">Browse uploaded documents and copy IDs easily</p>
        </div>
        <div className="flex items-center gap-2">
          <input className="form-field" placeholder="Search filename" value={q} onChange={e => setQ(e.target.value)} />
          <button className="btn btn-secondary" onClick={() => { setOffset(0); load(); }}>Search</button>
        </div>
      </div>

      {error && <div className="text-sm text-red-600">{error}</div>}

      <div className="card overflow-x-auto">
        <table className="min-w-full">
          <thead>
            <tr className="text-left text-xs text-gray-500 border-b">
              <th className="py-2 px-2">ID</th>
              <th className="py-2 px-2">Filename</th>
              <th className="py-2 px-2">Uploaded</th>
              <th className="py-2 px-2">Status</th>
              <th className="py-2 px-2">Chunks</th>
              <th className="py-2 px-2">Rules</th>
              <th className="py-2 px-2">Categories</th>
              <th className="py-2 px-2">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-200">
            {items.map(doc => (
              <tr key={doc.id} className="hover:bg-gray-50">
                <td className="py-2 px-2 text-xs font-mono">{doc.id}</td>
                <td className="py-2 px-2">{doc.filename}</td>
                <td className="py-2 px-2 text-xs">{doc.upload_date || doc.created_at}</td>
                <td className="py-2 px-2 text-xs">{doc.status}{doc.processed ? '' : ' (pending)'}</td>
                <td className="py-2 px-2 text-xs">{doc.total_chunks}</td>
                <td className="py-2 px-2 text-xs">{doc.rules_count}</td>
                <td className="py-2 px-2 text-xs">{Array.isArray(doc.rule_categories) ? doc.rule_categories.join(', ') : JSON.stringify(doc.rule_categories)}</td>
                <td className="py-2 px-2 text-xs">
                  <button className="btn btn-secondary btn-sm" onClick={() => navigator.clipboard.writeText(doc.id)}>Copy ID</button>
                </td>
              </tr>
            ))}
            {items.length === 0 && !loading && (
              <tr><td className="py-4 px-2 text-sm text-gray-500" colSpan={8}>No documents found</td></tr>
            )}
          </tbody>
        </table>
      </div>

      <div className="flex items-center justify-between">
        <div className="text-sm text-gray-600">
          Page {page} of {pages} • {total} total
        </div>
        <div className="flex items-center gap-2">
          <button className="btn btn-secondary" onClick={() => go(1)} disabled={page <= 1}>« First</button>
          <button className="btn btn-secondary" onClick={() => go(page - 1)} disabled={page <= 1}>‹ Prev</button>
          <select className="form-field" value={limit} onChange={e => { setLimit(Number(e.target.value)); setOffset(0); }}>
            <option value={10}>10</option>
            <option value={25}>25</option>
            <option value={50}>50</option>
            <option value={100}>100</option>
          </select>
          <button className="btn btn-secondary" onClick={() => go(page + 1)} disabled={page >= pages}>Next ›</button>
          <button className="btn btn-secondary" onClick={() => go(pages)} disabled={page >= pages}>Last »</button>
        </div>
      </div>
    </div>
  );
}
