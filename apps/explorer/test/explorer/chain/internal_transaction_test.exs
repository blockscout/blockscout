defmodule Explorer.Chain.InternalTransactionTest do
  use Explorer.DataCase

  alias Explorer.Chain.{Address, Block, Data, InternalTransaction, Transaction, Wei}
  alias Explorer.Factory
  alias Explorer.PagingOptions

  import EthereumJSONRPC, only: [integer_to_quantity: 1]

  doctest InternalTransaction

  describe "changeset/2" do
    test "with valid attributes" do
      transaction = insert(:transaction)

      changeset =
        InternalTransaction.changeset(%InternalTransaction{}, %{
          call_type: "call",
          from_address_hash: "0xa94f5374fce5edbc8e2a8697c15331677e6ebf0b",
          gas: 100,
          gas_used: 100,
          index: 0,
          input: "0x70696e746f73",
          output: "0x72656672696564",
          to_address_hash: "0x6295ee1b4f6dd65047762f924ecd367c17eabf8f",
          trace_address: [0, 1],
          transaction_hash: transaction.hash,
          type: "call",
          value: 100,
          block_number: 35,
          block_hash: "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
          block_index: 0
        })

      assert changeset.valid?
    end

    test "with invalid attributes" do
      changeset = InternalTransaction.changeset(%InternalTransaction{}, %{falala: "falafel"})
      refute changeset.valid?
    end

    test "that a valid changeset is persistable" do
      transaction = insert(:transaction)

      changeset =
        InternalTransaction.changeset(%InternalTransaction{}, %{
          call_type: "call",
          gas: 100,
          gas_used: 100,
          index: 0,
          input: "thin-mints",
          output: "munchos",
          trace_address: [0, 1],
          transaction: transaction,
          type: "call",
          value: 100
        })

      assert Repo.insert(changeset)
    end

    test "with stop type" do
      transaction = insert(:transaction)

      changeset =
        InternalTransaction.changeset(%InternalTransaction{}, %{
          from_address_hash: "0x0000000000000000000000000000000000000000",
          gas: 0,
          gas_used: 22234,
          index: 0,
          input: "0x",
          trace_address: [],
          transaction_hash: transaction.hash,
          transaction_index: 0,
          type: "stop",
          error: "execution stopped",
          value: 0,
          block_number: 35,
          block_hash: "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
          block_index: 0
        })

      assert changeset.valid?
    end
  end

  describe "transaction_to_internal_transactions/1" do
    test "with transaction without internal transactions" do
      transaction = insert(:transaction)

      assert [] = InternalTransaction.transaction_to_internal_transactions(transaction.hash)
    end

    test "with transaction with internal transactions returns all internal transactions for a given transaction hash excluding parent trace" do
      block = insert(:block)

      transaction =
        :transaction
        |> insert()
        |> with_block(block)

      first =
        insert(:internal_transaction,
          transaction: transaction,
          index: 0,
          block_number: transaction.block_number,
          block_hash: transaction.block_hash,
          block_index: 0,
          transaction_index: transaction.index
        )

      second =
        insert(:internal_transaction,
          transaction: transaction,
          index: 1,
          block_hash: transaction.block_hash,
          block_index: 1,
          block_number: transaction.block_number,
          transaction_index: transaction.index
        )

      results = [internal_transaction | _] = InternalTransaction.transaction_to_internal_transactions(transaction.hash)

      # excluding of internal transactions with type=call and index=0
      assert 1 == length(results)

      assert Enum.all?(
               results,
               &({&1.transaction_hash, &1.index} in [
                   {first.transaction_hash, first.index},
                   {second.transaction_hash, second.index}
                 ])
             )

      assert internal_transaction.block_number == block.number
    end

    test "with transaction with internal transactions loads associations with in necessity_by_association" do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(:internal_transaction_create,
        transaction: transaction,
        index: 0,
        block_number: transaction.block_number,
        block_hash: transaction.block_hash,
        block_index: 0,
        transaction_index: transaction.index
      )

      assert [
               %InternalTransaction{
                 from_address: %Ecto.Association.NotLoaded{},
                 to_address: %Ecto.Association.NotLoaded{},
                 transaction: %Ecto.Association.NotLoaded{}
               }
             ] = InternalTransaction.transaction_to_internal_transactions(transaction.hash)

      assert [
               %InternalTransaction{
                 from_address: %Address{},
                 to_address: nil,
                 transaction: %Transaction{block: %Block{}}
               }
             ] =
               InternalTransaction.transaction_to_internal_transactions(
                 transaction.hash,
                 necessity_by_association: %{
                   :from_address => :optional,
                   :to_address => :optional,
                   [transaction: :block] => :optional
                 }
               )
    end

    test "excludes internal transaction of type call with no siblings in the transaction" do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(:internal_transaction,
        transaction: transaction,
        index: 0,
        block_number: transaction.block_number,
        block_hash: transaction.block_hash,
        block_index: 0,
        transaction_index: transaction.index
      )

      result = InternalTransaction.transaction_to_internal_transactions(transaction.hash)

      assert Enum.empty?(result)
    end

    test "includes internal transactions of type `create` even when they are alone in the parent transaction" do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      expected =
        insert(:internal_transaction_create,
          index: 0,
          transaction: transaction,
          block_number: transaction.block_number,
          block_hash: transaction.block_hash,
          block_index: 0,
          transaction_index: transaction.index
        )

      actual = Enum.at(InternalTransaction.transaction_to_internal_transactions(transaction.hash), 0)

      assert {actual.transaction_hash, actual.index} == {expected.transaction_hash, expected.index}
    end

    test "includes internal transactions of type `reward` even when they are alone in the parent transaction" do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      expected =
        insert(:internal_transaction,
          index: 0,
          transaction: transaction,
          type: :reward,
          block_number: transaction.block_number,
          block_hash: transaction.block_hash,
          block_index: 0,
          transaction_index: transaction.index
        )

      actual = Enum.at(InternalTransaction.transaction_to_internal_transactions(transaction.hash), 0)

      assert {actual.transaction_hash, actual.index} == {expected.transaction_hash, expected.index}
    end

    test "includes internal transactions of type `selfdestruct` even when they are alone in the parent transaction" do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      expected =
        insert(:internal_transaction,
          index: 0,
          transaction: transaction,
          gas: nil,
          type: :selfdestruct,
          block_number: transaction.block_number,
          block_hash: transaction.block_hash,
          block_index: 0,
          transaction_index: transaction.index
        )

      actual = Enum.at(InternalTransaction.transaction_to_internal_transactions(transaction.hash), 0)

      assert {actual.transaction_hash, actual.index} == {expected.transaction_hash, expected.index}
    end

    test "returns the internal transactions in ascending index order" do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      %InternalTransaction{transaction_hash: _, index: _} =
        insert(:internal_transaction,
          transaction: transaction,
          index: 0,
          block_number: transaction.block_number,
          block_hash: transaction.block_hash,
          block_index: 0,
          transaction_index: transaction.index
        )

      %InternalTransaction{transaction_hash: transaction_hash_1, index: index_1} =
        insert(:internal_transaction,
          transaction: transaction,
          index: 1,
          block_number: transaction.block_number,
          block_hash: transaction.block_hash,
          block_index: 1,
          transaction_index: transaction.index
        )

      %InternalTransaction{transaction_hash: transaction_hash_2, index: index_2} =
        insert(:internal_transaction,
          transaction: transaction,
          index: 2,
          block_number: transaction.block_number,
          block_hash: transaction.block_hash,
          block_index: 2,
          transaction_index: transaction.index
        )

      result =
        transaction.hash
        |> InternalTransaction.transaction_to_internal_transactions()
        |> Enum.map(&{&1.transaction_hash, &1.index})

      # excluding of internal transactions with type=call and index=0
      assert [{transaction_hash_1, index_1}, {transaction_hash_2, index_2}] == result
    end

    test "pages by index" do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      %InternalTransaction{transaction_hash: _, index: _} =
        insert(:internal_transaction,
          transaction: transaction,
          index: 0,
          block_number: transaction.block_number,
          block_hash: transaction.block_hash,
          block_index: 0,
          transaction_index: transaction.index
        )

      %InternalTransaction{transaction_hash: second_transaction_hash, index: second_index} =
        insert(:internal_transaction,
          transaction: transaction,
          index: 1,
          block_number: transaction.block_number,
          block_hash: transaction.block_hash,
          block_index: 1,
          transaction_index: transaction.index
        )

      %InternalTransaction{transaction_hash: third_transaction_hash, index: third_index} =
        insert(:internal_transaction,
          transaction: transaction,
          index: 2,
          block_number: transaction.block_number,
          block_hash: transaction.block_hash,
          block_index: 2,
          transaction_index: transaction.index
        )

      assert [{second_transaction_hash, second_index}, {third_transaction_hash, third_index}] ==
               transaction.hash
               |> InternalTransaction.transaction_to_internal_transactions(
                 paging_options: %PagingOptions{key: {-1}, page_size: 2}
               )
               |> Enum.map(&{&1.transaction_hash, &1.index})

      assert [{second_transaction_hash, second_index}] ==
               transaction.hash
               |> InternalTransaction.transaction_to_internal_transactions(
                 paging_options: %PagingOptions{key: {-1}, page_size: 1}
               )
               |> Enum.map(&{&1.transaction_hash, &1.index})

      assert [{third_transaction_hash, third_index}] ==
               transaction.hash
               |> InternalTransaction.transaction_to_internal_transactions(
                 paging_options: %PagingOptions{key: {1}, page_size: 2}
               )
               |> Enum.map(&{&1.transaction_hash, &1.index})
    end
  end

  describe "all_transaction_to_internal_transactions/1" do
    test "with transaction without internal transactions" do
      transaction = insert(:transaction)

      assert [] = InternalTransaction.all_transaction_to_internal_transactions(transaction.hash)
    end

    test "with transaction with internal transactions returns all internal transactions for a given transaction hash" do
      block = insert(:block)

      transaction =
        :transaction
        |> insert()
        |> with_block(block)

      first =
        insert(:internal_transaction,
          transaction: transaction,
          index: 0,
          block_number: transaction.block_number,
          block_hash: transaction.block_hash,
          block_index: 0,
          transaction_index: transaction.index
        )

      second =
        insert(:internal_transaction,
          transaction: transaction,
          index: 1,
          block_hash: transaction.block_hash,
          block_index: 1,
          block_number: transaction.block_number,
          transaction_index: transaction.index
        )

      results =
        [internal_transaction | _] = InternalTransaction.all_transaction_to_internal_transactions(transaction.hash)

      assert 2 == length(results)

      assert Enum.all?(
               results,
               &({&1.transaction_hash, &1.index} in [
                   {first.transaction_hash, first.index},
                   {second.transaction_hash, second.index}
                 ])
             )

      assert internal_transaction.block_number == block.number
    end

    test "with transaction with internal transactions loads associations with in necessity_by_association" do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(:internal_transaction_create,
        transaction: transaction,
        index: 0,
        block_number: transaction.block_number,
        block_hash: transaction.block_hash,
        block_index: 0,
        transaction_index: transaction.index
      )

      assert [
               %InternalTransaction{
                 from_address: %Ecto.Association.NotLoaded{},
                 to_address: %Ecto.Association.NotLoaded{},
                 transaction: %Ecto.Association.NotLoaded{}
               }
             ] = InternalTransaction.all_transaction_to_internal_transactions(transaction.hash)

      assert [
               %InternalTransaction{
                 from_address: %Address{},
                 to_address: nil,
                 transaction: %Transaction{block: %Block{}}
               }
             ] =
               InternalTransaction.all_transaction_to_internal_transactions(
                 transaction.hash,
                 necessity_by_association: %{
                   :from_address => :optional,
                   :to_address => :optional,
                   [transaction: :block] => :optional
                 }
               )
    end

    test "not excludes internal transaction of type call with no siblings in the transaction" do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(:internal_transaction,
        transaction: transaction,
        index: 0,
        block_number: transaction.block_number,
        block_hash: transaction.block_hash,
        block_index: 0,
        transaction_index: transaction.index
      )

      result = InternalTransaction.all_transaction_to_internal_transactions(transaction.hash)

      assert Enum.empty?(result) == false
    end

    test "includes internal transactions of type `create` even when they are alone in the parent transaction" do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      expected =
        insert(:internal_transaction_create,
          index: 0,
          transaction: transaction,
          block_number: transaction.block_number,
          block_hash: transaction.block_hash,
          block_index: 0,
          transaction_index: transaction.index
        )

      actual = Enum.at(InternalTransaction.all_transaction_to_internal_transactions(transaction.hash), 0)

      assert {actual.transaction_hash, actual.index} == {expected.transaction_hash, expected.index}
    end

    test "includes internal transactions of type `reward` even when they are alone in the parent transaction" do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      expected =
        insert(:internal_transaction,
          index: 0,
          transaction: transaction,
          type: :reward,
          block_number: transaction.block_number,
          block_hash: transaction.block_hash,
          block_index: 0,
          transaction_index: transaction.index
        )

      actual = Enum.at(InternalTransaction.all_transaction_to_internal_transactions(transaction.hash), 0)

      assert {actual.transaction_hash, actual.index} == {expected.transaction_hash, expected.index}
    end

    test "includes internal transactions of type `selfdestruct` even when they are alone in the parent transaction" do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      expected =
        insert(:internal_transaction,
          index: 0,
          transaction: transaction,
          gas: nil,
          type: :selfdestruct,
          block_number: transaction.block_number,
          block_hash: transaction.block_hash,
          block_index: 0,
          transaction_index: transaction.index
        )

      actual = Enum.at(InternalTransaction.all_transaction_to_internal_transactions(transaction.hash), 0)

      assert {actual.transaction_hash, actual.index} == {expected.transaction_hash, expected.index}
    end

    test "returns the internal transactions in ascending index order" do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      %InternalTransaction{transaction_hash: transaction_hash, index: index} =
        insert(:internal_transaction,
          transaction: transaction,
          index: 0,
          block_number: transaction.block_number,
          block_hash: transaction.block_hash,
          block_index: 0,
          transaction_index: transaction.index
        )

      %InternalTransaction{transaction_hash: second_transaction_hash, index: second_index} =
        insert(:internal_transaction,
          transaction: transaction,
          index: 1,
          block_number: transaction.block_number,
          block_hash: transaction.block_hash,
          block_index: 1,
          transaction_index: transaction.index
        )

      result =
        transaction.hash
        |> InternalTransaction.all_transaction_to_internal_transactions()
        |> Enum.map(&{&1.transaction_hash, &1.index})

      assert [{transaction_hash, index}, {second_transaction_hash, second_index}] == result
    end

    test "pages by index" do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      %InternalTransaction{transaction_hash: transaction_hash, index: index} =
        insert(:internal_transaction,
          transaction: transaction,
          index: 0,
          block_number: transaction.block_number,
          block_hash: transaction.block_hash,
          block_index: 0,
          transaction_index: transaction.index
        )

      %InternalTransaction{transaction_hash: second_transaction_hash, index: second_index} =
        insert(:internal_transaction,
          transaction: transaction,
          index: 1,
          block_number: transaction.block_number,
          block_hash: transaction.block_hash,
          block_index: 1,
          transaction_index: transaction.index
        )

      %InternalTransaction{transaction_hash: third_transaction_hash, index: third_index} =
        insert(:internal_transaction,
          transaction: transaction,
          index: 2,
          block_number: transaction.block_number,
          block_hash: transaction.block_hash,
          block_index: 2,
          transaction_index: transaction.index
        )

      assert [{transaction_hash, index}, {second_transaction_hash, second_index}] ==
               transaction.hash
               |> InternalTransaction.all_transaction_to_internal_transactions(
                 paging_options: %PagingOptions{key: {-1}, page_size: 2}
               )
               |> Enum.map(&{&1.transaction_hash, &1.index})

      assert [{transaction_hash, index}] ==
               transaction.hash
               |> InternalTransaction.all_transaction_to_internal_transactions(
                 paging_options: %PagingOptions{key: {-1}, page_size: 1}
               )
               |> Enum.map(&{&1.transaction_hash, &1.index})

      assert [{third_transaction_hash, third_index}] ==
               transaction.hash
               |> InternalTransaction.all_transaction_to_internal_transactions(
                 paging_options: %PagingOptions{key: {1}, page_size: 2}
               )
               |> Enum.map(&{&1.transaction_hash, &1.index})
    end
  end

  defp call_type(opts) do
    defaults = [
      type: :call,
      call_type: :call,
      to_address_hash: Factory.address_hash(),
      from_address_hash: Factory.address_hash(),
      input: Factory.transaction_input(),
      output: Factory.transaction_input(),
      gas: Decimal.new(50_000),
      gas_used: Decimal.new(25_000),
      value: %Wei{value: 100},
      index: 0,
      trace_address: []
    ]

    struct!(InternalTransaction, Keyword.merge(defaults, opts))
  end

  defp create_type(opts) do
    defaults = [
      type: :create,
      from_address_hash: Factory.address_hash(),
      gas: Decimal.new(50_000),
      gas_used: Decimal.new(25_000),
      value: %Wei{value: 100},
      index: 0,
      init: Factory.transaction_input(),
      trace_address: []
    ]

    struct!(InternalTransaction, Keyword.merge(defaults, opts))
  end

  defp selfdestruct_type(opts) do
    defaults = [
      type: :selfdestruct,
      from_address_hash: Factory.address_hash(),
      to_address_hash: Factory.address_hash(),
      gas: Decimal.new(50_000),
      gas_used: Decimal.new(25_000),
      value: %Wei{value: 100},
      index: 0,
      trace_address: []
    ]

    struct!(InternalTransaction, Keyword.merge(defaults, opts))
  end
end
