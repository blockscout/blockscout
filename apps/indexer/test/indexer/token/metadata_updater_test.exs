defmodule Indexer.Token.MetadataUpdaterTest do
  use Explorer.DataCase

  import Mox

  alias Explorer.Chain
  alias Explorer.Chain.Token
  alias Indexer.Token.MetadataUpdater

  setup :verify_on_exit!
  setup :set_mox_global

  test "updates tokens metadata on start" do
    insert(:token, name: nil, symbol: nil, decimals: 10, cataloged: true)

    expect(
      EthereumJSONRPC.Mox,
      :json_rpc,
      1,
      fn requests, _opts ->
        {:ok,
         Enum.map(requests, fn
           %{id: id, method: "eth_call", params: [%{data: "0x313ce567", to: _}, "latest"]} ->
             %{
               id: id,
               result: "0x0000000000000000000000000000000000000000000000000000000000000012"
             }

           %{id: id, method: "eth_call", params: [%{data: "0x06fdde03", to: _}, "latest"]} ->
             %{
               id: id,
               result:
                 "0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000642616e636f720000000000000000000000000000000000000000000000000000"
             }

           %{id: id, method: "eth_call", params: [%{data: "0x95d89b41", to: _}, "latest"]} ->
             %{
               id: id,
               result:
                 "0x00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000003424e540000000000000000000000000000000000000000000000000000000000"
             }

           %{id: id, method: "eth_call", params: [%{data: "0x18160ddd", to: _}, "latest"]} ->
             %{
               id: id,
               result: "0x0000000000000000000000000000000000000000000000000de0b6b3a7640000"
             }
         end)}
      end
    )

    pid = start_supervised!({MetadataUpdater, %{update_interval: 1}})

    wait_for_results(fn ->
      updated = Repo.one!(from(t in Token, where: t.cataloged == true and not is_nil(t.name), limit: 1))

      assert updated.name != nil
      assert updated.symbol != nil
    end)

    # Terminates the process so it finishes all Ecto processes.
    GenServer.stop(pid)
  end

  describe "update_metadata/1" do
    test "updates the metadata for a list of tokens" do
      token = insert(:token, name: nil, symbol: nil, decimals: 10)

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        1,
        fn requests, _opts ->
          {:ok,
           Enum.map(requests, fn
             %{id: id, method: "eth_call", params: [%{data: "0x313ce567", to: _}, "latest"]} ->
               %{
                 id: id,
                 result: "0x0000000000000000000000000000000000000000000000000000000000000012"
               }

             %{id: id, method: "eth_call", params: [%{data: "0x06fdde03", to: _}, "latest"]} ->
               %{
                 id: id,
                 result:
                   "0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000642616e636f720000000000000000000000000000000000000000000000000000"
               }

             %{id: id, method: "eth_call", params: [%{data: "0x95d89b41", to: _}, "latest"]} ->
               %{
                 id: id,
                 result:
                   "0x00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000003424e540000000000000000000000000000000000000000000000000000000000"
               }

             %{id: id, method: "eth_call", params: [%{data: "0x18160ddd", to: _}, "latest"]} ->
               %{
                 id: id,
                 result: "0x0000000000000000000000000000000000000000000000000de0b6b3a7640000"
               }
           end)}
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
