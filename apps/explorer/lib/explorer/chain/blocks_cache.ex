defmodule Explorer.Chain.BlocksCache do
  @moduledoc """
  Caches the last imported blocks
  """

  alias Explorer.Repo

  @block_numbers_key "block_numbers"
  @cache_name :blocks
  @number_of_elements 60

  def update(block) do
    numbers = block_numbers()

    max_number = if numbers == [], do: -1, else: Enum.max(numbers)
    min_number = if numbers == [], do: -1, else: Enum.min(numbers)

    in_range? = block.number > min_number && Enum.all?(numbers, fn number -> number != block.number end)
    not_too_far_away? = block.number > max_number - @number_of_elements - 1

    if (block.number > max_number || Enum.count(numbers) == 1 || in_range?) && not_too_far_away? do
      if Enum.count(numbers) >= @number_of_elements do
        remove_block(numbers)
        put_block(block, List.delete(numbers, Enum.min(numbers)))
      else
        put_block(block, numbers)
      end
    end
  end

  def rewrite_cache(elements) do
    numbers = block_numbers()

    ConCache.delete(@cache_name, @block_numbers_key)

    numbers
    |> Enum.each(fn number ->
      ConCache.delete(@cache_name, number)
    end)

    elements
    |> Enum.reduce([], fn element, acc ->
      put_block(element, acc)

      [element.number | acc]
    end)
  end

  def enough_elements?(number) do
    ConCache.size(@cache_name) > number
  end

  def update_blocks(blocks) do
    Enum.each(blocks, fn block ->
      update(block)
    end)
  end

  def blocks(number \\ nil) do
    numbers = block_numbers()

    number = if is_nil(number), do: Enum.count(numbers), else: number

    numbers
    |> Enum.sort()
    |> Enum.reverse()
    |> Enum.slice(0, number)
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
    block_with_preloads = Repo.preload(block, [:transactions, [miner: :names], :rewards])
    ConCache.put(@cache_name, block.number, block_with_preloads)
    ConCache.put(@cache_name, @block_numbers_key, [block.number | numbers])
  end
end
