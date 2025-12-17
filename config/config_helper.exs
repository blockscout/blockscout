defmodule ConfigHelper do
  require Logger

  import Bitwise
  alias Explorer.Market.Source
  alias Indexer.Transform.Blocks
  alias Utils.ConfigHelper

  def repos do
    base_repos = [Explorer.Repo, Explorer.Repo.Account]

    chain_identity_repos =
      %{
        {:arbitrum, nil} => [Explorer.Repo.Arbitrum],
        {:blackfort, nil} => [Explorer.Repo.Blackfort],
        {:ethereum, nil} => [Explorer.Repo.Beacon],
        {:filecoin, nil} => [Explorer.Repo.Filecoin],
        {:optimism, nil} => [Explorer.Repo.Optimism],
        {:polygon_zkevm, nil} => [Explorer.Repo.PolygonZkevm],
        {:rsk, nil} => [Explorer.Repo.RSK],
        {:scroll, nil} => [Explorer.Repo.Scroll],
        {:shibarium, nil} => [Explorer.Repo.Shibarium],
        {:stability, nil} => [Explorer.Repo.Stability],
        {:suave, nil} => [Explorer.Repo.Suave],
        {:zilliqa, nil} => [Explorer.Repo.Zilliqa],
        {:zksync, nil} => [Explorer.Repo.ZkSync],
        {:neon, nil} => [Explorer.Repo.Neon],
        {:optimism, :celo} => [
          Explorer.Repo.Optimism,
          Explorer.Repo.Celo
        ]
      }
      |> Map.get(chain_identity(), [])

    ext_repos =
      [
        {parse_bool_env_var("BRIDGED_TOKENS_ENABLED"), Explorer.Repo.BridgedTokens},
        {parse_bool_env_var("MUD_INDEXER_ENABLED"), Explorer.Repo.Mud},
        {parse_bool_env_var("SHRINK_INTERNAL_TRANSACTIONS_ENABLED"), Explorer.Repo.ShrunkInternalTransactions},
        {mode() in [:indexer, :api], Explorer.Repo.EventNotifications}
      ]
      |> Enum.filter(&elem(&1, 0))
      |> Enum.map(&elem(&1, 1))

    base_repos ++ chain_identity_repos ++ ext_repos
  end

  @doc """
  Returns the list of logger backends to be used by the application.

  If the DISABLE_FILE_LOGGING environment variable is set to true, only base
  logger backends (:console and LoggerJSON) are returned. Otherwise, returns
  both base and file logger backends.
  """
  @spec logger_backends() :: list()
  def logger_backends do
    base_logger_backends = [
      :console
    ]

    if parse_bool_env_var("DISABLE_FILE_LOGGING") do
      base_logger_backends
    else
      file_logger_backends =
        [
          {LoggerFileBackend, :error},
          {LoggerFileBackend, :block_scout_web},
          {LoggerFileBackend, :ethereum_jsonrpc},
          {LoggerFileBackend, :explorer},
          {LoggerFileBackend, :indexer},
          {LoggerFileBackend, :indexer_token_balances},
          {LoggerFileBackend, :token_instances},
          {LoggerFileBackend, :reading_token_functions},
          {LoggerFileBackend, :pending_transactions_to_refetch},
          {LoggerFileBackend, :empty_blocks_to_refetch},
          {LoggerFileBackend, :withdrawal},
          {LoggerFileBackend, :api},
          {LoggerFileBackend, :block_import_timings},
          {LoggerFileBackend, :account},
          {LoggerFileBackend, :api_v2}
        ]

      base_logger_backends ++ file_logger_backends
    end
  end

  @doc """
  Returns the list of metadata fields to be included in logger output.
  """
  @spec logger_metadata() :: list()
  def logger_metadata() do
    ~w(application fetcher request_id first_block_number last_block_number missing_block_range_count missing_block_count
       block_number step count error_count shrunk import_id transaction_id)a
  end

  @doc """
  Returns the list of metadata fields to be included in logger backend output.
  """
  @spec logger_backend_metadata() :: list()
  def logger_backend_metadata() do
    ~w(application fetcher request_id first_block_number last_block_number missing_block_range_count missing_block_count
        block_number step count error_count shrunk import_id transaction_id duration status unit endpoint method)a
  end

  @spec http_options(non_neg_integer()) :: list()
  def http_options(default_timeout \\ 1) do
    http_timeout = timeout(default_timeout)
    basic_auth_user = System.get_env("ETHEREUM_JSONRPC_USER", "")
    basic_auth_pass = System.get_env("ETHEREUM_JSONRPC_PASSWORD", nil)

    [pool: :ethereum_jsonrpc, recv_timeout: http_timeout, timeout: http_timeout]
    |> (&if(System.get_env("ETHEREUM_JSONRPC_HTTP_INSECURE", "") == "true", do: [insecure: true] ++ &1, else: &1)).()
    |> (&if(basic_auth_user != "" && !is_nil(basic_auth_pass),
          do: [basic_auth: {basic_auth_user, basic_auth_pass}] ++ &1,
          else: &1
        )).()
  end

  @spec timeout(non_neg_integer()) :: non_neg_integer()
  def timeout(default_minutes \\ 1) do
    case Integer.parse(safe_get_env("ETHEREUM_JSONRPC_HTTP_TIMEOUT", "#{default_minutes * 60}")) do
      {seconds, ""} -> seconds
      _ -> default_minutes * 60
    end
    |> :timer.seconds()
  end

  @spec parse_integer_env_var(String.t(), integer()) :: non_neg_integer()
  def parse_integer_env_var(env_var, default_value) do
    env_var
    |> safe_get_env(to_string(default_value))
    |> Integer.parse()
    |> case do
      {integer, _} -> integer
      _ -> 0
    end
  end

  @spec parse_float_env_var(String.t(), float()) :: float()
  def parse_float_env_var(env_var, default_value) do
    env_var
    |> safe_get_env(to_string(default_value))
    |> Float.parse()
    |> case do
      {float, _} -> float
      _ -> 0
    end
  end

  @spec parse_integer_or_nil_env_var(String.t()) :: non_neg_integer() | nil
  def parse_integer_or_nil_env_var(env_var) do
    env_var
    |> System.get_env("")
    |> Integer.parse()
    |> case do
      {integer, _} -> integer
      _ -> nil
    end
  end

  @spec parse_time_env_var(String.t(), String.t() | nil) :: non_neg_integer() | nil
  def parse_time_env_var(env_var, default_value \\ nil) do
    case safe_get_env(env_var, default_value) do
      "" ->
        nil

      value ->
        case ConfigHelper.parse_time_value(value) do
          :error ->
            raise "Invalid time format in environment variable #{env_var}: #{value}"

          time ->
            time
        end
    end
  end

  @doc """
  Parses value of env var through catalogued values list. If a value is not in the list, nil is returned.
  Also, the application shutdown option is supported, if a value is wrong.
  """
  @spec parse_catalog_value(String.t(), List.t(), bool(), String.t() | nil) :: atom() | nil
  def parse_catalog_value(env_var, catalog, shutdown_on_wrong_value?, default_value \\ nil) do
    value = env_var |> safe_get_env(default_value)

    if value !== "" do
      if value in catalog do
        String.to_atom(value)
      else
        if shutdown_on_wrong_value? do
          Logger.error(wrong_value_error(value, env_var, catalog))
          exit(:shutdown)
        else
          Logger.warning(wrong_value_error(value, env_var, catalog))
          nil
        end
      end
    else
      nil
    end
  end

  defp wrong_value_error(value, env_var, catalog) do
    "Invalid value \"#{value}\" of #{env_var} environment variable is provided. Supported values are #{inspect(catalog)}"
  end

  @doc """
  Parses value of env var through catalogued values map. If a value is not in
  the map, nil is returned. Also, the application shutdown option is supported,
  if a value is wrong.
  """
  @spec parse_catalog_map_value(String.t(), %{binary() => any()}, bool(), String.t() | nil) :: any() | nil
  def parse_catalog_map_value(env_var, catalog, shutdown_on_wrong_key?, default_key \\ nil) do
    key = env_var |> safe_get_env(default_key)

    if key !== "" do
      case Map.fetch(catalog, key) do
        {:ok, value} ->
          value

        :error ->
          if shutdown_on_wrong_key? do
            Logger.error(wrong_value_error(key, env_var, catalog))
            exit(:shutdown)
          else
            Logger.warning(wrong_value_error(key, env_var, catalog))
            nil
          end
      end
    else
      nil
    end
  end

  def safe_get_env(env_var, default_value) do
    env_var
    |> System.get_env(default_value)
    |> case do
      "" -> default_value
      value -> value
    end
    |> to_string()
  end

  @spec parse_bool_env_var(String.t(), String.t()) :: boolean()
  def parse_bool_env_var(env_var, default_value \\ "false"),
    do: String.downcase(safe_get_env(env_var, default_value)) == "true"

  @spec parse_path_env_var(String.t(), String.t() | nil) :: String.t() | nil
  def parse_path_env_var(env_var, default_value \\ nil) do
    env_var
    |> System.get_env(default_value)
    |> case do
      "//" <> _ = path -> raise "Invalid path in environment variable #{env_var}: #{path}"
      "/" <> _ = path -> path
      path when is_binary(path) -> "/" <> path
      other -> other
    end
  end

  @spec cache_ttl_check_interval(boolean()) :: non_neg_integer() | false
  def cache_ttl_check_interval(disable_indexer?) do
    if(disable_indexer?, do: :timer.seconds(1), else: false)
  end

  @spec cache_global_ttl(boolean()) :: non_neg_integer()
  def cache_global_ttl(disable_indexer?) do
    if(disable_indexer?, do: :timer.seconds(5))
  end

  @spec indexer_memory_limit() :: integer()
  def indexer_memory_limit do
    "INDEXER_MEMORY_LIMIT"
    |> safe_get_env(nil)
    |> String.downcase()
    |> Integer.parse()
    |> case do
      {integer, g} when g in ["g", "gb", ""] -> integer <<< 30
      {integer, m} when m in ["m", "mb"] -> integer <<< 20
      _ -> nil
    end
  end

  @spec market_source(String.t()) ::
          Source.CoinGecko
          | Source.CoinMarketCap
          | Source.CryptoCompare
          | Source.CryptoRank
          | Source.DefiLlama
          | Source.DIA
          | Source.Mobula
          | nil
  def market_source(env_var) do
    sources = %{
      "coin_gecko" => Source.CoinGecko,
      "coin_market_cap" => Source.CoinMarketCap,
      "crypto_compare" => Source.CryptoCompare,
      "crypto_rank" => Source.CryptoRank,
      "defillama" => Source.DefiLlama,
      "dia" => Source.DIA,
      "mobula" => Source.Mobula,
      "" => nil,
      nil => nil
    }

    configured_source = System.get_env(env_var)

    case Map.fetch(sources, configured_source) do
      {:ok, source} ->
        source

      _ ->
        raise """
        No such #{env_var}: #{configured_source}.

        Valid values are:
        #{Enum.join(Map.keys(sources), "\n")}

        Please update environment variable #{env_var} accordingly.
        """
    end
  end

  def block_transformer do
    block_transformers = %{
      "clique" => Blocks.Clique,
      "base" => Blocks.Base
    }

    # Compile time environment variable access requires recompilation.
    configured_transformer = safe_get_env("BLOCK_TRANSFORMER", "base")

    case Map.get(block_transformers, configured_transformer) do
      nil ->
        raise """
        No such block transformer: #{configured_transformer}.

        Valid values are:
        #{Enum.join(Map.keys(block_transformers), "\n")}

        Please update environment variable BLOCK_TRANSFORMER accordingly.
        """

      transformer ->
        transformer
    end
  end

  @spec parse_json_env_var(String.t(), String.t()) :: any()
  def parse_json_env_var(env_var, default_value \\ "{}") do
    env_var
    |> safe_get_env(default_value)
    |> Jason.decode!()
  rescue
    err -> raise "Invalid JSON in environment variable #{env_var}: #{inspect(err)}"
  end

  def parse_json_with_atom_keys_env_var(env_var, default_value \\ "{}") do
    with {:ok, map} <-
           env_var
           |> safe_get_env(default_value)
           |> Jason.decode() do
      for {key, value} <- map, into: %{}, do: {String.to_atom(key), value}
    else
      {:error, error} -> raise "Invalid JSON in environment variable #{env_var}: #{inspect(error)}"
    end
  rescue
    error -> raise "Invalid JSON in environment variable #{env_var}: #{inspect(error)}"
  end

  @spec parse_list_env_var(String.t(), String.t() | nil) :: list()
  def parse_list_env_var(env_var, default_value \\ nil) do
    addresses_var = safe_get_env(env_var, default_value)

    if addresses_var !== "" do
      addresses_list = (addresses_var && String.split(addresses_var, ",")) || []

      formatted_addresses_list =
        addresses_list
        |> Enum.map(fn addr ->
          String.downcase(addr)
        end)

      formatted_addresses_list
    else
      []
    end
  end

  @spec parse_url_env_var(String.t(), boolean()) :: String.t() | nil
  def parse_url_env_var(env_var, default_value \\ nil, trailing_slash_needed? \\ false) do
    with url when not is_nil(url) <- safe_get_env(env_var, default_value),
         url <- String.trim_trailing(url, "/"),
         true <- url != "",
         {url, true} <- {url, trailing_slash_needed?} do
      url <> "/"
    else
      {url, false} ->
        url

      false ->
        default_value

      nil ->
        nil
    end
  end

  @supported_chain_identities %{
    "default" => :default,
    "arbitrum" => :arbitrum,
    "arc" => :arc,
    "blackfort" => :blackfort,
    "ethereum" => :ethereum,
    "filecoin" => :filecoin,
    "optimism" => :optimism,
    "polygon_zkevm" => :polygon_zkevm,
    "rsk" => :rsk,
    "scroll" => :scroll,
    "shibarium" => :shibarium,
    "stability" => :stability,
    "suave" => :suave,
    "zetachain" => :zetachain,
    "zilliqa" => :zilliqa,
    "zksync" => :zksync,
    "neon" => :neon,
    "optimism-celo" => {:optimism, :celo}
  }

  @doc """
  Returns the primary chain type.

  This function extracts the base chain type from the chain identity (see
  chain_identity/1), which is used to determine the core feature set and
  indexing behavior. For example, both `:optimism` and `{:optimism, :celo}`
  identities will return `:optimism` as the chain type, allowing them to share
  the same Optimism-specific logic.

  ## Examples

      iex> System.put_env("CHAIN_TYPE", "optimism")
      iex> chain_type()
      :optimism

      iex> System.put_env("CHAIN_TYPE", "optimism-celo")
      iex> chain_type()
      :optimism

  ## Returns

    * `atom()` - The primary chain type identifier
  """
  @spec chain_type() :: atom()
  def chain_type do
    {type, _} = chain_identity()
    type
  end

  @doc """
  Returns the full chain identity as a tuple of base type and optional variant.

  Chain identity is a concept that allows networks to inherit a base chain's
  feature set while adding variant-specific customizations. The identity is
  returned as a two-element tuple `{base_type, variant}` where:

  - `base_type` - The primary chain type (e.g., `:optimism`, `:arbitrum`)
  - `variant` - An optional sub-type for specialized networks (e.g., `:celo`)

  This enables Celo to run on the OP Stack with the identity `{:optimism,
  :celo}`, inheriting all Optimism features (deposits, withdrawals, batches,
  etc.) while allowing Celo-specific endpoints, caches, and schema fields to be
  gated on the full identity tuple.

  The identity is configured via the `CHAIN_TYPE` environment variable and must
  match one of the supported values in `@supported_chain_identities`.

  ## Examples

      iex> System.put_env("CHAIN_TYPE", "optimism")
      iex> chain_identity()
      {:optimism, nil}

      iex> System.put_env("CHAIN_TYPE", "optimism-celo")
      iex> chain_identity()
      {:optimism, :celo}

      iex> System.put_env("CHAIN_TYPE", "ethereum")
      iex> chain_identity()
      {:ethereum, nil}

  ## Returns

    * `{atom(), atom() | nil}` - A tuple containing the base chain type and
      optional variant
  """
  @spec chain_identity() :: {atom(), atom() | nil}
  def chain_identity do
    "CHAIN_TYPE"
    |> parse_catalog_map_value(@supported_chain_identities, true, "default")
    |> case do
      type when is_atom(type) -> {type, nil}
      identity -> identity
    end
  end

  @supported_modes ["all", "indexer", "api"]

  @spec mode :: atom()
  def mode, do: parse_catalog_value("APPLICATION_MODE", @supported_modes, true, "all")

  @doc """
  Retrieves json rpc urls list based on `urls_type`
  """
  @spec parse_urls_list(
          :http | :trace | :eth_call | :fallback_http | :fallback_trace | :fallback_eth_call,
          String.t() | nil
        ) :: [String.t()]
  def parse_urls_list(urls_type, default_url \\ nil) do
    {urls_var, url_var} = define_urls_vars(urls_type)

    with [] <- parse_list_env_var(urls_var),
         "" <- safe_get_env(url_var, default_url) do
      case urls_type do
        :http ->
          Logger.warning("ETHEREUM_JSONRPC_HTTP_URL (or ETHEREUM_JSONRPC_HTTP_URLS) env variable is required")
          []

        :fallback_http ->
          parse_urls_list(:http)

        _other ->
          new_urls_type = if String.contains?(to_string(urls_type), "fallback"), do: :fallback_http, else: :http
          parse_urls_list(new_urls_type)
      end
    else
      urls when is_list(urls) -> urls
      url -> [url]
    end
  end

  @doc """
    Parses and validates a microservice URL from an environment variable, removing any trailing slash.

    ## Parameters
    - `env_name`: The name of the environment variable containing the URL

    ## Returns
    - The validated URL string with any trailing slash removed
    - `nil` if the URL is invalid or missing required components
  """
  @spec parse_microservice_url(String.t()) :: String.t() | nil
  def parse_microservice_url(env_name) do
    url = System.get_env(env_name)

    cond do
      not valid_url?(url) ->
        nil

      String.ends_with?(url, "/") ->
        url
        |> String.slice(0..(String.length(url) - 2))

      true ->
        url
    end
  end

  # Validates if the given string is a valid URL by checking if it has both scheme (like http,
  # https, ftp) and host components.
  @spec valid_url?(String.t()) :: boolean()
  defp valid_url?(string) when is_binary(string) do
    uri = URI.parse(string)

    !is_nil(uri.scheme) && !is_nil(uri.host)
  end

  defp valid_url?(_), do: false

  defp define_urls_vars(:http), do: {"ETHEREUM_JSONRPC_HTTP_URLS", "ETHEREUM_JSONRPC_HTTP_URL"}
  defp define_urls_vars(:trace), do: {"ETHEREUM_JSONRPC_TRACE_URLS", "ETHEREUM_JSONRPC_TRACE_URL"}
  defp define_urls_vars(:eth_call), do: {"ETHEREUM_JSONRPC_ETH_CALL_URLS", "ETHEREUM_JSONRPC_ETH_CALL_URL"}

  defp define_urls_vars(:fallback_http),
    do: {"ETHEREUM_JSONRPC_FALLBACK_HTTP_URLS", "ETHEREUM_JSONRPC_FALLBACK_HTTP_URL"}

  defp define_urls_vars(:fallback_trace),
    do: {"ETHEREUM_JSONRPC_FALLBACK_TRACE_URLS", "ETHEREUM_JSONRPC_FALLBACK_TRACE_URL"}

  defp define_urls_vars(:fallback_eth_call),
    do: {"ETHEREUM_JSONRPC_FALLBACK_ETH_CALL_URLS", "ETHEREUM_JSONRPC_FALLBACK_ETH_CALL_URL"}
end
