defmodule BlockScout.Mixfile do
  use Mix.Project

  # Functions

  def project do
    [
      app: :block_scout,
      # aliases: aliases(config_env()),
      version: "4.1.2",
      apps_path: "apps",
      deps: deps(),
      dialyzer: dialyzer(),
      elixir: "~> 1.12",
      preferred_cli_env: [
        credo: :test,
        dialyzer: :test
      ],
      # start_permanent: config_env() == :prod,
      releases: [
        blockscout: [
          applications: [
            block_scout_web: :permanent,
            ethereum_jsonrpc: :permanent,
            explorer: :permanent,
            indexer: :permanent
          ]
        ]
      ]
    ]
  end

  ## Private Functions

  defp dialyzer() do
    [
      plt_add_deps: :transitive,
      plt_add_apps: ~w(ex_unit mix)a,
      ignore_warnings: ".dialyzer-ignore",
      plt_core_path: "priv/plts",
      plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
    ]
  end

  # defp aliases(env) do
  #   [
  #     # to match behavior of `mix test` in `apps/indexer`, which needs to not start applications for `indexer` to
  #     # prevent its supervision tree from starting, which is undesirable in test
  #     test: "test --no-start"
  #   ] ++ env_aliases(env)
  # end

  # defp env_aliases(:dev) do
  #   []
  # end

  # defp env_aliases(_env) do
  #   [
  #     compile: "compile --warnings-as-errors"
  #   ]
  # end

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
      {:con_cache, "~> 1.0"},
      {:absinthe_plug, git: "https://github.com/blockscout/absinthe_plug.git", tag: "1.5.3", override: true},
      {:tesla, "~> 1.3.3"},
      # Documentation
      {:ex_doc, "~> 0.28.2", only: :dev, runtime: false},
      {:number, "~> 1.0.3"}
    ]
  end
end
