defmodule Explorer.Chain.TokenTest do
  use Explorer.DataCase

  import Explorer.Factory

  alias Explorer.Chain.Token.Instance

  describe "unfetched_erc_721_token_instances_count/0" do
    test "it returns 0 if there are no unfetched token instances" do
      assert Instance.unfetched_erc_721_token_instances_count() == 0
    end

    test "it returns number of unfetched token instances" do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      erc_721_token_address = insert(:contract_address)
      erc_1155_token_address = insert(:contract_address)

      insert(:token, %{contract_address: erc_721_token_address, type: "ERC-721"})
      insert(:token, %{contract_address: erc_1155_token_address, type: "ERC-1155"})

      Enum.each(2..5, fn token_id ->
        insert(:token_transfer, %{
          token_contract_address: erc_721_token_address,
          token_id: token_id,
          token_ids: nil,
          transaction: transaction,
          block: transaction.block,
          block_number: transaction.block_number
        })
      end)

      insert(:token_transfer, %{
        token_contract_address: erc_1155_token_address,
        token_id: nil,
        token_ids: [2, 3, 4, 5, 6],
        transaction: transaction,
        block: transaction.block,
        block_number: transaction.block_number
      })

      insert(:token_instance, %{token_contract_address_hash: erc_721_token_address.hash, token_id: 2})
      insert(:token_instance, %{token_contract_address_hash: erc_721_token_address.hash, token_id: 4})

      insert(:token_instance, %{token_contract_address_hash: erc_1155_token_address.hash, token_id: 5})
      insert(:token_instance, %{token_contract_address_hash: erc_1155_token_address.hash, token_id: 6})

      assert Instance.unfetched_erc_721_token_instances_count() == 2
    end
  end
end
