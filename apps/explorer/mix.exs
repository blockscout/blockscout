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
      elixir: "~> 1.6",
      elixirc_paths: elixirc_paths(Mix.env()),
      lockfile: "../../mix.lock",
      package: package(),
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        dialyzer: :test
      ],
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      version: "0.0.1"
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
      :crontab,
      :logger,
      :mix,
      :runtime_tools,
      :timex,
      :timex_ecto
    ]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:bcrypt_elixir, "~> 1.0"},
      # benchmark optimizations
      {:benchee, "~> 0.13.1", only: :test},
      # CSV output for benchee
      {:benchee_csv, "~> 0.8.0", only: :test},
      {:bypass, "~> 0.8", only: :test},
      {:comeonin, "~> 4.0"},
      {:credo, "0.9.2", only: [:dev, :test], runtime: false},
      {:crontab, "~> 1.1"},
      {:decimal, "~> 1.0"},
      {:dialyxir, "~> 0.5", only: [:dev, :test], runtime: false},
      # Casting Ethereum-native types to Elixir-native types
      {:ecto, "~> 2.2"},
      # JSONRPC access to query smart contracts
      {:ethereum_jsonrpc, in_umbrella: true},
      # Data factory for testing
      {:ex_machina, "~> 2.1", only: [:test]},
      # Code coverage
      {:excoveralls, "~> 0.10.0", only: [:test], github: "KronicDeth/excoveralls", branch: "circle-workflows"},
      {:exvcr, "~> 0.10", only: :test},
      {:httpoison, "~> 1.0", override: true},
      {:jason, "~> 1.0"},
      {:junit_formatter, ">= 0.0.0", only: [:test], runtime: false},
      # Log errors and application output to separate files
      {:logger_file_backend, "~> 0.0.10"},
      {:math, "~> 0.3.0"},
      {:mock, "~> 0.3.0", only: [:test], runtime: false},
      {:mox, "~> 0.4", only: [:test]},
      {:postgrex, ">= 0.0.0"},
      {:sobelow, ">= 0.7.0", only: [:dev, :test], runtime: false},
      {:timex, "~> 3.1.24"},
      {:timex_ecto, "~> 3.2.1"}
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
      maintainers: ["POA Networks Ltd."],
      licenses: ["GPL 3.0"],
      links: %{"GitHub" => "https://github.com/poanetwork/blockscout"}
    ]
  end
end
