defmodule Explorer.EtherscanTest do
  use Explorer.DataCase

  import Explorer.Factory

  alias Explorer.{Etherscan, Chain}
  alias Explorer.Chain.Transaction

  describe "list_transactions/2" do
    test "with empty db" do
      address = build(:address)

      assert Etherscan.list_transactions(address.hash) == []
    end

    test "with from address" do
      address = insert(:address)

      transaction =
        :transaction
        |> insert(from_address: address)
        |> with_block()

      [found_transaction] = Etherscan.list_transactions(address.hash)

      assert transaction.hash == found_transaction.hash
    end

    test "with to address" do
      address = insert(:address)

      transaction =
        :transaction
        |> insert(to_address: address)
        |> with_block()

      [found_transaction] = Etherscan.list_transactions(address.hash)

      assert transaction.hash == found_transaction.hash
    end

    test "with same to and from address" do
      address = insert(:address)

      _transaction =
        :transaction
        |> insert(from_address: address, to_address: address)
        |> with_block()

      found_transactions = Etherscan.list_transactions(address.hash)

      assert length(found_transactions) == 1
    end

    test "with created contract address" do
      address = insert(:address)
      contract_address = insert(:contract_address)

      transaction =
        :transaction
        |> insert(from_address: address, to_address: nil)
        |> with_contract_creation(contract_address)
        |> with_block()

      %{created_contract_address_hash: contract_address_hash} =
        :internal_transaction_create
        |> insert(
          transaction: transaction,
          index: 0,
          block_number: transaction.block_number,
          block_hash: transaction.block_hash,
          block_index: 0,
          transaction_index: transaction.index
        )
        |> with_contract_creation(contract_address)

      [found_transaction] = Etherscan.list_transactions(contract_address_hash)

      assert found_transaction.hash == transaction.hash
    end

    test "with address with 0 transactions" do
      address1 = insert(:address)
      address2 = insert(:address)

      :transaction
      |> insert(from_address: address2)
      |> with_block()

      assert Etherscan.list_transactions(address1.hash) == []
    end

    test "with address with multiple transactions" do
      address1 = insert(:address)
      address2 = insert(:address)

      3
      |> insert_list(:transaction, from_address: address1)
      |> with_block()

      :transaction
      |> insert(from_address: address2)
      |> with_block()

      found_transactions = Etherscan.list_transactions(address1.hash)

      assert length(found_transactions) == 3

      for found_transaction <- found_transactions do
        assert found_transaction.from_address_hash == address1.hash
      end
    end

    test "includes confirmations value" do
      insert(:block)
      address = insert(:address)

      transaction =
        :transaction
        |> insert(from_address: address)
        |> with_block()

      insert(:block)

      [found_transaction] = Etherscan.list_transactions(address.hash)

      block_height = Chain.block_height()
      expected_confirmations = block_height - transaction.block_number

      assert found_transaction.confirmations == expected_confirmations
    end

    test "loads created_contract_address_hash if available" do
      address = insert(:address)
      contract_address = insert(:contract_address)

      transaction =
        :transaction
        |> insert(from_address: address, to_address: nil)
        |> with_contract_creation(contract_address)
        |> with_block()

      %{created_contract_address_hash: contract_hash} =
        :internal_transaction_create
        |> insert(
          transaction: transaction,
          index: 0,
          block_number: transaction.block_number,
          block_hash: transaction.block_hash,
          block_index: 0,
          transaction_index: transaction.index
        )
        |> with_contract_creation(contract_address)

      [found_transaction] = Etherscan.list_transactions(address.hash)

      assert found_transaction.created_contract_address_hash == contract_hash
    end

    test "loads block_timestamp" do
      address = insert(:address)

      %Transaction{block: block} =
        :transaction
        |> insert(from_address: address)
        |> with_block()

      [found_transaction] = Etherscan.list_transactions(address.hash)

      assert found_transaction.block_timestamp == block.timestamp
    end

    test "orders transactions by block, in ascending order (default)" do
      first_block = insert(:block)
      second_block = insert(:block)
      address = insert(:address)

      2
      |> insert_list(:transaction, from_address: address)
      |> with_block(second_block)

      2
      |> insert_list(:transaction, from_address: address)
      |> with_block()

      2
      |> insert_list(:transaction, from_address: address)
      |> with_block(first_block)

      found_transactions = Etherscan.list_transactions(address.hash)

      block_numbers_order = Enum.map(found_transactions, & &1.block_number)

      assert block_numbers_order == Enum.sort(block_numbers_order, &(&1 >= &2))
    end

    test "orders transactions by block, in descending order" do
      first_block = insert(:block)
      second_block = insert(:block)
      address = insert(:address)

      2
      |> insert_list(:transaction, from_address: address)
      |> with_block(second_block)

      2
      |> insert_list(:transaction, from_address: address)
      |> with_block()

      2
      |> insert_list(:transaction, from_address: address)
      |> with_block(first_block)

      options = %{order_by_direction: :desc}

      found_transactions = Etherscan.list_transactions(address.hash, options)

      block_numbers_order = Enum.map(found_transactions, & &1.block_number)

      assert block_numbers_order == Enum.sort(block_numbers_order, &(&1 >= &2))
    end

    test "with page_size and page_number options" do
      first_block = insert(:block)
      second_block = insert(:block)
      third_block = insert(:block)
      address = insert(:address)

      second_block_transactions =
        2
        |> insert_list(:transaction, from_address: address)
        |> with_block(second_block)

      first_block_transactions =
        2
        |> insert_list(:transaction, from_address: address)
        |> with_block(third_block)

      third_block_transactions =
        2
        |> insert_list(:transaction, from_address: address)
        |> with_block(first_block)

      options = %{page_number: 1, page_size: 2}

      page1_transactions = Etherscan.list_transactions(address.hash, options)

      page1_hashes = Enum.map(page1_transactions, & &1.hash)

      assert length(page1_transactions) == 2

      for transaction <- first_block_transactions do
        assert transaction.hash in page1_hashes
      end

      options = %{page_number: 2, page_size: 2}

      page2_transactions = Etherscan.list_transactions(address.hash, options)

      page2_hashes = Enum.map(page2_transactions, & &1.hash)

      assert length(page2_transactions) == 2

      for transaction <- second_block_transactions do
        assert transaction.hash in page2_hashes
      end

      options = %{page_number: 3, page_size: 2}

      page3_transactions = Etherscan.list_transactions(address.hash, options)

      page3_hashes = Enum.map(page3_transactions, & &1.hash)

      assert length(page3_transactions) == 2

      for transaction <- third_block_transactions do
        assert transaction.hash in page3_hashes
      end

      options = %{page_number: 4, page_size: 2}

      assert Etherscan.list_transactions(address.hash, options) == []
    end

    test "with start and end block options" do
      blocks = [_, second_block, third_block, _] = insert_list(4, :block)
      address = insert(:address)

      for block <- blocks do
        2
        |> insert_list(:transaction, from_address: address)
        |> with_block(block)
      end

      options = %{
        start_block: second_block.number,
        end_block: third_block.number
      }

      found_transactions = Etherscan.list_transactions(address.hash, options)

      expected_block_numbers = [second_block.number, third_block.number]

      assert length(found_transactions) == 4

      for transaction <- found_transactions do
        assert transaction.block_number in expected_block_numbers
      end
    end

    test "with start_block but no end_block option" do
      blocks = [_, _, third_block, fourth_block] = insert_list(4, :block)
      address = insert(:address)

      for block <- blocks do
        2
        |> insert_list(:transaction, from_address: address)
        |> with_block(block)
      end

      options = %{
        start_block: third_block.number
      }

      found_transactions = Etherscan.list_transactions(address.hash, options)

      expected_block_numbers = [third_block.number, fourth_block.number]

      assert length(found_transactions) == 4

      for transaction <- found_transactions do
        assert transaction.block_number in expected_block_numbers
      end
    end

    test "with end_block but no start_block option" do
      blocks = [first_block, second_block, _, _] = insert_list(4, :block)
      address = insert(:address)

      for block <- blocks do
        2
        |> insert_list(:transaction, from_address: address)
        |> with_block(block)
      end

      options = %{
        end_block: second_block.number
      }

      found_transactions = Etherscan.list_transactions(address.hash, options)

      expected_block_numbers = [first_block.number, second_block.number]

      assert length(found_transactions) == 4

      for transaction <- found_transactions do
        assert transaction.block_number in expected_block_numbers
      end
    end

    test "with start and end timestamp options" do
      now = Timex.now()
      timestamp1 = Timex.shift(now, hours: -1)
      timestamp2 = Timex.shift(now, hours: -3)
      timestamp3 = Timex.shift(now, hours: -6)
      blocks1 = insert_list(2, :block, timestamp: timestamp1)
      blocks2 = [third_block, fourth_block] = insert_list(2, :block, timestamp: timestamp2)
      blocks3 = insert_list(2, :block, timestamp: timestamp3)
      address = insert(:address)

      for block <- Enum.concat([blocks1, blocks2, blocks3]) do
        2
        |> insert_list(:transaction, from_address: address)
        |> with_block(block)
      end

      start_timestamp = Timex.shift(now, hours: -4)
      end_timestamp = Timex.shift(now, hours: -2)

      options = %{
        start_timestamp: start_timestamp,
        end_timestamp: end_timestamp
      }

      found_transactions = Etherscan.list_transactions(address.hash, options)

      expected_block_numbers = [third_block.number, fourth_block.number]

      assert length(found_transactions) == 4

      for transaction <- found_transactions do
        assert transaction.block_number in expected_block_numbers
      end
    end

    test "with filter_by: 'to' option with one matching transaction" do
      address = insert(:address)
      contract_address = insert(:contract_address)

      :transaction
      |> insert(to_address: address)
      |> with_block()

      :transaction
      |> insert(from_address: address, to_address: nil)
      |> with_contract_creation(contract_address)
      |> with_block()

      options = %{filter_by: "to"}

      found_transactions = Etherscan.list_transactions(address.hash, options)

      assert length(found_transactions) == 1
    end

    test "with filter_by: 'to' option with non-matching transaction" do
      address = insert(:address)
      contract_address = insert(:contract_address)

      :transaction
      |> insert(from_address: address, to_address: nil)
      |> with_contract_creation(contract_address)
      |> with_block()

      options = %{filter_by: "to"}

      found_transactions = Etherscan.list_transactions(address.hash, options)

      assert length(found_transactions) == 0
    end

    test "with filter_by: 'from' option with one matching transaction" do
      address = insert(:address)

      :transaction
      |> insert(to_address: address)
      |> with_block()

      :transaction
      |> insert(from_address: address)
      |> with_block()

      options = %{filter_by: "from"}

      found_transactions = Etherscan.list_transactions(address.hash, options)

      assert length(found_transactions) == 1
    end

    test "with filter_by: 'from' option with non-matching transaction" do
      address = insert(:address)
      other_address = insert(:address)

      :transaction
      |> insert(from_address: other_address, to_address: nil)
      |> with_block()

      options = %{filter_by: "from"}

      found_transactions = Etherscan.list_transactions(address.hash, options)

      assert length(found_transactions) == 0
    end
  end

  describe "list_pending_transactions/2" do
    test "with empty db" do
      address = build(:address)

      assert Etherscan.list_pending_transactions(address.hash) == []
    end

    test "with from address" do
      address = insert(:address)

      transaction =
        :transaction
        |> insert(from_address: address)

      [found_transaction] = Etherscan.list_pending_transactions(address.hash)

      assert transaction.hash == found_transaction.hash
    end

    test "with to address" do
      address = insert(:address)

      transaction =
        :transaction
        |> insert(to_address: address)

      [found_transaction] = Etherscan.list_pending_transactions(address.hash)

      assert transaction.hash == found_transaction.hash
    end

    test "with same to and from address" do
      address = insert(:address)

      _transaction =
        :transaction
        |> insert(from_address: address, to_address: address)

      found_transactions = Etherscan.list_pending_transactions(address.hash)

      assert length(found_transactions) == 1
    end

    test "with address with 0 transactions" do
      address1 = insert(:address)
      address2 = insert(:address)

      :transaction
      |> insert(from_address: address2)

      assert Etherscan.list_pending_transactions(address1.hash) == []
    end

    test "with address with multiple transactions" do
      address1 = insert(:address)
      address2 = insert(:address)

      3
      |> insert_list(:transaction, from_address: address1)

      :transaction
      |> insert(from_address: address2)

      found_transactions = Etherscan.list_pending_transactions(address1.hash)

      assert length(found_transactions) == 3

      for found_transaction <- found_transactions do
        assert found_transaction.from_address_hash == address1.hash
      end
    end

    test "orders transactions by inserted_at, in descending order" do
      address = insert(:address)

      2
      |> insert_list(:transaction, from_address: address)

      2
      |> insert_list(:transaction, from_address: address)

      2
      |> insert_list(:transaction, from_address: address)

      options = %{order_by_direction: :desc}

      found_transactions = Etherscan.list_pending_transactions(address.hash, options)

      inserted_at_order = Enum.map(found_transactions, & &1.inserted_at)

      assert inserted_at_order ==
               Enum.sort(inserted_at_order, &(DateTime.compare(&1, &2) == :gt || DateTime.compare(&1, &2) == :eq))
    end

    test "with page_size and page_number options" do
      address = insert(:address)

      transactions_1 =
        2
        |> insert_list(:transaction, from_address: address)

      transactions_2 =
        2
        |> insert_list(:transaction, from_address: address)

      transactions_3 =
        2
        |> insert_list(:transaction, from_address: address)

      options = %{page_number: 1, page_size: 2}

      page1_transactions = Etherscan.list_pending_transactions(address.hash, options)

      page1_hashes = Enum.map(page1_transactions, & &1.hash)

      assert length(page1_transactions) == 2

      for transaction <- transactions_3 do
        assert transaction.hash in page1_hashes
      end

      options = %{page_number: 2, page_size: 2}

      page2_transactions = Etherscan.list_pending_transactions(address.hash, options)

      page2_hashes = Enum.map(page2_transactions, & &1.hash)

      assert length(page2_transactions) == 2

      for transaction <- transactions_2 do
        assert transaction.hash in page2_hashes
      end

      options = %{page_number: 3, page_size: 2}

      page3_transactions = Etherscan.list_pending_transactions(address.hash, options)

      page3_hashes = Enum.map(page3_transactions, & &1.hash)

      assert length(page3_transactions) == 2

      for transaction <- transactions_1 do
        assert transaction.hash in page3_hashes
      end

      options = %{page_number: 4, page_size: 2}

      assert Etherscan.list_pending_transactions(address.hash, options) == []
    end
  end

  describe "list_internal_transactions/1 with transaction hash" do
    test "with empty db" do
      transaction = build(:transaction)

      assert Etherscan.list_internal_transactions(transaction.hash) == []
    end

    test "response includes all the expected fields" do
      address = insert(:address)
      contract_address = insert(:contract_address)

      block = insert(:block)

      transaction =
        :transaction
        |> insert(from_address: address, to_address: nil)
        |> with_contract_creation(contract_address)
        |> with_block(block)

      internal_transaction =
        :internal_transaction_create
        |> insert(
          transaction: transaction,
          index: 0,
          from_address: address,
          block_number: transaction.block_number,
          block_hash: transaction.block_hash,
          block_index: 0,
          transaction_index: transaction.index
        )
        |> with_contract_creation(contract_address)

      [found_internal_transaction] = Etherscan.list_internal_transactions(transaction.hash)

      assert found_internal_transaction.block_number == block.number
      assert found_internal_transaction.block_timestamp == block.timestamp
      assert found_internal_transaction.from_address_hash == internal_transaction.from_address_hash
      assert found_internal_transaction.to_address_hash == internal_transaction.to_address_hash
      assert found_internal_transaction.value == internal_transaction.value

      assert found_internal_transaction.created_contract_address_hash ==
               internal_transaction.created_contract_address_hash

      assert found_internal_transaction.input == internal_transaction.input
      assert found_internal_transaction.type == internal_transaction.type
      assert found_internal_transaction.gas == internal_transaction.gas
      assert found_internal_transaction.gas_used == internal_transaction.gas_used
      assert found_internal_transaction.error == internal_transaction.error
    end

    test "with transaction with 0 internal transactions" do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      assert Etherscan.list_internal_transactions(transaction.hash) == []
    end

    test "with transaction with multiple internal transactions" do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      for index <- 0..2 do
        insert(:internal_transaction,
          transaction: transaction,
          index: index,
          block_number: transaction.block_number,
          block_hash: transaction.block_hash,
          block_index: index,
          transaction_index: transaction.index
        )
      end

      found_internal_transactions = Etherscan.list_internal_transactions(transaction.hash)

      # excluding of internal transactions with type=call and index=0
      assert length(found_internal_transactions) == 2
    end

    test "only returns internal transactions that belong to the transaction" do
      transaction1 =
        :transaction
        |> insert()
        |> with_block()

      transaction2 =
        :transaction
        |> insert()
        |> with_block()

      insert(:internal_transaction,
        transaction: transaction1,
        index: 0,
        block_number: transaction1.block_number,
        block_hash: transaction1.block_hash,
        block_index: 0,
        transaction_index: transaction1.index
      )

      insert(:internal_transaction,
        transaction: transaction1,
        index: 1,
        block_number: transaction1.block_number,
        block_hash: transaction1.block_hash,
        block_index: 1,
        transaction_index: transaction1.index
      )

      insert(:internal_transaction,
        transaction: transaction2,
        index: 0,
        type: :reward,
        block_number: transaction2.block_number,
        block_hash: transaction2.block_hash,
        block_index: 2,
        transaction_index: transaction2.index
      )

      internal_transactions1 = Etherscan.list_internal_transactions(transaction1.hash)

      # excluding of internal transactions with type=call and index=0
      assert length(internal_transactions1) == 1

      internal_transactions2 = Etherscan.list_internal_transactions(transaction2.hash)

      assert length(internal_transactions2) == 1
    end

    # Note that `list_internal_transactions/1` relies on
    # `Chain.where_transaction_has_multiple_transactions/1` to ensure the
    # following behavior:
    #
    # * exclude internal transactions of type call with no siblings in the
    #   transaction
    #
    # * include internal transactions of type create, reward, or suicide
    #   even when they are alone in the parent transaction
    #
    # These two requirements are tested in `Explorer.ChainTest`.
  end

  describe "list_internal_transactions/2 with address hash" do
    test "with empty db" do
      address = build(:address)

      assert Etherscan.list_internal_transactions(address.hash) == []
    end

    test "response includes all the expected fields" do
      address = insert(:address)
      contract_address = insert(:contract_address)

      block = insert(:block)

      transaction =
        :transaction
        |> insert(from_address: address, to_address: nil)
        |> with_contract_creation(contract_address)
        |> with_block(block)

      internal_transaction =
        :internal_transaction_create
        |> insert(
          transaction: transaction,
          index: 0,
          from_address: address,
          block_number: transaction.block_number,
          block_hash: block.hash,
          block_index: 0,
          transaction_index: transaction.index
        )
        |> with_contract_creation(contract_address)

      [found_internal_transaction] = Etherscan.list_internal_transactions(address.hash)

      expected = %{
        block_number: block.number,
        block_timestamp: block.timestamp,
        from_address_hash: internal_transaction.from_address_hash,
        to_address_hash: internal_transaction.to_address_hash,
        value: internal_transaction.value,
        created_contract_address_hash: internal_transaction.created_contract_address_hash,
        input: internal_transaction.input,
        index: internal_transaction.index,
        transaction_hash: internal_transaction.transaction_hash,
        type: internal_transaction.type,
        gas: internal_transaction.gas,
        gas_used: internal_transaction.gas_used,
        error: internal_transaction.error
      }

      assert found_internal_transaction == expected
    end

    test "with address with 0 internal transactions" do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      assert Etherscan.list_internal_transactions(transaction.from_address_hash) == []
    end

    test "with address with multiple internal transactions" do
      address = insert(:address)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      for index <- 0..3 do
        internal_transaction_details = %{
          transaction: transaction,
          index: index,
          from_address: address,
          block_number: transaction.block_number,
          block_hash: transaction.block_hash,
          block_index: index,
          transaction_index: transaction.index
        }

        insert(:internal_transaction, internal_transaction_details)
      end

      found_internal_transactions = Etherscan.list_internal_transactions(address.hash)

      assert length(found_internal_transactions) == 3
    end

    test "only returns internal transactions associated to the given address" do
      address1 = insert(:address)
      address2 = insert(:address)

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
        transaction_index: transaction.index,
        created_contract_address: address1
      )

      insert(:internal_transaction,
        transaction: transaction,
        index: 1,
        block_number: transaction.block_number,
        block_hash: transaction.block_hash,
        block_index: 1,
        transaction_index: transaction.index,
        from_address: address1
      )

      insert(:internal_transaction,
        transaction: transaction,
        index: 2,
        block_number: transaction.block_number,
        block_hash: transaction.block_hash,
        block_index: 2,
        transaction_index: transaction.index,
        to_address: address1
      )

      insert(:internal_transaction,
        transaction: transaction,
        index: 3,
        block_number: transaction.block_number,
        block_hash: transaction.block_hash,
        block_index: 3,
        transaction_index: transaction.index,
        from_address: address2
      )

      internal_transactions1 = Etherscan.list_internal_transactions(address1.hash)

      # excluding of internal transactions with type=call and index=0
      assert length(internal_transactions1) == 2

      internal_transactions2 = Etherscan.list_internal_transactions(address2.hash)

      assert length(internal_transactions2) == 1
    end

    test "with pagination options" do
      address = insert(:address)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      for index <- 0..3 do
        internal_transaction_details = %{
          transaction: transaction,
          index: index,
          from_address: address,
          block_number: transaction.block_number,
          block_hash: transaction.block_hash,
          block_index: index,
          transaction_index: transaction.index
        }

        insert(:internal_transaction, internal_transaction_details)
      end

      options1 = %{
        page_number: 1,
        page_size: 2
      }

      found_internal_transactions1 = Etherscan.list_internal_transactions(address.hash, options1)

      assert length(found_internal_transactions1) == 2

      options2 = %{
        page_number: 2,
        page_size: 2
      }

      found_internal_transactions2 = Etherscan.list_internal_transactions(address.hash, options2)

      assert length(found_internal_transactions2) == 1
    end

    test "with start and end block options" do
      blocks = [_, second_block, third_block, _] = insert_list(4, :block)
      address = insert(:address)

      for block <- blocks, index <- 0..1 do
        transaction =
          :transaction
          |> insert()
          |> with_block(block)

        internal_transaction_details = %{
          transaction: transaction,
          index: index,
          from_address: address,
          block_number: transaction.block_number,
          block_hash: transaction.block_hash,
          block_index: index,
          transaction_index: transaction.index
        }

        insert(:internal_transaction, internal_transaction_details)
      end

      options = %{
        start_block: second_block.number,
        end_block: third_block.number
      }

      found_internal_transactions = Etherscan.list_internal_transactions(address.hash, options)

      expected_block_numbers = [second_block.number, third_block.number]

      # excluding of internal transactions with type=call and index=0
      assert length(found_internal_transactions) == 2

      for internal_transaction <- found_internal_transactions do
        assert internal_transaction.block_number in expected_block_numbers
      end
    end

    # Note that `list_internal_transactions/2` relies on
    # `Chain.where_transaction_has_multiple_transactions/1` to ensure the
    # following behavior:
    #
    # * exclude internal transactions of type call with no siblings in the
    #   transaction
    #
    # * include internal transactions of type create, reward, or suicide
    #   even when they are alone in the parent transaction
    #
    # These two requirements are tested in `Explorer.ChainTest`.
  end

  describe "list_token_transfers/2" do
    test "with empty db" do
      address = build(:address)

      assert Etherscan.list_token_transfers(address.hash, nil) == []
    end

    test "with from address" do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      token_transfer =
        insert(:token_transfer,
          transaction: transaction,
          block: transaction.block,
          block_number: transaction.block_number
        )

      [found_token_transfer] = Etherscan.list_token_transfers(token_transfer.from_address_hash, nil)

      assert token_transfer.from_address_hash == found_token_transfer.from_address_hash
    end

    test "with to address" do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      token_transfer =
        insert(:token_transfer,
          transaction: transaction,
          block: transaction.block,
          block_number: transaction.block_number
        )

      [found_token_transfer] = Etherscan.list_token_transfers(token_transfer.to_address_hash, nil)

      assert token_transfer.to_address_hash == found_token_transfer.to_address_hash
    end

    test "with address with 0 token transfers" do
      address = insert(:address)

      assert Etherscan.list_token_transfers(address.hash, nil) == []
    end

    test "with address with multiple token transfers" do
      address1 = insert(:address)
      address2 = insert(:address)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(:token_transfer,
        from_address: address1,
        transaction: transaction,
        block: transaction.block,
        block_number: transaction.block_number
      )

      insert(:token_transfer,
        from_address: address1,
        transaction: transaction,
        block: transaction.block,
        block_number: transaction.block_number
      )

      insert(:token_transfer,
        from_address: address2,
        transaction: transaction,
        block: transaction.block,
        block_number: transaction.block_number
      )

      found_token_transfers = Etherscan.list_token_transfers(address1.hash, nil)

      assert length(found_token_transfers) == 2

      for found_token_transfer <- found_token_transfers do
        assert found_token_transfer.from_address_hash == address1.hash
      end
    end

    test "confirmations value is calculated correctly" do
      insert(:block)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      token_transfer =
        insert(:token_transfer,
          transaction: transaction,
          block: transaction.block,
          block_number: transaction.block_number
        )

      insert(:block)

      [found_token_transfer] = Etherscan.list_token_transfers(token_transfer.from_address_hash, nil)

      block_height = Chain.block_height()
      expected_confirmations = block_height - transaction.block_number

      assert found_token_transfer.confirmations == expected_confirmations
    end

    test "returns all required fields" do
      transaction =
        %{block: block} =
        :transaction
        |> insert()
        |> with_block()

      token_transfer =
        insert(:token_transfer,
          transaction: transaction,
          block: transaction.block,
          block_number: transaction.block_number
        )

      {:ok, token} = Chain.token_from_address_hash(token_transfer.token_contract_address_hash)

      [found_token_transfer] = Etherscan.list_token_transfers(token_transfer.from_address_hash, nil)

      assert found_token_transfer.block_number == transaction.block_number
      assert found_token_transfer.block_timestamp == block.timestamp
      assert found_token_transfer.transaction_hash == token_transfer.transaction_hash
      assert found_token_transfer.transaction_nonce == transaction.nonce
      assert found_token_transfer.block_hash == block.hash
      assert found_token_transfer.from_address_hash == token_transfer.from_address_hash
      assert found_token_transfer.token_contract_address_hash == token_transfer.token_contract_address_hash
      assert found_token_transfer.to_address_hash == token_transfer.to_address_hash
      assert found_token_transfer.amount == token_transfer.amount
      assert found_token_transfer.token_name == token.name
      assert found_token_transfer.token_symbol == token.symbol
      assert found_token_transfer.token_decimals == token.decimals
      assert found_token_transfer.transaction_index == transaction.index
      assert found_token_transfer.transaction_gas == transaction.gas
      assert found_token_transfer.transaction_gas_price == transaction.gas_price
      assert found_token_transfer.transaction_gas_used == transaction.gas_used
      assert found_token_transfer.transaction_cumulative_gas_used == transaction.cumulative_gas_used
      assert found_token_transfer.transaction_input == transaction.input
      # There is a separate test to ensure confirmations are calculated correctly.
      assert found_token_transfer.confirmations
    end

    test "orders token transfers by block, in ascending order (default)" do
      address = insert(:address)

      first_block = insert(:block)
      second_block = insert(:block)

      transaction1 =
        :transaction
        |> insert()
        |> with_block(second_block)

      transaction2 =
        :transaction
        |> insert()
        |> with_block()

      transaction3 =
        :transaction
        |> insert()
        |> with_block(first_block)

      insert(:token_transfer,
        from_address: address,
        transaction: transaction2,
        block: transaction2.block,
        block_number: transaction2.block_number
      )

      insert(:token_transfer,
        from_address: address,
        transaction: transaction1,
        block: transaction1.block,
        block_number: transaction1.block_number
      )

      insert(:token_transfer,
        from_address: address,
        transaction: transaction3,
        block: transaction3.block,
        block_number: transaction3.block_number
      )

      found_token_transfers = Etherscan.list_token_transfers(address.hash, nil)

      block_numbers_order = Enum.map(found_token_transfers, & &1.block_number)

      assert Enum.count(block_numbers_order) == 3
      assert block_numbers_order == Enum.sort(block_numbers_order, &(&1 >= &2))
    end

    test "orders token transfers by block, in descending order" do
      address = insert(:address)

      first_block = insert(:block)
      second_block = insert(:block)

      transaction1 =
        :transaction
        |> insert()
        |> with_block(second_block)

      transaction2 =
        :transaction
        |> insert()
        |> with_block()

      transaction3 =
        :transaction
        |> insert()
        |> with_block(first_block)

      insert(:token_transfer,
        from_address: address,
        transaction: transaction2,
        block: transaction2.block,
        block_number: transaction2.block_number
      )

      insert(:token_transfer,
        from_address: address,
        transaction: transaction1,
        block: transaction1.block,
        block_number: transaction1.block_number
      )

      insert(:token_transfer,
        from_address: address,
        transaction: transaction3,
        block: transaction3.block,
        block_number: transaction3.block_number
      )

      options = %{order_by_direction: :desc}

      found_token_transfers = Etherscan.list_token_transfers(address.hash, nil, options)

      block_numbers_order = Enum.map(found_token_transfers, & &1.block_number)

      assert Enum.count(block_numbers_order) == 3
      assert block_numbers_order == Enum.sort(block_numbers_order, &(&1 >= &2))
    end

    test "with page_size and page_number options" do
      address = insert(:address)

      first_block = insert(:block)
      second_block = insert(:block)
      third_block = insert(:block)

      transaction1 =
        :transaction
        |> insert()
        |> with_block(first_block)

      transaction2 =
        :transaction
        |> insert()
        |> with_block(second_block)

      transaction3 =
        :transaction
        |> insert()
        |> with_block(third_block)

      second_block_token_transfers =
        insert_list(2, :token_transfer,
          from_address: address,
          transaction: transaction2,
          block: transaction2.block,
          block_number: transaction2.block_number
        )

      first_block_token_transfers =
        insert_list(2, :token_transfer,
          from_address: address,
          transaction: transaction3,
          block: transaction3.block,
          block_number: transaction3.block_number
        )

      third_block_token_transfers =
        insert_list(2, :token_transfer,
          from_address: address,
          transaction: transaction1,
          block: transaction1.block,
          block_number: transaction1.block_number
        )

      options1 = %{page_number: 1, page_size: 2}

      page1_token_transfers = Etherscan.list_token_transfers(address.hash, nil, options1)

      page1_hashes = Enum.map(page1_token_transfers, & &1.transaction_hash)

      assert length(page1_token_transfers) == 2

      for token_transfer <- first_block_token_transfers do
        assert token_transfer.transaction_hash in page1_hashes
      end

      options2 = %{page_number: 2, page_size: 2}

      page2_token_transfers = Etherscan.list_token_transfers(address.hash, nil, options2)

      page2_hashes = Enum.map(page2_token_transfers, & &1.transaction_hash)

      assert length(page2_token_transfers) == 2

      for token_transfer <- second_block_token_transfers do
        assert token_transfer.transaction_hash in page2_hashes
      end

      options3 = %{page_number: 3, page_size: 2}

      page3_token_transfers = Etherscan.list_token_transfers(address.hash, nil, options3)

      page3_hashes = Enum.map(page3_token_transfers, & &1.transaction_hash)

      assert length(page3_token_transfers) == 2

      for token_transfer <- third_block_token_transfers do
        assert token_transfer.transaction_hash in page3_hashes
      end

      options4 = %{page_number: 4, page_size: 2}

      assert Etherscan.list_token_transfers(address.hash, nil, options4) == []
    end

    test "with start and end block options" do
      blocks = [_, second_block, third_block, _] = insert_list(4, :block)
      address = insert(:address)

      for block <- blocks do
        transaction =
          :transaction
          |> insert()
          |> with_block(block)

        insert(:token_transfer,
          from_address: address,
          transaction: transaction,
          block: block,
          block_number: block.number
        )
      end

      options = %{
        start_block: second_block.number,
        end_block: third_block.number
      }

      found_token_transfers = Etherscan.list_token_transfers(address.hash, nil, options)

      expected_block_numbers = [second_block.number, third_block.number]

      assert length(found_token_transfers) == 2

      for token_transfer <- found_token_transfers do
        assert token_transfer.block_number in expected_block_numbers
      end
    end

    test "with start_block but no end_block option" do
      blocks = [_, _, third_block, fourth_block] = insert_list(4, :block)
      address = insert(:address)

      for block <- blocks do
        transaction =
          :transaction
          |> insert()
          |> with_block(block)

        insert(:token_transfer,
          from_address: address,
          transaction: transaction,
          block: block,
          block_number: block.number
        )
      end

      options = %{start_block: third_block.number}

      found_token_transfers = Etherscan.list_token_transfers(address.hash, nil, options)

      expected_block_numbers = [third_block.number, fourth_block.number]

      assert length(found_token_transfers) == 2

      for token_transfer <- found_token_transfers do
        assert token_transfer.block_number in expected_block_numbers
      end
    end

    test "with end_block but no start_block option" do
      blocks = [first_block, second_block, _, _] = insert_list(4, :block)
      address = insert(:address)

      for block <- blocks do
        transaction =
          :transaction
          |> insert()
          |> with_block(block)

        insert(:token_transfer,
          from_address: address,
          transaction: transaction,
          block: block,
          block_number: block.number
        )
      end

      options = %{end_block: second_block.number}

      found_token_transfers = Etherscan.list_token_transfers(address.hash, nil, options)

      expected_block_numbers = [first_block.number, second_block.number]

      assert length(found_token_transfers) == 2

      for token_transfer <- found_token_transfers do
        assert token_transfer.block_number in expected_block_numbers
      end
    end

    test "with contract_address option" do
      address = insert(:address)

      contract_address = insert(:contract_address)

      insert(:token, contract_address: contract_address)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(:token_transfer, from_address: address, transaction: transaction)

      insert(:token_transfer,
        from_address: address,
        token_contract_address: contract_address,
        transaction: transaction,
        block: transaction.block,
        block_number: transaction.block_number
      )

      [found_token_transfer] = Etherscan.list_token_transfers(address.hash, contract_address.hash)

      assert found_token_transfer.token_contract_address_hash == contract_address.hash
    end
  end

  describe "list_blocks/1" do
    test "it returns all required fields" do
      %{block_range: range} = insert(:emission_reward)

      block = insert(:block, number: Enum.random(Range.new(range.from, range.to)))

      # irrelevant transaction
      insert(:transaction)

      :transaction
      |> insert(gas_price: 1)
      |> with_block(block, gas_used: 1)

      expected = [
        %{
          number: block.number,
          timestamp: block.timestamp
        }
      ]

      assert Etherscan.list_blocks(block.miner_hash) == expected
    end

    test "with block containing multiple transactions" do
      %{block_range: range} = insert(:emission_reward)

      block = insert(:block, number: Enum.random(Range.new(range.from, range.to)))

      expected = [
        %{
          number: block.number,
          timestamp: block.timestamp
        }
      ]

      assert Etherscan.list_blocks(block.miner_hash) == expected
    end

    test "with block without transactions" do
      %{block_range: range} = insert(:emission_reward)

      block = insert(:block, number: Enum.random(Range.new(range.from, range.to)))

      # irrelevant transaction
      insert(:transaction)

      expected = [
        %{
          number: block.number,
          timestamp: block.timestamp
        }
      ]

      assert Etherscan.list_blocks(block.miner_hash) == expected
    end

    test "with multiple blocks" do
      %{block_range: range} = insert(:emission_reward)

      block_numbers = Range.new(range.from, range.to)

      [block_number1, block_number2] = Enum.take(block_numbers, 2)

      address = insert(:address)

      block1 = insert(:block, number: block_number1, miner: address)
      block2 = insert(:block, number: block_number2, miner: address)

      expected = [
        %{
          number: block2.number,
          timestamp: block2.timestamp
        },
        %{
          number: block1.number,
          timestamp: block1.timestamp
        }
      ]

      assert Etherscan.list_blocks(address.hash) == expected
    end

    test "with pagination options" do
      %{block_range: range} = insert(:emission_reward)

      block_numbers = Range.new(range.from, range.to)

      [block_number1, block_number2] = Enum.take(block_numbers, 2)

      address = insert(:address)

      block1 = insert(:block, number: block_number1, miner: address)
      block2 = insert(:block, number: block_number2, miner: address)

      expected1 = [
        %{
          number: block2.number,
          timestamp: block2.timestamp
        }
      ]

      expected2 = [
        %{
          number: block1.number,
          timestamp: block1.timestamp
        }
      ]

      options1 = %{page_number: 1, page_size: 1}
      options2 = %{page_number: 2, page_size: 1}
      options3 = %{page_number: 3, page_size: 1}

      assert Etherscan.list_blocks(address.hash, options1) == expected1
      assert Etherscan.list_blocks(address.hash, options2) == expected2
      assert Etherscan.list_blocks(address.hash, options3) == []
    end
  end

  describe "get_token_balance/2" do
    test "with a single matching token_balance record" do
      address_current_token_balance =
        %{token_contract_address_hash: contract_address_hash, address_hash: address_hash} =
        insert(:address_current_token_balance)

      found_token_balance = Etherscan.get_token_balance(contract_address_hash, address_hash)

      assert found_token_balance.id == address_current_token_balance.id
    end
  end

  describe "list_tokens/1" do
    test "returns the tokens owned by an address hash" do
      address = insert(:address)

      token_balance =
        :address_current_token_balance
        |> insert(address: address)
        |> Repo.preload(:token)

      insert(:address_current_token_balance, address: build(:address))

      token_list = Etherscan.list_tokens(address.hash)

      expected_tokens = [
        %{
          balance: token_balance.value,
          contract_address_hash: token_balance.token_contract_address_hash,
          name: token_balance.token.name,
          decimals: token_balance.token.decimals,
          symbol: token_balance.token.symbol,
          type: token_balance.token.type,
          id: token_balance.token_id
        }
      ]

      assert token_list == expected_tokens
    end

    test "returns an empty list when there are no token balances" do
      address = insert(:address)

      insert(:token_balance, address: build(:address))

      assert Etherscan.list_tokens(address.hash) == []
    end
  end
end
