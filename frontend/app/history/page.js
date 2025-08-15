"use client";
import { useState } from "react";

export default function HistoryPage() {
  const [searchTerm, setSearchTerm] = useState("");
  const [filterType, setFilterType] = useState("all");
  const [filterStatus, setFilterStatus] = useState("all");

  // Mock data - in real app this would come from API
  const submissions = [
    {
      id: 1,
      formName: "Income Tax",
      formType: "income_tax",
      submissionDate: "2025-08-12T14:30:00Z",
      status: "complete",
      schemaVersion: "v2.1"
    },
    {
      id: 2,
      formName: "Income Tax",
      formType: "income_tax", 
      submissionDate: "2025-08-10T09:15:00Z",
      status: "draft",
      schemaVersion: "v2.0"
    },
    {
      id: 3,
      formName: "PAYE",
      formType: "paye",
      submissionDate: "2025-08-08T16:45:00Z", 
      status: "processing",
      schemaVersion: "v1.0"
    }
  ];

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
      complete: 'badge-success',
      draft: 'badge-gray', 
      processing: 'badge-warning'
    };
    return `badge ${classes[status] || 'badge-gray'}`;
  };

  const filteredSubmissions = submissions.filter(submission => {
    const matchesSearch = submission.formName.toLowerCase().includes(searchTerm.toLowerCase()) ||
                         submission.formType.toLowerCase().includes(searchTerm.toLowerCase());
    const matchesType = filterType === 'all' || submission.formType === filterType;
    const matchesStatus = filterStatus === 'all' || submission.status === filterStatus;
    
    return matchesSearch && matchesType && matchesStatus;
  });

  return (
    <div className="bg-gray-50 min-h-screen py-8">
      <div className="mx-auto max-w-6xl px-6">
        {/* Page Header */}
        <div className="mb-8">
          <nav className="text-sm text-gray-500 mb-2">
            <a href="/" className="hover:text-blue-600">Home</a> / Form Submission History
          </nav>
          <h1 className="text-3xl font-bold text-gray-900">Form Submission History</h1>
          <p className="text-gray-600 mt-2">View and manage your past form submissions</p>
        </div>

        {/* Search and Filters */}
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
                  placeholder="Search by form name or type..."
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
              <label htmlFor="type-filter" className="block text-sm font-medium text-gray-700 mb-1">
                Form Type
              </label>
              <select
                id="type-filter"
                value={filterType}
                onChange={(e) => setFilterType(e.target.value)}
                className="form-field"
              >
                <option value="all">All Types</option>
                <option value="income_tax">Income Tax</option>
                <option value="paye">PAYE</option>
                <option value="vat">VAT</option>
              </select>
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
                <option value="complete">Complete</option>
                <option value="draft">Draft</option>
                <option value="processing">Processing</option>
              </select>
            </div>
          </div>
        </div>

        {/* History Table */}
        {filteredSubmissions.length > 0 ? (
          <div className="bg-white rounded-lg shadow-sm border border-gray-200 overflow-hidden">
            <div className="overflow-x-auto">
              <table className="min-w-full divide-y divide-gray-200">
                <thead className="bg-gray-50">
                  <tr>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Form Details
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Date & Time
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Status
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Schema Version
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Actions
                    </th>
                  </tr>
                </thead>
                <tbody className="bg-white divide-y divide-gray-200">
                  {filteredSubmissions.map((submission) => (
                    <tr key={submission.id} className="hover:bg-gray-50 transition-colors">
                      <td className="px-6 py-4">
                        <div>
                          <div className="font-medium text-gray-900">{submission.formName}</div>
                          <div className="text-sm text-gray-500">{submission.formType}</div>
                        </div>
                      </td>
                      <td className="px-6 py-4 text-sm text-gray-900">
                        {formatDate(submission.submissionDate)}
                      </td>
                      <td className="px-6 py-4">
                        <span className={getStatusBadge(submission.status)}>
                          {submission.status}
                        </span>
                      </td>
                      <td className="px-6 py-4 text-sm text-gray-900">
                        {submission.schemaVersion}
                      </td>
                      <td className="px-6 py-4">
                        <div className="flex items-center gap-2">
                          {submission.status === 'complete' && (
                            <>
                              <button className="text-blue-600 hover:text-blue-800 text-sm font-medium">
                                View
                              </button>
                              <button className="text-blue-600 hover:text-blue-800 text-sm font-medium">
                                Download
                              </button>
                            </>
                          )}
                          {submission.status === 'draft' && (
                            <a 
                              href={`/forms/${submission.formType}`}
                              className="text-blue-600 hover:text-blue-800 text-sm font-medium"
                            >
                              Continue
                            </a>
                          )}
                          {submission.status === 'processing' && (
                            <span className="text-gray-500 text-sm">Processing...</span>
                          )}
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            
            {/* Pagination */}
            <div className="bg-white px-6 py-3 border-t border-gray-200 flex items-center justify-between">
              <div className="text-sm text-gray-700">
                Showing <span className="font-medium">1</span> to <span className="font-medium">{filteredSubmissions.length}</span> of{' '}
                <span className="font-medium">{submissions.length}</span> results
              </div>
              <div className="flex items-center gap-2">
                <button className="btn btn-secondary text-sm" disabled>
                  Previous
                </button>
                <span className="px-3 py-1 bg-blue-500 text-white text-sm rounded">1</span>
                <button className="btn btn-secondary text-sm" disabled>
                  Next
                </button>
              </div>
            </div>
          </div>
        ) : submissions.length === 0 ? (
          /* Empty State - No submissions */
          <div className="text-center py-16">
            <div className="mx-auto w-24 h-24 bg-gray-100 rounded-full flex items-center justify-center mb-6">
              <svg className="w-12 h-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
              </svg>
            </div>
            <h3 className="text-xl font-medium text-gray-900 mb-2">No submissions yet</h3>
            <p className="text-gray-600 mb-6">
              You haven't submitted any forms yet. Start by creating your first form.
            </p>
            <a href="/forms" className="btn btn-primary">
              Start New Form
            </a>
          </div>
        ) : (
          /* Empty State - No search results */
          <div className="text-center py-16">
            <div className="mx-auto w-24 h-24 bg-gray-100 rounded-full flex items-center justify-center mb-6">
              <svg className="w-12 h-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
              </svg>
            </div>
            <h3 className="text-xl font-medium text-gray-900 mb-2">No results found</h3>
            <p className="text-gray-600 mb-6">
              Try adjusting your search terms or filters.
            </p>
            <button 
              onClick={() => {
                setSearchTerm("");
                setFilterType("all");
                setFilterStatus("all");
              }}
              className="btn btn-secondary"
            >
              Clear Filters
            </button>
          </div>
        )}
      </div>
    </div>
  );
}
