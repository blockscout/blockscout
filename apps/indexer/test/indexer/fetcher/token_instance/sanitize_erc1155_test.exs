defmodule Indexer.Fetcher.TokenInstance.SanitizeERC1155Test do
  use Explorer.DataCase

  alias Explorer.Repo
  alias Explorer.Chain.Token.Instance

  describe "sanitizer test" do
    test "imports token instances" do
      for i <- 0..3 do
        token = insert(:token, type: "ERC-1155")

        insert(:address_current_token_balance,
          token_type: "ERC-1155",
          token_id: i,
          token_contract_address_hash: token.contract_address_hash,
          value: Enum.random(1..100_000)
        )
      end

      assert [] = Repo.all(Instance)

      start_supervised!({Indexer.Fetcher.TokenInstance.SanitizeERC1155, []})
      start_supervised!({Indexer.Fetcher.TokenInstance.Sanitize.Supervisor, [[flush_interval: 1]]})

      :timer.sleep(500)

      instances = Repo.all(Instance)

      assert Enum.count(instances) == 4
      assert Enum.all?(instances, fn instance -> !is_nil(instance.error) and is_nil(instance.metadata) end)
    end
  end
end
