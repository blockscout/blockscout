defmodule Explorer.Chain.Cache.AddressSum do
  @moduledoc """
  Cache for address sum.
  """

  require Logger

  use Explorer.Chain.MapCache,
    name: :address_sum,
    key: :sum,
    key: :async_task,
    ttl_check_interval: Application.get_env(:explorer, __MODULE__)[:ttl_check_interval],
    global_ttl: Application.get_env(:explorer, __MODULE__)[:global_ttl]

  alias Explorer.Chain

  defp handle_fallback(:sum) do
    result = fetch_from_db()

    if Application.get_env(:explorer, __MODULE__)[:enabled] do
      {:update, result}
    else
      {:return, result}
    end
  end

  defp fetch_from_db do
    Chain.fetch_sum_coin_total_supply()
  end
end
