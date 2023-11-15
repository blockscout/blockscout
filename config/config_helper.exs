defmodule ConfigHelper do
  import Bitwise
  alias Explorer.ExchangeRates.Source
  alias Explorer.Market.History.Source.{MarketCap, Price, TVL}
  alias Indexer.Transform.Blocks

  def repos do
    base_repos = [Explorer.Repo, Explorer.Repo.Account]

    case System.get_env("CHAIN_TYPE") do
      "polygon_edge" -> base_repos ++ [Explorer.Repo.PolygonEdge]
      "polygon_zkevm" -> base_repos ++ [Explorer.Repo.PolygonZkevm]
      "rsk" -> base_repos ++ [Explorer.Repo.RSK]
      "suave" -> base_repos ++ [Explorer.Repo.Suave]
      _ -> base_repos
    end
  end

  @spec hackney_options() :: any()
  def hackney_options() do
    basic_auth_user = System.get_env("ETHEREUM_JSONRPC_USER", "")
    basic_auth_pass = System.get_env("ETHEREUM_JSONRPC_PASSWORD", nil)

    [pool: :ethereum_jsonrpc]
    |> (&if(System.get_env("ETHEREUM_JSONRPC_HTTP_INSECURE", "") == "true", do: [:insecure] ++ &1, else: &1)).()
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

  @spec parse_time_env_var(String.t(), String.t() | nil) :: non_neg_integer()
  def parse_time_env_var(env_var, default_value) do
    case env_var |> safe_get_env(default_value) |> String.downcase() |> Integer.parse() do
      {milliseconds, "ms"} -> milliseconds
      {hours, "h"} -> :timer.hours(hours)
      {minutes, "m"} -> :timer.minutes(minutes)
      {seconds, s} when s in ["s", ""] -> :timer.seconds(seconds)
      _ -> 0
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
    indexer_memory_limit_default = 1

    "INDEXER_MEMORY_LIMIT"
    |> safe_get_env(to_string(indexer_memory_limit_default))
    |> String.downcase()
    |> Integer.parse()
    |> case do
      {integer, g} when g in ["g", "gb", ""] -> integer <<< 30
      {integer, m} when m in ["m", "mb"] -> integer <<< 20
      _ -> indexer_memory_limit_default <<< 30
    end
  end

  @spec exchange_rates_source() :: Source.CoinGecko | Source.CoinMarketCap
  def exchange_rates_source do
    case System.get_env("EXCHANGE_RATES_MARKET_CAP_SOURCE") do
      "coin_gecko" -> Source.CoinGecko
      "coin_market_cap" -> Source.CoinMarketCap
      _ -> Source.CoinGecko
    end
  end

  @spec exchange_rates_market_cap_source() :: MarketCap.CoinGecko | MarketCap.CoinMarketCap
  def exchange_rates_market_cap_source do
    case System.get_env("EXCHANGE_RATES_MARKET_CAP_SOURCE") do
      "coin_gecko" -> MarketCap.CoinGecko
      "coin_market_cap" -> MarketCap.CoinMarketCap
      _ -> MarketCap.CoinGecko
    end
  end

  @spec exchange_rates_tvl_source() :: TVL.DefiLlama
  def exchange_rates_tvl_source do
    case System.get_env("EXCHANGE_RATES_TVL_SOURCE") do
      "defillama" -> TVL.DefiLlama
      _ -> TVL.DefiLlama
    end
  end

  @spec exchange_rates_price_source() :: Price.CoinGecko | Price.CoinMarketCap | Price.CryptoCompare
  def exchange_rates_price_source do
    case System.get_env("EXCHANGE_RATES_PRICE_SOURCE") do
      "coin_gecko" -> Price.CoinGecko
      "coin_market_cap" -> Price.CoinMarketCap
      "crypto_compare" -> Price.CryptoCompare
      _ -> Price.CryptoCompare
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
  def parse_json_env_var(env_var, default_value) do
    env_var
    |> safe_get_env(default_value)
    |> Jason.decode!()
  rescue
    err -> raise "Invalid JSON in environment variable #{env_var}: #{inspect(err)}"
  end

  @spec chain_type() :: String.t()
  def chain_type, do: System.get_env("CHAIN_TYPE") || "ethereum"
end
