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

  describe "address_to_internal_transactions/1" do
    test "with single transaction containing two internal transactions" do
      address = insert(:address)

      block = insert(:block, number: 2000)

      transaction =
        :transaction
        |> insert()
        |> with_block(block)

      %InternalTransaction{transaction_hash: first_transaction_hash, index: first_index} =
        insert(:internal_transaction,
          index: 1,
          transaction: transaction,
          to_address: address,
          block_number: transaction.block_number,
          block_hash: transaction.block_hash,
          block_index: 1,
          transaction_index: transaction.index
        )

      %InternalTransaction{transaction_hash: second_transaction_hash, index: second_index} =
        insert(:internal_transaction,
          index: 2,
          transaction: transaction,
          to_address: address,
          block_number: transaction.block_number,
          block_hash: transaction.block_hash,
          block_index: 2,
          transaction_index: transaction.index
        )

      result =
        address.hash
        |> InternalTransaction.address_to_internal_transactions()
        |> Enum.map(&{&1.transaction_hash, &1.index})

      assert Enum.member?(result, {first_transaction_hash, first_index})
      assert Enum.member?(result, {second_transaction_hash, second_index})
    end

    test "loads associations in necessity_by_association" do
      %Address{hash: address_hash} = address = insert(:address)
      block = insert(:block, number: 2000)

      transaction =
        :transaction
        |> insert()
        |> with_block(block)

      insert(:internal_transaction,
        transaction: transaction,
        to_address: address,
        index: 0,
        block_number: transaction.block_number,
        block_hash: transaction.block_hash,
        block_index: 0,
        transaction_index: transaction.index
      )

      insert(:internal_transaction,
        transaction: transaction,
        to_address: address,
        index: 1,
        block_number: transaction.block_number,
        block_hash: transaction.block_hash,
        block_index: 1,
        transaction_index: transaction.index
      )

      assert [
               %InternalTransaction{
                 from_address: %Ecto.Association.NotLoaded{},
                 to_address: %Ecto.Association.NotLoaded{},
                 transaction: %Ecto.Association.NotLoaded{}
               }
               | _
             ] = InternalTransaction.address_to_internal_transactions(address_hash)

      assert [
               %InternalTransaction{
                 from_address: %Address{},
                 to_address: %Address{},
                 transaction: %Transaction{}
               }
               | _
             ] =
               InternalTransaction.address_to_internal_transactions(
                 address_hash,
                 necessity_by_association: %{
                   [from_address: :names] => :optional,
                   [to_address: :names] => :optional,
                   :transaction => :optional
                 }
               )
    end

    test "returns results in reverse chronological order by block number, transaction index, internal transaction index" do
      address = insert(:address)

      block = insert(:block, number: 7000)

      pending_transaction =
        :transaction
        |> insert()
        |> with_block(block)

      %InternalTransaction{transaction_hash: first_pending_transaction_hash, index: first_pending_index} =
        insert(
          :internal_transaction,
          transaction: pending_transaction,
          to_address: address,
          index: 1,
          block_number: pending_transaction.block_number,
          block_hash: pending_transaction.block_hash,
          block_index: 1,
          transaction_index: pending_transaction.index
        )

      %InternalTransaction{transaction_hash: second_pending_transaction_hash, index: second_pending_index} =
        insert(
          :internal_transaction,
          transaction: pending_transaction,
          to_address: address,
          index: 2,
          block_number: pending_transaction.block_number,
          block_hash: pending_transaction.block_hash,
          block_index: 2,
          transaction_index: pending_transaction.index
        )

      a_block = insert(:block, number: 2000)

      first_a_transaction =
        :transaction
        |> insert()
        |> with_block(a_block)

      %InternalTransaction{transaction_hash: first_transaction_hash, index: first_index} =
        insert(
          :internal_transaction,
          transaction: first_a_transaction,
          to_address: address,
          index: 1,
          block_number: first_a_transaction.block_number,
          block_hash: a_block.hash,
          block_index: 1,
          transaction_index: first_a_transaction.index
        )

      %InternalTransaction{transaction_hash: second_transaction_hash, index: second_index} =
        insert(
          :internal_transaction,
          transaction: first_a_transaction,
          to_address: address,
          index: 2,
          block_number: first_a_transaction.block_number,
          block_hash: a_block.hash,
          block_index: 2,
          transaction_index: first_a_transaction.index
        )

      second_a_transaction =
        :transaction
        |> insert()
        |> with_block(a_block)

      %InternalTransaction{transaction_hash: third_transaction_hash, index: third_index} =
        insert(
          :internal_transaction,
          transaction: second_a_transaction,
          to_address: address,
          index: 1,
          block_number: second_a_transaction.block_number,
          block_hash: a_block.hash,
          block_index: 4,
          transaction_index: second_a_transaction.index
        )

      %InternalTransaction{transaction_hash: fourth_transaction_hash, index: fourth_index} =
        insert(
          :internal_transaction,
          transaction: second_a_transaction,
          to_address: address,
          index: 2,
          block_number: second_a_transaction.block_number,
          block_hash: a_block.hash,
          block_index: 5,
          transaction_index: second_a_transaction.index
        )

      b_block = insert(:block, number: 6000)

      first_b_transaction =
        :transaction
        |> insert()
        |> with_block(b_block)

      %InternalTransaction{transaction_hash: fifth_transaction_hash, index: fifth_index} =
        insert(
          :internal_transaction,
          transaction: first_b_transaction,
          to_address: address,
          index: 1,
          block_number: first_b_transaction.block_number,
          block_hash: b_block.hash,
          block_index: 1,
          transaction_index: first_b_transaction.index
        )

      %InternalTransaction{transaction_hash: sixth_transaction_hash, index: sixth_index} =
        insert(
          :internal_transaction,
          transaction: first_b_transaction,
          to_address: address,
          index: 2,
          block_number: first_b_transaction.block_number,
          block_hash: b_block.hash,
          block_index: 2,
          transaction_index: first_b_transaction.index
        )

      result =
        address.hash
        |> InternalTransaction.address_to_internal_transactions()
        |> Enum.map(&{&1.transaction_hash, &1.index})

      assert [
               {second_pending_transaction_hash, second_pending_index},
               {first_pending_transaction_hash, first_pending_index},
               {sixth_transaction_hash, sixth_index},
               {fifth_transaction_hash, fifth_index},
               {fourth_transaction_hash, fourth_index},
               {third_transaction_hash, third_index},
               {second_transaction_hash, second_index},
               {first_transaction_hash, first_index}
             ] == result
    end

    test "pages by {block_number, transaction_index, index}" do
      address = insert(:address)

      pending_transaction = insert(:transaction)

      old_block = insert(:block, consensus: false)

      insert(
        :internal_transaction,
        transaction: pending_transaction,
        to_address: address,
        block_hash: old_block.hash,
        block_index: 1,
        index: 1
      )

      insert(
        :internal_transaction,
        transaction: pending_transaction,
        to_address: address,
        block_hash: old_block.hash,
        block_index: 2,
        index: 2
      )

      a_block = insert(:block, number: 2000)

      first_a_transaction =
        :transaction
        |> insert()
        |> with_block(a_block)

      %InternalTransaction{transaction_hash: first_transaction_hash, index: first_index} =
        insert(
          :internal_transaction,
          transaction: first_a_transaction,
          to_address: address,
          index: 1,
          block_number: first_a_transaction.block_number,
          block_hash: a_block.hash,
          block_index: 1,
          transaction_index: first_a_transaction.index
        )

      %InternalTransaction{transaction_hash: second_transaction_hash, index: second_index} =
        insert(
          :internal_transaction,
          transaction: first_a_transaction,
          to_address: address,
          index: 2,
          block_number: first_a_transaction.block_number,
          block_hash: a_block.hash,
          block_index: 2,
          transaction_index: first_a_transaction.index
        )

      second_a_transaction =
        :transaction
        |> insert()
        |> with_block(a_block)

      %InternalTransaction{transaction_hash: third_transaction_hash, index: third_index} =
        insert(
          :internal_transaction,
          transaction: second_a_transaction,
          to_address: address,
          index: 1,
          block_number: second_a_transaction.block_number,
          block_hash: a_block.hash,
          block_index: 4,
          transaction_index: second_a_transaction.index
        )

      %InternalTransaction{transaction_hash: fourth_transaction_hash, index: fourth_index} =
        insert(
          :internal_transaction,
          transaction: second_a_transaction,
          to_address: address,
          index: 2,
          block_number: second_a_transaction.block_number,
          block_hash: a_block.hash,
          block_index: 5,
          transaction_index: second_a_transaction.index
        )

      b_block = insert(:block, number: 6000)

      first_b_transaction =
        :transaction
        |> insert()
        |> with_block(b_block)

      %InternalTransaction{transaction_hash: fifth_transaction_hash, index: fifth_index} =
        insert(
          :internal_transaction,
          transaction: first_b_transaction,
          to_address: address,
          index: 1,
          block_number: first_b_transaction.block_number,
          block_hash: b_block.hash,
          block_index: 1,
          transaction_index: first_b_transaction.index
        )

      %InternalTransaction{transaction_hash: sixth_transaction_hash, index: sixth_index} =
        insert(
          :internal_transaction,
          transaction: first_b_transaction,
          to_address: address,
          index: 2,
          block_number: first_b_transaction.block_number,
          block_hash: b_block.hash,
          block_index: 2,
          transaction_index: first_b_transaction.index
        )

      # When paged, internal transactions need an associated block number, so `second_pending` and `first_pending` are
      # excluded.
      assert [
               {sixth_transaction_hash, sixth_index},
               {fifth_transaction_hash, fifth_index},
               {fourth_transaction_hash, fourth_index},
               {third_transaction_hash, third_index},
               {second_transaction_hash, second_index},
               {first_transaction_hash, first_index}
             ] ==
               address.hash
               |> InternalTransaction.address_to_internal_transactions(
                 paging_options: %PagingOptions{key: {6001, 3, 2}, page_size: 8}
               )
               |> Enum.map(&{&1.transaction_hash, &1.index})

      # block number ==, transaction index ==, internal transaction index <
      assert [
               {fourth_transaction_hash, fourth_index},
               {third_transaction_hash, third_index},
               {second_transaction_hash, second_index},
               {first_transaction_hash, first_index}
             ] ==
               address.hash
               |> InternalTransaction.address_to_internal_transactions(
                 paging_options: %PagingOptions{key: {6000, 0, 1}, page_size: 8}
               )
               |> Enum.map(&{&1.transaction_hash, &1.index})

      # block number ==, transaction index <
      assert [
               {fourth_transaction_hash, fourth_index},
               {third_transaction_hash, third_index},
               {second_transaction_hash, second_index},
               {first_transaction_hash, first_index}
             ] ==
               address.hash
               |> InternalTransaction.address_to_internal_transactions(
                 paging_options: %PagingOptions{key: {6000, -1, -1}, page_size: 8}
               )
               |> Enum.map(&{&1.transaction_hash, &1.index})

      # block number <
      assert [] ==
               address.hash
               |> InternalTransaction.address_to_internal_transactions(
                 paging_options: %PagingOptions{key: {2000, -1, -1}, page_size: 8}
               )
               |> Enum.map(&{&1.transaction_hash, &1.index})
    end

    test "excludes internal transactions of type `call` when they are alone in the parent transaction" do
      %Address{hash: address_hash} = address = insert(:address)

      transaction =
        :transaction
        |> insert(to_address: address)
        |> with_block()

      insert(:internal_transaction,
        index: 0,
        to_address: address,
        transaction: transaction,
        block_number: transaction.block_number,
        block_hash: transaction.block_hash,
        block_index: 0,
        transaction_index: transaction.index
      )

      assert Enum.empty?(InternalTransaction.address_to_internal_transactions(address_hash))
    end

    test "includes internal transactions of type `create` even when they are alone in the parent transaction" do
      %Address{hash: address_hash} = address = insert(:address)

      transaction =
        :transaction
        |> insert(to_address: address)
        |> with_block()

      expected =
        insert(
          :internal_transaction_create,
          index: 0,
          from_address: address,
          transaction: transaction,
          block_hash: transaction.block_hash,
          block_index: 0,
          block_number: transaction.block_number,
          transaction_index: transaction.index
        )

      actual = Enum.at(InternalTransaction.address_to_internal_transactions(address_hash), 0)

      assert {actual.transaction_hash, actual.index} == {expected.transaction_hash, expected.index}
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
