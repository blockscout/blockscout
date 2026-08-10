/**
 * Blockscout AI Copilot & Verifier Unit Tests
 */

import { defaultAiCopilot } from '../src/core/ai-copilot.js';
import { defaultVerifierEngine } from '../src/core/contract-verifier.js';

async function runCopilotTests() {
  console.log('Testing Blockscout AI Copilot & Contract Verifier Engine...');

  // 1. AI Copilot Query
  const copilotRes = defaultAiCopilot.query('Analyze DEX swaps and gas on Base');
  if (!copilotRes.intent || copilotRes.insights.length === 0) {
    throw new Error('AI Copilot query failed');
  }

  // 2. Contract Verifier
  const verRes = defaultVerifierEngine.verifyContract({ address: '0x4200000000000000000000000000000000000006' });
  if (verRes.verificationStatus !== 'VERIFIED_FULL_MATCH') {
    throw new Error('Contract verifier failed');
  }

  console.log(`✅ Blockscout AI Copilot & Contract Verifier Tested (${copilotRes.intent})!`);
}

runCopilotTests().catch(e => {
  console.error('❌ Copilot Test Failed:', e);
  process.exit(1);
});
