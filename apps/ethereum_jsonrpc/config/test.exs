import Config

config :ethereum_jsonrpc, EthereumJSONRPC.RequestCoordinator,
  rolling_window_opts: [
    window_count: 3,
    duration: :timer.seconds(6),
    table: EthereumJSONRPC.RequestCoordinator.TimeoutCounter
  ],
  max_jitter: 1,
  # This should not actually limit anything in tests, but it is here to enable the relevant code for testing
  throttle_rate_limit: 10_000,
  throttle_rolling_window_opts: [
    window_count: 4,
    duration: :timer.seconds(1),
    table: EthereumJSONRPC.RequestCoordinator.ThrottleCounter
  ]

config :ethereum_jsonrpc, EthereumJSONRPC.Tracer, disabled?: false

config :tesla, adapter: Explorer.Mock.TeslaAdapter

config :logger, :ethereum_jsonrpc,
  level: :warn,
  path: Path.absname("logs/test/ethereum_jsonrpc.log")
