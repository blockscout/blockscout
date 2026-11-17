# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Indexer.Fetcher.OnDemand.FirstTraceTest do
  use Explorer.DataCase

  alias Explorer.Chain.InternalTransaction
  alias Indexer.Fetcher.OnDemand.FirstTrace

  describe "maybe_trigger_fetch/2" do
    setup do
      initial_config = Application.get_env(:explorer, InternalTransaction)
      initial_shrink_enabled = Application.get_env(:explorer, :shrink_internal_transactions_enabled)

      Application.put_env(:explorer, :shrink_internal_transactions_enabled, false)

      on_exit(fn ->
        Application.put_env(:explorer, :shrink_internal_transactions_enabled, initial_shrink_enabled)

        if is_nil(initial_config) do
          Application.delete_env(:explorer, InternalTransaction)
        else
          Application.put_env(:explorer, InternalTransaction, initial_config)
        end
      end)

      # stand in for the fetcher server to receive its fetch requests
      Process.register(self(), FirstTrace)

      %{initial_config: initial_config || []}
    end

    test "requests the missing first trace", %{initial_config: initial_config} do
      Application.put_env(:explorer, InternalTransaction, Keyword.merge(initial_config, storage_disabled?: false))

      transaction = insert(:transaction) |> with_block()
      transaction_hash = transaction.hash

      FirstTrace.maybe_trigger_fetch(transaction)

      assert_received {:"$gen_cast", {:fetch, %{hash: ^transaction_hash}}}
    end

    test "does not request the first trace when the internal transactions storage is disabled", %{
      initial_config: initial_config
    } do
      Application.put_env(:explorer, InternalTransaction, Keyword.merge(initial_config, storage_disabled?: true))

      transaction = insert(:transaction) |> with_block()

      FirstTrace.maybe_trigger_fetch(transaction)

      refute_received {:"$gen_cast", {:fetch, _}}
    end
  end
end
