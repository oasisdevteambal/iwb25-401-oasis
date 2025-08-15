import Image from "next/image";

export default function Home() {
  return (
    <div className="bg-white">
      {/* Hero Section */}
      <section className="bg-gradient-to-b from-blue-50 to-white py-20">
        <div className="mx-auto max-w-4xl px-6 text-center">
          <h1 className="text-4xl md:text-6xl font-bold text-gray-900 mb-6">
            Dynamic Tax Form Generation
          </h1>
          <p className="text-xl text-gray-600 mb-8 max-w-2xl mx-auto">
            Intelligent document processing that automatically generates tax forms from uploaded documents, 
            ensuring accuracy and compliance with the latest regulations.
          </p>
          <div className="flex flex-col sm:flex-row gap-4 justify-center">
            <a href="/forms" className="btn btn-primary text-lg px-8 py-3">
              Get Started
            </a>
            <a href="/upload" className="btn btn-secondary text-lg px-8 py-3">
              Upload Documents
            </a>
          </div>
        </div>
      </section>

      {/* Feature Cards */}
      <section className="py-20">
        <div className="mx-auto max-w-6xl px-6">
          <h2 className="text-3xl font-bold text-center text-gray-900 mb-12">
            How It Works
          </h2>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            {/* Upload Documents */}
            <div className="card text-center fade-in">
              <div className="mx-auto w-12 h-12 bg-blue-100 rounded-lg flex items-center justify-center mb-6">
                <svg className="w-6 h-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
                </svg>
              </div>
              <h3 className="text-xl font-bold text-gray-900 mb-4">Upload Documents</h3>
              <p className="text-gray-600">
                Simply upload your tax-related documents (PDFs, images) and our AI will extract 
                relevant information and tax rules automatically.
              </p>
            </div>

            {/* Generate Forms */}
            <div className="card text-center fade-in">
              <div className="mx-auto w-12 h-12 bg-green-100 rounded-lg flex items-center justify-center mb-6">
                <svg className="w-6 h-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                </svg>
              </div>
              <h3 className="text-xl font-bold text-gray-900 mb-4">Generate Forms</h3>
              <p className="text-gray-600">
                Dynamic forms are created based on extracted rules, with proper validation, 
                conditional fields, and real-time updates as regulations change.
              </p>
            </div>

            {/* Submit & Validate */}
            <div className="card text-center fade-in">
              <div className="mx-auto w-12 h-12 bg-purple-100 rounded-lg flex items-center justify-center mb-6">
                <svg className="w-6 h-6 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
              </div>
              <h3 className="text-xl font-bold text-gray-900 mb-4">Submit & Validate</h3>
              <p className="text-gray-600">
                Complete your forms with confidence. Built-in validation ensures accuracy 
                and compliance before submission.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* CTA Section */}
      <section className="bg-gray-50 py-16">
        <div className="mx-auto max-w-4xl px-6 text-center">
          <h2 className="text-3xl font-bold text-gray-900 mb-4">
            Ready to streamline your tax processes?
          </h2>
          <p className="text-xl text-gray-600 mb-8">
            Join thousands of users who trust our intelligent tax form system.
          </p>
          <a href="/forms/income_tax" className="btn btn-primary text-lg px-8 py-3">
            Start with Income Tax Form
          </a>
        </div>
      </section>
    </div>
  );
}
