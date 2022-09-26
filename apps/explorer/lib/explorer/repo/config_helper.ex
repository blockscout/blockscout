defmodule Explorer.Repo.ConfigHelper do
  @moduledoc """
  Extracts values from environment and adds them to application config.

  Notably, this module processes the DATABASE_URL environment variable and extracts discrete parameters.

  The priority of vars is postgrex environment vars < DATABASE_URL components, with values being overwritted by higher priority.
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

  def get_db_pool_size(default_pool_size), do: String.to_integer(System.get_env("POOL_SIZE", default_pool_size))

  def get_account_db_url, do: System.get_env("ACCOUNT_DATABASE_URL") || System.get_env("DATABASE_URL")

  def get_account_db_pool_size(default_pool_size),
    do: String.to_integer(System.get_env("ACCOUNT_POOL_SIZE", default_pool_size))

  def get_api_db_url, do: System.get_env("DATABASE_READ_ONLY_API_URL") || System.get_env("DATABASE_URL")

  def get_api_db_pool_size(default_pool_size), do: String.to_integer(System.get_env("POOL_SIZE_API", default_pool_size))

  def ssl_enabled?, do: String.equivalent?(System.get_env("ECTO_USE_SSL") || "true", "true")

  defp extract_parameters(empty) when empty == nil or empty == "", do: []

  # sobelow_skip ["DOS.StringToAtom"]
  defp extract_parameters(database_url) do
    ~r/\w*:\/\/(?<username>\w+):(?<password>[a-zA-Z0-9-*#!%^&$_]*)?@(?<hostname>(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])):(?<port>\d+)\/(?<database>[a-zA-Z0-9_-]*)/
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
