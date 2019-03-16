defmodule Indexer.Temporary.FailedCreatedAddressesTest do
  use Explorer.DataCase, async: false
  use EthereumJSONRPC.Case, async: false

  import Mox

  import Ecto.Query

  alias Explorer.Repo
  alias Explorer.Chain.Address
  alias Indexer.Temporary.FailedCreatedAddresses.Supervisor
  alias Indexer.CoinBalance

  @moduletag capture_log: true

  setup :set_mox_global

  setup :verify_on_exit!

  describe "run/1" do
    @tag :no_parity
    @tag :no_geth
    test "updates failed replaced transactions", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      CoinBalance.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)

      block = insert(:block)

      transaction =
        :transaction
        |> insert(
          status: 0,
          error: "Reverted",
          internal_transactions_indexed_at: DateTime.utc_now(),
          block: block,
          block_number: block.number,
          cumulative_gas_used: 200,
          gas_used: 100,
          index: 0
        )

      address = insert(:address, contract_code: "0x0102030405")

      insert(:internal_transaction,
        block_number: transaction.block_number,
        transaction: transaction,
        index: 0,
        created_contract_address_hash: address.hash
      )

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        EthereumJSONRPC.Mox
        |> expect(:json_rpc, fn _json, _options ->
          {:ok, [%{id: 0, jsonrpc: "2.0", result: "0x"}]}
        end)
        |> expect(:json_rpc, fn [%{id: id, method: "eth_getBalance", params: [_address, _block_quantity]}], _options ->
          {:ok, [%{id: id, result: "0x0"}]}
        end)
      end

      params = [json_rpc_named_arguments, [name: TestFailedCreatedAddresses]]

      params
      |> Supervisor.child_spec()
      |> ExUnit.Callbacks.start_supervised!()

      Process.sleep(3_000)

      fetched_address =
        Repo.one(
          from(a in Address,
            where: a.hash == ^address.hash
          )
        )

      assert fetched_address.contract_code == %Explorer.Chain.Data{bytes: ""}
    end
  end
end
