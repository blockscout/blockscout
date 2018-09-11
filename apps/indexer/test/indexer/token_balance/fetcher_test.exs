defmodule Indexer.TokenBalance.FetcherTest do
  use EthereumJSONRPC.Case
  use Explorer.DataCase

  import Mox

  alias Explorer.Chain.Address
  alias Indexer.TokenBalance

  setup :verify_on_exit!
  setup :set_mox_global

  describe "init/3" do
    test "returns unfetched token balances" do
      %Address.TokenBalance{address_hash: address_hash} =
        insert(:token_balance, block_number: 1_000, value_fetched_at: nil)

      insert(:token_balance, value_fetched_at: DateTime.utc_now())

      assert TokenBalance.Fetcher.init([], &[&1.address_hash | &2], nil) == [address_hash]
    end
  end

  describe "run/3" do
    test "imports the given token balances" do
      token_balance = insert(:token_balance, value_fetched_at: nil, value: nil)

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        fn [%{id: _, method: _, params: [%{data: _, to: _}, _]}], _options ->
          {:ok,
           [
             %{
               id: "balanceOf",
               jsonrpc: "2.0",
               result: "0x00000000000000000000000000000000000000000000d3c21bcecceda1000000"
             }
           ]}
        end
      )

      assert TokenBalance.Fetcher.run([token_balance], 0, nil) == :ok

      token_balance_updated =
        Address.TokenBalance
        |> Explorer.Repo.get_by(address_hash: token_balance.address_hash)

      assert token_balance_updated.value == Decimal.new(1_000_000_000_000_000_000_000_000)
      assert token_balance_updated.value_fetched_at != nil
    end
  end
end
