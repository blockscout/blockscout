defmodule Explorer.Migrator.SanitizeDuplicatedLogIndexLogs do
  @moduledoc """
  Module responsible for sanitizing duplicated log index logs in the database.

  The migration process involves identifying and updating duplicated log index logs, updating the corresponding token transfers and token instances.
  """

  use Explorer.Migrator.FillingMigration

  import Ecto.Query

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Chain.Log
  alias Explorer.Chain.TokenTransfer
  alias Explorer.Chain.Token.Instance
  alias Explorer.Migrator.FillingMigration
  alias Explorer.Repo

  require Logger

  @migration_name "sanitize_duplicated_log_index_logs"

  def init(_) do
    """
    CREATE TYPE log_id AS (
      tx_hash bytea,
      block_hash bytea,
      log_index integer
    );
    """
    |> Repo.query!([], timeout: :infinity)

    """
    CREATE TYPE nft_id AS (
      block_number bigint,
      log_index integer
    );
    """
    |> Repo.query!([], timeout: :infinity)

    {:ok, %{}, {:continue, :ok}}
  end

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
      Enum.map(ids, fn {tx_hash, block_hash, log_index} ->
        {tx_hash.bytes, block_hash.bytes, log_index}
      end)

    Repo.transaction(fn ->
      Log
      |> where(
        [log],
        fragment(
          "(?, ?, ?) = ANY(?::log_id[])",
          log.transaction_hash,
          log.block_hash,
          log.index,
          ^prepared_ids
        )
      )
      |> Repo.delete_all(timeout: :infinity)

      {_, token_transfers} =
        TokenTransfer
        |> where(
          [token_transfer],
          fragment(
            "(?, ?, ?) = ANY(?::log_id[])",
            token_transfer.transaction_hash,
            token_transfer.block_hash,
            token_transfer.log_index,
            ^prepared_ids
          )
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
        |> Enum.filter(&(&1.token_type == "ERC-721"))
        |> Enum.reduce(%{}, fn token_transfer, acc ->
          if token_transfer.block_consensus do
            id = token_transfer_to_index(token_transfer)
            Map.put(acc, {token_transfer.block_number, token_transfer.log_index}, ids_to_new_index[id])
          else
            acc
          end
        end)

      Instance
      |> where(
        [nft],
        fragment(
          "(?, ?) = ANY(?::nft_id[])",
          nft.owner_updated_at_block,
          nft.owner_updated_at_log_index,
          ^nft_instances_params
        )
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
      # credo:disable-for-next-line Credo.Check.Refactor.Nesting
      |> Enum.map_reduce(0, fn log, index ->
        {{log, index}, index + 1}
      end)
      |> elem(0)
    end
  end

  @impl FillingMigration
  def update_cache do
    BackgroundMigrations.set_sanitize_duplicated_log_index_logs_finished(true)
  end

  defp token_transfer_to_index(token_transfer) do
    {token_transfer.transaction_hash, token_transfer.block_hash, token_transfer.log_index}
  end

  @impl FillingMigration

  @doc """
  Callback function that is executed when the migration process finishes.
  """
  def on_finish do
    """
    DROP TYPE log_id;
    """
    |> Repo.query!([], timeout: :infinity)

    """
    DROP TYPE nft_id;
    """
    |> Repo.query!([], timeout: :infinity)

    :ok
  end
end
