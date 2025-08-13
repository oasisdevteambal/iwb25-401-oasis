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

function Field({ name, schema, value, required, onChange }) {
  const type = schema?.type;
  const title = schema?.title || name;
  const description = schema?.description;
  const enumVals = schema?.enum;
  const min = schema?.minimum;
  const pattern = schema?.pattern;

  const commonProps = {
    id: `field-${name}`,
    name,
    className:
      "block w-full rounded border border-gray-300 px-3 py-2 text-sm focus:border-black focus:outline-none",
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
    <div className="mb-4">
      <label htmlFor={`field-${name}`} className="mb-1 block text-sm font-medium">
        {title}
        {required ? <span className="text-red-600"> *</span> : null}
      </label>
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
      {description ? <p className="mt-1 text-xs text-gray-500">{description}</p> : null}
    </div>
  );
}

export default function FormRenderer({ schemaBlob, onSubmit }) {
  const jsonSchema = schemaBlob?.jsonSchema || { type: "object", properties: {} };
  const uiSchema = schemaBlob?.uiSchema || {};
  const required = Array.isArray(jsonSchema?.required) ? jsonSchema.required : [];

  const fields = useMemo(() => getOrderedFields(jsonSchema, uiSchema), [jsonSchema, uiSchema]);
  const [formData, setFormData] = useState({});
  const [errors, setErrors] = useState([]);
  const [submitted, setSubmitted] = useState(null);

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
        } catch {}
      }
    }
    return errs;
  }

  function handleSubmit(e) {
    e.preventDefault();
    const errs = validate();
    setErrors(errs);
    if (errs.length === 0) {
      setSubmitted({ ...formData });
      onSubmit?.(formData);
    }
  }

  return (
    <div className="max-w-2xl">
      <form onSubmit={handleSubmit} noValidate>
        {fields.map((name) => (
          <Field
            key={name}
            name={name}
            schema={jsonSchema.properties?.[name]}
            value={formData[name]}
            required={required.includes(name)}
            onChange={(v) => setFormData((p) => ({ ...p, [name]: v }))}
          />
        ))}
        {errors.length > 0 ? (
          <div className="mb-4 rounded border border-red-300 bg-red-50 p-3 text-sm text-red-700">
            <ul className="list-disc pl-5">
              {errors.map((er, i) => (
                <li key={i}>{er}</li>
              ))}
            </ul>
          </div>
        ) : null}
        <button
          type="submit"
          className="rounded bg-black px-4 py-2 text-white hover:bg-gray-800"
        >
          Submit
        </button>
      </form>
      {submitted ? (
        <pre className="mt-6 overflow-auto rounded bg-gray-100 p-3 text-xs">
{JSON.stringify(submitted, null, 2)}
        </pre>
      ) : null}
    </div>
  );
}
