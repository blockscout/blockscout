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
  alias Explorer.Chain.Cache.TokenExchangeRate, as: TokenExchangeRateCache
  alias Explorer.Counters.Bridge
  alias Explorer.ExchangeRates.Source
  alias Explorer.{CustomContractsHelpers, Repo}
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

    if Decimal.cmp(total_market_cap_from_omni, 0) == :gt do
      Decimal.add(total_market_cap_from_token_bridge, total_market_cap_from_omni)
    else
      total_market_cap_from_token_bridge
    end
  end

  def market_cap(_) do
    Decimal.new(0)
  end

  def token_bridge_market_cap(%{usd_value: usd_value}) when not is_nil(usd_value) do
    total_coins_from_token_bridge = get_total_coins_from_token_bridge()

    if total_coins_from_token_bridge do
      Decimal.mult(total_coins_from_token_bridge, usd_value)
    else
      Decimal.new(0)
    end
  end

  def token_bridge_market_cap(_), do: Decimal.new(0)

  def circulating, do: total_chain_supply()

  def total, do: total_chain_supply()

  def get_total_coins_from_token_bridge, do: Bridge.fetch_token_bridge_total_supply()

  def total_market_cap_from_omni_bridge, do: Bridge.fetch_omni_bridge_market_cap()

  def total_chain_supply do
    usd_value =
      case Source.fetch_exchange_rates(Source.CoinGecko) do
        {:ok, [rates]} ->
          rates.usd_value

        _ ->
          Decimal.new(1)
      end

    total_coins_from_token_bridge = get_total_coins_from_token_bridge()
    total_market_cap_from_omni = total_market_cap_from_omni_bridge()

    if Decimal.cmp(total_coins_from_token_bridge, 0) == :gt && Decimal.cmp(total_market_cap_from_omni, 0) == :gt do
      total_coins_from_omni_bridge = Decimal.div(total_market_cap_from_omni, usd_value)
      Decimal.add(total_coins_from_token_bridge, total_coins_from_omni_bridge)
    else
      total_coins_from_token_bridge
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
      case Reader.query_contract(address, abi, params, false) do
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

  def get_current_price_for_bridged_token(_token_hash, foreign_token_contract_address_hash)
      when is_nil(foreign_token_contract_address_hash),
      do: nil

  def get_current_price_for_bridged_token(token_hash, _foreign_token_contract_address_hash) when is_nil(token_hash),
    do: nil

  def get_current_price_for_bridged_token(token_hash, foreign_token_contract_address_hash) do
    foreign_token_contract_address_hash_str =
      "0x" <> Base.encode16(foreign_token_contract_address_hash.bytes, case: :lower)

    TokenExchangeRateCache.fetch(token_hash, foreign_token_contract_address_hash_str)
  end

  def get_bridged_mainnet_tokens_list do
    query =
      from(bt in BridgedToken,
        left_join: t in Token,
        on: t.contract_address_hash == bt.home_token_contract_address_hash,
        where: bt.foreign_chain_id == ^1,
        where: t.bridged == true,
        select: {bt.home_token_contract_address_hash, t.symbol, bt.custom_cap, bt.foreign_token_contract_address_hash},
        order_by: [desc: t.holder_count]
      )

    query
    |> Repo.all()
  end

  defp get_bridged_mainnet_tokens_supply(bridged_mainnet_tokens_list) do
    bridged_mainnet_tokens_with_supply =
      bridged_mainnet_tokens_list
      |> Enum.map(fn {bridged_token_hash, _bridged_token_symbol, bridged_token_custom_cap,
                      foreign_token_contract_address_hash} ->
        if bridged_token_custom_cap do
          {bridged_token_hash, Decimal.new(0), Decimal.new(0), bridged_token_custom_cap}
        else
          bridged_token_price_from_cache =
            TokenExchangeRateCache.fetch(bridged_token_hash, foreign_token_contract_address_hash)

          bridged_token_price =
            if bridged_token_price_from_cache && Decimal.cmp(bridged_token_price_from_cache, 0) == :gt do
              bridged_token_price_from_cache
            else
              TokenExchangeRateCache.fetch_token_exchange_rate_by_address(foreign_token_contract_address_hash)
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

          {bridged_token_hash, bridged_token_price, bridged_token_balance_formatted, nil}
        end
      end)

    bridged_mainnet_tokens_with_supply
  end

  defp calc_omni_bridge_market_cap(bridged_mainnet_tokens_with_supply) do
    test_token_addresses = CustomContractsHelpers.get_custom_addresses_list(:test_tokens_addresses)

    config = Application.get_env(:explorer, Explorer.Counters.Bridge)
    disable_lp_tokens_in_market_cap = Keyword.get(config, :disable_lp_tokens_in_market_cap)

    omni_bridge_market_cap =
      bridged_mainnet_tokens_with_supply
      |> Enum.filter(fn {bridged_token_hash, _, _, _} ->
        bridged_token_hash_str = "0x" <> Base.encode16(bridged_token_hash.bytes, case: :lower)
        !Enum.member?(test_token_addresses, bridged_token_hash_str)
      end)
      |> Enum.reduce(Decimal.new(0), fn {_bridged_token_hash, bridged_token_price, bridged_token_balance,
                                         bridged_token_custom_cap},
                                        acc ->
        if !disable_lp_tokens_in_market_cap && bridged_token_custom_cap do
          Decimal.add(acc, bridged_token_custom_cap)
        else
          if bridged_token_price do
            bridged_token_cap = Decimal.mult(bridged_token_price, bridged_token_balance)
            Decimal.add(acc, bridged_token_cap)
          else
            acc
          end
        end
      end)

    omni_bridge_market_cap
  end
end
