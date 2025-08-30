'use client';

import { useState } from 'react';
import MarkdownRenderer from './MarkdownRenderer';

export default function ChatMessage({ message, compact = false }) {
    // Auto-expand evidence for formula and rates_brackets intents
    const shouldAutoExpand = message.intent === 'formulas' || message.intent === 'rates_brackets';
    const [isExpanded, setIsExpanded] = useState(shouldAutoExpand);

    const isUser = message.type === 'user';
    const isError = !message.success && message.type === 'assistant';

    const formatTimestamp = (timestamp) => {
        return new Date(timestamp).toLocaleTimeString([], {
            hour: '2-digit',
            minute: '2-digit'
        });
    };

    const renderEvidence = (evidence) => {
        if (!evidence || typeof evidence !== 'object') return null;

        return (
            <div className="mt-3 p-3 bg-blue-50 rounded-lg border border-blue-200 animate-slideDown">
                <button
                    onClick={() => setIsExpanded(!isExpanded)}
                    className="flex items-center justify-between w-full text-left text-sm font-medium text-blue-800 hover:text-blue-900"
                >
                    <span>📊 Supporting Evidence</span>
                    <svg
                        className={`w-4 h-4 transition-transform duration-200 ${isExpanded ? 'rotate-180' : ''}`}
                        fill="none"
                        stroke="currentColor"
                        viewBox="0 0 24 24"
                    >
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                    </svg>
                </button>

                {isExpanded && (
                    <div className="mt-2 animate-fadeIn">
                        {evidence.formulas && (
                            <div className="mb-3">
                                <h4 className="font-medium text-blue-800 mb-2">🧮 Formulas:</h4>
                                <div className="space-y-3">
                                    {evidence.formulas.map((formula, index) => (
                                        <div key={index} className="bg-white p-3 rounded-lg border border-gray-200 shadow-sm">
                                            <div className="flex items-center justify-between mb-2">
                                                <span className="font-semibold text-gray-900">
                                                    {formula.name || formula.id}
                                                </span>
                                                <span className="text-xs text-gray-500 bg-gray-100 px-2 py-1 rounded">
                                                    Order: {formula.order || index + 1}
                                                </span>
                                            </div>
                                            <div className="bg-gray-50 p-2 rounded font-mono text-sm text-gray-800 border">
                                                <code>{formula.expression || formula.formula}</code>
                                            </div>
                                            {formula.description && (
                                                <div className="text-xs text-gray-600 mt-2 italic">
                                                    {formula.description}
                                                </div>
                                            )}
                                        </div>
                                    ))}
                                </div>
                            </div>
                        )}

                        {evidence.brackets && (
                            <div className="mb-3">
                                <h4 className="font-medium text-blue-800 mb-2">Tax Brackets:</h4>
                                <div className="overflow-x-auto">
                                    <table className="min-w-full bg-white rounded border">
                                        <thead className="bg-gray-50">
                                            <tr>
                                                <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Min Income</th>
                                                <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Max Income</th>
                                                <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Rate</th>
                                                <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Fixed Amount</th>
                                            </tr>
                                        </thead>
                                        <tbody className="divide-y divide-gray-200">
                                            {evidence.brackets.map((bracket, index) => (
                                                <tr key={index}>
                                                    <td className="px-3 py-2 text-sm text-gray-900">
                                                        {bracket.min_income?.toLocaleString() || 'N/A'}
                                                    </td>
                                                    <td className="px-3 py-2 text-sm text-gray-900">
                                                        {bracket.max_income?.toLocaleString() || 'No Limit'}
                                                    </td>
                                                    <td className="px-3 py-2 text-sm text-gray-900">
                                                        {(bracket.rate_fraction * 100).toFixed(1)}%
                                                    </td>
                                                    <td className="px-3 py-2 text-sm text-gray-900">
                                                        {bracket.fixed_amount?.toLocaleString() || '0'}
                                                    </td>
                                                </tr>
                                            ))}
                                        </tbody>
                                    </table>
                                </div>
                            </div>
                        )}

                        {evidence.sources && (
                            <div className="mb-3">
                                <h4 className="font-medium text-blue-800 mb-2">Source Documents:</h4>
                                <div className="space-y-2">
                                    {evidence.sources.map((source, index) => (
                                        <div key={index} className="bg-white p-2 rounded border flex items-center space-x-2">
                                            <svg className="w-4 h-4 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                                            </svg>
                                            <span className="text-sm text-gray-700">{source.filename || 'Unknown Document'}</span>
                                        </div>
                                    ))}
                                </div>
                            </div>
                        )}

                        {evidence.variables && (
                            <div className="mb-3">
                                <h4 className="font-medium text-blue-800 mb-2">Variables:</h4>
                                <div className="flex flex-wrap gap-2">
                                    {evidence.variables.map((variable, index) => (
                                        <span
                                            key={index}
                                            className="inline-block bg-white px-2 py-1 rounded text-xs text-gray-700 border"
                                        >
                                            {variable}
                                        </span>
                                    ))}
                                </div>
                            </div>
                        )}
                    </div>
                )}
            </div>
        );
    };

    const getIntentIcon = (intent) => {
        switch (intent) {
            case 'formulas':
                return '🧮';
            case 'rates_brackets':
                return '📊';
            case 'variable_source':
                return '📄';
            case 'variables_list':
                return '📝';
            case 'guidance':
                return '💡';
            case 'welcome':
                return '👋';
            default:
                return '💬';
        }
    };

    return (
        <div className={`flex ${isUser ? 'justify-end' : 'justify-start'} animate-slideUp`}>
            <div className={`${compact ? 'max-w-xs' : 'max-w-3xl'} ${isUser ? 'order-2' : 'order-1'}`}>
                <div className={`flex items-start ${compact ? 'space-x-2' : 'space-x-3'} ${isUser ? 'flex-row-reverse space-x-reverse' : ''}`}>
                    {/* Avatar */}
                    <div className={`${compact ? 'w-6 h-6' : 'w-8 h-8'} rounded-full flex items-center justify-center text-sm ${isUser
                        ? 'bg-blue-600 text-white'
                        : isError
                            ? 'bg-red-100 text-red-600'
                            : 'bg-gray-100 text-gray-600'
                        }`}>
                        {isUser ? (
                            <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                                <path fillRule="evenodd" d="M10 9a3 3 0 100-6 3 3 0 000 6zm-7 9a7 7 0 1114 0H3z" clipRule="evenodd" />
                            </svg>
                        ) : (
                            <span>{getIntentIcon(message.intent)}</span>
                        )}
                    </div>

                    {/* Message Content */}
                    <div className={`flex-1 ${compact ? 'px-3 py-2' : 'px-4 py-3'} rounded-2xl ${isUser
                        ? 'bg-blue-600 text-white rounded-br-md'
                        : isError
                            ? 'bg-red-50 text-red-800 border border-red-200 rounded-bl-md'
                            : 'bg-white text-gray-800 border border-gray-200 rounded-bl-md shadow-sm'
                        }`}>
                        <div className={`${compact ? 'text-xs' : 'text-sm'} leading-relaxed`}>
                            {isUser ? (
                                <div className="whitespace-pre-wrap">{message.content}</div>
                            ) : (
                                <MarkdownRenderer content={message.content} />
                            )}
                        </div>

                        {/* Metadata for user messages */}
                        {isUser && message.metadata && (
                            <div className="mt-2 text-xs text-blue-100 opacity-75">
                                {message.metadata.schemaType && (
                                    <span className="bg-blue-500 bg-opacity-50 px-2 py-1 rounded mr-2">
                                        {message.metadata.schemaType}
                                    </span>
                                )}
                                {message.metadata.date && (
                                    <span className="bg-blue-500 bg-opacity-50 px-2 py-1 rounded mr-2">
                                        {message.metadata.date}
                                    </span>
                                )}
                                {message.metadata.variable && (
                                    <span className="bg-blue-500 bg-opacity-50 px-2 py-1 rounded">
                                        var: {message.metadata.variable}
                                    </span>
                                )}
                            </div>
                        )}

                        {/* Evidence for assistant messages */}
                        {!isUser && message.evidence && renderEvidence(message.evidence)}

                        {/* Timestamp */}
                        <div className={`text-xs mt-2 ${isUser ? 'text-blue-100' : 'text-gray-500'
                            }`}>
                            {formatTimestamp(message.timestamp)}
                        </div>
                    </div>
                </div>
            </div>
        </div>
    );
}
