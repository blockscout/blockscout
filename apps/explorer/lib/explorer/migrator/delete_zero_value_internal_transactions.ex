defmodule Explorer.Migrator.DeleteZeroValueInternalTransactions do
  @moduledoc """
  Continuously deletes all zero-value calls older than
  `MIGRATION_DELETE_ZERO_VALUE_INTERNAL_TRANSACTIONS_STORAGE_PERIOD_DAYS` from DB.
  """

  use GenServer

  import Ecto.Query
  import Explorer.QueryHelper, only: [select_ctid: 1, join_on_ctid: 2]

  alias Explorer.Chain.{Block, InternalTransaction}
  alias Explorer.Chain.Cache.Counters.AverageBlockTime
  alias Explorer.Migrator.MigrationStatus
  alias Explorer.Repo
  alias Timex.Duration

  @migration_name "delete_zero_value_internal_transactions"
  @past_check_interval 10
  @default_future_check_interval :timer.minutes(1)
  @default_batch_size 100
  @default_storage_period_days 30

  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(_) do
    {:ok, %{}, {:continue, :ok}}
  end

  @impl true
  def handle_continue(:ok, _state) do
    state =
      case MigrationStatus.fetch(@migration_name) do
        nil ->
          border_number = get_border_number()
          state = %{"min_block_number" => border_number, "max_block_number" => border_number}
          MigrationStatus.set_status(@migration_name, "started")
          MigrationStatus.update_meta(@migration_name, state)
          state

        %{meta: meta} ->
          meta
      end

    schedule_future_check()
    schedule_past_check()

    {:noreply, state}
  end

  @impl true
  def handle_info(:update_future, %{"max_block_number" => max_number} = state) do
    border_number = get_border_number()
    to_number = min(max_number + batch_size(), border_number)
    clear_internal_transactions(max_number, to_number)
    new_state = %{state | "max_block_number" => to_number + 1}
    MigrationStatus.update_meta(@migration_name, new_state)
    schedule_future_check()
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:update_past, %{"min_block_number" => -1} = state) do
    new_state = Map.delete(state, "min_block_number")
    MigrationStatus.set_status(@migration_name, "completed")
    MigrationStatus.update_meta(@migration_name, new_state)
    {:noreply, new_state}
  end

  def handle_info(:update_past, %{"min_block_number" => min_number} = state) do
    from_number = max(min_number - batch_size(), 0)
    clear_internal_transactions(from_number, min_number)
    new_state = %{state | "min_block_number" => from_number - 1}
    MigrationStatus.update_meta(@migration_name, new_state)
    schedule_past_check()
    {:noreply, new_state}
  end

  def handle_info(:update_past, state) do
    {:noreply, state}
  end

  defp clear_internal_transactions(from_number, to_number) when from_number < to_number do
    Repo.transaction(fn ->
      locked_internal_transactions_to_delete_query =
        from(
          it in InternalTransaction,
          select: select_ctid(it),
          where: it.block_number >= ^from_number,
          where: it.block_number <= ^to_number,
          where: it.type == ^:call,
          where: it.value == ^0,
          order_by: [asc: it.transaction_hash, asc: it.index],
          lock: "FOR UPDATE"
        )

      delete_query =
        from(
          it in InternalTransaction,
          inner_join: locked_it in subquery(locked_internal_transactions_to_delete_query),
          on: join_on_ctid(it, locked_it)
        )

      Repo.delete_all(delete_query, timeout: :infinity)
    end)
  end

  defp clear_internal_transactions(_from, _to), do: :ok

  defp get_border_number do
    storage_period = Application.get_env(:explorer, __MODULE__)[:storage_period_days] || @default_storage_period_days
    border_timestamp = Timex.shift(Timex.now(), days: -storage_period)

    Block
    |> where([b], b.timestamp < ^border_timestamp)
    |> order_by([b], desc: b.timestamp)
    |> limit(1)
    |> select([b], b.number)
    |> Repo.one()
    |> Kernel.||(0)
  end

  defp schedule_past_check do
    Process.send_after(self(), :update_past, @past_check_interval)
  end

  defp schedule_future_check do
    Process.send_after(self(), :update_future, future_check_interval())
  end

  defp future_check_interval do
    with nil <- Application.get_env(:explorer, __MODULE__)[:future_check_interval],
         nil <- get_average_block_time() do
      @default_future_check_interval
    else
      interval -> interval
    end
  end

  defp get_average_block_time do
    case AverageBlockTime.average_block_time() do
      {:error, :disabled} -> nil
      average_block_time -> Duration.to_milliseconds(average_block_time)
    end
  end

  defp batch_size do
    max(Application.get_env(:explorer, __MODULE__)[:batch_size] || @default_batch_size, 1)
  end
end
