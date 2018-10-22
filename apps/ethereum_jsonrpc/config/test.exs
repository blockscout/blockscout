use Mix.Config

config :logger, :ethereum_jsonrpc,
  level: :warn,
  path: Path.absname("logs/test/ethereum_jsonrpc.log")

config :ethereum_jsonrpc, EthereumJSONRPC.RequestCoordinator,
  rolling_window_opts: [
    window_count: 3,
    window_length: :timer.seconds(5),
    table: EthereumJSONRPC.RequestCoordinator.TimeoutCounter
  ],
  wait_per_timeout: 1
