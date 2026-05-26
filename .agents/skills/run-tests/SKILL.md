---
name: run-tests
description: "Use this skill whenever you need to run Elixir/Mix tests for the Blockscout project. This includes: running a specific test file, running all tests for an app, running tests after writing or modifying code, or verifying test results. Trigger on any mention of 'mix test', 'run tests', 'run the tests', 'test this', 'verify tests pass', or when you've just written code and need to confirm it works."
---

# Running Blockscout Tests

Spawn the **test-runner** agent with the mix command and chain type. The agent runs the tests via a script that handles all environment setup automatically.

## How to invoke

Use the Agent tool with `subagent_type: "test-runner"`. Include in the prompt:

1. The mix command with the full `apps/<app>/test/...` path
2. `CHAIN_TYPE=<value>` if the tests are chain-specific

### Prompt examples

```
Run: mix test apps/explorer/test/explorer/chain_test.exs
```

```
Run: mix test apps/block_scout_web/test/block_scout_web/controllers/api/v2/arbitrum_controller_test.exs. CHAIN_TYPE=arbitrum
```

```
Run: mix test apps/indexer/test/indexer/fetcher/token_balance_test.exs:42
```

The agent and script handle everything else automatically:
- `TEST_DATABASE_URL` and `MIX_ENV=test`
- `--no-start` for `block_scout_web` tests
- `cd apps/<app>` for non-`block_scout_web` tests (avoids chromedriver dependency)
- Devcontainer delegation when mix is not available on the host

## CHAIN_TYPE

Chain-specific tests are gated with compile-time checks (e.g., `if @chain_type == :arbitrum`). If `CHAIN_TYPE` does not match, you get `0 tests, 0 failures` with no error — this is **not** a pass, it means the tests were silently skipped. The agent will warn about this, but always set the correct `CHAIN_TYPE` for chain-specific tests.

Omit `CHAIN_TYPE` for chain-agnostic tests.

## Database setup

If the agent reports `database "explorer_test" does not exist`, send these commands to the agent:

```
Run: mix ecto.create. CHAIN_TYPE=<type>
```
```
Run: mix ecto.migrate. CHAIN_TYPE=<type>
```

This is needed once per environment or after a database reset.
