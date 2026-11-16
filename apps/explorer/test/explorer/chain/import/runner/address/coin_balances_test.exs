# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Import.Runner.Address.CoinBalancesTest do
  use Explorer.DataCase

  alias Ecto.Multi
  alias Explorer.Chain.Address.CoinBalance
  alias Explorer.Chain.Import.Runner.Address.CoinBalances
  alias Explorer.Chain.Wei
  alias Explorer.Utility.MissingBlockRange
  alias Indexer.Fetcher.InternalTransaction.Supervisor, as: InternalTransactionSupervisor

  setup do
    initial_supervisor_env = Application.get_env(:indexer, InternalTransactionSupervisor)
    initial_json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

    on_exit(fn ->
      Application.put_env(:indexer, InternalTransactionSupervisor, initial_supervisor_env)
      Application.put_env(:explorer, :json_rpc_named_arguments, initial_json_rpc_named_arguments)
    end)

    set_internal_transactions_fetcher(true)

    %{address_hash: insert(:address).hash}
  end

  defp set_internal_transactions_fetcher(disabled?) do
    initial = Application.get_env(:indexer, InternalTransactionSupervisor)
    Application.put_env(:indexer, InternalTransactionSupervisor, Keyword.merge(initial || [], disabled?: disabled?))
  end

  defp set_json_rpc_variant(variant) do
    initial = Application.get_env(:explorer, :json_rpc_named_arguments)
    Application.put_env(:explorer, :json_rpc_named_arguments, Keyword.merge(initial || [], variant: variant))
  end

  defp fetched(address_hash, block_number, value) do
    %{
      address_hash: address_hash,
      block_number: block_number,
      value: %Wei{value: Decimal.new(value)},
      value_fetched_at: DateTime.utc_now()
    }
  end

  defp run(changes_list) do
    options = %{timestamps: %{inserted_at: DateTime.utc_now(), updated_at: DateTime.utc_now()}}

    assert {:ok, %{address_coin_balances: imported}} =
             Multi.new()
             |> CoinBalances.run(changes_list, options)
             |> Repo.transaction()

    Enum.map(imported, & &1.block_number)
  end

  defp stored(address_hash) do
    CoinBalance
    |> where([cb], cb.address_hash == ^address_hash)
    |> order_by([cb], asc: cb.block_number)
    |> select([cb], {cb.block_number, cb.value})
    |> Repo.all()
    |> Enum.map(fn
      {block_number, nil} -> {block_number, nil}
      {block_number, %Wei{value: value}} -> {block_number, Decimal.to_integer(value)}
    end)
  end

  describe "run/3" do
    test "deletes the placeholder when the fetched value is the same as the previous one", %{address_hash: address_hash} do
      insert(:fetched_balance, address_hash: address_hash, block_number: 1, value: 100)
      insert(:unfetched_balance, address_hash: address_hash, block_number: 2)

      assert run([fetched(address_hash, 2, 100)]) == []
      assert stored(address_hash) == [{1, 100}]
    end

    test "does not insert a row when there is no placeholder and the value is unchanged", %{address_hash: address_hash} do
      insert(:fetched_balance, address_hash: address_hash, block_number: 1, value: 100)

      assert run([fetched(address_hash, 2, 100)]) == []
      assert stored(address_hash) == [{1, 100}]
    end

    test "fills in the placeholder when the fetched value differs from the previous one", %{address_hash: address_hash} do
      insert(:fetched_balance, address_hash: address_hash, block_number: 1, value: 100)
      insert(:unfetched_balance, address_hash: address_hash, block_number: 2)

      assert run([fetched(address_hash, 2, 150)]) == [2]
      assert stored(address_hash) == [{1, 100}, {2, 150}]
    end

    test "keeps the first balance of an address", %{address_hash: address_hash} do
      insert(:unfetched_balance, address_hash: address_hash, block_number: 1)

      assert run([fetched(address_hash, 1, 0)]) == [1]
      assert stored(address_hash) == [{1, 0}]
    end

    test "compares with the previous row filled in by the same batch", %{address_hash: address_hash} do
      insert(:fetched_balance, address_hash: address_hash, block_number: 1, value: 100)
      insert(:unfetched_balance, address_hash: address_hash, block_number: 2)
      insert(:unfetched_balance, address_hash: address_hash, block_number: 3)
      insert(:unfetched_balance, address_hash: address_hash, block_number: 4)

      assert run([fetched(address_hash, 2, 200), fetched(address_hash, 3, 200), fetched(address_hash, 4, 300)]) ==
               [2, 4]

      assert stored(address_hash) == [{1, 100}, {2, 200}, {4, 300}]
    end

    test "keeps the row when the previous row is an unfetched placeholder", %{address_hash: address_hash} do
      insert(:fetched_balance, address_hash: address_hash, block_number: 1, value: 100)
      insert(:unfetched_balance, address_hash: address_hash, block_number: 2)
      insert(:unfetched_balance, address_hash: address_hash, block_number: 3)

      assert run([fetched(address_hash, 3, 100)]) == [3]
      assert stored(address_hash) == [{1, 100}, {2, nil}, {3, 100}]
    end

    test "keeps the row when blocks between it and the previous row are not imported yet", %{
      address_hash: address_hash
    } do
      insert(:fetched_balance, address_hash: address_hash, block_number: 1, value: 100)
      insert(:unfetched_balance, address_hash: address_hash, block_number: 5)
      Repo.insert!(%MissingBlockRange{from_number: 3, to_number: 2})

      assert run([fetched(address_hash, 5, 100)]) == [5]
      assert stored(address_hash) == [{1, 100}, {5, 100}]
    end

    test "ignores missing block ranges outside the gap", %{address_hash: address_hash} do
      insert(:fetched_balance, address_hash: address_hash, block_number: 3, value: 100)
      insert(:unfetched_balance, address_hash: address_hash, block_number: 5)
      Repo.insert!(%MissingBlockRange{from_number: 2, to_number: 0})
      Repo.insert!(%MissingBlockRange{from_number: 10, to_number: 6})

      assert run([fetched(address_hash, 5, 100)]) == []
      assert stored(address_hash) == [{3, 100}]
    end

    test "upserts a row that already has a value", %{address_hash: address_hash} do
      insert(:fetched_balance, address_hash: address_hash, block_number: 1, value: 100)

      insert(:fetched_balance,
        address_hash: address_hash,
        block_number: 2,
        value: 150,
        value_fetched_at: DateTime.add(DateTime.utc_now(), -60)
      )

      assert run([fetched(address_hash, 2, 100)]) == [2]
      assert stored(address_hash) == [{1, 100}, {2, 100}]
    end

    test "never drops placeholder params", %{address_hash: address_hash} do
      insert(:fetched_balance, address_hash: address_hash, block_number: 1, value: 100)

      assert run([%{address_hash: address_hash, block_number: 2}]) == [2]
      assert stored(address_hash) == [{1, 100}, {2, nil}]
    end
  end

  describe "run/3 with the internal transactions fetcher enabled" do
    setup do
      set_internal_transactions_fetcher(false)
      :ok
    end

    test "keeps the row when internal transactions of a block in the gap are pending", %{address_hash: address_hash} do
      set_json_rpc_variant(EthereumJSONRPC.Nethermind)

      insert(:fetched_balance, address_hash: address_hash, block_number: 1, value: 100)
      insert(:unfetched_balance, address_hash: address_hash, block_number: 5)
      block = insert(:block, number: 3)
      insert(:pending_block_operation, block_hash: block.hash, block_number: block.number)

      assert run([fetched(address_hash, 5, 100)]) == [5]
      assert stored(address_hash) == [{1, 100}, {5, 100}]
    end

    test "drops the unchanged row when only its own block is pending", %{address_hash: address_hash} do
      set_json_rpc_variant(EthereumJSONRPC.Nethermind)

      insert(:fetched_balance, address_hash: address_hash, block_number: 1, value: 100)
      insert(:unfetched_balance, address_hash: address_hash, block_number: 5)
      block = insert(:block, number: 5)
      insert(:pending_block_operation, block_hash: block.hash, block_number: block.number)

      assert run([fetched(address_hash, 5, 100)]) == []
      assert stored(address_hash) == [{1, 100}]
    end

    test "keeps unchanged rows when pending operations are tracked per transaction", %{address_hash: address_hash} do
      set_json_rpc_variant(EthereumJSONRPC.Geth)

      initial_geth_env = Application.get_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth)

      Application.put_env(
        :ethereum_jsonrpc,
        EthereumJSONRPC.Geth,
        Keyword.merge(initial_geth_env || [], block_traceable?: false)
      )

      on_exit(fn -> Application.put_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth, initial_geth_env) end)

      insert(:fetched_balance, address_hash: address_hash, block_number: 1, value: 100)
      insert(:unfetched_balance, address_hash: address_hash, block_number: 2)

      assert run([fetched(address_hash, 2, 100)]) == [2]
      assert stored(address_hash) == [{1, 100}, {2, 100}]
    end
  end
end
