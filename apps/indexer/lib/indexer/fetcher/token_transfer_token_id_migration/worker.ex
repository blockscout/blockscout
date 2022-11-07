defmodule Indexer.Fetcher.TokenTransferTokenIdMigration.Worker do
  use GenServer

  import Ecto.Query

  alias Explorer.Chain.TokenTransfer
  alias Explorer.Repo
  alias Indexer.Fetcher.TokenTransferTokenIdMigration.LowestBlockNumberUpdater

  @default_batch_size 500
  @interval 10

  def start_link(idx: idx, first_block: first, last_block: last, step: step, name: name) do
    GenServer.start_link(__MODULE__, %{idx: idx, bottom_block: first, last_block: last, step: step}, name: name)
  end

  @impl true
  def init(%{idx: idx, bottom_block: bottom_block, last_block: last_block, step: step}) do
    batch_size = Application.get_env(:indexer, :token_id_migration)[:batch_size] || @default_batch_size
    range = calculate_new_range(last_block, bottom_block, batch_size, idx - 1)

    schedule_next_update()

    {:ok, %{batch_size: batch_size, bottom_block: bottom_block, step: step, current_range: range}}
  end

  @impl true
  def handle_info(:update, %{current_range: :out_of_bound} = state) do
    {:stop, :normal, state}
  end

  @impl true
  def handle_info(:update, %{current_range: {lower_bound, upper_bound}} = state) do
    case do_update(lower_bound, upper_bound) do
      {_total, _result} ->
        LowestBlockNumberUpdater.add_range(upper_bound, lower_bound)
        new_range = calculate_new_range(lower_bound, state.bottom_block, state.batch_size, state.step)
        schedule_next_update()
        {:noreply, %{state | current_range: new_range}}

      _ ->
        schedule_next_update()
        {:noreply, state}
    end
  end

  defp calculate_new_range(last_processed_block, bottom_block, batch_size, step) do
    upper_bound = last_processed_block - step * batch_size - 1
    lower_bound = max(upper_bound - batch_size + 1, bottom_block)

    if upper_bound >= bottom_block do
      {lower_bound, upper_bound}
    else
      :out_of_bound
    end
  end

  defp do_update(lower_bound, upper_bound) do
    query =
      from(
        tt in TokenTransfer,
        where: tt.block_number >= ^lower_bound,
        where: tt.block_number <= ^upper_bound,
        where: not is_nil(tt.token_id),
        update: [
          set: [
            token_ids: fragment("ARRAY_APPEND(ARRAY[]::decimal[], ?)", tt.token_id),
            token_id: nil
          ]
        ]
      )

    Repo.update_all(query, [], timeout: :infinity)
  end

  defp schedule_next_update do
    Process.send_after(self(), :update, @interval)
  end
end
