defmodule Explorer.Mixfile do
  use Mix.Project

  def project do
    [
      aliases: aliases(),
      app: :explorer,
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps: deps(),
      deps_path: "../../deps",
      dialyzer: [
        plt_add_deps: :transitive,
        plt_add_apps: [:mix],
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
        "coveralls.html": :test
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
      extra_applications: extra_applications(Mix.env())
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["test/support" | elixirc_paths()]
  defp elixirc_paths(_), do: elixirc_paths()
  defp elixirc_paths, do: ["lib"]

  # Specifies extra applications to start per environment
  defp extra_applications(:prod),
    do: [:phoenix_pubsub_redis, :exq, :exq_ui | extra_applications()]

  defp extra_applications(:dev), do: [:exq, :exq_ui | extra_applications()]
  defp extra_applications(_), do: extra_applications()

  defp extra_applications,
    do: [
      :crontab,
      :ethereumex,
      :logger,
      :mix,
      :new_relixir,
      :runtime_tools,
      :scrivener_ecto,
      :timex,
      :timex_ecto
    ]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:credo, "~> 0.8", only: [:dev, :test], runtime: false},
      {:crontab, "~> 1.1"},
      {:dialyxir, "~> 0.5", only: [:dev, :test], runtime: false},
      {:ethereumex, "~> 0.3"},
      {:ex_machina, "~> 2.1", only: [:test]},
      # Code coverage
      {:excoveralls, "~> 0.8.1", only: [:test]},
      {:exq, "~> 0.9.1"},
      {:exq_ui, "~> 0.9.0"},
      {:exvcr, "~> 0.10", only: :test},
      {:flow, "~> 0.12"},
      {:httpoison, "~> 1.0", override: true},
      {:junit_formatter, ">= 0.0.0", only: [:test], runtime: false},
      {:math, "~> 0.3.0"},
      {:mock, "~> 0.3.0", only: [:test], runtime: false},
      {:new_relixir, "~> 0.4"},
      {:postgrex, ">= 0.0.0"},
      {:quantum, "~> 2.2.1"},
      {:scrivener_ecto, "~> 1.0"},
      {:scrivener_html, "~> 1.7"},
      {:sobelow, ">= 0.0.0", only: [:dev, :test], runtime: false},
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
  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate", "test"]
    ]
  end

  defp package do
    [
      maintainers: ["POA Networks Ltd."],
      licenses: ["GPL 3.0"],
      links: %{"GitHub" => "https://github.com/poanetwork/poa-explorer"}
    ]
  end
end
