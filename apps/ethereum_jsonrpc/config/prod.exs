use Mix.Config

config :logger, :ethereum_jsonrpc,
  level: :info,
  path: Path.absname("logs/prod/ethereum_jsonrpc.log"),
  rotate: %{max_bytes: 52_428_800, keep: 19}
