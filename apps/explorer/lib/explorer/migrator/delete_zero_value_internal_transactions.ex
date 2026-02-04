defmodule Explorer.Migrator.DeleteZeroValueInternalTransactions do
  @moduledoc """
  Continuously deletes all zero-value calls older than
  `MIGRATION_DELETE_ZERO_VALUE_INTERNAL_TRANSACTIONS_STORAGE_PERIOD` from DB.
  """

  use GenServer

  import Ecto.Query
  import Explorer.QueryHelper, only: [select_ctid: 1, join_on_ctid: 2]

  alias Explorer.Chain.{Block, InternalTransaction}
  alias Explorer.Chain.Cache.Counters.AverageBlockTime
  alias Explorer.Migrator.MigrationStatus
  alias Explorer.Repo
  alias Explorer.Utility.{AddressIdToAddressHash, InternalTransactionsAddressPlaceholder}
  alias Timex.Duration

  @migration_name "delete_zero_value_internal_transactions"
  @shrink_internal_transactions_migration_name "shrink_internal_transactions"
  @not_completed_check_interval 10
  @default_check_interval :timer.minutes(1)
  @default_batch_size 100
  @default_storage_period :timer.hours(24) * 30

  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc """
  Returns the border block number. All internal transactions with zero value (and no contract creation) and
  block number less than or equal to the border number are subject to deletion.
  """
  @spec border_number() :: non_neg_integer() | nil
  def border_number, do: get_border_number()

  @impl true
  def init(_) do
    {:ok, %{}, {:continue, :ok}}
  end

  @impl true
  def handle_continue(:ok, state) do
    check_dependency_and_start(state)
  end

  @impl true
  def handle_info(:check_dependency, state) do
    check_dependency_and_start(state)
  end

  @impl true
  def handle_info(:update, %{"max_block_number" => max_number} = state) do
    border_number = get_border_number()
    to_number = border_number && min(max_number + batch_size(), border_number)
    clear_internal_transactions(max_number, to_number)
    completed? = not is_nil(border_number) and to_number == border_number
    new_max_number = (to_number && to_number + 1) || max_number

    new_state =
      if completed? and is_nil(state["completed"]) do
        MigrationStatus.set_status(@migration_name, "completed")
        Map.merge(state, %{"max_block_number" => new_max_number, "completed" => true})
      else
        %{state | "max_block_number" => new_max_number}
      end

    MigrationStatus.update_meta(@migration_name, new_state)
    schedule_check(completed? or is_nil(border_number))
    {:noreply, new_state}
  end

  defp check_dependency_and_start(state) do
    shrink_config = Application.get_env(:explorer, Explorer.Migrator.ShrinkInternalTransactions) || []
    shrink_enabled? = shrink_config[:enabled] != false
    shrink_status = MigrationStatus.get_status(@shrink_internal_transactions_migration_name)

    if shrink_enabled? && shrink_status != "completed" do
      schedule_dependency_check()
      {:noreply, state}
    else
      state =
        case MigrationStatus.fetch(@migration_name) do
          nil ->
            state = %{"max_block_number" => -1}
            MigrationStatus.set_status(@migration_name, "started")
            MigrationStatus.update_meta(@migration_name, state)
            state

          %{meta: meta} ->
            meta
        end

      schedule_check()
      {:noreply, state}
    end
  end

  defp clear_internal_transactions(from_number, to_number)
       when is_integer(from_number) and is_integer(to_number) and from_number < to_number do
    dynamic_condition = dynamic([it], it.block_number >= ^from_number and it.block_number <= ^to_number)

    do_clear_internal_transactions(dynamic_condition)
  end

  defp clear_internal_transactions(_from, _to), do: :ok

  @smallint_max_value 32767
  defp do_clear_internal_transactions(dynamic_condition) do
    Repo.transaction(
      fn ->
        condition = dynamic([it], ^dynamic_condition and it.type == ^:call and it.value == ^0)

        locked_internal_transactions_to_delete_query =
          from(
            it in InternalTransaction,
            select: select_ctid(it),
            where: ^condition,
            order_by: [asc: it.transaction_hash, asc: it.index],
            lock: "FOR UPDATE"
          )

        delete_query =
          from(
            it in InternalTransaction,
            inner_join: locked_it in subquery(locked_internal_transactions_to_delete_query),
            on: join_on_ctid(it, locked_it),
            select: %{
              from_address_hash: it.from_address_hash,
              to_address_hash: it.to_address_hash,
              block_number: it.block_number,
              index: it.index
            }
          )

        {_count, deleted_internal_transactions} = Repo.delete_all(delete_query, timeout: :infinity)

        address_hashes =
          deleted_internal_transactions
          |> Enum.flat_map(&[&1.from_address_hash, &1.to_address_hash])
          |> Enum.uniq()
          |> Enum.reject(&is_nil/1)

        id_to_address_params = Enum.map(address_hashes, &%{address_hash: &1})

        Repo.insert_all(AddressIdToAddressHash, id_to_address_params, on_conflict: :nothing)

        address_to_id_map =
          AddressIdToAddressHash
          |> where([a], a.address_hash in ^address_hashes)
          |> select([a], {a.address_hash, a.address_id})
          |> Repo.all()
          |> Map.new()

        placeholders_params =
          deleted_internal_transactions
          |> Enum.group_by(& &1.block_number)
          |> Enum.flat_map(fn {block_number, internal_transactions} ->
            internal_transactions
            |> Enum.reduce(%{}, fn
              %{index: 0}, inner_acc ->
                inner_acc

              internal_transaction, inner_acc ->
                from_address_hash = internal_transaction.from_address_hash
                to_address_hash = internal_transaction.to_address_hash

                inner_acc
                |> Map.update(
                  from_address_hash,
                  %{
                    address_id: address_to_id_map[from_address_hash],
                    block_number: block_number,
                    count_tos: 0,
                    count_froms: 1
                  },
                  fn existing_params ->
                    %{existing_params | count_froms: min(existing_params.count_froms + 1, @smallint_max_value)}
                  end
                )
                |> Map.update(
                  to_address_hash,
                  %{
                    address_id: address_to_id_map[to_address_hash],
                    block_number: block_number,
                    count_tos: 1,
                    count_froms: 0
                  },
                  # credo:disable-for-next-line Credo.Check.Refactor.Nesting
                  fn existing_params ->
                    %{existing_params | count_tos: min(existing_params.count_tos + 1, @smallint_max_value)}
                  end
                )
            end)
            |> Map.values()
            |> Enum.reject(&is_nil(&1.address_id))
          end)
          |> Enum.sort_by(&{&1.address_id, &1.block_number})

        placeholders_params
        |> Enum.chunk_every(1000)
        |> Enum.each(fn placeholders_batch ->
          Repo.insert_all(InternalTransactionsAddressPlaceholder, placeholders_batch,
            on_conflict: :replace_all,
            conflict_target: [:address_id, :block_number]
          )
        end)
      end,
      timeout: :infinity
    )
  end

  defp get_border_number do
    storage_period = Application.get_env(:explorer, __MODULE__)[:storage_period] || @default_storage_period
    border_timestamp = Timex.shift(Timex.now(), milliseconds: -storage_period)

    Block
    |> where([b], b.timestamp < ^border_timestamp)
    |> order_by([b], desc: b.timestamp)
    |> limit(1)
    |> select([b], b.number)
    |> Repo.one()
  end

  defp schedule_check(completed? \\ false) do
    Process.send_after(self(), :update, (completed? && completed_check_interval()) || @not_completed_check_interval)
  end

  defp schedule_dependency_check do
    interval = Application.get_env(:explorer, __MODULE__)[:dependency_check_interval] || :timer.hours(1)
    Process.send_after(self(), :check_dependency, interval)
  end

  defp completed_check_interval do
    with nil <- Application.get_env(:explorer, __MODULE__)[:check_interval],
         nil <- get_average_block_time() do
      @default_check_interval
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
