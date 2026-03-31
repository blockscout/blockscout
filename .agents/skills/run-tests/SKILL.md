---
name: run-tests
description: "Use this skill whenever you need to run Elixir/Mix tests for the Blockscout project. This includes: running a specific test file, running all tests for an app, running tests after writing or modifying code, or verifying test results. Trigger on any mention of 'mix test', 'run tests', 'run the tests', 'test this', 'verify tests pass', or when you've just written code and need to confirm it works."
---

# Running Blockscout tests

This skill covers the Blockscout-specific configuration needed to run `mix test` successfully. The commands below show raw `mix` invocations — run them in whatever environment has Elixir available (host, devcontainer, CI, etc.).

## Umbrella structure and chromedriver

Blockscout is an Elixir umbrella project with these apps: `block_scout_web`, `explorer`, `indexer`, `ethereum_jsonrpc`, and others.

**Important:** The `block_scout_web` app's `test_helper.exs` unconditionally starts Wallaby (a browser testing library), which requires `chromedriver` and `chromium`. If chromedriver is not installed, **all** `block_scout_web` tests crash at startup — including non-browser tests like controller tests. The devcontainer installs chromedriver automatically via `postCreateCommand`.

Other apps (`explorer`, `indexer`, `ethereum_jsonrpc`) do **not** require chromedriver. To avoid the Wallaby dependency, run their tests **from within the app directory** rather than from the umbrella root:

```
cd apps/explorer && TEST_DATABASE_URL="..." mix test test/explorer/chain_test.exs
```

Running `mix test` from the umbrella root triggers all apps' test helpers, including `block_scout_web`'s, so chromedriver is needed in that case.

## Quick reference

**`block_scout_web` tests** (requires chromedriver — use devcontainer):
```
TEST_DATABASE_URL="postgresql://postgres:postgres@localhost:5432/explorer_test" \
  CHAIN_TYPE=<type> \
  mix test apps/block_scout_web/test/<path_to_test_file> --no-start
```

**Other app tests** (no chromedriver needed — can run from app dir):
```
cd apps/explorer && \
  TEST_DATABASE_URL="postgresql://postgres:postgres@localhost:5432/explorer_test" \
  CHAIN_TYPE=<type> \
  mix test test/<path_to_test_file>
```

## Environment variables

### `TEST_DATABASE_URL`

The test config (`apps/explorer/config/test.exs`) falls back to connecting as the current OS user with no password when `TEST_DATABASE_URL` is not set. This only works if the OS user matches a postgres role. In most development setups (devcontainer, Docker, CI) it doesn't — the postgres instance is configured with user `postgres` / password `postgres`.

Always set it:
```
TEST_DATABASE_URL="postgresql://postgres:postgres@localhost:5432/explorer_test"
```

### `CHAIN_TYPE`

Chain-specific code compiles conditionally based on `CHAIN_TYPE`. Tests for chain-specific controllers (arbitrum, scroll, optimism, etc.) are gated with compile-time checks like `if @chain_type == :arbitrum` — they are **silently skipped** if the chain type doesn't match. This means you'll see `0 tests, 0 failures` with no error, which can be misleading.

Set it to match the tests you're running:
```
CHAIN_TYPE=arbitrum    # for Arbitrum-specific tests
CHAIN_TYPE=scroll      # for Scroll-specific tests
CHAIN_TYPE=optimism    # for Optimism-specific tests
```

Omit `CHAIN_TYPE` for chain-agnostic tests.

## The `--no-start` flag

The `block_scout_web` app uses `--no-start` in its test alias to prevent the indexer's supervision tree from starting during tests. The `test_helper.exs` then selectively starts only the required applications (including Wallaby). Pass `--no-start` when running `block_scout_web` tests from the umbrella root.

Note: `--no-start` does **not** prevent Wallaby from starting — `test_helper.exs` calls `Application.ensure_all_started(:wallaby)` unconditionally, overriding the flag. Chromedriver must be installed for `block_scout_web` tests regardless.

## Database setup

If you see an error like `database "explorer_test" does not exist`, create and migrate the test database:

```
TEST_DATABASE_URL="postgresql://postgres:postgres@localhost:5432/explorer_test" \
  CHAIN_TYPE=<type> MIX_ENV=test mix ecto.create

TEST_DATABASE_URL="postgresql://postgres:postgres@localhost:5432/explorer_test" \
  CHAIN_TYPE=<type> MIX_ENV=test mix ecto.migrate
```

This is needed once per environment (or after a database reset). `ecto.create` is idempotent — it reports "already created" harmlessly if the database exists.

## Examples

**`block_scout_web` test file (chain-specific, from umbrella root):**
```
TEST_DATABASE_URL="postgresql://postgres:postgres@localhost:5432/explorer_test" \
  CHAIN_TYPE=arbitrum \
  mix test apps/block_scout_web/test/block_scout_web/controllers/api/v2/arbitrum_controller_test.exs --no-start
```

**Single test by line number:**
```
TEST_DATABASE_URL="postgresql://postgres:postgres@localhost:5432/explorer_test" \
  CHAIN_TYPE=arbitrum \
  mix test apps/block_scout_web/test/block_scout_web/controllers/api/v2/arbitrum_controller_test.exs:10 --no-start
```

**Explorer test (from app directory, no chromedriver needed):**
```
cd apps/explorer && \
  TEST_DATABASE_URL="postgresql://postgres:postgres@localhost:5432/explorer_test" \
  mix test test/explorer/chain_test.exs
```

**All tests in explorer app:**
```
cd apps/explorer && \
  TEST_DATABASE_URL="postgresql://postgres:postgres@localhost:5432/explorer_test" \
  mix test test/
```

## Timeouts

Tests can take a while, especially on first run when compilation is needed. Use `timeout: 300000` (5 minutes) on the Bash tool call. For large test suites, consider `run_in_background: true`.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `role "<user>" does not exist` | `TEST_DATABASE_URL` not set or wrong credentials | Set the env var as shown above |
| `Wallaby can't find chromedriver` | chromedriver not installed (only affects `block_scout_web`) | Use devcontainer (installs it automatically), or run non-`block_scout_web` tests from their app directory |
| Tests compile but 0 tests run | `CHAIN_TYPE` doesn't match the test's compile-time guard | Set the correct `CHAIN_TYPE` |
| `database "explorer_test" does not exist` | Test DB not created yet | Run `ecto.create` then `ecto.migrate` |
