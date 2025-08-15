"use client";

export default function FormErrorState({ schemaType, error }) {
  return (
    <div className="bg-gray-50 min-h-screen py-8">
      <div className="mx-auto max-w-3xl px-6">
        <nav className="text-sm text-gray-500 mb-4">
          <a href="/" className="hover:text-blue-600">Home</a> /
          <a href="/forms" className="hover:text-blue-600"> Forms</a> /
          <span className="capitalize"> {schemaType.replaceAll("_", " ")}</span>
        </nav>

        <h1 className="text-2xl font-bold text-gray-900 mb-6 capitalize">
          {schemaType.replaceAll("_", " ")} Tax Return
        </h1>

        <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-6">
          <div className="flex items-start gap-3">
            <svg className="w-6 h-6 text-yellow-600 mt-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16c-.77.833.192 2.5 1.732 2.5z" />
            </svg>
            <div>
              <h3 className="text-lg font-medium text-yellow-800 mb-2">Form Temporarily Unavailable</h3>
              <p className="text-yellow-700 mb-4">
                We're unable to load an active schema for this form. This could be because:
              </p>
              <ul className="list-disc list-inside text-yellow-700 mb-4 space-y-1">
                <li>New documents are being processed</li>
                <li>Tax rules are being updated</li>
                <li>Schema generation is in progress</li>
              </ul>
              <div className="text-sm text-yellow-600 mb-4">
                Error details: {String(error.message || error)}
              </div>
              <div className="flex gap-3">
                <a href="/admin" className="btn btn-primary">
                  Admin Panel
                </a>
                <a href="/upload" className="btn btn-secondary">
                  Upload Documents
                </a>
                <button
                  onClick={() => window.location.reload()}
                  className="btn btn-secondary"
                >
                  Try Again
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
