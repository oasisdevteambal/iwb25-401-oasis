'use client';

export default function LoadingIndicator() {
    return (
        <div className="flex justify-start animate-slideUp">
            <div className="max-w-3xl">
                <div className="flex items-start space-x-3">
                    {/* Avatar */}
                    <div className="w-8 h-8 rounded-full bg-gray-100 text-gray-600 flex items-center justify-center text-sm">
                        <div className="animate-pulse">
                            🤖
                        </div>
                    </div>

                    {/* Loading Message */}
                    <div className="flex-1 px-4 py-3 rounded-2xl rounded-bl-md bg-white border border-gray-200 shadow-sm">
                        <div className="flex items-center space-x-2">
                            <div className="flex space-x-1">
                                <div className="w-2 h-2 bg-blue-600 rounded-full animate-bounce" style={{ animationDelay: '0ms' }}></div>
                                <div className="w-2 h-2 bg-blue-600 rounded-full animate-bounce" style={{ animationDelay: '150ms' }}></div>
                                <div className="w-2 h-2 bg-blue-600 rounded-full animate-bounce" style={{ animationDelay: '300ms' }}></div>
                            </div>
                            <span className="text-sm text-gray-500 animate-pulse">
                                Analyzing your question...
                            </span>
                        </div>

                        {/* Progress Bar */}
                        <div className="mt-3 w-full bg-gray-200 rounded-full h-1">
                            <div className="bg-blue-600 h-1 rounded-full animate-pulse" style={{ width: '60%' }}></div>
                        </div>

                        {/* Loading Steps */}
                        <div className="mt-2 space-y-1">
                            <div className="flex items-center space-x-2 text-xs text-gray-500">
                                <div className="w-1 h-1 bg-green-500 rounded-full animate-pulse"></div>
                                <span>Processing intent...</span>
                            </div>
                            <div className="flex items-center space-x-2 text-xs text-gray-500">
                                <div className="w-1 h-1 bg-blue-500 rounded-full animate-pulse" style={{ animationDelay: '500ms' }}></div>
                                <span>Searching knowledge base...</span>
                            </div>
                            <div className="flex items-center space-x-2 text-xs text-gray-400">
                                <div className="w-1 h-1 bg-gray-300 rounded-full"></div>
                                <span>Generating response...</span>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    );
}
