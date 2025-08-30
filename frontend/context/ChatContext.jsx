'use client';

import { createContext, useContext, useState, useEffect, useCallback } from 'react';
import { getConversationMemory, resetConversationMemory } from '../lib/conversationMemory';

const INITIAL_MESSAGE = {
    id: 'welcome',
    type: 'assistant',
    content: "Hi! I'm your tax assistant. I can help you with Sri Lankan tax rules, calculations, and forms. Ask me about:\n\n• Tax formulas and calculations\n• Tax rates and brackets\n• Variable sources from documents\n• Available form variables\n\nWhat would you like to know?",
    timestamp: new Date(),
    intent: 'welcome'
};

// Create context
const ChatContext = createContext();

// Custom hook to use chat context
export const useChat = () => {
    const context = useContext(ChatContext);
    if (!context) {
        throw new Error('useChat must be used within a ChatProvider');
    }
    return context;
};

// Chat provider component
export const ChatProvider = ({ children }) => {
    const [isOpen, setIsOpen] = useState(false);
    const [isMinimizing, setIsMinimizing] = useState(false);
    const [messages, setMessages] = useState([INITIAL_MESSAGE]);
    const [isLoading, setIsLoading] = useState(false);
    const [selectedSchema, setSelectedSchema] = useState('');
    const [targetDate, setTargetDate] = useState('');
    const [hasNewMessage, setHasNewMessage] = useState(false);
    const [isInitialized, setIsInitialized] = useState(false);

    const conversationMemory = getConversationMemory();

    // Initialize conversation memory once
    useEffect(() => {
        if (!isInitialized) {
            const memory = getConversationMemory();
            const history = memory.getHistory();

            if (history.length > 0) {
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
            setIsInitialized(true);
        }
    }, [isInitialized]);

    // Show notification when chatbot is closed and new message arrives
    useEffect(() => {
        if (!isOpen && messages.length > 1 && messages[messages.length - 1].type === 'assistant') {
            setHasNewMessage(true);
        }
    }, [messages, isOpen]);

    const toggleChatbot = useCallback(() => {
        if (isOpen) {
            setIsMinimizing(true);
            setTimeout(() => {
                setIsOpen(false);
                setIsMinimizing(false);
            }, 200);
        } else {
            setIsOpen(true);
            setHasNewMessage(false);
        }
    }, [isOpen]);

    const handleSendMessage = useCallback(async (question, variable = '') => {
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

        conversationMemory.addMessage(userMessage);
        setMessages(prev => [...prev, userMessage]);
        setIsLoading(true);

        try {
            const recentContext = conversationMemory.getRecentContext();
            const conversationSummary = conversationMemory.getConversationSummary();

            const conversationContextString = recentContext
                .map(msg => `${msg.role}: ${msg.content}`)
                .join('\n');

            const payload = {
                question: question,
                ...(selectedSchema && { schemaType: selectedSchema }),
                ...(targetDate && { date: targetDate }),
                ...(variable && { variable: variable }),
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
    }, [selectedSchema, targetDate, conversationMemory]);

    const clearChat = useCallback(() => {
        resetConversationMemory();
        setMessages([INITIAL_MESSAGE]);
    }, []);

    const value = {
        // State
        isOpen,
        isMinimizing,
        messages,
        isLoading,
        selectedSchema,
        targetDate,
        hasNewMessage,
        isInitialized,

        // Actions
        setSelectedSchema,
        setTargetDate,
        toggleChatbot,
        handleSendMessage,
        clearChat
    };

    return (
        <ChatContext.Provider value={value}>
            {children}
        </ChatContext.Provider>
    );
};
