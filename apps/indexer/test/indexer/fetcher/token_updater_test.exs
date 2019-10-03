defmodule Indexer.Fetcher.TokenUpdaterTest do
  use Explorer.DataCase

  import Mox

  alias Explorer.Chain
  alias Explorer.Chain.Token
  alias Indexer.Fetcher.TokenUpdater

  setup :verify_on_exit!
  setup :set_mox_global

  test "updates tokens metadata on start" do
    insert(:token,
      name: nil,
      symbol: nil,
      decimals: 10,
      cataloged: true,
      updated_at: DateTime.add(DateTime.utc_now(), -:timer.hours(50), :millisecond)
    )

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

    pid = TokenUpdater.Supervisor.Case.start_supervised!(json_rpc_named_arguments: [])

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

      params = %{name: "Bancor", symbol: "BNT", contract_address_hash: to_string(token.contract_address_hash)}

      TokenUpdater.update_metadata([params])

      assert {:ok,
              %Token{
                name: "Bancor",
                symbol: "BNT",
                cataloged: true
              }} = Chain.token_from_address_hash(token.contract_address_hash)
    end
  end
end
