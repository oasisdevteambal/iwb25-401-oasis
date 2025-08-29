'use client';

import { useState } from 'react';

export default function ChatDemo() {
    const [activeDemo, setActiveDemo] = useState('formulas');

    const demoScenarios = {
        formulas: {
            title: "Tax Formulas",
            icon: "🧮",
            question: "How is income tax calculated?",
            response: "Income tax is calculated using progressive brackets. Here are the formulas we use:",
            evidence: {
                formulas: [
                    {
                        field: "total_tax",
                        formula: "calculateProgressiveTax(taxable_income, tax_brackets)",
                        description: "Main calculation using progressive tax brackets"
                    },
                    {
                        field: "taxable_income",
                        formula: "gross_income - deductions - exemptions",
                        description: "Income after deductions and exemptions"
                    }
                ]
            }
        },
        brackets: {
            title: "Tax Brackets",
            icon: "📊",
            question: "What are the current income tax brackets?",
            response: "Here are the current tax brackets for income tax:",
            evidence: {
                brackets: [
                    { min_income: 0, max_income: 500000, rate_fraction: 0, fixed_amount: 0 },
                    { min_income: 500001, max_income: 750000, rate_fraction: 0.06, fixed_amount: 0 },
                    { min_income: 750001, max_income: 1500000, rate_fraction: 0.12, fixed_amount: 15000 },
                    { min_income: 1500001, max_income: null, rate_fraction: 0.18, fixed_amount: 105000 }
                ]
            }
        },
        provenance: {
            title: "Variable Sources",
            icon: "📄",
            question: "Which document defines the basic_salary variable?",
            response: "The variable 'basic_salary' comes from the following source documents:",
            evidence: {
                variable: "basic_salary",
                sources: [
                    { filename: "employment_tax_guidelines_2024.pdf", document_id: "doc_123" },
                    { filename: "paye_calculation_manual.pdf", document_id: "doc_456" }
                ]
            }
        }
    };

    return (
        <div className="bg-gray-50 py-16">
            <div className="container mx-auto px-4">
                <div className="text-center mb-12">
                    <h2 className="text-3xl font-bold text-gray-900 mb-4">
                        See Our Tax Assistant in Action
                    </h2>
                    <p className="text-lg text-gray-600 max-w-2xl mx-auto">
                        Explore different types of questions you can ask our intelligent chat assistant.
                    </p>
                </div>

                {/* Demo Selector */}
                <div className="flex flex-wrap justify-center gap-4 mb-8">
                    {Object.entries(demoScenarios).map(([key, scenario]) => (
                        <button
                            key={key}
                            onClick={() => setActiveDemo(key)}
                            className={`px-6 py-3 rounded-full font-medium transition-all duration-200 ${activeDemo === key
                                    ? 'bg-blue-600 text-white shadow-lg'
                                    : 'bg-white text-gray-700 hover:bg-gray-50 shadow'
                                }`}
                        >
                            <span className="mr-2">{scenario.icon}</span>
                            {scenario.title}
                        </button>
                    ))}
                </div>

                {/* Demo Chat Interface */}
                <div className="max-w-4xl mx-auto">
                    <div className="bg-white rounded-2xl shadow-lg overflow-hidden">
                        {/* Header */}
                        <div className="bg-gradient-to-r from-blue-600 to-blue-700 px-6 py-4">
                            <div className="flex items-center space-x-3">
                                <div className="w-10 h-10 bg-white bg-opacity-20 rounded-full flex items-center justify-center">
                                    <svg className="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
                                    </svg>
                                </div>
                                <div>
                                    <h3 className="text-lg font-semibold text-white">Tax Assistant Demo</h3>
                                    <p className="text-blue-100 text-sm">{demoScenarios[activeDemo].title}</p>
                                </div>
                            </div>
                        </div>

                        {/* Chat Messages */}
                        <div className="p-6 space-y-4 bg-gradient-to-b from-gray-50 to-white min-h-[400px]">
                            {/* User Message */}
                            <div className="flex justify-end animate-slideUp">
                                <div className="max-w-3xl">
                                    <div className="flex items-start space-x-3 flex-row-reverse space-x-reverse">
                                        <div className="w-8 h-8 rounded-full bg-blue-600 text-white flex items-center justify-center text-sm">
                                            <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                                                <path fillRule="evenodd" d="M10 9a3 3 0 100-6 3 3 0 000 6zm-7 9a7 7 0 1114 0H3z" clipRule="evenodd" />
                                            </svg>
                                        </div>
                                        <div className="flex-1 px-4 py-3 rounded-2xl bg-blue-600 text-white rounded-br-md">
                                            <div className="text-sm leading-relaxed">
                                                {demoScenarios[activeDemo].question}
                                            </div>
                                            <div className="text-xs mt-2 text-blue-100">
                                                Just now
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>

                            {/* Assistant Response */}
                            <div className="flex justify-start animate-slideUp" style={{ animationDelay: '0.5s' }}>
                                <div className="max-w-3xl">
                                    <div className="flex items-start space-x-3">
                                        <div className="w-8 h-8 rounded-full bg-gray-100 text-gray-600 flex items-center justify-center text-sm">
                                            <span>{demoScenarios[activeDemo].icon}</span>
                                        </div>
                                        <div className="flex-1 px-4 py-3 rounded-2xl bg-white text-gray-800 border border-gray-200 rounded-bl-md shadow-sm">
                                            <div className="text-sm leading-relaxed mb-3">
                                                {demoScenarios[activeDemo].response}
                                            </div>

                                            {/* Evidence Section */}
                                            <div className="p-3 bg-blue-50 rounded-lg border border-blue-200">
                                                <div className="flex items-center justify-between mb-2">
                                                    <span className="text-sm font-medium text-blue-800">📊 Supporting Evidence</span>
                                                </div>

                                                {/* Render specific evidence based on demo type */}
                                                {demoScenarios[activeDemo].evidence.formulas && (
                                                    <div className="space-y-2">
                                                        <h4 className="font-medium text-blue-800 text-sm">Formulas:</h4>
                                                        {demoScenarios[activeDemo].evidence.formulas.map((formula, index) => (
                                                            <div key={index} className="bg-white p-2 rounded border">
                                                                <div className="font-mono text-xs text-gray-800">
                                                                    {formula.field}: {formula.formula}
                                                                </div>
                                                                <div className="text-xs text-gray-600 mt-1">
                                                                    {formula.description}
                                                                </div>
                                                            </div>
                                                        ))}
                                                    </div>
                                                )}

                                                {demoScenarios[activeDemo].evidence.brackets && (
                                                    <div>
                                                        <h4 className="font-medium text-blue-800 text-sm mb-2">Tax Brackets:</h4>
                                                        <div className="overflow-x-auto">
                                                            <table className="min-w-full bg-white rounded border text-xs">
                                                                <thead className="bg-gray-50">
                                                                    <tr>
                                                                        <th className="px-2 py-1 text-left font-medium text-gray-500">Min Income</th>
                                                                        <th className="px-2 py-1 text-left font-medium text-gray-500">Max Income</th>
                                                                        <th className="px-2 py-1 text-left font-medium text-gray-500">Rate</th>
                                                                        <th className="px-2 py-1 text-left font-medium text-gray-500">Fixed Amount</th>
                                                                    </tr>
                                                                </thead>
                                                                <tbody className="divide-y divide-gray-200">
                                                                    {demoScenarios[activeDemo].evidence.brackets.map((bracket, index) => (
                                                                        <tr key={index}>
                                                                            <td className="px-2 py-1 text-gray-900">{bracket.min_income.toLocaleString()}</td>
                                                                            <td className="px-2 py-1 text-gray-900">{bracket.max_income?.toLocaleString() || 'No Limit'}</td>
                                                                            <td className="px-2 py-1 text-gray-900">{(bracket.rate_fraction * 100).toFixed(1)}%</td>
                                                                            <td className="px-2 py-1 text-gray-900">{bracket.fixed_amount.toLocaleString()}</td>
                                                                        </tr>
                                                                    ))}
                                                                </tbody>
                                                            </table>
                                                        </div>
                                                    </div>
                                                )}

                                                {demoScenarios[activeDemo].evidence.sources && (
                                                    <div>
                                                        <h4 className="font-medium text-blue-800 text-sm mb-2">Source Documents:</h4>
                                                        <div className="space-y-2">
                                                            {demoScenarios[activeDemo].evidence.sources.map((source, index) => (
                                                                <div key={index} className="bg-white p-2 rounded border flex items-center space-x-2">
                                                                    <svg className="w-4 h-4 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                                                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                                                                    </svg>
                                                                    <span className="text-xs text-gray-700">{source.filename}</span>
                                                                </div>
                                                            ))}
                                                        </div>
                                                    </div>
                                                )}
                                            </div>

                                            <div className="text-xs mt-2 text-gray-500">
                                                Just now
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>

                        {/* Footer CTA */}
                        <div className="bg-gray-50 px-6 py-4 border-t border-gray-200">
                            <div className="text-center">
                                <p className="text-sm text-gray-600 mb-3">
                                    Ready to try it yourself?
                                </p>
                                <a href="/chat" className="btn btn-primary">
                                    Start Chatting with Tax Assistant
                                </a>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    );
}
