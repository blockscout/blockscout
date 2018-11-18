use Mix.Config

config :logger, :indexer,
  level: :info,
  path: Path.absname("logs/prod/indexer.log"),
  rotate: %{max_bytes: 52_428_800, keep: 19}

config :logger, :indexer_token_balances,
  level: :debug,
  path: Path.absname("logs/prod/indexer/token_balances/error.log"),
  metadata_filter: [fetcher: :token_balances],
  rotate: %{max_bytes: 52_428_800, keep: 19}

variant =
  if is_nil(System.get_env("ETHEREUM_JSONRPC_VARIANT")) do
    "geth"
  else
    System.get_env("ETHEREUM_JSONRPC_VARIANT")
    |> String.split(".")
    |> List.last()
    |> String.downcase()
  end

# Import variant specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "prod/#{variant}.exs"
