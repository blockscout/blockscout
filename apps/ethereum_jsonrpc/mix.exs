defmodule EthereumJSONRPC.MixProject do
  use Mix.Project

  def project do
    [
      aliases: aliases(Mix.env()),
      app: :ethereum_jsonrpc,
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps: deps(),
      deps_path: "../../deps",
      description: "Ethereum JSONRPC client.",
      dialyzer: [
        plt_add_deps: :app_tree,
        plt_add_apps: [:mix],
        ignore_warnings: "../../.dialyzer_ignore.exs"
      ],
      elixir: "~> 1.19",
      elixirc_paths: elixirc_paths(Mix.env()),
      lockfile: "../../mix.lock",
      start_permanent: Mix.env() == :prod,
      version: "10.0.0"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {EthereumJSONRPC.Application, []},
      extra_applications: [:logger, :tesla]
    ]
  end

  def cli do
    [preferred_envs: [credo: :test, dialyzer: :test]]
  end

  defp aliases(env) do
    [
      # to match behavior of `mix test` from project root, which needs to not start applications for `indexer` to
      # prevent its supervision tree from starting, which is undesirable in test
      test: "test --no-start"
    ] ++ env_aliases(env)
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["test/support" | elixirc_paths(:dev)]
  defp elixirc_paths(_), do: ["lib"]

  defp env_aliases(:dev), do: []

  defp env_aliases(_env), do: [compile: "compile --warnings-as-errors"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # CACerts bundle for `EthereumJSONRPC.WebSocket.WebSocketClient`
      {:certifi, "~> 2.3"},
      # WebSocket-server for testing `EthereumJSONRPC.WebSocket.WebSocketClient`.
      {:cowboy, "~> 2.0", only: [:dev, :test]},
      # Static Type Checking
      {:dialyxir, "~> 1.1", only: [:dev, :test], runtime: false},
      {:ex_keccak, "~> 0.7.5"},
      # JSONRPC HTTP Post calls
      {:httpoison, "~> 2.0"},
      # Decode/Encode JSON for JSONRPC
      {:jason, "~> 1.3"},
      # Log errors and application output to separate files
      {:logger_file_backend, "~> 0.0.10"},
      {:logger_json, "~> 7.0"},
      # Mocking `EthereumJSONRPC.Transport` and `EthereumJSONRPC.HTTP` so we avoid hitting real chains for local testing
      {:mox, "~> 1.1.0", only: [:test]},
      {:prometheus_ex, "~> 5.0.0", override: true},
      # Tracing
      {:spandex, "~> 3.0"},
      # `:spandex` integration with Datadog
      {:spandex_datadog, "~> 1.0"},
      {:tesla, "~> 1.16.0"},
      # Convert unix timestamps in JSONRPC to DateTimes
      {:timex, "~> 3.7.1"},
      # Encode/decode function names and arguments
      {:ex_abi, "~> 0.8"},
      # `:verify_fun` for `Socket.Web.connect`
      {:ssl_verify_fun, "~> 1.1"},
      # `EthereumJSONRPC.WebSocket`
      {:decimal, "~> 2.0"},
      {:decorator, "~> 1.4"},
      {:hackney, "~> 1.18"},
      {:poolboy, "~> 1.5.2"},
      {:utils, in_umbrella: true},
      {:websockex, "~> 0.5.0"}
    ]
  end
end
