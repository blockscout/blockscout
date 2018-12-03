use Mix.Config

config :ethereum_jsonrpc, EthereumJSONRPC.RequestCoordinator,
  rolling_window_opts: [
    window_count: 3,
    duration: :timer.seconds(6),
    table: EthereumJSONRPC.RequestCoordinator.TimeoutCounter
  ],
  wait_per_timeout: 2,
  max_jitter: 1

config :ethereum_jsonrpc, EthereumJSONRPC.Tracer, disabled?: false

config :logger, :ethereum_jsonrpc,
  level: :warn,
  path: Path.absname("logs/test/ethereum_jsonrpc.log")
