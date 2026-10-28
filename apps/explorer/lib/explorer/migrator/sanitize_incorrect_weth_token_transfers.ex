# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.SanitizeIncorrectWETHTokenTransfers do
  @moduledoc """
    This migrator will delete all incorrect WETH token transfers. As incorrect we consider:
      - WETH withdrawals and WETH deposits emitted by tokens which are not in `WHITELISTED_WETH_CONTRACTS` env
      - WETH withdrawal or WETH deposit which has sibling token transfer within the same block and transaction, with the same amount, same from and to addresses, same token contract addresses. (We consider such pairs as duplicates)

    Both steps walk the chain from the latest consensus block down to the earliest one in
    ranges of `blocks_batch_size` blocks. Within a range the identifiers of incorrect token
    transfers are fetched and deleted in batches until the range contains no more of them,
    then the migration moves to the next range and checkpoints its position in the
    migration meta, so the work resumes from the last processed range after a restart.
  """

  use GenServer, restart: :transient

  import Ecto.Query

  require Logger

  alias Explorer.Chain.{Block, Log, TokenTransfer}
  alias Explorer.Migrator.MigrationStatus
  alias Explorer.Repo

  @migration_name "sanitize_incorrect_weth_transfers"

  @delete_duplicates_step "delete_duplicates"
  @delete_not_whitelisted_step "delete_not_whitelisted_weth_transfers"

  def migration_name, do: @migration_name

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

      %{status: "wait_for_enabling_weth_filtering"} ->
        if weth_token_transfers_filtering_enabled() do
          new_state = initial_step_state(@delete_not_whitelisted_step)
          MigrationStatus.set_status(@migration_name, "started")
          MigrationStatus.set_meta(@migration_name, new_state)
          schedule_batch_migration(0)
          {:noreply, new_state}
        else
          {:stop, :normal, state}
        end

      status ->
        new_state = restore_state(status && status.meta)

        if is_nil(status) do
          MigrationStatus.set_status(@migration_name, "started")
        end

        if is_nil(status) or new_state != status.meta do
          MigrationStatus.set_meta(@migration_name, new_state)
        end

        schedule_batch_migration(0)
        {:noreply, new_state}
    end
  end

  @impl true
  def handle_info(:migrate_batch, %{"step" => step} = state) do
    if step == @delete_not_whitelisted_step and !weth_token_transfers_filtering_enabled() do
      MigrationStatus.set_status(@migration_name, "wait_for_enabling_weth_filtering")
      {:stop, :normal, state}
    else
      process_batch(state)
    end
  end

  defp process_batch(%{"step" => step} = state) do
    case last_unprocessed_identifiers(state) do
      [] ->
        if state["block_number"] <= state["min_block_number"] do
          finish_step(step, state)
        else
          new_state = next_range_state(state)
          MigrationStatus.set_meta(@migration_name, new_state)

          Logger.info(
            "SanitizeIncorrectWETHTokenTransfers step #{step}: #{Float.round(new_state["percentage"], 2)}% done, continuing from block #{new_state["block_number"]}"
          )

          schedule_batch_migration()

          {:noreply, new_state}
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

  defp finish_step(@delete_duplicates_step, _state) do
    Logger.info(
      "SanitizeIncorrectWETHTokenTransfers deletion of duplicates finished, continuing with deletion of not whitelisted weth transfers"
    )

    new_state = initial_step_state(@delete_not_whitelisted_step)
    MigrationStatus.set_meta(@migration_name, new_state)

    schedule_batch_migration()

    {:noreply, new_state}
  end

  defp finish_step(@delete_not_whitelisted_step, state) do
    Logger.info(
      "SanitizeIncorrectWETHTokenTransfers deletion of not whitelisted weth transfers finished. Sanitizing is completed."
    )

    MigrationStatus.set_status(@migration_name, "completed")
    MigrationStatus.set_meta(@migration_name, nil)

    {:stop, :normal, state}
  end

  # Builds the state for a fresh pass of the given step over the whole chain.
  defp initial_step_state(step) do
    max_block_number = Block.fetch_max_block_number()
    min_block_number = Block.fetch_min_block_number()

    %{
      "step" => step,
      "block_number" => max_block_number,
      "max_block_number" => max_block_number,
      "min_block_number" => min_block_number,
      "percentage" => 0
    }
  end

  # Restores the state saved in the migration meta. Meta written by previous versions of
  # this migrator contains only the step (or nothing at all), in which case the block
  # cursor is initialized to cover the whole chain.
  defp restore_state(%{"step" => step, "block_number" => _, "min_block_number" => _, "max_block_number" => _} = meta)
       when step in [@delete_duplicates_step, @delete_not_whitelisted_step] do
    Map.put_new(meta, "percentage", 0)
  end

  defp restore_state(%{"step" => step}) when step in [@delete_duplicates_step, @delete_not_whitelisted_step] do
    initial_step_state(step)
  end

  defp restore_state(_), do: initial_step_state(@delete_duplicates_step)

  defp next_range_state(state) do
    new_block_number = max(state["min_block_number"], state["block_number"] - blocks_batch_size())

    %{
      state
      | "block_number" => new_block_number,
        "percentage" =>
          (state["max_block_number"] - new_block_number) /
            max(state["max_block_number"] - state["min_block_number"], 1) * 100
    }
  end

  defp last_unprocessed_identifiers(%{"step" => step} = state) do
    limit = batch_size() * concurrency()

    step
    |> unprocessed_identifiers(state)
    |> limit(^limit)
    |> Repo.all(timeout: :infinity)
  end

  defp unprocessed_identifiers(@delete_duplicates_step, state) do
    weth_transfers =
      state
      |> token_transfers_with_logs_query()
      |> where(^Log.first_topic_is_deposit_or_withdrawal_signature(:log))

    not_weth_transfers =
      state
      |> token_transfers_with_logs_query()
      |> where(^Log.first_topic_is_not_deposit_or_withdrawal_signature())

    from(
      weth_tt in subquery(weth_transfers),
      inner_join: tt in subquery(not_weth_transfers),
      on: weth_tt.block_hash == tt.block_hash and weth_tt.transaction_hash == tt.transaction_hash,
      where:
        weth_tt.log_index != tt.log_index and weth_tt.token_contract_address_hash == tt.token_contract_address_hash and
          weth_tt.to_address_hash == tt.to_address_hash and weth_tt.from_address_hash == tt.from_address_hash and
          weth_tt.amount == tt.amount,
      select: {weth_tt.transaction_hash, weth_tt.block_hash, weth_tt.log_index}
    )
  end

  defp unprocessed_identifiers(@delete_not_whitelisted_step, state) do
    state
    |> token_transfers_with_logs_query()
    |> where(^Log.first_topic_is_deposit_or_withdrawal_signature(:log))
    |> where([tt], tt.token_contract_address_hash not in ^whitelisted_weth_contracts())
    |> select([tt], {tt.transaction_hash, tt.block_hash, tt.log_index})
  end

  # Restricts token transfers to the current block range `(block_number - blocks_batch_size, block_number]`.
  # The lower bound is clamped so that the earliest block (including block 0) is covered by the
  # last range.
  defp token_transfers_with_logs_query(state) do
    upper_bound = state["block_number"]
    lower_bound = max(state["min_block_number"] - 1, upper_bound - blocks_batch_size())

    TokenTransfer
    |> where([tt], tt.block_number > ^lower_bound and tt.block_number <= ^upper_bound)
    |> Log.join_to_token_transfer_query()
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
    Application.get_env(:explorer, __MODULE__)[:batch_size]
  end

  defp concurrency do
    Application.get_env(:explorer, __MODULE__)[:concurrency]
  end

  defp blocks_batch_size do
    Application.get_env(:explorer, __MODULE__)[:blocks_batch_size]
  end

  defp whitelisted_weth_contracts do
    Application.get_env(:explorer, Explorer.Chain.TokenTransfer)[:whitelisted_weth_contracts]
  end

  defp weth_token_transfers_filtering_enabled do
    Application.get_env(:explorer, Explorer.Chain.TokenTransfer)[:weth_token_transfers_filtering_enabled]
  end
end
