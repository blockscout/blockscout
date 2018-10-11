defmodule Explorer.Chain.TransactionTest do
  use Explorer.DataCase

  alias Ecto.Changeset
  alias Explorer.Chain.Transaction

  doctest Transaction

  describe "changeset/2" do
    test "with valid attributes" do
      assert %Changeset{valid?: true} =
               Transaction.changeset(%Transaction{}, %{
                 from_address_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
                 hash: "0x9fc76417374aa880d4449a1f7f31ec597f00b1f6f3dd2d66f4c9c6c445836d8b",
                 value: 1,
                 gas: 21000,
                 gas_price: 10000,
                 input: "0x5c8eff12",
                 nonce: "31337",
                 r: 0x9,
                 s: 0x10,
                 transaction_index: "0x12",
                 v: 27
               })
    end

    test "with invalid attributes" do
      changeset = Transaction.changeset(%Transaction{}, %{racecar: "yellow ham"})
      refute changeset.valid?
    end

    test "it creates a new to address" do
      params = params_for(:transaction, from_address_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca")
      to_address_params = %{hash: "sk8orDi3"}
      changeset_params = Map.merge(params, %{to_address: to_address_params})

      assert %Changeset{valid?: true} = Transaction.changeset(%Transaction{}, changeset_params)
    end
  end

  describe "transactions_with_token_transfers/2" do
    test "returns the transaction when there is token transfer from the given address" do
      address = insert(:address)
      token = insert(:token)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(
        :token_transfer,
        from_address: address,
        transaction: transaction,
        token_contract_address: token.contract_address
      )

      result =
        address.hash
        |> Transaction.transactions_with_token_transfers(token.contract_address_hash)
        |> Repo.all()
        |> Enum.map(& &1.hash)

      assert result == [transaction.hash]
    end

    test "returns the transaction when there is token transfer to the given address" do
      address = insert(:address)
      token = insert(:token)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(
        :token_transfer,
        to_address: address,
        transaction: transaction,
        token_contract_address: token.contract_address
      )

      result =
        address.hash
        |> Transaction.transactions_with_token_transfers(token.contract_address_hash)
        |> Repo.all()
        |> Enum.map(& &1.hash)

      assert result == [transaction.hash]
    end

    test "returns only transactions that have token transfers from the given token hash" do
      address = insert(:address)
      token = insert(:token)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      :transaction
      |> insert()
      |> with_block()

      insert(
        :token_transfer,
        to_address: address,
        transaction: transaction,
        token_contract_address: token.contract_address
      )

      insert(
        :token_transfer,
        to_address: address,
        transaction: transaction,
        token_contract_address: insert(:token).contract_address
      )

      result =
        address.hash
        |> Transaction.transactions_with_token_transfers(token.contract_address_hash)
        |> Repo.all()
        |> Enum.map(& &1.hash)

      assert result == [transaction.hash]
    end

    test "order the results DESC by block_number" do
      address = insert(:address)
      token = insert(:token)

      transaction_a =
        :transaction
        |> insert()
        |> with_block(insert(:block, number: 1000))

      transaction_b =
        :transaction
        |> insert()
        |> with_block(insert(:block, number: 1002))

      transaction_c =
        :transaction
        |> insert()
        |> with_block(insert(:block, number: 1003))

      insert(
        :token_transfer,
        amount: 2,
        to_address: address,
        token_contract_address: token.contract_address,
        transaction: transaction_a
      )

      insert(
        :token_transfer,
        amount: 1,
        to_address: address,
        token_contract_address: token.contract_address,
        transaction: transaction_b
      )

      insert(
        :token_transfer,
        amount: 1,
        to_address: address,
        token_contract_address: token.contract_address,
        transaction: transaction_c
      )

      result =
        address.hash
        |> Transaction.transactions_with_token_transfers(token.contract_address_hash)
        |> Repo.all()
        |> Enum.map(& &1.block_number)

      assert result == [transaction_c.block_number, transaction_b.block_number, transaction_a.block_number]
    end
  end

  describe "consolidate_by_address/1" do
    test "counts transactions and group by addresses" do
      address_a = insert(:address, hash: "0x0000000000000000000000000000000000000b09")
      address_b = insert(:address, hash: "0x0000000000000000000000000000000000000b08")

      insert(:transaction, to_address: address_a, from_address: address_b)

      expected = [
        {address_a.hash, 1},
        {address_b.hash, 1}
      ]

      assert Transaction.consolidate_by_address() == expected
    end

    test "considers the created_contract_address when the to_address is nil" do
      address_a = insert(:address, hash: "0x0000000000000000000000000000000000000b02")
      address_b = insert(:contract_address, hash: "0x0000000000000000000000000000000000000b03")

      insert(
        :transaction,
        from_address: address_a,
        to_address: nil,
        created_contract_address: address_b
      )

      expected = [
        {address_a.hash, 1},
        {address_b.hash, 1}
      ]

      assert Transaction.consolidate_by_address() == expected
    end
  end
end
