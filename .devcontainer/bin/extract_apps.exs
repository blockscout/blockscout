#!/usr/bin/env elixir

defmodule LocalHelper do
  # Helper function to safely get configuration values
  def get_config_value(config, key, name) do
    case Keyword.get(config, key) do
      nil -> {:error, name}
      value -> {:ok, value}
    end
  end
end

# Start Mix application
Mix.start()

# Set the Mix environment to dev (or whatever environment you need)
Mix.env(:dev)

# Read and evaluate the mix.exs file
Code.require_file("mix.exs")

# Get the applications from the project configuration
apps =
  try do
    project = BlockScout.Mixfile.project()

    with {:ok, releases} <- LocalHelper.get_config_value(project, :releases, "releases"),
         {:ok, blockscout} <- LocalHelper.get_config_value(releases, :blockscout, "blockscout release"),
         {:ok, applications} <- LocalHelper.get_config_value(blockscout, :applications, "applications") do
      applications
      |> Keyword.keys()
      |> Enum.join("\n")
    else
      {:error, message} ->
        IO.puts(:stderr, "Error: #{message} not found in mix.exs configuration")
        System.halt(1)
    end
  rescue
    error ->
      IO.puts(:stderr, "Error: Failed to read mix.exs configuration - #{Exception.message(error)}")
      System.halt(1)
  end

# Print the applications to stdout
IO.puts(apps)
