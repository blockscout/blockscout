defmodule Indexer.Fetcher.InternalTransaction.DeleteQueueTest do
  use Explorer.DataCase

  import Mox

  alias Explorer.Chain.{InternalTransaction, PendingBlockOperation}
  alias Explorer.Chain.InternalTransaction.DeleteQueue
  alias Indexer.Fetcher.InternalTransaction.DeleteQueue, as: DeleteQueueFetcher

  setup :verify_on_exit!
  setup :set_mox_global

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
      block_hash: transaction_1.block_hash,
      block_index: 0,
      block_number: fresh_block_number
    )

    insert(:internal_transaction,
      transaction: transaction_2,
      index: 0,
      block_hash: transaction_2.block_hash,
      block_index: 0,
      block_number: expired_block_number
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
end
