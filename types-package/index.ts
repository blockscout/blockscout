/**
 * Generated types grouped by OpenAPI spec. Regenerate: `npm run build` from `types-package/`.
 */

/** Default public API (no `CHAIN_TYPE`). */
export * as publicApi from "./dist/public.schema";

/** Private account API (`BlockScoutWeb.Specs.Private`). */
export * as privateApi from "./dist/private.schema";

/** All specs (public, private, every chain) merged into one. Schemas only; chain-specific properties are optional. Regenerate: `npm run build:merged`. */
import * as merged from "./dist/merged.schema";
export { merged };
/** Shorthand for merged.components["schemas"] */
export type schemas = merged.components["schemas"];

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
