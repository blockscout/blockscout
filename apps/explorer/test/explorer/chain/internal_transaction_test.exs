defmodule Explorer.Chain.InternalTransactionTest do
  use Explorer.DataCase
  use EthereumJSONRPC.Case

  import EthereumJSONRPC, only: [integer_to_quantity: 1]
  import Mox

  alias Explorer.Chain
  alias Explorer.Chain.{Address, Block, Data, InternalTransaction, Transaction, Wei}
  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Chain.InternalTransaction.Type
  alias Explorer.PagingOptions

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
          transaction_index: 0,
          type: "call",
          value: 100,
          block_number: 35,
          block_hash: "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd"
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
          block_hash: "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd"
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
          transaction_index: transaction.index
        )

      second =
        insert(:internal_transaction,
          transaction: transaction,
          index: 1,
          block_hash: transaction.block_hash,
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
          transaction_index: transaction.index
        )

      %InternalTransaction{transaction_hash: transaction_hash_1, index: index_1} =
        insert(:internal_transaction,
          transaction: transaction,
          index: 1,
          block_number: transaction.block_number,
          block_hash: transaction.block_hash,
          transaction_index: transaction.index
        )

      %InternalTransaction{transaction_hash: transaction_hash_2, index: index_2} =
        insert(:internal_transaction,
          transaction: transaction,
          index: 2,
          block_number: transaction.block_number,
          block_hash: transaction.block_hash,
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
          transaction_index: transaction.index
        )

      %InternalTransaction{transaction_hash: second_transaction_hash, index: second_index} =
        insert(:internal_transaction,
          transaction: transaction,
          index: 1,
          block_number: transaction.block_number,
          block_hash: transaction.block_hash,
          transaction_index: transaction.index
        )

      %InternalTransaction{transaction_hash: third_transaction_hash, index: third_index} =
        insert(:internal_transaction,
          transaction: transaction,
          index: 2,
          block_number: transaction.block_number,
          block_hash: transaction.block_hash,
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
          transaction_index: transaction.index
        )

      second =
        insert(:internal_transaction,
          transaction: transaction,
          index: 1,
          block_hash: transaction.block_hash,
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
          transaction_index: transaction.index
        )

      %InternalTransaction{transaction_hash: second_transaction_hash, index: second_index} =
        insert(:internal_transaction,
          transaction: transaction,
          index: 1,
          block_number: transaction.block_number,
          block_hash: transaction.block_hash,
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
          transaction_index: transaction.index
        )

      %InternalTransaction{transaction_hash: second_transaction_hash, index: second_index} =
        insert(:internal_transaction,
          transaction: transaction,
          index: 1,
          block_number: transaction.block_number,
          block_hash: transaction.block_hash,
          transaction_index: transaction.index
        )

      %InternalTransaction{transaction_hash: third_transaction_hash, index: third_index} =
        insert(:internal_transaction,
          transaction: transaction,
          index: 2,
          block_number: transaction.block_number,
          block_hash: transaction.block_hash,
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
          transaction_index: transaction.index
        )

      %InternalTransaction{transaction_hash: second_transaction_hash, index: second_index} =
        insert(:internal_transaction,
          index: 2,
          transaction: transaction,
          to_address: address,
          block_number: transaction.block_number,
          block_hash: transaction.block_hash,
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
        transaction_index: transaction.index
      )

      insert(:internal_transaction,
        transaction: transaction,
        to_address: address,
        index: 1,
        block_number: transaction.block_number,
        block_hash: transaction.block_hash,
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
          block_number: transaction.block_number,
          transaction_index: transaction.index
        )

      actual = Enum.at(InternalTransaction.address_to_internal_transactions(address_hash), 0)

      assert {actual.transaction_hash, actual.index} == {expected.transaction_hash, expected.index}
    end
  end

  describe "fetch/1" do
    # todo: This test is temporarily disabled because this check is removed for the sake of performance:
    # |> where([internal_transaction, transaction], transaction.block_hash == internal_transaction.block_hash)
    # Return the test back when reorg data will be moved out from the main tables.
    #   test "with consensus transactions and blocks only" do
    #     BackgroundMigrations.set_transactions_denormalization_finished(true)
    #     block_non_consensus = insert(:block, number: 2000, consensus: false)
    #     block_consensus = insert(:block, number: 3000)

    #     transaction =
    #       :transaction
    #       |> insert()
    #       |> with_block(block_consensus)

    #     insert(:internal_transaction,
    #       index: 1,
    #       transaction: transaction,
    #       block_number: transaction.block_number,
    #       block_hash: block_non_consensus.hash,
    #       transaction_index: transaction.index
    #     )

    #     consensus_it =
    #       insert(:internal_transaction,
    #         index: 2,
    #         transaction: transaction,
    #         block_number: transaction.block_number,
    #         block_hash: block_consensus.hash,
    #         transaction_index: transaction.index
    #       )

    #     assert [{consensus_it.transaction_hash, consensus_it.index, consensus_it.block_hash}] ==
    #              []
    #              |> InternalTransaction.fetch()
    #              |> Enum.map(&{&1.transaction_hash, &1.index, &1.block_hash})
    #   end
  end

  describe "fetch_first_trace/2" do
    test "fetched first trace", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      from_address_hash = "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca"
      gas = 4_533_872

      init =
        "0x6060604052341561000f57600080fd5b60405160208061071a83398101604052808051906020019091905050806000806101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff1602179055506003600160006001600281111561007e57fe5b60ff1660ff168152602001908152602001600020819055506002600160006002808111156100a857fe5b60ff1660ff168152602001908152602001600020819055505061064a806100d06000396000f30060606040526004361061008e576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff168063247b3210146100935780632ffdfc8a146100bc57806374294144146100f6578063ae4b1b5b14610125578063bf7370d11461017a578063d1104cb2146101a3578063eecd1079146101f8578063fcff021c14610221575b600080fd5b341561009e57600080fd5b6100a661024a565b6040518082815260200191505060405180910390f35b34156100c757600080fd5b6100e0600480803560ff16906020019091905050610253565b6040518082815260200191505060405180910390f35b341561010157600080fd5b610123600480803590602001909190803560ff16906020019091905050610276565b005b341561013057600080fd5b61013861037a565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b341561018557600080fd5b61018d61039f565b6040518082815260200191505060405180910390f35b34156101ae57600080fd5b6101b66104d9565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b341561020357600080fd5b61020b610588565b6040518082815260200191505060405180910390f35b341561022c57600080fd5b6102346105bd565b6040518082815260200191505060405180910390f35b600060c8905090565b6000600160008360ff1660ff168152602001908152602001600020549050919050565b61027e6104d9565b73ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff161415156102b757600080fd5b60008160ff161115156102c957600080fd5b6002808111156102d557fe5b60ff168160ff16111515156102e957600080fd5b6000821180156103125750600160008260ff1660ff168152602001908152602001600020548214155b151561031d57600080fd5b81600160008360ff1660ff168152602001908152602001600020819055508060ff167fe868bbbdd6cd2efcd9ba6e0129d43c349b0645524aba13f8a43bfc7c5ffb0889836040518082815260200191505060405180910390a25050565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b6000806000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16638b8414c46000604051602001526040518163ffffffff167c0100000000000000000000000000000000000000000000000000000000028152600401602060405180830381600087803b151561042f57600080fd5b6102c65a03f1151561044057600080fd5b5050506040518051905090508073ffffffffffffffffffffffffffffffffffffffff16630eaba26a6000604051602001526040518163ffffffff167c0100000000000000000000000000000000000000000000000000000000028152600401602060405180830381600087803b15156104b857600080fd5b6102c65a03f115156104c957600080fd5b5050506040518051905091505090565b60008060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1663a3b3fff16000604051602001526040518163ffffffff167c0100000000000000000000000000000000000000000000000000000000028152600401602060405180830381600087803b151561056857600080fd5b6102c65a03f1151561057957600080fd5b50505060405180519050905090565b60006105b860016105aa600261059c61039f565b6105e590919063ffffffff16565b61060090919063ffffffff16565b905090565b60006105e06105ca61039f565b6105d261024a565b6105e590919063ffffffff16565b905090565b60008082848115156105f357fe5b0490508091505092915050565b600080828401905083811015151561061457fe5b80915050929150505600a165627a7a723058206b7eef2a57eb659d5e77e45ab5bc074e99c6a841921038cdb931e119c6aac46c0029000000000000000000000000862d67cb0773ee3f8ce7ea89b328ffea861ab3ef"

      value = 0
      block_number = 39
      block_hash = "0x74c72ccabcb98b7ebbd7b31de938212b7e8814a002263b6569564e944d88f51f"
      index = 0
      created_contract_address_hash = "0x1e0eaa06d02f965be2dfe0bc9ff52b2d82133461"

      created_contract_code =
        "0x60606040526004361061008e576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff168063247b3210146100935780632ffdfc8a146100bc57806374294144146100f6578063ae4b1b5b14610125578063bf7370d11461017a578063d1104cb2146101a3578063eecd1079146101f8578063fcff021c14610221575b600080fd5b341561009e57600080fd5b6100a661024a565b6040518082815260200191505060405180910390f35b34156100c757600080fd5b6100e0600480803560ff16906020019091905050610253565b6040518082815260200191505060405180910390f35b341561010157600080fd5b610123600480803590602001909190803560ff16906020019091905050610276565b005b341561013057600080fd5b61013861037a565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b341561018557600080fd5b61018d61039f565b6040518082815260200191505060405180910390f35b34156101ae57600080fd5b6101b66104d9565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b341561020357600080fd5b61020b610588565b6040518082815260200191505060405180910390f35b341561022c57600080fd5b6102346105bd565b6040518082815260200191505060405180910390f35b600060c8905090565b6000600160008360ff1660ff168152602001908152602001600020549050919050565b61027e6104d9565b73ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff161415156102b757600080fd5b60008160ff161115156102c957600080fd5b6002808111156102d557fe5b60ff168160ff16111515156102e957600080fd5b6000821180156103125750600160008260ff1660ff168152602001908152602001600020548214155b151561031d57600080fd5b81600160008360ff1660ff168152602001908152602001600020819055508060ff167fe868bbbdd6cd2efcd9ba6e0129d43c349b0645524aba13f8a43bfc7c5ffb0889836040518082815260200191505060405180910390a25050565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b6000806000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16638b8414c46000604051602001526040518163ffffffff167c0100000000000000000000000000000000000000000000000000000000028152600401602060405180830381600087803b151561042f57600080fd5b6102c65a03f1151561044057600080fd5b5050506040518051905090508073ffffffffffffffffffffffffffffffffffffffff16630eaba26a6000604051602001526040518163ffffffff167c0100000000000000000000000000000000000000000000000000000000028152600401602060405180830381600087803b15156104b857600080fd5b6102c65a03f115156104c957600080fd5b5050506040518051905091505090565b60008060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1663a3b3fff16000604051602001526040518163ffffffff167c0100000000000000000000000000000000000000000000000000000000028152600401602060405180830381600087803b151561056857600080fd5b6102c65a03f1151561057957600080fd5b50505060405180519050905090565b60006105b860016105aa600261059c61039f565b6105e590919063ffffffff16565b61060090919063ffffffff16565b905090565b60006105e06105ca61039f565b6105d261024a565b6105e590919063ffffffff16565b905090565b60008082848115156105f357fe5b0490508091505092915050565b600080828401905083811015151561061457fe5b80915050929150505600a165627a7a723058206b7eef2a57eb659d5e77e45ab5bc074e99c6a841921038cdb931e119c6aac46c0029"

      gas_used = 382_953
      trace_address = []
      transaction_hash = "0x0fa6f723216dba694337f9bb37d8870725655bdf2573526a39454685659e39b1"
      transaction_index = 0
      type = "create"

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        expect(EthereumJSONRPC.Mox, :json_rpc, fn _json, _options ->
          {:ok,
           [
             %{
               id: 0,
               result: %{
                 "output" => "0x",
                 "stateDiff" => nil,
                 "trace" => [
                   %{
                     "action" => %{
                       "from" => from_address_hash,
                       "gas" => integer_to_quantity(gas),
                       "init" => init,
                       "value" => integer_to_quantity(value)
                     },
                     "blockNumber" => block_number,
                     "index" => index,
                     "result" => %{
                       "address" => created_contract_address_hash,
                       "code" => created_contract_code,
                       "gasUsed" => integer_to_quantity(gas_used)
                     },
                     "traceAddress" => trace_address,
                     "type" => type
                   }
                 ],
                 "transactionHash" => transaction_hash
               }
             }
           ]}
        end)
      end

      {:ok, created_contract_address_hash_bytes} = Chain.string_to_address_hash(created_contract_address_hash)
      {:ok, from_address_hash_bytes} = Chain.string_to_address_hash(from_address_hash)
      {:ok, created_contract_code_bytes} = Data.cast(created_contract_code)
      {:ok, init_bytes} = Data.cast(init)
      {:ok, transaction_hash_bytes} = Chain.string_to_full_hash(transaction_hash)
      {:ok, type_bytes} = Type.load(type)
      value_wei = %Wei{value: Decimal.new(value)}

      assert InternalTransaction.fetch_first_trace(
               [
                 %{
                   hash_data: transaction_hash,
                   block_hash: block_hash,
                   block_number: block_number,
                   transaction_index: transaction_index
                 }
               ],
               json_rpc_named_arguments
             ) == {
               :ok,
               [
                 %{
                   block_number: block_number,
                   block_hash: block_hash,
                   call_type: nil,
                   created_contract_address_hash: created_contract_address_hash_bytes,
                   created_contract_code: created_contract_code_bytes,
                   from_address_hash: from_address_hash_bytes,
                   gas: gas,
                   gas_used: gas_used,
                   index: index,
                   init: init_bytes,
                   input: nil,
                   output: nil,
                   to_address_hash: nil,
                   trace_address: trace_address,
                   transaction_hash: transaction_hash_bytes,
                   type: type_bytes,
                   value: value_wei,
                   transaction_index: transaction_index
                 }
               ]
             }
    end
  end
end
