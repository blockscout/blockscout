defmodule Indexer.Temporary.FailedCreatedAddressesTest do
  use Explorer.DataCase, async: false
  use EthereumJSONRPC.Case, async: false

  import Mox

  alias Explorer.Repo
  alias Explorer.Chain.InternalTransaction
  alias Indexer.Temporary.FailedCreatedAddresses

  @moduletag capture_log: true

  setup :set_mox_global

  setup :verify_on_exit!

  describe "run/1" do
    test "updates failed replaced transactions", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      transaction = :transaction |> insert(status: 0, error: "Reverted") |> with_block()
      address = insert(:address)

      internal_transaction =
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
                       "init" =>
                         "0x608060405234801561001057600080fd5b5060d38061001f6000396000f3fe6080604052600436106038577c010000000000000000000000000000000000000000000000000000000060003504633ccfd60b8114604f575b3360009081526020819052604090208025434019055005b348015605a57600080fd5b5060616063565b005b33600081815260208190526040808220805490839055905190929183156108fc02918491818181858888f1935050505015801560a3573d6000803e3d6000fd5b505056fea165627a7a72305820e9a226f249def650de957dd8b4127b85a3049d6bfa818cadc4e2d3c44b6a53530029",
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

      FailedCreatedAddresses.run(json_rpc_named_arguments)
    end
  end
end
