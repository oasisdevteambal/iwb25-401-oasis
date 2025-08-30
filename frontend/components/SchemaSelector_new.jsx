'use client';

export default function SchemaSelector({ selectedSchema, onSchemaChange, targetDate, onDateChange, compact = false }) {
    const schemas = [
        { value: '', label: 'All Tax Types', description: 'General tax questions' },
        { value: 'income_tax', label: 'Income Tax', description: 'Personal income tax calculations' },
        { value: 'paye', label: 'PAYE', description: 'Pay As You Earn tax' },
        { value: 'vat', label: 'VAT', description: 'Value Added Tax' }
    ];

    return (
        <div className={compact ? "flex flex-col sm:flex-row gap-2" : "flex flex-col sm:flex-row gap-4"}>
            {/* Schema Type Selector */}
            <div className="flex-1">
                <label className={`block ${compact ? 'text-xs' : 'text-sm'} font-medium text-gray-700 ${compact ? 'mb-1' : 'mb-2'}`}>
                    Tax Type Focus
                </label>
                <div className="relative">
                    <select
                        value={selectedSchema}
                        onChange={(e) => onSchemaChange(e.target.value)}
                        className={`w-full ${compact ? 'px-2 py-1 text-xs' : 'px-3 py-2'} border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent appearance-none bg-white`}
                    >
                        {schemas.map((schema) => (
                            <option key={schema.value} value={schema.value}>
                                {schema.label}
                            </option>
                        ))}
                    </select>
                    <div className="absolute inset-y-0 right-0 flex items-center px-2 pointer-events-none">
                        <svg className="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                        </svg>
                    </div>
                </div>
                {!compact && (
                    <p className="text-xs text-gray-500 mt-1">
                        {schemas.find(s => s.value === selectedSchema)?.description}
                    </p>
                )}
            </div>

            {/* Date Selector */}
            <div className="flex-1">
                <label className={`block ${compact ? 'text-xs' : 'text-sm'} font-medium text-gray-700 ${compact ? 'mb-1' : 'mb-2'}`}>
                    Effective Date (Optional)
                </label>
                <input
                    type="date"
                    value={targetDate}
                    onChange={(e) => onDateChange(e.target.value)}
                    className={`w-full ${compact ? 'px-2 py-1 text-xs' : 'px-3 py-2'} border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent`}
                />
                {!compact && (
                    <p className="text-xs text-gray-500 mt-1">
                        Leave empty for latest rules
                    </p>
                )}
            </div>

            {/* Visual Indicators */}
            {!compact && (
                <div className="flex items-end">
                    <div className="flex flex-col space-y-1">
                        {selectedSchema && (
                            <div className="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-800 animate-fadeIn">
                                <span className="w-2 h-2 bg-blue-600 rounded-full mr-1"></span>
                                {schemas.find(s => s.value === selectedSchema)?.label}
                            </div>
                        )}
                        {targetDate && (
                            <div className="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-green-100 text-green-800 animate-fadeIn">
                                <span className="w-2 h-2 bg-green-600 rounded-full mr-1"></span>
                                {new Date(targetDate).toLocaleDateString()}
                            </div>
                        )}
                    </div>
                </div>
            )}
        </div>
    );
}
