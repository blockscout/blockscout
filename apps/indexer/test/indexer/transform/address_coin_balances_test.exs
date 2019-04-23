defmodule Indexer.Transform.AddressCoinBalancesTest do
  use ExUnit.Case, async: true

  alias Explorer.Factory
  alias Indexer.Transform.AddressCoinBalances

  describe "params_set/1" do
    test "with block extracts miner_hash" do
      miner_hash =
        Factory.address_hash()
        |> to_string()

      block_number = 1

      params_set = AddressCoinBalances.params_set(%{blocks_params: [%{miner_hash: miner_hash, number: block_number}]})

      assert MapSet.size(params_set) == 1
      assert %{address_hash: miner_hash, block_number: block_number}
    end

    test "with block second degree relations extracts nothing" do
      params_set =
        AddressCoinBalances.params_set(%{
          block_second_degree_relations_params: [%{nephew_hash: Factory.block_hash(), uncle_hash: Factory.block_hash()}]
        })

      assert MapSet.size(params_set) == 0
    end

    test "with call internal transaction extracts nothing" do
      internal_transaction_params =
        :internal_transaction
        |> Factory.params_for()
        |> Map.update!(:type, &to_string/1)
        |> Map.put(:block_number, 1)

      params_set = AddressCoinBalances.params_set(%{internal_transactions_params: [internal_transaction_params]})

      assert MapSet.size(params_set) == 0
    end

    test "with create internal transaction with error extracts nothing" do
      internal_transaction_params =
        :internal_transaction_create
        |> Factory.params_for()
        |> Map.update!(:type, &to_string/1)
        |> Map.put(:block_number, 1)
        |> Map.put(:error, "illegal operation")

      params_set = AddressCoinBalances.params_set(%{internal_transactions_params: [internal_transaction_params]})

      assert MapSet.size(params_set) == 0
    end

    test "with create internal transaction without error extracts created_contract_address_hash" do
      block_number = 1

      created_contract_address_hash =
        Factory.address_hash()
        |> to_string()

      internal_transaction_params =
        :internal_transaction_create
        |> Factory.params_for()
        |> Map.update!(:type, &to_string/1)
        |> Map.put(:block_number, block_number)
        |> Map.put(:created_contract_address_hash, created_contract_address_hash)

      params_set = AddressCoinBalances.params_set(%{internal_transactions_params: [internal_transaction_params]})

      assert MapSet.size(params_set) == 1
      assert %{address_hash: created_contract_address_hash, block_number: block_number}
    end

    test "with self-destruct internal transaction extracts from_address_hash and to_address_hash" do
      block_number = 1

      from_address_hash =
        Factory.address_hash()
        |> to_string()

      to_address_hash =
        Factory.address_hash()
        |> to_string()

      internal_transaction_params =
        :internal_transaction_selfdestruct
        |> Factory.params_for()
        |> Map.update!(:type, &to_string/1)
        |> Map.put(:block_number, block_number)
        |> Map.put(:from_address_hash, from_address_hash)
        |> Map.put(:to_address_hash, to_address_hash)

      params_set = AddressCoinBalances.params_set(%{internal_transactions_params: [internal_transaction_params]})

      assert MapSet.size(params_set) == 2
      assert %{address_hash: from_address_hash, block_number: block_number}
      assert %{address_hash: to_address_hash, block_number: block_number}
    end

    test "with log extracts address_hash" do
      block_number = 1

      address_hash =
        Factory.address_hash()
        |> to_string()

      log_params =
        :log
        |> Factory.params_for()
        |> Map.put(:block_number, block_number)
        |> Map.put(:address_hash, address_hash)

      params_set = AddressCoinBalances.params_set(%{logs_params: [log_params]})

      assert MapSet.size(params_set) == 1
      assert MapSet.new([%{address_hash: address_hash, block_number: block_number}]) == params_set
    end

    test "with log skips pending transactions" do
      block_number = 1

      address_hash =
        Factory.address_hash()
        |> to_string()

      log_params1 =
        :log
        |> Factory.params_for()
        |> Map.put(:block_number, nil)
        |> Map.put(:address_hash, address_hash)
        |> Map.put(:type, "pending")

      log_params2 =
        :log
        |> Factory.params_for()
        |> Map.put(:block_number, block_number)
        |> Map.put(:address_hash, address_hash)

      params_set = AddressCoinBalances.params_set(%{logs_params: [log_params1, log_params2]})

      assert MapSet.size(params_set) == 1
      assert MapSet.new([%{address_hash: address_hash, block_number: block_number}]) == params_set
    end

    test "with transaction without to_address_hash extracts from_address_hash" do
      block_number = 1

      from_address_hash =
        Factory.address_hash()
        |> to_string()

      transaction_params =
        :transaction
        |> Factory.params_for()
        |> Map.put(:block_number, block_number)
        |> Map.put(:from_address_hash, from_address_hash)

      params_set = AddressCoinBalances.params_set(%{transactions_params: [transaction_params]})

      assert MapSet.size(params_set) == 1
      assert %{address_hash: from_address_hash, block_number: block_number}
    end

    test "with transaction with to_address_hash extracts from_address_hash and to_address_hash" do
      block_number = 1

      from_address_hash =
        Factory.address_hash()
        |> to_string()

      to_address_hash =
        Factory.address_hash()
        |> to_string()

      transaction_params =
        :transaction
        |> Factory.params_for()
        |> Map.put(:block_number, block_number)
        |> Map.put(:from_address_hash, from_address_hash)
        |> Map.put(:to_address_hash, to_address_hash)

      params_set = AddressCoinBalances.params_set(%{transactions_params: [transaction_params]})

      assert MapSet.size(params_set) == 2
      assert %{address_hash: from_address_hash, block_number: block_number}
      assert %{address_hash: to_address_hash, block_number: block_number}
    end
  end
end
