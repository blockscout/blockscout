defmodule Explorer.Chain.Token.InstanceTest do
  use Explorer.DataCase

  alias Explorer.Repo
  alias Explorer.Chain.Token.Instance

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
end
