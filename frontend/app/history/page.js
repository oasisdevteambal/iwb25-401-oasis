'use client';

import Link from 'next/link';
import { useEffect, useMemo, useRef, useState } from 'react';

export default function HistoryPage() {
  // UI state
  const [searchTerm, setSearchTerm] = useState('');
  const [filterStatus, setFilterStatus] = useState('all');
  const [limit, setLimit] = useState(25);
  const [offset, setOffset] = useState(0);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  // Data state
  const [items, setItems] = useState([]);
  const [total, setTotal] = useState(0);
  const debounceRef = useRef(null);

  // Helpers
  const buildPublicFileUrl = (filePath) => {
    const base = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://ohdbwbrutlwikcmpprky.supabase.co';
    const bucket = process.env.NEXT_PUBLIC_SUPABASE_BUCKET || 'documents';
    return `${base}/storage/v1/object/public/${bucket}/${filePath}`;
  };

  // For public buckets, we can directly use the public URL
  const getSignedUrl = async (filePath) => buildPublicFileUrl(filePath);

  const fetchDocuments = async ({ q = '', lim = limit, off = offset } = {}) => {
    setLoading(true);
    setError('');
    try {
      const url = new URL('/api/admin/documents', window.location.origin);
      if (q) url.searchParams.set('q', q);
      if (lim) url.searchParams.set('limit', String(lim));
      if (off) url.searchParams.set('offset', String(off));
      const res = await fetch(url, { cache: 'no-store' });
      if (!res.ok) {
        const txt = await res.text();
        throw new Error(`Failed to load: ${res.status} ${txt}`);
      }
      const data = await res.json();
      setItems(Array.isArray(data?.items) ? data.items : []);
      setTotal(Number(data?.pagination?.total || 0));
    } catch (e) {
      setError(e?.message || 'Failed to load documents');
      setItems([]);
      setTotal(0);
    } finally {
      setLoading(false);
    }
  };

  // Initial load
  useEffect(() => {
    fetchDocuments({ q: '', lim: limit, off: 0 });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Page/limit changes
  useEffect(() => {
    fetchDocuments({ q: searchTerm, lim: limit, off: offset });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [offset, limit]);

  // Debounced search
  useEffect(() => {
    if (debounceRef.current) clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(() => {
      setOffset(0);
      fetchDocuments({ q: searchTerm, lim: limit, off: 0 });
    }, 350);
    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [searchTerm]);

  const formatDate = (dateString) => {
    if (!dateString) return '—';
    try {
      return new Date(dateString).toLocaleString('en-US', {
        year: 'numeric',
        month: 'short',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
      });
    } catch {
      return String(dateString);
    }
  };

  const getStatusBadge = (status) => {
    const classes = {
      complete: 'badge-success',
      completed: 'badge-success',
      draft: 'badge-gray',
      processing: 'badge-warning',
      pending: 'badge-warning',
      failed: 'badge-error',
    };
    return `badge ${classes[status] || 'badge-gray'}`;
  };

  const rows = useMemo(() => {
    const mapped = items.map((it) => {
      const processed = !!it?.processed;
      const status = processed ? it?.status || 'completed' : it?.status || 'processing';
      return {
        id: it?.id,
        filename: it?.filename,
        uploadDate: it?.upload_date || it?.created_at,
        status,
        processed,
        schemaVersion: it?.document_type || '—',
        filePath: it?.file_path,
        contentType: it?.content_type || 'application/octet-stream',
        rulesCount: Number(it?.rules_count || 0),
        categories: Array.isArray(it?.rule_categories) ? it.rule_categories : [],
      };
    });
    return filterStatus === 'all'
      ? mapped
      : mapped.filter((r) => (r.status || '').toLowerCase() === filterStatus.toLowerCase());
  }, [items, filterStatus]);

  const pageFrom = total === 0 ? 0 : offset + 1;
  const pageTo = Math.min(offset + rows.length, total);
  const canPrev = offset > 0;
  const canNext = offset + limit < total;

  const onPrev = () => {
    if (!canPrev) return;
    setOffset(Math.max(0, offset - limit));
  };
  const onNext = () => {
    if (!canNext) return;
    setOffset(offset + limit);
  };

  return (
    <div className="bg-gray-50 min-h-screen py-8">
      <div className="mx-auto max-w-6xl px-6">
        <div className="mb-8">
          <nav className="text-sm text-gray-500 mb-2">
            <Link href="/" className="hover:text-blue-600">
              Home
            </Link>{' '}
            / Document History
          </nav>
          <h1 className="text-3xl font-bold text-gray-900">Document History</h1>
          <p className="text-gray-600 mt-2">View and manage uploaded documents</p>
        </div>

        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-4 mb-6">
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
            <div className="md:col-span-2">
              <label htmlFor="search" className="block text-sm font-medium text-gray-700 mb-1">
                Search
              </label>
              <div className="relative">
                <input
                  id="search"
                  type="text"
                  placeholder="Search by filename..."
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                  className="form-field pl-10"
                />
                <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                  <svg className="w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                  </svg>
                </div>
              </div>
            </div>

            <div>
              <label htmlFor="status-filter" className="block text-sm font-medium text-gray-700 mb-1">
                Status
              </label>
              <select
                id="status-filter"
                value={filterStatus}
                onChange={(e) => setFilterStatus(e.target.value)}
                className="form-field"
              >
                <option value="all">All Statuses</option>
                <option value="completed">Completed</option>
                <option value="processing">Processing</option>
                <option value="failed">Failed</option>
              </select>
            </div>

            <div>
              <label htmlFor="page-size" className="block text-sm font-medium text-gray-700 mb-1">
                Page Size
              </label>
              <select
                id="page-size"
                value={String(limit)}
                onChange={(e) => {
                  setLimit(Number(e.target.value));
                  setOffset(0);
                }}
                className="form-field"
              >
                {[10, 25, 50, 100].map((n) => (
                  <option key={n} value={n}>
                    {n}
                  </option>
                ))}
              </select>
            </div>
          </div>
        </div>

        {error && (
          <div className="bg-red-50 border border-red-200 text-red-700 rounded-md p-3 mb-3 text-sm">{error}</div>
        )}

        {loading ? (
          <div className="text-center text-gray-600 py-16">Loading…</div>
        ) : rows.length > 0 ? (
          <div className="bg-white rounded-lg shadow-sm border border-gray-200 overflow-hidden">
            <div className="overflow-x-auto">
              <table className="min-w-full divide-y divide-gray-200">
                <thead className="bg-gray-50">
                  <tr>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">File</th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Date & Time</th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Type</th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
                  </tr>
                </thead>
                <tbody className="bg-white divide-y divide-gray-200">
                  {rows.map((row) => (
                    <tr key={row.id} className="hover:bg-gray-50 transition-colors">
                      <td className="px-6 py-4">
                        <div>
                          <div className="font-medium text-gray-900">{row.filename}</div>
                          <div className="text-sm text-gray-500">
                            {row.rulesCount > 0 ? `${row.rulesCount} rule(s)` : 'No rules'}
                            {Array.isArray(row.categories) && row.categories.length > 0 && (
                              <span className="ml-2 text-gray-400">· {row.categories.join(', ')}</span>
                            )}
                          </div>
                        </div>
                      </td>
                      <td className="px-6 py-4 text-sm text-gray-900">{formatDate(row.uploadDate)}</td>
                      <td className="px-6 py-4">
                        <span className={getStatusBadge(row.status)}>{row.status}</span>
                      </td>
                      <td className="px-6 py-4 text-sm text-gray-900">{row.schemaVersion}</td>
                      <td className="px-6 py-4">
                        <div className="flex items-center gap-2">
                          {row.processed ? (
                            <>
                              <button
                                onClick={async () => {
                                  const url = await getSignedUrl(row.filePath);
                                  window.open(url, '_blank', 'noopener,noreferrer');
                                }}
                                className="text-blue-600 hover:text-blue-800 text-sm font-medium"
                              >
                                View
                              </button>
                              <a
                                href={buildPublicFileUrl(row.filePath)}
                                download
                                className="text-blue-600 hover:text-blue-800 text-sm font-medium"
                              >
                                Download
                              </a>
                            </>
                          ) : row.status === 'processing' ? (
                            <span className="text-gray-500 text-sm">Processing...</span>
                          ) : (
                            <span className="text-gray-500 text-sm">Unavailable</span>
                          )}
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            <div className="bg-white px-6 py-3 border-t border-gray-200 flex items-center justify-between">
              <div className="text-sm text-gray-700">
                Showing <span className="font-medium">{pageFrom}</span> to <span className="font-medium">{pageTo}</span> of <span className="font-medium">{total}</span> results
              </div>
              <div className="flex items-center gap-2">
                <button className="btn btn-secondary text-sm" disabled={!canPrev} onClick={onPrev}>
                  Previous
                </button>
                <span className="px-3 py-1 bg-blue-500 text-white text-sm rounded">{Math.max(1, Math.floor(offset / limit) + 1)}</span>
                <button className="btn btn-secondary text-sm" disabled={!canNext} onClick={onNext}>
                  Next
                </button>
              </div>
            </div>
          </div>
        ) : (
          <div className="text-center py-16">
            <div className="mx-auto w-24 h-24 bg-gray-100 rounded-full flex items-center justify-center mb-6">
              <svg className="w-12 h-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
              </svg>
            </div>
            <h3 className="text-xl font-medium text-gray-900 mb-2">No results found</h3>
            <p className="text-gray-600 mb-6">Try adjusting your search terms or filters.</p>
            <button
              onClick={() => {
                setSearchTerm('');
                setFilterStatus('all');
                setOffset(0);
              }}
              className="btn btn-secondary"
            >
              Clear Filters
            </button>
            <div className="mt-4">
              <Link href="/upload" className="btn btn-primary">
                Upload a document
              </Link>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
