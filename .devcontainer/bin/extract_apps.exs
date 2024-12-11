#!/usr/bin/env elixir

# Start Mix application
Mix.start()

# Set the Mix environment to dev (or whatever environment you need)
Mix.env(:dev)

# Read and evaluate the mix.exs file
Code.require_file("mix.exs")

# Get the applications from the project configuration
apps = BlockScout.Mixfile.project()
  |> Keyword.get(:releases)
  |> Keyword.get(:blockscout)
  |> Keyword.get(:applications)
  |> Keyword.keys()
  |> Enum.join("\n")

# Print the applications to stdout
IO.puts(apps)
