defmodule Indexer.Fetcher.ZkSync.Utils.Logging do
  @moduledoc """
    Common logging functions for Indexer.Fetcher.ZkSync fetchers
  """
  require Logger

  def log_warning(msg) do
    Logger.warning(msg)
  end

  def log_info(msg) do
    Logger.notice(msg)
  end

  def log_error(msg) do
    Logger.error(msg)
  end

  def log_details_chunk_handling(prefix, chunk, current_progress, total) do
    chunk_length = length(chunk)

    progress =
      case chunk_length == total do
        true ->
          ""

        false ->
          percentage =
            Decimal.div(current_progress + chunk_length, total)
            |> Decimal.mult(100)
            |> Decimal.round(2)
            |> Decimal.to_string()

          " Progress: #{percentage}%"
      end

    if chunk_length == 1 do
      log_info("#{prefix} for batch ##{Enum.at(chunk, 0)}")
    else
      log_info("#{prefix} for batches #{Enum.join(shorten_numbers_list(chunk), ", ")}.#{progress}")
    end
  end

  defp shorten_numbers_list_impl(number, shorten_list, prev_range_start, prev_number) do
    cond do
      is_nil(prev_number) ->
        {[], number, number}

      prev_number + 1 != number and prev_range_start == prev_number ->
        {["#{prev_range_start}" | shorten_list], number, number}

      prev_number + 1 != number ->
        {["#{prev_range_start}..#{prev_number}" | shorten_list], number, number}

      true ->
        {shorten_list, prev_range_start, number}
    end
  end

  defp shorten_numbers_list(numbers_list) do
    {shorten_list, _, _} =
      Enum.sort(numbers_list)
      |> Enum.reduce({[], nil, nil}, fn number, {shorten_list, prev_range_start, prev_number} ->
        shorten_numbers_list_impl(number, shorten_list, prev_range_start, prev_number)
      end)
      |> then(fn {shorten_list, prev_range_start, prev_number} ->
        shorten_numbers_list_impl(prev_number, shorten_list, prev_range_start, prev_number)
      end)

    Enum.reverse(shorten_list)
  end
end
