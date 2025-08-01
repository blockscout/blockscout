defmodule NFTMediaHandler.MixProject do
  use Mix.Project

  def project do
    [
      app: :nft_media_handler,
      version: "9.0.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [mod: {NFTMediaHandler.Application, []}, extra_applications: [:logger]]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_aws, "~> 2.0"},
      {:ex_aws_s3, "~> 2.0"},
      {:jason, "~> 1.3"},
      {:hackney, "~> 1.9"},
      {:sweet_xml, "~> 0.7"},
      {:image, "~> 0.54"},
      {:httpoison, "~> 2.0"},
      {:evision, "~> 0.2"},
      {:mime, "~> 2.0"},
      {:utils, in_umbrella: true}
    ]
    |> optionally_nft_media_handler()
  end

  defp optionally_nft_media_handler(deps) do
    if Application.get_env(:nft_media_handler, :remote?) do
      deps
    else
      deps ++ [{:indexer, in_umbrella: true}]
    end
  end
end
