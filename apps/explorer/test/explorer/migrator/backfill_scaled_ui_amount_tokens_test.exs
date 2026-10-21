# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.BackfillScaledUIAmountTokensTest do
  use Explorer.DataCase, async: false

  import Ecto.Query
  import Mox

  alias Explorer.Chain.Token.{ScaledUIAmount, UIMultiplierChange}
  alias Explorer.Migrator.{BackfillScaledUIAmountTokens, MigrationStatus}
  alias Explorer.Repo

  @abi_true "0x0000000000000000000000000000000000000000000000000000000000000001"
  @abi_false "0x0000000000000000000000000000000000000000000000000000000000000000"

  setup :set_mox_global

  # supportsInterface(0xa60bf13d); nothing is recorded without the claim
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
    Repo.delete_all(
      from(status in MigrationStatus, where: status.migration_name == ^BackfillScaledUIAmountTokens.migration_name())
    )

    stub_json_rpc(true)

    :ok
  end

  @one 1_000_000_000_000_000_000
  @two 2_000_000_000_000_000_000
  # 2026-01-01T00:00:00Z
  @effective_at_unix 1_767_225_600

  defp ui_multiplier_updated_log(token, block, log_index, old, new, effective_at_unix) do
    data =
      [old, new, effective_at_unix]
      |> Enum.map(&(&1 |> Integer.to_string(16) |> String.downcase() |> String.pad_leading(64, "0")))
      |> Enum.join()

    insert(:log,
      address: token.contract_address,
      block: block,
      block_number: block.number,
      index: log_index,
      first_topic: ScaledUIAmount.ui_multiplier_updated_event(),
      second_topic: nil,
      third_topic: nil,
      fourth_topic: nil,
      data: "0x" <> data
    )
  end

  defp run_migration do
    {:ok, pid} = BackfillScaledUIAmountTokens.start_link([])
    ref = Process.monitor(pid)

    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 5_000
  end

  defp changes_of(token) do
    UIMultiplierChange
    |> Repo.all()
    |> Enum.filter(&(&1.token_contract_address_hash == token.contract_address_hash))
    |> Enum.sort_by(&{&1.block_number, &1.log_index})
  end

  describe "Backfill ERC-8056 state from logs" do
    test "records the history and types the token from the log alone" do
      token = insert(:token)
      block = insert(:block, number: 100)
      ui_multiplier_updated_log(token, block, 3, @one, @two, @effective_at_unix)

      assert MigrationStatus.get_status(BackfillScaledUIAmountTokens.migration_name()) == nil

      run_migration()

      assert [change] = changes_of(token)
      assert change.block_number == 100
      assert change.log_index == 3
      assert Decimal.equal?(change.old_multiplier, Decimal.new(@one))
      assert Decimal.equal?(change.new_multiplier, Decimal.new(@two))
      assert change.effective_at == ~U[2026-01-01 00:00:00.000000Z]

      assert %{type: "ERC-8056"} = Repo.reload(token)

      assert MigrationStatus.get_status(BackfillScaledUIAmountTokens.migration_name()) == "completed"
    end

    test "walks every log of a token, in order" do
      token = insert(:token)
      block = insert(:block, number: 100)
      ui_multiplier_updated_log(token, block, 0, @one, @two, @effective_at_unix)
      ui_multiplier_updated_log(token, block, 1, @two, @one, @effective_at_unix)

      run_migration()

      assert [%{log_index: 0}, %{log_index: 1}] = changes_of(token)
    end

    test "records nothing for a contract that does not claim the ERC-165 interface" do
      stub_json_rpc(false)

      token = insert(:token)
      block = insert(:block, number: 100)
      ui_multiplier_updated_log(token, block, 0, @one, @two, @effective_at_unix)

      run_migration()

      assert changes_of(token) == []
      assert %{type: "ERC-20"} = Repo.reload(token)

      assert MigrationStatus.get_status(BackfillScaledUIAmountTokens.migration_name()) == "completed"
    end

    test "does not move past a log whose ERC-165 lookup failed" do
      stub(EthereumJSONRPC.Mox, :json_rpc, fn requests, _opts ->
        {:ok,
         Enum.map(requests, fn %{id: id} ->
           %{id: id, error: %{code: -32603, message: "timeout"}, jsonrpc: "2.0"}
         end)}
      end)

      token = insert(:token)
      block = insert(:block, number: 100)
      ui_multiplier_updated_log(token, block, 0, @one, @two, @effective_at_unix)

      {:ok, pid} = BackfillScaledUIAmountTokens.start_link([])
      Process.sleep(300)

      assert Process.alive?(pid)
      assert changes_of(token) == []
      refute MigrationStatus.get_status(BackfillScaledUIAmountTokens.migration_name()) == "completed"

      GenServer.stop(pid)
    end

    test "records an empty ERC-165 answer as a denial rather than a failure" do
      # some nodes answer `0x` for a function the contract does not have
      stub(EthereumJSONRPC.Mox, :json_rpc, fn requests, _opts ->
        {:ok, Enum.map(requests, fn %{id: id} -> %{id: id, result: "0x"} end)}
      end)

      token = insert(:token)
      block = insert(:block, number: 100)
      ui_multiplier_updated_log(token, block, 0, @one, @two, @effective_at_unix)

      run_migration()

      assert changes_of(token) == []
      assert %{type: "ERC-20"} = Repo.reload(token)
      assert MigrationStatus.get_status(BackfillScaledUIAmountTokens.migration_name()) == "completed"
    end

    test "leaves tokens whose logs are of other events alone" do
      token = insert(:token)
      block = insert(:block, number: 100)

      insert(:log,
        address: token.contract_address,
        block: block,
        block_number: block.number,
        index: 0,
        first_topic: ScaledUIAmount.transfer_with_ui_amount_event()
      )

      run_migration()

      assert changes_of(token) == []
      assert %{type: "ERC-20"} = Repo.reload(token)
    end
  end
end
