/**
 * Blockscout Studio Client Logic
 */

document.addEventListener('DOMContentLoaded', () => {
  initTabs();
  initListeners();
});

function initTabs() {
  const tabs = document.querySelectorAll('.nav-tab');
  tabs.forEach(tab => {
    tab.addEventListener('click', () => {
      document.querySelectorAll('.nav-tab').forEach(t => t.classList.toggle('active', t === tab));
      document.querySelectorAll('.tab-pane').forEach(p => p.classList.toggle('active', p.id === `tab-${tab.dataset.tab}`));
    });
  });
}

function initListeners() {
  const preset = document.getElementById('select-preset-prompt');
  const input = document.getElementById('input-prompt');

  preset.addEventListener('change', () => {
    input.value = preset.value;
  });
  input.value = preset.value;

  // Copilot Query
  document.getElementById('copilot-form').addEventListener('submit', async (e) => {
    e.preventDefault();
    const btn = document.getElementById('btn-run-copilot');
    const container = document.getElementById('insights-container');

    const prompt = input.value;
    btn.disabled = true;
    btn.textContent = '🔍 Analyzing EVM Execution Trace...';

    try {
      const res = await fetch('/api/copilot/query', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ prompt }),
      });
      const data = await res.json();

      container.innerHTML = `
        <div style="font-weight: 700; color: #10b981; font-size: 1.1rem; margin-bottom: 0.5rem;">
          🤖 Intent: ${data.intent}
        </div>
        <div style="color: #fff; margin-bottom: 1rem; font-size: 0.95rem;">${data.summary}</div>
        <div style="font-weight: 600; color: var(--text-muted); font-size: 0.85rem; margin-bottom: 0.35rem;">Key AI Insights:</div>
        <ul style="list-style: none; display: flex; flex-direction: column; gap: 6px;">
          ${data.insights.map(i => `<li style="font-size: 0.88rem; color: #6ee7b7;">• ${i}</li>`).join('')}
        </ul>
      `;
    } catch (err) {
      container.innerHTML = `<div class="badge red">Query error: ${err.message}</div>`;
    } finally {
      btn.disabled = false;
      btn.textContent = '🔍 Ask Blockscout Copilot';
    }
  });

  // Contract Verification
  document.getElementById('verify-form').addEventListener('submit', async (e) => {
    e.preventDefault();
    const address = document.getElementById('verify-address').value;
    const box = document.getElementById('verify-json-box');

    try {
      const res = await fetch('/api/contract/verify', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ address }),
      });
      const data = await res.json();
      box.textContent = JSON.stringify(data, null, 2);
    } catch (err) {
      box.textContent = `Error: ${err.message}`;
    }
  });
}
