# Explorer Market

## FiatValue.load and persistent_term

`Explorer.Chain.Token.FiatValue.load/1` returns `nil` for any value when `:market_token_fetcher_enabled` persistent_term is `false` (the default in test env). If your test needs to assert on loaded `fiat_value` / `circulating_market_cap` fields, add to setup:

```elixir
:persistent_term.put(:market_token_fetcher_enabled, true)

on_exit(fn ->
  :persistent_term.put(:market_token_fetcher_enabled, false)
end)
```

## Market source request metric

All market source requests go through `Explorer.Market.Source.http_request/4`, which increments the
`market_source_requests_count` counter (`Explorer.Prometheus.Instrumenter`, exposed on `/metrics`)
with the `source`, `endpoint` and `status` labels.

When adding a request to a market source, pass `__MODULE__` and a new endpoint atom:

```elixir
Source.http_request(url, headers(), __MODULE__, :coins_details)
```

The endpoint atom is the *endpoint type*, not the URL: requests differing only in variable parts
(token address hash, coin id, pagination offset, date range) must share one atom, so that e.g. all
per-token DIA calls land in a single `asset_quotation_token` series. Conversely, when one path serves
two purposes, use two atoms (`coins_market_chart_price` vs `coins_market_chart_market_cap`) so the
driving fetcher is distinguishable. Never interpolate a variable into the atom — that would blow up
the metric cardinality.