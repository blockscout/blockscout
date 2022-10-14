defmodule Explorer.Chain.TransactionTest do
  use Explorer.DataCase
  import Mox

  import Mox

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
        block: transaction.block,
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
        block: transaction.block,
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
        block: transaction.block,
        token_contract_address: token.contract_address
      )

      insert(
        :token_transfer,
        to_address: address,
        transaction: transaction,
        block: transaction.block,
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
        block: transaction_a.block,
        transaction: transaction_a
      )

      insert(
        :token_transfer,
        amount: 1,
        to_address: address,
        token_contract_address: token.contract_address,
        block: transaction_b.block,
        transaction: transaction_b
      )

      insert(
        :token_transfer,
        amount: 1,
        to_address: address,
        token_contract_address: token.contract_address,
        block: transaction_c.block,
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

  describe "transaction_hash_to_block_number/1" do
    test "returns only transactions with the specified block number" do
      target_block = insert(:block, number: 1_000_000)

      :transaction
      |> insert()
      |> with_block(target_block)

      :transaction
      |> insert()
      |> with_block(target_block)

      :transaction
      |> insert()
      |> with_block(insert(:block, number: 1_001_101))

      result =
        1_000_000
        |> Transaction.transactions_with_block_number()
        |> Repo.all()
        |> Enum.map(& &1.block_number)

      refute Enum.any?(result, fn block_number -> 1_001_101 == block_number end)
      assert Enum.all?(result, fn block_number -> 1_000_000 == block_number end)
    end
  end

  describe "last_nonce_by_address_query/1" do
    test "returns the nonce value from the last block" do
      address = insert(:address)

      :transaction
      |> insert(nonce: 100, from_address: address)
      |> with_block(insert(:block, number: 1000))

      :transaction
      |> insert(nonce: 300, from_address: address)
      |> with_block(insert(:block, number: 2000))

      last_nonce =
        address.hash
        |> Transaction.last_nonce_by_address_query()
        |> Repo.one()

      assert last_nonce == 300
    end

    test "considers only from_address in transactions" do
      address = insert(:address)

      :transaction
      |> insert(nonce: 100, to_address: address)
      |> with_block(insert(:block, number: 1000))

      last_nonce =
        address.hash
        |> Transaction.last_nonce_by_address_query()
        |> Repo.one()

      assert last_nonce == nil
    end
  end

  describe "decoded_input_data/1" do
    test "that a tranasction that is not a contract call returns a commensurate error" do
      transaction = insert(:transaction)

      assert Transaction.decoded_input_data(transaction) == {:error, :not_a_contract_call}
    end

    test "that a contract call transaction that has no verified contract returns a commensurate error" do
      transaction =
        :transaction
        |> insert(to_address: insert(:contract_address))
        |> Repo.preload(to_address: :smart_contract)

      assert Transaction.decoded_input_data(transaction) == {:error, :contract_not_verified, []}
    end

    test "that a contract call transaction that has a verified contract returns the decoded input data" do
      transaction =
        :transaction_to_verified_contract
        |> insert()
        |> Repo.preload(to_address: :smart_contract)

      EthereumJSONRPC.Mox
      |> expect(
        :json_rpc,
        fn %{
             id: _id,
             method: "eth_getStorageAt",
             params: [
               _,
               "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc",
               "latest"
             ]
           },
           _options ->
          {:ok, "0x0000000000000000000000000000000000000000000000000000000000000000"}
        end
      )
      |> expect(
        :json_rpc,
        fn %{
             id: _id,
             method: "eth_getStorageAt",
             params: [
               _,
               "0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50",
               "latest"
             ]
           },
           _options ->
          {:ok, "0x0000000000000000000000000000000000000000000000000000000000000000"}
        end
      )

      assert Transaction.decoded_input_data(transaction) == {:ok, "60fe47b1", "set(uint256 x)", [{"x", "uint256", 50}]}
    end

    test "that a contract call will look up a match in contract_methods table" do
      :transaction_to_verified_contract
      |> insert()
      |> Repo.preload(to_address: :smart_contract)

      expect(EthereumJSONRPC.Mox, :json_rpc, 2, fn _, _options ->
        {:ok, "0x0000000000000000000000000000000000000000000000000000000000000000"}
      end)

      contract = insert(:smart_contract, contract_code_md5: "123") |> Repo.preload(:address)

      input_data =
        "set(uint)"
        |> ABI.encode([10])
        |> Base.encode16(case: :lower)

      transaction =
        :transaction
        |> insert(to_address: contract.address, input: "0x" <> input_data)
        |> Repo.preload(to_address: :smart_contract)

      EthereumJSONRPC.Mox
      |> expect(
        :json_rpc,
        fn %{
             id: _id,
             method: "eth_getStorageAt",
             params: [
               _,
               "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc",
               "latest"
             ]
           },
           _options ->
          {:ok, "0x0000000000000000000000000000000000000000000000000000000000000000"}
        end
      )
      |> expect(
        :json_rpc,
        fn %{
             id: _id,
             method: "eth_getStorageAt",
             params: [
               _,
               "0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50",
               "latest"
             ]
           },
           _options ->
          {:ok, "0x0000000000000000000000000000000000000000000000000000000000000000"}
        end
      )

      assert Transaction.decoded_input_data(transaction) == {:ok, "60fe47b1", "set(uint256 x)", [{"x", "uint256", 10}]}
    end
  end

  describe "Poison.encode!/1" do
    test "encodes transaction input" do
      assert %{
               insert(:transaction)
               | input: %Explorer.Chain.Data{
                   bytes:
                     <<169, 5, 156, 187, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 193, 108, 45, 196, 42, 228, 149, 239, 119,
                       191, 128, 248>>
                 }
             }
             |> Poison.encode!()
    end
  end
end
