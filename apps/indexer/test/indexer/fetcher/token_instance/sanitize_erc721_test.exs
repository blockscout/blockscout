defmodule Indexer.Fetcher.TokenInstance.SanitizeERC721Test do
  use Explorer.DataCase

  alias Explorer.Repo
  alias Explorer.Chain.Token.Instance
  alias EthereumJSONRPC.Encoder

  describe "sanitizer test" do
    test "imports token instances" do
      for x <- 0..3 do
        erc_721_token = insert(:token, type: "ERC-721")

        tx = insert(:transaction, input: "0xabcd010203040506") |> with_block()

        address = insert(:address)

        insert(:token_transfer,
          transaction: tx,
          block: tx.block,
          block_number: tx.block_number,
          from_address: address,
          token_contract_address: erc_721_token.contract_address,
          token_ids: [x]
        )
      end

      assert [] = Repo.all(Instance)

      start_supervised!({Indexer.Fetcher.TokenInstance.SanitizeERC721, []})

      :timer.sleep(500)

      instances = Repo.all(Instance)

      assert Enum.count(instances) == 4
      assert Enum.all?(instances, fn instance -> !is_nil(instance.error) and is_nil(instance.metadata) end)
    end
  end
end
