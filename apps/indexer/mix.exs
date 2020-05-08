defmodule Indexer.MixProject do
  use Mix.Project

  def project do
    [
      aliases: aliases(),
      app: :indexer,
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps: deps(),
      deps_path: "../../deps",
      description: "Fetches block chain data from on-chain node for later reading with Explorer.",
      elixir: "~> 1.10",
      elixirc_paths: elixirc_paths(Mix.env()),
      lockfile: "../../mix.lock",
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      version: "0.1.0"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Indexer.Application, []}
    ]
  end

  defp aliases do
    [
      # so that the supervision tree does not start, which would begin indexing, and so that the various fetchers can
      # be started with `ExUnit`'s `start_supervised` for unit testing.
      test: "test --no-start"
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Optional dependency of `:spandex` for `Spandex.Decorators`
      {:decorator, "~> 1.2"},
      # JSONRPC access to Parity for `Explorer.Indexer`
      {:ethereum_jsonrpc, in_umbrella: true},
      # RLP encoding
      {:ex_rlp, "~> 0.5.2"},
      # Code coverage
      {:excoveralls, "~> 0.10.0", only: [:test], github: "KronicDeth/excoveralls", branch: "circle-workflows"},
      # Importing to database
      {:explorer, in_umbrella: true},
      # libsecp2561k1 crypto functions
      {:libsecp256k1, "~> 0.1.10"},
      # Log errors and application output to separate files
      {:logger_file_backend, "~> 0.0.10"},
      # Mocking `EthereumJSONRPC.Transport`, so we avoid hitting real chains for local testing
      {:mox, "~> 0.4", only: [:test]},
      # Tracing
      {:spandex, github: "spandex-project/spandex", branch: "allow-setting-trace-key", override: true},
      # `:spandex` integration with Datadog
      {:spandex_datadog, "~> 0.4.0"}
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["test/support" | elixirc_paths(:dev)]
  defp elixirc_paths(_), do: ["lib"]
end
