'use client';

/**
 * Conversation Memory Manager
 * Handles storing and retrieving conversation history from browser storage
 * without any database persistence
 * 
 * Uses sessionStorage so memory persists during the session but clears on:
 * - Page refresh (explicitly cleared by ChatInterface)
 * - Tab close (automatically by browser)
 * - Browser restart
 */

export class ConversationMemory {
    constructor(sessionId = null) {
        // Maintain a stable session id per browser tab so history survives navigations
        const SESSION_ID_KEY = 'chat_session_id';
        let stableId = sessionId;
        try {
            if (!stableId) {
                const existing = sessionStorage.getItem(SESSION_ID_KEY);
                stableId = existing || this.generateSessionId();
                // Store for subsequent reloads/navigations in this tab
                sessionStorage.setItem(SESSION_ID_KEY, stableId);
            }
        } catch (e) {
            // Fallback if sessionStorage is unavailable
            stableId = stableId || this.generateSessionId();
        }
        this.sessionId = stableId;
        this.storageKey = `chat_history_${this.sessionId}`;
        this.maxMessages = 20; // Keep last 20 messages for context
        this.maxContextMessages = 5; // Send last 5 messages as context
    }

    generateSessionId() {
        return `session_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    }

    // Add a message to conversation history
    addMessage(message) {
        const history = this.getHistory();
        
        // Add timestamp if not present
        if (!message.timestamp) {
            message.timestamp = Date.now();
        }

        history.push(message);

        // Keep only the last maxMessages
        if (history.length > this.maxMessages) {
            history.splice(0, history.length - this.maxMessages);
        }

        this.saveHistory(history);
        return message;
    }

    // Get full conversation history
    getHistory() {
        try {
            const stored = sessionStorage.getItem(this.storageKey);
            return stored ? JSON.parse(stored) : [];
        } catch (error) {
            console.warn('Failed to load conversation history:', error);
            return [];
        }
    }

    // Get recent context for sending to backend
    getRecentContext(includeUserMessages = true, includeAssistantMessages = true) {
        const history = this.getHistory();
        
        // Filter messages based on type preferences
        const filteredHistory = history.filter(msg => {
            if (msg.type === 'user' && includeUserMessages) return true;
            if (msg.type === 'assistant' && includeAssistantMessages && msg.success) return true;
            return false;
        });

        // Get the last few messages for context
        const recentMessages = filteredHistory.slice(-this.maxContextMessages);
        
        // Format for backend consumption
        return recentMessages.map(msg => ({
            role: msg.type === 'user' ? 'user' : 'assistant',
            content: msg.content,
            timestamp: msg.timestamp,
            intent: msg.intent,
            evidence: msg.evidence // Include evidence for assistant messages
        }));
    }

    // Get conversation summary for context
    getConversationSummary() {
        const history = this.getHistory();
        if (history.length === 0) return null;

        const recentMessages = history.slice(-5);
        const topics = new Set();
        const formulas = [];
        const taxTypes = new Set();

        recentMessages.forEach(msg => {
            if (msg.intent) topics.add(msg.intent);
            if (msg.evidence?.schemaType) taxTypes.add(msg.evidence.schemaType);
            if (msg.evidence?.formulas) {
                msg.evidence.formulas.forEach(formula => {
                    formulas.push({
                        name: formula.name || formula.id,
                        expression: formula.expression || formula.formula
                    });
                });
            }
        });

        return {
            messageCount: history.length,
            recentTopics: Array.from(topics),
            discussedTaxTypes: Array.from(taxTypes),
            recentFormulas: formulas,
            lastActivity: recentMessages[recentMessages.length - 1]?.timestamp
        };
    }

    // Save history to sessionStorage
    saveHistory(history) {
        try {
            sessionStorage.setItem(this.storageKey, JSON.stringify(history));
        } catch (error) {
            console.warn('Failed to save conversation history:', error);
        }
    }

    // Clear conversation history
    clearHistory() {
        try {
            sessionStorage.removeItem(this.storageKey);
        } catch (error) {
            console.warn('Failed to clear conversation history:', error);
        }
    }

    // Check if we have recent context about a topic
    hasRecentContext(searchTerms = []) {
        const context = this.getRecentContext();
        const searchText = context
            .map(msg => msg.content.toLowerCase())
            .join(' ');

        return searchTerms.some(term => 
            searchText.includes(term.toLowerCase())
        );
    }

    // Get specific information from recent context
    findInRecentContext(searchTerms = []) {
        const context = this.getRecentContext();
        const matches = [];

        context.forEach(msg => {
            const content = msg.content.toLowerCase();
            searchTerms.forEach(term => {
                if (content.includes(term.toLowerCase())) {
                    matches.push({
                        message: msg,
                        term: term
                    });
                }
            });
        });

        return matches;
    }

    // Export conversation for debugging
    exportConversation() {
        return {
            sessionId: this.sessionId,
            history: this.getHistory(),
            summary: this.getConversationSummary()
        };
    }
}

// Singleton instance for the current session
let conversationMemory = null;

export function getConversationMemory() {
    if (!conversationMemory) {
        conversationMemory = new ConversationMemory();
    }
    return conversationMemory;
}

export function resetConversationMemory() {
    // Clear history but keep the same session id so future messages continue the same tab session
    if (conversationMemory) {
        const currentId = conversationMemory.sessionId;
        conversationMemory.clearHistory();
        conversationMemory = new ConversationMemory(currentId);
    } else {
        conversationMemory = new ConversationMemory();
    }
    return conversationMemory;
}
