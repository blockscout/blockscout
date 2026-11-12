# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Indexer.Fetcher.InternalTransaction.DeleteQueueTest do
  use Explorer.DataCase

  import Mox

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Chain.{InternalTransaction, PendingBlockOperation}
  alias Explorer.Chain.InternalTransaction.DeleteQueue
  alias Explorer.Utility.InternalTransactionsAddressPlaceholder
  alias Indexer.Fetcher.InternalTransaction.DeleteQueue, as: DeleteQueueFetcher

  setup :verify_on_exit!
  setup :set_mox_global

  setup do
    geth_config = Application.get_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth)
    Application.put_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth, Keyword.put(geth_config, :block_traceable?, true))

    fetcher_config = Application.get_env(:indexer, DeleteQueueFetcher)
    Application.put_env(:indexer, DeleteQueueFetcher, Keyword.put(fetcher_config, :threshold, :timer.minutes(10)))

    on_exit(fn ->
      Application.put_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth, geth_config)
      Application.put_env(:indexer, DeleteQueueFetcher, fetcher_config)
    end)
  end

  test "deletes internal transactions and inserts pending operations" do
    transaction_1 =
      :transaction
      |> insert()
      |> with_block()

    transaction_2 =
      :transaction
      |> insert()
      |> with_block()

    %{block_number: fresh_block_number} =
      insert(:internal_transaction_delete_queue, block_number: transaction_1.block_number, updated_at: Timex.now())

    %{block_number: expired_block_number} =
      insert(:internal_transaction_delete_queue,
        block_number: transaction_2.block_number,
        updated_at: Timex.shift(Timex.now(), minutes: -20)
      )

    insert(:internal_transaction,
      transaction: transaction_1,
      index: 0,
      block_number: fresh_block_number,
      transaction_index: transaction_1.index
    )

    insert(:internal_transaction,
      transaction: transaction_2,
      index: 0,
      block_number: expired_block_number,
      transaction_index: transaction_2.index
    )

    pid = DeleteQueueFetcher.Supervisor.Case.start_supervised!()

    wait_for_results(fn ->
      PendingBlockOperation
      |> limit(1)
      |> Repo.one!()
    end)

    assert [%{block_number: ^fresh_block_number}] = Repo.all(DeleteQueue)
    assert [%{block_number: ^fresh_block_number}] = Repo.all(InternalTransaction)
    assert [%{block_number: ^expired_block_number}] = Repo.all(PendingBlockOperation)

    GenServer.stop(pid)
  end

  test "deletes the address placeholders of the blocks when the internal transactions storage is disabled" do
    internal_transaction_config = Application.get_env(:explorer, InternalTransaction)

    Application.put_env(
      :explorer,
      InternalTransaction,
      Keyword.merge(internal_transaction_config || [], storage_disabled?: true)
    )

    initial_index_finished? =
      BackgroundMigrations.get_heavy_indexes_create_deleted_internal_transactions_address_placeholders_block_number_index_finished()

    set_placeholders_block_number_index_finished(true)

    on_exit(fn ->
      if is_nil(internal_transaction_config) do
        Application.delete_env(:explorer, InternalTransaction)
      else
        Application.put_env(:explorer, InternalTransaction, internal_transaction_config)
      end

      set_placeholders_block_number_index_finished(initial_index_finished?)
    end)

    %{block_number: block_number} = :transaction |> insert() |> with_block()

    insert(:internal_transaction_delete_queue,
      block_number: block_number,
      updated_at: Timex.shift(Timex.now(), minutes: -20)
    )

    %{address_id: address_id} = insert(:address_id_to_address_hash, address: insert(:address))
    other_block_number = block_number + 1

    for placeholder_block_number <- [block_number, other_block_number] do
      insert(:deleted_internal_transactions_address_placeholder,
        address_id: address_id,
        block_number: placeholder_block_number
      )
    end

    pid = DeleteQueueFetcher.Supervisor.Case.start_supervised!()

    wait_for_results(fn ->
      PendingBlockOperation
      |> limit(1)
      |> Repo.one!()
    end)

    assert [%{block_number: ^other_block_number}] = Repo.all(InternalTransactionsAddressPlaceholder)

    GenServer.stop(pid)
  end

  defp set_placeholders_block_number_index_finished(finished?) do
    BackgroundMigrations.set_heavy_indexes_create_deleted_internal_transactions_address_placeholders_block_number_index_finished(
      finished?
    )
  end
end
