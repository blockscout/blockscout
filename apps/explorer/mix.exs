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
      description: "Read-access to indexed block chain data.",
      dialyzer: [
        plt_add_deps: :transitive,
        plt_add_apps: ~w(ex_unit mix)a,
        ignore_warnings: "../../.dialyzer-ignore"
      ],
      elixir: "~> 1.13",
      elixirc_paths: elixirc_paths(Mix.env()),
      lockfile: "../../mix.lock",
      package: package(),
      preferred_cli_env: [
        credo: :test,
        dialyzer: :test
      ],
      start_permanent: Mix.env() == :prod,
      version: "5.0.0",
      xref: [exclude: [BlockScoutWeb.WebRouter.Helpers]]
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
      {:bamboo, "~> 2.3.0"},
      {:mime, "~> 2.0"},
      {:bcrypt_elixir, "~> 3.0"},
      # benchmark optimizations
      {:benchee, "~> 1.1.0", only: :test},
      # CSV output for benchee
      {:benchee_csv, "~> 1.0.0", only: :test},
      {:bypass, "~> 2.1", only: :test},
      {:briefly, "~> 0.4", github: "CargoSense/briefly"},
      {:comeonin, "~> 5.3"},
      {:credo, "~> 1.5", only: :test, runtime: false},
      # For Absinthe to load data in batches
      {:dataloader, "~> 1.0.0"},
      {:decimal, "~> 2.0"},
      {:dialyxir, "~> 1.1", only: [:dev, :test], runtime: false},
      # `override: true` for `ex_machina` compatibility
      {:ecto, "~> 3.3", override: true},
      # Storing blockchain data and derived data in PostgreSQL.
      {:ecto_sql, "~> 3.3"},
      # JSONRPC access to query smart contracts
      {:ethereum_jsonrpc, in_umbrella: true},
      # Data factory for testing
      {:ex_machina, "~> 2.3", only: [:test]},
      {:exvcr, "~> 0.10", only: :test},
      {:httpoison, "~> 1.6"},
      {:jason, "~> 1.3"},
      {:junit_formatter, ">= 0.0.0", only: [:test], runtime: false},
      # Log errors and application output to separate files
      {:logger_file_backend, "~> 0.0.10"},
      {:math, "~> 0.7.0"},
      {:mock, "~> 0.3.0", only: [:test], runtime: false},
      {:mox, "~> 1.0", only: [:test]},
      {:phoenix_html, "== 3.0.4"},
      {:poison, "~> 4.0.1"},
      {:nimble_csv, "~> 1.1"},
      {:postgrex, ">= 0.0.0"},
      # For compatibility with `prometheus_process_collector`, which hasn't been updated yet
      {:prometheus, "~> 4.0", override: true},
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
      {:telemetry, "~> 0.4.3"},
      # `Timex.Duration` for `Explorer.Counters.AverageBlockTime.average_block_time/0`
      {:timex, "~> 3.7.1"},
      {:con_cache, "~> 1.0"},
      {:tesla, "~> 1.5.0"},
      {:cbor, "~> 1.0"},
      {:cloak_ecto, "~> 1.2.0"},
      {:redix, "~> 1.1"}
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
