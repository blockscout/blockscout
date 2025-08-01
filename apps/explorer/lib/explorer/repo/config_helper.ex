defmodule Explorer.Repo.ConfigHelper do
  @moduledoc """
  Extracts values from environment and adds them to application config.

  Notably, this module processes the DATABASE_URL environment variable and extracts discrete parameters.

  The priority of vars is postgrex environment vars < DATABASE_URL components, with values being overwritten by higher priority.
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
    url_encoded = opts[:url]
    url = url_encoded && URI.decode(url_encoded)
    env_function = opts[:env_func] || (&System.get_env/1)

    @postgrex_env_vars
    |> get_env_vars(env_function)
    |> Keyword.merge(extract_parameters(url))
  end

  def get_account_db_url, do: System.get_env("ACCOUNT_DATABASE_URL") || System.get_env("DATABASE_URL")

  def get_suave_db_url, do: System.get_env("SUAVE_DATABASE_URL") || System.get_env("DATABASE_URL")

  def get_api_db_url, do: System.get_env("DATABASE_READ_ONLY_API_URL") || System.get_env("DATABASE_URL")

  def get_mud_db_url, do: System.get_env("MUD_DATABASE_URL") || System.get_env("DATABASE_URL")

  def init_repo_module(module, opts) do
    db_url = Application.get_env(:explorer, module)[:url]
    repo_conf = Application.get_env(:explorer, module)

    merged =
      %{url: db_url}
      |> get_db_config()
      |> Keyword.merge(repo_conf, fn
        _key, v1, nil -> v1
        _key, nil, v2 -> v2
        _, _, v2 -> v2
      end)

    Application.put_env(:explorer, module, merged)

    {:ok, opts |> Keyword.put(:url, remove_search_path(db_url)) |> Keyword.merge(Keyword.take(merged, [:search_path]))}
  end

  def ssl_enabled?, do: String.equivalent?(System.get_env("ECTO_USE_SSL") || "true", "true")

  def extract_parameters(empty) when empty == nil or empty == "", do: []

  # sobelow_skip ["DOS.StringToAtom"]
  def extract_parameters(database_url) do
    ~r/\w*:\/\/(?<username>[a-zA-Z0-9_-]*):(?<password>[a-zA-Z0-9-*#!%^&$_.]*)?@(?<hostname>(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])):(?<port>\d+)\/(?<database>[a-zA-Z0-9_\-]*)(\?.*search_path=(?<search_path>[a-zA-Z0-9_\-,]+))?/
    |> Regex.named_captures(database_url)
    |> Keyword.new(fn {k, v} -> {String.to_atom(k), v} end)
    |> Keyword.put(:url, database_url)
    |> adjust_search_path()
  end

  defp adjust_search_path(params) do
    case params[:search_path] do
      empty when empty in [nil, ""] -> Keyword.delete(params, :search_path)
      [_search_path] -> params
      search_path -> Keyword.put(params, :search_path, [search_path])
    end
  end

  # Workaround for Ecto.Repo init.
  # It takes parameters from the url in priority over provided options (as strings)
  # while Postgrex expects search_path to be a list
  # which means that it will always crash if there is a search_path parameter in DB url.
  # That's why we need to remove this parameter from DB url before passing it to Ecto.
  defp remove_search_path(nil), do: nil

  defp remove_search_path(db_url) do
    case URI.parse(db_url) do
      %{query: nil} ->
        db_url

      %{query: query} = uri ->
        query_without_search_path =
          query
          |> URI.decode_query()
          |> Map.delete("search_path")
          |> URI.encode_query()

        uri
        |> Map.put(:query, query_without_search_path)
        |> URI.to_string()
    end
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

  def network_path do
    path = System.get_env("NETWORK_PATH", "/")

    path_from_env(path)
  end

  @doc """
  Defines http port of the application
  """
  @spec get_port() :: non_neg_integer()
  def get_port do
    case System.get_env("PORT") && Integer.parse(System.get_env("PORT")) do
      {port, _} -> port
      _ -> 4000
    end
  end

  defp path_from_env(path_env_var) do
    if String.ends_with?(path_env_var, "/") do
      path_env_var
    else
      path_env_var <> "/"
    end
  end
end
