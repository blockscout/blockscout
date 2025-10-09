defmodule Explorer.Chain.Token.InstanceTest do
  use Explorer.DataCase

  alias Explorer.Repo
  alias Explorer.Chain.Token.Instance
  alias Explorer.PagingOptions

  describe "stream_not_inserted_token_instances/2" do
    test "reduces with given reducer and accumulator for ERC-721 token" do
      token_contract_address = insert(:contract_address)
      token = insert(:token, contract_address: token_contract_address, type: "ERC-721")

      transaction =
        :transaction
        |> insert()
        |> with_block(insert(:block, number: 1))

      token_transfer =
        insert(
          :token_transfer,
          block_number: 1000,
          to_address: build(:address),
          transaction: transaction,
          token_contract_address: token_contract_address,
          token: token,
          token_ids: [11]
        )

      assert [result] = 5 |> Instance.not_inserted_token_instances_query() |> Repo.all()
      assert result.token_id == List.first(token_transfer.token_ids)
      assert result.contract_address_hash == token_transfer.token_contract_address_hash
    end

    test "does not fetch token transfers without token_ids" do
      token_contract_address = insert(:contract_address)
      token = insert(:token, contract_address: token_contract_address, type: "ERC-721")

      transaction =
        :transaction
        |> insert()
        |> with_block(insert(:block, number: 1))

      insert(
        :token_transfer,
        block_number: 1000,
        to_address: build(:address),
        transaction: transaction,
        token_contract_address: token_contract_address,
        token: token,
        token_ids: nil
      )

      assert [] = 5 |> Instance.not_inserted_token_instances_query() |> Repo.all()
    end

    test "do not fetch records with token instances" do
      token_contract_address = insert(:contract_address)
      token = insert(:token, contract_address: token_contract_address, type: "ERC-721")

      transaction =
        :transaction
        |> insert()
        |> with_block(insert(:block, number: 1))

      token_transfer =
        insert(
          :token_transfer,
          block_number: 1000,
          to_address: build(:address),
          transaction: transaction,
          token_contract_address: token_contract_address,
          token: token,
          token_ids: [11]
        )

      insert(:token_instance,
        token_id: List.first(token_transfer.token_ids),
        token_contract_address_hash: token_transfer.token_contract_address_hash
      )

      assert [] = 5 |> Instance.not_inserted_token_instances_query() |> Repo.all()
    end
  end

  describe "address_to_unique_tokens/2" do
    test "unique tokens can be paginated through token_id" do
      token_contract_address = insert(:contract_address)
      token = insert(:token, contract_address: token_contract_address, type: "ERC-721")

      insert(
        :token_instance,
        token_contract_address_hash: token_contract_address.hash,
        token_id: 11
      )

      insert(
        :token_instance,
        token_contract_address_hash: token_contract_address.hash,
        token_id: 29
      )

      transaction =
        :transaction
        |> insert()
        |> with_block(insert(:block, number: 1))

      first_page =
        insert(
          :token_transfer,
          block_number: 1000,
          to_address: build(:address),
          transaction: transaction,
          token_contract_address: token_contract_address,
          token: token,
          token_ids: [29]
        )

      second_page =
        insert(
          :token_transfer,
          block_number: 999,
          to_address: build(:address),
          transaction: transaction,
          token_contract_address: token_contract_address,
          token: token,
          token_ids: [11]
        )

      paging_options = %PagingOptions{key: {List.first(first_page.token_ids)}, page_size: 1}

      unique_tokens_ids_paginated =
        token_contract_address.hash
        |> Instance.address_to_unique_tokens(token, paging_options: paging_options)
        |> Enum.map(& &1.token_id)

      assert unique_tokens_ids_paginated == [List.first(second_page.token_ids)]
    end
  end

  describe "nft_instance_by_token_id_and_token_address/2" do
    test "return NFT instance" do
      token = insert(:token)

      token_id = 10

      insert(:token_instance,
        token_contract_address_hash: token.contract_address_hash,
        token_id: token_id
      )

      assert {:ok, result} =
               Instance.nft_instance_by_token_id_and_token_address(
                 token_id,
                 token.contract_address_hash
               )

      assert result.token_id == Decimal.new(token_id)
    end
  end

  describe "batch_upsert_token_instances/1" do
    test "insert a new token instance with valid params" do
      token = insert(:token)

      params = %{
        token_id: 1,
        token_contract_address_hash: token.contract_address_hash,
        metadata: %{uri: "http://example.com"}
      }

      [result] = Instance.batch_upsert_token_instances([params])

      assert result.token_id == Decimal.new(1)
      assert result.metadata == %{"uri" => "http://example.com"}
      assert result.token_contract_address_hash == token.contract_address_hash
    end

    test "inserts just an error without metadata" do
      token = insert(:token)
      error = "no uri"

      params = %{
        token_id: 1,
        token_contract_address_hash: token.contract_address_hash,
        error: error
      }

      [result] = Instance.batch_upsert_token_instances([params])

      assert result.error == error
    end

    test "nillifies error" do
      token = insert(:token)

      insert(:token_instance,
        token_id: 1,
        token_contract_address_hash: token.contract_address_hash,
        error: "no uri",
        metadata: nil
      )

      params = %{
        token_id: 1,
        token_contract_address_hash: token.contract_address_hash,
        metadata: %{uri: "http://example1.com"}
      }

      [result] = Instance.batch_upsert_token_instances([params])

      assert is_nil(result.error)
      assert result.metadata == %{"uri" => "http://example1.com"}
    end
  end
end
