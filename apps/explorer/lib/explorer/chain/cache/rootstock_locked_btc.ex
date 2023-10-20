defmodule Explorer.Chain.Cache.RootstockLockedBTC do
  @moduledoc """
  Caches the number of BTC locked in 2WP on Rootstock chain.
  """

  require Logger
  alias Explorer.Chain
  alias Explorer.Chain.{Address, Wei}

  use Explorer.Chain.MapCache,
    name: :locked_rsk,
    key: :locked_value,
    global_ttl: Application.get_env(:explorer, __MODULE__)[:global_ttl],
    ttl_check_interval: :timer.seconds(1)

  defp handle_fallback(:locked_value) do
    rootstock_bridge_address_str = Application.get_env(:explorer, Explorer.Chain.Transaction)[:rootstock_bridge_address]
    rootstock_locking_cap = Application.get_env(:explorer, __MODULE__)[:locking_cap] |> Decimal.new()

    with {:ok, rootstock_bridge_address_hash} <- Chain.string_to_address_hash(rootstock_bridge_address_str),
         {:ok, %Address{fetched_coin_balance: balance}} when not is_nil(balance) <-
           Chain.hash_to_address(rootstock_bridge_address_hash) do
      {:update, rootstock_locking_cap |> Wei.from(:ether) |> Wei.sub(balance)}
    else
      _ ->
        {:return, nil}
    end
  end

  defp handle_fallback(_key), do: {:return, nil}
end
