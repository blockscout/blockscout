# 🔍 Blockscout Studio & AI Copilot

An interactive **AI Explorer Copilot**, **Automated Smart Contract Verifier**, and **Sourcify Matcher** for **Blockscout**.

---

## 🌟 Key Features

- 🔍 **Natural Language EVM Querying**: Translate user questions into transaction traces, DEX swap statistics, and gas metrics.
- 🔐 **Automated Contract Verification**: Standard JSON input verifier with exact Sourcify bytecode matching.
- 🌐 **Interactive Web Studio**: Live EVM explorer assistant and contract verifier on `http://localhost:3423`.
- ⌨️ **Universal CLI (`blockscout-cli`)**: Terminal utility for querying transactions and verifying contracts.

---

## 🚀 Quickstart

```bash
# Launch Blockscout Studio
npm start
# Open http://localhost:3423

# Or run via CLI
node bin/blockscout-cli.js query "Analyze DEX swaps and gas utilization on Base"
node bin/blockscout-cli.js verify "0x4200000000000000000000000000000000000006"
```
