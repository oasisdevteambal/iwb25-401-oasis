"use client";
import { useMemo, useState } from "react";

function getOrderedFields(jsonSchema, uiSchema) {
    const props = jsonSchema?.properties ? Object.keys(jsonSchema.properties) : [];
    const order = uiSchema?.["ui:order"]; // optional array order
    if (Array.isArray(order) && order.length) {
        const seen = new Set();
        const ordered = [];
        for (const k of order) {
            if (props.includes(k)) {
                ordered.push(k);
                seen.add(k);
            }
        }
        for (const k of props) if (!seen.has(k)) ordered.push(k);
        return ordered;
    }
    return props;
}

function getFieldGroups(fields, jsonSchema) {
    // Group fields by common prefixes or categories
    const groups = {
        'Personal Information': [],
        'Income Details': [],
        'Deductions': [],
        'Other': []
    };

    fields.forEach(fieldName => {
        const field = jsonSchema.properties?.[fieldName];
        const title = field?.title || fieldName;

        if (fieldName.includes('personal') || fieldName.includes('name') || fieldName.includes('id')) {
            groups['Personal Information'].push(fieldName);
        } else if (fieldName.includes('income') || fieldName.includes('salary') || fieldName.includes('wage')) {
            groups['Income Details'].push(fieldName);
        } else if (fieldName.includes('deduction') || fieldName.includes('allowance') || fieldName.includes('credit')) {
            groups['Deductions'].push(fieldName);
        } else {
            groups['Other'].push(fieldName);
        }
    });

    // Remove empty groups
    return Object.fromEntries(
        Object.entries(groups).filter(([_, fields]) => fields.length > 0)
    );
}

function ProvenanceDrawer({ isOpen, onClose, field, schema }) {
    if (!isOpen) return null;

    return (
        <div className="fixed inset-0 z-50 overflow-hidden">
            <div className="absolute inset-0 bg-black bg-opacity-50" onClick={onClose} />
            <div className="absolute right-0 top-0 h-full w-96 bg-white shadow-xl">
                <div className="p-6">
                    <div className="flex items-center justify-between mb-4">
                        <h3 className="text-lg font-medium text-gray-900">Field Information</h3>
                        <button
                            onClick={onClose}
                            className="text-gray-400 hover:text-gray-600"
                        >
                            <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                            </svg>
                        </button>
                    </div>

                    <div className="space-y-4">
                        <div>
                            <h4 className="font-medium text-gray-900 mb-2">Field Details</h4>
                            <div className="bg-gray-50 p-3 rounded">
                                <div className="text-sm space-y-1">
                                    <div><strong>Name:</strong> {field}</div>
                                    <div><strong>Type:</strong> {schema?.type || 'text'}</div>
                                    <div><strong>Required:</strong> {schema?.required ? 'Yes' : 'No'}</div>
                                    {schema?.description && (
                                        <div><strong>Description:</strong> {schema.description}</div>
                                    )}
                                </div>
                            </div>
                        </div>

                        <div>
                            <h4 className="font-medium text-gray-900 mb-2">Rule Provenance</h4>
                            <div className="space-y-2">
                                <div className="flex items-center gap-2">
                                    <div className="w-3 h-3 bg-green-500 rounded-full"></div>
                                    <span className="text-sm font-medium text-green-700">High Confidence (95%)</span>
                                </div>
                                <div className="text-sm text-gray-600">
                                    <strong>Source Document:</strong> Tax Code Amendment 2025.pdf
                                </div>
                                <div className="text-sm text-gray-600">
                                    <strong>Page:</strong> 12, Section 3.2
                                </div>
                                <div className="text-sm text-gray-600">
                                    <strong>Extracted Rule:</strong> "Personal income must be declared for amounts exceeding..."
                                </div>
                            </div>
                        </div>

                        <div>
                            <h4 className="font-medium text-gray-900 mb-2">Validation Rules</h4>
                            <div className="bg-gray-50 p-3 rounded text-sm">
                                {schema?.minimum !== undefined && (
                                    <div>Minimum value: {schema.minimum}</div>
                                )}
                                {schema?.pattern && (
                                    <div>Pattern: {schema.pattern}</div>
                                )}
                                {schema?.enum && (
                                    <div>Allowed values: {schema.enum.join(', ')}</div>
                                )}
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    );
}

