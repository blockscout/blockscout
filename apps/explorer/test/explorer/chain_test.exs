defmodule Explorer.ChainTest do
  use Explorer.DataCase

  require Ecto.Query

  import Ecto.Query
  import Explorer.Factory

  alias Explorer.{Chain, Factory, PagingOptions, Repo}

  alias Explorer.Chain.{
    Address,
    Block,
    Data,
    Hash,
    InternalTransaction,
    Log,
    Token,
    TokenTransfer,
    Transaction,
    SmartContract,
    Wei
  }

  alias Explorer.Chain.Supply.ProofOfAuthority

  doctest Explorer.Chain

  describe "address_estimated_count/1" do
    test "returns integer" do
      assert is_integer(Chain.address_estimated_count())
    end
  end

  describe "address_to_pending_transactions/2" do
    test "without pending transactions" do
      address = insert(:address)

      assert Repo.aggregate(Transaction, :count, :hash) == 0

      assert [] == Chain.address_to_pending_transactions(address)
    end

    test "with from pending transactions" do
      address = insert(:address)

      transaction = insert(:transaction, from_address: address)

      assert [transaction] ==
               Chain.address_to_pending_transactions(address, direction: :from)
               |> Repo.preload([:to_address, :from_address])
    end

    test "with to transactions" do
      address = insert(:address)

      transaction = insert(:transaction, to_address: address)

      assert [transaction] ==
               Chain.address_to_pending_transactions(address, direction: :to)
               |> Repo.preload([:to_address, :from_address])
    end

    test "with to and from transactions and direction: :from" do
      address = insert(:address)

      transaction = insert(:transaction, from_address: address)
      insert(:transaction, to_address: address)

      # only contains "from" transaction
      assert [transaction] ==
               Chain.address_to_pending_transactions(address, direction: :from)
               |> Repo.preload([:to_address, :from_address])
    end

    test "with to and from transactions and direction: :to" do
      address = insert(:address)

      transaction = insert(:transaction, to_address: address)
      insert(:transaction, from_address: address)

      assert [transaction] ==
               Chain.address_to_pending_transactions(address, direction: :to)
               |> Repo.preload([:to_address, :from_address])
    end

    test "with to and from transactions and no :direction option" do
      address = insert(:address)

      transaction1 = insert(:transaction, from_address: address)
      transaction2 = insert(:transaction, to_address: address)

      assert [transaction1, transaction2] ==
               Chain.address_to_pending_transactions(address)
               |> Repo.preload([:to_address, :from_address])
    end
  end

  describe "address_to_transactions/2" do
    test "without transactions" do
      address = insert(:address)

      assert Repo.aggregate(Transaction, :count, :hash) == 0

      assert [] == Chain.address_to_transactions(address)
    end

    test "with from transactions" do
      address = insert(:address)

      transaction =
        :transaction
        |> insert(from_address: address)
        |> with_block()
        |> Repo.preload(:token_transfers)

      assert [transaction] ==
               Chain.address_to_transactions(address, direction: :from)
               |> Repo.preload([:block, :to_address, :from_address])
    end

    test "with to transactions" do
      address = insert(:address)

      transaction =
        :transaction
        |> insert(to_address: address)
        |> with_block()
        |> Repo.preload(:token_transfers)

      assert [transaction] ==
               Chain.address_to_transactions(address, direction: :to)
               |> Repo.preload([:block, :to_address, :from_address])
    end

    test "with to and from transactions and direction: :from" do
      address = insert(:address)

      transaction =
        :transaction
        |> insert(from_address: address)
        |> with_block()
        |> Repo.preload(:token_transfers)

      # only contains "from" transaction
      assert [transaction] ==
               Chain.address_to_transactions(address, direction: :from)
               |> Repo.preload([:block, :to_address, :from_address])
    end

    test "with to and from transactions and direction: :to" do
      address = insert(:address)

      transaction =
        :transaction
        |> insert(to_address: address)
        |> with_block()
        |> Repo.preload(:token_transfers)

      assert [transaction] ==
               Chain.address_to_transactions(address, direction: :to)
               |> Repo.preload([:block, :to_address, :from_address])
    end

    test "with to and from transactions and no :direction option" do
      address = insert(:address)
      block = insert(:block)

      transaction1 =
        :transaction
        |> insert(to_address: address)
        |> with_block(block)
        |> Repo.preload(:token_transfers)

      transaction2 =
        :transaction
        |> insert(from_address: address)
        |> with_block(block)
        |> Repo.preload(:token_transfers)

      assert [transaction2, transaction1] ==
               Chain.address_to_transactions(address)
               |> Repo.preload([:block, :to_address, :from_address])
    end

    test "does not include non-contract-creation parent transactions" do
      transaction =
        %Transaction{} =
        :transaction
        |> insert()
        |> with_block()

      %InternalTransaction{created_contract_address: address} =
        insert(:internal_transaction_create, transaction: transaction, index: 0)

      assert [] == Chain.address_to_transactions(address)
    end

    test "returns transactions that have token transfers for the given to_address" do
      address = insert(:address)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(:token_transfer, to_address: address, transaction: transaction)

      transaction =
        Transaction
        |> Repo.get!(transaction.hash)
        |> Repo.preload([:block, :to_address, :from_address, token_transfers: :token])

      assert [transaction.hash] ==
               Chain.address_to_transactions(address)
               |> Enum.map(& &1.hash)
    end

    test "returns just the token transfers related to the given address" do
      address = insert(:address)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      token_transfer = insert(:token_transfer, to_address: address, transaction: transaction)
      insert(:token_transfer, to_address: build(:address), transaction: transaction)

      transaction = Chain.address_to_transactions(address) |> List.first()
      assert transaction.token_transfers |> Enum.map(& &1.id) == [token_transfer.id]
    end

    test "returns just the token transfers related to the given contract address" do
      contract_address = insert(:address, contract_code: Factory.data("contract_code"))

      transaction =
        :transaction
        |> insert()
        |> with_block()

      token_transfer = insert(:token_transfer, to_address: contract_address, transaction: transaction)
      insert(:token_transfer, to_address: build(:address), transaction: transaction)

      transaction = Chain.address_to_transactions(contract_address) |> List.first()
      assert Enum.map(transaction.token_transfers, & &1.id) == [token_transfer.id]
    end

    test "returns all token transfers when the given address is the token contract address" do
      contract_address = insert(:address, contract_code: Factory.data("contract_code"))

      transaction =
        :transaction
        |> insert(to_address: contract_address)
        |> with_block()

      insert(
        :token_transfer,
        to_address: build(:address),
        token_contract_address: contract_address,
        transaction: transaction
      )

      insert(
        :token_transfer,
        to_address: build(:address),
        token_contract_address: contract_address,
        transaction: transaction
      )

      transaction = Chain.address_to_transactions(contract_address) |> List.first()
      assert Enum.count(transaction.token_transfers) == 2
    end

    test "with transactions can be paginated" do
      address = insert(:address)

      second_page_hashes =
        50
        |> insert_list(:transaction, from_address: address)
        |> with_block()
        |> Enum.map(& &1.hash)

      %Transaction{block_number: block_number, index: index} =
        :transaction
        |> insert(from_address: address)
        |> with_block()

      assert second_page_hashes ==
               address
               |> Chain.address_to_transactions(
                 paging_options: %PagingOptions{key: {block_number, index}, page_size: 50}
               )
               |> Enum.map(& &1.hash)
               |> Enum.reverse()
    end

    test "returns results in reverse chronological order by block number and transaction index" do
      address = insert(:address)

      %Transaction{hash: first_pending} = insert(:transaction, to_address: address)
      %Transaction{hash: second_pending} = insert(:transaction, to_address: address)

      a_block = insert(:block, number: 6000)

      %Transaction{hash: first} =
        :transaction
        |> insert(to_address: address)
        |> with_block(a_block)

      %Transaction{hash: second} =
        :transaction
        |> insert(to_address: address)
        |> with_block(a_block)

      %Transaction{hash: third} =
        :transaction
        |> insert(to_address: address)
        |> with_block(a_block)

      %Transaction{hash: fourth} =
        :transaction
        |> insert(to_address: address)
        |> with_block(a_block)

      b_block = insert(:block, number: 2000)

      %Transaction{hash: fifth} =
        :transaction
        |> insert(to_address: address)
        |> with_block(b_block)

      %Transaction{hash: sixth} =
        :transaction
        |> insert(to_address: address)
        |> with_block(b_block)

      result =
        address
        |> Chain.address_to_transactions()
        |> Enum.map(& &1.hash)

      assert [first_pending, second_pending, fourth, third, second, first, sixth, fifth] == result
    end
  end

  describe "average_block_time/0" do
    test "without blocks duration is 0" do
      assert Chain.average_block_time() == Timex.Duration.parse!("PT0S")
    end

    test "with blocks is average duration between blocks" do
      first_block = insert(:block)
      second_block = insert(:block, timestamp: Timex.shift(first_block.timestamp, seconds: 3))
      insert(:block, timestamp: Timex.shift(second_block.timestamp, seconds: 9))

      assert Chain.average_block_time() == Timex.Duration.parse!("PT6S")
    end
  end

  describe "balance/2" do
    test "with Address.t with :wei" do
      assert Chain.balance(%Address{fetched_coin_balance: %Wei{value: Decimal.new(1)}}, :wei) == Decimal.new(1)
      assert Chain.balance(%Address{fetched_coin_balance: nil}, :wei) == nil
    end

    test "with Address.t with :gwei" do
      assert Chain.balance(%Address{fetched_coin_balance: %Wei{value: Decimal.new(1)}}, :gwei) == Decimal.new("1e-9")
      assert Chain.balance(%Address{fetched_coin_balance: %Wei{value: Decimal.new("1e9")}}, :gwei) == Decimal.new(1)
      assert Chain.balance(%Address{fetched_coin_balance: nil}, :gwei) == nil
    end

    test "with Address.t with :ether" do
      assert Chain.balance(%Address{fetched_coin_balance: %Wei{value: Decimal.new(1)}}, :ether) == Decimal.new("1e-18")
      assert Chain.balance(%Address{fetched_coin_balance: %Wei{value: Decimal.new("1e18")}}, :ether) == Decimal.new(1)
      assert Chain.balance(%Address{fetched_coin_balance: nil}, :ether) == nil
    end
  end

  describe "block_to_transactions/2" do
    test "without transactions" do
      block = insert(:block)

      assert Repo.aggregate(Transaction, :count, :hash) == 0

      assert [] = Chain.block_to_transactions(block)
    end

    test "with transactions" do
      %Transaction{block: block, hash: transaction_hash} =
        :transaction
        |> insert()
        |> with_block()

      assert [%Transaction{hash: ^transaction_hash}] = Chain.block_to_transactions(block)
    end

    test "with transactions can be paginated by {index}" do
      block = insert(:block)

      second_page_hashes =
        50
        |> insert_list(:transaction)
        |> with_block(block)
        |> Enum.map(& &1.hash)

      %Transaction{index: index} =
        :transaction
        |> insert()
        |> with_block(block)

      assert second_page_hashes ==
               block
               |> Chain.block_to_transactions(paging_options: %PagingOptions{key: {index}, page_size: 50})
               |> Enum.map(& &1.hash)
               |> Enum.reverse()
    end

    test "returns transactions with token_transfers preloaded" do
      address = insert(:address)
      block = insert(:block)
      token_contract_address = insert(:contract_address)
      token = insert(:token, contract_address: token_contract_address)

      transaction =
        :transaction
        |> insert()
        |> with_block(block)

      insert_list(
        2,
        :token_transfer,
        to_address: address,
        transaction: transaction,
        token_contract_address: token_contract_address,
        token: token
      )

      fetched_transaction = List.first(Explorer.Chain.block_to_transactions(block))
      assert fetched_transaction.hash == transaction.hash
      assert length(fetched_transaction.token_transfers) == 2
    end
  end

  describe "block_to_transaction_count/1" do
    test "without transactions" do
      block = insert(:block)

      assert Chain.block_to_transaction_count(block) == 0
    end

    test "with transactions" do
      %Transaction{block: block} =
        :transaction
        |> insert()
        |> with_block()

      assert Chain.block_to_transaction_count(block) == 1
    end
  end

  describe "confirmations/1" do
    test "with block.number == max_block_number " do
      block = insert(:block)
      {:ok, max_block_number} = Chain.max_block_number()

      assert block.number == max_block_number
      assert Chain.confirmations(block, max_block_number: max_block_number) == 0
    end

    test "with block.number < max_block_number" do
      block = insert(:block)
      max_block_number = block.number + 2

      assert block.number < max_block_number

      assert Chain.confirmations(block, max_block_number: max_block_number) == max_block_number - block.number
    end
  end

  describe "fee/2" do
    test "without receipt with :wei unit" do
      assert Chain.fee(%Transaction{gas: Decimal.new(3), gas_price: %Wei{value: Decimal.new(2)}, gas_used: nil}, :wei) ==
               {:maximum, Decimal.new(6)}
    end

    test "without receipt with :gwei unit" do
      assert Chain.fee(%Transaction{gas: Decimal.new(3), gas_price: %Wei{value: Decimal.new(2)}, gas_used: nil}, :gwei) ==
               {:maximum, Decimal.new("6e-9")}
    end

    test "without receipt with :ether unit" do
      assert Chain.fee(%Transaction{gas: Decimal.new(3), gas_price: %Wei{value: Decimal.new(2)}, gas_used: nil}, :ether) ==
               {:maximum, Decimal.new("6e-18")}
    end

    test "with receipt with :wei unit" do
      assert Chain.fee(
               %Transaction{
                 gas: Decimal.new(3),
                 gas_price: %Wei{value: Decimal.new(2)},
                 gas_used: Decimal.new(2)
               },
               :wei
             ) == {:actual, Decimal.new(4)}
    end

    test "with receipt with :gwei unit" do
      assert Chain.fee(
               %Transaction{
                 gas: Decimal.new(3),
                 gas_price: %Wei{value: Decimal.new(2)},
                 gas_used: Decimal.new(2)
               },
               :gwei
             ) == {:actual, Decimal.new("4e-9")}
    end

    test "with receipt with :ether unit" do
      assert Chain.fee(
               %Transaction{
                 gas: Decimal.new(3),
                 gas_price: %Wei{value: Decimal.new(2)},
                 gas_used: Decimal.new(2)
               },
               :ether
             ) == {:actual, Decimal.new("4e-18")}
    end
  end

  describe "fetch_token_transfers_from_token_hash/2" do
    test "without token transfers" do
      %Token{contract_address_hash: contract_address_hash} = insert(:token)

      assert Chain.fetch_token_transfers_from_token_hash(contract_address_hash) == []
    end

    test "with token transfers" do
      address = insert(:address)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      %TokenTransfer{id: token_transfer_id, token_contract_address_hash: token_contract_address_hash} =
        insert(:token_transfer, to_address: address, transaction: transaction)

      assert token_contract_address_hash
             |> Chain.fetch_token_transfers_from_token_hash()
             |> Enum.map(& &1.id) == [token_transfer_id]
    end
  end

  describe "gas_price/2" do
    test ":wei unit" do
      assert Chain.gas_price(%Transaction{gas_price: %Wei{value: Decimal.new(1)}}, :wei) == Decimal.new(1)
    end

    test ":gwei unit" do
      assert Chain.gas_price(%Transaction{gas_price: %Wei{value: Decimal.new(1)}}, :gwei) == Decimal.new("1e-9")

      assert Chain.gas_price(%Transaction{gas_price: %Wei{value: Decimal.new("1e9")}}, :gwei) == Decimal.new(1)
    end

    test ":ether unit" do
      assert Chain.gas_price(%Transaction{gas_price: %Wei{value: Decimal.new(1)}}, :ether) == Decimal.new("1e-18")

      assert Chain.gas_price(%Transaction{gas_price: %Wei{value: Decimal.new("1e18")}}, :ether) == Decimal.new(1)
    end
  end

  describe "hashes_to_addresses/1" do
    test "with existing addresses" do
      address1 = insert(:address, hash: "0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed")
      address2 = insert(:address, hash: "0x6aaeb6053f3e94c9b9a09f33669435e7ef1beaed")
      # in opposite of insertion order, to check that ordering matches ordering of arguments
      # regression test for https://github.com/poanetwork/blockscout/issues/843
      hashes = [address2.hash, address1.hash]

      [found_address1, found_address2] = Explorer.Chain.hashes_to_addresses(hashes)

      %Explorer.Chain.Address{hash: found_hash1} = found_address1
      %Explorer.Chain.Address{hash: found_hash2} = found_address2

      assert found_hash1 == address2.hash
      assert found_hash2 == address1.hash

      hashes = [address1.hash, address2.hash]

      [found_address1, found_address2] = Explorer.Chain.hashes_to_addresses(hashes)

      %Explorer.Chain.Address{hash: found_hash1} = found_address1
      %Explorer.Chain.Address{hash: found_hash2} = found_address2

      assert found_hash1 == address1.hash
      assert found_hash2 == address2.hash
    end

    test "with nonexistent addresses" do
      hash1 = "0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed"
      hash2 = "0x6aaeb6053f3e94c9b9a09f33669435e7ef1beaed"
      hashes = [hash1, hash2]

      assert Explorer.Chain.hashes_to_addresses(hashes) == []
    end
  end

  describe "hash_to_transaction/2" do
    test "with transaction with block required without block returns {:error, :not_found}" do
      %Transaction{hash: hash_with_block} =
        :transaction
        |> insert()
        |> with_block()

      %Transaction{hash: hash_without_index} = insert(:transaction)

      assert {:ok, %Transaction{hash: ^hash_with_block}} =
               Chain.hash_to_transaction(
                 hash_with_block,
                 necessity_by_association: %{block: :required}
               )

      assert {:error, :not_found} =
               Chain.hash_to_transaction(
                 hash_without_index,
                 necessity_by_association: %{block: :required}
               )

      assert {:ok, %Transaction{hash: ^hash_without_index}} =
               Chain.hash_to_transaction(
                 hash_without_index,
                 necessity_by_association: %{block: :optional}
               )
    end

    test "transaction with multiple create internal transactions is returned" do
      transaction =
        %Transaction{hash: hash_with_block} =
        :transaction
        |> insert()
        |> with_block()

      insert(:internal_transaction, transaction: transaction, index: 0)

      Enum.each(1..3, fn index ->
        insert(:internal_transaction_create, transaction: transaction, index: index)
      end)

      assert {:ok, %Transaction{hash: ^hash_with_block}} = Chain.hash_to_transaction(hash_with_block)
    end
  end

  describe "hashes_to_transactions/2" do
    test "with transaction with block required without block returns nil" do
      [%Transaction{hash: hash_with_block1}, %Transaction{hash: hash_with_block2}] =
        2
        |> insert_list(:transaction)
        |> with_block()

      [%Transaction{hash: hash_without_index1}, %Transaction{hash: hash_without_index2}] = insert_list(2, :transaction)

      assert [%Transaction{hash: ^hash_with_block2}, %Transaction{hash: ^hash_with_block1}] =
               Chain.hashes_to_transactions(
                 [hash_with_block1, hash_with_block2],
                 necessity_by_association: %{block: :required}
               )

      assert [] =
               Chain.hashes_to_transactions(
                 [hash_without_index1, hash_without_index2],
                 necessity_by_association: %{block: :required}
               )

      assert [hash_without_index1, hash_without_index2]
             |> Chain.hashes_to_transactions(necessity_by_association: %{block: :optional})
             |> Enum.all?(&(&1.hash in [hash_without_index1, hash_without_index2]))
    end

    test "returns transactions with token_transfers preloaded" do
      address = insert(:address)
      token_contract_address = insert(:contract_address)
      token = insert(:token, contract_address: token_contract_address)

      [transaction1, transaction2] =
        2
        |> insert_list(:transaction)
        |> with_block()

      %TokenTransfer{id: id1} =
        insert(
          :token_transfer,
          to_address: address,
          transaction: transaction1,
          token_contract_address: token_contract_address,
          token: token
        )

      %TokenTransfer{id: id2} =
        insert(
          :token_transfer,
          to_address: address,
          transaction: transaction2,
          token_contract_address: token_contract_address,
          token: token
        )

      fetched_transactions = Explorer.Chain.hashes_to_transactions([transaction1.hash, transaction2.hash])

      assert Enum.all?(fetched_transactions, fn transaction ->
               hd(transaction.token_transfers).id in [id1, id2]
             end)
    end
  end

  # Full tests in `test/explorer/import_test.exs`
  describe "import/1" do
    @import_data %{
      blocks: %{
        params: [
          %{
            consensus: true,
            difficulty: 340_282_366_920_938_463_463_374_607_431_768_211_454,
            gas_limit: 6_946_336,
            gas_used: 50450,
            hash: "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
            miner_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
            nonce: 0,
            number: 37,
            parent_hash: "0xc37bbad7057945d1bf128c1ff009fb1ad632110bf6a000aac025a80f7766b66e",
            size: 719,
            timestamp: Timex.parse!("2017-12-15T21:06:30.000000Z", "{ISO:Extended:Z}"),
            total_difficulty: 12_590_447_576_074_723_148_144_860_474_975_121_280_509
          }
        ]
      },
      block_second_degree_relations: %{
        params: [
          %{
            nephew_hash: "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
            uncle_hash: "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471be"
          }
        ]
      },
      broadcast: true,
      internal_transactions: %{
        params: [
          %{
            call_type: "call",
            from_address_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
            gas: 4_677_320,
            gas_used: 27770,
            index: 0,
            output: "0x",
            to_address_hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
            trace_address: [],
            transaction_hash: "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
            type: "call",
            value: 0
          }
        ]
      },
      logs: %{
        params: [
          %{
            address_hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
            data: "0x0000000000000000000000000000000000000000000000000de0b6b3a7640000",
            first_topic: "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
            second_topic: "0x000000000000000000000000e8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
            third_topic: "0x000000000000000000000000515c09c5bba1ed566b02a5b0599ec5d5d0aee73d",
            fourth_topic: nil,
            index: 0,
            transaction_hash: "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
            type: "mined"
          }
        ]
      },
      transactions: %{
        on_conflict: :replace_all,
        params: [
          %{
            block_hash: "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
            block_number: 37,
            cumulative_gas_used: 50450,
            from_address_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
            gas: 4_700_000,
            gas_price: 100_000_000_000,
            gas_used: 50450,
            hash: "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
            index: 0,
            input: "0x10855269000000000000000000000000862d67cb0773ee3f8ce7ea89b328ffea861ab3ef",
            nonce: 4,
            public_key:
              "0xe5d196ad4ceada719d9e592f7166d0c75700f6eab2e3c3de34ba751ea786527cb3f6eb96ad9fdfdb9989ff572df50f1c42ef800af9c5207a38b929aff969b5c9",
            r: 0xA7F8F45CCE375BB7AF8750416E1B03E0473F93C256DA2285D1134FC97A700E01,
            s: 0x1F87A076F13824F4BE8963E3DFFD7300DAE64D5F23C9A062AF0C6EAD347C135F,
            standard_v: 1,
            status: :ok,
            to_address_hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
            v: 0xBE,
            value: 0
          }
        ]
      },
      addresses: %{
        params: [
          %{hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"},
          %{hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca"},
          %{hash: "0x515c09c5bba1ed566b02a5b0599ec5d5d0aee73d"}
        ]
      },
      tokens: %{
        on_conflict: :nothing,
        params: [
          %{
            contract_address_hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
            type: "ERC-20"
          }
        ]
      },
      token_transfers: %{
        params: [
          %{
            amount: Decimal.new(1_000_000_000_000_000_000),
            block_number: 37,
            log_index: 0,
            from_address_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
            to_address_hash: "0x515c09c5bba1ed566b02a5b0599ec5d5d0aee73d",
            token_contract_address_hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
            transaction_hash: "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5"
          }
        ]
      }
    }

    test "with valid data" do
      difficulty = Decimal.new(340_282_366_920_938_463_463_374_607_431_768_211_454)
      total_difficulty = Decimal.new(12_590_447_576_074_723_148_144_860_474_975_121_280_509)
      token_transfer_amount = Decimal.new(1_000_000_000_000_000_000)
      gas_limit = Decimal.new(6_946_336)
      gas_used = Decimal.new(50450)

      assert {:ok,
              %{
                addresses: [
                  %Address{
                    hash: %Hash{
                      byte_count: 20,
                      bytes:
                        <<81, 92, 9, 197, 187, 161, 237, 86, 107, 2, 165, 176, 89, 158, 197, 213, 208, 174, 231, 61>>
                    },
                    inserted_at: %{},
                    updated_at: %{}
                  },
                  %Address{
                    hash: %Hash{
                      byte_count: 20,
                      bytes:
                        <<139, 243, 141, 71, 100, 146, 144, 100, 242, 212, 211, 165, 101, 32, 167, 106, 179, 223, 65,
                          91>>
                    },
                    inserted_at: %{},
                    updated_at: %{}
                  },
                  %Address{
                    hash: %Hash{
                      byte_count: 20,
                      bytes:
                        <<232, 221, 197, 199, 162, 210, 240, 215, 169, 121, 132, 89, 192, 16, 79, 223, 94, 152, 122,
                          202>>
                    },
                    inserted_at: %{},
                    updated_at: %{}
                  }
                ],
                blocks: [
                  %Block{
                    consensus: true,
                    difficulty: ^difficulty,
                    gas_limit: ^gas_limit,
                    gas_used: ^gas_used,
                    hash: %Hash{
                      byte_count: 32,
                      bytes:
                        <<246, 180, 184, 200, 141, 243, 235, 210, 82, 236, 71, 99, 40, 51, 77, 192, 38, 207, 102, 96,
                          106, 132, 251, 118, 155, 61, 60, 188, 204, 132, 113, 189>>
                    },
                    miner_hash: %Hash{
                      byte_count: 20,
                      bytes:
                        <<232, 221, 197, 199, 162, 210, 240, 215, 169, 121, 132, 89, 192, 16, 79, 223, 94, 152, 122,
                          202>>
                    },
                    nonce: %Explorer.Chain.Hash{
                      byte_count: 8,
                      bytes: <<0, 0, 0, 0, 0, 0, 0, 0>>
                    },
                    number: 37,
                    parent_hash: %Hash{
                      byte_count: 32,
                      bytes:
                        <<195, 123, 186, 215, 5, 121, 69, 209, 191, 18, 140, 31, 240, 9, 251, 26, 214, 50, 17, 11, 246,
                          160, 0, 170, 192, 37, 168, 15, 119, 102, 182, 110>>
                    },
                    size: 719,
                    timestamp: %DateTime{
                      year: 2017,
                      month: 12,
                      day: 15,
                      hour: 21,
                      minute: 6,
                      second: 30,
                      microsecond: {0, 6},
                      std_offset: 0,
                      utc_offset: 0,
                      time_zone: "Etc/UTC",
                      zone_abbr: "UTC"
                    },
                    total_difficulty: ^total_difficulty,
                    inserted_at: %{},
                    updated_at: %{}
                  }
                ],
                internal_transactions: [
                  %{
                    index: 0,
                    transaction_hash: %Hash{
                      byte_count: 32,
                      bytes:
                        <<83, 189, 136, 72, 114, 222, 62, 72, 134, 146, 136, 27, 174, 236, 38, 46, 123, 149, 35, 77, 57,
                          101, 36, 140, 57, 254, 153, 47, 255, 212, 51, 229>>
                    }
                  }
                ],
                logs: [
                  %Log{
                    address_hash: %Hash{
                      byte_count: 20,
                      bytes:
                        <<139, 243, 141, 71, 100, 146, 144, 100, 242, 212, 211, 165, 101, 32, 167, 106, 179, 223, 65,
                          91>>
                    },
                    data: %Data{
                      bytes:
                        <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 13, 224, 182, 179,
                          167, 100, 0, 0>>
                    },
                    index: 0,
                    first_topic: "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
                    second_topic: "0x000000000000000000000000e8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
                    third_topic: "0x000000000000000000000000515c09c5bba1ed566b02a5b0599ec5d5d0aee73d",
                    fourth_topic: nil,
                    transaction_hash: %Hash{
                      byte_count: 32,
                      bytes:
                        <<83, 189, 136, 72, 114, 222, 62, 72, 134, 146, 136, 27, 174, 236, 38, 46, 123, 149, 35, 77, 57,
                          101, 36, 140, 57, 254, 153, 47, 255, 212, 51, 229>>
                    },
                    type: "mined",
                    inserted_at: %{},
                    updated_at: %{}
                  }
                ],
                transactions: [
                  %Hash{
                    byte_count: 32,
                    bytes:
                      <<83, 189, 136, 72, 114, 222, 62, 72, 134, 146, 136, 27, 174, 236, 38, 46, 123, 149, 35, 77, 57,
                        101, 36, 140, 57, 254, 153, 47, 255, 212, 51, 229>>
                  }
                ],
                tokens: [
                  %Token{
                    contract_address_hash: %Hash{
                      byte_count: 20,
                      bytes:
                        <<139, 243, 141, 71, 100, 146, 144, 100, 242, 212, 211, 165, 101, 32, 167, 106, 179, 223, 65,
                          91>>
                    },
                    type: "ERC-20",
                    inserted_at: %{},
                    updated_at: %{}
                  }
                ],
                token_transfers: [
                  %TokenTransfer{
                    amount: ^token_transfer_amount,
                    log_index: 0,
                    from_address_hash: %Hash{
                      byte_count: 20,
                      bytes:
                        <<232, 221, 197, 199, 162, 210, 240, 215, 169, 121, 132, 89, 192, 16, 79, 223, 94, 152, 122,
                          202>>
                    },
                    to_address_hash: %Hash{
                      byte_count: 20,
                      bytes:
                        <<81, 92, 9, 197, 187, 161, 237, 86, 107, 2, 165, 176, 89, 158, 197, 213, 208, 174, 231, 61>>
                    },
                    token_contract_address_hash: %Hash{
                      byte_count: 20,
                      bytes:
                        <<139, 243, 141, 71, 100, 146, 144, 100, 242, 212, 211, 165, 101, 32, 167, 106, 179, 223, 65,
                          91>>
                    },
                    transaction_hash: %Hash{
                      byte_count: 32,
                      bytes:
                        <<83, 189, 136, 72, 114, 222, 62, 72, 134, 146, 136, 27, 174, 236, 38, 46, 123, 149, 35, 77, 57,
                          101, 36, 140, 57, 254, 153, 47, 255, 212, 51, 229>>
                    },
                    inserted_at: %{},
                    updated_at: %{}
                  }
                ]
              }} = Chain.import(@import_data)
    end
  end

  describe "list_blocks/2" do
    test "without blocks" do
      assert [] = Chain.list_blocks()
    end

    test "with blocks" do
      %Block{hash: hash} = insert(:block)

      assert [%Block{hash: ^hash}] = Chain.list_blocks()
    end

    test "with blocks can be paginated" do
      second_page_block_ids =
        50
        |> insert_list(:block)
        |> Enum.map(& &1.number)

      block = insert(:block)

      assert second_page_block_ids ==
               [paging_options: %PagingOptions{key: {block.number}, page_size: 50}]
               |> Chain.list_blocks()
               |> Enum.map(& &1.number)
               |> Enum.reverse()
    end
  end

  describe "list_top_addresses/0" do
    test "without addresses with balance > 0" do
      insert(:address, fetched_coin_balance: 0)
      assert [] = Chain.list_top_addresses()
    end

    test "with top addresses in order" do
      address_hashes =
        4..1
        |> Enum.map(&insert(:address, fetched_coin_balance: &1))
        |> Enum.map(& &1.hash)

      assert address_hashes == Enum.map(Chain.list_top_addresses(), & &1.hash)
    end

    test "with top addresses in order with matching value" do
      test_hashes =
        4..0
        |> Enum.map(&Explorer.Chain.Hash.cast(Explorer.Chain.Hash.Address, &1))
        |> Enum.map(&elem(&1, 1))

      tail =
        4..1
        |> Enum.map(&insert(:address, fetched_coin_balance: &1, hash: Enum.fetch!(test_hashes, &1 - 1)))
        |> Enum.map(& &1.hash)

      first_result_hash =
        :address
        |> insert(fetched_coin_balance: 4, hash: Enum.fetch!(test_hashes, 4))
        |> Map.fetch!(:hash)

      assert [first_result_hash | tail] == Enum.map(Chain.list_top_addresses(), & &1.hash)
    end
  end

  describe "get_blocks_validated_by_address/2" do
    test "returns nothing when there are no blocks" do
      address = insert(:address)

      assert [] = Chain.get_blocks_validated_by_address(address)
    end

    test "returns the blocks validated by a specified address" do
      address = insert(:address)
      another_address = insert(:address)

      block = insert(:block, miner: address, miner_hash: address.hash)
      insert(:block, miner: another_address, miner_hash: another_address.hash)

      results =
        address
        |> Chain.get_blocks_validated_by_address()
        |> Enum.map(& &1.hash)

      assert results == [block.hash]
    end

    test "with blocks can be paginated" do
      address = insert(:address)

      first_page_block = insert(:block, miner: address, miner_hash: address.hash, number: 0)
      second_page_block = insert(:block, miner: address, miner_hash: address.hash, number: 2)

      assert [first_page_block.number] ==
               [paging_options: %PagingOptions{key: {1}, page_size: 1}]
               |> Chain.get_blocks_validated_by_address(address)
               |> Enum.map(& &1.number)
               |> Enum.reverse()

      assert [second_page_block.number] ==
               [paging_options: %PagingOptions{key: {3}, page_size: 1}]
               |> Chain.get_blocks_validated_by_address(address)
               |> Enum.map(& &1.number)
               |> Enum.reverse()
    end
  end

  describe "address_to_validation_count/1" do
    test "returns 0 when there aren't any blocks" do
      address = insert(:address)

      assert 0 = Chain.address_to_validation_count(address)
    end

    test "returns the number of blocks mined by addres" do
      address = insert(:address)
      another_address = insert(:address)

      insert(:block, miner: address, miner_hash: address.hash)
      insert(:block, miner: another_address, miner_hash: another_address.hash)
      insert(:block, miner: another_address, miner_hash: another_address.hash)

      assert 1 = Chain.address_to_validation_count(address)
      assert 2 = Chain.address_to_validation_count(another_address)
    end
  end

  describe "number_to_block/1" do
    test "without block" do
      assert {:error, :not_found} = Chain.number_to_block(-1)
    end

    test "with block" do
      %Block{number: number} = insert(:block)

      assert {:ok, %Block{number: ^number}} = Chain.number_to_block(number)
    end
  end

  describe "address_to_internal_transactions/1" do
    test "with single transaction containing two internal transactions" do
      address = insert(:address)
      transaction = insert(:transaction)

      %InternalTransaction{id: first_id} =
        insert(:internal_transaction, index: 0, transaction: transaction, to_address: address)

      %InternalTransaction{id: second_id} =
        insert(:internal_transaction, index: 1, transaction: transaction, to_address: address)

      result = address |> Chain.address_to_internal_transactions() |> Enum.map(& &1.id)
      assert Enum.member?(result, first_id)
      assert Enum.member?(result, second_id)
    end

    test "loads associations in necessity_by_association" do
      address = insert(:address)
      transaction = insert(:transaction, to_address: address)
      insert(:internal_transaction, transaction: transaction, to_address: address, index: 0)
      insert(:internal_transaction, transaction: transaction, to_address: address, index: 1)

      assert [
               %InternalTransaction{
                 from_address: %Ecto.Association.NotLoaded{},
                 to_address: %Ecto.Association.NotLoaded{},
                 transaction: %Transaction{}
               }
               | _
             ] = Chain.address_to_internal_transactions(address)

      assert [
               %InternalTransaction{
                 from_address: %Address{},
                 to_address: %Address{},
                 transaction: %Transaction{}
               }
               | _
             ] =
               Chain.address_to_internal_transactions(
                 address,
                 necessity_by_association: %{
                   [from_address: :names] => :optional,
                   [to_address: :names] => :optional,
                   :transaction => :optional
                 }
               )
    end

    test "returns results in reverse chronological order by block number, transaction index, internal transaction index" do
      address = insert(:address)

      pending_transaction = insert(:transaction)

      %InternalTransaction{id: first_pending} =
        insert(
          :internal_transaction,
          transaction: pending_transaction,
          to_address: address,
          index: 0
        )

      %InternalTransaction{id: second_pending} =
        insert(
          :internal_transaction,
          transaction: pending_transaction,
          to_address: address,
          index: 1
        )

      a_block = insert(:block, number: 2000)

      first_a_transaction =
        :transaction
        |> insert()
        |> with_block(a_block)

      %InternalTransaction{id: first} =
        insert(
          :internal_transaction,
          transaction: first_a_transaction,
          to_address: address,
          index: 0
        )

      %InternalTransaction{id: second} =
        insert(
          :internal_transaction,
          transaction: first_a_transaction,
          to_address: address,
          index: 1
        )

      second_a_transaction =
        :transaction
        |> insert()
        |> with_block(a_block)

      %InternalTransaction{id: third} =
        insert(
          :internal_transaction,
          transaction: second_a_transaction,
          to_address: address,
          index: 0
        )

      %InternalTransaction{id: fourth} =
        insert(
          :internal_transaction,
          transaction: second_a_transaction,
          to_address: address,
          index: 1
        )

      b_block = insert(:block, number: 6000)

      first_b_transaction =
        :transaction
        |> insert()
        |> with_block(b_block)

      %InternalTransaction{id: fifth} =
        insert(
          :internal_transaction,
          transaction: first_b_transaction,
          to_address: address,
          index: 0
        )

      %InternalTransaction{id: sixth} =
        insert(
          :internal_transaction,
          transaction: first_b_transaction,
          to_address: address,
          index: 1
        )

      result =
        address
        |> Chain.address_to_internal_transactions()
        |> Enum.map(& &1.id)

      assert [second_pending, first_pending, sixth, fifth, fourth, third, second, first] == result
    end

    test "pages by {block_number, transaction_index, index}" do
      address = insert(:address)

      pending_transaction = insert(:transaction)

      insert(
        :internal_transaction,
        transaction: pending_transaction,
        to_address: address,
        index: 0
      )

      insert(
        :internal_transaction,
        transaction: pending_transaction,
        to_address: address,
        index: 1
      )

      a_block = insert(:block, number: 2000)

      first_a_transaction =
        :transaction
        |> insert()
        |> with_block(a_block)

      %InternalTransaction{id: first} =
        insert(
          :internal_transaction,
          transaction: first_a_transaction,
          to_address: address,
          index: 0
        )

      %InternalTransaction{id: second} =
        insert(
          :internal_transaction,
          transaction: first_a_transaction,
          to_address: address,
          index: 1
        )

      second_a_transaction =
        :transaction
        |> insert()
        |> with_block(a_block)

      %InternalTransaction{id: third} =
        insert(
          :internal_transaction,
          transaction: second_a_transaction,
          to_address: address,
          index: 0
        )

      %InternalTransaction{id: fourth} =
        insert(
          :internal_transaction,
          transaction: second_a_transaction,
          to_address: address,
          index: 1
        )

      b_block = insert(:block, number: 6000)

      first_b_transaction =
        :transaction
        |> insert()
        |> with_block(b_block)

      %InternalTransaction{id: fifth} =
        insert(
          :internal_transaction,
          transaction: first_b_transaction,
          to_address: address,
          index: 0
        )

      %InternalTransaction{id: sixth} =
        insert(
          :internal_transaction,
          transaction: first_b_transaction,
          to_address: address,
          index: 1
        )

      # When paged, internal transactions need an associated block number, so `second_pending` and `first_pending` are
      # excluded.
      assert [sixth, fifth, fourth, third, second, first] ==
               address
               |> Chain.address_to_internal_transactions(
                 paging_options: %PagingOptions{key: {6001, 3, 2}, page_size: 8}
               )
               |> Enum.map(& &1.id)

      # block number ==, transaction index ==, internal transaction index <
      assert [fifth, fourth, third, second, first] ==
               address
               |> Chain.address_to_internal_transactions(
                 paging_options: %PagingOptions{key: {6000, 0, 1}, page_size: 8}
               )
               |> Enum.map(& &1.id)

      # block number ==, transaction index <
      assert [fourth, third, second, first] ==
               address
               |> Chain.address_to_internal_transactions(
                 paging_options: %PagingOptions{key: {6000, -1, -1}, page_size: 8}
               )
               |> Enum.map(& &1.id)

      # block number <
      assert [] ==
               address
               |> Chain.address_to_internal_transactions(
                 paging_options: %PagingOptions{key: {2000, -1, -1}, page_size: 8}
               )
               |> Enum.map(& &1.id)
    end

    test "excludes internal transactions of type `call` when they are alone in the parent transaction" do
      address = insert(:address)

      transaction =
        :transaction
        |> insert(to_address: address)
        |> with_block()

      insert(:internal_transaction, index: 0, to_address: address, transaction: transaction)

      assert Enum.empty?(Chain.address_to_internal_transactions(address))
    end

    test "includes internal transactions of type `create` even when they are alone in the parent transaction" do
      address = insert(:address)

      transaction =
        :transaction
        |> insert(to_address: address)
        |> with_block()

      expected =
        insert(
          :internal_transaction_create,
          index: 0,
          from_address: address,
          transaction: transaction
        )

      actual = Enum.at(Chain.address_to_internal_transactions(address), 0)

      assert actual.id == expected.id
    end
  end

  describe "pending_transactions/0" do
    test "without transactions" do
      assert [] = Chain.recent_pending_transactions()
    end

    test "with transactions" do
      %Transaction{hash: hash} = insert(:transaction)

      assert [%Transaction{hash: ^hash}] = Chain.recent_pending_transactions()
    end

    test "with transactions can be paginated" do
      second_page_hashes =
        50
        |> insert_list(:transaction)
        |> Enum.map(& &1.hash)

      %Transaction{inserted_at: inserted_at, hash: hash} = insert(:transaction)

      assert second_page_hashes ==
               [paging_options: %PagingOptions{key: {inserted_at, hash}, page_size: 50}]
               |> Chain.recent_pending_transactions()
               |> Enum.map(& &1.hash)
               |> Enum.reverse()
    end
  end

  describe "transaction_estimated_count/1" do
    test "returns integer" do
      assert is_integer(Chain.transaction_estimated_count())
    end
  end

  describe "transaction_to_internal_transactions/1" do
    test "with transaction without internal transactions" do
      transaction = insert(:transaction)

      assert [] = Chain.transaction_to_internal_transactions(transaction)
    end

    test "with transaction with internal transactions returns all internal transactions for a given transaction hash" do
      block = insert(:block)

      transaction =
        :transaction
        |> insert()
        |> with_block(block)

      first = insert(:internal_transaction, transaction: transaction, index: 0)
      second = insert(:internal_transaction, transaction: transaction, index: 1)

      results = [internal_transaction | _] = Chain.transaction_to_internal_transactions(transaction)

      assert 2 == length(results)
      assert Enum.all?(results, &(&1.id in [first.id, second.id]))
      assert internal_transaction.transaction.block.number == block.number
    end

    test "with transaction with internal transactions loads associations with in necessity_by_association" do
      transaction = insert(:transaction)
      insert(:internal_transaction_create, transaction: transaction, index: 0)

      assert [
               %InternalTransaction{
                 from_address: %Ecto.Association.NotLoaded{},
                 to_address: %Ecto.Association.NotLoaded{},
                 transaction: %Transaction{}
               }
             ] = Chain.transaction_to_internal_transactions(transaction)

      assert [
               %InternalTransaction{
                 from_address: %Address{},
                 to_address: nil,
                 transaction: %Transaction{}
               }
             ] =
               Chain.transaction_to_internal_transactions(
                 transaction,
                 necessity_by_association: %{
                   from_address: :optional,
                   to_address: :optional,
                   transaction: :optional
                 }
               )
    end

    test "excludes internal transaction of type call with no siblings in the transaction" do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(:internal_transaction, transaction: transaction, index: 0)

      result = Chain.transaction_to_internal_transactions(transaction)

      assert Enum.empty?(result)
    end

    test "includes internal transactions of type `create` even when they are alone in the parent transaction" do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      expected = insert(:internal_transaction_create, index: 0, transaction: transaction)

      actual = Enum.at(Chain.transaction_to_internal_transactions(transaction), 0)

      assert actual.id == expected.id
    end

    test "includes internal transactions of type `reward` even when they are alone in the parent transaction" do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      expected = insert(:internal_transaction, index: 0, transaction: transaction, type: :reward)

      actual = Enum.at(Chain.transaction_to_internal_transactions(transaction), 0)

      assert actual.id == expected.id
    end

    test "includes internal transactions of type `suicide` even when they are alone in the parent transaction" do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      expected = insert(:internal_transaction, index: 0, transaction: transaction, gas: nil, type: :suicide)

      actual = Enum.at(Chain.transaction_to_internal_transactions(transaction), 0)

      assert actual.id == expected.id
    end

    test "returns the internal transactions in ascending index order" do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      %InternalTransaction{id: first_id} = insert(:internal_transaction, transaction: transaction, index: 0)
      %InternalTransaction{id: second_id} = insert(:internal_transaction, transaction: transaction, index: 1)

      result =
        transaction
        |> Chain.transaction_to_internal_transactions()
        |> Enum.map(& &1.id)

      assert [first_id, second_id] == result
    end

    test "pages by index" do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      %InternalTransaction{id: first_id} = insert(:internal_transaction, transaction: transaction, index: 0)
      %InternalTransaction{id: second_id} = insert(:internal_transaction, transaction: transaction, index: 1)

      assert [^first_id, ^second_id] =
               transaction
               |> Chain.transaction_to_internal_transactions(paging_options: %PagingOptions{key: {-1}, page_size: 2})
               |> Enum.map(& &1.id)

      assert [^first_id] =
               transaction
               |> Chain.transaction_to_internal_transactions(paging_options: %PagingOptions{key: {-1}, page_size: 1})
               |> Enum.map(& &1.id)

      assert [^second_id] =
               transaction
               |> Chain.transaction_to_internal_transactions(paging_options: %PagingOptions{key: {0}, page_size: 2})
               |> Enum.map(& &1.id)
    end
  end

  describe "transaction_to_logs/2" do
    test "without logs" do
      transaction = insert(:transaction)

      assert [] = Chain.transaction_to_logs(transaction)
    end

    test "with logs" do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      %Log{id: id} = insert(:log, transaction: transaction)

      assert [%Log{id: ^id}] = Chain.transaction_to_logs(transaction)
    end

    test "with logs can be paginated" do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      log = insert(:log, transaction: transaction, index: 1)

      second_page_indexes =
        2..51
        |> Enum.map(fn index -> insert(:log, transaction: transaction, index: index) end)
        |> Enum.map(& &1.index)

      assert second_page_indexes ==
               transaction
               |> Chain.transaction_to_logs(paging_options: %PagingOptions{key: {log.index}, page_size: 50})
               |> Enum.map(& &1.index)
    end

    test "with logs necessity_by_association loads associations" do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(:log, transaction: transaction)

      assert [%Log{address: %Address{}, transaction: %Transaction{}}] =
               Chain.transaction_to_logs(
                 transaction,
                 necessity_by_association: %{
                   address: :optional,
                   transaction: :optional
                 }
               )

      assert [
               %Log{
                 address: %Ecto.Association.NotLoaded{},
                 transaction: %Ecto.Association.NotLoaded{}
               }
             ] = Chain.transaction_to_logs(transaction)
    end
  end

  describe "transaction_to_token_transfers/2" do
    test "without token transfers" do
      transaction = insert(:transaction)

      assert [] = Chain.transaction_to_token_transfers(transaction)
    end

    test "with token transfers" do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      %TokenTransfer{id: id} = insert(:token_transfer, transaction: transaction)

      assert [%TokenTransfer{id: ^id}] = Chain.transaction_to_token_transfers(transaction)
    end

    test "token transfers necessity_by_association loads associations" do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(:token_transfer, transaction: transaction)

      assert [%TokenTransfer{token: %Token{}, transaction: %Transaction{}}] =
               Chain.transaction_to_token_transfers(
                 transaction,
                 necessity_by_association: %{
                   token: :optional,
                   transaction: :optional
                 }
               )

      assert [
               %TokenTransfer{
                 token: %Ecto.Association.NotLoaded{},
                 transaction: %Ecto.Association.NotLoaded{}
               }
             ] = Chain.transaction_to_token_transfers(transaction)
    end
  end

  describe "value/2" do
    test "with InternalTransaction.t with :wei" do
      assert Chain.value(%InternalTransaction{value: %Wei{value: Decimal.new(1)}}, :wei) == Decimal.new(1)
    end

    test "with InternalTransaction.t with :gwei" do
      assert Chain.value(%InternalTransaction{value: %Wei{value: Decimal.new(1)}}, :gwei) == Decimal.new("1e-9")

      assert Chain.value(%InternalTransaction{value: %Wei{value: Decimal.new("1e9")}}, :gwei) == Decimal.new(1)
    end

    test "with InternalTransaction.t with :ether" do
      assert Chain.value(%InternalTransaction{value: %Wei{value: Decimal.new(1)}}, :ether) == Decimal.new("1e-18")

      assert Chain.value(%InternalTransaction{value: %Wei{value: Decimal.new("1e18")}}, :ether) == Decimal.new(1)
    end

    test "with Transaction.t with :wei" do
      assert Chain.value(%Transaction{value: %Wei{value: Decimal.new(1)}}, :wei) == Decimal.new(1)
    end

    test "with Transaction.t with :gwei" do
      assert Chain.value(%Transaction{value: %Wei{value: Decimal.new(1)}}, :gwei) == Decimal.new("1e-9")
      assert Chain.value(%Transaction{value: %Wei{value: Decimal.new("1e9")}}, :gwei) == Decimal.new(1)
    end

    test "with Transaction.t with :ether" do
      assert Chain.value(%Transaction{value: %Wei{value: Decimal.new(1)}}, :ether) == Decimal.new("1e-18")
      assert Chain.value(%Transaction{value: %Wei{value: Decimal.new("1e18")}}, :ether) == Decimal.new(1)
    end
  end

  describe "find_contract_address/1" do
    test "doesn't find an address that doesn't have a code" do
      address = insert(:address, contract_code: nil)

      response = Chain.find_contract_address(address.hash)

      assert {:error, :not_found} == response
    end

    test "doesn't find a nonexistent address" do
      nonexistent_address_hash = Factory.address_hash()

      response = Chain.find_contract_address(nonexistent_address_hash)

      assert {:error, :not_found} == response
    end

    test "finds an contract address" do
      address =
        insert(:address, contract_code: Factory.data("contract_code"), smart_contract: nil, names: [])
        |> Repo.preload([:contracts_creation_internal_transaction, :token])

      response = Chain.find_contract_address(address.hash)

      assert response == {:ok, address}
    end
  end

  describe "block_reward/1" do
    setup do
      %{block_range: range} = block_reward = insert(:block_reward)

      block = insert(:block, number: Enum.random(Range.new(range.from, range.to)))
      insert(:transaction)

      {:ok, block: block, block_reward: block_reward}
    end

    test "with block containing transactions", %{block: block, block_reward: block_reward} do
      :transaction
      |> insert(gas_price: 1)
      |> with_block(block, gas_used: 1)

      :transaction
      |> insert(gas_price: 1)
      |> with_block(block, gas_used: 2)

      expected =
        block_reward.reward
        |> Wei.to(:wei)
        |> Decimal.add(Decimal.new(3))
        |> Wei.from(:wei)

      assert expected == Chain.block_reward(block)
    end

    test "with block without transactions", %{block: block, block_reward: block_reward} do
      assert block_reward.reward == Chain.block_reward(block)
    end
  end

  describe "recent_collated_transactions/1" do
    test "with no collated transactions it returns an empty list" do
      assert [] == Explorer.Chain.recent_collated_transactions()
    end

    test "it excludes pending transactions" do
      insert(:transaction)
      assert [] == Explorer.Chain.recent_collated_transactions()
    end

    test "returns a list of recent collated transactions" do
      newest_first_transactions =
        50
        |> insert_list(:transaction)
        |> with_block()
        |> Enum.reverse()

      oldest_seen = Enum.at(newest_first_transactions, 9)
      paging_options = %Explorer.PagingOptions{page_size: 10, key: {oldest_seen.block_number, oldest_seen.index}}
      recent_collated_transactions = Explorer.Chain.recent_collated_transactions(paging_options: paging_options)

      assert length(recent_collated_transactions) == 10
      assert hd(recent_collated_transactions).hash == Enum.at(newest_first_transactions, 10).hash
    end

    test "returns transactions with token_transfers preloaded" do
      address = insert(:address)
      token_contract_address = insert(:contract_address)
      token = insert(:token, contract_address: token_contract_address)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert_list(
        2,
        :token_transfer,
        to_address: address,
        transaction: transaction,
        token_contract_address: token_contract_address,
        token: token
      )

      fetched_transaction = List.first(Explorer.Chain.recent_collated_transactions())
      assert fetched_transaction.hash == transaction.hash
      assert length(fetched_transaction.token_transfers) == 2
    end
  end

  describe "smart_contract_bytecode/1" do
    test "fetches the smart contract bytecode" do
      smart_contract_bytecode =
        "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582040d82a7379b1ee1632ad4d8a239954fd940277b25628ead95259a85c5eddb2120029"

      created_contract_address = insert(:address, contract_code: smart_contract_bytecode)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(
        :internal_transaction_create,
        transaction: transaction,
        index: 0,
        created_contract_address: created_contract_address,
        created_contract_code: smart_contract_bytecode
      )

      assert Chain.smart_contract_bytecode(created_contract_address.hash) == smart_contract_bytecode
    end
  end

  describe "create_smart_contract/1" do
    setup do
      smart_contract_bytecode =
        "0x608060405234801561001057600080fd5b5060df8061001f6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114604e5780636d4ce63c146078575b600080fd5b348015605957600080fd5b5060766004803603810190808035906020019092919050505060a0565b005b348015608357600080fd5b50608a60aa565b6040518082815260200191505060405180910390f35b8060008190555050565b600080549050905600a165627a7a7230582040d82a7379b1ee1632ad4d8a239954fd940277b25628ead95259a85c5eddb2120029"

      created_contract_address =
        insert(
          :address,
          hash: "0x0f95fa9bc0383e699325f2658d04e8d96d87b90c",
          contract_code: smart_contract_bytecode
        )

      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(
        :internal_transaction_create,
        transaction: transaction,
        index: 0,
        created_contract_address: created_contract_address,
        created_contract_code: smart_contract_bytecode
      )

      valid_attrs = %{
        address_hash: "0x0f95fa9bc0383e699325f2658d04e8d96d87b90c",
        name: "SimpleStorage",
        compiler_version: "0.4.23",
        optimization: false,
        contract_source_code:
          "pragma solidity ^0.4.23; contract SimpleStorage {uint storedData; function set(uint x) public {storedData = x; } function get() public constant returns (uint) {return storedData; } }",
        abi: [
          %{
            "constant" => false,
            "inputs" => [%{"name" => "x", "type" => "uint256"}],
            "name" => "set",
            "outputs" => [],
            "payable" => false,
            "stateMutability" => "nonpayable",
            "type" => "function"
          },
          %{
            "constant" => true,
            "inputs" => [],
            "name" => "get",
            "outputs" => [%{"name" => "", "type" => "uint256"}],
            "payable" => false,
            "stateMutability" => "view",
            "type" => "function"
          }
        ]
      }

      {:ok, valid_attrs: valid_attrs, address: created_contract_address}
    end

    test "with valid data creates a smart contract", %{valid_attrs: valid_attrs} do
      assert {:ok, %SmartContract{} = smart_contract} = Chain.create_smart_contract(valid_attrs)
      assert smart_contract.name == "SimpleStorage"
      assert smart_contract.compiler_version == "0.4.23"
      assert smart_contract.optimization == false
      assert smart_contract.contract_source_code != ""
      assert smart_contract.abi != ""

      assert Repo.get_by(
               Address.Name,
               address_hash: smart_contract.address_hash,
               name: smart_contract.name,
               primary: true
             )
    end

    test "clears an existing primary name and sets the new one", %{valid_attrs: valid_attrs, address: address} do
      insert(:address_name, address: address, primary: true)
      assert {:ok, %SmartContract{} = smart_contract} = Chain.create_smart_contract(valid_attrs)

      assert Repo.get_by(
               Address.Name,
               address_hash: smart_contract.address_hash,
               name: smart_contract.name,
               primary: true
             )
    end

    test "trims whitespace from address name", %{valid_attrs: valid_attrs} do
      attrs = %{valid_attrs | name: "     SimpleStorage     "}
      assert {:ok, _} = Chain.create_smart_contract(attrs)
      assert Repo.get_by(Address.Name, name: "SimpleStorage")
    end
  end

  describe "stream_unfetched_balances/2" do
    test "with `t:Explorer.Chain.Address.CoinBalance.t/0` with value_fetched_at with same `address_hash` and `block_number` " <>
           "does not return `t:Explorer.Chain.Block.t/0` `miner_hash`" do
      %Address{hash: miner_hash} = miner = insert(:address)
      %Block{number: block_number} = insert(:block, miner: miner)
      balance = insert(:unfetched_balance, address_hash: miner_hash, block_number: block_number)

      assert {:ok, [%{address_hash: ^miner_hash, block_number: ^block_number}]} =
               Chain.stream_unfetched_balances([], &[&1 | &2])

      update_balance_value(balance, 1)

      assert {:ok, []} = Chain.stream_unfetched_balances([], &[&1 | &2])
    end

    test "with `t:Explorer.Chain.Address.CoinBalance.t/0` with value_fetched_at with same `address_hash` and `block_number` " <>
           "does not return `t:Explorer.Chain.Transaction.t/0` `from_address_hash`" do
      %Address{hash: from_address_hash} = from_address = insert(:address)
      %Block{number: block_number} = block = insert(:block)

      :transaction
      |> insert(from_address: from_address)
      |> with_block(block)

      balance = insert(:unfetched_balance, address_hash: from_address_hash, block_number: block_number)

      {:ok, balance_fields_list} =
        Explorer.Chain.stream_unfetched_balances(
          [],
          fn balance_fields, acc -> [balance_fields | acc] end
        )

      assert %{address_hash: from_address_hash, block_number: block_number} in balance_fields_list

      update_balance_value(balance, 1)

      {:ok, balance_fields_list} =
        Explorer.Chain.stream_unfetched_balances(
          [],
          fn balance_fields, acc -> [balance_fields | acc] end
        )

      refute %{address_hash: from_address_hash, block_number: block_number} in balance_fields_list
    end

    test "with `t:Explorer.Chain.Address.CoinBalance.t/0` with value_fetched_at with same `address_hash` and `block_number` " <>
           "does not return `t:Explorer.Chain.Transaction.t/0` `to_address_hash`" do
      %Address{hash: to_address_hash} = to_address = insert(:address)
      %Block{number: block_number} = block = insert(:block)

      :transaction
      |> insert(to_address: to_address)
      |> with_block(block)

      balance = insert(:unfetched_balance, address_hash: to_address_hash, block_number: block_number)

      {:ok, balance_fields_list} =
        Explorer.Chain.stream_unfetched_balances(
          [],
          fn balance_fields, acc -> [balance_fields | acc] end
        )

      assert %{address_hash: to_address_hash, block_number: block_number} in balance_fields_list

      update_balance_value(balance, 1)

      {:ok, balance_fields_list} =
        Explorer.Chain.stream_unfetched_balances(
          [],
          fn balance_fields, acc -> [balance_fields | acc] end
        )

      refute %{address_hash: to_address_hash, block_number: block_number} in balance_fields_list
    end

    test "with `t:Explorer.Chain.Address.CoinBalance.t/0` with value_fetched_at with same `address_hash` and `block_number` " <>
           "does not return `t:Explorer.Chain.Log.t/0` `address_hash`" do
      address = insert(:address)
      block = insert(:block)

      transaction =
        :transaction
        |> insert()
        |> with_block(block)

      insert(:log, address: address, transaction: transaction)

      balance = insert(:unfetched_balance, address_hash: address.hash, block_number: block.number)

      {:ok, balance_fields_list} =
        Explorer.Chain.stream_unfetched_balances(
          [],
          fn balance_fields, acc -> [balance_fields | acc] end
        )

      assert %{
               address_hash: address.hash,
               block_number: block.number
             } in balance_fields_list

      update_balance_value(balance, 1)

      {:ok, balance_fields_list} =
        Explorer.Chain.stream_unfetched_balances(
          [],
          fn balance_fields, acc -> [balance_fields | acc] end
        )

      refute %{
               address_hash: address.hash,
               block_number: block.number
             } in balance_fields_list
    end

    test "with `t:Explorer.Chain.Address.CoinBalance.t/0` with value_fetched_at with same `address_hash` and `block_number` " <>
           "does not return `t:Explorer.Chain.InternalTransaction.t/0` `created_contract_address_hash`" do
      created_contract_address = insert(:address)
      block = insert(:block)

      transaction =
        :transaction
        |> insert()
        |> with_block(block)

      insert(
        :internal_transaction_create,
        created_contract_address: created_contract_address,
        index: 0,
        transaction: transaction
      )

      balance = insert(:unfetched_balance, address_hash: created_contract_address.hash, block_number: block.number)

      {:ok, balance_fields_list} =
        Explorer.Chain.stream_unfetched_balances(
          [],
          fn balance_fields, acc -> [balance_fields | acc] end
        )

      assert %{
               address_hash: created_contract_address.hash,
               block_number: block.number
             } in balance_fields_list

      update_balance_value(balance, 1)

      {:ok, balance_fields_list} =
        Explorer.Chain.stream_unfetched_balances(
          [],
          fn balance_fields, acc -> [balance_fields | acc] end
        )

      refute %{
               address_hash: created_contract_address.hash,
               block_number: block.number
             } in balance_fields_list
    end

    test "with `t:Explorer.Chain.Address.CoinBalance.t/0` with value_fetched_at with same `address_hash` and `block_number` " <>
           "does not return `t:Explorer.Chain.InternalTransaction.t/0` `from_address_hash`" do
      from_address = insert(:address)
      block = insert(:block)

      transaction =
        :transaction
        |> insert()
        |> with_block(block)

      insert(
        :internal_transaction_create,
        from_address: from_address,
        index: 0,
        transaction: transaction
      )

      balance = insert(:unfetched_balance, address_hash: from_address.hash, block_number: block.number)

      {:ok, balance_fields_list} =
        Explorer.Chain.stream_unfetched_balances(
          [],
          fn balance_fields, acc -> [balance_fields | acc] end
        )

      assert %{address_hash: from_address.hash, block_number: block.number} in balance_fields_list

      update_balance_value(balance, 1)

      {:ok, balance_fields_list} =
        Explorer.Chain.stream_unfetched_balances(
          [],
          fn balance_fields, acc -> [balance_fields | acc] end
        )

      refute %{address_hash: from_address.hash, block_number: block.number} in balance_fields_list
    end

    test "with `t:Explorer.Chain.Address.CoinBalance.t/0` with value_fetched_at with same `address_hash` and `block_number` " <>
           "does not return `t:Explorer.Chain.InternalTransaction.t/0` `to_address_hash`" do
      to_address = insert(:address)
      block = insert(:block)

      transaction =
        :transaction
        |> insert()
        |> with_block(block)

      insert(
        :internal_transaction_create,
        to_address: to_address,
        index: 0,
        transaction: transaction
      )

      balance = insert(:unfetched_balance, address_hash: to_address.hash, block_number: block.number)

      {:ok, balance_fields_list} =
        Explorer.Chain.stream_unfetched_balances(
          [],
          fn balance_fields, acc -> [balance_fields | acc] end
        )

      assert %{address_hash: to_address.hash, block_number: block.number} in balance_fields_list

      update_balance_value(balance, 1)

      {:ok, balance_fields_list} =
        Explorer.Chain.stream_unfetched_balances(
          [],
          fn balance_fields, acc -> [balance_fields | acc] end
        )

      refute %{address_hash: to_address.hash, block_number: block.number} in balance_fields_list
    end

    test "an address_hash used for multiple block_numbers returns all block_numbers" do
      miner = insert(:address)
      mined_block = insert(:block, miner: miner)

      insert(:unfetched_balance, address_hash: miner.hash, block_number: mined_block.number)

      from_transaction_block = insert(:block)

      :transaction
      |> insert(from_address: miner)
      |> with_block(from_transaction_block)

      insert(:unfetched_balance, address_hash: miner.hash, block_number: from_transaction_block.number)

      to_transaction_block = insert(:block)

      :transaction
      |> insert(to_address: miner)
      |> with_block(to_transaction_block)

      insert(:unfetched_balance, address_hash: miner.hash, block_number: to_transaction_block.number)

      log_block = insert(:block)

      log_transaction =
        :transaction
        |> insert()
        |> with_block(log_block)

      insert(:log, address: miner, transaction: log_transaction)
      insert(:unfetched_balance, address_hash: miner.hash, block_number: log_block.number)

      from_internal_transaction_block = insert(:block)

      from_internal_transaction_transaction =
        :transaction
        |> insert()
        |> with_block(from_internal_transaction_block)

      insert(
        :internal_transaction_create,
        from_address: miner,
        index: 0,
        transaction: from_internal_transaction_transaction
      )

      insert(:unfetched_balance, address_hash: miner.hash, block_number: from_internal_transaction_block.number)

      to_internal_transaction_block = insert(:block)

      to_internal_transaction_transaction =
        :transaction
        |> insert()
        |> with_block(to_internal_transaction_block)

      insert(
        :internal_transaction_create,
        index: 0,
        to_address: miner,
        transaction: to_internal_transaction_transaction
      )

      insert(:unfetched_balance, address_hash: miner.hash, block_number: to_internal_transaction_block.number)

      {:ok, balance_fields_list} =
        Explorer.Chain.stream_unfetched_balances(
          [],
          fn balance_fields, acc -> [balance_fields | acc] end
        )

      balance_fields_list_by_address_hash = Enum.group_by(balance_fields_list, & &1.address_hash)

      assert balance_fields_list_by_address_hash[miner.hash] |> Enum.map(& &1.block_number) |> Enum.sort() ==
               Enum.sort([
                 to_internal_transaction_block.number,
                 from_internal_transaction_block.number,
                 log_block.number,
                 to_transaction_block.number,
                 from_transaction_block.number,
                 mined_block.number
               ])
    end

    test "an address_hash used for the same block_number is only returned once" do
      miner = insert(:address)
      block = insert(:block, miner: miner)

      insert(:unfetched_balance, address_hash: miner.hash, block_number: block.number)

      :transaction
      |> insert(from_address: miner)
      |> with_block(block)

      :transaction
      |> insert(to_address: miner)
      |> with_block(block)

      log_transaction =
        :transaction
        |> insert()
        |> with_block(block)

      insert(:log, address: miner, transaction: log_transaction)

      from_internal_transaction_transaction =
        :transaction
        |> insert()
        |> with_block(block)

      insert(
        :internal_transaction_create,
        from_address: miner,
        index: 0,
        transaction: from_internal_transaction_transaction
      )

      to_internal_transaction_transaction =
        :transaction
        |> insert()
        |> with_block(block)

      insert(
        :internal_transaction_create,
        to_address: miner,
        index: 0,
        transaction: to_internal_transaction_transaction
      )

      {:ok, balance_fields_list} =
        Explorer.Chain.stream_unfetched_balances(
          [],
          fn balance_fields, acc -> [balance_fields | acc] end
        )

      balance_fields_list_by_address_hash = Enum.group_by(balance_fields_list, & &1.address_hash)

      assert balance_fields_list_by_address_hash[miner.hash] |> Enum.map(& &1.block_number) |> Enum.sort() == [
               block.number
             ]
    end
  end

  describe "stream_unfetched_token_balances/2" do
    test "executes the given reducer with the query result" do
      address = insert(:address, hash: "0xc45e4830dff873cf8b70de2b194d0ddd06ef651e")
      token_balance = insert(:token_balance, value_fetched_at: nil, address: address)
      insert(:token_balance)

      assert Chain.stream_unfetched_token_balances([], &[&1.block_number | &2]) == {:ok, [token_balance.block_number]}
    end
  end

  describe "stream_unfetched_uncle_hashes/2" do
    test "does not return uncle hashes where t:Explorer.Chain.Block.SecondDegreeRelation.t/0 uncle_fetched_at is not nil" do
      %Block.SecondDegreeRelation{nephew: %Block{}, uncle_hash: uncle_hash} = insert(:block_second_degree_relation)

      assert {:ok, [^uncle_hash]} = Explorer.Chain.stream_unfetched_uncle_hashes([], &[&1 | &2])

      query = from(bsdr in Block.SecondDegreeRelation, where: bsdr.uncle_hash == ^uncle_hash)

      assert {1, _} = Repo.update_all(query, set: [uncle_fetched_at: DateTime.utc_now()])

      assert {:ok, []} = Explorer.Chain.stream_unfetched_uncle_hashes([], &[&1 | &2])
    end
  end

  test "total_supply/0" do
    height = 2_000_000
    insert(:block, number: height)
    expected = ProofOfAuthority.initial_supply() + height

    assert Chain.total_supply() == expected
  end

  test "circulating_supply/0" do
    assert Chain.circulating_supply() == ProofOfAuthority.circulating()
  end

  describe "address_hash_to_smart_contract/1" do
    test "fetches a smart contract" do
      smart_contract = insert(:smart_contract)

      assert ^smart_contract = Chain.address_hash_to_smart_contract(smart_contract.address_hash)
    end
  end

  test "subscribe_to_events/1" do
    assert :ok == Chain.subscribe_to_events(:logs)
    current_pid = self()
    assert [{^current_pid, _}] = Registry.lookup(Registry.ChainEvents, :logs)
  end

  describe "token_from_address_hash/1" do
    test "with valid hash" do
      token = insert(:token)
      assert {:ok, result} = Chain.token_from_address_hash(token.contract_address.hash)
      assert result.contract_address_hash == token.contract_address_hash
    end

    test "with hash that doesn't exist" do
      token = build(:token)
      assert {:error, :not_found} = Chain.token_from_address_hash(token.contract_address.hash)
    end
  end

  test "stream_uncataloged_token_contract_address_hashes/2 reduces with given reducer and accumulator" do
    insert(:token, cataloged: true)
    %Token{contract_address_hash: uncatalog_address} = insert(:token, cataloged: false)
    assert Chain.stream_uncataloged_token_contract_address_hashes([], &[&1 | &2]) == {:ok, [uncatalog_address]}
  end

  describe "transaction_has_token_transfers?/1" do
    test "returns true if transaction has token transfers" do
      transaction = insert(:transaction)
      insert(:token_transfer, transaction: transaction)

      assert Chain.transaction_has_token_transfers?(transaction.hash) == true
    end

    test "returns false if transaction has no token transfers" do
      transaction = insert(:transaction)

      assert Chain.transaction_has_token_transfers?(transaction.hash) == false
    end
  end

  describe "update_token/2" do
    test "updates a token's values" do
      token = insert(:token, name: nil, symbol: nil, total_supply: nil, decimals: nil, cataloged: false)

      update_params = %{
        name: "Hodl Token",
        symbol: "HT",
        total_supply: 10,
        decimals: 1,
        cataloged: true
      }

      assert {:ok, updated_token} = Chain.update_token(token, update_params)
      assert updated_token.name == update_params.name
      assert updated_token.symbol == update_params.symbol
      assert updated_token.total_supply == Decimal.new(update_params.total_supply)
      assert updated_token.decimals == update_params.decimals
      assert updated_token.cataloged
    end

    test "trims names of whitespace" do
      token = insert(:token, name: nil, symbol: nil, total_supply: nil, decimals: nil, cataloged: false)

      update_params = %{
        name: "      Hodl Token     ",
        symbol: "HT",
        total_supply: 10,
        decimals: 1,
        cataloged: true
      }

      assert {:ok, updated_token} = Chain.update_token(token, update_params)
      assert updated_token.name == "Hodl Token"
      assert Repo.get_by(Address.Name, name: "Hodl Token")
    end

    test "inserts an address name record when token has a name in params" do
      token = insert(:token, name: nil, symbol: nil, total_supply: nil, decimals: nil, cataloged: false)

      update_params = %{
        name: "Hodl Token",
        symbol: "HT",
        total_supply: 10,
        decimals: 1,
        cataloged: true
      }

      Chain.update_token(token, update_params)
      assert Repo.get_by(Address.Name, name: update_params.name, address_hash: token.contract_address_hash)
    end

    test "does not insert address name record when token doesn't have name in params" do
      token = insert(:token, name: nil, symbol: nil, total_supply: nil, decimals: nil, cataloged: false)

      update_params = %{
        cataloged: true
      }

      Chain.update_token(token, update_params)
      refute Repo.get_by(Address.Name, address_hash: token.contract_address_hash)
    end

    test "stores token with big 'decimals' values" do
      token = insert(:token, name: nil, symbol: nil, total_supply: nil, decimals: nil, cataloged: false)

      update_params = %{
        name: "Hodl Token",
        symbol: "HT",
        total_supply: 10,
        decimals: 1_000_000_000_000_000_000,
        cataloged: true
      }

      assert {:ok, updated_token} = Chain.update_token(token, update_params)
    end
  end

  describe "fetch_last_token_balances/1" do
    test "returns the token balances given the address hash" do
      address = insert(:address)
      token_balance = insert(:token_balance, address: address)
      insert(:token_balance, address: build(:address))

      token_balances =
        address.hash
        |> Chain.fetch_last_token_balances()
        |> Enum.map(& &1.address_hash)

      assert token_balances == [token_balance.address_hash]
    end

    test "returns the value from the last block" do
      address = insert(:address)
      token_a = insert(:token, contract_address: build(:contract_address))
      token_b = insert(:token, contract_address: build(:contract_address))

      insert(
        :token_balance,
        address: address,
        block_number: 1000,
        token_contract_address_hash: token_a.contract_address_hash,
        value: 5000
      )

      token_balance_a =
        insert(
          :token_balance,
          address: address,
          block_number: 1001,
          token_contract_address_hash: token_a.contract_address_hash,
          value: 4000
        )

      insert(
        :token_balance,
        address: address,
        block_number: 1000,
        token_contract_address_hash: token_b.contract_address_hash,
        value: 3000
      )

      token_balance_b =
        insert(
          :token_balance,
          address: address,
          block_number: 1001,
          token_contract_address_hash: token_b.contract_address_hash,
          value: 2000
        )

      token_balances = Chain.fetch_last_token_balances(address.hash)

      assert Enum.count(token_balances) == 2
      assert Enum.map(token_balances, & &1.value) == [token_balance_a.value, token_balance_b.value]
    end

    test "returns an empty list when there are no token balances" do
      address = insert(:address)

      insert(:token_balance, address: build(:address))

      assert Chain.fetch_last_token_balances(address.hash) == []
    end

    test "does not consider other blocks when the last block has the value 0" do
      address = insert(:address)
      token = insert(:token, contract_address: build(:contract_address))

      insert(
        :token_balance,
        address: address,
        block_number: 1000,
        token_contract_address_hash: token.contract_address_hash,
        value: 5000
      )

      insert(
        :token_balance,
        address: address,
        block_number: 1001,
        token_contract_address_hash: token.contract_address_hash,
        value: 0
      )

      assert Chain.fetch_last_token_balances(address.hash) == []
    end
  end

  describe "fetch_token_holders_from_token_hash/2" do
    test "returns the last value for each address" do
      %Token{contract_address_hash: contract_address_hash} = insert(:token)
      address = insert(:address)

      insert(
        :token_balance,
        address: address,
        block_number: 1000,
        token_contract_address_hash: contract_address_hash,
        value: 5000
      )

      insert(
        :token_balance,
        block_number: 1001,
        token_contract_address_hash: contract_address_hash,
        value: 4000
      )

      insert(
        :token_balance,
        address: address,
        block_number: 1002,
        token_contract_address_hash: contract_address_hash,
        value: 2000
      )

      values =
        contract_address_hash
        |> Chain.fetch_token_holders_from_token_hash([])
        |> Enum.map(&Decimal.to_integer(&1.value))

      assert values == [4000, 2000]
    end

    test "sort by the highest value" do
      %Token{contract_address_hash: contract_address_hash} = insert(:token)

      insert(
        :token_balance,
        block_number: 1000,
        token_contract_address_hash: contract_address_hash,
        value: 2000
      )

      insert(
        :token_balance,
        block_number: 1001,
        token_contract_address_hash: contract_address_hash,
        value: 1000
      )

      insert(
        :token_balance,
        block_number: 1002,
        token_contract_address_hash: contract_address_hash,
        value: 4000
      )

      insert(
        :token_balance,
        block_number: 1002,
        token_contract_address_hash: contract_address_hash,
        value: 3000
      )

      values =
        contract_address_hash
        |> Chain.fetch_token_holders_from_token_hash([])
        |> Enum.map(&Decimal.to_integer(&1.value))

      assert values == [4000, 3000, 2000, 1000]
    end

    test "returns only token balances that have value" do
      %Token{contract_address_hash: contract_address_hash} = insert(:token)

      insert(
        :token_balance,
        token_contract_address_hash: contract_address_hash,
        value: 0
      )

      assert Chain.fetch_token_holders_from_token_hash(contract_address_hash, []) == []
    end

    test "returns an empty list when there are no address with value greater than 0" do
      %Token{contract_address_hash: contract_address_hash} = insert(:token)

      insert(:token_balance, value: 1000)

      assert Chain.fetch_token_holders_from_token_hash(contract_address_hash, []) == []
    end

    test "ignores the burn address" do
      {:ok, burn_address_hash} = Chain.string_to_address_hash("0x0000000000000000000000000000000000000000")

      burn_address = insert(:address, hash: burn_address_hash)

      %Token{contract_address_hash: contract_address_hash} = insert(:token)

      insert(
        :token_balance,
        address: burn_address,
        token_contract_address_hash: contract_address_hash,
        value: 1000
      )

      assert Chain.fetch_token_holders_from_token_hash(contract_address_hash, []) == []
    end

    test "paginates the result by value and different address" do
      address_a = build(:address, hash: "0xcb2cf1fd3199584ac5faa16c6aca49472dc6495a")
      address_b = build(:address, hash: "0x5f26097334b6a32b7951df61fd0c5803ec5d8354")

      %Token{contract_address_hash: contract_address_hash} = insert(:token)

      first_page =
        insert(
          :token_balance,
          address: address_a,
          token_contract_address_hash: contract_address_hash,
          value: 4000
        )

      second_page =
        insert(
          :token_balance,
          address: address_b,
          token_contract_address_hash: contract_address_hash,
          value: 4000
        )

      paging_options = %PagingOptions{
        key: {first_page.value, first_page.address_hash},
        page_size: 2
      }

      holders_paginated =
        contract_address_hash
        |> Chain.fetch_token_holders_from_token_hash(paging_options: paging_options)
        |> Enum.map(& &1.address_hash)

      assert holders_paginated == [second_page.address_hash]
    end

    test "considers the last block only if it has value" do
      address = insert(:address, hash: "0x5f26097334b6a32b7951df61fd0c5803ec5d8354")
      %Token{contract_address_hash: contract_address_hash} = insert(:token)

      insert(
        :token_balance,
        address: address,
        block_number: 1000,
        token_contract_address_hash: contract_address_hash,
        value: 5000
      )

      insert(
        :token_balance,
        address: address,
        block_number: 1002,
        token_contract_address_hash: contract_address_hash,
        value: 0
      )

      assert Chain.fetch_token_holders_from_token_hash(contract_address_hash, []) == []
    end
  end

  describe "count_token_holders_from_token_hash" do
    test "counts different addresses that have the token" do
      address_a = insert(:address, hash: "0xe49fedd93960a0267b3c3b2c1e2d66028e013fee")
      address_b = insert(:address, hash: "0x5f26097334b6a32b7951df61fd0c5803ec5d8354")

      %Token{contract_address_hash: contract_address_hash} = insert(:token)

      insert(
        :token_balance,
        address: address_a,
        block_number: 1000,
        token_contract_address_hash: contract_address_hash,
        value: 5000
      )

      insert(
        :token_balance,
        address: address_b,
        block_number: 1002,
        token_contract_address_hash: contract_address_hash,
        value: 1000
      )

      assert Chain.count_token_holders_from_token_hash(contract_address_hash) == 2
    end

    test "counts only the last block" do
      address = insert(:address, hash: "0xe49fedd93960a0267b3c3b2c1e2d66028e013fee")

      %Token{contract_address_hash: contract_address_hash} = insert(:token)

      insert(
        :token_balance,
        address: address,
        block_number: 1000,
        token_contract_address_hash: contract_address_hash,
        value: 5000
      )

      insert(
        :token_balance,
        address: address,
        block_number: 1002,
        token_contract_address_hash: contract_address_hash,
        value: 1000
      )

      assert Chain.count_token_holders_from_token_hash(contract_address_hash) == 1
    end

    test "counts only the last block that has value greater than 0" do
      address = insert(:address, hash: "0xe49fedd93960a0267b3c3b2c1e2d66028e013fee")

      %Token{contract_address_hash: contract_address_hash} = insert(:token)

      insert(
        :token_balance,
        address: address,
        block_number: 1000,
        token_contract_address_hash: contract_address_hash,
        value: 5000
      )

      insert(
        :token_balance,
        address: address,
        block_number: 1002,
        token_contract_address_hash: contract_address_hash,
        value: 0
      )

      assert Chain.count_token_holders_from_token_hash(contract_address_hash) == 0
    end
  end

  describe "address_to_transactions_with_token_transfers/2" do
    test "paginates transactions by the block number" do
      address = insert(:address)
      token = insert(:token)

      first_page =
        :transaction
        |> insert()
        |> with_block(insert(:block, number: 1000))

      second_page =
        :transaction
        |> insert()
        |> with_block(insert(:block, number: 999))

      insert(
        :token_transfer,
        to_address: address,
        transaction: first_page,
        token_contract_address: token.contract_address
      )

      insert(
        :token_transfer,
        to_address: address,
        transaction: second_page,
        token_contract_address: token.contract_address
      )

      paging_options = %PagingOptions{
        key: {first_page.block_number, first_page.index},
        page_size: 2
      }

      result =
        address.hash
        |> Chain.address_to_transactions_with_token_transfers(token.contract_address_hash,
          paging_options: paging_options
        )
        |> Enum.map(& &1.hash)

      assert result == [second_page.hash]
    end

    test "doesn't duplicate the transaction when there are multiple transfers for it" do
      address = insert(:address)
      token = insert(:token)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(
        :token_transfer,
        amount: 2,
        to_address: address,
        token_contract_address: token.contract_address,
        transaction: transaction
      )

      insert(
        :token_transfer,
        amount: 1,
        to_address: address,
        token_contract_address: token.contract_address,
        transaction: transaction
      )

      result =
        address.hash
        |> Chain.address_to_transactions_with_token_transfers(token.contract_address_hash)
        |> Enum.map(& &1.hash)

      assert result == [transaction.hash]
    end
  end

  describe "address_to_unique_tokens/2" do
    test "unique tokens can be paginated through token_id" do
      token_contract_address = insert(:contract_address)
      token = insert(:token, contract_address: token_contract_address, type: "ERC-721")

      transaction =
        :transaction
        |> insert()
        |> with_block(insert(:block, number: 1))

      first_page =
        insert(
          :token_transfer,
          to_address: build(:address),
          transaction: transaction,
          token_contract_address: token_contract_address,
          token: token,
          token_id: 11
        )

      second_page =
        insert(
          :token_transfer,
          to_address: build(:address),
          transaction: transaction,
          token_contract_address: token_contract_address,
          token: token,
          token_id: 29
        )

      paging_options = %PagingOptions{key: {first_page.token_id}, page_size: 1}

      unique_tokens_ids_paginated =
        Chain.address_to_unique_tokens(
          token_contract_address.hash,
          paging_options: paging_options
        )
        |> Enum.map(& &1.token_id)

      assert unique_tokens_ids_paginated == [second_page.token_id]
    end
  end

  describe "uncataloged_token_transfer_block_numbers/0" do
    test "returns a list of block numbers" do
      log = insert(:token_transfer_log)
      block_number = log.transaction.block_number
      assert {:ok, [^block_number]} = Chain.uncataloged_token_transfer_block_numbers()
    end
  end
end
