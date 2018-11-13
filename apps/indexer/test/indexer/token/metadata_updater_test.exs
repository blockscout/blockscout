defmodule Indexer.Token.MetadataUpdaterTest do
  use Explorer.DataCase

  import Mox

  alias Explorer.Chain
  alias Explorer.Chain.Token
  alias Indexer.Token.MetadataUpdater

  setup :verify_on_exit!

  describe "update_metadata/1" do
    test "updates the metadata for a list of tokens" do
      token = insert(:token, name: nil, symbol: nil, decimals: 10)

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        1,
        fn [%{id: "decimals"}, %{id: "name"}, %{id: "symbol"}, %{id: "totalSupply"}], _opts ->
          {:ok,
           [
             %{
               id: "decimals",
               result: "0x0000000000000000000000000000000000000000000000000000000000000012"
             },
             %{
               id: "name",
               result:
                 "0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000642616e636f720000000000000000000000000000000000000000000000000000"
             },
             %{
               id: "symbol",
               result:
                 "0x00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000003424e540000000000000000000000000000000000000000000000000000000000"
             },
             %{
               id: "totalSupply",
               result: "0x0000000000000000000000000000000000000000000000000de0b6b3a7640000"
             }
           ]}
        end
      )

      MetadataUpdater.update_metadata([token.contract_address_hash])

      expected_supply = Decimal.new(1_000_000_000_000_000_000)

      decimals_expected = Decimal.new(18)

      assert {:ok,
              %Token{
                name: "Bancor",
                symbol: "BNT",
                total_supply: ^expected_supply,
                decimals: ^decimals_expected,
                cataloged: true
              }} = Chain.token_from_address_hash(token.contract_address_hash)
    end
  end
end
