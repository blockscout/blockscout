/**
 * Blockscout AI Copilot & Verifier Studio Server
 */

import express from 'express';
import cors from 'cors';
import path from 'path';
import { fileURLToPath } from 'url';
import { BLOCKSCOUT_CONFIG } from '../config.js';
import { defaultAiCopilot } from '../core/ai-copilot.js';
import { defaultVerifierEngine } from '../core/contract-verifier.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const WEB_ROOT = path.join(__dirname, '../../web');

const app = express();
const PORT = process.env.PORT || 3423;

app.use(cors());
app.use(express.json());
app.use(express.static(WEB_ROOT));

// 1. Config & Sample Contracts
app.get('/api/config', (req, res) => {
  res.json({
    explorer: BLOCKSCOUT_CONFIG.explorer,
    capabilities: BLOCKSCOUT_CONFIG.copilotCapabilities,
    samples: BLOCKSCOUT_CONFIG.sampleContracts,
  });
});

// 2. Query AI Copilot
app.post('/api/copilot/query', (req, res) => {
  try {
    const { prompt } = req.body;
    const response = defaultAiCopilot.query(prompt);
    res.json(response);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// 3. Verify Smart Contract
app.post('/api/contract/verify', (req, res) => {
  try {
    const result = defaultVerifierEngine.verifyContract(req.body);
    res.json(result);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// 4. Verification History
app.get('/api/verification/history', (req, res) => {
  res.json(defaultVerifierEngine.getHistory());
});

if (process.env.NODE_ENV !== 'test') {
  app.listen(PORT, () => {
    console.log(`\n======================================================`);
    console.log(`🔍 Blockscout AI Copilot & Contract Verifier Studio Running!`);
    console.log(`🌐 Web Dashboard: http://localhost:${PORT}`);
    console.log(`⚡ Open-Source EVM Explorer Infrastructure`);
    console.log(`======================================================\n`);
  });
}

export default app;
