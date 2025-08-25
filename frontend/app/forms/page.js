"use client";

import { useEffect, useState } from "react";

export default function FormsIndex() {
  const [forms, setForms] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let isMounted = true;
    const controller = new AbortController();

    const load = async () => {
      try {
        // Client-side fetch so you can see it in the browser Network tab
        const res = await fetch("/api/forms/list", { cache: "no-store", signal: controller.signal });
        if (res.ok) {
          const data = await res.json();
          if (isMounted) setForms(data?.forms || []);
        } else if (isMounted) {
          setForms([]);
        }
      } catch (_) {
        if (isMounted) setForms([]);
      } finally {
        if (isMounted) setLoading(false);
      }
    };

    load();
    return () => {
      isMounted = false;
      controller.abort();
    };
  }, []);

  return (
    <div className="bg-gray-50 min-h-screen py-8">
      <div className="mx-auto max-w-6xl px-6">
        {/* Page Header */}
        <div className="mb-8">
          <nav className="text-sm text-gray-500 mb-2">
            <a href="/" className="hover:text-blue-600">Home</a> / Forms
          </nav>
          <h1 className="text-3xl font-bold text-gray-900">Available Tax Forms</h1>
          <p className="text-gray-600 mt-2">Choose a form to begin your tax return process</p>
        </div>

        {/* Filter Bar */}
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-4 mb-6">
          <div className="flex flex-col sm:flex-row gap-4">
            <div className="flex-1">
              <label htmlFor="form-type" className="block text-sm font-medium text-gray-700 mb-1">
                Form Type
              </label>
              <select 
                id="form-type" 
                className="form-field"
                defaultValue="all"
              >
                <option value="all">All Forms</option>
                <option value="income">Income Tax</option>
                <option value="paye">PAYE</option>
                <option value="vat">VAT</option>
              </select>
            </div>
            <div className="flex-1">
              <label htmlFor="status" className="block text-sm font-medium text-gray-700 mb-1">
                Status
              </label>
              <select 
                id="status" 
                className="form-field"
                defaultValue="all"
              >
                <option value="all">All Statuses</option>
                <option value="active">Active</option>
                <option value="beta">Beta</option>
                <option value="draft">Draft</option>
              </select>
            </div>
            <div className="flex items-end">
              <button className="btn btn-primary whitespace-nowrap">
                Apply Filters
              </button>
            </div>
          </div>
        </div>

        {/* Form Cards Grid */}
        {forms.length > 0 ? (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {forms.map((form) => (
              <div key={form.href} className="card hover:shadow-lg transition-shadow duration-200">
                <div className="flex justify-between items-start mb-4">
                  <h3 className="text-xl font-bold text-gray-900">{form.title}</h3>
                  <span className={`badge ${
                    form.status === 'active' ? 'badge-success' : 
                    form.status === 'beta' ? 'badge-warning' : 'badge-gray'
                  }`}>
                    {form.version}
                  </span>
                </div>
                
                <p className="text-gray-600 mb-4">{form.description}</p>
                
                <div className="flex justify-between items-center mb-4">
                  <span className={`badge ${
                    form.status === 'active' ? 'badge-success' : 
                    form.status === 'beta' ? 'badge-warning' : 'badge-gray'
                  }`}>
                    {form.status}
                  </span>
                  <span className="text-xs text-gray-500">
                    {form.lastUpdated ? `Updated ${new Date(form.lastUpdated).toISOString().slice(0,10)}` : 'Active'}
                  </span>
                </div>
                
                <a 
                  href={form.href} 
                  className="btn btn-primary w-full text-center"
                >
                  Start Form
                </a>
              </div>
            ))}
          </div>
        ) : loading ? (
          // Loading State
          <div className="text-center py-16">
            <div className="mx-auto w-24 h-24 bg-gray-100 rounded-full flex items-center justify-center mb-6">
              <svg className="w-12 h-12 text-gray-400 animate-spin" fill="none" viewBox="0 0 24 24">
                <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z"></path>
              </svg>
            </div>
            <h3 className="text-xl font-medium text-gray-900 mb-2">Loading forms…</h3>
            <p className="text-gray-600 mb-6">Fetching available tax forms.</p>
          </div>
        ) : (
          /* Empty State */
          <div className="text-center py-16">
            <div className="mx-auto w-24 h-24 bg-gray-100 rounded-full flex items-center justify-center mb-6">
              <svg className="w-12 h-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
              </svg>
            </div>
            <h3 className="text-xl font-medium text-gray-900 mb-2">No forms available</h3>
            <p className="text-gray-600 mb-6">
              Upload some documents first to generate tax forms automatically.
            </p>
            <a href="/upload" className="btn btn-primary">
              Upload Documents
            </a>
          </div>
        )}
      </div>
    </div>
  );
}
