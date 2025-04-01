defmodule Explorer.Migrator.SanitizeIncorrectNFTTokenTransfers do
  @moduledoc """
  Delete all token transfers of ERC-721 tokens with deposit/withdrawal signatures
  Delete all token transfers of ERC-1155 tokens with empty amount, amounts and token_ids
  Send blocks containing token transfers of ERC-721 tokens with empty token_ids to re-fetch
  """

  use GenServer, restart: :transient

  import Ecto.Query

  require Logger

  alias Explorer.Chain.{Block, Log, Token, TokenTransfer}
  alias Explorer.Migrator.MigrationStatus
  alias Explorer.Repo

  @migration_name "sanitize_incorrect_nft"
  @default_batch_size 500

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(_) do
    {:ok, %{}, {:continue, :ok}}
  end

  @impl true
  def handle_continue(:ok, state) do
    case MigrationStatus.fetch(@migration_name) do
      %{status: "completed"} ->
        {:stop, :normal, state}

      status ->
        state = (status && status.meta) || %{"step" => "delete_erc_721"}

        if is_nil(status) do
          MigrationStatus.set_status(@migration_name, "started")
          MigrationStatus.update_meta(@migration_name, state)
        end

        schedule_batch_migration(0)
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(:migrate_batch, %{"step" => step} = state) do
    case last_unprocessed_identifiers(step) do
      [] ->
        case step do
          "delete_erc_721" ->
            Logger.info("SanitizeIncorrectNFTTokenTransfers `delete_erc_721` step is finished")

            schedule_batch_migration()

            new_state = %{"step" => "delete_erc_1155"}
            MigrationStatus.update_meta(@migration_name, new_state)

            {:noreply, new_state}

          "delete_erc_1155" ->
            Logger.info("SanitizeIncorrectNFTTokenTransfers `delete_erc_1155` step is finished")

            schedule_batch_migration()

            new_state = %{"step" => "refetch"}
            MigrationStatus.update_meta(@migration_name, new_state)

            {:noreply, new_state}

          "refetch" ->
            Logger.info("SanitizeIncorrectNFTTokenTransfers migration finished")

            MigrationStatus.set_status(@migration_name, "completed")
            MigrationStatus.set_meta(@migration_name, nil)

            {:stop, :normal, state}
        end

      identifiers ->
        identifiers
        |> Enum.chunk_every(batch_size())
        |> Enum.map(&run_task(&1, step))
        |> Task.await_many(:infinity)

        schedule_batch_migration()

        {:noreply, state}
    end
  end

  defp last_unprocessed_identifiers(step) do
    limit = batch_size() * concurrency()

    step
    |> unprocessed_identifiers()
    |> limit(^limit)
    |> Repo.all(timeout: :infinity)
  end

  defp unprocessed_identifiers("delete_erc_721") do
    base_query = from(log in Log, as: :log)

    logs_query =
      base_query
      |> where(^Log.first_topic_is_deposit_or_withdrawal_signature())
      |> join(:left, [log], token in Token, on: log.address_hash == token.contract_address_hash)
      |> where([log, token], token.type == ^"ERC-721")
      |> select([log], %{block_hash: log.block_hash, transaction_hash: log.transaction_hash, index: log.index})

    TokenTransfer
    |> select([tt], {tt.transaction_hash, tt.block_hash, tt.log_index})
    |> join(:inner, [tt], log in subquery(logs_query),
      on: tt.block_hash == log.block_hash and tt.transaction_hash == log.transaction_hash and tt.log_index == log.index
    )
  end

  defp unprocessed_identifiers("delete_erc_1155") do
    TokenTransfer
    |> select([tt], {tt.transaction_hash, tt.block_hash, tt.log_index})
    |> where([tt], tt.token_type == ^"ERC-1155" and is_nil(tt.amount) and is_nil(tt.amounts) and is_nil(tt.token_ids))
  end

  defp unprocessed_identifiers("refetch") do
    from(
      tt in TokenTransfer,
      join: b in assoc(tt, :block),
      where: tt.token_type == ^"ERC-721" and is_nil(tt.token_ids),
      where: b.consensus == true,
      where: b.refetch_needed == false,
      select: tt.block_number,
      distinct: tt.block_number
    )
  end

  defp run_task(batch, step), do: Task.async(fn -> handle_batch(batch, step) end)

  defp handle_batch(block_numbers, "refetch") do
    Block.set_refetch_needed(block_numbers)
  end

  defp handle_batch(token_transfer_ids, _delete_step) do
    query = TokenTransfer.by_ids_query(token_transfer_ids)

    Repo.delete_all(query, timeout: :infinity)
  end

  defp schedule_batch_migration(timeout \\ nil) do
    Process.send_after(self(), :migrate_batch, timeout || Application.get_env(:explorer, __MODULE__)[:timeout])
  end

  defp batch_size do
    Application.get_env(:explorer, __MODULE__)[:batch_size] || @default_batch_size
  end

  defp concurrency do
    Application.get_env(:explorer, __MODULE__)[:concurrency]
  end
end
