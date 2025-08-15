"use client";
import { useState, useRef } from "react";

export default function UploadPage() {
  const [files, setFiles] = useState([]);
  const [isDragOver, setIsDragOver] = useState(false);
  const [processingStep, setProcessingStep] = useState(0);
  const fileInputRef = useRef();

  const steps = [
    "Upload", 
    "Extract Text", 
    "Parse Rules", 
    "Generate Schema", 
    "Activate"
  ];

  const handleDragOver = (e) => {
    e.preventDefault();
    setIsDragOver(true);
  };

  const handleDragLeave = (e) => {
    e.preventDefault();
    setIsDragOver(false);
  };

  const handleDrop = (e) => {
    e.preventDefault();
    setIsDragOver(false);
    const droppedFiles = Array.from(e.dataTransfer.files);
    addFiles(droppedFiles);
  };

  const handleFileSelect = (e) => {
    const selectedFiles = Array.from(e.target.files);
    addFiles(selectedFiles);
  };

  const addFiles = (newFiles) => {
    const fileObjects = newFiles.map((file, index) => ({
      id: Date.now() + index,
      file,
      name: file.name,
      size: file.size,
      progress: 0,
      status: 'pending' // pending, uploading, complete, error
    }));
    setFiles(prev => [...prev, ...fileObjects]);
  };

  const removeFile = (id) => {
    setFiles(prev => prev.filter(f => f.id !== id));
  };

  const formatFileSize = (bytes) => {
    if (bytes === 0) return '0 Bytes';
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
  };

  const uploadFiles = async () => {
    // Simulate upload process
    for (let file of files.filter(f => f.status === 'pending')) {
      setFiles(prev => prev.map(f => 
        f.id === file.id ? { ...f, status: 'uploading' } : f
      ));
      
      // Simulate progress
      for (let progress = 0; progress <= 100; progress += 20) {
        await new Promise(resolve => setTimeout(resolve, 200));
        setFiles(prev => prev.map(f => 
          f.id === file.id ? { ...f, progress } : f
        ));
      }
      
      setFiles(prev => prev.map(f => 
        f.id === file.id ? { ...f, status: 'complete', progress: 100 } : f
      ));
    }
    
    // Simulate processing steps
    for (let step = 1; step <= 4; step++) {
      await new Promise(resolve => setTimeout(resolve, 1500));
      setProcessingStep(step);
    }
  };

  return (
    <div className="bg-gray-50 min-h-screen py-8">
      <div className="mx-auto max-w-4xl px-6">
        {/* Page Header */}
        <div className="mb-8">
          <nav className="text-sm text-gray-500 mb-2">
            <a href="/" className="hover:text-blue-600">Home</a> / Upload Documents
          </nav>
          <h1 className="text-3xl font-bold text-gray-900">Upload Documents</h1>
          <p className="text-gray-600 mt-2">
            Upload your tax-related documents to automatically generate forms
          </p>
        </div>

        {/* Upload Zone */}
        <div className="card mb-6">
          <div
            className={`border-2 border-dashed rounded-lg p-8 text-center transition-colors ${
              isDragOver 
                ? 'border-blue-400 bg-blue-50' 
                : 'border-gray-300 hover:border-gray-400'
            }`}
            onDragOver={handleDragOver}
            onDragLeave={handleDragLeave}
            onDrop={handleDrop}
            onClick={() => fileInputRef.current?.click()}
          >
            <input
              ref={fileInputRef}
              type="file"
              multiple
              accept=".pdf,.jpg,.jpeg,.png"
              onChange={handleFileSelect}
              className="hidden"
            />
            
            <div className="mx-auto w-16 h-16 bg-blue-100 rounded-full flex items-center justify-center mb-4">
              <svg className="w-8 h-8 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
              </svg>
            </div>
            
            <h3 className="text-lg font-medium text-gray-900 mb-2">
              Drop files here or click to browse
            </h3>
            <p className="text-gray-600 mb-4">
              Supported formats: PDF, JPG, PNG
            </p>
            <p className="text-sm text-gray-500">
              Maximum file size: 10MB per file
            </p>
          </div>
        </div>

        {/* Upload Queue */}
        {files.length > 0 && (
          <div className="card mb-6">
            <div className="flex justify-between items-center mb-4">
              <h3 className="text-lg font-medium text-gray-900">Upload Queue</h3>
              <div className="text-sm text-gray-600">
                {files.filter(f => f.status === 'complete').length} of {files.length} complete
              </div>
            </div>
            
            <div className="space-y-3">
              {files.map((file) => (
                <div key={file.id} className="flex items-center gap-4 p-3 bg-gray-50 rounded-lg">
                  <div className="flex-1">
                    <div className="flex items-center justify-between mb-1">
                      <span className="font-medium text-gray-900">{file.name}</span>
                      <span className="text-sm text-gray-500">{formatFileSize(file.size)}</span>
                    </div>
                    
                    {file.status !== 'pending' && (
                      <div className="w-full bg-gray-200 rounded-full h-2">
                        <div 
                          className={`h-2 rounded-full transition-all duration-300 ${
                            file.status === 'complete' ? 'bg-green-500' : 
                            file.status === 'error' ? 'bg-red-500' : 'bg-blue-500'
                          }`}
                          style={{ width: `${file.progress}%` }}
                        />
                      </div>
                    )}
                  </div>
                  
                  <div className="flex items-center gap-2">
                    {file.status === 'complete' && (
                      <svg className="w-5 h-5 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                      </svg>
                    )}
                    {file.status === 'error' && (
                      <svg className="w-5 h-5 text-red-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                      </svg>
                    )}
                    <button 
                      onClick={() => removeFile(file.id)}
                      className="text-gray-400 hover:text-red-500 transition-colors"
                    >
                      <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                      </svg>
                    </button>
                  </div>
                </div>
              ))}
            </div>
            
            <div className="flex gap-4 mt-4">
              <button 
                onClick={uploadFiles}
                className="btn btn-primary"
                disabled={files.every(f => f.status !== 'pending')}
              >
                Start Upload
              </button>
              <button 
                onClick={() => setFiles([])}
                className="btn btn-secondary"
              >
                Clear All
              </button>
            </div>
          </div>
        )}

        {/* Processing Timeline */}
        {processingStep > 0 && (
          <div className="card">
            <h3 className="text-lg font-medium text-gray-900 mb-6">Processing Status</h3>
            
            <div className="flex items-center justify-between mb-4">
              {steps.map((step, index) => (
                <div key={step} className="flex flex-col items-center">
                  <div className={`w-10 h-10 rounded-full flex items-center justify-center mb-2 ${
                    index < processingStep ? 'bg-green-500 text-white' :
                    index === processingStep ? 'bg-blue-500 text-white' :
                    'bg-gray-200 text-gray-500'
                  }`}>
                    {index < processingStep ? (
                      <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                      </svg>
                    ) : (
                      <span className="text-sm font-medium">{index + 1}</span>
                    )}
                  </div>
                  <span className="text-sm font-medium text-gray-700">{step}</span>
                </div>
              ))}
            </div>
            
            <div className="w-full bg-gray-200 rounded-full h-2">
              <div 
                className="bg-blue-500 h-2 rounded-full transition-all duration-500"
                style={{ width: `${(processingStep / (steps.length - 1)) * 100}%` }}
              />
            </div>
            
            {processingStep === steps.length - 1 && (
              <div className="mt-6 p-4 bg-green-50 border border-green-200 rounded-lg">
                <div className="flex items-center gap-2">
                  <svg className="w-5 h-5 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                  </svg>
                  <span className="font-medium text-green-800">Processing Complete!</span>
                </div>
                <p className="text-green-700 mt-1">
                  New form schemas have been generated and activated. You can now access the updated forms.
                </p>
                <div className="mt-3">
                  <a href="/forms" className="btn btn-primary">
                    View Updated Forms
                  </a>
                </div>
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
