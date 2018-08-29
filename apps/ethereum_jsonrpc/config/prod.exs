use Mix.Config

config :logger, :ethereum_jsonrpc,
  level: :info,
  path: Path.absname("logs/prod/ethereum_jsonrpc.log")
