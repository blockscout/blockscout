# Explorer Market

## FiatValue.load and persistent_term

`Explorer.Chain.Token.FiatValue.load/1` returns `nil` for any value when `:market_token_fetcher_enabled` persistent_term is `false` (the default in test env). If your test needs to assert on loaded `fiat_value` / `circulating_market_cap` fields, add to setup:

```elixir
:persistent_term.put(:market_token_fetcher_enabled, true)

on_exit(fn ->
  :persistent_term.put(:market_token_fetcher_enabled, false)
end)
```