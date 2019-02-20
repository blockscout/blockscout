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
        credo: :test,
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
      :logger,
      :runtime_tools
    ]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      # GraphQL toolkit
      {:absinthe, "~> 1.4"},
      # Integrates Absinthe subscriptions with Phoenix
      {:absinthe_phoenix, "~> 1.4"},
      # Plug support for Absinthe
      {:absinthe_plug, "~> 1.4"},
      # Absinthe support for the Relay framework
      {:absinthe_relay, "~> 1.4"},
      {:bypass, "~> 1.0", only: :test},
      # To add (CORS)(https://www.w3.org/TR/cors/)
      {:cors_plug, "~> 2.0"},
      {:credo, "1.0.0", only: :test, runtime: false},
      # For Absinthe to load data in batches
      {:dataloader, "~> 1.0.0"},
      {:dialyxir, "~> 0.5", only: [:dev, :test], runtime: false},
      # Need until https://github.com/absinthe-graphql/absinthe_relay/pull/125 is released, then can be removed
      # The current `absinthe_relay` is compatible though as shown from that PR
      {:ecto, "~> 3.0", override: true},
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
      {:gettext, "~> 0.16.1"},
      {:httpoison, "~> 1.0"},
      {:indexer, in_umbrella: true, runtime: false},
      # JSON parser and generator
      {:jason, "~> 1.0"},
      {:junit_formatter, ">= 0.0.0", only: [:test], runtime: false},
      # Log errors and application output to separate files
      {:logger_file_backend, "~> 0.0.10"},
      {:math, "~> 0.3.0"},
      {:mock, "~> 0.3.0", only: [:test], runtime: false},
      {:phoenix, "~> 1.4"},
      {:phoenix_ecto, "~> 4.0"},
      {:phoenix_html, "~> 2.10"},
      {:phoenix_live_reload, "~> 1.0", only: [:dev]},
      {:phoenix_pubsub, "~> 1.0"},
      # use `:cowboy` for WebServer with `:plug`
      {:plug_cowboy, "~> 2.0"},
      # Waiting for the Pretty Print to be implemented at the Jason lib
      # https://github.com/michalmuskala/jason/issues/15
      {:poison, "~> 3.1"},
      {:postgrex, ">= 0.0.0"},
      # For compatibility with `prometheus_process_collector`, which hasn't been updated yet
      {:prometheus, "~> 4.0", override: true},
      # Gather methods for Phoenix requests
      {:prometheus_phoenix, "~> 1.2"},
      # Expose metrics from URL Prometheus server can scrape
      {:prometheus_plugs, "~> 1.1"},
      # OS process metrics for Prometheus
      {:prometheus_process_collector, "~> 1.3"},
      {:qrcode, "~> 0.1.0"},
      {:sobelow, ">= 0.7.0", only: [:dev, :test], runtime: false},
      # Tracing
      {:spandex, github: "spandex-project/spandex", branch: "allow-setting-trace-key", override: true},
      # `:spandex` integration with Datadog
      {:spandex_datadog, "~> 0.3.1"},
      # `:spandex` tracing of `:phoenix`
      {:spandex_phoenix, "~> 0.3.1"},
      {:timex, "~> 3.4"},
      {:wallaby, "~> 0.20", only: [:test], runtime: false},
      # `:cowboy` `~> 2.0` and Phoenix 1.4 compatibility
      {:wobserver, "~> 0.2.0", github: "KronicDeth/wobserver", ref: "99683a936c75c0a94ebb884cef019f7ed0b97112"}
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
