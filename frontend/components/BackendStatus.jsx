'use client';

import { useState, useEffect } from 'react';

export default function BackendStatus() {
    const [status, setStatus] = useState('checking');
    const [details, setDetails] = useState(null);

    useEffect(() => {
        checkBackendHealth();
    }, []);

    const checkBackendHealth = async () => {
        try {
            const response = await fetch('/api/health/backend');
            const data = await response.json();

            if (response.ok && data.healthy) {
                setStatus('connected');
                setDetails(data.details);
            } else {
                setStatus('error');
                setDetails(data.error || 'Backend service is not responding');
            }
        } catch (error) {
            setStatus('error');
            setDetails('Cannot connect to backend service');
        }
    };

    const getStatusColor = () => {
        switch (status) {
            case 'connected': return 'text-green-600 bg-green-50';
            case 'error': return 'text-red-600 bg-red-50';
            default: return 'text-yellow-600 bg-yellow-50';
        }
    };

    const getStatusIcon = () => {
        switch (status) {
            case 'connected': return '✅';
            case 'error': return '❌';
            default: return '⏳';
        }
    };

    if (status === 'connected') return null; // Don't show when everything is working

    return (
        <div className={`p-3 rounded-lg border mb-4 ${getStatusColor()}`}>
            <div className="flex items-center space-x-2">
                <span>{getStatusIcon()}</span>
                <span className="font-medium text-sm">
                    {status === 'checking' && 'Checking backend connection...'}
                    {status === 'error' && 'Backend Connection Issue'}
                </span>
                {status === 'error' && (
                    <button
                        onClick={checkBackendHealth}
                        className="ml-auto text-sm underline hover:no-underline"
                    >
                        Retry
                    </button>
                )}
            </div>
            {details && status === 'error' && (
                <div className="mt-2 text-xs">
                    <p>{details}</p>
                    <p className="mt-1">
                        Make sure the Ballerina backend is running on port 5000:
                        <code className="ml-1 px-1 bg-gray-200 rounded">bal run</code>
                    </p>
                </div>
            )}
        </div>
    );
}
