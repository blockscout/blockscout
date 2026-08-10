#!/usr/bin/env node

/**
 * Blockscout CLI
 */

import { defaultAiCopilot } from '../src/core/ai-copilot.js';
import { defaultVerifierEngine } from '../src/core/contract-verifier.js';

const args = process.argv.slice(2);
const command = args[0] || 'help';

async function main() {
  switch (command.toLowerCase()) {
    case 'query': {
      const prompt = args.slice(1).join(' ') || 'Analyze DEX swaps and gas utilization on Base';
      console.log(`\n🔍 Blockscout AI Copilot Query: "${prompt}"...`);
      const res = defaultAiCopilot.query(prompt);
      console.log(`  Intent:   ${res.intent}`);
      console.log(`  Summary:  ${res.summary}`);
      console.log('  Insights:');
      res.insights.forEach(i => console.log(`   • ${i}`));
      console.log('');
      break;
    }

    case 'verify': {
      const address = args[1] || '0x4200000000000000000000000000000000000006';
      console.log(`\n🔐 Verifying Smart Contract '${address}' via Sourcify...`);
      const ver = defaultVerifierEngine.verifyContract({ address });
      console.log(`  Status:         ${ver.verificationStatus}`);
      console.log(`  Sourcify Match: ${ver.sourcifyMatch}`);
      console.log(`  Bytecode Hash:  ${ver.bytecodeHash}\n`);
      break;
    }

    case 'studio': {
      console.log('\n🌐 Launching Blockscout Copilot Studio on :3423...');
      await import('../src/server/app.js');
      break;
    }

    default: {
      console.log(`
╔══════════════════════════════════════════════════════════════════╗
║               🔍 BLOCKSCOUT AI COPILOT CLI                       ║
║    Smart Contract Verifier & Natural Language Explorer Suite     ║
╚══════════════════════════════════════════════════════════════════╝

Commands:
  blockscout-cli query [prompt]          Query AI Copilot for transaction insights
  blockscout-cli verify [address]        Verify EVM contract bytecode & Sourcify match
  blockscout-cli studio                  Launch Interactive Web Studio on :3423
      `);
      break;
    }
  }
}

main().catch(err => {
  console.error('Error:', err.message);
  process.exit(1);
});
