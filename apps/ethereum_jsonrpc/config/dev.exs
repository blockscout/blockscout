import Config

config :ethereum_jsonrpc, EthereumJSONRPC.Tracer, env: "dev", disabled?: true

config :logger, :ethereum_jsonrpc,
  level: :debug,
  path: Path.absname("logs/dev/ethereum_jsonrpc.log")
