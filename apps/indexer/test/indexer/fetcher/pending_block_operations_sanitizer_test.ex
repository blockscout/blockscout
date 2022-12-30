defmodule Indexer.Fetcher.PendingBlockOperationsSanitizerTest do
  use Explorer.DataCase, async: false

  alias Explorer.Repo
  alias Indexer.Fetcher.PendingBlockOperationsSanitizer

  setup do
    config = Application.get_env(:indexer, Indexer.Fetcher.InternalTransaction.Supervisor)

    Application.put_env(:indexer, Indexer.Fetcher.InternalTransaction.Supervisor, disabled?: true)

    on_exit(fn ->
      Application.put_env(:indexer, Indexer.Fetcher.InternalTransaction.Supervisor, config)
    end)
  end

  test "updates empty block_numbers" do
    %{number: block_number1, hash: hash1} = insert(:block)
    %{number: block_number2, hash: hash2} = insert(:block)
    %{number: block_number3, hash: hash3} = insert(:block)
    pending_block_operation1 = insert(:pending_block_operation, block_hash: hash1)
    pending_block_operation2 = insert(:pending_block_operation, block_hash: hash2)
    pending_block_operation3 = insert(:pending_block_operation, block_hash: hash3)

    PendingBlockOperationsSanitizer.update_batch()

    assert %{block_number: ^block_number1} = Repo.reload(pending_block_operation1)
    assert %{block_number: ^block_number2} = Repo.reload(pending_block_operation2)
    assert %{block_number: ^block_number3} = Repo.reload(pending_block_operation3)
  end
end
