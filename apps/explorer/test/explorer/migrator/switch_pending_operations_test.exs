# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.SwitchPendingOperationsTest do
  use Explorer.DataCase, async: false

  alias Explorer.Chain.{PendingBlockOperation, PendingTransactionOperation}
  alias Explorer.Migrator.SwitchPendingOperations
  alias Explorer.Repo

  describe "transfuse data" do
    setup do
      initial_config_json_rpc = Application.get_env(:explorer, :json_rpc_named_arguments)
      initial_config_geth = Application.get_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth)

      on_exit(fn ->
        Application.put_env(:explorer, :json_rpc_named_arguments, initial_config_json_rpc)
        Application.put_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth, initial_config_geth)
      end)
    end

    test "from pbo to pto" do
      first_block = insert(:block)
      second_block = insert(:block)
      insert(:pending_block_operation, block_number: first_block.number, block_hash: first_block.hash)
      insert(:pending_block_operation, block_number: second_block.number, block_hash: second_block.hash)

      2
      |> insert_list(:transaction)
      |> with_block(first_block)

      3
      |> insert_list(:transaction)
      |> with_block(second_block)

      json_rpc_config = Application.get_env(:explorer, :json_rpc_named_arguments)

      Application.put_env(
        :explorer,
        :json_rpc_named_arguments,
        Keyword.put(json_rpc_config, :variant, EthereumJSONRPC.Geth)
      )

      geth_config = Application.get_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth)
      Application.put_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth, Keyword.put(geth_config, :block_traceable?, false))

      SwitchPendingOperations.start_link([])
      Process.sleep(100)

      assert [] = Repo.all(PendingBlockOperation)
      assert [_, _, _, _, _] = Repo.all(PendingTransactionOperation)
    end

    test "from pbo to pto handles parameter overflow and still completes" do
      block = insert(:block)
      insert(:pending_block_operation, block_number: block.number, block_hash: block.hash)

      5
      |> insert_list(:transaction)
      |> with_block(block)

      json_rpc_config = Application.get_env(:explorer, :json_rpc_named_arguments)

      Application.put_env(
        :explorer,
        :json_rpc_named_arguments,
        Keyword.put(json_rpc_config, :variant, EthereumJSONRPC.Geth)
      )

      geth_config = Application.get_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth)
      Application.put_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth, Keyword.put(geth_config, :block_traceable?, false))

      overflow_raised? = :atomics.new(1, [])

      :meck.new(Repo, [:passthrough])

      :meck.expect(Repo, :insert_all, fn kind, elements, opts ->
        if kind == PendingTransactionOperation and :atomics.get(overflow_raised?, 1) == 0 do
          :atomics.put(overflow_raised?, 1, 1)

          raise Postgrex.QueryError,
            message: "postgresql protocol can not handle 135090 parameters, the maximum is 65535"
        else
          :meck.passthrough([kind, elements, opts])
        end
      end)

      on_exit(fn ->
        try do
          :meck.unload(Repo)
        catch
          _, _ -> :ok
        end
      end)

      SwitchPendingOperations.start_link([])
      Process.sleep(100)

      assert :atomics.get(overflow_raised?, 1) == 1
      assert [] = Repo.all(PendingBlockOperation)
      assert [_, _, _, _, _] = Repo.all(PendingTransactionOperation)
    end

    test "from pto to pbo" do
      first_block = insert(:block)
      second_block = insert(:block)

      transactions_1 =
        2
        |> insert_list(:transaction)
        |> with_block(first_block)

      transactions_2 =
        3
        |> insert_list(:transaction)
        |> with_block(second_block)

      pending_transactions = insert_list(4, :transaction)

      Enum.each(transactions_1 ++ transactions_2 ++ pending_transactions, fn %{hash: transaction_hash} ->
        insert(:pending_transaction_operation, transaction_hash: transaction_hash)
      end)

      json_rpc_config = Application.get_env(:explorer, :json_rpc_named_arguments)

      Application.put_env(
        :explorer,
        :json_rpc_named_arguments,
        Keyword.put(json_rpc_config, :variant, EthereumJSONRPC.Geth)
      )

      geth_config = Application.get_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth)
      Application.put_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth, Keyword.put(geth_config, :block_traceable?, true))

      SwitchPendingOperations.start_link([])
      Process.sleep(100)

      assert [] = Repo.all(PendingTransactionOperation)
      assert [_, _] = Repo.all(PendingBlockOperation)
    end

    test "from pto to pbo keeps priority and processes in small batches" do
      initial_helper_config = Application.get_env(:explorer, Explorer.Chain.PendingOperationsHelper)

      on_exit(fn ->
        Application.put_env(:explorer, Explorer.Chain.PendingOperationsHelper, initial_helper_config)
      end)

      Application.put_env(
        :explorer,
        Explorer.Chain.PendingOperationsHelper,
        Keyword.put(initial_helper_config || [], :transactions_batch_size, 2)
      )

      prioritized_block = insert(:block)
      regular_block = insert(:block)

      [first_prioritized, second_prioritized, third_prioritized] =
        3
        |> insert_list(:transaction)
        |> with_block(prioritized_block)

      regular_transactions =
        2
        |> insert_list(:transaction)
        |> with_block(regular_block)

      pending_transaction = insert(:transaction)

      insert(:pending_transaction_operation, transaction_hash: first_prioritized.hash)
      insert(:pending_transaction_operation, transaction_hash: second_prioritized.hash, priority: 1)
      insert(:pending_transaction_operation, transaction_hash: third_prioritized.hash)

      Enum.each(regular_transactions ++ [pending_transaction], fn %{hash: transaction_hash} ->
        insert(:pending_transaction_operation, transaction_hash: transaction_hash)
      end)

      json_rpc_config = Application.get_env(:explorer, :json_rpc_named_arguments)

      Application.put_env(
        :explorer,
        :json_rpc_named_arguments,
        Keyword.put(json_rpc_config, :variant, EthereumJSONRPC.Geth)
      )

      geth_config = Application.get_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth)
      Application.put_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth, Keyword.put(geth_config, :block_traceable?, true))

      SwitchPendingOperations.start_link([])
      Process.sleep(200)

      assert [] = Repo.all(PendingTransactionOperation)

      pbos = Repo.all(PendingBlockOperation)
      assert length(pbos) == 2

      assert %PendingBlockOperation{block_number: prioritized_number, priority: 1} =
               Enum.find(pbos, &(&1.block_hash == prioritized_block.hash))

      assert prioritized_number == prioritized_block.number

      assert %PendingBlockOperation{block_number: regular_number, priority: nil} =
               Enum.find(pbos, &(&1.block_hash == regular_block.hash))

      assert regular_number == regular_block.number
    end
  end
end
