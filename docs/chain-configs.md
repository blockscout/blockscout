<!--chain-configs.md -->

## Configuring EVM Chains

* **CSS:** Update the import instruction in `apps/block_scout_web/assets/css/theme/_variables.scss` to select a preset css file. This is reflected in the `production-${chain}` branch for each instance. For example, in the `production-xdai` branch, comment out `@import "neutral_variables` and uncomment `@import "dai-variables"`.

* **ENV:** Update the [environment variables](env-variables.md) to match the chain specs.

### Current css presets
``` bash
@import "theme/base_variables";
@import "neutral_variables";
// @import "dai_variables";
// @import "ethereum_classic_variables";
// @import "ethereum_variables";
// @import "ether1_variables";
// @import "expanse_variables";
// @import "gochain_variables";
// @import "goerli_variables";
// @import "kovan_variables";
// @import "lukso_variables";
// @import "musicoin_variables";
// @import "pirl_variables";
// @import "poa_variables";
// @import "posdao_variables";
// @import "rinkeby_variables";
// @import "ropsten_variables";
// @import "social_variables";
// @import "sokol_variables";
// @import "tobalaba_variables";
// @import "tomochain_variables";
// @import "rsk_variables";
```