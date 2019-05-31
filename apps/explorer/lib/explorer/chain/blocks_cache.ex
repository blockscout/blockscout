defmodule Explorer.Chain.BlocksCache do
  @moduledoc """
  Caches the last imported blocks
  """

  @block_numbers_key "block_numbers"
  @cache_name :blocks
  @number_of_elements 60

  def update(block) do
    numbers = block_numbers()

    max_number = if numbers == [], do: -1, else: Enum.max(numbers)

    if block.number > max_number do
      if Enum.count(numbers) >= @number_of_elements do
        remove_block(numbers)
        put_block(block, List.delete(numbers, Enum.min(numbers)))
      else
        put_block(block, numbers)
      end
    end
  end

  def blocks do
    numbers = block_numbers()

    numbers
    |> Enum.sort()
    |> Enum.map(fn number ->
      ConCache.get(@cache_name, number)
    end)
  end

  def cache_name, do: @cache_name

  def block_numbers do
    ConCache.get(@cache_name, @block_numbers_key) || []
  end

  defp remove_block(numbers) do
    min_number = Enum.min(numbers)
    ConCache.delete(@cache_name, min_number)
  end

  defp put_block(block, numbers) do
    ConCache.put(@cache_name, block.number, block)
    ConCache.put(@cache_name, @block_numbers_key, [block.number | numbers])
  end
end
