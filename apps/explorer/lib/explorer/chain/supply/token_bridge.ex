defmodule Explorer.Chain.Supply.TokenBridge do
  @moduledoc """
  Defines the supply API for calculating the supply based on Token Bridge.
  """

  use Explorer.Chain.Supply

  require Logger

  import Ecto.Query,
    only: [
      from: 2
    ]

  alias Explorer.Chain.{BridgedToken, Token, Wei}
  alias Explorer.Chain.Cache.TokenExchangeRate, as: TokenExchangeRateCache
  alias Explorer.Counters.Bridge
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

  def market_cap(%{usd_value: usd_value}) when not is_nil(usd_value) do
    total_market_cap_from_token_bridge = token_bridge_market_cap(%{usd_value: usd_value})
    total_market_cap_from_omni = total_market_cap_from_omni_bridge()

    if total_market_cap_from_omni do
      Decimal.add(total_market_cap_from_token_bridge, total_market_cap_from_omni)
    else
      total_market_cap_from_token_bridge
    end
  end

  def market_cap(_) do
    total_market_cap_from_omni = total_market_cap_from_omni_bridge()

    if total_market_cap_from_omni do
      total_market_cap_from_omni
    else
      Decimal.new(0)
    end
  end

  def token_bridge_market_cap(%{usd_value: usd_value}) when not is_nil(usd_value) do
    total_coins_from_token_b = total_coins_from_token_bridge()

    if total_coins_from_token_b do
      Decimal.mult(total_coins_from_token_b, usd_value)
    else
      Decimal.new(0)
    end
  end

  def token_bridge_market_cap(_), do: Decimal.new(0)

  def circulating, do: total_chain_supply()

  def total, do: total_chain_supply()

  def total_coins_from_token_bridge, do: Bridge.fetch_token_bridge_total_supply()

  def total_market_cap_from_omni_bridge, do: Bridge.fetch_omni_bridge_market_cap()

  def total_chain_supply do
    usd_value =
      case Source.fetch_exchange_rates(Source.CoinGecko) do
        {:ok, [rates]} ->
          rates.usd_value

        _ ->
          Decimal.new(1)
      end

    total_coins_from_token_b = total_coins_from_token_bridge()
    total_market_cap_from_omni = total_market_cap_from_omni_bridge()

    if total_coins_from_token_b && total_market_cap_from_omni do
      total_coins_from_omni_bridge = Decimal.div(total_market_cap_from_omni, usd_value)
      Decimal.add(total_coins_from_token_b, total_coins_from_omni_bridge)
    else
      total_coins_from_token_b
    end
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
        value

      "uint256" ->
        %Wei{value: Decimal.new(value)}

      _ ->
        value
    end
  end

  def get_current_total_supply_from_token_bridge do
    minted_coins()
    |> Wei.sub(burned_coins())
    |> Wei.to(:ether)
  end

  def get_current_market_cap_from_omni_bridge do
    bridged_mainnet_tokens_list = get_bridged_mainnet_tokens_list()

    bridged_mainnet_tokens_with_supply =
      bridged_mainnet_tokens_list
      |> get_bridged_mainnet_tokens_supply()

    omni_bridge_market_cap = calc_omni_bridge_market_cap(bridged_mainnet_tokens_with_supply)

    omni_bridge_market_cap
  end

  def get_current_price_for_bridged_token(symbol) when is_nil(symbol), do: nil

  def get_current_price_for_bridged_token(symbol) do
    bridged_token_symbol_for_price_fetching = bridged_token_symbol_mapping_to_get_price(symbol)

    TokenExchangeRateCache.fetch(bridged_token_symbol_for_price_fetching)
  end

  def get_bridged_mainnet_tokens_list do
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
        bridged_token_price_from_cache = TokenExchangeRateCache.fetch(bridged_token_symbol)

        bridged_token_price =
          if bridged_token_price_from_cache && Decimal.cmp(bridged_token_price_from_cache, 0) == :gt do
            bridged_token_price_from_cache
          else
            TokenExchangeRateCache.fetch_token_exchange_rate(bridged_token_symbol)
          end

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
    Logger.warn("Show: calc_omni_bridge_market_cap")

    hopr_test_token_hash = "0x08675CCCb9338e6197C9cB5453d9e7DA143e2C5C" |> String.downcase()

    omni_bridge_market_cap =
      bridged_mainnet_tokens_with_supply
      |> Enum.filter(fn {bridged_token_hash, _, _} ->
        bridged_token_hash_str = "0x" <> Base.encode16(bridged_token_hash.bytes, case: :lower)
        bridged_token_hash_str !== hopr_test_token_hash
      end)
      |> Enum.reduce(Decimal.new(0), fn {bridged_token_hash, bridged_token_price, bridged_token_balance}, acc ->
        if bridged_token_price do
          Logger.warn("Show: bridged_token_hash")
          Logger.warn("0x" <> Base.encode16(bridged_token_hash.bytes))
          Logger.warn("Show: bridged_token_price")
          Logger.warn(bridged_token_price |> Decimal.to_float() |> :erlang.float_to_binary(decimals: 2))
          Logger.warn("Show: bridged_token_balance")
          Logger.warn(bridged_token_balance |> Decimal.to_float() |> :erlang.float_to_binary(decimals: 2))

          bridged_token_cap = Decimal.mult(bridged_token_price, bridged_token_balance)
          Logger.warn("Show: bridged_token_cap")
          Logger.warn(bridged_token_cap |> Decimal.to_float() |> :erlang.float_to_binary(decimals: 2))

          Logger.warn("Show: current accumulator (before adding)")
          Logger.warn(acc |> Decimal.to_float() |> :erlang.float_to_binary(decimals: 2))
          Decimal.add(acc, bridged_token_cap)
        else
          acc
        end
      end)

    Logger.warn("Show: omni_bridge_market_cap")
    Logger.warn(omni_bridge_market_cap |> Decimal.to_float() |> :erlang.float_to_binary(decimals: 2))

    omni_bridge_market_cap
  end

  defp bridged_token_symbol_mapping_to_get_price(symbol) do
    case symbol do
      "POA20" -> "POA"
      "yDAI+yUSDC+yUSDT+yTUSD" -> "yCurve"
      symbol -> symbol
    end
  end
end
