defmodule Indexer.Migrator.RecoveryWETHTokenTransfers do
  @moduledoc """
  Recovers WETH token transfers that were accidentally deleted from the database by Explorer.Migrator.SanitizeIncorrectWETHTokenTransfers.
  This migration restores missing transfers by logs.
  """

  use GenServer, restart: :transient

  import Ecto.Query

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.{Log, TokenTransfer}
  alias Explorer.Migrator.MigrationStatus
  alias Indexer.Transform.TokenTransfers

  @migration_name "recovery_weth_token_transfers"

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(_) do
    {:ok, %{}, {:continue, :ok}}
  end

  @impl true
  def handle_continue(:ok, state) do
    case MigrationStatus.fetch(migration_name()) do
      %{status: "completed"} ->
        {:stop, :normal, state}

      migration_status ->
        state = (migration_status && migration_status.meta) || %{"block_number" => Chain.fetch_max_block_number()}

        if is_nil(migration_status) do
          MigrationStatus.set_status(migration_name(), "started")
          MigrationStatus.update_meta(@migration_name, state)
        end

        schedule_batch_migration(0)
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(:migrate_batch, state) do
    dbg(state)
    case last_unprocessed_identifiers(state)|>dbg() do
      [] ->
        if state["block_number"] == 0 do
          MigrationStatus.set_status(migration_name(), "completed")
          {:stop, :normal, state}
        else
          new_state = %{"block_number" => max(0, state["block_number"] - blocks_batch_size())}

          schedule_batch_migration()

          {:noreply, new_state}
        end

      identifiers ->
        last_transaction_hash = List.last(identifiers)

        identifiers
        |> Enum.uniq()
        |> Enum.chunk_every(batch_size())
        |> Enum.map(&run_task/1)
        |> Task.await_many(:infinity)

        new_state = Map.put(state, "transaction_hash", last_transaction_hash)
        MigrationStatus.update_meta(migration_name(), new_state)

        schedule_batch_migration()

        {:noreply, new_state}
    end
  end

  def migration_name, do: @migration_name

  def last_unprocessed_identifiers(state) do
    limit = batch_size() * concurrency()

    state["block_number"]
    |> unprocessed_data_query(state["transaction_hash"])
    |> limit(^limit)
    |> Repo.all(timeout: :infinity)
  end

  defp unprocessed_data_query(max_block_number, transaction_hash) do
    Log
    |> where(
      [log],
      log.first_topic in [^TokenTransfer.weth_deposit_signature(), ^TokenTransfer.weth_withdrawal_signature()]
    )
    |> apply_block_number_condition(max_block_number)
    |> apply_transaction_hash_condition(transaction_hash)
    |> group_by([log], [log.transaction_hash, log.address_hash, log.first_topic, log.second_topic])
    |> having([log], count(log) > 1)
    |> order_by([log], asc: log.transaction_hash)
    |> select([log], log.transaction_hash)
  end

  defp apply_block_number_condition(query, 0), do: query |> where([log], log.block_number == 0)

  defp apply_block_number_condition(query, max_block_number) do
    min_block_number = max(0, max_block_number - blocks_batch_size())

    query
    |> where([log], log.block_number <= ^max_block_number and log.block_number > ^min_block_number)
  end

  defp apply_transaction_hash_condition(query, nil), do: query

  defp apply_transaction_hash_condition(query, transaction_hash),
    do:
      query
      |> where([log], log.transaction_hash > ^transaction_hash)

  @spec run_task([any()]) :: any()
  defp run_task(batch), do: Task.async(fn -> update_batch(batch) end)

  def update_batch(batch) do
    %{token_transfers: token_transfers} =
      Log
      |> where([log], log.transaction_hash in ^batch)
      |> join(:left, [log], tt in TokenTransfer,
        on:
          log.transaction_hash == tt.transaction_hash and log.index == tt.log_index and log.block_hash == tt.block_hash
      )
      |> where([log, tt], is_nil(tt))
      |> where(
        [log],
        log.first_topic in [^TokenTransfer.weth_deposit_signature(), ^TokenTransfer.weth_withdrawal_signature()]
      )
      |> Repo.all(timeout: :infinity)|>dbg()
      |> Enum.map(fn log ->
        %Log{
          log
          | first_topic: to_string(log.first_topic),
            second_topic: to_string(log.second_topic),
            data: to_string(log.data)
        }
      end)
      |> TokenTransfers.parse(true)

    Chain.import(%{
      token_transfers: %{params: token_transfers},
      timeout: :infinity
    })
  end

  defp schedule_batch_migration(timeout \\ nil) do
    Process.send_after(self(), :migrate_batch, timeout || Application.get_env(:indexer, __MODULE__)[:timeout])
  end

  defp batch_size do
    Application.get_env(:indexer, __MODULE__)[:batch_size]
  end

  defp blocks_batch_size do
    Application.get_env(:indexer, __MODULE__)[:blocks_batch_size]
  end

  defp concurrency do
    Application.get_env(:indexer, __MODULE__)[:concurrency]
  end
end
