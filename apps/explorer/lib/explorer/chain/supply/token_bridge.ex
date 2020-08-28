defmodule Explorer.Chain.Supply.TokenBridge do
  @moduledoc """
  Defines the supply API for calculating the supply based on Token Bridge.
  """

  use Explorer.Chain.Supply

  alias Explorer.Chain.Wei
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
  @cache_key "coins_with_period"

  def circulating, do: total_coins()

  def total, do: total_coins()

  def total_coins(opts \\ []) do
    cache_period = Keyword.get(opts, :cache_period) || @cache_period

    cached_total_coins(cache_period)
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

  def cached_total_coins(cache_period) do
    setup_cache()

    {value, cache_time} = cached_values()

    if current_time() - cache_time > cache_period do
      {current_value, _} = update_cache()
      current_value
    else
      value
    end
  end

  defp cached_values do
    cache_key = @cache_key

    case :ets.lookup(@ets_table, @cache_key) do
      [{^cache_key, {coins, time}}] ->
        {coins, time}

      _ ->
        update_cache()
    end
  end

  defp update_cache do
    current_total_coins =
      minted_coins()
      |> Wei.sub(burned_coins())
      |> Wei.to(:ether)

    current_time = current_time()

    :ets.insert(@ets_table, {@cache_key, {current_total_coins, current_time}})

    {current_total_coins, current_time}
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
