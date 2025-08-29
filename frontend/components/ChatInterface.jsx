'use client';

import { useState, useRef, useEffect } from 'react';
import ChatMessage from './ChatMessage';
import ChatInput from './ChatInput';
import LoadingIndicator from './LoadingIndicator';
import SchemaSelector from './SchemaSelector';
import BackendStatus from './BackendStatus';
import { getConversationMemory, resetConversationMemory } from '../lib/conversationMemory';

const INITIAL_MESSAGE = {
    id: 'welcome',
    type: 'assistant',
    content: "Hi! I'm your tax assistant. I can help you with Sri Lankan tax rules, calculations, and forms. Ask me about:\n\n• Tax formulas and calculations\n• Tax rates and brackets\n• Variable sources from documents\n• Available form variables\n\nWhat would you like to know?",
    timestamp: new Date(),
    intent: 'welcome'
};

export default function ChatInterface() {
    const [messages, setMessages] = useState([INITIAL_MESSAGE]);
    const [isLoading, setIsLoading] = useState(false);
    const [selectedSchema, setSelectedSchema] = useState('');
    const [targetDate, setTargetDate] = useState('');
    const messagesEndRef = useRef(null);
    const chatContainerRef = useRef(null);
    const conversationMemory = getConversationMemory();

    // Initialize conversation memory but don't clear on page load
    useEffect(() => {
        // Only reset if explicitly requested (e.g., first time or after explicit clear)
        // Don't clear on page refresh to maintain context during session
        const memory = getConversationMemory();
        const history = memory.getHistory();

        // If we have history but no messages in state, restore from memory
        if (history.length > 0 && messages.length === 1) {
            const restoredMessages = [INITIAL_MESSAGE, ...history.map(msg => ({
                id: msg.id || Date.now().toString(),
                type: msg.type,
                content: msg.content,
                timestamp: new Date(msg.timestamp),
                intent: msg.intent,
                evidence: msg.evidence,
                success: msg.success
            }))];
            setMessages(restoredMessages);
        }
    }, []);

    const scrollToBottom = () => {
        messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
    };

    useEffect(() => {
        scrollToBottom();
    }, [messages]);

    const handleSendMessage = async (question, variable = '') => {
        if (!question.trim()) return;

        const userMessage = {
            id: Date.now().toString(),
            type: 'user',
            content: question,
            timestamp: new Date(),
            metadata: {
                schemaType: selectedSchema,
                date: targetDate,
                variable: variable
            }
        };

        // Add to conversation memory
        conversationMemory.addMessage(userMessage);
        setMessages(prev => [...prev, userMessage]);
        setIsLoading(true);

        try {
            // Get recent conversation context
            const recentContext = conversationMemory.getRecentContext();
            const conversationSummary = conversationMemory.getConversationSummary();

            // Format conversation context as string for backend
            const conversationContextString = recentContext
                .map(msg => `${msg.role}: ${msg.content}`)
                .join('\n');

            const payload = {
                question: question,
                ...(selectedSchema && { schemaType: selectedSchema }),
                ...(targetDate && { date: targetDate }),
                ...(variable && { variable: variable }),
                // Include conversation context for the backend
                conversationContext: conversationContextString,
                conversationSummary: JSON.stringify(conversationSummary)
            };

            const response = await fetch('/api/chat/ask', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(payload),
            });

            const data = await response.json();

            const assistantMessage = {
                id: (Date.now() + 1).toString(),
                type: 'assistant',
                content: data.answer || 'Sorry, I encountered an error processing your request.',
                timestamp: new Date(),
                intent: data.intent,
                evidence: data.evidence,
                success: data.success
            };

            // Add assistant message to conversation memory
            conversationMemory.addMessage(assistantMessage);
            setMessages(prev => [...prev, assistantMessage]);
        } catch (error) {
            console.error('Chat error:', error);
            const errorMessage = {
                id: (Date.now() + 1).toString(),
                type: 'assistant',
                content: 'Sorry, I encountered a connection error. Please try again.',
                timestamp: new Date(),
                intent: 'error',
                success: false
            };
            setMessages(prev => [...prev, errorMessage]);
        } finally {
            setIsLoading(false);
        }
    };

    const clearChat = () => {
        resetConversationMemory();
        setMessages([INITIAL_MESSAGE]);
    };

    return (
        <div className="bg-white rounded-2xl shadow-lg overflow-hidden border border-gray-200">
            {/* Chat Header */}
            <div className="bg-gradient-to-r from-blue-600 to-blue-700 px-6 py-4 border-b border-blue-500">
                <div className="flex items-center justify-between">
                    <div className="flex items-center space-x-3">
                        <div className="w-10 h-10 bg-white bg-opacity-20 rounded-full flex items-center justify-center">
                            <svg className="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
                            </svg>
                        </div>
                        <div>
                            <h2 className="text-lg font-semibold text-white">Tax Assistant</h2>
                            <p className="text-blue-100 text-sm">Ask about Sri Lankan tax rules</p>
                        </div>
                    </div>
                    <button
                        onClick={clearChat}
                        className="text-white hover:text-blue-200 transition-colors p-2 rounded-lg hover:bg-white hover:bg-opacity-10"
                        title="Clear chat"
                    >
                        <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                        </svg>
                    </button>
                </div>
            </div>

            {/* Schema and Date Selectors */}
            <div className="bg-gray-50 px-6 py-4 border-b border-gray-200">
                <SchemaSelector
                    selectedSchema={selectedSchema}
                    onSchemaChange={setSelectedSchema}
                    targetDate={targetDate}
                    onDateChange={setTargetDate}
                />
            </div>

            {/* Messages Area */}
            <div
                ref={chatContainerRef}
                className="flex-1 overflow-y-auto p-6 space-y-4 max-h-96 min-h-96 bg-gradient-to-b from-gray-50 to-white"
            >
                <BackendStatus />

                {messages.map((message) => (
                    <ChatMessage key={message.id} message={message} />
                ))}

                {isLoading && <LoadingIndicator />}

                <div ref={messagesEndRef} />
            </div>

            {/* Input Area */}
            <div className="border-t border-gray-200 bg-white">
                <ChatInput onSendMessage={handleSendMessage} disabled={isLoading} />
            </div>
        </div>
    );
}
