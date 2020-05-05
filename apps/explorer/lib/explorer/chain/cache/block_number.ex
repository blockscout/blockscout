defmodule Explorer.Chain.Cache.BlockNumber do
  @moduledoc """
  Cache for max and min block numbers.
  """

  @type value :: non_neg_integer()

  use Explorer.Chain.MapCache,
    name: :block_number,
    keys: [:min, :max],
    ttl_check_interval: Application.get_env(:explorer, __MODULE__)[:ttl_check_interval],
    global_ttl: Application.get_env(:explorer, __MODULE__)[:global_ttl]

  alias Explorer.Chain

  defp handle_update(_key, nil, value), do: {:ok, value}

  defp handle_update(:min, old_value, new_value), do: {:ok, min(new_value, old_value)}

  defp handle_update(:max, old_value, new_value), do: {:ok, max(new_value, old_value)}

  defp handle_fallback(key) do
    result = fetch_from_db(key)

    if Application.get_env(:explorer, __MODULE__)[:enabled] do
      {:update, result}
    else
      {:return, result}
    end
  end

  defp fetch_from_db(key) do
    case key do
      :min -> Chain.fetch_min_block_number()
      :max -> Chain.fetch_max_block_number()
    end
  rescue
    _e -> 0
  end
end
