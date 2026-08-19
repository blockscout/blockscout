#!/usr/bin/env node
/**
 * Merge all generated OpenAPI specs (public, private, and every chain-specific
 * spec) into a single `openapi/merged.yaml`: a union of `components.schemas` plus
 * a union of `paths`/operations that reference those merged schemas.
 *
 * Run `npm run generate:spec` first; this script only consumes existing YAML files.
 *
 * Schema merge semantics:
 * - `properties` are unioned; `required` is the intersection across specs that
 *   define a schema, so chain-specific properties become optional. Sub-schemas
 *   present in a single spec keep their `required` untouched.
 * - `enum` values are unioned; `nullable` is OR-ed; metadata (description,
 *   examples, x-*) is first-wins with the public spec as the base.
 * - Irreconcilable shapes are combined via `anyOf` and reported as warnings
 *   instead of failing the build.
 *
 * Path merge semantics:
 * - Paths and per-method operations are unioned across specs. Operation bodies
 *   are deep-merged; `parameters` merge by (in, name) with their `schema`s going
 *   through the schema rules above (so e.g. enum query params union their values).
 *   Conflicting scalar metadata is first-wins (public base).
 * - All `$ref`s target `#/components/schemas/*`, so merged operations
 *   automatically reference the merged models.
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

const HTTP_METHODS = new Set(["get", "put", "post", "delete", "options", "head", "patch", "trace"]);

/** A `parameters` array (OpenAPI parameter objects identified by `name` + `in`). */
function isParameterArray(arr) {
  return arr.length > 0 && arr.every((item) => isPlainObject(item) && "name" in item && "in" in item);
}

function mergeArray(a, b, ctxKey, path) {
  // If one side is empty it carries no information; take the other (e.g. one spec
  // declares `parameters: []` while another lists real parameters).
  if (a.length === 0) return clone(b);
  if (b.length === 0) return clone(a);
  // Parameters: merge by (in, name) identity so nested `schema` enums union; keep `a` order, append `b`-only.
  if (isParameterArray(a) && isParameterArray(b)) {
    const key = (param) => `${param.in} ${param.name}`;
    const byKey = new Map(b.map((param) => [key(param), param]));
    const merged = a.map((param) => {
      const match = byKey.get(key(param));
      byKey.delete(key(param));
      return match ? mergeGeneric(param, match, ctxKey, `${path}[${param.in}:${param.name}]`) : clone(param);
    });
    for (const param of b) if (byKey.has(key(param))) merged.push(clone(param));
    return merged;
  }
  // Scalar lists (tags, etc.): union + dedupe.
  if (a.every((item) => typeof item !== "object") && b.every((item) => typeof item !== "object")) {
    return dedupeDeep([...a, ...b]);
  }
  // Anything else (security, servers, examples): first spec wins.
  return clone(a);
}

/**
 * Generic context-aware deep merge for the non-schema layers (paths, operations, responses).
 * Schema values (reached via a `schema` key, or `additionalProperties`) are delegated to mergeNode
 * so schema-specific rules (required intersection, enum/anyOf union) apply throughout the subtree.
 */
function mergeGeneric(a, b, ctxKey, path) {
  if (deepEqual(a, b)) return a;
  if ((ctxKey === "schema" || ctxKey === "additionalProperties") && isPlainObject(a) && isPlainObject(b)) {
    return mergeNode(a, b, path);
  }
  if (Array.isArray(a) && Array.isArray(b)) return mergeArray(a, b, ctxKey, path);
  if (isPlainObject(a) && isPlainObject(b)) {
    const result = {};
    for (const key of [...new Set([...Object.keys(a), ...Object.keys(b)])]) {
      result[key] = key in a && key in b ? mergeGeneric(a[key], b[key], key, `${path}.${key}`) : clone(a[key] ?? b[key]);
    }
    return result;
  }
  // Scalar/shape conflict (description text, etc.): first spec wins (public is the base).
  return clone(a);
}

/** Merge two path-item objects (shared `parameters` plus per-method operations). */
function mergePathItem(a, b, path) {
  const result = {};
  for (const key of [...new Set([...Object.keys(a), ...Object.keys(b)])]) {
    if (key in a && key in b) {
      result[key] = mergeGeneric(a[key], b[key], HTTP_METHODS.has(key) ? "operation" : key, `${path}.${key}`);
    } else {
      result[key] = clone(a[key] ?? b[key]);
    }
  }
  return result;
}

function loadDoc(specPath) {
  return yaml.load(readFileSync(specPath, "utf8")) ?? {};
}

/** Union keyed component buckets (securitySchemes, responses) shallowly; warn on real collisions. */
function mergeKeyedBucket(target, incoming, bucketName) {
  for (const [name, value] of Object.entries(incoming ?? {})) {
    if (name in target && !deepEqual(target[name], value)) {
      warnings.push(`components.${bucketName}.${name}: differs across specs -> kept first`);
    } else if (!(name in target)) {
      target[name] = clone(value);
    }
  }
}

/** Union tag objects by `name`, keeping the first description. */
function mergeTags(target, incoming) {
  const seen = new Set(target.map((tag) => tag.name));
  for (const tag of incoming ?? []) {
    if (!seen.has(tag.name)) {
      seen.add(tag.name);
      target.push(clone(tag));
    }
  }
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
const mergedPaths = {};
const mergedSecuritySchemes = {};
const mergedResponses = {};
const mergedTags = [];

for (const specPath of specPaths) {
  const doc = loadDoc(specPath);

  for (const [name, schema] of Object.entries(doc?.components?.schemas ?? {})) {
    mergedSchemas[name] = name in mergedSchemas ? mergeNode(mergedSchemas[name], schema, name) : clone(schema);
  }

  for (const [path, item] of Object.entries(doc?.paths ?? {})) {
    mergedPaths[path] = path in mergedPaths ? mergePathItem(mergedPaths[path], item, path) : clone(item);
  }

  mergeKeyedBucket(mergedSecuritySchemes, doc?.components?.securitySchemes, "securitySchemes");
  mergeKeyedBucket(mergedResponses, doc?.components?.responses, "responses");
  mergeTags(mergedTags, doc?.tags);
}

const components = { schemas: mergedSchemas };
if (Object.keys(mergedResponses).length > 0) components.responses = mergedResponses;
if (Object.keys(mergedSecuritySchemes).length > 0) components.securitySchemes = mergedSecuritySchemes;

const mergedDoc = {
  openapi: "3.0.0",
  info: {
    title: "Blockscout Merged API",
    description:
      "Public, private, and all chain-specific specs merged into one. Schemas union their properties (required = intersection); paths and operations are unioned and reference the merged schemas.",
    version: "0.0.0",
  },
  servers: [{ url: "/api" }],
  tags: mergedTags,
  paths: mergedPaths,
  components,
};

writeFileSync(OUTPUT_PATH, yaml.dump(mergedDoc, { sortKeys: true, lineWidth: -1 }));
console.log(
  `Merged ${specPaths.length} specs into ${OUTPUT_PATH} (${Object.keys(mergedSchemas).length} schemas, ${Object.keys(mergedPaths).length} paths)`,
);

const uniqueWarnings = [...new Set(warnings)];
if (uniqueWarnings.length > 0) {
  console.warn(`\n${uniqueWarnings.length} merge warning(s):`);
  for (const warning of uniqueWarnings) console.warn(`  - ${warning}`);
}
