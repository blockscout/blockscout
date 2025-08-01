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

    # TODO: remove tag after the migration of internal transactions PK to [:block_hash, :transaction_index, :index]
    @tag :skip
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

      Enum.each(transactions_1 ++ transactions_2, fn %{hash: transaction_hash} ->
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
  end
end
