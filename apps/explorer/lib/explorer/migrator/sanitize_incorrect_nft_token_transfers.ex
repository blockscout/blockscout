defmodule Explorer.Migrator.SanitizeIncorrectNFTTokenTransfers do
  @moduledoc """
  Delete all token transfers of ERC-721 tokens with deposit/withdrawal signatures
  Delete all token transfers of ERC-1155 tokens with empty amount, amounts and token_ids
  Send blocks containing token transfers of ERC-721 tokens with empty token_ids to re-fetch
  """

  use GenServer, restart: :transient

  import Ecto.Query

  require Logger

  alias Explorer.Chain.{Block, Log, TokenTransfer}
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
    case MigrationStatus.get_status(@migration_name) do
      "completed" ->
        {:stop, :normal, state}

      _ ->
        MigrationStatus.set_status(@migration_name, "started")
        schedule_batch_migration(0)
        {:noreply, %{step: :delete}}
    end
  end

  @impl true
  def handle_info(:migrate_batch, %{step: step} = state) do
    case last_unprocessed_identifiers(step) do
      [] ->
        case step do
          :delete ->
            Logger.info("SanitizeIncorrectNFTTokenTransfers deletion finished, continuing with blocks re-fetch")
            schedule_batch_migration()
            {:noreply, %{step: :refetch}}

          :refetch ->
            Logger.info("SanitizeIncorrectNFTTokenTransfers migration finished")
            MigrationStatus.set_status(@migration_name, "completed")
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

  defp unprocessed_identifiers(:delete) do
    from(
      tt in TokenTransfer,
      left_join: l in Log,
      on: tt.block_hash == l.block_hash and tt.transaction_hash == l.transaction_hash and tt.log_index == l.index,
      left_join: t in assoc(tt, :token),
      where:
        t.type == ^"ERC-721" and
          (l.first_topic == ^TokenTransfer.weth_deposit_signature() or
             l.first_topic == ^TokenTransfer.weth_withdrawal_signature()),
      or_where: t.type == ^"ERC-1155" and is_nil(tt.amount) and is_nil(tt.amounts) and is_nil(tt.token_ids),
      select: {tt.transaction_hash, tt.block_hash, tt.log_index}
    )
  end

  defp unprocessed_identifiers(:refetch) do
    from(
      tt in TokenTransfer,
      join: t in assoc(tt, :token),
      join: b in assoc(tt, :block),
      where: t.type == ^"ERC-721" and is_nil(tt.token_ids),
      where: b.consensus == true,
      where: b.refetch_needed == false,
      select: tt.block_number,
      distinct: tt.block_number
    )
  end

  defp run_task(batch, step), do: Task.async(fn -> handle_batch(batch, step) end)

  defp handle_batch(token_transfer_ids, :delete) do
    query = TokenTransfer.by_ids_query(token_transfer_ids)

    Repo.delete_all(query, timeout: :infinity)
  end

  defp handle_batch(block_numbers, :refetch) do
    Block.set_refetch_needed(block_numbers)
  end

  defp schedule_batch_migration(timeout \\ nil) do
    Process.send_after(self(), :migrate_batch, timeout || Application.get_env(:explorer, __MODULE__)[:timeout])
  end

  defp batch_size do
    Application.get_env(:explorer, __MODULE__)[:batch_size] || @default_batch_size
  end

  defp concurrency do
    default = 4 * System.schedulers_online()

    Application.get_env(:explorer, __MODULE__)[:concurrency] || default
  end
end
