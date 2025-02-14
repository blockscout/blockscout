defmodule Explorer.Migrator.SanitizeDuplicatedLogIndexLogs do
  @moduledoc """
  This module is responsible for sanitizing duplicate log index entries in the database.
  The migration process includes identifying duplicate log indexes and updating the related token transfers and token instances accordingly.
  """

  use Explorer.Migrator.FillingMigration

  import Ecto.Query

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Chain.{Log, TokenTransfer}
  alias Explorer.Chain.Token.Instance
  alias Explorer.Migrator.FillingMigration
  alias Explorer.{QueryHelper, Repo}

  require Logger

  @migration_name "sanitize_duplicated_log_index_logs"

  @impl FillingMigration
  def migration_name, do: @migration_name

  @impl FillingMigration
  def last_unprocessed_identifiers(state) do
    block_number = state[:block_number_to_process] || 0

    limit = batch_size() * concurrency()

    ids =
      block_number
      |> unprocessed_data_query(block_number + limit)
      |> Repo.all(timeout: :infinity)
      |> Enum.group_by(& &1.block_hash)
      |> Map.to_list()

    {ids, Map.put(state, :block_number_to_process, block_number + limit)}
  end

  @doc """
  Stub implementation to satisfy FillingMigration behaviour
  """
  @impl FillingMigration
  @spec unprocessed_data_query() :: nil
  def unprocessed_data_query do
    nil
  end

  def unprocessed_data_query(block_number_start, block_number_end) do
    Log
    |> where([l], l.block_number >= ^block_number_start and l.block_number < ^block_number_end)
  end

  @impl FillingMigration
  @doc """
  Updates a batch of logs grouped by block.

  ## Parameters

    - logs_by_block: A map where the keys are block identifiers and the values are lists of logs associated with those blocks.

  ## Returns

    :ok
  """
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

        {[id | ids],
         [
           %Log{log | index: new_index} |> Map.from_struct() |> Map.drop([:block, :address, :transaction, :__meta__])
           | logs
         ], Map.put(ids_to_new_index, id, new_index)}
      end)

    prepared_ids =
      Enum.map(ids, fn {transaction_hash, block_hash, log_index} ->
        {transaction_hash.bytes, block_hash.bytes, log_index}
      end)

    Repo.transaction(fn ->
      Log
      |> where(
        [log],
        ^QueryHelper.tuple_in([:transaction_hash, :block_hash, :index], prepared_ids)
      )
      |> Repo.delete_all(timeout: :infinity)

      {_, token_transfers} =
        TokenTransfer
        |> where(
          [token_transfer],
          ^QueryHelper.tuple_in([:transaction_hash, :block_hash, :log_index], prepared_ids)
        )
        |> select([token_transfer], token_transfer)
        |> Repo.delete_all(timeout: :infinity)

      Repo.insert_all(Log, logs, timeout: :infinity)

      token_transfers
      |> Enum.map(fn token_transfer ->
        id = token_transfer_to_index(token_transfer)

        %TokenTransfer{token_transfer | log_index: ids_to_new_index[id]}
        |> Map.from_struct()
        |> Map.drop([
          :token_id,
          :index_in_batch,
          :reverse_index_in_batch,
          :token_decimals,
          :from_address,
          :to_address,
          :token_contract_address,
          :block,
          :instances,
          :token,
          :transaction,
          :token_instance,
          :__meta__
        ])
      end)
      |> (&Repo.insert_all(TokenTransfer, &1, timeout: :infinity)).()

      nft_instances_params =
        token_transfers
        |> Enum.filter(&(&1.token_type == "ERC-721"))
        |> Enum.map(fn token_transfer -> {token_transfer.block_number, token_transfer.log_index} end)

      nft_updates_map =
        token_transfers
        |> Enum.filter(&(&1.token_type == "ERC-721" && &1.block_consensus))
        |> Enum.reduce(%{}, fn token_transfer, acc ->
          id = token_transfer_to_index(token_transfer)
          Map.put(acc, {token_transfer.block_number, token_transfer.log_index}, ids_to_new_index[id])
        end)

      Instance
      |> where(
        [nft],
        ^QueryHelper.tuple_in([:owner_updated_at_block, :owner_updated_at_log_index], nft_instances_params)
      )
      |> Repo.all(timeout: :infinity)
      |> Enum.map(fn nft ->
        %Instance{
          nft
          | owner_updated_at_log_index: nft_updates_map[{nft.owner_updated_at_block, nft.owner_updated_at_log_index}]
        }
        |> Map.from_struct()
        |> Map.drop([
          :current_token_balance,
          :is_unique,
          :owner,
          :token,
          :__meta__
        ])
      end)
      |> (&Repo.insert_all(Instance, &1,
            conflict_target: [:token_contract_address_hash, :token_id],
            on_conflict: {:replace, [:owner_updated_at_log_index]},
            timeout: :infinity
          )).()
    end)

    :ok
  end

  defp process_block({block_hash, logs}) do
    if logs |> Enum.frequencies_by(& &1.index) |> Map.values() |> Enum.max() == 1 do
      :ignore
    else
      Logger.error("Found logs with same index within one block: #{block_hash} in DB")

      logs = Repo.preload(logs, :transaction)

      logs
      |> Enum.sort_by(&{&1.transaction.index, &1.index, &1.transaction_hash})
      |> Enum.with_index(&{&1, &2})
    end
  end

  @impl FillingMigration
  def update_cache do
    BackgroundMigrations.set_sanitize_duplicated_log_index_logs_finished(true)
  end

  defp token_transfer_to_index(token_transfer) do
    {token_transfer.transaction_hash, token_transfer.block_hash, token_transfer.log_index}
  end
end
