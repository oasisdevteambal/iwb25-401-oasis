'use client';

import { useState } from 'react';

export default function ChatInput({ onSendMessage, disabled, compact = false }) {
    const [message, setMessage] = useState('');
    const [variable, setVariable] = useState('');
    const [showAdvanced, setShowAdvanced] = useState(false);

    const handleSubmit = (e) => {
        e.preventDefault();
        if (!message.trim() || disabled) return;

        onSendMessage(message.trim(), variable.trim());
        setMessage('');
        setVariable('');
        setShowAdvanced(false);
    };

    const handleKeyPress = (e) => {
        if (e.key === 'Enter' && !e.shiftKey) {
            e.preventDefault();
            handleSubmit(e);
        }
    };

    const quickQuestions = [
        "What are the current income tax brackets?",
        "How is PAYE calculated?",
        "Show me the VAT formulas",
        "What variables are needed for income tax?"
    ];

    const handleQuickQuestion = (question) => {
        setMessage(question);
    };

    return (
        <div className={`${compact ? 'p-3' : 'p-4'}`}>
            {/* Quick Questions */}
            {message === '' && !compact && (
                <div className="mb-4 animate-fadeIn">
                    <p className="text-sm text-gray-600 mb-2">Quick questions:</p>
                    <div className="flex flex-wrap gap-2">
                        {quickQuestions.map((question, index) => (
                            <button
                                key={index}
                                onClick={() => handleQuickQuestion(question)}
                                className="text-sm px-3 py-1 bg-blue-50 text-blue-700 rounded-full hover:bg-blue-100 transition-all duration-200 transform hover:scale-105"
                                disabled={disabled}
                            >
                                {question}
                            </button>
                        ))}
                    </div>
                </div>
            )}

            {/* Advanced Options */}
            {showAdvanced && (
                <div className="mb-4 p-3 bg-gray-50 rounded-lg animate-slideDown">
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                        Specific Variable (optional)
                    </label>
                    <input
                        type="text"
                        value={variable}
                        onChange={(e) => setVariable(e.target.value)}
                        placeholder="e.g., basic_salary, tax_rate"
                        className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                        disabled={disabled}
                    />
                    <p className="text-xs text-gray-500 mt-1">
                        Specify a variable name for provenance queries
                    </p>
                </div>
            )}

            {/* Main Input Form */}
            <form onSubmit={handleSubmit} className="flex items-end space-x-3">
                <div className="flex-1">
                    <div className="relative">
                        <textarea
                            value={message}
                            onChange={(e) => setMessage(e.target.value)}
                            onKeyPress={handleKeyPress}
                            placeholder="Ask me about tax rules, formulas, rates, or variables..."
                            className="w-full px-4 py-3 pr-12 border border-gray-300 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-transparent resize-none transition-all duration-200"
                            rows={1}
                            style={{
                                minHeight: '50px',
                                maxHeight: '120px',
                                resize: 'none'
                            }}
                            disabled={disabled}
                        />

                        {/* Advanced Options Toggle */}
                        <button
                            type="button"
                            onClick={() => setShowAdvanced(!showAdvanced)}
                            className="absolute right-2 top-2 p-2 text-gray-400 hover:text-gray-600 transition-colors rounded-lg hover:bg-gray-100"
                            title="Advanced options"
                        >
                            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 6V4m0 2a2 2 0 100 4m0-4a2 2 0 110 4m-6 8a2 2 0 100-4m0 4a2 2 0 100 4m0-4v2m0-6V4m6 6v10m6-2a2 2 0 100-4m0 4a2 2 0 100 4m0-4v2m0-6V4" />
                            </svg>
                        </button>
                    </div>
                </div>

                {/* Send Button */}
                <button
                    type="submit"
                    disabled={!message.trim() || disabled}
                    className="bg-blue-600 text-white px-6 py-3 rounded-xl hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-all duration-200 transform hover:scale-105 disabled:hover:scale-100 flex items-center space-x-2"
                >
                    {disabled ? (
                        <div className="animate-spin rounded-full h-5 w-5 border-2 border-white border-t-transparent"></div>
                    ) : (
                        <>
                            <span>Send</span>
                            <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
                            </svg>
                        </>
                    )}
                </button>
            </form>
        </div>
    );
}
