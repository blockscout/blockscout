#!/usr/bin/env node
/**
 * Merge `components.schemas` from all generated OpenAPI specs (public, private,
 * and every chain-specific spec) into a single `openapi/merged.yaml`.
 *
 * Run `npm run generate:spec` first; this script only consumes existing YAML files.
 *
 * Merge semantics:
 * - Schemas only (no `paths`) — all $refs point to `#/components/schemas/*`.
 * - `properties` are unioned; `required` is the intersection across specs that
 *   define a schema, so chain-specific properties become optional. Sub-schemas
 *   present in a single spec keep their `required` untouched.
 * - `enum` values are unioned; `nullable` is OR-ed; metadata (description,
 *   examples, x-*) is first-wins with the public spec as the base.
 * - Irreconcilable shapes are combined via `anyOf` and reported as warnings
 *   instead of failing the build.
 */
import { readFileSync, readdirSync, writeFileSync, existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import yaml from "js-yaml";

const PACKAGE_ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const OPENAPI_DIR = join(PACKAGE_ROOT, "openapi");
const OUTPUT_PATH = join(OPENAPI_DIR, "merged.yaml");

const warnings = [];

function isPlainObject(value) {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function deepEqual(a, b) {
  if (a === b) return true;
  if (Array.isArray(a) && Array.isArray(b)) {
    return a.length === b.length && a.every((item, i) => deepEqual(item, b[i]));
  }
  if (isPlainObject(a) && isPlainObject(b)) {
    const keysA = Object.keys(a);
    const keysB = Object.keys(b);
    return keysA.length === keysB.length && keysA.every((key) => key in b && deepEqual(a[key], b[key]));
  }
  return false;
}

function clone(value) {
  return value === undefined ? undefined : structuredClone(value);
}

function dedupeDeep(items) {
  const result = [];
  for (const item of items) {
    if (!result.some((existing) => deepEqual(existing, item))) result.push(item);
  }
  return result;
}

function isObjectSchema(node) {
  return node.type === "object" || (node.type === undefined && (node.properties !== undefined || node.additionalProperties !== undefined));
}

/** Wrap conflicting schemas in an `anyOf` union, flattening members of prior conflict unions. */
function conflictUnion(a, b, path, reason) {
  warnings.push(`${path}: ${reason} -> anyOf`);
  const members = [a, b].flatMap((node) => (isConflictUnion(node) ? node.anyOf : [node]));
  return { anyOf: dedupeDeep(members.map(clone)) };
}

/** A bare `{anyOf: [...]}` node, as produced by conflictUnion (specs always carry x-* metadata). */
function isConflictUnion(node) {
  return isPlainObject(node) && node.anyOf !== undefined && Object.keys(node).length === 1;
}

/** Merge two schema nodes describing the same location in two specs. */
function mergeNode(a, b, path) {
  if (deepEqual(a, b)) return a;

  // A prior conflict union absorbs the other side (dedupe keeps it from growing per spec).
  if (isConflictUnion(a) || isConflictUnion(b)) {
    const union = isConflictUnion(a) ? a : b;
    const other = isConflictUnion(a) ? b : a;
    if (union.anyOf.some((member) => deepEqual(member, other))) return union;
    return { anyOf: dedupeDeep([...union.anyOf, other].map(clone)) };
  }

  // $ref nodes: equal refs were caught by deepEqual above; anything else conflicts.
  if (a.$ref !== undefined || b.$ref !== undefined) {
    return conflictUnion(a, b, path, `$ref conflict (${a.$ref ?? "inline"} vs ${b.$ref ?? "inline"})`);
  }

  // Composition keywords.
  if (a.allOf !== undefined && b.allOf !== undefined) {
    return { ...metaFirstWins(a, b), allOf: dedupeDeep([...clone(a.allOf), ...clone(b.allOf)]) };
  }
  for (const keyword of ["oneOf", "anyOf"]) {
    if (a[keyword] !== undefined && b[keyword] !== undefined) {
      const merged = dedupeDeep([...clone(a[keyword]), ...clone(b[keyword])]);
      if (keyword === "oneOf" && merged.length > a[keyword].length) {
        warnings.push(`${path}: oneOf gained members (${a[keyword].length} -> ${merged.length})`);
      }
      return { ...metaFirstWins(a, b), [keyword]: merged };
    }
  }
  const aComposed = a.allOf !== undefined || a.oneOf !== undefined || a.anyOf !== undefined;
  const bComposed = b.allOf !== undefined || b.oneOf !== undefined || b.anyOf !== undefined;
  if (aComposed !== bComposed) {
    return conflictUnion(a, b, path, "composition vs plain schema");
  }

  // Enums: union, first-seen order.
  if (a.enum !== undefined && b.enum !== undefined && (a.type === b.type || a.type === undefined || b.type === undefined)) {
    return { ...metaFirstWins(a, b), enum: dedupeDeep([...a.enum, ...b.enum]) };
  }

  // Genuine type conflict (and not both objects).
  if (a.type !== undefined && b.type !== undefined && a.type !== b.type) {
    return conflictUnion(a, b, path, `type conflict (${a.type} vs ${b.type})`);
  }

  if (isObjectSchema(a) && isObjectSchema(b)) return mergeObjectSchemas(a, b, path);

  if (a.type === "array" && b.type === "array") {
    const result = metaFirstWins(a, b);
    result.type = "array";
    if (a.items !== undefined && b.items !== undefined) {
      result.items = mergeNode(a.items, b.items, `${path}[]`);
    } else if (a.items !== undefined || b.items !== undefined) {
      result.items = clone(a.items ?? b.items);
    }
    for (const facet of ["minItems", "maxItems"]) {
      if (a[facet] !== undefined && b[facet] !== undefined && a[facet] !== b[facet]) {
        warnings.push(`${path}: ${facet} conflict (${a[facet]} vs ${b[facet]}) -> dropped`);
        delete result[facet];
      }
    }
    return result;
  }

  // Same scalar type, differing metadata only.
  if (a.type !== undefined && a.type === b.type) {
    const result = metaFirstWins(a, b);
    result.type = a.type;
    if (a.enum !== undefined || b.enum !== undefined) result.enum = dedupeDeep([...(a.enum ?? []), ...(b.enum ?? [])]);
    return result;
  }

  return conflictUnion(a, b, path, "unmergeable shapes");
}

const STRUCTURAL_KEYS = new Set(["$ref", "type", "properties", "required", "items", "enum", "additionalProperties", "nullable", "allOf", "oneOf", "anyOf"]);

/** Non-structural keys (description, example, x-*, ...): first spec wins. */
function metaFirstWins(a, b) {
  const result = {};
  for (const source of [b, a]) {
    for (const [key, value] of Object.entries(source)) {
      if (!STRUCTURAL_KEYS.has(key)) result[key] = clone(value);
    }
  }
  if (a.nullable || b.nullable) result.nullable = true;
  return result;
}

function mergeObjectSchemas(a, b, path) {
  const result = metaFirstWins(a, b);
  result.type = "object";

  const propsA = a.properties ?? {};
  const propsB = b.properties ?? {};
  const keys = [...new Set([...Object.keys(propsA), ...Object.keys(propsB)])];
  if (keys.length > 0) {
    result.properties = {};
    for (const key of keys) {
      if (key in propsA && key in propsB) {
        result.properties[key] = mergeNode(propsA[key], propsB[key], `${path}.${key}`);
      } else {
        result.properties[key] = clone(propsA[key] ?? propsB[key]);
      }
    }
  }

  // Required = intersection: properties absent from any defining spec become optional.
  const required = (a.required ?? []).filter((key) => (b.required ?? []).includes(key));
  if (required.length > 0) result.required = required;

  const apA = a.additionalProperties;
  const apB = b.additionalProperties;
  if (deepEqual(apA, apB)) {
    if (apA !== undefined) result.additionalProperties = clone(apA);
  } else if (apA === true || apB === true) {
    // One side is explicitly open: widen to the explicit open form.
    result.additionalProperties = true;
  } else if (isPlainObject(apA) && isPlainObject(apB)) {
    result.additionalProperties = mergeNode(apA, apB, `${path}.<additionalProperties>`);
  } else {
    // One side is closed (false) or typed while the other is absent: widen to open.
    warnings.push(`${path}: additionalProperties disagreement (${JSON.stringify(apA)} vs ${JSON.stringify(apB)}) -> dropped`);
  }

  return result;
}

function loadSchemas(specPath) {
  const doc = yaml.load(readFileSync(specPath, "utf8"));
  return doc?.components?.schemas ?? {};
}

// Deterministic order: public is the base, then private, then chains alphabetically.
const publicPath = join(OPENAPI_DIR, "public.yaml");
if (!existsSync(publicPath)) {
  console.error("openapi/public.yaml not found. Run `npm run generate:spec` first.");
  process.exit(1);
}
const chainsDir = join(OPENAPI_DIR, "chains");
const specPaths = [
  publicPath,
  join(OPENAPI_DIR, "private.yaml"),
  ...(existsSync(chainsDir)
    ? readdirSync(chainsDir)
        .filter((file) => file.endsWith(".yaml"))
        .sort()
        .map((file) => join(chainsDir, file))
    : []),
].filter((specPath) => {
  if (existsSync(specPath)) return true;
  console.log(`Skipping missing ${specPath}`);
  return false;
});

const mergedSchemas = {};
for (const specPath of specPaths) {
  for (const [name, schema] of Object.entries(loadSchemas(specPath))) {
    mergedSchemas[name] = name in mergedSchemas ? mergeNode(mergedSchemas[name], schema, name) : clone(schema);
  }
}

const mergedDoc = {
  openapi: "3.0.0",
  info: {
    title: "Blockscout Merged API",
    description: "Schemas merged from the public, private, and all chain-specific specs. Schemas only; no paths.",
    version: "0.0.0",
  },
  paths: {},
  components: { schemas: mergedSchemas },
};

writeFileSync(OUTPUT_PATH, yaml.dump(mergedDoc, { sortKeys: true, lineWidth: -1 }));
console.log(`Merged ${specPaths.length} specs (${Object.keys(mergedSchemas).length} schemas) into ${OUTPUT_PATH}`);

const uniqueWarnings = [...new Set(warnings)];
if (uniqueWarnings.length > 0) {
  console.warn(`\n${uniqueWarnings.length} merge warning(s):`);
  for (const warning of uniqueWarnings) console.warn(`  - ${warning}`);
}
