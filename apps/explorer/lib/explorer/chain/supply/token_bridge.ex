defmodule Explorer.Chain.Supply.TokenBridge do
  @moduledoc """
  Defines the supply API for calculating the supply based on Token Bridge.
  """

  use Explorer.Chain.Supply

  import Ecto.Query,
    only: [
      from: 2
    ]

  alias Explorer.Chain.{BridgedToken, Token, Wei}
  alias Explorer.ExchangeRates.Source
  alias Explorer.Repo
  alias Explorer.SmartContract.Reader

  @token_bridge_contract_address "0x7301CFA0e1756B71869E93d4e4Dca5c7d0eb0AA6"
  @total_burned_coins_abi %{
    "type" => "function",
    "stateMutability" => "view",
    "payable" => false,
    "outputs" => [%{"type" => "uint256", "name" => ""}],
    "name" => "totalBurntCoins",
    "inputs" => [],
    "constant" => true
  }
  # 0e8162ba=keccak256(totalBurntCoins())
  @total_burned_coins_params %{"0e8162ba" => []}

  @block_reward_contract_abi %{
    "type" => "function",
    "stateMutability" => "view",
    "payable" => false,
    "outputs" => [%{"type" => "address", "name" => ""}],
    "name" => "blockRewardContract",
    "inputs" => [],
    "constant" => true
  }

  # 56b54bae=keccak256(blockRewardContract())
  @block_reward_contract_params %{"56b54bae" => []}

  @total_minted_coins_abi %{
    "type" => "function",
    "stateMutability" => "view",
    "payable" => false,
    "outputs" => [%{"type" => "uint256", "name" => ""}],
    "name" => "mintedTotally",
    "inputs" => [],
    "constant" => true
  }

  # 553a5c85=keccak256(mintedTotallymintedTotally())
  @total_minted_coins_params %{"553a5c85" => []}

  @ets_table :token_bridge_contract_coin_cache
  # 30 minutes
  @cache_period 1_000 * 60 * 30
  @current_total_supply_from_token_bridge_cache_key "coins_with_period"
  @current_market_cap_from_omni_bridge_cache_key "current_market_cap_from_omni_bridge"

  def market_cap(%{usd_value: usd_value}) when not is_nil(usd_value) do
    total_market_cap_from_token_bridge = token_bridge_market_cap(%{usd_value: usd_value})
    Decimal.add(total_market_cap_from_token_bridge, total_market_cap_from_omni_bridge())
  end

  def market_cap(_), do: Decimal.new(0)

  def token_bridge_market_cap(%{usd_value: usd_value}) when not is_nil(usd_value) do
    Decimal.mult(total_coins_from_token_bridge(), usd_value)
  end

  def token_bridge_market_cap(_), do: Decimal.new(0)

  def circulating, do: total_chain_supply()

  def total, do: total_chain_supply()

  def total_coins_from_token_bridge, do: total_token_bridge_supply()

  def total_market_cap_from_omni_bridge, do: total_omni_bridge_market_cap()

  def total_chain_supply do
    usd_value =
      case Source.fetch_exchange_rates(Source.CoinGecko) do
        {:ok, [rates]} ->
          rates.usd_value

        _ ->
          Decimal.new(1)
      end

    total_coins_from_omni_bridge = Decimal.div(total_market_cap_from_omni_bridge(), usd_value)
    Decimal.add(total_coins_from_token_bridge(), total_coins_from_omni_bridge)
  end

  def total_token_bridge_supply(opts \\ []) do
    cache_period = Keyword.get(opts, :cache_period) || @cache_period

    cached_total_coins_from_token_bridge(cache_period)
  end

  def total_omni_bridge_market_cap(opts \\ []) do
    cache_period = Keyword.get(opts, :cache_period) || @cache_period

    cached_total_omni_bridge_market_cap(cache_period)
  end

  defp burned_coins do
    address = System.get_env("TOKEN_BRIDGE_CONTRACT") || @token_bridge_contract_address

    call_contract(address, @total_burned_coins_abi, @total_burned_coins_params)
  end

  defp block_reward_contract do
    address = System.get_env("TOKEN_BRIDGE_CONTRACT") || @token_bridge_contract_address

    call_contract(address, @block_reward_contract_abi, @block_reward_contract_params)
  end

  defp minted_coins do
    address = block_reward_contract()

    call_contract(address, @total_minted_coins_abi, @total_minted_coins_params)
  end

  defp call_contract(address, abi, params) do
    abi = [abi]

    method_id =
      params
      |> Enum.map(fn {key, _value} -> key end)
      |> List.first()

    type =
      abi
      |> Enum.at(0)
      |> Map.get("outputs", [])
      |> Enum.at(0)
      |> Map.get("type", "")

    value =
      case Reader.query_contract(address, abi, params) do
        %{^method_id => {:ok, [result]}} ->
          result

        _ ->
          case type do
            "address" -> "0x0000000000000000000000000000000000000000"
            "uint256" -> 0
            _ -> 0
          end
      end

    case type do
      "address" ->
        "0x" <> Base.encode16(value)

      "uint256" ->
        %Wei{value: Decimal.new(value)}

      _ ->
        value
    end
  end

  defp get_current_total_supply_from_token_bridge do
    minted_coins()
    |> Wei.sub(burned_coins())
    |> Wei.to(:ether)
  end

  defp get_current_market_cap_from_omni_bridge do
    bridged_mainnet_tokens_list = get_bridged_mainnet_tokens_list()

    bridged_mainnet_tokens_with_supply =
      bridged_mainnet_tokens_list
      |> get_bridged_mainnet_tokens_supply()

    omni_bridge_market_cap = calc_omni_bridge_market_cap(bridged_mainnet_tokens_with_supply)

    omni_bridge_market_cap
  end

  defp get_current_price_for_bridged_token(symbol) when is_nil(symbol), do: nil

  defp get_current_price_for_bridged_token(symbol) do
    case Source.fetch_exchange_rates_for_token(symbol) do
      {:ok, [rates]} ->
        rates.usd_value

      _ ->
        nil
    end
  end

  defp get_bridged_mainnet_tokens_list do
    query =
      from(bt in BridgedToken,
        left_join: t in Token,
        on: t.contract_address_hash == bt.home_token_contract_address_hash,
        where: bt.foreign_chain_id == ^1,
        select: {bt.home_token_contract_address_hash, t.symbol}
      )

    query
    |> Repo.all()
  end

  defp get_bridged_mainnet_tokens_supply(bridged_mainnet_tokens_list) do
    bridged_mainnet_tokens_with_supply =
      bridged_mainnet_tokens_list
      |> Enum.map(fn {bridged_token_hash, bridged_token_symbol} ->
        bridged_token_price = cached_bridged_token_price(bridged_token_symbol, @cache_period)

        query =
          from(t in Token,
            where: t.contract_address_hash == ^bridged_token_hash,
            select: {t.total_supply, t.decimals}
          )

        bridged_token_balance =
          query
          |> Repo.one()

        bridged_token_balance_formatted =
          if bridged_token_balance do
            {bridged_token_balance_with_decimals, decimals} = bridged_token_balance

            decimals_multiplier =
              10
              |> :math.pow(Decimal.to_integer(decimals))
              |> Decimal.from_float()

            Decimal.div(bridged_token_balance_with_decimals, decimals_multiplier)
          else
            bridged_token_balance
          end

        {bridged_token_hash, bridged_token_price, bridged_token_balance_formatted}
      end)

    bridged_mainnet_tokens_with_supply
  end

  defp calc_omni_bridge_market_cap(bridged_mainnet_tokens_with_supply) do
    omni_bridge_market_cap =
      bridged_mainnet_tokens_with_supply
      |> Enum.reduce(Decimal.new(0), fn {_bridged_token_hash, bridged_token_price, bridged_token_balance}, acc ->
        if bridged_token_price do
          Decimal.add(acc, Decimal.mult(bridged_token_price, bridged_token_balance))
        else
          acc
        end
      end)

    omni_bridge_market_cap
  end

  def cached_total_coins_from_token_bridge(cache_period) do
    setup_cache()

    {value, cache_time} = cached_values(@current_total_supply_from_token_bridge_cache_key)

    if current_time() - cache_time > cache_period do
      {current_value, _} = update_total_supply_from_token_bridge_cache()
      current_value
    else
      value
    end
  end

  def cached_total_omni_bridge_market_cap(cache_period) do
    setup_cache()

    {value, cache_time} = cached_values(@current_market_cap_from_omni_bridge_cache_key)

    if current_time() - cache_time > cache_period do
      {current_value, _} = update_total_omni_bridge_market_cap_cache()
      current_value
    else
      value
    end
  end

  def cached_bridged_token_price(symbol, cache_period) do
    setup_cache()

    {value, cache_time} = cached_values("token_symbol_price_#{symbol}")

    if current_time() - cache_time > cache_period do
      {current_value, _} = update_bridged_token_price_cache(symbol)
      current_value
    else
      value
    end
  end

  defp cached_values(cache_key) do
    case :ets.lookup(@ets_table, cache_key) do
      [{^cache_key, {coins, time}}] ->
        {coins, time}

      _ ->
        update_cache(cache_key)
    end
  end

  defp update_cache(cache_key) do
    case cache_key do
      @current_total_supply_from_token_bridge_cache_key ->
        update_total_supply_from_token_bridge_cache()

      @current_market_cap_from_omni_bridge_cache_key ->
        update_total_omni_bridge_market_cap_cache()

      "token_symbol_price_" <> symbol ->
        update_bridged_token_price_cache(symbol)
    end
  end

  defp update_total_supply_from_token_bridge_cache do
    current_total_supply_from_token_bridge = get_current_total_supply_from_token_bridge()

    current_time = current_time()

    :ets.insert(
      @ets_table,
      {@current_total_supply_from_token_bridge_cache_key, {current_total_supply_from_token_bridge, current_time}}
    )

    {current_total_supply_from_token_bridge, current_time}
  end

  defp update_total_omni_bridge_market_cap_cache do
    current_total_supply_from_omni_bridge = get_current_market_cap_from_omni_bridge()

    current_time = current_time()

    :ets.insert(
      @ets_table,
      {@current_market_cap_from_omni_bridge_cache_key, {current_total_supply_from_omni_bridge, current_time}}
    )

    {current_total_supply_from_omni_bridge, current_time}
  end

  defp update_bridged_token_price_cache(symbol) do
    bridged_token_price = get_current_price_for_bridged_token(symbol)

    current_time = current_time()

    :ets.insert(
      @ets_table,
      {"token_symbol_price_#{symbol}", {bridged_token_price, current_time}}
    )

    {bridged_token_price, current_time}
  end

  defp setup_cache do
    if :ets.whereis(@ets_table) == :undefined do
      :ets.new(@ets_table, [
        :set,
        :named_table,
        :public,
        write_concurrency: true
      ])
    end
  end

  defp current_time do
    utc_now = DateTime.utc_now()

    DateTime.to_unix(utc_now, :millisecond)
  end
end
