defmodule EthereumJsonrpc.MixProject do
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
        plt_add_deps: :transitive,
        plt_add_apps: [:mix],
        ignore_warnings: "../../.dialyzer-ignore"
      ],
      elixir: "~> 1.13",
      elixirc_paths: elixirc_paths(Mix.env()),
      lockfile: "../../mix.lock",
      preferred_cli_env: [
        credo: :test,
        dialyzer: :test
      ],
      start_permanent: Mix.env() == :prod,
      version: "5.1.1"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {EthereumJSONRPC.Application, []},
      extra_applications: [:logger]
    ]
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
      # Style Checking
      {:credo, "~> 1.5", only: :test, runtime: false},
      # Static Type Checking
      {:dialyxir, "~> 1.1", only: [:dev, :test], runtime: false},
      # JSONRPC HTTP Post calls
      {:httpoison, "~> 1.6"},
      # Decode/Encode JSON for JSONRPC
      {:jason, "~> 1.3"},
      # Log errors and application output to separate files
      {:logger_file_backend, "~> 0.0.10"},
      # Mocking `EthereumJSONRPC.Transport` and `EthereumJSONRPC.HTTP` so we avoid hitting real chains for local testing
      {:mox, "~> 1.0", only: [:test]},
      # Tracing
      {:spandex, "~> 3.0"},
      # `:spandex` integration with Datadog
      {:spandex_datadog, "~> 1.0"},
      # Convert unix timestamps in JSONRPC to DateTimes
      {:timex, "~> 3.7.1"},
      # Encode/decode function names and arguments
      {:ex_abi, "~> 0.4"},
      # `:verify_fun` for `Socket.Web.connect`
      {:ssl_verify_fun, "~> 1.1"},
      # `EthereumJSONRPC.WebSocket`
      {:websocket_client, git: "https://github.com/blockscout/websocket_client.git", branch: "master", override: true},
      {:decimal, "~> 2.0"},
      {:decorator, "~> 1.4"},
      {:hackney, "~> 1.18"},
      {:poolboy, "~> 1.5.2"}
    ]
  end
end
