# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Indexer.Fetcher.TokenUpdaterTest do
  use Explorer.DataCase

  import Mox

  alias Explorer.Chain
  alias Explorer.Chain.MultichainSearchDb.TokenInfoExportQueue
  alias Explorer.Chain.Token
  alias Explorer.MicroserviceInterfaces.MultichainSearch
  alias Indexer.Fetcher.TokenUpdater

  setup :verify_on_exit!
  setup :set_mox_global

  test "updates tokens metadata on start" do
    insert(:token,
      name: nil,
      symbol: nil,
      decimals: 10,
      cataloged: true,
      metadata_updated_at: DateTime.add(DateTime.utc_now(), -:timer.hours(50), :millisecond)
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

           # the ERC-165 probe, read along with the base metadata of an ERC-20
           # token and reverting on one that does not implement ERC-8056
           %{id: id, method: "eth_call", params: [%{data: _, to: _}, "latest"]} ->
             %{
               id: id,
               error: %{code: -32015, data: "something", message: "some error"},
               jsonrpc: "2.0"
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

    test "exports the ERC-8056 multiplier to the multichain service along with the metadata" do
      initial = Application.get_env(:explorer, MultichainSearch) || []

      Application.put_env(
        :explorer,
        MultichainSearch,
        Keyword.merge(initial, service_url: "http://localhost:1234", api_key: "12345", token_info_chunk_size: 1000)
      )

      on_exit(fn -> Application.put_env(:explorer, MultichainSearch, initial) end)

      plain_token = insert(:token)
      # the row still says ERC-20: the metadata batch is what finds the ERC-8056 interface
      scaled_token = insert(:token)

      TokenUpdater.update_metadata([
        %{name: "Plain", contract_address_hash: to_string(plain_token.contract_address_hash)},
        %{
          name: "Scaled",
          type: "ERC-8056",
          ui_multiplier: 2_000_000_000_000_000_000,
          new_ui_multiplier: 4_000_000_000_000_000_000,
          ui_multiplier_effective_at: ~U[2026-09-01 00:00:00.000000Z],
          contract_address_hash: to_string(scaled_token.contract_address_hash)
        }
      ])

      queue = TokenInfoExportQueue |> Repo.all() |> Map.new(&{&1.address_hash, {&1.data_type, &1.data}})

      assert queue[plain_token.contract_address_hash] ==
               {:metadata, %{"token_type" => "ERC-20", "name" => "Plain", "icon_url" => plain_token.icon_url}}

      assert queue[scaled_token.contract_address_hash] ==
               {:metadata,
                %{
                  "token_type" => "ERC-8056",
                  "name" => "Scaled",
                  "icon_url" => scaled_token.icon_url,
                  "ui_multiplier" => "2000000000000000000",
                  "new_ui_multiplier" => "4000000000000000000",
                  "ui_multiplier_effective_at" => "2026-09-01T00:00:00Z"
                }}

      assert {:ok, %Token{type: "ERC-8056", ui_multiplier: ui_multiplier}} =
               Chain.token_from_address_hash(scaled_token.contract_address_hash)

      assert Decimal.equal?(ui_multiplier, Decimal.new("2000000000000000000"))
    end
  end
end
