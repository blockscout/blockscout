defmodule Explorer.Migrator.SanitizeIncorrectWETHTokenTransfers do
  @moduledoc """
    This migrator will delete all incorrect WETH token transfers. As incorrect we consider:
      - WETH withdrawals and WETH deposits emitted by tokens which are not in `WHITELISTED_WETH_CONTRACTS` env
      - WETH withdrawal or WETH deposit which has sibling token transfer within the same block and transaction, with the same amount, same from and to addresses, same token contract addresses. (We consider such pairs as duplicates)
  """

  use GenServer, restart: :transient

  import Ecto.Query

  require Logger

  alias Explorer.Chain.{Log, TokenTransfer}
  alias Explorer.Migrator.MigrationStatus
  alias Explorer.Repo

  @migration_name "sanitize_incorrect_weth_transfers"
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
        {:noreply, %{step: :delete_duplicates}}
    end
  end

  @impl true
  def handle_info(:migrate_batch, %{step: step} = state) do
    if step == :delete_not_whitelisted_weth_transfers and
         !Application.get_env(:explorer, Explorer.Chain.TokenTransfer)[:weth_token_transfers_filtering_enabled] do
      {:stop, :normal, state}
    else
      process_batch(state)
    end
  end

  defp process_batch(%{step: step} = state) do
    case last_unprocessed_identifiers(step) do
      [] ->
        case step do
          :delete_duplicates ->
            Logger.info(
              "SanitizeIncorrectWETHTokenTransfers deletion of duplicates finished, continuing with deletion of not whitelisted weth transfers"
            )

            schedule_batch_migration()
            {:noreply, %{step: :delete_not_whitelisted_weth_transfers}}

          :delete_not_whitelisted_weth_transfers ->
            Logger.info(
              "SanitizeIncorrectWETHTokenTransfers deletion of not whitelisted weth transfers finished. Sanitizing is completed."
            )

            MigrationStatus.set_status(@migration_name, "completed")
            {:stop, :normal, state}
        end

      identifiers ->
        identifiers
        |> Enum.chunk_every(batch_size())
        |> Enum.map(&run_task/1)
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

  defp unprocessed_identifiers(:delete_duplicates) do
    weth_transfers =
      from(
        tt in TokenTransfer,
        left_join: l in Log,
        on: tt.block_hash == l.block_hash and tt.transaction_hash == l.transaction_hash and tt.log_index == l.index,
        where:
          l.first_topic == ^TokenTransfer.weth_deposit_signature() or
            l.first_topic == ^TokenTransfer.weth_withdrawal_signature()
      )

    from(
      weth_tt in subquery(weth_transfers),
      inner_join: tt in TokenTransfer,
      on: weth_tt.block_hash == tt.block_hash and weth_tt.transaction_hash == tt.transaction_hash,
      where:
        weth_tt.log_index != tt.log_index and weth_tt.token_contract_address_hash == tt.token_contract_address_hash and
          weth_tt.to_address_hash == tt.to_address_hash and weth_tt.from_address_hash == tt.from_address_hash and
          weth_tt.amount == tt.amount,
      select: {weth_tt.transaction_hash, weth_tt.block_hash, weth_tt.log_index}
    )
  end

  defp unprocessed_identifiers(:delete_not_whitelisted_weth_transfers) do
    from(
      tt in TokenTransfer,
      left_join: l in Log,
      on: tt.block_hash == l.block_hash and tt.transaction_hash == l.transaction_hash and tt.log_index == l.index,
      where:
        (l.first_topic == ^TokenTransfer.weth_deposit_signature() or
           l.first_topic == ^TokenTransfer.weth_withdrawal_signature()) and
          tt.token_contract_address_hash not in ^Application.get_env(:explorer, Explorer.Chain.TokenTransfer)[
            :whitelisted_weth_contracts
          ],
      select: {tt.transaction_hash, tt.block_hash, tt.log_index}
    )
  end

  defp run_task(batch), do: Task.async(fn -> handle_batch(batch) end)

  defp handle_batch(token_transfer_ids) do
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
    default = 4 * System.schedulers_online()

    Application.get_env(:explorer, __MODULE__)[:concurrency] || default
  end
end
