'use client';

import { useState } from 'react';
import ChatInterface from './ChatInterface';

export default function ChatWidget() {
    const [isOpen, setIsOpen] = useState(false);

    const toggleChat = () => {
        setIsOpen(!isOpen);
    };

    return (
        <>
            {/* Chat Widget Button */}
            <div className="fixed bottom-6 right-6 z-50">
                <button
                    onClick={toggleChat}
                    className={`w-14 h-14 rounded-full shadow-lg transition-all duration-300 flex items-center justify-center ${isOpen
                            ? 'bg-red-500 hover:bg-red-600 rotate-45'
                            : 'bg-blue-600 hover:bg-blue-700 hover:scale-110'
                        }`}
                    aria-label={isOpen ? 'Close chat' : 'Open chat'}
                >
                    {isOpen ? (
                        <svg className="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
                        </svg>
                    ) : (
                        <svg className="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
                        </svg>
                    )}
                </button>

                {/* Notification badge */}
                {!isOpen && (
                    <div className="absolute -top-1 -right-1 w-5 h-5 bg-red-500 rounded-full flex items-center justify-center animate-pulse">
                        <span className="text-xs text-white font-bold">!</span>
                    </div>
                )}
            </div>

            {/* Chat Panel */}
            <div className={`fixed bottom-24 right-6 z-40 transition-all duration-300 ${isOpen
                    ? 'opacity-100 transform translate-y-0 scale-100'
                    : 'opacity-0 transform translate-y-4 scale-95 pointer-events-none'
                }`}>
                <div className="w-96 h-[500px] max-w-[calc(100vw-3rem)] max-h-[calc(100vh-8rem)]">
                    {isOpen && <ChatInterface />}
                </div>
            </div>

            {/* Backdrop for mobile */}
            {isOpen && (
                <div
                    className="fixed inset-0 bg-black bg-opacity-25 z-30 md:hidden"
                    onClick={toggleChat}
                />
            )}
        </>
    );
}
