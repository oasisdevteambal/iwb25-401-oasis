'use client';

/**
 * Simple markdown-like renderer for chat responses
 * Supports: emojis, bullet points, numbered lists, bold text, line breaks, sections
 */
export default function MarkdownRenderer({ content }) {
    if (!content || typeof content !== 'string') {
        return <span>{content}</span>;
    }

    const renderContent = (text) => {
        // Split by double line breaks to create paragraphs
        const paragraphs = text.split('\n\n');

        return paragraphs.map((paragraph, pIndex) => {
            // Skip empty paragraphs
            if (!paragraph.trim()) return null;

            // Check for code blocks (```...```)
            const codeBlockMatch = paragraph.match(/^```[\s\S]*?```$/);
            if (codeBlockMatch) {
                const codeContent = paragraph.replace(/^```\w*\n?/, '').replace(/```$/, '');
                return (
                    <div key={pIndex} className="mb-4">
                        <div className="bg-gray-900 text-gray-100 p-4 rounded-lg font-mono text-sm overflow-x-auto">
                            <pre className="whitespace-pre-wrap">{codeContent}</pre>
                        </div>
                    </div>
                );
            }

            const lines = paragraph.split('\n');

            // Check if this is a list (starts with bullet points or numbers)
            const isBulletList = lines.some(line => line.trim().match(/^[•\-\*]\s/));
            const isNumberedList = lines.some(line => line.trim().match(/^\d+\.\s/));

            if (isBulletList || isNumberedList) {
                return (
                    <div key={pIndex} className="mb-4">
                        {isBulletList ? (
                            <ul className="space-y-2 ml-4">
                                {lines.map((line, lIndex) => {
                                    const match = line.trim().match(/^[•\-\*]\s(.+)/);
                                    if (match) {
                                        return (
                                            <li key={lIndex} className="flex items-start">
                                                <span className="text-blue-600 mr-2 mt-1">•</span>
                                                <span>{formatInlineText(match[1])}</span>
                                            </li>
                                        );
                                    }
                                    return formatInlineText(line);
                                })}
                            </ul>
                        ) : (
                            <ol className="space-y-2 ml-4">
                                {lines.map((line, lIndex) => {
                                    const match = line.trim().match(/^(\d+)\.\s(.+)/);
                                    if (match) {
                                        return (
                                            <li key={lIndex} className="flex items-start">
                                                <span className="text-blue-600 mr-2 mt-1 font-medium">{match[1]}.</span>
                                                <span>{formatInlineText(match[2])}</span>
                                            </li>
                                        );
                                    }
                                    return formatInlineText(line);
                                })}
                            </ol>
                        )}
                    </div>
                );
            }

            // Check if this is a header (starts with ##, ###, etc)
            const headerMatch = paragraph.match(/^(#{1,3})\s(.+)/);
            if (headerMatch) {
                const level = headerMatch[1].length;
                const text = headerMatch[2];
                const HeaderTag = `h${Math.min(level + 2, 6)}`;

                return (
                    <div key={pIndex} className="mb-3">
                        <HeaderTag className={`font-semibold text-gray-800 ${level === 1 ? 'text-lg' : level === 2 ? 'text-base' : 'text-sm'
                            }`}>
                            {formatInlineText(text)}
                        </HeaderTag>
                    </div>
                );
            }

            // Regular paragraph
            return (
                <div key={pIndex} className="mb-3">
                    {lines.map((line, lIndex) => (
                        <div key={lIndex}>
                            {formatInlineText(line)}
                            {lIndex < lines.length - 1 && <br />}
                        </div>
                    ))}
                </div>
            );
        }).filter(Boolean);
    };

    const formatInlineText = (text) => {
        if (!text) return '';

        // Handle bold text **text**
        let formatted = text.replace(/\*\*(.*?)\*\*/g, '<strong class="font-semibold text-gray-900">$1</strong>');

        // Handle code spans `code`
        formatted = formatted.replace(/`([^`]+)`/g, '<code class="bg-gray-100 px-1 py-0.5 rounded text-sm font-mono text-gray-800">$1</code>');

        // Split by HTML tags to preserve them while processing emojis
        const parts = formatted.split(/(<[^>]+>)/);

        return (
            <span
                dangerouslySetInnerHTML={{
                    __html: parts.map(part => {
                        // If it's an HTML tag, return as-is
                        if (part.match(/^<[^>]+>$/)) {
                            return part;
                        }
                        // Otherwise, just return the text (emojis are handled naturally by the browser)
                        return part;
                    }).join('')
                }}
            />
        );
    };

    return (
        <div className="prose prose-sm max-w-none">
            {renderContent(content)}
        </div>
    );
}
