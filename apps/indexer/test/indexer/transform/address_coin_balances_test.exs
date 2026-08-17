# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Indexer.Transform.AddressCoinBalancesTest do
  use Explorer.DataCase, async: true

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

    test "with call internal transaction extracts from_address_hash and to_address_hash" do
      block_number = 1
      from_address_hash = to_string(Factory.address_hash())
      to_address_hash = to_string(Factory.address_hash())

      internal_transaction_params =
        :internal_transaction
        |> Factory.params_for()
        |> Map.put(:type, "call")
        |> Map.put(:call_type, "call")
        |> Map.put(:block_number, block_number)
        |> Map.put(:from_address_hash, from_address_hash)
        |> Map.put(:to_address_hash, to_address_hash)

      params_set = AddressCoinBalances.params_set(%{internal_transactions_params: [internal_transaction_params]})

      assert MapSet.size(params_set) == 2
      assert MapSet.member?(params_set, %{address_hash: from_address_hash, block_number: block_number})
      assert MapSet.member?(params_set, %{address_hash: to_address_hash, block_number: block_number})
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

      assert MapSet.size(params_set) == 2
      assert MapSet.member?(params_set, %{address_hash: created_contract_address_hash, block_number: block_number})
    end

    test "with create2 internal transaction without error extracts created_contract_address_hash and from_address_hash" do
      block_number = 1

      created_contract_address_hash =
        Factory.address_hash()
        |> to_string()

      from_address_hash =
        Factory.address_hash()
        |> to_string()

      internal_transaction_params =
        :internal_transaction_create
        |> Factory.params_for()
        |> Map.put(:type, "create2")
        |> Map.put(:block_number, block_number)
        |> Map.put(:created_contract_address_hash, created_contract_address_hash)
        |> Map.put(:from_address_hash, from_address_hash)

      params_set = AddressCoinBalances.params_set(%{internal_transactions_params: [internal_transaction_params]})

      assert MapSet.size(params_set) == 2
      assert MapSet.member?(params_set, %{address_hash: created_contract_address_hash, block_number: block_number})
      assert MapSet.member?(params_set, %{address_hash: from_address_hash, block_number: block_number})
    end

    test "ignores call internal transaction with call type that does not change balances" do
      block_number = 1

      from_address_hash =
        Factory.address_hash()
        |> to_string()

      internal_transaction_params =
        :internal_transaction
        |> Factory.params_for()
        |> Map.put(:type, "call")
        |> Map.put(:call_type, "staticcall")
        |> Map.put(:block_number, block_number)
        |> Map.put(:from_address_hash, from_address_hash)

      params_set = AddressCoinBalances.params_set(%{internal_transactions_params: [internal_transaction_params]})

      assert MapSet.size(params_set) == 0
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
      assert MapSet.member?(params_set, %{address_hash: from_address_hash, block_number: block_number})
      assert MapSet.member?(params_set, %{address_hash: to_address_hash, block_number: block_number})
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
        |> Map.put(:first_topic, nil)

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
        |> Map.put(:first_topic, nil)
        |> Map.put(:type, "pending")

      log_params2 =
        :log
        |> Factory.params_for()
        |> Map.put(:block_number, block_number)
        |> Map.put(:address_hash, address_hash)
        |> Map.put(:first_topic, nil)

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
      assert MapSet.member?(params_set, %{address_hash: from_address_hash, block_number: block_number})
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
      assert MapSet.member?(params_set, %{address_hash: from_address_hash, block_number: block_number})
      assert MapSet.member?(params_set, %{address_hash: to_address_hash, block_number: block_number})
    end
  end

  if Application.compile_env(:explorer, :chain_type) == :eden do
    describe "params_set/1 transactions_params on Eden chain" do
      test "with sponsored transaction extracts fee_payer_address_hash" do
        block_number = 1

        from_address_hash = to_string(Factory.address_hash())
        fee_payer_address_hash = to_string(Factory.address_hash())

        transaction_params =
          :transaction
          |> Factory.params_for()
          |> Map.put(:block_number, block_number)
          |> Map.put(:from_address_hash, from_address_hash)
          |> Map.put(:fee_payer_address_hash, fee_payer_address_hash)

        params_set = AddressCoinBalances.params_set(%{transactions_params: [transaction_params]})

        assert MapSet.size(params_set) == 2
        assert MapSet.member?(params_set, %{address_hash: from_address_hash, block_number: block_number})
        assert MapSet.member?(params_set, %{address_hash: fee_payer_address_hash, block_number: block_number})
      end

      test "with sponsored transaction extracts the recipients of the batched calls" do
        block_number = 1

        from_address_hash = to_string(Factory.address_hash())
        fee_payer_address_hash = to_string(Factory.address_hash())
        first_call_address_hash = to_string(Factory.address_hash())
        second_call_address_hash = to_string(Factory.address_hash())

        transaction_params =
          :transaction
          |> Factory.params_for()
          |> Map.put(:block_number, block_number)
          |> Map.put(:from_address_hash, from_address_hash)
          |> Map.put(:fee_payer_address_hash, fee_payer_address_hash)
          |> Map.put(:calls, [
            %{"to" => first_call_address_hash, "value" => 1, "input" => "0x"},
            %{"to" => second_call_address_hash, "value" => 2, "input" => "0x"},
            %{"to" => nil, "value" => 3, "input" => "0xc0ffee"},
            %{"to" => "0xdeadbeef", "value" => 4, "input" => "0x"},
            %{"to" => 12_345, "value" => 5, "input" => "0x"}
          ])

        params_set = AddressCoinBalances.params_set(%{transactions_params: [transaction_params]})

        assert MapSet.size(params_set) == 4
        assert MapSet.member?(params_set, %{address_hash: from_address_hash, block_number: block_number})
        assert MapSet.member?(params_set, %{address_hash: fee_payer_address_hash, block_number: block_number})
        assert MapSet.member?(params_set, %{address_hash: first_call_address_hash, block_number: block_number})
        assert MapSet.member?(params_set, %{address_hash: second_call_address_hash, block_number: block_number})
      end

      test "with regular transaction extracts nothing extra" do
        block_number = 1

        from_address_hash = to_string(Factory.address_hash())

        transaction_params =
          :transaction
          |> Factory.params_for()
          |> Map.put(:block_number, block_number)
          |> Map.put(:from_address_hash, from_address_hash)
          |> Map.put(:fee_payer_address_hash, nil)
          |> Map.put(:calls, nil)

        params_set = AddressCoinBalances.params_set(%{transactions_params: [transaction_params]})

        assert MapSet.size(params_set) == 1
        assert MapSet.member?(params_set, %{address_hash: from_address_hash, block_number: block_number})
      end
    end
  end

  if Application.compile_env(:explorer, :chain_type) == :arc do
    describe "params_set/1 logs_params on Arc chain" do
      test "with EIP-7708 Transfer queues non-burn from_address and to_address for coin balances" do
        from_address = "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        to_address = "0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

        logs_params = [
          %{
            block_number: 100,
            address_hash: Explorer.Chain.TokenTransfer.eip7708_system_address(),
            first_topic: Explorer.Chain.TokenTransfer.constant(),
            second_topic: "0x000000000000000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            third_topic: "0x000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
          },
          %{
            block_number: 101,
            address_hash: Explorer.Chain.TokenTransfer.eip7708_system_address(),
            first_topic: Explorer.Chain.TokenTransfer.constant(),
            second_topic: "0x0000000000000000000000000000000000000000000000000000000000000000",
            third_topic: "0x000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
          },
          %{
            block_number: 102,
            address_hash: Explorer.Chain.TokenTransfer.eip7708_system_address(),
            first_topic: Explorer.Chain.TokenTransfer.constant(),
            second_topic: "0x000000000000000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            third_topic: "0x0000000000000000000000000000000000000000000000000000000000000000"
          }
        ]

        params_set = AddressCoinBalances.params_set(%{logs_params: logs_params})

        assert MapSet.member?(params_set, %{address_hash: from_address, block_number: 100})
        assert MapSet.member?(params_set, %{address_hash: to_address, block_number: 100})
        assert MapSet.member?(params_set, %{address_hash: to_address, block_number: 101})
        assert MapSet.member?(params_set, %{address_hash: from_address, block_number: 102})
        assert MapSet.size(params_set) == 4
      end
    end
  end
end
