defmodule Indexer.Fetcher.Arbitrum.Utils.Logging do
  @moduledoc """
    Common logging functions for Indexer.Fetcher.Arbitrum fetchers
  """
  require Logger

  @doc """
    A helper function to log a message with debug severity. Uses `Logger.debug` facility.

    ## Parameters
    - `msg`: a message to log

    ## Returns
    `:ok`
  """
  @spec log_debug(any()) :: :ok
  def log_debug(msg) do
    Logger.debug(msg)
  end

  @doc """
    A helper function to log a message with warning severity. Uses `Logger.warning` facility.

    ## Parameters
    - `msg`: a message to log

    ## Returns
    `:ok`
  """
  @spec log_warning(any()) :: :ok
  def log_warning(msg) do
    Logger.warning(msg)
  end

  @doc """
    A helper function to log a message with info severity. Uses `Logger.info` facility.

    ## Parameters
    - `msg`: a message to log

    ## Returns
    `:ok`
  """
  @spec log_info(any()) :: :ok
  def log_info(msg) do
    Logger.info(msg)
  end

  @doc """
    A helper function to log a message with error severity. Uses `Logger.error` facility.

    ## Parameters
    - `msg`: a message to log

    ## Returns
    `:ok`
  """
  @spec log_error(any()) :: :ok
  def log_error(msg) do
    Logger.error(msg)
  end

  @doc """
    A helper function to log progress when handling data items in chunks.

    ## Parameters
    - `prefix`: A prefix for the logging message.
    - `data_items_names`: A tuple with singular and plural of data items names
    - `chunk`: A list of data items numbers in the current chunk.
    - `current_progress`: The total number of data items handled up to this moment.
    - `total`: The total number of data items across all chunks.

    ## Returns
    `:ok`

    ## Examples:
    - `log_details_chunk_handling("A message", {"batch", "batches"}, [1, 2, 3], 0, 10)` produces
      `A message for batches 1..3. Progress 30%`
    - `log_details_chunk_handling("A message", {"batch", "batches"}, [2], 1, 10)` produces
      `A message for batch 2. Progress 20%`
    - `log_details_chunk_handling("A message", {"block", "blocks"}, [35], 0, 1)` produces
      `A message for block 35.`
    - `log_details_chunk_handling("A message", {"block", "blocks"}, [45, 50, 51, 52, 60], 1, 1)` produces
      `A message for blocks 45, 50..52, 60.`
  """
  @spec log_details_chunk_handling(binary(), tuple(), list(), non_neg_integer(), non_neg_integer()) :: :ok
  def log_details_chunk_handling(prefix, data_items_names, chunk, current_progress, total)
      # credo:disable-for-previous-line Credo.Check.Refactor.CyclomaticComplexity
      when is_binary(prefix) and is_tuple(data_items_names) and is_list(chunk) and
             (is_integer(current_progress) and current_progress >= 0) and
             (is_integer(total) and total > 0) do
    chunk_length = length(chunk)

    progress =
      case chunk_length == total do
        true ->
          ""

        false ->
          percentage =
            (current_progress + chunk_length)
            |> Decimal.div(total)
            |> Decimal.mult(100)
            |> Decimal.round(2)
            |> Decimal.to_string()

          " Progress: #{percentage}%"
      end

    if chunk_length == 1 do
      log_debug("#{prefix} for #{elem(data_items_names, 0)} ##{Enum.at(chunk, 0)}.")
    else
      log_debug(
        "#{prefix} for #{elem(data_items_names, 1)} #{Enum.join(shorten_numbers_list(chunk), ", ")}.#{progress}"
      )
    end
  end

  # Transform list of numbers to the list of string where consequent values
  # are combined to be displayed as a range.
  #
  # ## Parameters
  # - `msg`: a message to log
  #
  # ## Returns
  # `shorten_list` - resulting list after folding
  #
  # ## Examples:
  # [1, 2, 3] => ["1..3"]
  # [1, 3] => ["1", "3"]
  # [1, 2] => ["1..2"]
  # [1, 3, 4, 5] => ["1", "3..5"]
  defp shorten_numbers_list(numbers_list) do
    {shorten_list, _, _} =
      numbers_list
      |> Enum.sort()
      |> Enum.reduce({[], nil, nil}, fn number, {shorten_list, prev_range_start, prev_number} ->
        shorten_numbers_list_impl(number, shorten_list, prev_range_start, prev_number)
      end)
      |> then(fn {shorten_list, prev_range_start, prev_number} ->
        shorten_numbers_list_impl(prev_number, shorten_list, prev_range_start, prev_number)
      end)

    Enum.reverse(shorten_list)
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
end
