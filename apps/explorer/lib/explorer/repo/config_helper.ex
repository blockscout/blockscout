defmodule Explorer.Repo.ConfigHelper do
  @moduledoc """
  Extracts values from environment and adds them to application config.

  Notably, this module processes the DATABASE_URL environment variable and extracts discrete parameters.

  The priority of vars is DATABASE_URL components < postgrex enviroment vars < application config vars, with values being overwritted by higher priority.
  """

  # set in apps/*/config/*.exs
  @app_env_vars [
    username: "DATABASE_USER",
    password: "DATABASE_PASSWORD",
    hostname: "DATABASE_HOSTNAME",
    port: "DATABASE_PORT",
    database: "DATABASE_DB"
  ]

  # https://hexdocs.pm/postgrex/Postgrex.html#start_link/1-options
  @postgrex_env_vars [
    username: "PGUSER",
    password: "PGPASSWORD",
    hostname: "PGHOST",
    port: "PGPORT",
    database: "PGDATABASE"
  ]

  def get_db_config(opts) do
    url = opts[:url] || System.get_env("DATABASE_URL")
    env_function = opts[:env_func] || (&System.get_env/1)

    url
    |> extract_parameters()
    |> Keyword.merge(get_env_vars(@postgrex_env_vars, env_function))
    |> Keyword.merge(get_env_vars(@app_env_vars, env_function))
  end

  defp extract_parameters(empty) when empty == nil or empty == "", do: []

  # sobelow_skip ["DOS.StringToAtom"]
  defp extract_parameters(database_url) do
    ~r/\w*:\/\/(?<username>\w+):(?<password>[a-zA-Z0-9-*#!%^&$_]*)?@(?<hostname>(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])):(?<port>\d+)\/(?<database>\w+)/
    |> Regex.named_captures(database_url)
    |> Keyword.new(fn {k, v} -> {String.to_atom(k), v} end)
    |> Keyword.put(:url, database_url)
    |> Enum.filter(fn
      # don't include keys with empty values
      {_, ""} -> false
      _ -> true
    end)
  end

  defp get_env_vars(vars, env_function) do
    Enum.reduce(vars, [], fn {name, var}, opts ->
      case env_function.(var) do
        nil -> opts
        env_value -> Keyword.put(opts, name, env_value)
      end
    end)
  end
end
