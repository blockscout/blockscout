defmodule Explorer.Chain.TokenTransferTest do
  use Explorer.DataCase

  use Utils.CompileTimeEnvHelper,
    chain_identity: [:explorer, :chain_identity]

  import Explorer.Factory

  alias Explorer.PagingOptions
  alias Explorer.Chain.TokenTransfer

  doctest Explorer.Chain.TokenTransfer

  describe "fetch_token_transfers_from_token_hash/2" do
    test "returns token transfers for the given address" do
      token_contract_address = insert(:contract_address)

      token = insert(:token, contract_address: token_contract_address)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      token_transfer =
        insert(
          :token_transfer,
          to_address: build(:address),
          transaction: transaction,
          token_contract_address: token_contract_address,
          token: token
        )

      another_transaction =
        :transaction
        |> insert()
        |> with_block()

      another_transfer =
        insert(
          :token_transfer,
          to_address: build(:address),
          transaction: another_transaction,
          token_contract_address: token_contract_address,
          token: token
        )

      insert(
        :token_transfer,
        to_address: build(:address),
        transaction: transaction,
        token_contract_address: build(:address),
        token: token
      )

      transfers_primary_keys =
        token_contract_address.hash
        |> TokenTransfer.fetch_token_transfers_from_token_hash([])
        |> Enum.map(&{&1.transaction_hash, &1.log_index})

      assert transfers_primary_keys == [
               {another_transfer.transaction_hash, another_transfer.log_index},
               {token_transfer.transaction_hash, token_transfer.log_index}
             ]
    end

    test "when there isn't token transfers won't show anything" do
      token_contract_address = insert(:contract_address)

      insert(:token, contract_address: token_contract_address)

      transfers_ids =
        token_contract_address.hash
        |> TokenTransfer.fetch_token_transfers_from_token_hash([])
        |> Enum.map(& &1.id)

      assert transfers_ids == []
    end

    test "token transfers can be paginated" do
      token_contract_address = insert(:contract_address)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      token = insert(:token)

      second_page =
        insert(
          :token_transfer,
          block_number: 999,
          to_address: build(:address),
          transaction: transaction,
          token_contract_address: token_contract_address,
          token: token
        )

      first_page =
        insert(
          :token_transfer,
          block_number: 1000,
          to_address: build(:address),
          transaction: transaction,
          token_contract_address: token_contract_address,
          token: token
        )

      paging_options = %PagingOptions{key: {first_page.block_number, first_page.log_index}, page_size: 1}

      token_transfers_primary_keys_paginated =
        token_contract_address.hash
        |> TokenTransfer.fetch_token_transfers_from_token_hash(paging_options: paging_options)
        |> Enum.map(&{&1.transaction_hash, &1.log_index})

      assert token_transfers_primary_keys_paginated == [{second_page.transaction_hash, second_page.log_index}]
    end

    test "paginates considering the log_index when there are repeated block numbers" do
      token_contract_address = insert(:contract_address)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      token = insert(:token)

      token_transfer =
        insert(
          :token_transfer,
          block_number: 1000,
          log_index: 0,
          to_address: build(:address),
          transaction: transaction,
          token_contract_address: token_contract_address,
          token: token
        )

      paging_options = %PagingOptions{key: {token_transfer.block_number, token_transfer.log_index + 1}, page_size: 1}

      token_transfers_primary_keys_paginated =
        token_contract_address.hash
        |> TokenTransfer.fetch_token_transfers_from_token_hash(paging_options: paging_options)
        |> Enum.map(&{&1.transaction_hash, &1.log_index})

      assert token_transfers_primary_keys_paginated == [{token_transfer.transaction_hash, token_transfer.log_index}]
    end
  end

  describe "where_any_address_fields_match/3" do
    test "when to_address_hash match returns transactions hashes list" do
      john = insert(:address)
      paul = insert(:address)
      contract_address = insert(:contract_address)

      transaction =
        :transaction
        |> insert(
          from_address: john,
          from_address_hash: john.hash,
          to_address: contract_address,
          to_address_hash: contract_address.hash
        )
        |> with_block()

      insert(
        :token_transfer,
        from_address: john,
        to_address: paul,
        transaction: transaction,
        amount: 1
      )

      insert(
        :token_transfer,
        from_address: john,
        to_address: paul,
        transaction: transaction,
        amount: 1
      )

      {:ok, transaction_bytes} = Explorer.Chain.Hash.Full.dump(transaction.hash)

      transactions_hashes = TokenTransfer.where_any_address_fields_match(:to, paul.hash, %PagingOptions{page_size: 1})

      assert Enum.member?(transactions_hashes, transaction_bytes) == true
    end

    test "when from_address_hash match returns transactions hashes list" do
      john = insert(:address)
      paul = insert(:address)
      contract_address = insert(:contract_address)

      transaction =
        :transaction
        |> insert(
          from_address: john,
          from_address_hash: john.hash,
          to_address: contract_address,
          to_address_hash: contract_address.hash
        )
        |> with_block()

      insert(
        :token_transfer,
        from_address: john,
        to_address: paul,
        transaction: transaction,
        amount: 1
      )

      insert(
        :token_transfer,
        from_address: john,
        to_address: paul,
        transaction: transaction,
        amount: 1
      )

      {:ok, transaction_bytes} = Explorer.Chain.Hash.Full.dump(transaction.hash)

      transactions_hashes = TokenTransfer.where_any_address_fields_match(:from, john.hash, %PagingOptions{page_size: 1})

      assert Enum.member?(transactions_hashes, transaction_bytes) == true
    end

    test "when to_from_address_hash or from_address_hash match returns transactions hashes list" do
      john = insert(:address)
      paul = insert(:address)
      contract_address = insert(:contract_address)

      transaction_one =
        :transaction
        |> insert(
          from_address: john,
          from_address_hash: john.hash,
          to_address: contract_address,
          to_address_hash: contract_address.hash
        )
        |> with_block()

      insert(
        :token_transfer,
        from_address: john,
        to_address: paul,
        transaction: transaction_one,
        amount: 1
      )

      transaction_two =
        :transaction
        |> insert(
          from_address: john,
          from_address_hash: john.hash,
          to_address: contract_address,
          to_address_hash: contract_address.hash
        )
        |> with_block()

      insert(
        :token_transfer,
        from_address: paul,
        to_address: john,
        transaction: transaction_two,
        amount: 1
      )

      {:ok, transaction_one_bytes} = Explorer.Chain.Hash.Full.dump(transaction_one.hash)
      {:ok, transaction_two_bytes} = Explorer.Chain.Hash.Full.dump(transaction_two.hash)

      transactions_hashes = TokenTransfer.where_any_address_fields_match(nil, john.hash, %PagingOptions{page_size: 2})

      assert Enum.member?(transactions_hashes, transaction_one_bytes) == true
      assert Enum.member?(transactions_hashes, transaction_two_bytes) == true
    end

    test "paginates result from to_from_address_hash and from_address_hash match" do
      john = insert(:address)
      paul = insert(:address)
      contract_address = insert(:contract_address)

      transaction_one =
        :transaction
        |> insert(
          from_address: paul,
          from_address_hash: paul.hash,
          to_address: contract_address,
          to_address_hash: contract_address.hash
        )
        |> with_block(number: 1)

      insert(
        :token_transfer,
        from_address: john,
        to_address: paul,
        transaction: transaction_one,
        amount: 1
      )

      transaction_two =
        :transaction
        |> insert(
          from_address: paul,
          from_address_hash: paul.hash,
          to_address: contract_address,
          to_address_hash: contract_address.hash
        )
        |> with_block(number: 2)

      insert(
        :token_transfer,
        from_address: paul,
        to_address: john,
        transaction: transaction_two,
        amount: 1
      )

      {:ok, transaction_one_bytes} = Explorer.Chain.Hash.Full.dump(transaction_one.hash)

      page_two =
        TokenTransfer.where_any_address_fields_match(nil, john.hash, %PagingOptions{
          page_size: 1,
          key: {transaction_two.block_number, transaction_two.index}
        })

      assert Enum.member?(page_two, transaction_one_bytes) == true
    end
  end

  describe "uncataloged_token_transfer_block_numbers/0" do
    test "returns a list of block numbers" do
      block = insert(:block)
      address = insert(:address)

      log =
        insert(:token_transfer_log,
          transaction:
            insert(:transaction,
              block_number: block.number,
              block_hash: block.hash,
              cumulative_gas_used: 0,
              gas_used: 0,
              index: 0
            ),
          block: block,
          address_hash: address.hash,
          address: address
        )

      block_number = log.block_number
      assert {:ok, [^block_number]} = TokenTransfer.uncataloged_token_transfer_block_numbers()
    end
  end

  if @chain_identity == {:optimism, :celo} do
    test "returns block numbers for Celo epoch blocks with nil transaction_hash" do
      log =
        insert(:token_transfer_log,
          transaction: nil,
          transaction_hash: nil
        )

      block_number = log.block_number
      assert {:ok, [^block_number]} = TokenTransfer.uncataloged_token_transfer_block_numbers()
    end

    test "does not return block numbers when matching token transfer exists for Celo epoch blocks" do
      log =
        insert(:token_transfer_log,
          transaction: nil,
          transaction_hash: nil
        )

      from_address_hash =
        log.second_topic
        |> to_string()
        |> String.replace_prefix("0x000000000000000000000000", "0x")

      to_address_hash =
        log.third_topic
        |> to_string()
        |> String.replace_prefix("0x000000000000000000000000", "0x")

      token_contract_address = log.address
      to_address = insert(:address, hash: to_address_hash)
      from_address = insert(:address, hash: from_address_hash)

      insert(:token_transfer,
        transaction: nil,
        transaction_hash: nil,
        block: log.block,
        log_index: log.index,
        token_contract_address: token_contract_address,
        from_address: from_address,
        to_address: to_address
      )

      assert {:ok, []} = TokenTransfer.uncataloged_token_transfer_block_numbers()
    end
  end

  describe "ERC-7984 token transfers" do
    test "filters ERC-7984 token transfers correctly" do
      erc7984_token = insert(:token, type: "ERC-7984")
      erc20_token = insert(:token, type: "ERC-20")

      transaction = insert(:transaction) |> with_block()

      erc7984_transfer =
        insert(
          :token_transfer,
          token_type: "ERC-7984",
          amount: nil,
          token_ids: nil,
          token: erc7984_token,
          token_contract_address: erc7984_token.contract_address,
          transaction: transaction
        )

      _erc20_transfer =
        insert(
          :token_transfer,
          token_type: "ERC-20",
          token: erc20_token,
          token_contract_address: erc20_token.contract_address,
          transaction: transaction
        )

      # Test that ERC-7984 transfers can be queried
      transfers = TokenTransfer.fetch_token_transfers_from_token_hash(erc7984_token.contract_address_hash, [])

      assert length(transfers) == 1
      assert hd(transfers).token_type == "ERC-7984"
      assert hd(transfers).amount == nil
      assert hd(transfers).token_ids == nil
    end
  end
end
