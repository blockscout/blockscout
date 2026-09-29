# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Indexer.Fetcher.TokenUIMultiplierUpdaterTest do
  use Explorer.DataCase

  import Mox

  alias Explorer.Chain.MultichainSearchDb.TokenInfoExportQueue
  alias Explorer.Chain.Token.UIMultiplierChange
  alias Explorer.MicroserviceInterfaces.MultichainSearch
  alias Indexer.Fetcher.TokenUIMultiplierUpdater

  @abi_true "0x0000000000000000000000000000000000000000000000000000000000000001"
  @abi_false "0x0000000000000000000000000000000000000000000000000000000000000000"

  setup :verify_on_exit!
  setup :set_mox_global

  @one Decimal.new("1000000000000000000")
  @two Decimal.new("2000000000000000000")
  @four Decimal.new("4000000000000000000")

  # supportsInterface(0xa60bf13d) == true; the getters revert, which keeps these
  # tests about the history rather than the multiplier columns
  defp stub_json_rpc(supports_interface?) do
    stub(EthereumJSONRPC.Mox, :json_rpc, fn requests, _opts ->
      {:ok,
       Enum.map(requests, fn %{id: id, params: [%{data: data}, _]} ->
         cond do
           String.starts_with?(data, "0x01ffc9a7") ->
             %{id: id, result: if(supports_interface?, do: @abi_true, else: @abi_false)}

           true ->
             %{id: id, error: %{code: -32015, data: "something", message: "execution reverted"}, jsonrpc: "2.0"}
         end
       end)}
    end)
  end

  # supportsInterface(0xa60bf13d) == true and the getters answer: the multiplier
  # is 2.0 and becomes 4.0 at `effective_at`
  defp stub_json_rpc_with_getters(effective_at) do
    stub(EthereumJSONRPC.Mox, :json_rpc, fn requests, _opts ->
      {:ok,
       Enum.map(requests, fn %{id: id, params: [%{data: data}, _]} ->
         cond do
           String.starts_with?(data, "0x01ffc9a7") -> %{id: id, result: @abi_true}
           String.starts_with?(data, "0xa60bf13d") -> %{id: id, result: abi_uint(@two)}
           String.starts_with?(data, "0xdc767007") -> %{id: id, result: abi_uint(@four)}
           String.starts_with?(data, "0x97a4064f") -> %{id: id, result: abi_uint(DateTime.to_unix(effective_at))}
         end
       end)}
    end)
  end

  defp abi_uint(%Decimal{} = value), do: value |> Decimal.to_integer() |> abi_uint()

  defp abi_uint(value) when is_integer(value),
    do: "0x" <> (value |> Integer.to_string(16) |> String.downcase() |> String.pad_leading(64, "0"))

  defp enable_multichain_search do
    initial = Application.get_env(:explorer, MultichainSearch) || []

    Application.put_env(
      :explorer,
      MultichainSearch,
      Keyword.merge(initial, service_url: "http://localhost:1234", api_key: "12345", token_info_chunk_size: 1000)
    )

    on_exit(fn -> Application.put_env(:explorer, MultichainSearch, initial) end)
  end

  setup do
    stub_json_rpc(true)

    :ok
  end

  # The shape `Indexer.Transform.TokenTransfers.parse_ui_multiplier_changes/1`
  # produces: both hashes are still the strings taken off the log.
  defp change_params(token, block_number, log_index, old, new, effective_at) do
    block = insert(:block, number: block_number)

    %{
      token_contract_address_hash: to_string(token.contract_address.hash),
      block_number: block_number,
      block_hash: to_string(block.hash),
      log_index: log_index,
      old_multiplier: old,
      new_multiplier: new,
      effective_at: effective_at
    }
  end

  defp run_update(changes) do
    # the updater is registered by name, so a test driving it twice reuses it
    pid = Process.whereis(TokenUIMultiplierUpdater) || start_supervised!(TokenUIMultiplierUpdater)

    TokenUIMultiplierUpdater.add_changes(changes)
    send(pid, :update)

    # a `:sys` call is answered only after the queued cast and info messages
    # have been handled, which makes the asynchronous updater testable
    :sys.get_state(pid)

    pid
  end

  defp recorded_changes(token) do
    UIMultiplierChange
    |> Repo.all()
    |> Enum.filter(&(&1.token_contract_address_hash == token.contract_address.hash))
    |> Enum.sort_by(&{&1.block_number, &1.log_index})
  end

  describe "add_changes/1" do
    test "records the announced change" do
      token = insert(:token)

      run_update([change_params(token, 200, 0, @two, @four, ~U[2026-09-01 00:00:00.000000Z])])

      assert [change] = recorded_changes(token)
      assert change.block_number == 200
      assert change.log_index == 0
      assert Decimal.equal?(change.old_multiplier, @two)
      assert Decimal.equal?(change.new_multiplier, @four)
    end

    test "converges when the same change arrives twice" do
      token = insert(:token)
      change = change_params(token, 200, 0, @two, @four, ~U[2026-09-01 00:00:00.000000Z])

      run_update([change])
      run_update([%{change | new_multiplier: @one}])

      assert [only_change] = recorded_changes(token)
      assert Decimal.equal?(only_change.new_multiplier, @one)
    end

    test "sends nothing to the updater when no log announced a change" do
      # the common case: a block with ordinary transfers leaves the state empty
      # and `update_token/2` is never reached
      assert TokenUIMultiplierUpdater.add_changes([]) == :ok
    end

    test "keeps the change until the token it belongs to is indexed" do
      # the block import inserts the token together with the transfers of its
      # block, but this updater runs on its own schedule and can get there first
      token = build(:token)
      change = change_params(token, 200, 0, @two, @four, ~U[2026-09-01 00:00:00.000000Z])

      pid = run_update([change])

      assert recorded_changes(token) == []
      assert %{^change => 1} = :sys.get_state(pid)

      insert(:token, contract_address: token.contract_address)
      run_update([])

      assert [%{block_number: 200}] = recorded_changes(token)
      assert :sys.get_state(pid) == %{}
    end

    test "gives up on a change whose token never gets indexed" do
      token = build(:token)
      change = change_params(token, 200, 0, @two, @four, ~U[2026-09-01 00:00:00.000000Z])

      pid = run_update([change])

      state =
        Enum.reduce(1..12, :sys.get_state(pid), fn _attempt, _acc ->
          send(pid, :update)
          :sys.get_state(pid)
        end)

      assert state == %{}
      assert recorded_changes(token) == []
    end

    test "records nothing for a contract that does not claim the ERC-165 interface" do
      stub_json_rpc(false)

      token = insert(:token)

      run_update([change_params(token, 200, 0, @two, @four, ~U[2026-09-01 00:00:00.000000Z])])

      assert recorded_changes(token) == []
      assert %{type: "ERC-20"} = Repo.reload(token)
    end

    test "keeps the history of a token whose metadata is skipped" do
      token = insert(:token, skip_metadata: true)

      run_update([change_params(token, 200, 0, @two, @four, ~U[2026-09-01 00:00:00.000000Z])])

      assert [%{block_number: 200}] = recorded_changes(token)
    end

    test "sends the refreshed token metadata to the multichain service" do
      effective_at = ~U[2026-09-01 00:00:00.000000Z]
      stub_json_rpc_with_getters(effective_at)
      enable_multichain_search()

      token = insert(:token)

      run_update([change_params(token, 200, 0, @two, @four, effective_at)])

      assert [%TokenInfoExportQueue{address_hash: address_hash, data_type: :metadata, data: data}] =
               Repo.all(TokenInfoExportQueue)

      assert address_hash == token.contract_address_hash

      assert data == %{
               "token_type" => "ERC-8056",
               "name" => token.name,
               "symbol" => token.symbol,
               "decimals" => 18,
               "total_supply" => "1000000000",
               "icon_url" => token.icon_url,
               "ui_multiplier" => "2000000000000000000",
               "new_ui_multiplier" => "4000000000000000000",
               "ui_multiplier_effective_at" => "2026-09-01T00:00:00Z"
             }
    end

    test "sends nothing to the multichain service when it is disabled" do
      effective_at = ~U[2026-09-01 00:00:00.000000Z]
      stub_json_rpc_with_getters(effective_at)

      token = insert(:token)

      run_update([change_params(token, 200, 0, @two, @four, effective_at)])

      assert %{type: "ERC-8056", new_ui_multiplier: new_ui_multiplier} = Repo.reload(token)
      assert Decimal.equal?(new_ui_multiplier, @four)
      assert Repo.all(TokenInfoExportQueue) == []
    end

    test "gives up on a change whose contract hash cannot be parsed" do
      change =
        %{
          token_contract_address_hash: "not a hash",
          block_number: 200,
          block_hash: to_string(insert(:block, number: 200).hash),
          log_index: 0,
          old_multiplier: @two,
          new_multiplier: @four,
          effective_at: ~U[2026-09-01 00:00:00.000000Z]
        }

      pid = run_update([change])

      # retrying it forever would never succeed
      assert :sys.get_state(pid) == %{}
    end
  end
end
