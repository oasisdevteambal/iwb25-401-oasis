'use client';

import ChatInterface from '../../components/ChatInterface';

export default function ChatPage() {
  return (
    <div className="container mx-auto px-4 py-8 max-w-6xl">
      <div className="mb-8 text-center">
        <h1 className="text-3xl font-bold text-gray-900 mb-4">
          Tax Assistant Chat
        </h1>
        <p className="text-lg text-gray-600 max-w-2xl mx-auto">
          Ask me anything about Sri Lankan tax rules, calculations, or our tax forms. 
          I can help you understand formulas, rates, brackets, and variable sources.
        </p>
      </div>
      
      <ChatInterface />
    </div>
  );
}
