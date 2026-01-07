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
      description: "Fetches blockchain data from on-chain node for later reading with Explorer.",
      elixir: "~> 1.19",
      elixirc_paths: elixirc_paths(Mix.env()),
      lockfile: "../../mix.lock",
      start_permanent: Mix.env() == :prod,
      version: "9.3.5",
      xref: [
        exclude: [
          Explorer.Chain.Optimism.Deposit,
          Explorer.Chain.Optimism.FrameSequence,
          Explorer.Chain.Optimism.OutputRoot,
          Explorer.Chain.Optimism.TransactionBatch,
          Explorer.Chain.Optimism.Withdrawal,
          Explorer.Chain.Optimism.WithdrawalEvent
        ]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :os_mon],
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
      {:decorator, "~> 1.4"},
      # JSONRPC access to Nethermind for `Explorer.Indexer`
      {:ethereum_jsonrpc, in_umbrella: true},
      {:ex_eth_bls, "~> 0.1.0"},
      # Brotli compression/decompression
      {:ex_brotli, "~> 0.5.0"},
      {:ex_keccak, "~> 0.7.5"},
      # RLP encoding
      {:ex_rlp, "~> 0.6.0"},
      # Importing to database
      {:explorer, in_umbrella: true},
      # ex_secp256k1 crypto functions
      {:ex_secp256k1, "~> 0.7.0"},
      # Log errors and application output to separate files
      {:logger_file_backend, "~> 0.0.10"},
      {:logger_json, "~> 7.0"},
      # Mocking `EthereumJSONRPC.Transport`, so we avoid hitting real chains for local testing
      {:mox, "~> 1.1.0"},
      {:prometheus_ex, "~> 5.0.0", override: true},
      # Tracing
      {:spandex, "~> 3.0"},
      # `:spandex` integration with Datadog
      {:spandex_datadog, "~> 1.0"},
      {:varint, "~> 1.4"},
      {:utils, in_umbrella: true},
      {:cachex, "~> 4.0"}
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["test/support" | elixirc_paths(:dev)]
  defp elixirc_paths(_), do: ["lib"]
end
