defmodule Indexer.TokenTransfersTest do
  use Explorer.DataCase

  alias Indexer.TokenTransfers

  test "start_link" do
    assert {:ok, _} = TokenTransfers.start_link([])
  end

  test "init" do
    assert TokenTransfers.init([]) == {:ok, %{catalog_task: nil, queue: {[], []}}}
    assert_received :fetch_uncataloged_token_transfers
    assert_received :catalog
    current_pid = self()
    assert [{^current_pid, _}] = Registry.lookup(Registry.ChainEvents, :logs)
  end

  test "handle_info with :fetch_uncataloged_token_transfer message" do
    transfer_log = insert(:token_transfer_log)

    state = %{queue: {[], []}, catalog_task: nil}

    assert {:noreply, %{queue: {[], [item]}, catalog_task: nil}} =
             TokenTransfers.handle_info(:fetch_uncataloged_token_transfers, state)

    assert item.log.id == transfer_log.id
  end

  test "handle_info with {:chain_event, :logs, logs} message" do
    logs = [
      transfer_log = insert(:token_transfer_log),
      insert(:log)
    ]

    state = %{queue: {[], []}, catalog_task: nil}

    assert {:noreply, %{queue: {[], [item]}, catalog_task: nil}} =
             TokenTransfers.handle_info({:chain_event, :logs, logs}, state)

    assert item.id == transfer_log.id
  end

  test "handle_info with :DOWN message" do
    state = %{queue: {[], []}, catalog_task: nil}
    assert {:noreply, ^state} = TokenTransfers.handle_info({:DOWN, nil, :process, nil, :normal}, state)
  end

  test "handle_info with :catalog message"

  describe "handle_info with task callback messages" do
    test "with successful task"
    test "with failed task"
  end

  test "catalog"

  test "fetch_token"
end
