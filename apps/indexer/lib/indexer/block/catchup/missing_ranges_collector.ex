defmodule Indexer.Block.Catchup.MissingRangesCollector do
  @moduledoc """
  Collects missing block ranges.
  """

  use GenServer

  import Explorer.Helper, only: [parse_integer: 1]

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Cache.BlockNumber
  alias Explorer.Utility.MissingBlockRange
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
    {min_number, max_number} = get_initial_min_max()

    clear_to_bounds(min_number, max_number)

    Process.send_after(self(), :update_future, @future_check_interval)
    Process.send_after(self(), :update_past, @past_check_interval)

    %{min_fetched_block_number: min_number, max_fetched_block_number: max_number}
  end

  defp ranges_init(ranges, max_fetched_block_number \\ nil) do
    Repo.delete_all(MissingBlockRange)

    ranges
    |> Enum.reverse()
    |> Enum.flat_map(fn f..l -> Chain.missing_block_number_ranges(l..f) end)
    |> MissingBlockRange.save_batch()

    if not is_nil(max_fetched_block_number) do
      Process.send_after(self(), :update_future, @future_check_interval)
    end

    %{max_fetched_block_number: max_fetched_block_number}
  end

  defp clear_to_bounds(min_number, max_number) do
    first = first_block()
    last = last_block() - 1

    if min_number < first do
      first
      |> MissingBlockRange.from_number_below_query()
      |> Repo.delete_all()

      first
      |> MissingBlockRange.include_bound_query()
      |> Repo.one()
      |> case do
        nil ->
          :ok

        range ->
          range
          |> MissingBlockRange.changeset(%{to_number: first})
          |> Repo.update()
      end
    end

    if max_number > last do
      last
      |> MissingBlockRange.to_number_above_query()
      |> Repo.delete_all()

      last
      |> MissingBlockRange.include_bound_query()
      |> Repo.one()
      |> case do
        nil ->
          :ok

        range ->
          range
          |> MissingBlockRange.changeset(%{from_number: last})
          |> Repo.update()
      end
    end
  end

  defp get_initial_min_max do
    case MissingBlockRange.fetch_min_max() do
      %{min: nil, max: nil} ->
        max_number = last_block()
        {min_number, first_batch} = fetch_missing_ranges_batch(max_number, false)
        MissingBlockRange.save_batch(first_batch)
        {min_number, max_number}

      %{min: min, max: max} ->
        {min, max}
    end
  end

  @impl true
  def handle_info(:update_future, %{max_fetched_block_number: max_number} = state) do
    if continue_future_updating?(max_number) do
      {new_max_number, batch} = fetch_missing_ranges_batch(max_number, true)
      MissingBlockRange.save_batch(batch)
      Process.send_after(self(), :update_future, @future_check_interval)
      {:noreply, %{state | max_fetched_block_number: new_max_number}}
    else
      {:noreply, state}
    end
  end

  def handle_info(:update_past, %{min_fetched_block_number: min_number} = state) do
    if min_number > first_block() do
      {new_min_number, batch} = fetch_missing_ranges_batch(min_number, false)
      Process.send_after(self(), :update_past, @past_check_interval)
      MissingBlockRange.save_batch(batch)
      {:noreply, %{state | min_fetched_block_number: new_min_number}}
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
      _ -> fetch_max_block_number()
    end
  end

  defp fetch_max_block_number do
    case BlockNumber.get_max() do
      0 ->
        json_rpc_named_arguments = Application.get_env(:indexer, :json_rpc_named_arguments)
        {:ok, number} = EthereumJSONRPC.fetch_block_number_by_tag("latest", json_rpc_named_arguments)
        number

      number ->
        number
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
end
