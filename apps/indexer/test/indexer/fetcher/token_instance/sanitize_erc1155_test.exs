defmodule Indexer.Fetcher.TokenInstance.SanitizeERC1155Test do
  use Explorer.DataCase

  import Mox

  alias Explorer.Repo
  alias Explorer.Chain.Token.Instance

  setup :verify_on_exit!
  setup :set_mox_global

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

      # Mock the ERC-1155 uri() calls to return errors so instances get error field populated
      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn _requests, _options ->
        {:ok,
         [
           %{id: 0, error: %{code: -32015, message: "VM execution error"}},
           %{id: 1, error: %{code: -32015, message: "VM execution error"}},
           %{id: 2, error: %{code: -32015, message: "VM execution error"}},
           %{id: 3, error: %{code: -32015, message: "VM execution error"}}
         ]}
      end)

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
