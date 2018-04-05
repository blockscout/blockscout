defmodule ExplorerUmbrella.Mixfile do
  use Mix.Project

  # Functions

  def project do
    [
      aliases: aliases(),
      apps_path: "apps",
      deps: deps(),
      dialyzer: [
        plt_add_deps: :transitive,
        plt_add_apps: [:mix],
        ignore_warnings: ".dialyzer-ignore"
      ],
      elixir: "~> 1.6",
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls]
    ]
  end

  ## Private Functions

  defp aliases do
    [
      compile: "compile --warnings-as-errors"
    ]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options.
  #
  # Dependencies listed here are available only for this project
  # and cannot be accessed from applications inside the apps folder
  defp deps do
    [
      # Documentation
      {:ex_doc, "~> 0.18.3", only: [:dev]},
      # Code coverage
      {:excoveralls, "~> 0.8.1", only: [:test]}
    ]
  end
end
