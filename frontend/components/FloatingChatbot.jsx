'use client';

import { useRef, useEffect } from 'react';
import ChatMessage from './ChatMessage';
import ChatInput from './ChatInput';
import LoadingIndicator from './LoadingIndicator';
import SchemaSelector from './SchemaSelector_fixed';
import BackendStatus from './BackendStatus';
import { useChat } from '../context/ChatContext';

export default function FloatingChatbot() {
    const {
        isOpen,
        isMinimizing,
        messages,
        isLoading,
        selectedSchema,
        targetDate,
        hasNewMessage,
        setSelectedSchema,
        setTargetDate,
        toggleChatbot,
        handleSendMessage,
        clearChat
    } = useChat();

    const messagesEndRef = useRef(null);
    const chatContainerRef = useRef(null);

    const scrollToBottom = () => {
        messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
    };

    useEffect(() => {
        scrollToBottom();
    }, [messages]);

    return (
        <div className="fixed bottom-6 right-6 z-50">
            {/* Chat Widget */}
            <div
                className={`absolute bottom-16 right-0 w-96 bg-white rounded-2xl shadow-2xl border border-gray-200 transition-all duration-300 transform ${isOpen && !isMinimizing
                        ? 'opacity-100 scale-100 translate-y-0'
                        : 'opacity-0 scale-95 translate-y-4 pointer-events-none'
                    }`}
                style={{ maxHeight: '500px' }}
            >
                {/* Chat Header */}
                <div className="bg-gradient-to-r from-blue-600 to-blue-700 px-4 py-3 rounded-t-2xl border-b border-blue-500">
                    <div className="flex items-center justify-between">
                        <div className="flex items-center space-x-3">
                            <div className="w-8 h-8 bg-white bg-opacity-20 rounded-full flex items-center justify-center">
                                <svg className="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
                                </svg>
                            </div>
                            <div>
                                <h3 className="text-sm font-semibold text-white">Tax Assistant</h3>
                                <p className="text-blue-100 text-xs">Ask about tax rules</p>
                            </div>
                        </div>
                        <div className="flex items-center space-x-2">
                            <button
                                onClick={clearChat}
                                className="text-white hover:text-blue-200 transition-colors p-1 rounded hover:bg-white hover:bg-opacity-10"
                                title="Clear chat"
                            >
                                <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                                </svg>
                            </button>
                            <button
                                onClick={toggleChatbot}
                                className="text-white hover:text-blue-200 transition-colors p-1 rounded hover:bg-white hover:bg-opacity-10"
                                title="Minimize chat"
                            >
                                <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                                </svg>
                            </button>
                        </div>
                    </div>
                </div>

                {/* Schema and Date Selectors */}
                <div className="bg-gray-50 px-4 py-2 border-b border-gray-200">
                    <SchemaSelector
                        selectedSchema={selectedSchema}
                        onSchemaChange={setSelectedSchema}
                        targetDate={targetDate}
                        onDateChange={setTargetDate}
                        compact={true}
                    />
                </div>

                {/* Messages Area */}
                <div
                    ref={chatContainerRef}
                    className="flex-1 overflow-y-auto p-4 space-y-3 bg-gradient-to-b from-gray-50 to-white"
                    style={{ height: '280px' }}
                >
                    <BackendStatus />

                    {messages.map((message) => (
                        <ChatMessage key={message.id} message={message} compact={true} />
                    ))}

                    {isLoading && <LoadingIndicator />}

                    <div ref={messagesEndRef} />
                </div>

                {/* Input Area */}
                <div className="border-t border-gray-200 bg-white rounded-b-2xl">
                    <ChatInput onSendMessage={handleSendMessage} disabled={isLoading} compact={true} />
                </div>
            </div>

            {/* Floating Chat Button */}
            <button
                onClick={toggleChatbot}
                className={`w-14 h-14 bg-gradient-to-r from-blue-600 to-blue-700 hover:from-blue-700 hover:to-blue-800 text-white rounded-full shadow-lg flex items-center justify-center transition-all duration-300 transform hover:scale-110 focus:outline-none focus:ring-4 focus:ring-blue-300 ${isOpen ? 'rotate-180' : 'rotate-0'
                    }`}
                title={isOpen ? 'Close chat' : 'Open chat assistant'}
            >
                {/* Chat Icon */}
                <svg
                    className={`transition-all duration-300 ${isOpen ? 'w-5 h-5' : 'w-6 h-6'}`}
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                >
                    {isOpen ? (
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                    ) : (
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
                    )}
                </svg>

                {/* New Message Indicator */}
                {hasNewMessage && !isOpen && (
                    <div className="absolute -top-1 -right-1 w-4 h-4 bg-red-500 rounded-full flex items-center justify-center animate-pulse">
                        <div className="w-2 h-2 bg-white rounded-full"></div>
                    </div>
                )}
            </button>

            {/* Pulse Animation Ring */}
            {!isOpen && (
                <div className="absolute inset-0 w-14 h-14 rounded-full bg-blue-600 opacity-20 animate-ping pointer-events-none"></div>
            )}
        </div>
    );
}
