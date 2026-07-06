/**
 * Generated types grouped by OpenAPI spec. Regenerate: `npm run build` from `types-package/`.
 */

/** Default public API (no `CHAIN_TYPE`). */
export * as publicApi from "./dist/public.schema";

/** Private account API (`BlockScoutWeb.Specs.Private`). */
export * as privateApi from "./dist/private.schema";

/** All specs (public, private, every chain) merged into one — unified `schemas`, `paths`, and `operations`. Chain-specific properties are optional. Regenerate: `npm run generate:spec:merged`. */
import * as merged from "./dist/merged.schema";
export { merged };
/** Shorthand for merged.components["schemas"] */
export type schemas = merged.components["schemas"];

/* ── Successful-response shorthands (derived from the merged spec) ────────────
   Resolve the 200 `application/json` body of an endpoint without the deep
   `…["responses"][200]["content"]["application/json"]` indexing. */

type HttpMethod = "get" | "put" | "post" | "delete" | "options" | "head" | "patch" | "trace";

/** The 200 `application/json` response body of an operation (or `never` if it has none). */
type OkJson<Operation> = Operation extends {
  responses: { 200: { content: { "application/json": infer Body } } };
}
  ? Body
  : never;

/** The request parameters of an operation (`query`, `path`; `header`/`cookie` usually empty). */
type OperationParams<Operation> = Operation extends { parameters: infer Params } ? Params : never;

/**
 * The `application/json` request body of an operation (or `never` if it has none).
 * `requestBody` is optional in the generated types, so the pattern matches it optionally.
 */
type RequestJson<Operation> = Operation extends { requestBody?: infer RequestBody }
  ? RequestBody extends { content: { "application/json": infer Body } }
    ? Body
    : never
  : never;

/** Drop the controller module prefix (v2, account v2, or legacy) from an operationId. */
type ShortOperationId<Id extends string> = Id extends `BlockScoutWeb.API.V2.${infer Rest}`
  ? Rest
  : Id extends `BlockScoutWeb.Account.API.V2.${infer Rest}`
    ? Rest
    : Id extends `BlockScoutWeb.API.Legacy.${infer Rest}`
      ? Rest
      : Id;

/**
 * Per-operation shape keyed by short operationId:
 *  - `json`: the 200 `application/json` response body
 *  - `params`: the request parameters (`query`, `path`; `header`/`cookie` usually empty)
 *  - `requestBody`: the `application/json` request body (`never` for endpoints without one)
 * e.g. `operations["BlockController.internal_transactions"]["json"]`.
 */
export type operations = {
  [Id in keyof merged.operations as ShortOperationId<Id & string>]: {
    json: OkJson<merged.operations[Id]>;
    params: OperationParams<merged.operations[Id]>;
    requestBody: RequestJson<merged.operations[Id]>;
  };
};

/**
 * Successful (200) JSON response bodies keyed by path, then HTTP method, e.g.
 * `paths["/v2/blocks/{block_hash_or_number_param}/internal-transactions"]["get"]`.
 * Only the methods an endpoint actually defines are present.
 */
export type paths = {
  [Path in keyof merged.paths]: {
    [Method in HttpMethod as [merged.paths[Path][Method]] extends [never] ? never : Method]: OkJson<
      merged.paths[Path][Method]
    >;
  };
};

/** Chain-specific public API (`CHAIN_TYPE` set). */
export * as arbitrum from "./dist/chains/arbitrum.schema";
export * as arc from "./dist/chains/arc.schema";
export * as blackfort from "./dist/chains/blackfort.schema";
export * as ethereum from "./dist/chains/ethereum.schema";
export * as filecoin from "./dist/chains/filecoin.schema";
export * as neon from "./dist/chains/neon.schema";
export * as optimism from "./dist/chains/optimism.schema";
export * as optimismCelo from "./dist/chains/optimism-celo.schema";
export * as rsk from "./dist/chains/rsk.schema";
export * as scroll from "./dist/chains/scroll.schema";
export * as shibarium from "./dist/chains/shibarium.schema";
export * as stability from "./dist/chains/stability.schema";
export * as suave from "./dist/chains/suave.schema";
export * as zetachain from "./dist/chains/zetachain.schema";
export * as zilliqa from "./dist/chains/zilliqa.schema";
export * as zksync from "./dist/chains/zksync.schema";
