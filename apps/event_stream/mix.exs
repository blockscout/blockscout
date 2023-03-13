defmodule EventStream.MixProject do
  use Mix.Project

  def project do
    [
      app: :event_stream,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.7",
      elixirc_paths: elixirc_paths(Mix.env()),
      elixirc_options: [
        warnings_as_errors: true
      ],
      compilers: [:phoenix] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {EventStream.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:explorer, in_umbrella: true, runtime: false},
      {:phoenix, "~> 1.5.13"},
      {:phoenix_html, "== 3.0.4"},
      {:phoenix_live_dashboard, "~> 0.4"},
      {:phoenix_live_reload, "~> 1.2", only: [:dev]},
      {:phoenix_live_view, "~> 0.17.2"},
      {:floki, ">= 0.30.0", only: :test},
      {:telemetry, "~> 1.0", override: true},
      {:telemetry_metrics, "~> 0.6.1"},
      {:telemetry_metrics_prometheus_core, "~> 1.1.0"},
      {:telemetry_poller, "~> 0.4"},
      {:gettext, "~> 0.11"},
      {:jason, "~> 1.0"},
      {:plug_cowboy, "~> 2.5.2"},
      # publishing implementations
      {:elixir_talk, "~> 1.2"},
      {:junit_formatter, ">= 0.0.0", only: [:test], runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "cmd npm install --prefix assets"]
    ]
  end
end
