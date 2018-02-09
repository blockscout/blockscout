defmodule Explorer.Mixfile do
  use Mix.Project

  def project do
    [
      app: :explorer,
      version: "0.0.1",
      elixir: "~> 1.4",
      elixirc_paths: elixirc_paths(Mix.env),
      compilers: [:phoenix, :gettext | Mix.compilers],
      start_permanent: Mix.env == :prod,
      aliases: aliases(),
      deps: deps(),
      dialyzer: [
        plt_add_deps: :transitive,
        plt_add_apps: [:mix],
        ignore_warnings: ".dialyzer-ignore"
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Explorer.Application, []},
      extra_applications: extra_applications(Mix.env)
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["test/support" | elixirc_paths()]
  defp elixirc_paths(_),     do: elixirc_paths()
  defp elixirc_paths,        do: ["lib"]

  # Specifies extra applications to start per environment
  defp extra_applications(:prod), do: [:phoenix_pubsub_redis, :exq, :exq_ui | extra_applications()]
  defp extra_applications(:dev), do: [:exq, :exq_ui | extra_applications()]
  defp extra_applications(_), do: extra_applications()
  defp extra_applications, do: [
    :scrivener_ecto, :scrivener_html, :ex_cldr, :ex_jasmine, :ethereumex,
    :timex, :timex_ecto, :crontab, :set_locale, :logger, :runtime_tools,
    :new_relixir
  ]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:cowboy, "~> 1.0"},
      {:credo, "~> 0.8", only: [:dev, :test], runtime: false},
      {:crontab, "~> 1.1"},
      {:dialyxir, "~> 0.5", only: [:dev, :test], runtime: false},
      {:ethereumex, "~> 0.3"},
      {:ex_cldr_numbers, "~> 1.0"},
      {:ex_cldr_units, "~> 1.0"},
      {:ex_jasmine, github: "minifast/ex_jasmine", branch: "master"},
      {:ex_machina, "~> 2.1", only: [:test]},
      {:exq, "~> 0.9.1"},
      {:exq_ui, "~> 0.9.0"},
      {:exvcr, "~> 0.10", only: :test},
      {:flow, "~> 0.12"},
      {:gettext, "~> 0.11"},
      {:httpoison, "~> 1.0", override: true},
      {:junit_formatter, ">= 0.0.0", only: [:test], runtime: false},
      {:math, "~> 0.3.0"},
      {:mock, "~> 0.3.0", only: [:test], runtime: false},
      {:new_relixir, "~> 0.4"},
      {:phoenix, "~> 1.3.0"},
      {:phoenix_ecto, "~> 3.2"},
      {:phoenix_html, "~> 2.10"},
      {:phoenix_live_reload, "~> 1.0", only: [:dev]},
      {:phoenix_pubsub, "~> 1.0"},
      {:phoenix_pubsub_redis, "~> 2.1.0", only: [:prod]},
      {:postgrex, ">= 0.0.0"},
      {:quantum, "~> 2.2.1"},
      {:react_phoenix, "~> 0.5"},
      {:scrivener_ecto, "~> 1.0"},
      {:scrivener_html, "~> 1.7"},
      {:set_locale, github: "minifast/set_locale", branch: "master"}, # Waiting on https://github.com/smeevil/set_locale/pull/9
      {:sobelow, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:timex, "~> 3.1.24"},
      {:timex_ecto, "~> 3.2.1"},
      {:wallaby, "~> 0.19.2", only: [:test], runtime: false},
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
      "test": ["ecto.create --quiet", "ecto.migrate", "test"]
    ]
  end
end
