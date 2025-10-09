defmodule Explorer.Chain.Cache.LatestL1BlockNumber do
  @moduledoc """
    Caches latest L1 block number.
  """

  use Explorer.Chain.MapCache,
    name: :latest_l1_block_number,
    key: :block_number,
    ttl_check_interval: :timer.seconds(5),
    global_ttl: :timer.seconds(15)

  @dialyzer :no_match

  defp handle_fallback(_key), do: {:return, nil}
end
