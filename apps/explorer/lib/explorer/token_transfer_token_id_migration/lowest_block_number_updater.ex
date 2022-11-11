defmodule Explorer.TokenTransferTokenIdMigration.LowestBlockNumberUpdater do
  @moduledoc """
  Collects processed block numbers from token id migration workers
  and updates last_processed_block_number according to them.
  Full algorithm is in the 'Indexer.Fetcher.TokenTransferTokenIdMigration.Supervisor' module doc.
  """
  use GenServer

  alias Explorer.Utility.TokenTransferTokenIdMigratorProgress

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(_) do
    last_processed_block_number = TokenTransferTokenIdMigratorProgress.get_last_processed_block_number()

    {:ok, %{last_processed_block_number: last_processed_block_number, processed_ranges: []}}
  end

  def add_range(from, to) do
    GenServer.cast(__MODULE__, {:add_range, from..to})
  end

  @impl true
  def handle_cast({:add_range, range}, %{processed_ranges: processed_ranges} = state) do
    ranges =
      [range | processed_ranges]
      |> Enum.sort_by(& &1.last, &>=/2)
      |> normalize_ranges()

    {new_last_number, new_ranges} = maybe_update_last_processed_number(state.last_processed_block_number, ranges)

    {:noreply, %{last_processed_block_number: new_last_number, processed_ranges: new_ranges}}
  end

  defp normalize_ranges(ranges) do
    %{prev_range: prev, result: result} =
      Enum.reduce(ranges, %{prev_range: nil, result: []}, fn range, %{prev_range: prev_range, result: result} ->
        case {prev_range, range} do
          {nil, _} ->
            %{prev_range: range, result: result}

          {%{last: l1} = r1, %{first: f2} = r2} when l1 - 1 > f2 ->
            %{prev_range: r2, result: [r1 | result]}

          {%{first: f1}, %{last: l2}} ->
            %{prev_range: f1..l2, result: result}
        end
      end)

    Enum.reverse([prev | result])
  end

  # since ranges are normalized, we need to check only the first range to determine the new last_processed_number
  defp maybe_update_last_processed_number(current_last, [from..to | rest] = ranges) when current_last - 1 <= from do
    case TokenTransferTokenIdMigratorProgress.update_last_processed_block_number(to) do
      {:ok, _} -> {to, rest}
      _ -> {current_last, ranges}
    end
  end

  defp maybe_update_last_processed_number(current_last, ranges), do: {current_last, ranges}
end