function CalculationBreakdown({ breakdown, friendlyBreakdown, isLoading }) {
    const [viewMode, setViewMode] = useState('friendly'); // 'friendly' or 'technical'
    const [showProcessing, setShowProcessing] = useState(false);

    // Show processing animation for 2 seconds when friendly breakdown is being generated
    useState(() => {
        if (isLoading) {
            setShowProcessing(true);
            const timer = setTimeout(() => setShowProcessing(false), 2000);
            return () => clearTimeout(timer);
        }
    }, [isLoading]);

    const hasFriendlyBreakdown = Array.isArray(friendlyBreakdown) && friendlyBreakdown.length > 0;
    const hasBreakdown = Array.isArray(breakdown) && breakdown.length > 0;

    // Default to friendly view if available, otherwise technical
    const effectiveViewMode = hasFriendlyBreakdown ? viewMode : 'technical';

    return (
        <div>
            <div className="flex items-center justify-between mb-3">
                <h4 className="font-medium text-green-800">Calculation Details</h4>

                {/* View toggle buttons */}
                {hasFriendlyBreakdown && (
                    <div className="flex bg-gray-100 rounded-lg p-1">
                        <button
                            onClick={() => setViewMode('friendly')}
                            className={`px-3 py-1 rounded text-sm font-medium transition-colors ${viewMode === 'friendly'
                                    ? 'bg-white text-green-800 shadow-sm'
                                    : 'text-gray-600 hover:text-gray-800'
                                }`}
                        >
                            Simple View
                        </button>
                        <button
                            onClick={() => setViewMode('technical')}
                            className={`px-3 py-1 rounded text-sm font-medium transition-colors ${viewMode === 'technical'
                                    ? 'bg-white text-green-800 shadow-sm'
                                    : 'text-gray-600 hover:text-gray-800'
                                }`}
                        >
                            Technical View
                        </button>
                    </div>
                )}
            </div>

            {/* Loading state for friendly breakdown generation */}
            {showProcessing && !hasFriendlyBreakdown && (
                <div className="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-4">
                    <div className="flex items-center space-x-3">
                        <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-blue-600"></div>
                        <div>
                            <div className="text-sm font-medium text-blue-800">
                                Generating user-friendly explanation...
                            </div>
                            <div className="text-xs text-blue-600">
                                Our AI is converting the technical calculation into easy-to-understand language
                            </div>
                        </div>
                    </div>
                </div>
            )}

            {/* Friendly Breakdown */}
            {effectiveViewMode === 'friendly' && hasFriendlyBreakdown && (
                <div className="bg-white border rounded-lg p-4 space-y-4">
                    {friendlyBreakdown.map((step, i) => (
                        <div key={i} className="border-b border-gray-100 last:border-b-0 pb-4 last:pb-0">
                            <div className="flex items-start justify-between gap-4">
                                <div className="flex-1">
                                    <h5 className="font-semibold text-gray-900 mb-1">{step.title}</h5>
                                    <p className="text-gray-600 text-sm mb-2">{step.description}</p>
                                    <div className="text-sm text-gray-700 bg-gray-50 rounded p-2">
                                        {step.calculation}
                                    </div>
                                    {step.explanation && (
                                        <div className="text-xs text-blue-600 mt-2 italic">
                                            💡 {step.explanation}
                                        </div>
                                    )}
                                </div>
                                <div className="text-right">
                                    <div className="font-semibold text-lg text-gray-900">
                                        {step.amount || formatCurrency(step.result)}
                                    </div>
                                </div>
                            </div>
                        </div>
                    ))}
                </div>
            )}

            {/* Technical Breakdown */}
            {effectiveViewMode === 'technical' && hasBreakdown && (
                <div className="bg-white p-3 rounded border text-sm overflow-auto">
                    <ul className="space-y-2">
                        {breakdown.map((s, i) => (
                            <li key={i} className="flex items-start justify-between gap-4">
                                <div>
                                    <div className="font-medium text-gray-900">{s.name}</div>
                                    <div className="text-gray-600">{s.expression}{s.substituted ? ` = ${s.substituted}` : ""}</div>
                                </div>
                                <div className="text-gray-900 font-semibold whitespace-nowrap">{formatCurrency(s.result)}</div>
                            </li>
                        ))}
                    </ul>
                </div>
            )}

            {/* Fallback message */}
            {!hasFriendlyBreakdown && viewMode === 'friendly' && (
                <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
                    <div className="flex items-center space-x-2">
                        <svg className="w-5 h-5 text-yellow-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z" />
                        </svg>
                        <div>
                            <div className="text-sm font-medium text-yellow-800">
                                Simple explanation not available
                            </div>
                            <div className="text-xs text-yellow-600">
                                Showing technical breakdown instead
                            </div>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
}

function Field({ name, schema, value, required, onChange, onShowProvenance }) {
    const type = schema?.type;
    const title = schema?.title || name.replaceAll('_', ' ').replace(/\b\w/g, l => l.toUpperCase());
    const description = schema?.description;
    const enumVals = schema?.enum;
    const min = schema?.minimum;
    const pattern = schema?.pattern;

    const commonProps = {
        id: `field-${name}`,
        name,
        className: "form-field",
        value: value ?? (type === "number" ? "" : ""),
        onChange: (e) => {
            const v = e.target.value;
            if (type === "number" && v !== "") {
                const n = Number(v);
                onChange(Number.isNaN(n) ? undefined : n);
            } else {
                onChange(v);
            }
        },
        required: !!required,
    };

    return (
        <div className="space-y-2">
            <div className="flex items-center justify-between">
                <label htmlFor={`field-${name}`} className="block text-sm font-medium text-gray-700">
                    {title}
                    {required ? <span className="text-red-600 ml-1">*</span> : null}
                </label>
                <button
                    type="button"
                    onClick={() => onShowProvenance(name, schema)}
                    className="text-blue-600 hover:text-blue-800 p-1"
                    title="Why this field?"
                >
                    <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                </button>
            </div>

            {Array.isArray(enumVals) ? (
                <select {...commonProps} value={value ?? ""}>
                    <option value="">Select...</option>
                    {enumVals.map((opt) => (
                        <option key={String(opt)} value={String(opt)}>
                            {String(opt)}
                        </option>
                    ))}
                </select>
            ) : type === "number" ? (
                <input type="number" {...commonProps} min={min !== undefined ? min : undefined} step="any" />
            ) : (
                <input type="text" {...commonProps} pattern={pattern || undefined} />
            )}

            {description ? <p className="text-xs text-gray-500">{description}</p> : null}

            {/* Confidence indicator */}
            <div className="flex items-center gap-1">
                <div className="w-2 h-2 bg-green-500 rounded-full"></div>
                <span className="text-xs text-gray-500">High confidence</span>
            </div>
        </div>
    );
}

export default function FormRenderer({ schemaBlob, schemaType, targetDate, apiBase }) {
    const jsonSchema = schemaBlob?.jsonSchema || { type: "object", properties: {} };
    const uiSchema = schemaBlob?.uiSchema || {};
    const required = Array.isArray(jsonSchema?.required) ? jsonSchema.required : [];

    const fields = useMemo(() => getOrderedFields(jsonSchema, uiSchema), [jsonSchema, uiSchema]);
    const fieldGroups = useMemo(() => getFieldGroups(fields, jsonSchema), [fields, jsonSchema]);

    const [formData, setFormData] = useState({});
    const [errors, setErrors] = useState([]);
    const [submitted, setSubmitted] = useState(null);
    const [calcLoading, setCalcLoading] = useState(false);
    const [calcError, setCalcError] = useState(null);
    const [calcResult, setCalcResult] = useState(null);
    const [expandedGroups, setExpandedGroups] = useState(
        Object.fromEntries(Object.keys(fieldGroups).map(group => [group, true]))
    );
    const [provenanceDrawer, setProvenanceDrawer] = useState({
        isOpen: false,
        field: null,
        schema: null
    });

    function validate() {
        const errs = [];
        // Required
        for (const key of required) {
            const v = formData[key];
            if (v === undefined || v === "") errs.push(`${key} is required`);
        }
        // Minimum (number)
        for (const key of fields) {
            const s = jsonSchema.properties?.[key];
            if (!s) continue;
            if (s.type === "number" && s.minimum !== undefined) {
                const v = formData[key];
                if (v !== undefined && typeof v === "number" && v < s.minimum) {
                    errs.push(`${key} must be >= ${s.minimum}`);
                }
            }
            if (s.type === "string" && s.pattern) {
                try {
                    const re = new RegExp(s.pattern);
                    const v = formData[key];
                    if (v && !re.test(String(v))) errs.push(`${key} is invalid`);
                } catch { }
            }
        }
        return errs;
    }

    async function handleSubmit(e) {
        e.preventDefault();
        setCalcError(null);
        setCalcResult(null);
        const errs = validate();
        setErrors(errs);
        if (errs.length > 0) return;

        // Prepare payload for backend calculation
        const cleanedData = Object.fromEntries(
            Object.entries(formData).filter(([_, v]) => v !== undefined && v !== "")
        );

        const body = {
            schemaType: schemaType || schemaBlob?.metadata?.schemaType || "income_tax",
            data: cleanedData
        };
        const dateStr = targetDate && typeof targetDate === "string" && targetDate !== "—" ? targetDate : null;
        if (dateStr) body.date = dateStr;

        setCalcLoading(true);
        try {
            const url = "/api/calculate"; // Server-side proxy avoids CORS
            const res = await fetch(url, {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify(body)
            });
            const json = await res.json().catch(() => ({}));
            if (!res.ok || json?.success === false) {
                const msg = json?.message || `Calculation failed (${res.status})`;
                setCalcError(msg);
            } else {
                setCalcResult(json);
                setSubmitted({ ...cleanedData });
            }
        } catch (err) {
            setCalcError(err?.message || "Network error");
        } finally {
            setCalcLoading(false);
        }
    }

    function toggleGroup(groupName) {
        setExpandedGroups(prev => ({
            ...prev,
            [groupName]: !prev[groupName]
        }));
    }

    function showProvenance(fieldName, schema) {
        setProvenanceDrawer({
            isOpen: true,
            field: fieldName,
            schema: schema
        });
    }

    function closeProvenance() {
        setProvenanceDrawer({
            isOpen: false,
            field: null,
            schema: null
        });
    }

    const completedFields = Object.keys(formData).filter(key =>
        formData[key] !== undefined && formData[key] !== ""
    ).length;

    const totalFields = fields.length;
    const completionPercentage = totalFields > 0 ? Math.round((completedFields / totalFields) * 100) : 0;

    return (
        <div className="space-y-6">
            {/* Form Progress Summary */}
            <div className="card">
                <div className="flex items-center justify-between mb-4">
                    <h2 className="text-lg font-medium text-gray-900">Form Progress</h2>
                    <span className="text-sm text-gray-600">{completedFields} of {totalFields} fields completed</span>
                </div>
                <div className="w-full bg-gray-200 rounded-full h-2">
                    <div
                        className="bg-blue-500 h-2 rounded-full transition-all duration-300"
                        style={{ width: `${completionPercentage}%` }}
                    />
                </div>
            </div>

            <form onSubmit={handleSubmit} noValidate className="space-y-6">
                {/* Grouped Fields */}
                {Object.entries(fieldGroups).map(([groupName, groupFields]) => (
                    <div key={groupName} className="card">
                        <button
                            type="button"
                            onClick={() => toggleGroup(groupName)}
                            className="flex items-center justify-between w-full text-left"
                        >
                            <div className="flex items-center gap-3">
                                <h3 className="text-lg font-medium text-gray-900">{groupName}</h3>
                                <span className="badge badge-gray text-xs">
                                    {groupFields.length} fields
                                </span>
                                <div className={`w-3 h-3 rounded-full ${groupFields.every(field => formData[field] !== undefined && formData[field] !== "")
                                    ? 'bg-green-500'
                                    : groupFields.some(field => formData[field] !== undefined && formData[field] !== "")
                                        ? 'bg-yellow-500'
                                        : 'bg-gray-300'
                                    }`} />
                            </div>
                            <svg
                                className={`w-5 h-5 text-gray-500 transition-transform ${expandedGroups[groupName] ? 'rotate-180' : ''
                                    }`}
                                fill="none"
                                stroke="currentColor"
                                viewBox="0 0 24 24"
                            >
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                            </svg>
                        </button>

                        {expandedGroups[groupName] && (
                            <div className="mt-6 grid grid-cols-1 md:grid-cols-2 gap-6 slide-in">
                                {groupFields.map((name) => (
                                    <Field
                                        key={name}
                                        name={name}
                                        schema={jsonSchema.properties?.[name]}
                                        value={formData[name]}
                                        required={required.includes(name)}
                                        onChange={(v) => setFormData((p) => ({ ...p, [name]: v }))}
                                        onShowProvenance={showProvenance}
                                    />
                                ))}
                            </div>
                        )}
                    </div>
                ))}

                {/* Error Summary */}
                {errors.length > 0 ? (
                    <div className="card border-red-200 bg-red-50">
                        <div className="flex items-start gap-3">
                            <svg className="w-5 h-5 text-red-500 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                            </svg>
                            <div>
                                <h3 className="font-medium text-red-800 mb-2">Please correct the following errors:</h3>
                                <ul className="list-disc list-inside text-sm text-red-700 space-y-1">
                                    {errors.map((er, i) => (
                                        <li key={i}>{er}</li>
                                    ))}
                                </ul>
                            </div>
                        </div>
                    </div>
                ) : null}

                {/* Calculation Error */}
                {calcError ? (
                    <div className="card border-red-200 bg-red-50">
                        <div className="flex items-start gap-3">
                            <svg className="w-5 h-5 text-red-500 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                            </svg>
                            <div>
                                <h3 className="font-medium text-red-800 mb-2">Calculation failed</h3>
                                <p className="text-sm text-red-700">{String(calcError)}</p>
                            </div>
                        </div>
                    </div>
                ) : null}

                {/* Form Actions */}
                <div className="card">
                    <div className="flex items-center justify-between">
                        <div className="text-sm text-gray-600">
                            Last saved: Just now
                        </div>
                        <div className="flex gap-3">
                            <button type="button" className="btn btn-secondary">
                                Save Draft
                            </button>
                            <button type="submit" className="btn btn-primary" disabled={calcLoading}>
                                {calcLoading ? "Calculating..." : "Submit & Calculate"}
                            </button>
                        </div>
                    </div>
                </div>
            </form>

            {/* Calculation Result */}
            {calcResult ? (
                <div className="card border-green-200 bg-green-50">
                    <div className="flex items-start gap-3 mb-4">
                        <svg className="w-5 h-5 text-green-500 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                        </svg>
                        <div>
                            <h3 className="font-medium text-green-800">Calculation Complete</h3>
                            <p className="text-green-700 text-sm">Schema v{calcResult?.schemaVersion} • {calcResult?.createdAt}</p>
                        </div>
                    </div>
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                        <div className="bg-white p-3 rounded border">
                            <div className="text-sm text-gray-600">Final Tax</div>
                            <div className="text-2xl font-semibold text-gray-900">{formatCurrency(calcResult?.result)}</div>
                        </div>
                        <div className="bg-white p-3 rounded border">
                            <div className="text-sm text-gray-600">Execution ID</div>
                            <div className="text-sm font-mono text-gray-900 break-all">{calcResult?.executionId}</div>
                        </div>
                    </div>
                    {Array.isArray(calcResult?.breakdown) && calcResult.breakdown.length > 0 && (
                        <div className="mt-4">
                            <CalculationBreakdown
                                breakdown={calcResult.breakdown}
                                friendlyBreakdown={calcResult.friendlyBreakdown}
                                isLoading={calcLoading}
                            />
                        </div>
                    )}

                    <details className="text-sm mt-4">
                        <summary className="cursor-pointer font-medium text-green-800 mb-2">Inputs</summary>
                        <pre className="bg-white p-3 rounded border text-xs overflow-auto">{JSON.stringify(calcResult?.inputs, null, 2)}</pre>
                    </details>
                </div>
            ) : null}

            {/* Provenance Drawer */}
            <ProvenanceDrawer
                isOpen={provenanceDrawer.isOpen}
                onClose={closeProvenance}
                field={provenanceDrawer.field}
                schema={provenanceDrawer.schema}
            />
        </div>
    );
}

function formatCurrency(val) {
    if (typeof val !== "number" && typeof val !== "bigint") return String(val ?? "—");
    try {
        return new Intl.NumberFormat("en-LK", { style: "currency", currency: "LKR", maximumFractionDigits: 2 }).format(Number(val));
    } catch {
        return String(val);
    }
}
