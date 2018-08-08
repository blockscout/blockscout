defmodule Explorer.Chain.TokenTransferTest do
  use Explorer.DataCase

  import Explorer.Factory

  alias Explorer.PagingOptions
  alias Explorer.Chain.TokenTransfer

  doctest Explorer.Chain.TokenTransfer

  describe "fetch_token_transfers/2" do
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

      transfers_ids =
        token_contract_address.hash
        |> TokenTransfer.fetch_token_transfers_from_token_hash([])
        |> Enum.map(& &1.id)

      assert transfers_ids == [another_transfer.id, token_transfer.id]
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
          to_address: build(:address),
          transaction: transaction,
          token_contract_address: token_contract_address,
          token: token
        )

      first_page =
        insert(
          :token_transfer,
          to_address: build(:address),
          transaction: transaction,
          token_contract_address: token_contract_address,
          token: token
        )

      paging_options = %PagingOptions{key: first_page.inserted_at, page_size: 1}

      token_transfers_ids_paginated =
        TokenTransfer.fetch_token_transfers_from_token_hash(
          token_contract_address.hash,
          paging_options: paging_options
        )
        |> Enum.map(& &1.id)

      assert token_transfers_ids_paginated == [second_page.id]
    end
  end

  describe "count_token_transfers/1" do
    test "counts how many token transfers a token has" do
      token_contract_address = insert(:contract_address)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      token = insert(:token)

      insert(
        :token_transfer,
        to_address: build(:address),
        transaction: transaction,
        token_contract_address: token_contract_address,
        token: token
      )

      insert(
        :token_transfer,
        to_address: build(:address),
        transaction: transaction,
        token_contract_address: token_contract_address,
        token: token
      )

      assert TokenTransfer.count_token_transfers_from_token_hash(token_contract_address.hash) == 2
    end
  end

  describe "count_addresses_in_transfers/1" do
    test "counts how many unique addresses that appeared at `to` or `from`" do
      token_contract_address = insert(:contract_address)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      john_address = insert(:address)
      jane_address = insert(:address)
      bob_address = insert(:address)

      insert(
        :token_transfer,
        from_address: jane_address,
        to_address: john_address,
        transaction: transaction,
        token_contract_address: token_contract_address
      )

      insert(
        :token_transfer,
        from_address: john_address,
        to_address: jane_address,
        transaction: transaction,
        token_contract_address: token_contract_address
      )

      insert(
        :token_transfer,
        from_address: bob_address,
        to_address: jane_address,
        transaction: transaction,
        token_contract_address: token_contract_address
      )

      insert(
        :token_transfer,
        from_address: jane_address,
        to_address: bob_address,
        transaction: transaction,
        token_contract_address: token_contract_address
      )

      assert TokenTransfer.count_addresses_in_token_transfers_from_token_hash(token_contract_address.hash) == 3
    end
  end
end
