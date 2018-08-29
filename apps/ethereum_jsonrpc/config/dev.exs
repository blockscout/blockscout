use Mix.Config

config :logger, :ethereum_jsonrpc,
  level: :debug,
  path: Path.absname("logs/dev/ethereum_jsonrpc.log")
