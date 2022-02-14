defmodule Explorer.Repo.ConfigHelper do
  @moduledoc """
  Extracts values from environment and adds them to application config.

  Notably, this module processes the DATABASE_URL environment variable and extracts discrete parameters.

  The priority of vars is postgrex enviroment vars < DATABASE_URL components, with values being overwritted by higher priority.
  """

  # https://hexdocs.pm/postgrex/Postgrex.html#start_link/1-options
  @postgrex_env_vars [
    username: "PGUSER",
    password: "PGPASSWORD",
    host: "PGHOST",
    port: "PGPORT",
    database: "PGDATABASE"
  ]

  def get_db_config(opts) do
    url = opts[:url] || System.get_env("DATABASE_URL")
    env_function = opts[:env_func] || (&System.get_env/1)

    @postgrex_env_vars
    |> get_env_vars(env_function)
    |> Keyword.merge(extract_parameters(url))
  end

  defp extract_parameters(empty) when empty == nil or empty == "", do: []

  # sobelow_skip ["DOS.StringToAtom"]
  defp extract_parameters(database_url) do
    ~r/\w*:\/\/(?<username>\w+):(?<password>\w*)?@(?<hostname>[a-zA-Z\d\.]+):(?<port>\d+)\/(?<database>\w+)/
    |> Regex.named_captures(database_url)
    |> Keyword.new(fn {k, v} -> {String.to_atom(k), v} end)
    |> Keyword.put(:url, database_url)
  end

  defp get_env_vars(vars, env_function) do
    Enum.reduce(vars, [], fn {name, var}, opts ->
      case env_function.(var) do
        nil -> opts
        "" -> opts
        env_value -> Keyword.put(opts, name, env_value)
      end
    end)
  end
end
