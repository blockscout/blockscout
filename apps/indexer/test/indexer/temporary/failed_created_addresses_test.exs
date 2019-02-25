defmodule Indexer.Temporary.FailedCreatedAddressesTest do
  use Explorer.DataCase, async: false
  use EthereumJSONRPC.Case, async: false

  import Mox

  import Ecto.Query

  alias Explorer.Repo
  alias Explorer.Chain.{Address, Transaction}
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
        |> expect(:json_rpc, fn _json, _options ->
          {:ok,
           [
             %{
               id: 0,
               jsonrpc: "2.0",
               result: %{
                 "output" => "0x",
                 "stateDiff" => nil,
                 "trace" => [
                   %{
                     "action" => %{
                       "callType" => "call",
                       "from" => "0xc73add416e2119d20ce80e0904fc1877e33ef246",
                       "gas" => "0x13388",
                       "input" => "0xc793bf97",
                       "to" => "0x2d07e106b5d280e4ccc2d10deee62441c91d4340",
                       "value" => "0x0"
                     },
                     "error" => "Reverted",
                     "subtraces" => 1,
                     "traceAddress" => [],
                     "type" => "call"
                   },
                   %{
                     "action" => %{
                       "from" => "0x2d07e106b5d280e4ccc2d10deee62441c91d4340",
                       "gas" => "0xb2ab",
                       "init" => "0x4bb278f3",
                       "value" => "0x0"
                     },
                     "result" => %{
                       "address" => "0xf4a5afe28b91cf928c2568805cfbb36d477f0b75",
                       "code" =>
                         "0x6080604052600436106038577c010000000000000000000000000000000000000000000000000000000060003504633ccfd60b8114604f575b336000908152602081905260409020805434019055005b348015605a57600080fd5b5060616063565b005b33600081815260208190526040808220805490839055905190929183156108fc02918491818181858888f1935050505015801560a3573d6000803e3d6000fd5b505056fea165627a7a72305820e9a226f249def650de957dd8b4127b85a3049d6bfa818cadc4e2d3c44b6a53530029",
                       "gasUsed" => "0xa535"
                     },
                     "subtraces" => 0,
                     "traceAddress" => [0],
                     "type" => "create"
                   }
                 ],
                 "vmTrace" => nil
               }
             }
           ]}
        end)
      end

      params = [json_rpc_named_arguments, [name: TestFailedCreatedAddresses]]

      params
      |> Supervisor.child_spec()
      |> ExUnit.Callbacks.start_supervised!()

      Process.sleep(3_000)

      query =
        from(t in Transaction,
          where: t.hash == ^transaction.hash,
          preload: [internal_transactions: :created_contract_address]
        )

      fetched_transaction = Repo.one(query)

      assert Enum.count(fetched_transaction.internal_transactions) == 2

      assert Enum.all?(fetched_transaction.internal_transactions, fn it ->
               it.error && is_nil(it.created_contract_address_hash)
             end)

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
