defmodule BlockScoutWeb.Mixfile do
  use Mix.Project

  def project do
    [
      aliases: aliases(),
      app: :block_scout_web,
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      compilers: [:phoenix, :gettext | Mix.compilers()],
      deps: deps(),
      deps_path: "../../deps",
      description: "Web interface for BlockScout.",
      dialyzer: [
        plt_add_deps: :transitive,
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
      mod: {BlockScoutWeb.Application, []},
      extra_applications: extra_applications()
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["test/support", "test/block_scout_web/features/pages"] ++ elixirc_paths()
  defp elixirc_paths(_), do: elixirc_paths()
  defp elixirc_paths, do: ["lib"]

  defp extra_applications,
    do: [
      :ex_cldr,
      :timex,
      :timex_ecto,
      :crontab,
      :logger,
      :runtime_tools
    ]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:bypass, "~> 0.8", only: :test},
      {:cowboy, "~> 1.0"},
      {:credo, "0.9.2", only: [:dev, :test], runtime: false},
      {:crontab, "~> 1.1"},
      {:dialyxir, "~> 0.5", only: [:dev, :test], runtime: false},
      {:ex_cldr_numbers, "~> 1.0"},
      {:ex_cldr_units, "~> 1.0"},
      {:ex_machina, "~> 2.1", only: [:test]},
      # Code coverage
      {:excoveralls, "~> 0.10.0", only: [:test], github: "KronicDeth/excoveralls", branch: "circle-workflows"},
      {:explorer, in_umbrella: true},
      {:exvcr, "~> 0.10", only: :test},
      # HTML CSS selectors for Phoenix controller tests
      {:floki, "~> 0.20.1", only: :test},
      {:flow, "~> 0.12"},
      {:gettext, "~> 0.14.1"},
      {:httpoison, "~> 1.0", override: true},
      {:junit_formatter, ">= 0.0.0", only: [:test], runtime: false},
      # Log errors and application output to separate files
      {:logger_file_backend, "~> 0.0.10"},
      {:math, "~> 0.3.0"},
      {:mock, "~> 0.3.0", only: [:test], runtime: false},
      {:phoenix, "~> 1.3.0"},
      {:phoenix_ecto, "~> 3.2"},
      {:phoenix_html, "~> 2.10"},
      {:phoenix_live_reload, "~> 1.0", only: [:dev]},
      {:phoenix_pubsub, "~> 1.0"},
      # Waiting for the Pretty Print to be implemented at the Jason lib
      # https://github.com/michalmuskala/jason/issues/15
      {:poison, "~> 3.1"},
      {:postgrex, ">= 0.0.0"},
      {:qrcode, "~> 0.1.0"},
      {:sobelow, ">= 0.7.0", only: [:dev, :test], runtime: false},
      {:timex, "~> 3.1.24"},
      {:timex_ecto, "~> 3.2.1"},
      {:wallaby, "~> 0.20", only: [:test], runtime: false},
      {:wobserver, "~> 0.1.8"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to create, migrate and run the seeds file at once:
  #
  #     $ mix ecto.setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      compile: "compile --warnings-as-errors",
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: [
        "ecto.create --quiet",
        "ecto.migrate",
        # to match behavior of `mix test` from project root, which needs to not start applications for `indexer` to
        # prevent its supervision tree from starting, which is undesirable in test
        "test --no-start"
      ]
    ]
  end

  defp package do
    [
      maintainers: ["POA Networks Ltd."],
      licenses: ["GPL 3.0"],
      links: %{"GitHub" => "https://github.com/poanetwork/blockscout"}
    ]
  end
end
