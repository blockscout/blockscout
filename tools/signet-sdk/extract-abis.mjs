/**
 * Extract ABIs from @signet-sh/sdk and save as JSON files for use in Elixir.
 * 
 * Run with: npm run extract
 * Output: ../../apps/explorer/priv/contracts_abi/signet/
 */

import { writeFileSync, mkdirSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

import {
  rollupOrdersAbi,
  hostOrdersAbi,
  passageAbi,
  rollupPassageAbi,
  permit2Abi,
  wethAbi,
  zenithAbi,
  transactorAbi,
  bundleHelperAbi,
} from '@signet-sh/sdk';

const __dirname = dirname(fileURLToPath(import.meta.url));
const OUTPUT_DIR = join(__dirname, '../../apps/explorer/priv/contracts_abi/signet');

// Ensure output directory exists
mkdirSync(OUTPUT_DIR, { recursive: true });

const abis = {
  'rollup_orders': rollupOrdersAbi,
  'host_orders': hostOrdersAbi,
  'passage': passageAbi,
  'rollup_passage': rollupPassageAbi,
  'permit2': permit2Abi,
  'weth': wethAbi,
  'zenith': zenithAbi,
  'transactor': transactorAbi,
  'bundle_helper': bundleHelperAbi,
};

for (const [name, abi] of Object.entries(abis)) {
  const outputPath = join(OUTPUT_DIR, `${name}.json`);
  writeFileSync(outputPath, JSON.stringify(abi, null, 2));
  console.log(`Wrote ${outputPath}`);
}

// Also create a combined file with event signatures for quick reference
const events = [];
for (const [name, abi] of Object.entries(abis)) {
  for (const item of abi) {
    if (item.type === 'event') {
      events.push({
        contract: name,
        name: item.name,
        signature: `${item.name}(${item.inputs.map(i => i.type).join(',')})`,
        inputs: item.inputs,
      });
    }
  }
}

const eventsPath = join(OUTPUT_DIR, 'events_index.json');
writeFileSync(eventsPath, JSON.stringify(events, null, 2));
console.log(`Wrote ${eventsPath}`);

console.log('\nExtraction complete!');
