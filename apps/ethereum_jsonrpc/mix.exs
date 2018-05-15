defmodule EthereumJsonrpc.MixProject do
  use Mix.Project

  def project do
    [
      aliases: aliases(Mix.env()),
      app: :ethereum_jsonrpc,
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
      lockfile: "../../mix.lock",
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        dialyzer: :test
      ],
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      version: "0.1.0"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {EthereumJSONRPC.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp aliases(env) do
    env_aliases(env)
  end

  defp env_aliases(:dev), do: []

  defp env_aliases(_env), do: [compile: "compile --warnings-as-errors"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Style Checking
      {:credo, "0.9.2", only: [:dev, :test], runtime: false},
      # Static Type Checking
      {:dialyxir, "~> 0.5", only: [:dev, :test], runtime: false},
      # Casting Ethereum-native types to Elixir-native types
      {:ecto, "~> 2.2"},
      # Code coverage
      {:excoveralls, "~> 0.8.1", only: [:test]},
      # JSONRPC HTTP Post calls
      {:httpoison, "~> 1.0", override: true},
      # Decode/Encode JSON for JSONRPC
      {:jason, "~> 1.0"},
      # Convert unix timestamps in JSONRPC to DateTimes
      {:timex, "~> 3.1.24"}
    ]
  end
end
