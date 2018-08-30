use Mix.Config

config :logger, :ethereum_jsonrpc,
  level: :warn,
  path: Path.absname("logs/test/ethereum_jsonrpc.log")
