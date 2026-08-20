# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Indexer.Fetcher.TokenUIMultiplierUpdaterTest do
  use Explorer.DataCase

  import Mox

  alias Explorer.Chain.Token.UIMultiplierChange
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

  setup do
    stub_json_rpc(true)

    :ok
  end

  # The shape `Indexer.Transform.TokenTransfers.parse_ui_multiplier_changes/1`
  # produces: the contract hash is still the string taken off the log.
  defp change_params(token, block_number, log_index, old, new, effective_at) do
    %{
      token_contract_address_hash: to_string(token.contract_address.hash),
      block_number: block_number,
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

    test "gives up on a change whose contract hash cannot be parsed" do
      change =
        %{
          token_contract_address_hash: "not a hash",
          block_number: 200,
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
