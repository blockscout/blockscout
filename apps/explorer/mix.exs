defmodule Explorer.Mixfile do
  use Mix.Project

  def project do
    [
      aliases: aliases(Mix.env()),
      app: :explorer,
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps: deps(),
      deps_path: "../../deps",
      description: "Read-access to indexed blockchain data.",
      dialyzer: [
        plt_add_deps: :app_tree,
        plt_add_apps: ~w(ex_unit mix)a,
        ignore_warnings: "../../.dialyzer_ignore.exs"
      ],
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      lockfile: "../../mix.lock",
      package: package(),
      preferred_cli_env: [
        credo: :test,
        dialyzer: :test
      ],
      start_permanent: Mix.env() == :prod,
      version: "9.0.0",
      xref: [exclude: [BlockScoutWeb.Routers.WebRouter.Helpers, Indexer.Helper, Indexer.Fetcher.InternalTransaction]]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Explorer.Application, []},
      extra_applications: extra_applications()
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["test/support" | elixirc_paths()]
  defp elixirc_paths(_), do: elixirc_paths()
  defp elixirc_paths, do: ["lib"]

  defp extra_applications,
    do: [
      :logger,
      :mix,
      :runtime_tools,
      :tesla
    ]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:bamboo, "~> 2.4.0"},
      {:mime, "~> 2.0"},
      {:bcrypt_elixir, "~> 3.0"},
      # benchmark optimizations
      {:benchee, "~> 1.4.0", only: :test},
      # CSV output for benchee
      {:benchee_csv, "~> 1.0.0", only: :test},
      {:bypass, "~> 2.1", only: :test},
      {:briefly, "~> 0.4", github: "CargoSense/briefly"},
      {:comeonin, "~> 5.3"},
      # For Absinthe to load data in batches
      {:dataloader, "~> 2.0.0"},
      {:decimal, "~> 2.0"},
      {:dialyxir, "~> 1.1", only: [:dev, :test], runtime: false},
      # `override: true` for `ex_machina` compatibility
      {:ecto, "~> 3.3", override: true},
      # Storing blockchain data and derived data in PostgreSQL.
      {:ecto_sql, "~> 3.3"},
      # JSONRPC access to query smart contracts
      {:ethereum_jsonrpc, in_umbrella: true},
      {:ex_keccak, "~> 0.7.5"},
      # Data factory for testing
      {:ex_machina, "~> 2.3", only: [:test]},
      # ZSTD compression/decompression
      {:ezstd, "~> 1.2"},
      {:exvcr, "~> 0.10", only: :test},
      {:httpoison, "~> 2.0"},
      {:jason, "~> 1.3"},
      {:junit_formatter, ">= 0.0.0", only: [:test], runtime: false},
      # Log errors and application output to separate files
      {:logger_file_backend, "~> 0.0.10"},
      {:math, "~> 0.7.0"},
      {:mock, "~> 0.3.0", only: [:test], runtime: false},
      {:mox, "~> 1.1.0"},
      {:phoenix_html, "== 3.3.4"},
      {:poison, "~> 4.0.1"},
      {:nimble_csv, "~> 1.1"},
      {:postgrex, ">= 0.0.0"},
      # For compatibility with `prometheus_process_collector`, which hasn't been updated yet
      {:prometheus, "~> 5.1", override: true},
      # Prometheus metrics for query duration
      {:prometheus_ecto, "~> 1.4.3"},
      {:prometheus_ex, git: "https://github.com/lanodan/prometheus.ex", branch: "fix/elixir-1.14", override: true},
      # bypass optional dependency
      {:plug_cowboy, "~> 2.2", only: [:dev, :test]},
      {:que, "~> 0.10.1"},
      {:sobelow, ">= 0.7.0", only: [:dev, :test], runtime: false},
      # Tracing
      {:spandex, "~> 3.0"},
      # `:spandex` integration with Datadog
      {:spandex_datadog, "~> 1.0"},
      # `:spandex` tracing of `:ecto`
      {:spandex_ecto, "~> 0.7.0"},
      # Attach `:prometheus_ecto` to `:ecto`
      {:telemetry, "~> 1.3.0"},
      # `Timex.Duration` for `Explorer.Chain.Cache.Counters.AverageBlockTime.average_block_time/0`
      {:timex, "~> 3.7.1"},
      {:con_cache, "~> 1.0"},
      {:tesla, "~> 1.14.2"},
      {:cbor, "~> 1.0"},
      {:cloak_ecto, "~> 1.3.0"},
      {:redix, "~> 1.1"},
      {:hammer_backend_redis, "~> 7.0"},
      {:logger_json, "~> 5.1"},
      {:typed_ecto_schema, "~> 0.4.1"},
      {:ueberauth, "~> 0.7"},
      {:recon, "~> 2.5"},
      {:varint, "~> 1.4"},
      {:blake2, "~> 1.0"},
      {:ueberauth_auth0, "~> 2.0"},
      {:oauth2, "~> 2.0"},
      {:siwe, github: "royal-markets/siwe-ex", ref: "51c9c08240eb7eea3c35693011f8d260cd9bb3be"},
      {:joken, "~> 2.6"},
      {:utils, in_umbrella: true},
      {:dns, "~> 2.4.0"},
      {:inet_cidr, "~> 1.0.0"},
      {:hammer, "~> 7.0"},
      {:ton, "~> 0.5.0"},
      {:mint, "~> 1.0"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to create, migrate and run the seeds file at once:
  #
  #     $ mix ecto.setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases(env) do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate", "test --no-start"]
    ] ++ env_aliases(env)
  end

  defp env_aliases(:dev), do: []

  defp env_aliases(_env) do
    [compile: "compile --warnings-as-errors"]
  end

  defp package do
    [
      maintainers: ["Blockscout"],
      licenses: ["GPL 3.0"],
      links: %{"GitHub" => "https://github.com/blockscout/blockscout"}
    ]
  end
end
