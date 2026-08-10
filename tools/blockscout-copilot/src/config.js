/**
 * Blockscout AI Copilot & Contract Verification Configuration
 */

export const BLOCKSCOUT_CONFIG = {
  explorer: {
    name: 'Blockscout Open-Source EVM Explorer',
    license: 'GPL-3.0',
    supportedChains: ['Ethereum Mainnet', 'Base', 'Optimism', 'Arbitrum One', 'Polygon zkEVM', 'Mode'],
  },
  copilotCapabilities: [
    'Natural Language Transaction Querying',
    'Smart Contract Bytecode Explanation & Decompilation',
    'Re-Entrancy & Security Vulnerability Alerting',
    'Automated Sourcify & Standard JSON Contract Verification',
  ],
  sampleContracts: [
    {
      address: '0x4200000000000000000000000000000000000006',
      name: 'WETH9 (Wrapped Ether)',
      compiler: 'v0.8.20+commit.a1b79de6',
      verified: true,
      sourcifyMatch: 'EXACT_MATCH',
    },
    {
      address: '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913',
      name: 'USDC Token (Base Mainnet)',
      compiler: 'v0.8.23+commit.f704f362',
      verified: true,
      sourcifyMatch: 'EXACT_MATCH',
    },
  ],
};
