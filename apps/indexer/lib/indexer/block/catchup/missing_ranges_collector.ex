defmodule Indexer.Block.Catchup.MissingRangesCollector do
  @moduledoc """
  Collects missing block ranges.
  """

  use GenServer

  alias Explorer.Chain
  alias Explorer.Chain.Cache.BlockNumber
  alias Indexer.Block.Catchup.Helper

  @default_missing_ranges_batch_size 100_000
  @future_check_interval Application.compile_env(:indexer, __MODULE__)[:future_check_interval]
  @past_check_interval 10

  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(_) do
    {:ok, define_init()}
  end

  defp define_init do
    case Application.get_env(:indexer, :block_ranges) do
      nil ->
        default_init()

      string_ranges ->
        case parse_block_ranges(string_ranges) do
          :no_ranges -> default_init()
          {:finite_ranges, ranges} -> ranges_init(ranges)
          {:infinite_ranges, ranges, max_fetched_block_number} -> ranges_init(ranges, max_fetched_block_number)
        end
    end
  end

  defp default_init do
    max_number = last_block()
    {min_number, first_batch} = fetch_missing_ranges_batch(max_number, false)
    initial_queue = push_batch_to_queue(first_batch, :queue.new())

    Process.send_after(self(), :update_future, @future_check_interval)
    Process.send_after(self(), :update_past, @past_check_interval)

    %{queue: initial_queue, min_fetched_block_number: min_number, max_fetched_block_number: max_number}
  end

  defp ranges_init(ranges, max_fetched_block_number \\ nil) do
    missing_ranges =
      ranges
      |> Enum.reverse()
      |> Enum.flat_map(fn f..l -> Chain.missing_block_number_ranges(l..f) end)

    initial_queue = push_batch_to_queue(missing_ranges, :queue.new())

    if not is_nil(max_fetched_block_number) do
      Process.send_after(self(), :update_future, @future_check_interval)
    end

    %{queue: initial_queue, max_fetched_block_number: max_fetched_block_number}
  end

  def get_latest_batch do
    GenServer.call(__MODULE__, :get_latest_batch)
  end

  @impl true
  def handle_call(:get_latest_batch, _from, %{queue: queue} = state) do
    {latest_batch, new_queue} =
      case :queue.out(queue) do
        {{:value, batch}, rest} -> {batch, rest}
        {:empty, rest} -> {[], rest}
      end

    {:reply, latest_batch, %{state | queue: new_queue}}
  end

  @impl true
  def handle_info(:update_future, %{queue: queue, max_fetched_block_number: max_number} = state) do
    if continue_future_updating?(max_number) do
      {new_max_number, batch} = fetch_missing_ranges_batch(max_number, true)
      Process.send_after(self(), :update_future, @future_check_interval)
      {:noreply, %{state | queue: push_batch_to_queue(batch, queue, true), max_fetched_block_number: new_max_number}}
    else
      {:noreply, state}
    end
  end

  def handle_info(:update_past, %{queue: queue, min_fetched_block_number: min_number} = state) do
    if min_number > first_block() do
      {new_min_number, batch} = fetch_missing_ranges_batch(min_number, false)
      Process.send_after(self(), :update_past, @past_check_interval)
      {:noreply, %{state | queue: push_batch_to_queue(batch, queue), min_fetched_block_number: new_min_number}}
    else
      {:noreply, state}
    end
  end

  defp fetch_missing_ranges_batch(min_fetched_block_number, false = _to_future?) do
    from = min_fetched_block_number - 1
    to = max(min_fetched_block_number - missing_ranges_batch_size(), first_block())

    if from >= to do
      {to, Chain.missing_block_number_ranges(from..to)}
    else
      {min_fetched_block_number, []}
    end
  end

  defp fetch_missing_ranges_batch(max_fetched_block_number, true) do
    to = max_fetched_block_number + 1
    from = min(max_fetched_block_number + missing_ranges_batch_size(), last_block() - 1)

    if from >= to do
      {from, Chain.missing_block_number_ranges(from..to)}
    else
      {max_fetched_block_number, []}
    end
  end

  defp push_batch_to_queue(batch, queue, r? \\ false)
  defp push_batch_to_queue([], queue, _r?), do: queue
  defp push_batch_to_queue(batch, queue, false), do: :queue.in(batch, queue)
  defp push_batch_to_queue(batch, queue, true), do: :queue.in_r(batch, queue)

  defp first_block do
    string_value = Application.get_env(:indexer, :first_block)

    case Integer.parse(string_value) do
      {integer, ""} ->
        integer

      _ ->
        min_missing_block_number =
          "min_missing_block_number"
          |> Chain.get_last_fetched_counter()
          |> Decimal.to_integer()

        min_missing_block_number
    end
  end

  defp last_block do
    case Integer.parse(Application.get_env(:indexer, :last_block)) do
      {block, ""} -> block + 1
      _ -> BlockNumber.get_max()
    end
  end

  defp continue_future_updating?(max_fetched_block_number) do
    case Integer.parse(Application.get_env(:indexer, :last_block)) do
      {block, ""} -> max_fetched_block_number < block
      _ -> true
    end
  end

  defp missing_ranges_batch_size do
    Application.get_env(:indexer, :missing_ranges_batch_size) || @default_missing_ranges_batch_size
  end

  def parse_block_ranges(block_ranges_string) do
    ranges =
      block_ranges_string
      |> String.split(",")
      |> Enum.map(fn string_range ->
        case String.split(string_range, "..") do
          [from_string, "latest"] ->
            parse_integer(from_string)

          [from_string, to_string] ->
            with {from, ""} <- Integer.parse(from_string),
                 {to, ""} <- Integer.parse(to_string) do
              if from <= to, do: from..to, else: nil
            else
              _ -> nil
            end

          _ ->
            nil
        end
      end)
      |> Helper.sanitize_ranges()

    case List.last(ranges) do
      _from.._to ->
        {:finite_ranges, ranges}

      nil ->
        :no_ranges

      num ->
        {:infinite_ranges, List.delete_at(ranges, -1), num - 1}
    end
  end

  defp parse_integer(integer_string) do
    case Integer.parse(integer_string) do
      {integer, ""} -> integer
      _ -> nil
    end
  end
end
