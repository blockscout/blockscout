defmodule Explorer.Chain.BlockNumberCache do
  @moduledoc """
  Cache for max and min block numbers.
  """

  alias Explorer.Chain

  @tab :block_number_cache
  @key "min_max"

  @spec setup() :: :ok
  def setup do
    if :ets.whereis(@tab) == :undefined do
      :ets.new(@tab, [
        :set,
        :named_table,
        :public,
        write_concurrency: true
      ])
    end

    update_cache()

    :ok
  end

  def max_number do
    value(:max)
  end

  def min_number do
    value(:min)
  end

  def min_and_max_numbers do
    value(:all)
  end

  defp value(type) do
    {min, max} =
      if Application.get_env(:explorer, __MODULE__)[:enabled] do
        cached_values()
      else
        min_and_max_from_db()
      end

    case type do
      :max -> max
      :min -> min
      :all -> {min, max}
    end
  end

  @spec update(non_neg_integer()) :: boolean()
  def update(number) do
    {old_min, old_max} = cached_values()

    cond do
      number > old_max ->
        tuple = {old_min, number}
        :ets.insert(@tab, {@key, tuple})

      number < old_min ->
        tuple = {number, old_max}
        :ets.insert(@tab, {@key, tuple})

      true ->
        false
    end
  end

  defp update_cache do
    {min, max} = min_and_max_from_db()
    tuple = {min, max}

    :ets.insert(@tab, {@key, tuple})
  end

  defp cached_values do
    [{_, cached_values}] = :ets.lookup(@tab, @key)

    cached_values
  end

  defp min_and_max_from_db do
    Chain.fetch_min_and_max_block_numbers()
  rescue
    _e ->
      {0, 0}
  end
end
