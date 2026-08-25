## Contributing essentials

A curated subset of `.github/CONTRIBUTING.md`, kept small on purpose. Only the
parts that actually change how a plan is written, how a change is reviewed, or
how a phase gets committed are here. Deliberately **not** curated — read
`.github/CONTRIBUTING.md` directly if one of these is genuinely needed: which
contribution types are accepted, the fork/branch/push flow, PR title/label
formatting, incompatible-change callouts in a PR description,
`.dialyzer-ignore` hygiene, and the regression-test-first/fix-second commit
ordering for bug fixes (it doesn't compose with this repo's phase-based plan
workflow, where a phase — tests included — is already the atomic, reviewable
commit unit; don't try to split a phase's commit to honor it).

### Naming conventions

- Prefer full words over abbreviations: `transaction` not `tx`/`txn`,
  `transactions` not `txs`, `transaction_hash` not `tx_hash`/`txn_hash`,
  `address_hash` not `address`, `block_number` not `block_num`.
- Variable and field names should describe their content, not just echo their
  type.

API v2 response fields, additionally:

- Block numbers are numbers, in a property ending `block_number`.
- Hashes (transaction, block, address, etc.) are hex strings, in a property
  ending `_hash`.
- Aggregations use the plural entity name plus `_count`/`_sum`
  (`transactions_count`, `blocks_count`, `withdrawals_sum`).
- Any field ending `index` is a number.

### Runtime vs. compile-time configuration

Runtime configuration is preferred over compile-time for new configuration
options and chain types. Decision order:

1. Feature-specific behavior of a function → `Utils.RuntimeEnvHelper` or
   `Application.get_env/3` plus pattern matching.
2. Needs new database tables → a new `Ecto.Repo`, wired in conditionally at
   runtime in `config_helper.exs`.
3. Is an API endpoint → the `chain_scope` router macro, or the `CheckFeature`
   plug.
4. Modifies an *existing* database schema (new column/constraint on a shared
   table) → compile-time configuration (`Utils.CompileTimeEnvHelper`) is still
   the only supported approach, since Ecto schemas are fixed at compile time.
   This is the one case where compile-time configuration is expected, not an
   anti-pattern.
5. None of the above → a genuinely new case; flag it for discussion rather
   than guessing.

See `.github/CONTRIBUTING.md`'s "Environment Configuration Best Practices"
section for the full decision tree and code examples.
