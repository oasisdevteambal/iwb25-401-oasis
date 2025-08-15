"use client";
import { useState, useEffect } from "react";

export default function AdminDashboard() {
  const [stats, setStats] = useState({
    totalDocuments: 47,
    successfulExtractions: 42,
    activeSchemas: 3,
    pendingProcessing: 2
  });

  const [recentActivity] = useState([
    {
      id: 1,
      type: 'document_uploaded',
      message: 'Tax code document uploaded by Admin',
      timestamp: '2025-08-14T10:30:00Z',
      user: 'admin@example.com'
    },
    {
      id: 2,
      type: 'schema_generated',
      message: 'Income tax schema v2.1 generated successfully',
      timestamp: '2025-08-14T10:25:00Z',
      user: 'system'
    },
    {
      id: 3,
      type: 'rules_extracted',
      message: '15 new tax rules extracted from uploaded document',
      timestamp: '2025-08-14T10:20:00Z',
      user: 'system'
    },
    {
      id: 4,
      type: 'user_registered',
      message: 'New user registered: john.doe@example.com',
      timestamp: '2025-08-14T09:45:00Z',
      user: 'system'
    }
  ]);

  const [systemHealth] = useState([
    { name: 'API Server', status: 'healthy', uptime: '99.9%' },
    { name: 'Database', status: 'healthy', uptime: '99.8%' },
    { name: 'Document Processor', status: 'warning', uptime: '98.5%' },
    { name: 'Schema Generator', status: 'healthy', uptime: '99.7%' }
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

  const generateSchema = async () => {
    // This would call the actual API
    try {
      const response = await fetch('/api/v1/admin/generate-schema', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ schemaType: 'income_tax' })
      });
      
      if (response.ok) {
        // Update stats or show success message
        console.log('Schema generation triggered');
      }
    } catch (error) {
      console.error('Failed to generate schema:', error);
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
            <h3 className="text-lg font-medium text-gray-900 mb-4">Quick Actions</h3>
            <div className="space-y-3">
              <button 
                onClick={generateSchema}
                className="btn btn-primary w-full text-left"
              >
                <div className="flex items-center gap-2">
                  <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                  </svg>
                  Regenerate Schema
                </div>
              </button>
              
              <button className="btn btn-secondary w-full text-left">
                <div className="flex items-center gap-2">
                  <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                  </svg>
                  Clear Cache
                </div>
              </button>
              
              <button className="btn btn-secondary w-full text-left">
                <div className="flex items-center gap-2">
                  <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                  </svg>
                  Export Data
                </div>
              </button>
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
