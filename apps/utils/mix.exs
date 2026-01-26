defmodule Utils.MixProject do
  use Mix.Project

  def project do
    [
      app: :utils,
      version: "10.0.0",
      build_path: "../../_build",
      # config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.19",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :tesla]
    ]
  end

  def cli do
    [preferred_envs: [credo: :test, dialyzer: :test]]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.5", only: [:test, :dev], runtime: false},
      {:httpoison, "~> 2.0"},
      {:mime, "~> 2.0"},
      {:tesla, "~> 1.16.0"}
    ]
  end

  defp elixirc_paths(:prod), do: ["lib/utils", "lib/*"]
  defp elixirc_paths(_), do: ["lib"]
end
