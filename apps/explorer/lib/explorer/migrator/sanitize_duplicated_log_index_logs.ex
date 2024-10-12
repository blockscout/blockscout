defmodule Explorer.Migrator.SanitizeDuplicatedLogIndexLogs do
  # remember last block processed
  # run iff chain_type is zkevm and rsk

  use Explorer.Migrator.FillingMigration

  import Ecto.Query

  alias Explorer.Chain.Log
  alias Explorer.Chain.Transaction
  alias Explorer.Chain.Token.Instance
  alias Explorer.Migrator.FillingMigration
  alias Explorer.Repo
  require Logger

  @migration_name "sanitize_duplicated_log_index_logs"

  @impl FillingMigration
  def migration_name, do: @migration_name

  @impl FillingMigration
  def last_unprocessed_identifiers(state) do
    block_number = state[:block_number_to_process] || 0

    limit = batch_size() * concurrency()

    ids =
      unprocessed_data_query(block_number, block_number + limit)
      |> Repo.all(timeout: :infinity)
      |> Enum.group_by(& &1.block_hash)

    {ids, Map.put(state, :block_number_to_process, block_number + limit)}
  end

  def unprocessed_data_query(block_number_start, block_number_end) do
    Log
    |> where([l], l.block_number >= ^block_number_start and l.block_number < ^block_number_end)
  end

  @impl FillingMigration
  def update_batch(logs_by_block) do
    logs_to_update =
      logs_by_block
      |> Enum.map(&process_block/1)
      |> Enum.reject(&(&1 == :ignore))
      |> List.flatten()

    {ids, logs, ids_to_new_index} =
      logs_to_update
      |> Enum.reduce({[], [], %{}}, fn {log, new_index}, {ids, logs, ids_to_new_index} ->
        id = {log.transaction_hash, log.block_hash, log.index}
        {[id | ids], [%Log{log | index: new_index} | logs], Map.put(ids_to_new_index, id, new_index)}
      end)

    Repo.transaction(fn ->
      Log
      |> where([log], {log.transaction_hash, log.block_hash, log.index} in ^ids)
      |> Repo.delete_all(timeout: :infinity)

      token_transfers =
        TokenTransfer
        |> where(
          [token_transfer],
          {token_transfer.transaction_hash, token_transfer.block_hash, token_transfer.index} in ^ids
        )
        |> select([token_transfer], token_transfer)
        |> Repo.delete_all(timeout: :infinity)

      Repo.insert_all(Log, logs, timeout: :infinity)

      token_transfers
      |> Enum.map(fn token_transfer ->
        id = token_transfer_to_index(token_transfer)
        %TokenTransfer{token_transfer | log_index: ids_to_new_index[id]}
      end)
      |> Repo.insert_all(TokenTransfer, timeout: :infinity)

      nft_instances_params =
        logs
        |> Enum.map(fn log -> {log.block_number, log.index} end)

      nft_updates_map =
        Enum.reduce(token_transfers, %{}, fn token_transfer, acc ->
          if token_transfer.consensus == true do
            id = token_transfer_to_index(token_transfer)
            Map.put(acc, {token_transfer.block_number, token_transfer.log_index}, ids_to_new_index[id])
          else
            acc
          end
        end)

      Instance
      |> where([nft], {nft.owner_updated_at_block, nft.owner_updated_at_log_index} in ^nft_instances_params)
      |> Repo.all(timeout: :infinity)
      |> Enum.map(fn nft ->
        %Instance{
          nft
          | owner_updated_at_log_index: nft_updates_map[{nft.owner_updated_at_block, nft.owner_updated_at_log_index}]
        }
      end)
      |> Repo.insert_all(on_conflict: {:replace, [:owner_updated_at_log_index]}, timeout: :infinity)
    end)
  end

  defp process_block({block_hash, logs}) do
    if logs |> Enum.frequencies_by(& &1.index) |> Map.values() |> Enum.max() == 1 do
      :ignore
    else
      Logger.error("Found logs with same index within one block: #{block_hash} in DB")

      logs = Repo.preload(logs, :transaction)

      logs
      |> Enum.sort_by(&{&1.transaction.index, &1.index, &1.transaction_hash})
      # credo:disable-for-next-line Credo.Check.Refactor.Nesting
      |> Enum.map_reduce(0, fn log, index ->
        {{log, index}, index + 1}
      end)
      |> elem(0)
    end
  end

  @impl FillingMigration
  def update_cache do
    BackgroundMigrations.set_transactions_denormalization_finished(true)
  end

  defp token_transfer_to_index(token_transfer) do
    {token_transfer.transaction_hash, token_transfer.block_hash, token_transfer.log_index}
  end
end
