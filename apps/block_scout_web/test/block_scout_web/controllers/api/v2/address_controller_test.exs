defmodule BlockScoutWeb.API.V2.AddressControllerTest do
  use BlockScoutWeb.ConnCase
  use EthereumJSONRPC.Case, async: false
  use BlockScoutWeb.ChannelCase
  use Utils.CompileTimeEnvHelper, chain_identity: [:explorer, :chain_identity]

  alias ABI.{TypeDecoder, TypeEncoder}
  alias Explorer.{Chain, Repo, TestHelper}
  alias Explorer.Chain.Address.Counters

  alias Explorer.Chain.{
    Address,
    Address.CoinBalance,
    Block,
    InternalTransaction,
    Log,
    Token,
    Token.Instance,
    TokenTransfer,
    Transaction,
    Wei,
    Withdrawal
  }

  alias Explorer.Account.{Identity, WatchlistAddress}
  alias Explorer.Chain.Address.CurrentTokenBalance
  alias Explorer.Chain.Beacon.Deposit, as: BeaconDeposit
  alias Indexer.Fetcher.OnDemand.ContractCode, as: ContractCodeOnDemand
  alias Plug.Conn

  import Explorer.Chain, only: [hash_to_lower_case_string: 1]
  import Mox

  @first_topic_hex_string_1 "0x7fcf532c15f0a6db0bd6d0e038bea71d30d808c7d98cb3bf7268a95bf5081b65"
  @instances_amount_in_collection 9
  @resolved_delegate_proxy "0x608060408181523060009081526001602090815282822054908290529181207FBF40FAC1000000000000000000000000000000000000000000000000000000009093529173FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF9091169063BF40FAC19061006D9060846101E2565B602060405180830381865AFA15801561008A573D6000803E3D6000FD5B505050506040513D601F19601F820116820180604052508101906100AE91906102C5565B905073FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF8116610157576040517F08C379A000000000000000000000000000000000000000000000000000000000815260206004820152603960248201527F5265736F6C76656444656C656761746550726F78793A2074617267657420616460448201527F6472657373206D75737420626520696E697469616C697A656400000000000000606482015260840160405180910390FD5B6000808273FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF16600036604051610182929190610302565B600060405180830381855AF49150503D80600081146101BD576040519150601F19603F3D011682016040523D82523D6000602084013E6101C2565B606091505B5090925090508115156001036101DA57805160208201F35B805160208201FD5B600060208083526000845481600182811C91508083168061020457607F831692505B858310810361023A577F4E487B710000000000000000000000000000000000000000000000000000000085526022600452602485FD5B878601838152602001818015610257576001811461028B576102B6565B7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF008616825284151560051B820196506102B6565B60008B81526020902060005B868110156102B057815484820152908501908901610297565B83019750505B50949998505050505050505050565B6000602082840312156102D757600080FD5B815173FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF811681146102FB57600080FD5B9392505050565B818382376000910190815291905056FEA164736F6C634300080F000A"

  setup :set_mox_global

  setup :verify_on_exit!

  setup %{json_rpc_named_arguments: json_rpc_named_arguments} do
    mocked_json_rpc_named_arguments = Keyword.put(json_rpc_named_arguments, :transport, EthereumJSONRPC.Mox)

    start_supervised!({Task.Supervisor, name: Indexer.TaskSupervisor})

    start_supervised!({ContractCodeOnDemand, [mocked_json_rpc_named_arguments, [name: ContractCodeOnDemand]]})

    %{json_rpc_named_arguments: mocked_json_rpc_named_arguments}

    :ok
  end

  describe "/addresses/{address_hash}" do
    test "get 200 on non existing address", %{conn: conn} do
      address = build(:address)

      correct_response = %{
        "hash" => Address.checksum(address.hash),
        "is_contract" => false,
        "is_verified" => false,
        "name" => nil,
        "private_tags" => [],
        "public_tags" => [],
        "watchlist_names" => [],
        "creator_address_hash" => nil,
        "creation_transaction_hash" => nil,
        "token" => nil,
        "coin_balance" => nil,
        "proxy_type" => nil,
        "implementations" => [],
        "block_number_balance_updated_at" => nil,
        "has_validated_blocks" => false,
        "has_logs" => false,
        "has_tokens" => false,
        "has_token_transfers" => false,
        "watchlist_address_id" => nil,
        "has_beacon_chain_withdrawals" => false,
        "ens_domain_name" => nil,
        "metadata" => nil,
        "creation_status" => nil
      }

      stub(EthereumJSONRPC.Mox, :json_rpc, fn _, _ ->
        {:ok, []}
      end)

      request = get(conn, "/api/v2/addresses/#{Address.checksum(address.hash)}")
      json_response = json_response(request, 200)
      check_response(correct_response, json_response)
    end

    test "get 422 on invalid address", %{conn: conn} do
      request = get(conn, "/api/v2/addresses/0x")

      json_response = json_response(request, 422)

      assert %{
               "errors" => [
                 %{
                   "detail" => "Invalid format. Expected ~r/^0x([A-Fa-f0-9]{40})$/",
                   "source" => %{"pointer" => "/address_hash_param"},
                   "title" => "Invalid value"
                 }
               ]
             } = json_response
    end

    test "get address & get the same response for checksummed and downcased parameter", %{conn: conn} do
      address = insert(:address)

      correct_response = %{
        "hash" => Address.checksum(address.hash),
        "is_contract" => false,
        "is_verified" => false,
        "name" => nil,
        "private_tags" => [],
        "public_tags" => [],
        "watchlist_names" => [],
        "creator_address_hash" => nil,
        "creation_transaction_hash" => nil,
        "token" => nil,
        "coin_balance" => nil,
        "proxy_type" => nil,
        "implementations" => [],
        "block_number_balance_updated_at" => nil,
        "has_validated_blocks" => false,
        "has_logs" => false,
        "has_tokens" => false,
        "has_token_transfers" => false,
        "watchlist_address_id" => nil,
        "has_beacon_chain_withdrawals" => false,
        "ens_domain_name" => nil,
        "metadata" => nil,
        "creation_status" => nil
      }

      stub(EthereumJSONRPC.Mox, :json_rpc, fn _, _ ->
        {:ok, []}
      end)

      request = get(conn, "/api/v2/addresses/#{Address.checksum(address.hash)}")
      json_response = json_response(request, 200)
      check_response(correct_response, json_response)

      request = get(conn, "/api/v2/addresses/#{String.downcase(to_string(address.hash))}")
      json_response = json_response(request, 200)
      check_response(correct_response, json_response)
    end

    test "returns successful creation transaction for a contract when both failed and successful transactions exist",
         %{conn: conn} do
      contract_address = insert(:address, contract_code: "0x")

      failed_transaction =
        insert(:transaction,
          created_contract_address_hash: contract_address.hash
        )
        |> with_block(status: :error)

      succeeded_transaction =
        insert(:transaction,
          created_contract_address_hash: contract_address.hash
        )
        |> with_block(status: :ok)

      assert failed_transaction.block_number < succeeded_transaction.block_number

      stub(EthereumJSONRPC.Mox, :json_rpc, fn _, _ ->
        {:ok, []}
      end)

      request = get(conn, "/api/v2/addresses/#{Address.checksum(contract_address.hash)}")
      response = json_response(request, 200)
      assert response["is_contract"]
      assert response["creation_transaction_hash"] == to_string(succeeded_transaction.hash)
      assert response["creation_status"] == "success"
    end

    test "returns failed creation transaction for a contract",
         %{conn: conn} do
      contract_address = insert(:address, contract_code: "0x")

      failed_transaction =
        insert(:transaction,
          created_contract_address_hash: contract_address.hash
        )
        |> with_block(status: :error)

      stub(EthereumJSONRPC.Mox, :json_rpc, fn _, _ ->
        {:ok, []}
      end)

      request = get(conn, "/api/v2/addresses/#{Address.checksum(contract_address.hash)}")
      response = json_response(request, 200)
      assert response["is_contract"]
      assert response["creation_transaction_hash"] == to_string(failed_transaction.hash)
      assert response["creation_status"] == "failed"
    end

    defp check_response(pattern_response, response) do
      assert pattern_response["hash"] == response["hash"]
      assert pattern_response["is_contract"] == response["is_contract"]
      assert pattern_response["is_verified"] == response["is_verified"]
      assert pattern_response["name"] == response["name"]
      assert pattern_response["private_tags"] == response["private_tags"]
      assert pattern_response["public_tags"] == response["public_tags"]
      assert pattern_response["watchlist_names"] == response["watchlist_names"]
      assert pattern_response["creator_address_hash"] == response["creator_address_hash"]
      assert pattern_response["creation_transaction_hash"] == response["creation_transaction_hash"]
      assert pattern_response["token"] == response["token"]
      assert pattern_response["coin_balance"] == response["coin_balance"]
      assert pattern_response["implementation_address"] == response["implementation_address"]
      assert pattern_response["implementation_name"] == response["implementation_name"]
      assert pattern_response["implementations"] == response["implementations"]
      assert pattern_response["block_number_balance_updated_at"] == response["block_number_balance_updated_at"]
      assert pattern_response["has_validated_blocks"] == response["has_validated_blocks"]
      assert pattern_response["has_logs"] == response["has_logs"]
      assert pattern_response["has_tokens"] == response["has_tokens"]
      assert pattern_response["has_token_transfers"] == response["has_token_transfers"]
      assert pattern_response["watchlist_address_id"] == response["watchlist_address_id"]
      assert pattern_response["has_beacon_chain_withdrawals"] == response["has_beacon_chain_withdrawals"]
      assert pattern_response["ens_domain_name"] == response["ens_domain_name"]
      assert pattern_response["metadata"] == response["metadata"]
      assert pattern_response["creation_status"] == response["creation_status"]
    end

    test "get EIP-1167 proxy contract info", %{conn: conn} do
      implementation_contract =
        insert(:smart_contract,
          name: "Implementation",
          external_libraries: [],
          constructor_arguments: "",
          abi: [
            %{
              "type" => "constructor",
              "inputs" => [
                %{"type" => "address", "name" => "_proxyStorage"},
                %{"type" => "address", "name" => "_implementationAddress"}
              ]
            },
            %{
              "constant" => false,
              "inputs" => [%{"name" => "x", "type" => "uint256"}],
              "name" => "set",
              "outputs" => [],
              "payable" => false,
              "stateMutability" => "nonpayable",
              "type" => "function"
            },
            %{
              "constant" => true,
              "inputs" => [],
              "name" => "get",
              "outputs" => [%{"name" => "", "type" => "uint256"}],
              "payable" => false,
              "stateMutability" => "view",
              "type" => "function"
            }
          ],
          license_type: 9
        )

      implementation_contract_address_hash_string =
        Base.encode16(implementation_contract.address_hash.bytes, case: :lower)

      proxy_transaction_input =
        "0x11b804ab000000000000000000000000" <>
          implementation_contract_address_hash_string <>
          "000000000000000000000000000000000000000000000000000000000000006035323031313537360000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000284e159163400000000000000000000000034420c13696f4ac650b9fafe915553a1abcd7dd30000000000000000000000000000000000000000000000000000000000000140000000000000000000000000000000000000000000000000000000000000018000000000000000000000000000000000000000000000000000000000000001c00000000000000000000000000000000000000000000000000000000000000220000000000000000000000000ff5ae9b0a7522736299d797d80b8fc6f31d61100000000000000000000000000ff5ae9b0a7522736299d797d80b8fc6f31d6110000000000000000000000000000000000000000000000000000000000000003e8000000000000000000000000000000000000000000000000000000000000000000000000000000000000000034420c13696f4ac650b9fafe915553a1abcd7dd300000000000000000000000000000000000000000000000000000000000000184f7074696d69736d2053756273637269626572204e465473000000000000000000000000000000000000000000000000000000000000000000000000000000054f504e46540000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000037697066733a2f2f516d66544e504839765651334b5952346d6b52325a6b757756424266456f5a5554545064395538666931503332752f300000000000000000000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000c82bbe41f2cf04e3a8efa18f7032bdd7f6d98a81000000000000000000000000efba8a2a82ec1fb1273806174f5e28fbb917cf9500000000000000000000000000000000000000000000000000000000"

      proxy_deployed_bytecode =
        "0x363d3d373d3d3d363d73" <> implementation_contract_address_hash_string <> "5af43d82803e903d91602b57fd5bf3"

      proxy_address =
        insert(:contract_address,
          contract_code: proxy_deployed_bytecode
        )

      transaction =
        insert(:transaction,
          created_contract_address_hash: proxy_address.hash,
          input: proxy_transaction_input
        )
        |> with_block(status: :ok)

      name = implementation_contract.name
      from = Address.checksum(transaction.from_address_hash)
      transaction_hash = to_string(transaction.hash)
      address_hash = Address.checksum(proxy_address.hash)

      {:ok, implementation_contract_address_hash} =
        Chain.string_to_address_hash("0x" <> implementation_contract_address_hash_string)

      checksummed_implementation_contract_address_hash =
        implementation_contract_address_hash && Address.checksum(implementation_contract_address_hash)

      insert(:proxy_implementation,
        proxy_address_hash: proxy_address.hash,
        proxy_type: "eip1167",
        address_hashes: [implementation_contract.address_hash],
        names: [name]
      )

      request = get(conn, "/api/v2/addresses/#{Address.checksum(proxy_address.hash)}")

      json_response = json_response(request, 200)

      assert %{
               "hash" => ^address_hash,
               "is_contract" => true,
               "is_verified" => true,
               "private_tags" => [],
               "public_tags" => [],
               "watchlist_names" => [],
               "creator_address_hash" => ^from,
               "creation_transaction_hash" => ^transaction_hash,
               "creation_status" => "success",
               "proxy_type" => "eip1167",
               "implementations" => [
                 %{
                   "address_hash" => ^checksummed_implementation_contract_address_hash,
                   "name" => ^name
                 }
               ]
             } = json_response
    end

    test "get EIP-1967 proxy contract info", %{conn: conn} do
      smart_contract = insert(:smart_contract)

      transaction =
        insert(:transaction,
          to_address_hash: nil,
          to_address: nil,
          created_contract_address_hash: smart_contract.address_hash,
          created_contract_address: smart_contract.address
        )

      insert(:address_name,
        address: smart_contract.address,
        primary: true,
        name: smart_contract.name,
        address_hash: smart_contract.address_hash
      )

      name = smart_contract.name
      from = Address.checksum(transaction.from_address_hash)
      transaction_hash = to_string(transaction.hash)
      address_hash = Address.checksum(smart_contract.address_hash)

      implementation_address = insert(:address)
      implementation_address_hash_string = to_string(Address.checksum(implementation_address.hash))

      EthereumJSONRPC.Mox
      |> TestHelper.mock_generic_proxy_requests(eip1967: implementation_address.hash)

      request = get(conn, "/api/v2/addresses/#{Address.checksum(smart_contract.address_hash)}")

      json_response = json_response(request, 200)

      assert %{
               "hash" => ^address_hash,
               "is_contract" => true,
               "is_verified" => true,
               "name" => ^name,
               "private_tags" => [],
               "public_tags" => [],
               "watchlist_names" => [],
               "creator_address_hash" => ^from,
               "creation_transaction_hash" => ^transaction_hash,
               "creation_status" => "success",
               "proxy_type" => "eip1967",
               "implementations" => [
                 %{
                   "address_hash" => ^implementation_address_hash_string,
                   "name" => nil
                 }
               ]
             } = json_response
    end

    test "get Resolved Delegate Proxy contract info", %{conn: conn} do
      proxy_address = insert(:address, contract_code: @resolved_delegate_proxy)
      proxy_smart_contract = insert(:smart_contract, address_hash: proxy_address.hash)

      transaction =
        insert(:transaction,
          to_address_hash: nil,
          to_address: nil,
          created_contract_address_hash: proxy_smart_contract.address_hash,
          created_contract_address: proxy_smart_contract.address
        )

      insert(:address_name,
        address: proxy_smart_contract.address,
        primary: true,
        name: proxy_smart_contract.name,
        address_hash: proxy_smart_contract.address_hash
      )

      name = proxy_smart_contract.name
      from = Address.checksum(transaction.from_address_hash)
      transaction_hash = to_string(transaction.hash)
      checksummed_proxy_address_hash = Address.checksum(proxy_smart_contract.address_hash)

      implementation_address = insert(:address)
      implementation_address_hash_string = implementation_address.hash |> Address.checksum() |> to_string()

      EthereumJSONRPC.Mox
      |> TestHelper.mock_resolved_delegate_proxy_requests(
        proxy_smart_contract.address_hash,
        implementation_address.hash
      )

      request = get(conn, "/api/v2/addresses/#{checksummed_proxy_address_hash}")
      json_response = json_response(request, 200)

      assert %{
               "hash" => ^checksummed_proxy_address_hash,
               "is_contract" => true,
               "is_verified" => true,
               "name" => ^name,
               "private_tags" => [],
               "public_tags" => [],
               "watchlist_names" => [],
               "creator_address_hash" => ^from,
               "creation_transaction_hash" => ^transaction_hash,
               "creation_status" => "success",
               "proxy_type" => "resolved_delegate_proxy",
               "implementations" => [
                 %{
                   "address_hash" => ^implementation_address_hash_string,
                   "name" => nil
                 }
               ]
             } = json_response
    end

    test "get watchlist id", %{conn: conn} do
      auth = build(:auth)
      address = insert(:address)
      {:ok, user} = Identity.find_or_create(auth)

      conn = Plug.Test.init_test_session(conn, current_user: user)

      watchlist_address =
        Repo.account_repo().insert!(%WatchlistAddress{
          name: "wallet",
          watchlist_id: user.watchlist_id,
          address_hash: address.hash,
          address_hash_hash: hash_to_lower_case_string(address.hash),
          watch_coin_input: true,
          watch_coin_output: true,
          watch_erc_20_input: true,
          watch_erc_20_output: true,
          watch_erc_721_input: true,
          watch_erc_721_output: true,
          watch_erc_1155_input: true,
          watch_erc_1155_output: true,
          notify_email: true
        })

      stub(EthereumJSONRPC.Mox, :json_rpc, fn _, _ ->
        {:ok, []}
      end)

      request = get(conn, "/api/v2/addresses/#{Address.checksum(address.hash)}")
      assert response = json_response(request, 200)

      assert response["watchlist_address_id"] == watchlist_address.id
    end

    test "broadcasts fetched_bytecode event", %{conn: conn} do
      address = insert(:address)
      address_hash = address.hash
      string_address_hash = to_string(address.hash)

      contract_code = "0x6080"

      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn [
                                %{
                                  id: id,
                                  jsonrpc: "2.0",
                                  method: "eth_getCode",
                                  params: [^string_address_hash, "latest"]
                                }
                              ],
                              _ ->
        {:ok, [%{id: id, result: contract_code}]}
      end)

      topic = "addresses:#{address_hash}"

      {:ok, _reply, _socket} =
        BlockScoutWeb.V2.UserSocket
        |> socket("no_id", %{})
        |> subscribe_and_join(topic)

      request = get(conn, "/api/v2/addresses/#{address.hash}")
      assert _response = json_response(request, 200)

      assert_receive %Phoenix.Socket.Message{
                       payload: %{fetched_bytecode: ^contract_code},
                       event: "fetched_bytecode",
                       topic: ^topic
                     },
                     :timer.seconds(1)
    end
  end

  describe "/addresses/{address_hash}/counters" do
    test "get 200 on non existing address", %{conn: conn} do
      address = build(:address)

      request = get(conn, "/api/v2/addresses/#{address.hash}/counters")

      json_response = json_response(request, 200)

      assert %{
               "transactions_count" => "0",
               "token_transfers_count" => "0",
               "gas_usage_count" => "0",
               "validations_count" => "0"
             } = json_response
    end

    test "get 422 on invalid address", %{conn: conn} do
      request = get(conn, "/api/v2/addresses/0x/counters")

      json_response = json_response(request, 422)

      assert %{
               "errors" => [
                 %{
                   "detail" => "Invalid format. Expected ~r/^0x([A-Fa-f0-9]{40})$/",
                   "source" => %{"pointer" => "/address_hash_param"},
                   "title" => "Invalid value"
                 }
               ]
             } = json_response
    end

    test "get counters with 0s", %{conn: conn} do
      address = insert(:address)

      request = get(conn, "/api/v2/addresses/#{address.hash}/counters")

      json_response = json_response(request, 200)

      assert %{
               "transactions_count" => "0",
               "token_transfers_count" => "0",
               "gas_usage_count" => "0",
               "validations_count" => "0"
             } = json_response
    end

    test "get counters", %{conn: conn} do
      address = insert(:address)

      transaction_from = insert(:transaction, from_address: address) |> with_block()
      insert(:transaction, to_address: address) |> with_block()
      another_transaction = insert(:transaction) |> with_block()

      insert(:token_transfer,
        from_address: address,
        transaction: another_transaction,
        block: another_transaction.block,
        block_number: another_transaction.block_number
      )

      insert(:token_transfer,
        to_address: address,
        transaction: another_transaction,
        block: another_transaction.block,
        block_number: another_transaction.block_number
      )

      insert(:block, miner: address)

      Counters.transactions_count(address)
      Counters.token_transfers_count(address)
      Counters.gas_usage_count(address)

      request = get(conn, "/api/v2/addresses/#{address.hash}/counters")
      json_response = json_response(request, 200)
      gas_used = to_string(transaction_from.gas_used)

      assert %{
               "transactions_count" => "2",
               "token_transfers_count" => "2",
               "gas_usage_count" => ^gas_used,
               "validations_count" => "1"
             } = json_response
    end
  end

  describe "/addresses/{address_hash}/transactions" do
    test "get empty list on non existing address", %{conn: conn} do
      address = build(:address)

      request = get(conn, "/api/v2/addresses/#{address.hash}/transactions")
      json_response = json_response(request, 200)

      assert %{"items" => [], "next_page_params" => nil} = json_response
    end

    test "get 422 on invalid address", %{conn: conn} do
      request = get(conn, "/api/v2/addresses/0x/transactions")

      json_response = json_response(request, 422)

      assert %{
               "errors" => [
                 %{
                   "detail" => "Invalid format. Expected ~r/^0x([A-Fa-f0-9]{40})$/",
                   "source" => %{"pointer" => "/address_hash_param"},
                   "title" => "Invalid value"
                 }
               ]
             } = json_response
    end

    test "get relevant transaction", %{conn: conn} do
      address = insert(:address)

      transaction = insert(:transaction, from_address: address) |> with_block()

      insert(:transaction) |> with_block()

      request = get(conn, "/api/v2/addresses/#{address.hash}/transactions")

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 1
      assert response["next_page_params"] == nil

      compare_item(transaction, Enum.at(response["items"], 0))
    end

    test "get pending transaction", %{conn: conn} do
      address = insert(:address)

      transaction = insert(:transaction, from_address: address) |> with_block()
      pending_transaction = insert(:transaction, from_address: address)

      insert(:transaction) |> with_block()
      insert(:transaction)

      request = get(conn, "/api/v2/addresses/#{address.hash}/transactions")

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 2
      assert response["next_page_params"] == nil

      compare_item(pending_transaction, Enum.at(response["items"], 0))
      compare_item(transaction, Enum.at(response["items"], 1))
    end

    test "get only :to transaction", %{conn: conn} do
      address = insert(:address)

      insert(:transaction, from_address: address) |> with_block()
      transaction = insert(:transaction, to_address: address) |> with_block()

      request = get(conn, "/api/v2/addresses/#{address.hash}/transactions", %{"filter" => "to"})

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 1
      assert response["next_page_params"] == nil

      compare_item(transaction, Enum.at(response["items"], 0))
    end

    test "get only :from transactions", %{conn: conn} do
      address = insert(:address)

      transaction = insert(:transaction, from_address: address) |> with_block()
      insert(:transaction, to_address: address) |> with_block()

      request = get(conn, "/api/v2/addresses/#{address.hash}/transactions", %{"filter" => "from"})

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 1
      assert response["next_page_params"] == nil

      compare_item(transaction, Enum.at(response["items"], 0))
    end

    test "validated transactions can paginate", %{conn: conn} do
      address = insert(:address)

      transactions = insert_list(51, :transaction, from_address: address) |> with_block()

      request = get(conn, "/api/v2/addresses/#{address.hash}/transactions")
      assert response = json_response(request, 200)

      request_2nd_page = get(conn, "/api/v2/addresses/#{address.hash}/transactions", response["next_page_params"])
      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, transactions)
    end

    test "pending transactions can paginate", %{conn: conn} do
      address = insert(:address)

      transactions = insert_list(51, :transaction, from_address: address)

      request = get(conn, "/api/v2/addresses/#{address.hash}/transactions")
      assert response = json_response(request, 200)

      request_2nd_page = get(conn, "/api/v2/addresses/#{address.hash}/transactions", response["next_page_params"])
      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, transactions)
    end

    test "pending + validated transactions can paginate", %{conn: conn} do
      address = insert(:address)

      transactions_pending = insert_list(51, :transaction, from_address: address)
      transactions_validated = insert_list(50, :transaction, to_address: address) |> with_block()

      request = get(conn, "/api/v2/addresses/#{address.hash}/transactions")
      assert response = json_response(request, 200)

      request_2nd_page = get(conn, "/api/v2/addresses/#{address.hash}/transactions", response["next_page_params"])
      assert response_2nd_page = json_response(request_2nd_page, 200)

      assert Enum.count(response["items"]) == 50
      assert response["next_page_params"] != nil
      compare_item(Enum.at(transactions_pending, 50), Enum.at(response["items"], 0))
      compare_item(Enum.at(transactions_pending, 1), Enum.at(response["items"], 49))

      assert Enum.count(response_2nd_page["items"]) == 50
      assert response_2nd_page["next_page_params"] != nil
      compare_item(Enum.at(transactions_pending, 0), Enum.at(response_2nd_page["items"], 0))
      compare_item(Enum.at(transactions_validated, 49), Enum.at(response_2nd_page["items"], 1))
      compare_item(Enum.at(transactions_validated, 1), Enum.at(response_2nd_page["items"], 49))

      request = get(conn, "/api/v2/addresses/#{address.hash}/transactions", response_2nd_page["next_page_params"])
      assert response = json_response(request, 200)

      check_paginated_response(
        response_2nd_page,
        response,
        transactions_validated ++ [Enum.at(transactions_pending, 0)]
      )
    end

    test ":to transactions can paginate", %{conn: conn} do
      address = insert(:address)

      transactions = insert_list(51, :transaction, to_address: address) |> with_block()
      insert_list(51, :transaction, from_address: address) |> with_block()

      filter = %{"filter" => "to"}
      request = get(conn, "/api/v2/addresses/#{address.hash}/transactions", filter)
      assert response = json_response(request, 200)

      request_2nd_page =
        get(conn, "/api/v2/addresses/#{address.hash}/transactions", Map.merge(response["next_page_params"], filter))

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, transactions)
    end

    test ":from transactions can paginate", %{conn: conn} do
      address = insert(:address)

      insert_list(51, :transaction, to_address: address) |> with_block()
      transactions = insert_list(51, :transaction, from_address: address) |> with_block()

      filter = %{"filter" => "from"}
      request = get(conn, "/api/v2/addresses/#{address.hash}/transactions", filter)
      assert response = json_response(request, 200)

      request_2nd_page =
        get(conn, "/api/v2/addresses/#{address.hash}/transactions", Map.merge(response["next_page_params"], filter))

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, transactions)
    end

    test ":from + :to transactions can paginate", %{conn: conn} do
      address = insert(:address)

      transactions_from = insert_list(50, :transaction, from_address: address) |> with_block()
      transactions_to = insert_list(51, :transaction, to_address: address) |> with_block()

      request = get(conn, "/api/v2/addresses/#{address.hash}/transactions")
      assert response = json_response(request, 200)

      request_2nd_page = get(conn, "/api/v2/addresses/#{address.hash}/transactions", response["next_page_params"])
      assert response_2nd_page = json_response(request_2nd_page, 200)

      assert Enum.count(response["items"]) == 50
      assert response["next_page_params"] != nil
      compare_item(Enum.at(transactions_to, 50), Enum.at(response["items"], 0))
      compare_item(Enum.at(transactions_to, 1), Enum.at(response["items"], 49))

      assert Enum.count(response_2nd_page["items"]) == 50
      assert response_2nd_page["next_page_params"] != nil
      compare_item(Enum.at(transactions_to, 0), Enum.at(response_2nd_page["items"], 0))
      compare_item(Enum.at(transactions_from, 49), Enum.at(response_2nd_page["items"], 1))
      compare_item(Enum.at(transactions_from, 1), Enum.at(response_2nd_page["items"], 49))

      request_3rd_page =
        get(conn, "/api/v2/addresses/#{address.hash}/transactions", response_2nd_page["next_page_params"])

      assert response_3rd_page = json_response(request_3rd_page, 200)

      check_paginated_response(response_2nd_page, response_3rd_page, transactions_from ++ [Enum.at(transactions_to, 0)])
    end

    test "422 on wrong ordering params", %{conn: conn} do
      address = insert(:address)

      insert_list(51, :transaction, from_address: address) |> with_block()

      request = get(conn, "/api/v2/addresses/#{address.hash}/transactions", %{"sort" => "foo", "order" => "bar"})
      assert json_response = json_response(request, 422)

      assert %{
               "errors" => [
                 %{
                   "detail" => "Invalid value for enum",
                   "source" => %{"pointer" => "/sort"},
                   "title" => "Invalid value"
                 },
                 %{
                   "detail" => "Invalid value for enum",
                   "source" => %{"pointer" => "/order"},
                   "title" => "Invalid value"
                 }
               ]
             } = json_response
    end

    test "backward compatible with legacy paging params", %{conn: conn} do
      address = insert(:address)
      block = insert(:block)

      transactions = insert_list(51, :transaction, from_address: address) |> with_block(block)

      [_, transaction_before_last | _] = transactions

      request = get(conn, "/api/v2/addresses/#{address.hash}/transactions")
      assert response = json_response(request, 200)

      request_2nd_page =
        get(
          conn,
          "/api/v2/addresses/#{address.hash}/transactions",
          %{"block_number" => to_string(block.number), "index" => to_string(transaction_before_last.index)}
        )

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, transactions)
    end

    test "backward compatible with legacy paging params for pending transactions", %{conn: conn} do
      address = insert(:address)

      transactions = insert_list(51, :transaction, from_address: address)

      [_, transaction_before_last | _] = transactions

      request = get(conn, "/api/v2/addresses/#{address.hash}/transactions")
      assert response = json_response(request, 200)

      request_2nd_page_pending =
        get(
          conn,
          "/api/v2/addresses/#{address.hash}/transactions",
          %{
            "inserted_at" => to_string(transaction_before_last.inserted_at),
            "hash" => to_string(transaction_before_last.hash)
          }
        )

      assert response_2nd_page_pending = json_response(request_2nd_page_pending, 200)

      check_paginated_response(response, response_2nd_page_pending, transactions)
    end

    test "can order and paginate by fee ascending", %{conn: conn} do
      address = insert(:address)

      transactions_from = insert_list(25, :transaction, from_address: address) |> with_block()
      transactions_to = insert_list(26, :transaction, to_address: address) |> with_block()

      transactions =
        (transactions_from ++ transactions_to)
        |> Enum.sort(
          &(Decimal.compare(&1 |> Transaction.fee(:wei) |> elem(1), &2 |> Transaction.fee(:wei) |> elem(1)) in [
              :eq,
              :lt
            ])
        )

      request = get(conn, "/api/v2/addresses/#{address.hash}/transactions", %{"sort" => "fee", "order" => "asc"})
      assert response = json_response(request, 200)

      request_2nd_page =
        get(
          conn,
          "/api/v2/addresses/#{address.hash}/transactions",
          %{"sort" => "fee", "order" => "asc"} |> Map.merge(response["next_page_params"])
        )

      assert response_2nd_page = json_response(request_2nd_page, 200)

      assert Enum.count(response["items"]) == 50
      assert response["next_page_params"] != nil
      compare_item(Enum.at(transactions, 0), Enum.at(response["items"], 0))
      compare_item(Enum.at(transactions, 49), Enum.at(response["items"], 49))

      assert Enum.count(response_2nd_page["items"]) == 1
      assert response_2nd_page["next_page_params"] == nil
      compare_item(Enum.at(transactions, 50), Enum.at(response_2nd_page["items"], 0))

      check_paginated_response(response, response_2nd_page, transactions |> Enum.reverse())
    end

    test "can order and paginate by fee descending", %{conn: conn} do
      address = insert(:address)

      transactions_from = insert_list(25, :transaction, from_address: address) |> with_block()
      transactions_to = insert_list(26, :transaction, to_address: address) |> with_block()

      transactions =
        (transactions_from ++ transactions_to)
        |> Enum.sort(
          &(Decimal.compare(&1 |> Transaction.fee(:wei) |> elem(1), &2 |> Transaction.fee(:wei) |> elem(1)) in [
              :eq,
              :gt
            ])
        )

      request = get(conn, "/api/v2/addresses/#{address.hash}/transactions", %{"sort" => "fee", "order" => "desc"})
      assert response = json_response(request, 200)

      request_2nd_page =
        get(
          conn,
          "/api/v2/addresses/#{address.hash}/transactions",
          %{"sort" => "fee", "order" => "desc"} |> Map.merge(response["next_page_params"])
        )

      assert response_2nd_page = json_response(request_2nd_page, 200)

      assert Enum.count(response["items"]) == 50
      assert response["next_page_params"] != nil
      compare_item(Enum.at(transactions, 0), Enum.at(response["items"], 0))
      compare_item(Enum.at(transactions, 49), Enum.at(response["items"], 49))

      assert Enum.count(response_2nd_page["items"]) == 1
      assert response_2nd_page["next_page_params"] == nil
      compare_item(Enum.at(transactions, 50), Enum.at(response_2nd_page["items"], 0))

      check_paginated_response(response, response_2nd_page, transactions |> Enum.reverse())
    end

    test "can order and paginate by value ascending", %{conn: conn} do
      address = insert(:address)

      transactions_from = insert_list(25, :transaction, from_address: address) |> with_block()
      transactions_to = insert_list(26, :transaction, to_address: address) |> with_block()

      transactions =
        (transactions_from ++ transactions_to)
        |> Enum.sort(&(Decimal.compare(Wei.to(&1.value, :wei), Wei.to(&2.value, :wei)) in [:eq, :lt]))

      request = get(conn, "/api/v2/addresses/#{address.hash}/transactions", %{"sort" => "value", "order" => "asc"})
      assert response = json_response(request, 200)

      request_2nd_page =
        get(
          conn,
          "/api/v2/addresses/#{address.hash}/transactions",
          %{"sort" => "value", "order" => "asc"} |> Map.merge(response["next_page_params"])
        )

      assert response_2nd_page = json_response(request_2nd_page, 200)

      assert Enum.count(response["items"]) == 50
      assert response["next_page_params"] != nil
      compare_item(Enum.at(transactions, 0), Enum.at(response["items"], 0))
      compare_item(Enum.at(transactions, 49), Enum.at(response["items"], 49))

      assert Enum.count(response_2nd_page["items"]) == 1
      assert response_2nd_page["next_page_params"] == nil
      compare_item(Enum.at(transactions, 50), Enum.at(response_2nd_page["items"], 0))

      check_paginated_response(response, response_2nd_page, transactions |> Enum.reverse())
    end

    test "can order and paginate by value descending", %{conn: conn} do
      address = insert(:address)

      transactions_from = insert_list(25, :transaction, from_address: address) |> with_block()
      transactions_to = insert_list(26, :transaction, to_address: address) |> with_block()

      transactions =
        (transactions_from ++ transactions_to)
        |> Enum.sort(&(Decimal.compare(Wei.to(&1.value, :wei), Wei.to(&2.value, :wei)) in [:eq, :gt]))

      request = get(conn, "/api/v2/addresses/#{address.hash}/transactions", %{"sort" => "value", "order" => "desc"})
      assert response = json_response(request, 200)

      request_2nd_page =
        get(
          conn,
          "/api/v2/addresses/#{address.hash}/transactions",
          %{"sort" => "value", "order" => "desc"} |> Map.merge(response["next_page_params"])
        )

      assert response_2nd_page = json_response(request_2nd_page, 200)

      assert Enum.count(response["items"]) == 50
      assert response["next_page_params"] != nil
      compare_item(Enum.at(transactions, 0), Enum.at(response["items"], 0))
      compare_item(Enum.at(transactions, 49), Enum.at(response["items"], 49))

      assert Enum.count(response_2nd_page["items"]) == 1
      assert response_2nd_page["next_page_params"] == nil
      compare_item(Enum.at(transactions, 50), Enum.at(response_2nd_page["items"], 0))

      check_paginated_response(response, response_2nd_page, transactions |> Enum.reverse())
    end

    test "can order and paginate by block number ascending", %{conn: conn} do
      address = insert(:address)

      transactions_from =
        for _ <- 0..24, do: insert(:transaction, from_address: address) |> with_block()

      transactions_to = for _ <- 0..25, do: insert(:transaction, to_address: address) |> with_block()

      transactions =
        (transactions_from ++ transactions_to)
        |> Enum.sort_by(& &1.block.number)

      request =
        get(conn, "/api/v2/addresses/#{address.hash}/transactions", %{"sort" => "block_number", "order" => "asc"})

      assert response = json_response(request, 200)

      request_2nd_page =
        get(
          conn,
          "/api/v2/addresses/#{address.hash}/transactions",
          %{"sort" => "block_number", "order" => "asc"} |> Map.merge(response["next_page_params"])
        )

      assert response_2nd_page = json_response(request_2nd_page, 200)

      assert Enum.count(response["items"]) == 50
      assert response["next_page_params"] != nil
      compare_item(Enum.at(transactions, 0), Enum.at(response["items"], 0))
      compare_item(Enum.at(transactions, 49), Enum.at(response["items"], 49))

      assert Enum.count(response_2nd_page["items"]) == 1
      assert response_2nd_page["next_page_params"] == nil
      compare_item(Enum.at(transactions, 50), Enum.at(response_2nd_page["items"], 0))

      check_paginated_response(response, response_2nd_page, transactions |> Enum.reverse())
    end

    test "can order and paginate by block number descending", %{conn: conn} do
      address = insert(:address)

      transactions_from =
        for _ <- 0..24, do: insert(:transaction, from_address: address) |> with_block()

      transactions_to = for _ <- 0..25, do: insert(:transaction, to_address: address) |> with_block()

      transactions =
        (transactions_from ++ transactions_to)
        |> Enum.sort_by(& &1.block.number, :desc)

      request =
        get(conn, "/api/v2/addresses/#{address.hash}/transactions", %{"sort" => "block_number", "order" => "desc"})

      assert response = json_response(request, 200)

      request_2nd_page =
        get(
          conn,
          "/api/v2/addresses/#{address.hash}/transactions",
          %{"sort" => "block_number", "order" => "desc"} |> Map.merge(response["next_page_params"])
        )

      assert response_2nd_page = json_response(request_2nd_page, 200)

      assert Enum.count(response["items"]) == 50
      assert response["next_page_params"] != nil
      compare_item(Enum.at(transactions, 0), Enum.at(response["items"], 0))
      compare_item(Enum.at(transactions, 49), Enum.at(response["items"], 49))

      assert Enum.count(response_2nd_page["items"]) == 1
      assert response_2nd_page["next_page_params"] == nil
      compare_item(Enum.at(transactions, 50), Enum.at(response_2nd_page["items"], 0))

      check_paginated_response(response, response_2nd_page, transactions |> Enum.reverse())
    end

    test "regression test for decoding issue", %{conn: conn} do
      from_address = insert(:address)
      to_address = build(:address)

      insert(:transaction, from_address: from_address, to_address_hash: to_address.hash, to_address: to_address)

      Explorer.Repo.delete(to_address)

      bypass = Bypass.open()

      Application.put_env(:tesla, :adapter, Tesla.Adapter.Mint)

      old_chain_id = Application.get_env(:block_scout_web, :chain_id)
      chain_id = 1
      Application.put_env(:block_scout_web, :chain_id, chain_id)

      old_env_bens = Application.get_env(:explorer, Explorer.MicroserviceInterfaces.BENS)

      Application.put_env(:explorer, Explorer.MicroserviceInterfaces.BENS,
        service_url: "http://localhost:#{bypass.port}",
        enabled: true
      )

      old_env_metadata = Application.get_env(:explorer, Explorer.MicroserviceInterfaces.Metadata)

      Application.put_env(:explorer, Explorer.MicroserviceInterfaces.Metadata,
        service_url: "http://localhost:#{bypass.port}",
        enabled: true
      )

      Bypass.expect_once(bypass, "POST", "api/v1/#{chain_id}/addresses:batch_resolve_names", fn conn ->
        Conn.resp(
          conn,
          200,
          Jason.encode!(%{
            "names" => %{
              to_string(to_address) => "test.eth"
            }
          })
        )
      end)

      Bypass.expect_once(bypass, "GET", "api/v1/metadata", fn conn ->
        Conn.resp(
          conn,
          200,
          Jason.encode!(%{
            "addresses" => %{
              to_string(to_address) => %{
                "tags" => [
                  %{
                    "name" => "Proposer Fee Recipient",
                    "ordinal" => 0,
                    "slug" => "proposer-fee-recipient",
                    "tagType" => "generic",
                    "meta" => "{\"styles\":\"danger_high\"}"
                  }
                ]
              }
            }
          })
        )
      end)

      request = get(conn, "/api/v2/addresses/#{from_address.hash}/transactions")

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 1
      assert response["next_page_params"] == nil

      transaction = Enum.at(response["items"], 0)
      assert transaction["to"]["ens_domain_name"] == "test.eth"

      assert transaction["to"]["metadata"] == %{
               "tags" => [
                 %{
                   "slug" => "proposer-fee-recipient",
                   "name" => "Proposer Fee Recipient",
                   "ordinal" => 0,
                   "tagType" => "generic",
                   "meta" => %{"styles" => "danger_high"}
                 }
               ]
             }

      Application.put_env(:block_scout_web, :chain_id, old_chain_id)
      Application.put_env(:explorer, Explorer.MicroserviceInterfaces.BENS, old_env_bens)
      Application.put_env(:explorer, Explorer.MicroserviceInterfaces.Metadata, old_env_metadata)
      Application.put_env(:tesla, :adapter, Explorer.Mock.TeslaAdapter)
      Bypass.down(bypass)
    end
  end

  describe "/addresses/{address_hash}/token-transfers" do
    test "get token transfers with ok reputation", %{conn: conn} do
      init_value = Application.get_env(:block_scout_web, :hide_scam_addresses)
      Application.put_env(:block_scout_web, :hide_scam_addresses, true)
      on_exit(fn -> Application.put_env(:block_scout_web, :hide_scam_addresses, init_value) end)

      address = insert(:address)

      transaction = insert(:transaction, input: "0xabcd010203040506") |> with_block()

      insert(:token_transfer,
        transaction: transaction,
        block: transaction.block,
        block_number: transaction.block_number,
        from_address: address
      )

      request =
        conn |> put_req_cookie("show_scam_tokens", "true") |> get("/api/v2/addresses/#{address.hash}/token-transfers")

      response = json_response(request, 200)

      assert List.first(response["items"])["token"]["reputation"] == "ok"

      assert response == conn |> get("/api/v2/addresses/#{address.hash}/token-transfers") |> json_response(200)
    end

    test "get token transfers with scam reputation", %{conn: conn} do
      init_value = Application.get_env(:block_scout_web, :hide_scam_addresses)
      Application.put_env(:block_scout_web, :hide_scam_addresses, true)
      on_exit(fn -> Application.put_env(:block_scout_web, :hide_scam_addresses, init_value) end)

      address = insert(:address)

      transaction = insert(:transaction, input: "0xabcd010203040506") |> with_block()

      token_transfer =
        insert(:token_transfer,
          transaction: transaction,
          block: transaction.block,
          block_number: transaction.block_number,
          from_address: address
        )

      insert(:scam_badge_to_address, address_hash: token_transfer.token_contract_address_hash)

      request =
        conn |> put_req_cookie("show_scam_tokens", "true") |> get("/api/v2/addresses/#{address.hash}/token-transfers")

      response = json_response(request, 200)

      assert List.first(response["items"])["token"]["reputation"] == "scam"

      request = conn |> get("/api/v2/addresses/#{address.hash}/token-transfers")
      response = json_response(request, 200)

      assert response["items"] == []
    end

    test "get token transfers with ok reputation with hide_scam_addresses=false", %{conn: conn} do
      init_value = Application.get_env(:block_scout_web, :hide_scam_addresses)
      Application.put_env(:block_scout_web, :hide_scam_addresses, false)
      on_exit(fn -> Application.put_env(:block_scout_web, :hide_scam_addresses, init_value) end)

      address = insert(:address)

      transaction = insert(:transaction, input: "0xabcd010203040506") |> with_block()

      insert(:token_transfer,
        transaction: transaction,
        block: transaction.block,
        block_number: transaction.block_number,
        from_address: address
      )

      request = conn |> get("/api/v2/addresses/#{address.hash}/token-transfers")
      response = json_response(request, 200)

      assert List.first(response["items"])["token"]["reputation"] == "ok"
    end

    test "get token transfers with scam reputation with hide_scam_addresses=false", %{conn: conn} do
      init_value = Application.get_env(:block_scout_web, :hide_scam_addresses)
      Application.put_env(:block_scout_web, :hide_scam_addresses, false)
      on_exit(fn -> Application.put_env(:block_scout_web, :hide_scam_addresses, init_value) end)

      address = insert(:address)

      transaction = insert(:transaction, input: "0xabcd010203040506") |> with_block()

      token_transfer =
        insert(:token_transfer,
          transaction: transaction,
          block: transaction.block,
          block_number: transaction.block_number,
          from_address: address
        )

      insert(:scam_badge_to_address, address_hash: token_transfer.token_contract_address_hash)

      request = conn |> get("/api/v2/addresses/#{address.hash}/token-transfers")
      response = json_response(request, 200)

      assert List.first(response["items"])["token"]["reputation"] == "ok"
    end

    test "get 200 on non existing address", %{conn: conn} do
      address = build(:address)

      request = get(conn, "/api/v2/addresses/#{address.hash}/token-transfers")
      json_response = json_response(request, 200)

      assert %{"items" => [], "next_page_params" => nil} = json_response
    end

    test "get 422 on invalid address", %{conn: conn} do
      request = get(conn, "/api/v2/addresses/0x/token-transfers")

      json_response = json_response(request, 422)

      assert %{
               "errors" => [
                 %{
                   "detail" => "Invalid format. Expected ~r/^0x([A-Fa-f0-9]{40})$/",
                   "source" => %{"pointer" => "/address_hash_param"},
                   "title" => "Invalid value"
                 }
               ]
             } = json_response
    end

    test "get 200 on non existing address of token", %{conn: conn} do
      address = insert(:address)

      token = build(:address)

      request = get(conn, "/api/v2/addresses/#{address.hash}/token-transfers", %{"token" => to_string(token.hash)})
      json_response = json_response(request, 200)

      assert %{"items" => [], "next_page_params" => nil} = json_response
    end

    test "get 422 on invalid token address hash", %{conn: conn} do
      address = insert(:address)

      request = get(conn, "/api/v2/addresses/#{address.hash}/token-transfers", %{"token" => "0x"})

      json_response = json_response(request, 422)

      assert %{
               "errors" => [
                 %{
                   "detail" => "Invalid format. Expected ~r/^0x([A-Fa-f0-9]{40})$/",
                   "source" => %{"pointer" => "/token"},
                   "title" => "Invalid value"
                 }
               ]
             } = json_response
    end

    test "get relevant token transfer", %{conn: conn} do
      address = insert(:address)

      transaction = insert(:transaction, input: "0xabcd010203040506") |> with_block()

      insert(:token_transfer,
        transaction: transaction,
        block: transaction.block,
        block_number: transaction.block_number
      )

      token_transfer =
        insert(:token_transfer,
          transaction: transaction,
          block: transaction.block,
          block_number: transaction.block_number,
          from_address: address
        )

      request = get(conn, "/api/v2/addresses/#{address.hash}/token-transfers")

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 1
      assert response["next_page_params"] == nil

      compare_item(token_transfer, Enum.at(response["items"], 0))
    end

    test "method in token transfer could be decoded", %{conn: conn} do
      insert(:contract_method,
        identifier: Base.decode16!("731133e9", case: :lower),
        abi: %{
          "constant" => false,
          "inputs" => [
            %{"name" => "account", "type" => "address"},
            %{"name" => "id", "type" => "uint256"},
            %{"name" => "amount", "type" => "uint256"},
            %{"name" => "data", "type" => "bytes"}
          ],
          "name" => "mint",
          "outputs" => [],
          "payable" => false,
          "stateMutability" => "nonpayable",
          "type" => "function"
        }
      )

      address = insert(:address)

      transaction =
        insert(:transaction,
          input:
            "0x731133e9000000000000000000000000bb36c792b9b45aaf8b848a1392b0d6559202729e000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000001700000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000000"
        )
        |> with_block()

      insert(:token_transfer,
        transaction: transaction,
        block: transaction.block,
        block_number: transaction.block_number
      )

      token_transfer =
        insert(:token_transfer,
          transaction: transaction,
          block: transaction.block,
          block_number: transaction.block_number,
          from_address: address
        )

      request = get(conn, "/api/v2/addresses/#{address.hash}/token-transfers")

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 1
      assert response["next_page_params"] == nil
      compare_item(token_transfer, Enum.at(response["items"], 0))
      assert Enum.at(response["items"], 0)["method"] == "mint"
    end

    test "get relevant token transfer filtered by token", %{conn: conn} do
      token = insert(:token)

      address = insert(:address)

      transaction = insert(:transaction, input: "0xabcd010203040506") |> with_block()

      insert(:token_transfer,
        transaction: transaction,
        block: transaction.block,
        block_number: transaction.block_number
      )

      insert(:token_transfer,
        transaction: transaction,
        block: transaction.block,
        block_number: transaction.block_number,
        from_address: address
      )

      token_transfer =
        insert(:token_transfer,
          transaction: transaction,
          block: transaction.block,
          block_number: transaction.block_number,
          from_address: address,
          token_contract_address: token.contract_address
        )

      request =
        get(conn, "/api/v2/addresses/#{address.hash}/token-transfers", %{
          "token" => to_string(token.contract_address)
        })

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 1
      assert response["next_page_params"] == nil

      compare_item(token_transfer, Enum.at(response["items"], 0))
    end

    test "token transfers by token can paginate", %{conn: conn} do
      address = insert(:address)

      token = insert(:token)

      token_transfers =
        for _ <- 0..50 do
          transaction = insert(:transaction, input: "0xabcd010203040506") |> with_block()

          insert(:token_transfer,
            transaction: transaction,
            block: transaction.block,
            block_number: transaction.block_number,
            from_address: address
          )

          insert(:token_transfer,
            transaction: transaction,
            block: transaction.block,
            block_number: transaction.block_number,
            from_address: address,
            token_contract_address: token.contract_address
          )
        end

      params = %{"token" => to_string(token.contract_address)}
      request = get(conn, "/api/v2/addresses/#{address.hash}/token-transfers", params)
      assert response = json_response(request, 200)

      request_2nd_page =
        get(conn, "/api/v2/addresses/#{address.hash}/token-transfers", Map.merge(params, response["next_page_params"]))

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, token_transfers)
    end

    test "get only :to token transfer", %{conn: conn} do
      address = insert(:address)

      transaction = insert(:transaction, input: "0xabcd010203040506") |> with_block()

      insert(:token_transfer,
        transaction: transaction,
        block: transaction.block,
        block_number: transaction.block_number,
        from_address: address
      )

      token_transfer =
        insert(:token_transfer,
          transaction: transaction,
          block: transaction.block,
          block_number: transaction.block_number,
          to_address: address
        )

      request = get(conn, "/api/v2/addresses/#{address.hash}/token-transfers", %{"filter" => "to"})

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 1
      assert response["next_page_params"] == nil

      compare_item(token_transfer, Enum.at(response["items"], 0))
    end

    test "get only :from token transfer", %{conn: conn} do
      address = insert(:address)

      transaction = insert(:transaction, input: "0xabcd010203040506") |> with_block()

      token_transfer =
        insert(:token_transfer,
          transaction: transaction,
          block: transaction.block,
          block_number: transaction.block_number,
          from_address: address
        )

      insert(:token_transfer,
        transaction: transaction,
        block: transaction.block,
        block_number: transaction.block_number,
        to_address: address
      )

      request = get(conn, "/api/v2/addresses/#{address.hash}/token-transfers", %{"filter" => "from"})

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 1
      assert response["next_page_params"] == nil

      compare_item(token_transfer, Enum.at(response["items"], 0))
    end

    test "token transfers can paginate", %{conn: conn} do
      address = insert(:address)

      token_transfers =
        for _ <- 0..50 do
          transaction = insert(:transaction, input: "0xabcd010203040506") |> with_block()

          insert(:token_transfer,
            transaction: transaction,
            block: transaction.block,
            block_number: transaction.block_number,
            from_address: address
          )
        end

      request = get(conn, "/api/v2/addresses/#{address.hash}/token-transfers")
      assert response = json_response(request, 200)

      request_2nd_page = get(conn, "/api/v2/addresses/#{address.hash}/token-transfers", response["next_page_params"])
      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, token_transfers)
    end

    test ":to token transfers can paginate", %{conn: conn} do
      address = insert(:address)

      for _ <- 0..50 do
        transaction = insert(:transaction, input: "0xabcd010203040506") |> with_block()

        insert(:token_transfer,
          transaction: transaction,
          block: transaction.block,
          block_number: transaction.block_number,
          from_address: address
        )
      end

      token_transfers =
        for _ <- 0..50 do
          transaction = insert(:transaction, input: "0xabcd010203040506") |> with_block()

          insert(:token_transfer,
            transaction: transaction,
            block: transaction.block,
            block_number: transaction.block_number,
            to_address: address
          )
        end

      filter = %{"filter" => "to"}
      request = get(conn, "/api/v2/addresses/#{address.hash}/token-transfers", filter)
      assert response = json_response(request, 200)

      request_2nd_page =
        get(conn, "/api/v2/addresses/#{address.hash}/token-transfers", Map.merge(response["next_page_params"], filter))

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, token_transfers)
    end

    test ":from token transfers can paginate", %{conn: conn} do
      address = insert(:address)

      token_transfers =
        for _ <- 0..50 do
          transaction = insert(:transaction, input: "0xabcd010203040506") |> with_block()

          insert(:token_transfer,
            transaction: transaction,
            block: transaction.block,
            block_number: transaction.block_number,
            from_address: address
          )
        end

      for _ <- 0..50 do
        transaction = insert(:transaction, input: "0xabcd010203040506") |> with_block()

        insert(:token_transfer,
          transaction: transaction,
          block: transaction.block,
          block_number: transaction.block_number,
          to_address: address
        )
      end

      filter = %{"filter" => "from"}
      request = get(conn, "/api/v2/addresses/#{address.hash}/token-transfers", filter)
      assert response = json_response(request, 200)

      request_2nd_page =
        get(conn, "/api/v2/addresses/#{address.hash}/token-transfers", Map.merge(response["next_page_params"], filter))

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, token_transfers)
    end

    test ":from + :to tt can paginate", %{conn: conn} do
      address = insert(:address)

      tt_from =
        for _ <- 0..49 do
          transaction = insert(:transaction, input: "0xabcd010203040506") |> with_block()

          insert(:token_transfer,
            transaction: transaction,
            block: transaction.block,
            block_number: transaction.block_number,
            from_address: address
          )
        end

      tt_to =
        for _ <- 0..50 do
          transaction = insert(:transaction, input: "0xabcd010203040506") |> with_block()

          insert(:token_transfer,
            transaction: transaction,
            block: transaction.block,
            block_number: transaction.block_number,
            to_address: address
          )
        end

      request = get(conn, "/api/v2/addresses/#{address.hash}/token-transfers")
      assert response = json_response(request, 200)

      request_2nd_page = get(conn, "/api/v2/addresses/#{address.hash}/token-transfers", response["next_page_params"])
      assert response_2nd_page = json_response(request_2nd_page, 200)

      assert Enum.count(response["items"]) == 50
      assert response["next_page_params"] != nil
      compare_item(Enum.at(tt_to, 50), Enum.at(response["items"], 0))
      compare_item(Enum.at(tt_to, 1), Enum.at(response["items"], 49))

      assert Enum.count(response_2nd_page["items"]) == 50
      assert response_2nd_page["next_page_params"] != nil
      compare_item(Enum.at(tt_to, 0), Enum.at(response_2nd_page["items"], 0))
      compare_item(Enum.at(tt_from, 49), Enum.at(response_2nd_page["items"], 1))
      compare_item(Enum.at(tt_from, 1), Enum.at(response_2nd_page["items"], 49))

      request_3rd_page =
        get(conn, "/api/v2/addresses/#{address.hash}/token-transfers", response_2nd_page["next_page_params"])

      assert response_3rd_page = json_response(request_3rd_page, 200)

      check_paginated_response(response_2nd_page, response_3rd_page, tt_from ++ [Enum.at(tt_to, 0)])
    end

    test "check token type filters", %{conn: conn} do
      address = insert(:address)

      erc_20_token = insert(:token, type: "ERC-20")

      erc_20_tt =
        for _ <- 0..50 do
          transaction = insert(:transaction, input: "0xabcd010203040506") |> with_block()

          insert(:token_transfer,
            transaction: transaction,
            block: transaction.block,
            block_number: transaction.block_number,
            from_address: address,
            token_contract_address: erc_20_token.contract_address,
            token_type: "ERC-20"
          )
        end

      erc_721_token = insert(:token, type: "ERC-721")

      erc_721_tt =
        for x <- 0..50 do
          transaction = insert(:transaction, input: "0xabcd010203040506") |> with_block()

          insert(:token_transfer,
            transaction: transaction,
            block: transaction.block,
            block_number: transaction.block_number,
            from_address: address,
            token_contract_address: erc_721_token.contract_address,
            token_ids: [x],
            token_type: "ERC-721"
          )
        end

      erc_1155_token = insert(:token, type: "ERC-1155")

      erc_1155_tt =
        for x <- 0..50 do
          transaction = insert(:transaction, input: "0xabcd010203040506") |> with_block()

          insert(:token_transfer,
            transaction: transaction,
            block: transaction.block,
            block_number: transaction.block_number,
            from_address: address,
            token_contract_address: erc_1155_token.contract_address,
            token_ids: [x],
            token_type: "ERC-1155"
          )
        end

      # -- ERC-20 --
      filter = %{"type" => "ERC-20"}
      request = get(conn, "/api/v2/addresses/#{address.hash}/token-transfers", filter)
      assert response = json_response(request, 200)

      request_2nd_page =
        get(conn, "/api/v2/addresses/#{address.hash}/token-transfers", Map.merge(response["next_page_params"], filter))

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, erc_20_tt)
      # -- ------ --

      # -- ERC-721 --
      filter = %{"type" => "ERC-721"}
      request = get(conn, "/api/v2/addresses/#{address.hash}/token-transfers", filter)
      assert response = json_response(request, 200)

      request_2nd_page =
        get(conn, "/api/v2/addresses/#{address.hash}/token-transfers", Map.merge(response["next_page_params"], filter))

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, erc_721_tt)
      # -- ------ --

      # -- ERC-1155 --
      filter = %{"type" => "ERC-1155"}
      request = get(conn, "/api/v2/addresses/#{address.hash}/token-transfers", filter)
      assert response = json_response(request, 200)

      request_2nd_page =
        get(conn, "/api/v2/addresses/#{address.hash}/token-transfers", Map.merge(response["next_page_params"], filter))

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, erc_1155_tt)
      # -- ------ --

      # two filters simultaneously (includes ERC-7984 but no ERC-7984 transfers created in this test)
      filter = %{"type" => "ERC-1155,ERC-20,ERC-7984"}
      request = get(conn, "/api/v2/addresses/#{address.hash}/token-transfers", filter)
      assert response = json_response(request, 200)

      request_2nd_page =
        get(conn, "/api/v2/addresses/#{address.hash}/token-transfers", Map.merge(response["next_page_params"], filter))

      assert response_2nd_page = json_response(request_2nd_page, 200)

      assert Enum.count(response["items"]) == 50
      assert response["next_page_params"] != nil
      compare_item(Enum.at(erc_1155_tt, 50), Enum.at(response["items"], 0))
      compare_item(Enum.at(erc_1155_tt, 1), Enum.at(response["items"], 49))

      assert Enum.count(response_2nd_page["items"]) == 50
      assert response_2nd_page["next_page_params"] != nil
      compare_item(Enum.at(erc_1155_tt, 0), Enum.at(response_2nd_page["items"], 0))
      compare_item(Enum.at(erc_20_tt, 50), Enum.at(response_2nd_page["items"], 1))
      compare_item(Enum.at(erc_20_tt, 2), Enum.at(response_2nd_page["items"], 49))

      request_3rd_page =
        get(
          conn,
          "/api/v2/addresses/#{address.hash}/token-transfers",
          Map.merge(response_2nd_page["next_page_params"], filter)
        )

      assert response_3rd_page = json_response(request_3rd_page, 200)
      assert Enum.count(response_3rd_page["items"]) == 2
      assert response_3rd_page["next_page_params"] == nil
      compare_item(Enum.at(erc_20_tt, 1), Enum.at(response_3rd_page["items"], 0))
      compare_item(Enum.at(erc_20_tt, 0), Enum.at(response_3rd_page["items"], 1))
      # -- ------ --
    end

    test "type and direction filters at the same time", %{conn: conn} do
      address = insert(:address)

      erc_20_token = insert(:token, type: "ERC-20")

      erc_20_tt =
        for _ <- 0..50 do
          transaction = insert(:transaction, input: "0xabcd010203040506") |> with_block()

          insert(:token_transfer,
            transaction: transaction,
            block: transaction.block,
            block_number: transaction.block_number,
            from_address: address,
            token_contract_address: erc_20_token.contract_address,
            token_type: "ERC-20"
          )
        end

      erc_721_token = insert(:token, type: "ERC-721")

      erc_721_tt =
        for x <- 0..50 do
          transaction = insert(:transaction, input: "0xabcd010203040506") |> with_block()

          insert(:token_transfer,
            transaction: transaction,
            block: transaction.block,
            block_number: transaction.block_number,
            to_address: address,
            token_contract_address: erc_721_token.contract_address,
            token_ids: [x],
            token_type: "ERC-721"
          )
        end

      filter = %{"type" => "ERC-721", "filter" => "from"}
      request = get(conn, "/api/v2/addresses/#{address.hash}/token-transfers", filter)
      assert response = json_response(request, 200)
      assert response["items"] == []
      assert response["next_page_params"] == nil

      filter = %{"type" => "ERC-721", "filter" => "to"}
      request = get(conn, "/api/v2/addresses/#{address.hash}/token-transfers", filter)
      assert response = json_response(request, 200)

      request_2nd_page =
        get(
          conn,
          "/api/v2/addresses/#{address.hash}/token-transfers",
          Map.merge(response["next_page_params"], filter)
        )

      assert response_2nd_page = json_response(request_2nd_page, 200)
      check_paginated_response(response, response_2nd_page, erc_721_tt)
      filter = %{"type" => "ERC-721,ERC-20", "filter" => "to"}
      request = get(conn, "/api/v2/addresses/#{address.hash}/token-transfers", filter)
      assert response = json_response(request, 200)

      request_2nd_page =
        get(conn, "/api/v2/addresses/#{address.hash}/token-transfers", Map.merge(response["next_page_params"], filter))

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, erc_721_tt)

      filter = %{"type" => "ERC-721,ERC-20", "filter" => "from"}
      request = get(conn, "/api/v2/addresses/#{address.hash}/token-transfers", filter)
      assert response = json_response(request, 200)

      request_2nd_page =
        get(conn, "/api/v2/addresses/#{address.hash}/token-transfers", Map.merge(response["next_page_params"], filter))

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, erc_20_tt)
    end

    test "check that same token_ids within batch squashes", %{conn: conn} do
      address = insert(:address)

      token = insert(:token, type: "ERC-1155")

      id = 0

      insert(:token_instance, token_id: id, token_contract_address_hash: token.contract_address_hash)

      tt =
        for _ <- 0..50 do
          transaction = insert(:transaction, input: "0xabcd010203040506") |> with_block()

          insert(:token_transfer,
            to_address: address,
            transaction: transaction,
            block: transaction.block,
            block_number: transaction.block_number,
            token_contract_address: token.contract_address,
            token_ids: Enum.map(0..50, fn _x -> id end),
            token_type: "ERC-1155",
            amounts: Enum.map(0..50, fn x -> x end)
          )
        end

      token_transfers =
        for i <- tt do
          %TokenTransfer{i | token_ids: [id], amount: Decimal.new(1275)}
        end

      request = get(conn, "/api/v2/addresses/#{address.hash}/token-transfers")
      assert response = json_response(request, 200)

      request_2nd_page = get(conn, "/api/v2/addresses/#{address.hash}/token-transfers", response["next_page_params"])

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, token_transfers)
    end

    test "check that pagination works for 721 tokens", %{conn: conn} do
      address = insert(:address)

      token = insert(:token, type: "ERC-721")

      token_transfers =
        for i <- 0..50 do
          transaction = insert(:transaction, input: "0xabcd010203040506") |> with_block()

          insert(:token_transfer,
            transaction: transaction,
            to_address: address,
            block: transaction.block,
            block_number: transaction.block_number,
            token_contract_address: token.contract_address,
            token_ids: [i],
            token_type: "ERC-721"
          )
        end

      request = get(conn, "/api/v2/addresses/#{address.hash}/token-transfers")
      assert response = json_response(request, 200)

      request_2nd_page = get(conn, "/api/v2/addresses/#{address.hash}/token-transfers", response["next_page_params"])

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, token_transfers)
    end

    test "check that pagination works fine with 1155 batches #1 (large batch) + check filters", %{conn: conn} do
      address = insert(:address)

      token = insert(:token, type: "ERC-1155")
      transaction = insert(:transaction, input: "0xabcd010203040506") |> with_block()

      tt =
        insert(:token_transfer,
          transaction: transaction,
          to_address: address,
          block: transaction.block,
          block_number: transaction.block_number,
          token_contract_address: token.contract_address,
          token_ids: Enum.map(0..50, fn x -> x end),
          token_type: "ERC-1155",
          amounts: Enum.map(0..50, fn x -> x end)
        )

      token_transfers =
        for i <- 0..50 do
          %TokenTransfer{tt | token_ids: [i], amount: i}
        end

      filter = %{"type" => "ERC-1155", "filter" => "to"}

      request = get(conn, "/api/v2/addresses/#{address.hash}/token-transfers", filter)
      assert response = json_response(request, 200)

      request_2nd_page =
        get(conn, "/api/v2/addresses/#{address.hash}/token-transfers", Map.merge(response["next_page_params"], filter))

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, token_transfers)

      filter = %{"type" => "ERC-1155", "filter" => "from"}

      request = get(conn, "/api/v2/addresses/#{address.hash}/token-transfers", filter)
      assert response = json_response(request, 200)
      assert %{"items" => [], "next_page_params" => nil} = response
    end

    test "check that pagination works fine with 1155 batches #2 some batches on the first page and one on the second",
         %{conn: conn} do
      address = insert(:address)

      token = insert(:token, type: "ERC-1155")

      transaction_1 = insert(:transaction, input: "0xabcd010203040506") |> with_block()

      tt_1 =
        insert(:token_transfer,
          transaction: transaction_1,
          to_address: address,
          block: transaction_1.block,
          block_number: transaction_1.block_number,
          token_contract_address: token.contract_address,
          token_ids: Enum.map(0..24, fn x -> x end),
          token_type: "ERC-1155",
          amounts: Enum.map(0..24, fn x -> x end)
        )

      token_transfers_1 =
        for i <- 0..24 do
          %TokenTransfer{tt_1 | token_ids: [i], amount: i}
        end

      transaction_2 = insert(:transaction, input: "0xabcd010203040506") |> with_block()

      tt_2 =
        insert(:token_transfer,
          transaction: transaction_2,
          to_address: address,
          block: transaction_2.block,
          block_number: transaction_2.block_number,
          token_contract_address: token.contract_address,
          token_ids: Enum.map(25..49, fn x -> x end),
          token_type: "ERC-1155",
          amounts: Enum.map(25..49, fn x -> x end)
        )

      token_transfers_2 =
        for i <- 25..49 do
          %TokenTransfer{tt_2 | token_ids: [i], amount: i}
        end

      tt_3 =
        insert(:token_transfer,
          transaction: transaction_2,
          from_address: address,
          block: transaction_2.block,
          block_number: transaction_2.block_number,
          token_contract_address: token.contract_address,
          token_ids: [50],
          token_type: "ERC-1155",
          amounts: [50]
        )

      request = get(conn, "/api/v2/addresses/#{address.hash}/token-transfers")
      assert response = json_response(request, 200)

      request_2nd_page = get(conn, "/api/v2/addresses/#{address.hash}/token-transfers", response["next_page_params"])

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, token_transfers_1 ++ token_transfers_2 ++ [tt_3])
    end

    test "check that pagination works fine with 1155 batches #3", %{conn: conn} do
      address = insert(:address)

      token = insert(:token, type: "ERC-1155")

      transaction_1 = insert(:transaction, input: "0xabcd010203040506") |> with_block()

      tt_1 =
        insert(:token_transfer,
          transaction: transaction_1,
          from_address: address,
          block: transaction_1.block,
          block_number: transaction_1.block_number,
          token_contract_address: token.contract_address,
          token_ids: Enum.map(0..24, fn x -> x end),
          token_type: "ERC-1155",
          amounts: Enum.map(0..24, fn x -> x end)
        )

      token_transfers_1 =
        for i <- 0..24 do
          %TokenTransfer{tt_1 | token_ids: [i], amount: i}
        end

      transaction_2 = insert(:transaction, input: "0xabcd010203040506") |> with_block()

      tt_2 =
        insert(:token_transfer,
          transaction: transaction_2,
          to_address: address,
          block: transaction_2.block,
          block_number: transaction_2.block_number,
          token_contract_address: token.contract_address,
          token_ids: Enum.map(25..50, fn x -> x end),
          token_type: "ERC-1155",
          amounts: Enum.map(25..50, fn x -> x end)
        )

      token_transfers_2 =
        for i <- 25..50 do
          %TokenTransfer{tt_2 | token_ids: [i], amount: i}
        end

      request = get(conn, "/api/v2/addresses/#{address.hash}/token-transfers")
      assert response = json_response(request, 200)

      request_2nd_page = get(conn, "/api/v2/addresses/#{address.hash}/token-transfers", response["next_page_params"])

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, token_transfers_1 ++ token_transfers_2)
    end

    if @chain_identity == {:optimism, :celo} do
      test "get token balance when a token transfer has no transaction", %{conn: conn} do
        address = insert(:address)
        block = insert(:block)

        token_transfer =
          insert(:token_transfer,
            from_address: address,
            transaction_hash: nil,
            block: block,
            transaction: nil
          )

        request = get(conn, "/api/v2/addresses/#{address.hash}/token-transfers")

        assert response = json_response(request, 200)
        assert Enum.count(response["items"]) == 1
        assert response["next_page_params"] == nil

        compare_item(token_transfer, Enum.at(response["items"], 0), true)
      end
    end
  end

  describe "/addresses/{address_hash}/internal-transactions" do
    test "get empty list on non existing address", %{conn: conn} do
      address = build(:address)

      request = get(conn, "/api/v2/addresses/#{address.hash}/internal-transactions")
      response = json_response(request, 200)

      assert %{"items" => [], "next_page_params" => nil} = response
    end

    test "get 422 on invalid address", %{conn: conn} do
      request = get(conn, "/api/v2/addresses/0x/internal-transactions")

      json_response = json_response(request, 422)

      assert %{
               "errors" => [
                 %{
                   "detail" => "Invalid format. Expected ~r/^0x([A-Fa-f0-9]{40})$/",
                   "source" => %{"pointer" => "/address_hash_param"},
                   "title" => "Invalid value"
                 }
               ]
             } = json_response
    end

    test "get internal transaction and filter working", %{conn: conn} do
      address = insert(:address)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      internal_transaction_from =
        insert(:internal_transaction,
          transaction: transaction,
          index: 1,
          block_number: transaction.block_number,
          transaction_index: transaction.index,
          block_hash: transaction.block_hash,
          from_address: address
        )

      internal_transaction_to =
        insert(:internal_transaction,
          transaction: transaction,
          index: 2,
          block_number: transaction.block_number,
          transaction_index: transaction.index,
          block_hash: transaction.block_hash,
          to_address: address
        )

      request = get(conn, "/api/v2/addresses/#{address.hash}/internal-transactions")

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 2
      assert response["next_page_params"] == nil

      compare_item(internal_transaction_from, Enum.at(response["items"], 1))
      compare_item(internal_transaction_to, Enum.at(response["items"], 0))

      request = get(conn, "/api/v2/addresses/#{address.hash}/internal-transactions", %{"filter" => "from"})

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 1
      assert response["next_page_params"] == nil

      compare_item(internal_transaction_from, Enum.at(response["items"], 0))

      request = get(conn, "/api/v2/addresses/#{address.hash}/internal-transactions", %{"filter" => "to"})

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 1
      assert response["next_page_params"] == nil
      compare_item(internal_transaction_to, Enum.at(response["items"], 0))
    end

    test "returns gas_limit as 0 for selfdestruct without gas", %{conn: conn} do
      address = insert(:address)

      transaction =
        :transaction
        |> insert(from_address: address)
        |> with_block()

      internal_transaction =
        insert(:internal_transaction_selfdestruct,
          transaction: transaction,
          index: 1,
          block_number: transaction.block_number,
          transaction_index: transaction.index,
          block_hash: transaction.block_hash,
          from_address: address,
          to_address: insert(:address),
          gas: nil,
          gas_used: nil
        )

      request = get(conn, "/api/v2/addresses/#{address.hash}/internal-transactions")

      assert %{"items" => [item], "next_page_params" => nil} = json_response(request, 200)
      assert "0" == to_string(item["gas_limit"])
      assert item["index"] == internal_transaction.index
    end

    test "internal transactions can paginate", %{conn: conn} do
      address = insert(:address)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      internal_transactions_from =
        for i <- 1..51 do
          insert(:internal_transaction,
            transaction: transaction,
            index: i,
            block_number: transaction.block_number,
            transaction_index: transaction.index,
            block_hash: transaction.block_hash,
            from_address: address
          )
        end

      request = get(conn, "/api/v2/addresses/#{address.hash}/internal-transactions")
      assert response = json_response(request, 200)

      request_2nd_page =
        get(conn, "/api/v2/addresses/#{address.hash}/internal-transactions", response["next_page_params"])

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, internal_transactions_from)

      internal_transactions_to =
        for i <- 52..102 do
          insert(:internal_transaction,
            transaction: transaction,
            index: i,
            block_number: transaction.block_number,
            transaction_index: transaction.index,
            block_hash: transaction.block_hash,
            to_address: address
          )
        end

      filter = %{"filter" => "to"}
      request = get(conn, "/api/v2/addresses/#{address.hash}/internal-transactions", filter)
      assert response = json_response(request, 200)

      request_2nd_page =
        get(
          conn,
          "/api/v2/addresses/#{address.hash}/internal-transactions",
          Map.merge(response["next_page_params"], filter)
        )

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, internal_transactions_to)

      filter = %{"filter" => "from"}
      request = get(conn, "/api/v2/addresses/#{address.hash}/internal-transactions", filter)
      assert response = json_response(request, 200)

      request_2nd_page =
        get(
          conn,
          "/api/v2/addresses/#{address.hash}/internal-transactions",
          Map.merge(response["next_page_params"], filter)
        )

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, internal_transactions_from)
    end
  end

  describe "/addresses/{address_hash}/blocks-validated" do
    test "get empty list on non existing address", %{conn: conn} do
      address = build(:address)

      request = get(conn, "/api/v2/addresses/#{address.hash}/blocks-validated")
      assert response = json_response(request, 200)
      assert %{"items" => [], "next_page_params" => nil} = response
    end

    test "get 422 on invalid address", %{conn: conn} do
      request = get(conn, "/api/v2/addresses/0x/blocks-validated")

      json_response = json_response(request, 422)

      assert %{
               "errors" => [
                 %{
                   "detail" => "Invalid format. Expected ~r/^0x([A-Fa-f0-9]{40})$/",
                   "source" => %{"pointer" => "/address_hash_param"},
                   "title" => "Invalid value"
                 }
               ]
             } = json_response
    end

    test "get relevant block validated", %{conn: conn} do
      address = insert(:address)
      insert(:block)
      block = insert(:block, miner: address)

      request = get(conn, "/api/v2/addresses/#{address.hash}/blocks-validated")

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 1
      assert response["next_page_params"] == nil

      compare_item(block, Enum.at(response["items"], 0))
    end

    test "blocks validated can be paginated", %{conn: conn} do
      address = insert(:address)
      insert(:block)
      blocks = insert_list(51, :block, miner: address)

      request = get(conn, "/api/v2/addresses/#{address.hash}/blocks-validated")
      assert response = json_response(request, 200)

      request_2nd_page = get(conn, "/api/v2/addresses/#{address.hash}/blocks-validated", response["next_page_params"])
      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, blocks)
    end
  end

  describe "/addresses/{address_hash}/token-balances" do
    test "get token balances with ok reputation", %{conn: conn} do
      init_value = Application.get_env(:block_scout_web, :hide_scam_addresses)
      Application.put_env(:block_scout_web, :hide_scam_addresses, true)
      on_exit(fn -> Application.put_env(:block_scout_web, :hide_scam_addresses, init_value) end)

      address = insert(:address)

      insert(:address_current_token_balance_with_token_id, address: address)

      request =
        conn |> put_req_cookie("show_scam_tokens", "true") |> get("/api/v2/addresses/#{address.hash}/token-balances")

      response = json_response(request, 200)

      assert List.first(response)["token"]["reputation"] == "ok"

      assert response == conn |> get("/api/v2/addresses/#{address.hash}/token-balances") |> json_response(200)
    end

    test "get token balances with scam reputation", %{conn: conn} do
      init_value = Application.get_env(:block_scout_web, :hide_scam_addresses)
      Application.put_env(:block_scout_web, :hide_scam_addresses, true)
      on_exit(fn -> Application.put_env(:block_scout_web, :hide_scam_addresses, init_value) end)

      address = insert(:address)

      ctb = insert(:address_current_token_balance_with_token_id, address: address)

      insert(:scam_badge_to_address, address_hash: ctb.token_contract_address_hash)

      request =
        conn |> put_req_cookie("show_scam_tokens", "true") |> get("/api/v2/addresses/#{address.hash}/token-balances")

      response = json_response(request, 200)

      assert List.first(response)["token"]["reputation"] == "scam"

      request = conn |> get("/api/v2/addresses/#{address.hash}/token-balances")
      response = json_response(request, 200)

      assert response == []
    end

    test "get smart-contract with ok reputation with hide_scam_addresses=false", %{conn: conn} do
      init_value = Application.get_env(:block_scout_web, :hide_scam_addresses)
      Application.put_env(:block_scout_web, :hide_scam_addresses, false)
      on_exit(fn -> Application.put_env(:block_scout_web, :hide_scam_addresses, init_value) end)

      address = insert(:address)

      insert(:address_current_token_balance_with_token_id, address: address)

      request = conn |> get("/api/v2/addresses/#{address.hash}/token-balances")
      response = json_response(request, 200)

      assert List.first(response)["token"]["reputation"] == "ok"
    end

    test "get smart-contract with scam reputation with hide_scam_addresses=false", %{conn: conn} do
      init_value = Application.get_env(:block_scout_web, :hide_scam_addresses)
      Application.put_env(:block_scout_web, :hide_scam_addresses, false)
      on_exit(fn -> Application.put_env(:block_scout_web, :hide_scam_addresses, init_value) end)

      address = insert(:address)

      ctb = insert(:address_current_token_balance_with_token_id, address: address)

      insert(:scam_badge_to_address, address_hash: ctb.token_contract_address_hash)

      request = conn |> get("/api/v2/addresses/#{address.hash}/token-balances")
      response = json_response(request, 200)

      assert List.first(response)["token"]["reputation"] == "ok"
    end

    test "get empty list on non existing address", %{conn: conn} do
      address = build(:address)

      request = get(conn, "/api/v2/addresses/#{address.hash}/token-balances")
      assert response = json_response(request, 200)
      assert response == []
    end

    test "get 422 on invalid address", %{conn: conn} do
      request = get(conn, "/api/v2/addresses/0x/token-balances")

      json_response = json_response(request, 422)

      assert %{
               "errors" => [
                 %{
                   "detail" => "Invalid format. Expected ~r/^0x([A-Fa-f0-9]{40})$/",
                   "source" => %{"pointer" => "/address_hash_param"},
                   "title" => "Invalid value"
                 }
               ]
             } = json_response
    end

    test "get token balance", %{conn: conn} do
      address = insert(:address)

      ctbs =
        for _ <- 0..50 do
          insert(:address_current_token_balance_with_token_id, address: address) |> Repo.preload([:token])
        end
        |> Enum.sort_by(fn x -> x.value end, :desc)

      request = get(conn, "/api/v2/addresses/#{address.hash}/token-balances")

      assert response = json_response(request, 200)

      for i <- 0..50 do
        compare_item(Enum.at(ctbs, i), Enum.at(response, i))
      end
    end
  end

  describe "/addresses/{address_hash}/coin-balance-history" do
    test "get empty list on non existing address", %{conn: conn} do
      address = build(:address)

      request = get(conn, "/api/v2/addresses/#{address.hash}/coin-balance-history")
      response = json_response(request, 200)

      assert %{"items" => [], "next_page_params" => nil} = response
    end

    test "get 422 on invalid address", %{conn: conn} do
      request = get(conn, "/api/v2/addresses/0x/coin-balance-history")

      json_response = json_response(request, 422)

      assert %{
               "errors" => [
                 %{
                   "detail" => "Invalid format. Expected ~r/^0x([A-Fa-f0-9]{40})$/",
                   "source" => %{"pointer" => "/address_hash_param"},
                   "title" => "Invalid value"
                 }
               ]
             } = json_response
    end

    test "get coin balance history", %{conn: conn} do
      address = insert(:address)

      insert(:address_coin_balance)
      acb = insert(:address_coin_balance, address: address)

      request = get(conn, "/api/v2/addresses/#{address.hash}/coin-balance-history")

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 1
      assert response["next_page_params"] == nil

      compare_item(acb, Enum.at(response["items"], 0))
    end

    test "get coin balance with transaction", %{conn: conn} do
      address = insert(:address)

      transaction =
        :transaction
        |> insert(to_address_hash: address.hash, to_address: address, value: 123)
        |> with_block()

      acb = insert(:address_coin_balance, address: address, block_number: transaction.block_number)

      request = get(conn, "/api/v2/addresses/#{address.hash}/coin-balance-history")

      assert %{"items" => [acb_json], "next_page_params" => nil} = json_response(request, 200)
      assert acb_json["transaction_hash"] == to_string(transaction.hash)

      compare_item(acb, acb_json)
    end

    test "get coin balance with internal transaction", %{conn: conn} do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      address = insert(:address)

      insert(:internal_transaction,
        type: "call",
        call_type: "call",
        transaction: transaction,
        transaction_index: transaction.index,
        block: transaction.block,
        to_address: address,
        value: 123,
        block_number: transaction.block_number,
        index: 1
      )

      insert(:address_coin_balance)
      acb = insert(:address_coin_balance, address: address, block_number: transaction.block_number)

      request = get(conn, "/api/v2/addresses/#{address.hash}/coin-balance-history")

      assert %{"items" => [acb_json], "next_page_params" => nil} = json_response(request, 200)
      assert acb_json["transaction_hash"] == to_string(transaction.hash)

      compare_item(acb, acb_json)
    end

    test "coin balance history can paginate", %{conn: conn} do
      address = insert(:address)

      acbs = insert_list(51, :address_coin_balance, address: address)

      request = get(conn, "/api/v2/addresses/#{address.hash}/coin-balance-history")
      assert response = json_response(request, 200)

      request_2nd_page =
        get(conn, "/api/v2/addresses/#{address.hash}/coin-balance-history", response["next_page_params"])

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, acbs)
    end
  end

  describe "/addresses/{address_hash}/coin-balance-history-by-day" do
    test "get empty list on non existing address", %{conn: conn} do
      address = build(:address)

      request = get(conn, "/api/v2/addresses/#{address.hash}/coin-balance-history-by-day")

      days_count =
        Application.get_env(:block_scout_web, BlockScoutWeb.Chain.Address.CoinBalance)[:coin_balance_history_days]

      response = json_response(request, 200)

      assert %{
               "days" => ^days_count,
               "items" => []
             } = response
    end

    test "get 422 on invalid address", %{conn: conn} do
      request = get(conn, "/api/v2/addresses/0x/coin-balance-history-by-day")

      json_response = json_response(request, 422)

      assert %{
               "errors" => [
                 %{
                   "detail" => "Invalid format. Expected ~r/^0x([A-Fa-f0-9]{40})$/",
                   "source" => %{"pointer" => "/address_hash_param"},
                   "title" => "Invalid value"
                 }
               ]
             } = json_response
    end

    test "get coin balance history by day", %{conn: conn} do
      address = insert(:address)
      noon = Timex.now() |> Timex.beginning_of_day() |> Timex.set(hour: 12)
      block = insert(:block, timestamp: noon, number: 2)
      block_one_day_ago = insert(:block, timestamp: Timex.shift(noon, days: -1), number: 1)
      insert(:fetched_balance, address_hash: address.hash, value: 1000, block_number: block.number)
      insert(:fetched_balance, address_hash: address.hash, value: 2000, block_number: block_one_day_ago.number)
      insert(:fetched_balance_daily, address_hash: address.hash, value: 1000, day: noon)
      insert(:fetched_balance_daily, address_hash: address.hash, value: 2000, day: Timex.shift(noon, days: -1))

      request = get(conn, "/api/v2/addresses/#{address.hash}/coin-balance-history-by-day")

      response = json_response(request, 200)

      assert %{
               "days" => 10,
               "items" => [
                 %{"date" => _, "value" => "2000"},
                 %{"date" => _, "value" => "1000"}
               ]
             } = response
    end
  end

  describe "/addresses/{address_hash}/logs" do
    test "get empty list on non existing address", %{conn: conn} do
      address = build(:address)

      request = get(conn, "/api/v2/addresses/#{address.hash}/logs")
      response = json_response(request, 200)
      assert %{"items" => [], "next_page_params" => nil} = response
    end

    test "get 422 on invalid address", %{conn: conn} do
      request = get(conn, "/api/v2/addresses/0x/logs")

      json_response = json_response(request, 422)

      assert %{
               "errors" => [
                 %{
                   "detail" => "Invalid format. Expected ~r/^0x([A-Fa-f0-9]{40})$/",
                   "source" => %{"pointer" => "/address_hash_param"},
                   "title" => "Invalid value"
                 }
               ]
             } = json_response
    end

    test "get log", %{conn: conn} do
      address = insert(:address)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      log =
        insert(:log,
          transaction: transaction,
          index: 1,
          block: transaction.block,
          block_number: transaction.block_number,
          address: address
        )

      request = get(conn, "/api/v2/addresses/#{address.hash}/logs")

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 1
      assert response["next_page_params"] == nil

      compare_item(log, Enum.at(response["items"], 0))
    end

    # for some reasons test does not work if run as single test
    test "logs can paginate", %{conn: conn} do
      address = insert(:address)

      logs =
        for x <- 0..50 do
          transaction =
            :transaction
            |> insert()
            |> with_block()

          insert(:log,
            transaction: transaction,
            index: x,
            block: transaction.block,
            block_number: transaction.block_number,
            address: address
          )
        end

      request = get(conn, "/api/v2/addresses/#{address.hash}/logs")
      assert response = json_response(request, 200)

      request_2nd_page = get(conn, "/api/v2/addresses/#{address.hash}/logs", response["next_page_params"])
      assert response_2nd_page = json_response(request_2nd_page, 200)
      check_paginated_response(response, response_2nd_page, logs)
    end

    # https://github.com/blockscout/blockscout/issues/9926
    test "regression test for 9926", %{conn: conn} do
      address = insert(:address, hash: "0x036cec1a199234fC02f72d29e596a09440825f1C")

      transaction =
        :transaction
        |> insert()
        |> with_block()

      log =
        insert(:log,
          transaction: transaction,
          index: 1,
          block: transaction.block,
          block_number: transaction.block_number,
          address: address
        )

      bypass = Bypass.open()

      Application.put_env(:tesla, :adapter, Tesla.Adapter.Mint)

      old_chain_id = Application.get_env(:block_scout_web, :chain_id)
      chain_id = 1
      Application.put_env(:block_scout_web, :chain_id, chain_id)

      old_env_bens = Application.get_env(:explorer, Explorer.MicroserviceInterfaces.BENS)

      Application.put_env(:explorer, Explorer.MicroserviceInterfaces.BENS,
        service_url: "http://localhost:#{bypass.port}",
        enabled: true
      )

      old_env_metadata = Application.get_env(:explorer, Explorer.MicroserviceInterfaces.Metadata)

      Application.put_env(:explorer, Explorer.MicroserviceInterfaces.Metadata,
        service_url: "http://localhost:#{bypass.port}",
        enabled: true
      )

      Bypass.expect_once(bypass, "POST", "api/v1/#{chain_id}/addresses:batch_resolve_names", fn conn ->
        Conn.resp(
          conn,
          200,
          Jason.encode!(%{
            "names" => %{
              to_string(address) => "test.eth"
            }
          })
        )
      end)

      Bypass.expect_once(bypass, "GET", "api/v1/metadata", fn conn ->
        Conn.resp(
          conn,
          200,
          Jason.encode!(%{
            "addresses" => %{
              to_string(address) => %{
                "tags" => [
                  %{
                    "name" => "Proposer Fee Recipient",
                    "ordinal" => 0,
                    "slug" => "proposer-fee-recipient",
                    "tagType" => "generic",
                    "meta" => "{\"styles\":\"danger_high\"}"
                  }
                ]
              }
            }
          })
        )
      end)

      request = get(conn, "/api/v2/addresses/#{address.hash}/logs")

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 1
      assert response["next_page_params"] == nil

      compare_item(log, Enum.at(response["items"], 0))

      log = Enum.at(response["items"], 0)
      assert log["address"]["ens_domain_name"] == "test.eth"

      assert log["address"]["metadata"] == %{
               "tags" => [
                 %{
                   "slug" => "proposer-fee-recipient",
                   "name" => "Proposer Fee Recipient",
                   "ordinal" => 0,
                   "tagType" => "generic",
                   "meta" => %{"styles" => "danger_high"}
                 }
               ]
             }

      Application.put_env(:block_scout_web, :chain_id, old_chain_id)
      Application.put_env(:explorer, Explorer.MicroserviceInterfaces.BENS, old_env_bens)
      Application.put_env(:explorer, Explorer.MicroserviceInterfaces.Metadata, old_env_metadata)
      Application.put_env(:tesla, :adapter, Explorer.Mock.TeslaAdapter)
      Bypass.down(bypass)
    end

    # https://github.com/blockscout/blockscout/issues/13763
    test "BENS multiprotocol: batch resolve uses protocol-based URL without chain_id", %{conn: conn} do
      address = insert(:address, hash: "0x036cec1a199234fC02f72d29e596a09440825f1C")

      transaction =
        :transaction
        |> insert()
        |> with_block()

      log =
        insert(:log,
          transaction: transaction,
          index: 1,
          block: transaction.block,
          block_number: transaction.block_number,
          address: address
        )

      bypass = Bypass.open()

      Application.put_env(:tesla, :adapter, Tesla.Adapter.Mint)

      old_chain_id = Application.get_env(:block_scout_web, :chain_id)
      chain_id = 1
      Application.put_env(:block_scout_web, :chain_id, chain_id)

      old_env_bens = Application.get_env(:explorer, Explorer.MicroserviceInterfaces.BENS)

      Application.put_env(:explorer, Explorer.MicroserviceInterfaces.BENS,
        service_url: "http://localhost:#{bypass.port}",
        enabled: true,
        protocols: ["ens"]
      )

      old_env_metadata = Application.get_env(:explorer, Explorer.MicroserviceInterfaces.Metadata)

      Application.put_env(:explorer, Explorer.MicroserviceInterfaces.Metadata,
        service_url: "http://localhost:#{bypass.port}",
        enabled: true
      )

      on_exit(fn ->
        Application.put_env(:block_scout_web, :chain_id, old_chain_id)
        Application.put_env(:explorer, Explorer.MicroserviceInterfaces.BENS, old_env_bens)
        Application.put_env(:explorer, Explorer.MicroserviceInterfaces.Metadata, old_env_metadata)
        Application.put_env(:tesla, :adapter, Explorer.Mock.TeslaAdapter)
        Bypass.down(bypass)
      end)

      Bypass.expect_once(bypass, "POST", "api/v1/addresses:batch_resolve", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["protocols"] == "ens"

        Conn.resp(
          conn,
          200,
          Jason.encode!(%{
            "names" => %{
              to_string(address) => "test.eth"
            }
          })
        )
      end)

      Bypass.expect_once(bypass, "GET", "api/v1/metadata", fn conn ->
        Conn.resp(
          conn,
          200,
          Jason.encode!(%{
            "addresses" => %{
              to_string(address) => %{
                "tags" => [
                  %{
                    "name" => "Proposer Fee Recipient",
                    "ordinal" => 0,
                    "slug" => "proposer-fee-recipient",
                    "tagType" => "generic",
                    "meta" => "{\"styles\":\"danger_high\"}"
                  }
                ]
              }
            }
          })
        )
      end)

      request = get(conn, "/api/v2/addresses/#{address.hash}/logs")

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 1
      assert response["next_page_params"] == nil

      compare_item(log, Enum.at(response["items"], 0))

      log = Enum.at(response["items"], 0)
      assert log["address"]["ens_domain_name"] == "test.eth"
    end

    test "logs can be filtered by topic", %{conn: conn} do
      address = insert(:address)

      for x <- 0..20 do
        transaction =
          :transaction
          |> insert()
          |> with_block()

        insert(:log,
          transaction: transaction,
          index: x,
          block: transaction.block,
          block_number: transaction.block_number,
          address: address
        )
      end

      transaction =
        :transaction
        |> insert()
        |> with_block()

      log =
        insert(:log,
          transaction: transaction,
          block: transaction.block,
          block_number: transaction.block_number,
          address: address,
          first_topic: TestHelper.topic(@first_topic_hex_string_1)
        )

      request = get(conn, "/api/v2/addresses/#{address.hash}/logs?topic=#{@first_topic_hex_string_1}")
      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 1
      assert response["next_page_params"] == nil

      compare_item(log, Enum.at(response["items"], 0))
    end

    test "log could be decoded via verified implementation", %{conn: conn} do
      address = insert(:contract_address)

      contract_address = insert(:contract_address)

      smart_contract =
        insert(:smart_contract,
          address_hash: contract_address.hash,
          abi: [
            %{
              "name" => "OptionSettled",
              "type" => "event",
              "inputs" => [
                %{"name" => "accountId", "type" => "uint256", "indexed" => true, "internalType" => "uint256"},
                %{"name" => "option", "type" => "address", "indexed" => false, "internalType" => "address"},
                %{"name" => "subId", "type" => "uint256", "indexed" => false, "internalType" => "uint256"},
                %{"name" => "amount", "type" => "int256", "indexed" => false, "internalType" => "int256"},
                %{"name" => "value", "type" => "int256", "indexed" => false, "internalType" => "int256"}
              ],
              "anonymous" => false
            }
          ]
        )

      topic1_bytes = ExKeccak.hash_256("OptionSettled(uint256,address,uint256,int256,int256)")
      topic1 = "0x" <> Base.encode16(topic1_bytes, case: :lower)
      topic2 = "0x0000000000000000000000000000000000000000000000000000000000005d19"

      log_data =
        "0x000000000000000000000000aeb81cbe6b19ceeb0dbe0d230cffe35bb40a13a700000000000000000000000000000000000000000000045d964b80006597b700fffffffffffffffffffffffffffffffffffffffffffffffffe55aca2c2f40000ffffffffffffffffffffffffffffffffffffffffffffffe3a8289da3d7a13ef2"

      transaction = :transaction |> insert() |> with_block()

      log =
        insert(:log,
          transaction: transaction,
          first_topic: TestHelper.topic(topic1),
          second_topic: TestHelper.topic(topic2),
          third_topic: nil,
          fourth_topic: nil,
          data: log_data,
          address: address
        )

      insert(:proxy_implementation,
        proxy_address_hash: address.hash,
        proxy_type: "eip1167",
        address_hashes: [smart_contract.address_hash],
        names: ["Test"]
      )

      request = get(conn, "/api/v2/addresses/#{address.hash}/logs")

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 1
      assert response["next_page_params"] == nil
      log_from_api = Enum.at(response["items"], 0)
      compare_item(log, log_from_api)
      assert not is_nil(log_from_api["decoded"])

      assert log_from_api["decoded"] == %{
               "method_call" =>
                 "OptionSettled(uint256 indexed accountId, address option, uint256 subId, int256 amount, int256 value)",
               "method_id" => "d20a68b2",
               "parameters" => [
                 %{
                   "indexed" => true,
                   "name" => "accountId",
                   "type" => "uint256",
                   "value" => "23833"
                 },
                 %{
                   "indexed" => false,
                   "name" => "option",
                   "type" => "address",
                   "value" => Address.checksum("0xAeB81cbe6b19CeEB0dBE0d230CFFE35Bb40a13a7")
                 },
                 %{
                   "indexed" => false,
                   "name" => "subId",
                   "type" => "uint256",
                   "value" => "20615843020801704441600"
                 },
                 %{
                   "indexed" => false,
                   "name" => "amount",
                   "type" => "int256",
                   "value" => "-120000000000000000"
                 },
                 %{
                   "indexed" => false,
                   "name" => "value",
                   "type" => "int256",
                   "value" => "-522838470013113778446"
                 }
               ]
             }
    end

    test "test corner case, when preload functions face absent smart contract", %{conn: conn} do
      address = insert(:contract_address)

      contract_address = insert(:contract_address)

      topic1_bytes = ExKeccak.hash_256("OptionSettled(uint256,address,uint256,int256,int256)")
      topic1 = "0x" <> Base.encode16(topic1_bytes, case: :lower)
      topic2 = "0x0000000000000000000000000000000000000000000000000000000000005d19"

      log_data =
        "0x000000000000000000000000aeb81cbe6b19ceeb0dbe0d230cffe35bb40a13a700000000000000000000000000000000000000000000045d964b80006597b700fffffffffffffffffffffffffffffffffffffffffffffffffe55aca2c2f40000ffffffffffffffffffffffffffffffffffffffffffffffe3a8289da3d7a13ef2"

      transaction = :transaction |> insert() |> with_block()

      log =
        insert(:log,
          transaction: transaction,
          first_topic: TestHelper.topic(topic1),
          second_topic: TestHelper.topic(topic2),
          third_topic: nil,
          fourth_topic: nil,
          data: log_data,
          address: address
        )

      insert(:proxy_implementation,
        proxy_address_hash: address.hash,
        proxy_type: "eip1167",
        address_hashes: [contract_address.hash],
        names: ["Test"]
      )

      request = get(conn, "/api/v2/addresses/#{address.hash}/logs")

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 1
      assert response["next_page_params"] == nil
      log_from_api = Enum.at(response["items"], 0)

      compare_item(log, log_from_api)
    end

    test "ignore logs without topics when trying to decode with sig provider", %{conn: conn} do
      bypass = Bypass.open()

      Application.put_env(:tesla, :adapter, Tesla.Adapter.Mint)

      old_env_sig_provider = Application.get_env(:explorer, Explorer.SmartContract.SigProviderInterface)

      Application.put_env(:explorer, Explorer.SmartContract.SigProviderInterface,
        enabled: true,
        service_url: "http://localhost:#{bypass.port}"
      )

      on_exit(fn ->
        Application.put_env(:explorer, Explorer.SmartContract.SigProviderInterface, old_env_sig_provider)
        Application.put_env(:tesla, :adapter, Explorer.Mock.TeslaAdapter)
      end)

      address = insert(:contract_address)

      log_data =
        "0x000000000000000000000000aeb81cbe6b19ceeb0dbe0d230cffe35bb40a13a700000000000000000000000000000000000000000000045d964b80006597b700fffffffffffffffffffffffffffffffffffffffffffffffffe55aca2c2f40000ffffffffffffffffffffffffffffffffffffffffffffffe3a8289da3d7a13ef2"

      transaction = :transaction |> insert() |> with_block()

      insert(:log,
        transaction: transaction,
        first_topic: nil,
        second_topic: nil,
        third_topic: nil,
        fourth_topic: nil,
        data: log_data,
        address: address
      )

      insert(:log,
        transaction: transaction,
        first_topic: TestHelper.topic("0x0000000000000000000000000000000000000000000000000000000000005d19"),
        second_topic: nil,
        third_topic: nil,
        fourth_topic: nil,
        data: log_data,
        address: address
      )

      # cspell:disable
      Bypass.expect_once(bypass, "POST", "/api/v1/abi/events%3Abatch-get", fn conn ->
        # cspell:enable
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        body = Jason.decode!(body)
        assert Enum.count(body["requests"]) == 1

        Conn.resp(conn, 200, Jason.encode!([]))
      end)

      request = get(conn, "/api/v2/addresses/#{address.hash}/logs")

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 2

      Bypass.down(bypass)
    end
  end

  describe "/addresses/{address_hash}/tokens" do
    test "get token balances with ok reputation", %{conn: conn} do
      init_value = Application.get_env(:block_scout_web, :hide_scam_addresses)
      Application.put_env(:block_scout_web, :hide_scam_addresses, true)
      on_exit(fn -> Application.put_env(:block_scout_web, :hide_scam_addresses, init_value) end)

      address = insert(:address)

      insert(:address_current_token_balance_with_token_id_and_fixed_token_type,
        address: address,
        token_type: "ERC-1155",
        token_id: Enum.random(1..100_000)
      )

      request = conn |> put_req_cookie("show_scam_tokens", "true") |> get("/api/v2/addresses/#{address.hash}/tokens")
      response = json_response(request, 200)

      assert List.first(response["items"])["token"]["reputation"] == "ok"

      assert response == conn |> get("/api/v2/addresses/#{address.hash}/tokens") |> json_response(200)
    end

    test "get token balances with scam reputation", %{conn: conn} do
      init_value = Application.get_env(:block_scout_web, :hide_scam_addresses)
      Application.put_env(:block_scout_web, :hide_scam_addresses, true)
      on_exit(fn -> Application.put_env(:block_scout_web, :hide_scam_addresses, init_value) end)

      address = insert(:address)

      ctbs_erc_1155 =
        insert(:address_current_token_balance_with_token_id_and_fixed_token_type,
          address: address,
          token_type: "ERC-1155",
          token_id: Enum.random(1..100_000)
        )

      insert(:scam_badge_to_address, address_hash: ctbs_erc_1155.token_contract_address_hash)

      request = conn |> put_req_cookie("show_scam_tokens", "true") |> get("/api/v2/addresses/#{address.hash}/tokens")
      response = json_response(request, 200)

      assert List.first(response["items"])["token"]["reputation"] == "scam"

      request = conn |> get("/api/v2/addresses/#{address.hash}/tokens")
      response = json_response(request, 200)

      assert response["items"] == []
    end

    test "get token balances with ok reputation with hide_scam_addresses=false", %{conn: conn} do
      init_value = Application.get_env(:block_scout_web, :hide_scam_addresses)
      Application.put_env(:block_scout_web, :hide_scam_addresses, false)
      on_exit(fn -> Application.put_env(:block_scout_web, :hide_scam_addresses, init_value) end)

      address = insert(:address)

      insert(:address_current_token_balance_with_token_id_and_fixed_token_type,
        address: address,
        token_type: "ERC-1155",
        token_id: Enum.random(1..100_000)
      )

      request = conn |> get("/api/v2/addresses/#{address.hash}/tokens")
      response = json_response(request, 200)

      assert List.first(response["items"])["token"]["reputation"] == "ok"
    end

    test "get token balances with scam reputation with hide_scam_addresses=false", %{conn: conn} do
      init_value = Application.get_env(:block_scout_web, :hide_scam_addresses)
      Application.put_env(:block_scout_web, :hide_scam_addresses, false)
      on_exit(fn -> Application.put_env(:block_scout_web, :hide_scam_addresses, init_value) end)

      address = insert(:address)

      ctbs_erc_1155 =
        insert(:address_current_token_balance_with_token_id_and_fixed_token_type,
          address: address,
          token_type: "ERC-1155",
          token_id: Enum.random(1..100_000)
        )

      insert(:scam_badge_to_address, address_hash: ctbs_erc_1155.token_contract_address_hash)

      request = conn |> get("/api/v2/addresses/#{address.hash}/tokens")
      response = json_response(request, 200)

      assert List.first(response["items"])["token"]["reputation"] == "ok"
    end

    test "get empty list on non existing address", %{conn: conn} do
      address = build(:address)

      request = get(conn, "/api/v2/addresses/#{address.hash}/tokens")

      response = json_response(request, 200)
      assert %{"items" => [], "next_page_params" => nil} = response
    end

    test "get 422 on invalid address", %{conn: conn} do
      request = get(conn, "/api/v2/addresses/0x/tokens")

      json_response = json_response(request, 422)

      assert %{
               "errors" => [
                 %{
                   "detail" => "Invalid format. Expected ~r/^0x([A-Fa-f0-9]{40})$/",
                   "source" => %{"pointer" => "/address_hash_param"},
                   "title" => "Invalid value"
                 }
               ]
             } = json_response
    end

    test "get tokens", %{conn: conn} do
      initial_value = :persistent_term.get(:market_token_fetcher_enabled, false)
      :persistent_term.put(:market_token_fetcher_enabled, true)

      on_exit(fn ->
        :persistent_term.put(:market_token_fetcher_enabled, initial_value)
      end)

      address = insert(:address)

      ctbs_erc_20 =
        for _ <- 0..50 do
          insert(:address_current_token_balance_with_token_id_and_fixed_token_type,
            address: address,
            token_type: "ERC-20",
            token_id: nil
          )
          |> Repo.preload([:token])
        end
        |> Enum.sort_by(fn x -> Decimal.to_float(Decimal.mult(x.value, x.token.fiat_value)) end, :asc)

      ctbs_erc_721 =
        for _ <- 0..50 do
          insert(:address_current_token_balance_with_token_id_and_fixed_token_type,
            address: address,
            token_type: "ERC-721",
            token_id: nil
          )
          |> Repo.preload([:token])
        end
        |> Enum.sort_by(fn x -> Decimal.to_integer(x.value) end, :asc)

      ctbs_erc_1155 =
        for _ <- 0..50 do
          insert(:address_current_token_balance_with_token_id_and_fixed_token_type,
            address: address,
            token_type: "ERC-1155",
            token_id: Enum.random(1..100_000)
          )
          |> Repo.preload([:token])
        end
        |> Enum.sort_by(fn x -> Decimal.to_integer(x.value) end, :asc)

      filter = %{"type" => "ERC-20"}
      request = get(conn, "/api/v2/addresses/#{address.hash}/tokens", filter)
      assert response = json_response(request, 200)

      request_2nd_page =
        get(conn, "/api/v2/addresses/#{address.hash}/tokens", Map.merge(response["next_page_params"], filter))

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, ctbs_erc_20)

      filter = %{"type" => "ERC-721"}
      request = get(conn, "/api/v2/addresses/#{address.hash}/tokens", filter)
      assert response = json_response(request, 200)

      request_2nd_page =
        get(conn, "/api/v2/addresses/#{address.hash}/tokens", Map.merge(response["next_page_params"], filter))

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, ctbs_erc_721)

      filter = %{"type" => "ERC-1155"}
      request = get(conn, "/api/v2/addresses/#{address.hash}/tokens", filter)
      assert response = json_response(request, 200)

      request_2nd_page =
        get(conn, "/api/v2/addresses/#{address.hash}/tokens", Map.merge(response["next_page_params"], filter))

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, ctbs_erc_1155)

      # Test multiple token types (the fix for the original issue)
      filter = %{"type" => "ERC-721,ERC-1155"}
      request = get(conn, "/api/v2/addresses/#{address.hash}/tokens", filter)
      assert response = json_response(request, 200)

      # Verify we get tokens from both types
      response_token_types =
        response["items"]
        |> Enum.map(fn item -> item["token"]["type"] end)
        |> Enum.uniq()
        |> Enum.sort()

      assert response_token_types == ["ERC-1155", "ERC-721"]
    end
  end

  describe "checks Indexer.Fetcher.OnDemand.TokenBalance" do
    setup do
      Supervisor.terminate_child(Explorer.Supervisor, Explorer.Chain.Cache.BlockNumber.child_id())
      Supervisor.restart_child(Explorer.Supervisor, Explorer.Chain.Cache.BlockNumber.child_id())
      old_env = Application.get_env(:indexer, Indexer.Fetcher.OnDemand.TokenBalance)
      configuration = Application.get_env(:indexer, Indexer.Fetcher.OnDemand.TokenBalance.Supervisor)
      Application.put_env(:indexer, Indexer.Fetcher.OnDemand.TokenBalance.Supervisor, disabled?: false)
      Indexer.Fetcher.OnDemand.TokenBalance.Supervisor.Case.start_supervised!()

      Application.put_env(
        :indexer,
        Indexer.Fetcher.OnDemand.TokenBalance,
        Keyword.put(old_env, :fallback_threshold_in_blocks, 0)
      )

      on_exit(fn ->
        Application.put_env(:indexer, Indexer.Fetcher.OnDemand.TokenBalance.Supervisor, configuration)
        Application.put_env(:indexer, Indexer.Fetcher.OnDemand.TokenBalance, old_env)
      end)
    end

    test "Indexer.Fetcher.OnDemand.TokenBalance broadcasts only updated balances", %{conn: conn} do
      address = insert(:address)

      ctbs_erc_20 =
        for i <- 0..1 do
          ctb =
            insert(:address_current_token_balance_with_token_id_and_fixed_token_type,
              address: address,
              token_type: "ERC-20",
              token_id: nil
            )

          {to_string(ctb.token_contract_address_hash),
           Decimal.to_integer(ctb.value) + if(rem(i, 2) == 0, do: 1, else: 0)}
        end
        |> Enum.into(%{})

      ctbs_erc_721 =
        for i <- 0..1 do
          ctb =
            insert(:address_current_token_balance_with_token_id_and_fixed_token_type,
              address: address,
              token_type: "ERC-721",
              token_id: nil
            )

          {to_string(ctb.token_contract_address_hash),
           Decimal.to_integer(ctb.value) + if(rem(i, 2) == 0, do: 1, else: 0)}
        end
        |> Enum.into(%{})

      other_balances = Map.merge(ctbs_erc_20, ctbs_erc_721)

      balances_erc_1155 =
        for i <- 0..1 do
          ctb =
            insert(:address_current_token_balance_with_token_id_and_fixed_token_type,
              address: address,
              token_type: "ERC-1155",
              token_id: Enum.random(1..100_000)
            )

          {{to_string(ctb.token_contract_address_hash), to_string(ctb.token_id)},
           Decimal.to_integer(ctb.value) + if(rem(i, 2) == 0, do: 1, else: 0)}
        end
        |> Enum.into(%{})

      block_number_hex = "0x" <> (Integer.to_string(insert(:block).number, 16) |> String.upcase())

      expect(EthereumJSONRPC.Mox, :json_rpc, fn [
                                                  %{
                                                    id: id_1,
                                                    jsonrpc: "2.0",
                                                    method: "eth_call",
                                                    params: [
                                                      %{
                                                        data: "0x70a08231" <> request_1,
                                                        to: contract_address_1
                                                      },
                                                      ^block_number_hex
                                                    ]
                                                  },
                                                  %{
                                                    id: id_2,
                                                    jsonrpc: "2.0",
                                                    method: "eth_call",
                                                    params: [
                                                      %{
                                                        data: "0x70a08231" <> request_2,
                                                        to: contract_address_2
                                                      },
                                                      ^block_number_hex
                                                    ]
                                                  },
                                                  %{
                                                    id: id_3,
                                                    jsonrpc: "2.0",
                                                    method: "eth_call",
                                                    params: [
                                                      %{
                                                        data: "0x70a08231" <> request_3,
                                                        to: contract_address_3
                                                      },
                                                      ^block_number_hex
                                                    ]
                                                  },
                                                  %{
                                                    id: id_4,
                                                    jsonrpc: "2.0",
                                                    method: "eth_call",
                                                    params: [
                                                      %{
                                                        data: "0x70a08231" <> request_4,
                                                        to: contract_address_4
                                                      },
                                                      ^block_number_hex
                                                    ]
                                                  },
                                                  %{
                                                    id: id_5,
                                                    jsonrpc: "2.0",
                                                    method: "eth_call",
                                                    params: [
                                                      %{
                                                        data: "0x00fdd58e" <> request_5,
                                                        to: contract_address_5
                                                      },
                                                      ^block_number_hex
                                                    ]
                                                  },
                                                  %{
                                                    id: id_6,
                                                    jsonrpc: "2.0",
                                                    method: "eth_call",
                                                    params: [
                                                      %{
                                                        data: "0x00fdd58e" <> request_6,
                                                        to: contract_address_6
                                                      },
                                                      ^block_number_hex
                                                    ]
                                                  }
                                                ],
                                                _options ->
        types_list = [:address]

        assert request_1 |> Base.decode16!(case: :lower) |> TypeDecoder.decode_raw(types_list) == [address.hash.bytes]

        assert request_2 |> Base.decode16!(case: :lower) |> TypeDecoder.decode_raw(types_list) == [address.hash.bytes]

        assert request_3 |> Base.decode16!(case: :lower) |> TypeDecoder.decode_raw(types_list) == [address.hash.bytes]

        assert request_4 |> Base.decode16!(case: :lower) |> TypeDecoder.decode_raw(types_list) == [address.hash.bytes]

        result_1 =
          other_balances[contract_address_1 |> String.downcase()]
          |> List.wrap()
          |> TypeEncoder.encode_raw([{:uint, 256}], :standard)
          |> Base.encode16(case: :lower)

        result_2 =
          other_balances[contract_address_2 |> String.downcase()]
          |> List.wrap()
          |> TypeEncoder.encode_raw([{:uint, 256}], :standard)
          |> Base.encode16(case: :lower)

        result_3 =
          other_balances[contract_address_3 |> String.downcase()]
          |> List.wrap()
          |> TypeEncoder.encode_raw([{:uint, 256}], :standard)
          |> Base.encode16(case: :lower)

        result_4 =
          other_balances[contract_address_4 |> String.downcase()]
          |> List.wrap()
          |> TypeEncoder.encode_raw([{:uint, 256}], :standard)
          |> Base.encode16(case: :lower)

        types_list = [:address, {:uint, 256}]

        [address_5, token_id_5] = request_5 |> Base.decode16!(case: :lower) |> TypeDecoder.decode_raw(types_list)

        assert address_5 == address.hash.bytes

        result_5 =
          balances_erc_1155[{contract_address_5 |> String.downcase(), to_string(token_id_5)}]
          |> List.wrap()
          |> TypeEncoder.encode_raw([{:uint, 256}], :standard)
          |> Base.encode16(case: :lower)

        [address_6, token_id_6] = request_6 |> Base.decode16!(case: :lower) |> TypeDecoder.decode_raw(types_list)

        assert address_6 == address.hash.bytes

        result_6 =
          balances_erc_1155[{contract_address_6 |> String.downcase(), to_string(token_id_6)}]
          |> List.wrap()
          |> TypeEncoder.encode_raw([{:uint, 256}], :standard)
          |> Base.encode16(case: :lower)

        {:ok,
         [
           %{
             id: id_1,
             jsonrpc: "2.0",
             result: "0x" <> result_1
           },
           %{
             id: id_2,
             jsonrpc: "2.0",
             result: "0x" <> result_2
           },
           %{
             id: id_3,
             jsonrpc: "2.0",
             result: "0x" <> result_3
           },
           %{
             id: id_4,
             jsonrpc: "2.0",
             result: "0x" <> result_4
           },
           %{
             id: id_5,
             jsonrpc: "2.0",
             result: "0x" <> result_5
           },
           %{
             id: id_6,
             jsonrpc: "2.0",
             result: "0x" <> result_6
           }
         ]}
      end)

      topic = "addresses:#{address.hash}"

      {:ok, _reply, _socket} =
        BlockScoutWeb.V2.UserSocket
        |> socket("no_id", %{})
        |> subscribe_and_join(topic)

      request = get(conn, "/api/v2/addresses/#{address.hash}/tokens")
      assert _response = json_response(request, 200)
      overflow = false

      assert_receive %Phoenix.Socket.Message{
                       payload: %{token_balances: [ctb_erc_20], overflow: ^overflow},
                       event: "updated_token_balances_erc_20",
                       topic: ^topic
                     },
                     :timer.seconds(1)

      assert_receive %Phoenix.Socket.Message{
                       payload: %{token_balances: [ctb_erc_721], overflow: ^overflow},
                       event: "updated_token_balances_erc_721",
                       topic: ^topic
                     },
                     :timer.seconds(1)

      assert_receive %Phoenix.Socket.Message{
                       payload: %{token_balances: [ctb_erc_1155], overflow: ^overflow},
                       event: "updated_token_balances_erc_1155",
                       topic: ^topic
                     },
                     :timer.seconds(1)

      assert Decimal.to_integer(ctb_erc_20["value"]) ==
               other_balances[ctb_erc_20["token"]["address_hash"] |> String.downcase()]

      assert Decimal.to_integer(ctb_erc_721["value"]) ==
               other_balances[ctb_erc_721["token"]["address_hash"] |> String.downcase()]

      assert Decimal.to_integer(ctb_erc_1155["value"]) ==
               balances_erc_1155[
                 {ctb_erc_1155["token"]["address_hash"] |> String.downcase(), to_string(ctb_erc_1155["token_id"])}
               ]
    end
  end

  describe "/addresses/{address_hash}/withdrawals" do
    test "get empty list on non existing address", %{conn: conn} do
      address = build(:address)

      request = get(conn, "/api/v2/addresses/#{address.hash}/withdrawals")
      response = json_response(request, 200)

      assert %{"items" => [], "next_page_params" => nil} = response
    end

    test "get 422 on invalid address", %{conn: conn} do
      request = get(conn, "/api/v2/addresses/0x/withdrawals")

      json_response = json_response(request, 422)

      assert %{
               "errors" => [
                 %{
                   "detail" => "Invalid format. Expected ~r/^0x([A-Fa-f0-9]{40})$/",
                   "source" => %{"pointer" => "/address_hash_param"},
                   "title" => "Invalid value"
                 }
               ]
             } = json_response
    end

    test "get withdrawals", %{conn: conn} do
      address = insert(:address, withdrawals: insert_list(51, :withdrawal))

      request = get(conn, "/api/v2/addresses/#{address.hash}/withdrawals")
      assert response = json_response(request, 200)

      request_2nd_page = get(conn, "/api/v2/addresses/#{address.hash}/withdrawals", response["next_page_params"])

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, address.withdrawals)
    end
  end

  describe "/addresses" do
    test "get empty list", %{conn: conn} do
      request = get(conn, "/api/v2/addresses")

      total_supply = to_string(Chain.total_supply())

      pattern_response = %{"items" => [], "next_page_params" => nil, "total_supply" => total_supply}
      response = json_response(request, 200)

      assert pattern_response["items"] == response["items"]
      assert pattern_response["next_page_params"] == response["next_page_params"]
      assert pattern_response["total_supply"] == response["total_supply"]
    end

    test "check pagination", %{conn: conn} do
      addresses =
        for i <- 0..50 do
          insert(:address, nonce: i, fetched_coin_balance: i + 1)
        end

      request = get(conn, "/api/v2/addresses")
      assert response = json_response(request, 200)
      assert not is_nil(response["next_page_params"])
      request_2nd_page = get(conn, "/api/v2/addresses", response["next_page_params"])

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, addresses)

      assert Enum.at(response["items"], 0)["coin_balance"] ==
               to_string(Enum.at(addresses, 50).fetched_coin_balance.value)
    end

    test "check nil", %{conn: conn} do
      address = insert(:address, transactions_count: 2, fetched_coin_balance: 1)

      request = get(conn, "/api/v2/addresses")
      response = json_response(request, 200)
      assert %{"items" => [address_json], "next_page_params" => nil} = response

      compare_item(address, address_json)
    end

    test "check smart contract preload", %{conn: conn} do
      smart_contract = insert(:smart_contract, address_hash: insert(:contract_address, fetched_coin_balance: 1).hash)

      request = get(conn, "/api/v2/addresses")
      response = json_response(request, 200)
      assert %{"items" => [address]} = response

      assert String.downcase(address["hash"]) == to_string(smart_contract.address_hash)
      assert address["is_contract"] == true
      assert address["is_verified"] == true
    end

    test "check sorting by balance asc", %{conn: conn} do
      addresses =
        for i <- 0..50 do
          insert(:address, nonce: i, fetched_coin_balance: i + 1, transactions_count: 100 - i)
        end

      sort_options = %{"sort" => "balance", "order" => "asc"}
      request = get(conn, "/api/v2/addresses", sort_options)
      assert response = json_response(request, 200)
      assert not is_nil(response["next_page_params"])

      request_2nd_page = get(conn, "/api/v2/addresses", Map.merge(response["next_page_params"], sort_options))
      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(
        response,
        response_2nd_page,
        Enum.sort_by(addresses, &Decimal.to_integer(&1.fetched_coin_balance.value), :desc)
      )
    end

    test "check sorting by transactions count asc", %{conn: conn} do
      addresses =
        for i <- 0..50 do
          insert(:address, nonce: i, transactions_count: i + 1, fetched_coin_balance: 100 - i)
        end

      sort_options = %{"sort" => "transactions_count", "order" => "asc"}
      request = get(conn, "/api/v2/addresses", sort_options)
      assert response = json_response(request, 200)
      assert not is_nil(response["next_page_params"])

      request_2nd_page = get(conn, "/api/v2/addresses", Map.merge(response["next_page_params"], sort_options))
      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, Enum.sort_by(addresses, & &1.transactions_count, :desc))
    end

    test "check sorting by balance desc", %{conn: conn} do
      addresses =
        for i <- 0..50 do
          insert(:address, nonce: i, fetched_coin_balance: i + 1, transactions_count: 100 - i)
        end

      sort_options = %{"sort" => "balance", "order" => "desc"}
      request = get(conn, "/api/v2/addresses", sort_options)
      assert response = json_response(request, 200)
      assert not is_nil(response["next_page_params"])

      request_2nd_page = get(conn, "/api/v2/addresses", Map.merge(response["next_page_params"], sort_options))
      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(
        response,
        response_2nd_page,
        Enum.sort_by(addresses, &Decimal.to_integer(&1.fetched_coin_balance.value), :asc)
      )
    end

    test "check sorting by transactions count desc", %{conn: conn} do
      addresses =
        for i <- 0..50 do
          insert(:address, nonce: i, transactions_count: i + 1, fetched_coin_balance: 100 - i)
        end

      sort_options = %{"sort" => "transactions_count", "order" => "desc"}
      request = get(conn, "/api/v2/addresses", sort_options)
      assert response = json_response(request, 200)
      assert not is_nil(response["next_page_params"])

      request_2nd_page = get(conn, "/api/v2/addresses", Map.merge(response["next_page_params"], sort_options))
      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, Enum.sort_by(addresses, & &1.transactions_count, :asc))
    end
  end

  describe "/addresses/{address_hash}/tabs-counters" do
    test "get 200 on non existing address", %{conn: conn} do
      address = build(:address)

      request = get(conn, "/api/v2/addresses/#{address.hash}/tabs-counters")
      response = json_response(request, 200)

      assert %{
               "validations_count" => 0,
               "transactions_count" => 0,
               "token_transfers_count" => 0,
               "token_balances_count" => 0,
               "logs_count" => 0,
               "withdrawals_count" => 0,
               "internal_transactions_count" => 0,
               "celo_election_rewards_count" => 0
             } = response
    end

    test "get 422 on invalid address", %{conn: conn} do
      request = get(conn, "/api/v2/addresses/0x/tabs-counters")

      json_response = json_response(request, 422)

      assert %{
               "errors" => [
                 %{
                   "detail" => "Invalid format. Expected ~r/^0x([A-Fa-f0-9]{40})$/",
                   "source" => %{"pointer" => "/address_hash_param"},
                   "title" => "Invalid value"
                 }
               ]
             } = json_response
    end

    test "get counters with 0s", %{conn: conn} do
      address = insert(:address)

      request = get(conn, "/api/v2/addresses/#{address.hash}/tabs-counters")
      response = json_response(request, 200)

      assert %{
               "validations_count" => 0,
               "transactions_count" => 0,
               "token_transfers_count" => 0,
               "token_balances_count" => 0,
               "logs_count" => 0,
               "withdrawals_count" => 0,
               "internal_transactions_count" => 0
             } = response
    end

    test "get counters and check that cache works", %{conn: conn} do
      address = insert(:address, withdrawals: insert_list(60, :withdrawal))

      insert(:transaction, from_address: address) |> with_block()
      insert(:transaction, to_address: address) |> with_block()
      another_transaction = insert(:transaction) |> with_block()

      insert(:token_transfer,
        from_address: address,
        transaction: another_transaction,
        block: another_transaction.block,
        block_number: another_transaction.block_number
      )

      insert(:token_transfer,
        to_address: address,
        transaction: another_transaction,
        block: another_transaction.block,
        block_number: another_transaction.block_number
      )

      insert(:block, miner: address)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      for x <- 1..2 do
        insert(:internal_transaction,
          transaction: transaction,
          index: x,
          block_number: transaction.block_number,
          transaction_index: transaction.index,
          block_hash: transaction.block_hash,
          to_address: address
        )
      end

      for _ <- 0..60 do
        insert(:address_current_token_balance_with_token_id, address: address)
      end

      for x <- 0..60 do
        transaction =
          :transaction
          |> insert()
          |> with_block()

        insert(:log,
          transaction: transaction,
          index: x,
          block: transaction.block,
          block_number: transaction.block_number,
          address: address
        )
      end

      request = get(conn, "/api/v2/addresses/#{address.hash}/tabs-counters")
      response = json_response(request, 200)

      assert %{
               "validations_count" => 1,
               "transactions_count" => 2,
               "token_transfers_count" => 2,
               "token_balances_count" => 51,
               "logs_count" => 51,
               "withdrawals_count" => 51,
               "internal_transactions_count" => 2
             } = response

      for x <- 3..4 do
        insert(:internal_transaction,
          transaction: transaction,
          index: x,
          block_number: transaction.block_number,
          transaction_index: transaction.index,
          block_hash: transaction.block_hash,
          from_address: address
        )
      end

      request = get(conn, "/api/v2/addresses/#{address.hash}/tabs-counters")
      response = json_response(request, 200)

      assert %{
               "validations_count" => 1,
               "transactions_count" => 2,
               "token_transfers_count" => 2,
               "token_balances_count" => 51,
               "logs_count" => 51,
               "withdrawals_count" => 51,
               "internal_transactions_count" => 2
             } = response
    end

    test "check counters cache ttl", %{conn: conn} do
      address = insert(:address, withdrawals: insert_list(60, :withdrawal))

      insert(:transaction, from_address: address) |> with_block()
      insert(:transaction, to_address: address) |> with_block()
      another_transaction = insert(:transaction) |> with_block()

      insert(:token_transfer,
        from_address: address,
        transaction: another_transaction,
        block: another_transaction.block,
        block_number: another_transaction.block_number
      )

      insert(:token_transfer,
        to_address: address,
        transaction: another_transaction,
        block: another_transaction.block,
        block_number: another_transaction.block_number
      )

      insert(:block, miner: address)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      for x <- 1..2 do
        insert(:internal_transaction,
          transaction: transaction,
          index: x,
          block_number: transaction.block_number,
          transaction_index: transaction.index,
          block_hash: transaction.block_hash,
          from_address: address
        )
      end

      for _ <- 0..60 do
        insert(:address_current_token_balance_with_token_id, address: address)
      end

      for x <- 0..60 do
        transaction =
          :transaction
          |> insert()
          |> with_block()

        insert(:log,
          transaction: transaction,
          index: x,
          block: transaction.block,
          block_number: transaction.block_number,
          address: address
        )
      end

      request = get(conn, "/api/v2/addresses/#{address.hash}/tabs-counters")
      response = json_response(request, 200)

      assert %{
               "validations_count" => 1,
               "transactions_count" => 2,
               "token_transfers_count" => 2,
               "token_balances_count" => 51,
               "logs_count" => 51,
               "withdrawals_count" => 51,
               "internal_transactions_count" => 2
             } = response

      old_env = Application.get_env(:explorer, Explorer.Chain.Cache.Counters.AddressTabsElementsCount)
      Application.put_env(:explorer, Explorer.Chain.Cache.Counters.AddressTabsElementsCount, ttl: 200)
      :timer.sleep(200)

      for x <- 3..4 do
        insert(:internal_transaction,
          transaction: transaction,
          index: x,
          block_number: transaction.block_number,
          transaction_index: transaction.index,
          block_hash: transaction.block_hash,
          from_address: address
        )
      end

      insert(:transaction, from_address: address) |> with_block()
      insert(:transaction, to_address: address) |> with_block()

      request = get(conn, "/api/v2/addresses/#{address.hash}/tabs-counters")
      response = json_response(request, 200)

      assert %{
               "validations_count" => 1,
               "transactions_count" => 4,
               "token_transfers_count" => 2,
               "token_balances_count" => 51,
               "logs_count" => 51,
               "withdrawals_count" => 51,
               "internal_transactions_count" => 4
             } = response

      Application.put_env(:explorer, Explorer.Chain.Cache.Counters.AddressTabsElementsCount, old_env)
    end
  end

  describe "/addresses/{address_hash}/nft" do
    setup do
      {:ok, endpoint: &"/api/v2/addresses/#{&1}/nft"}
    end

    test "get 200 on non existing address", %{conn: conn, endpoint: endpoint} do
      address = build(:address)

      request = get(conn, endpoint.(address.hash))
      response = json_response(request, 200)

      assert %{"items" => [], "next_page_params" => nil} = response
    end

    test "get 422 on invalid address", %{conn: conn, endpoint: endpoint} do
      request = get(conn, endpoint.("0x"))

      json_response = json_response(request, 422)

      assert %{
               "errors" => [
                 %{
                   "detail" => "Invalid format. Expected ~r/^0x([A-Fa-f0-9]{40})$/",
                   "source" => %{"pointer" => "/address_hash_param"},
                   "title" => "Invalid value"
                 }
               ]
             } = json_response
    end

    test "get token with ok reputation", %{conn: conn, endpoint: endpoint} do
      init_value = Application.get_env(:block_scout_web, :hide_scam_addresses)
      Application.put_env(:block_scout_web, :hide_scam_addresses, true)
      on_exit(fn -> Application.put_env(:block_scout_web, :hide_scam_addresses, init_value) end)

      address = insert(:address)

      # --- ERC-721 ---
      erc_721_token = insert(:token, type: "ERC-721")

      insert(:token_instance,
        owner_address_hash: address.hash,
        token_contract_address_hash: erc_721_token.contract_address_hash
      )

      # --- ERC-1155 ---

      token = insert(:token, type: "ERC-1155")

      ti =
        insert(:token_instance,
          token_contract_address_hash: token.contract_address_hash
        )
        |> Repo.preload([:token])

      insert(:address_current_token_balance_with_token_id_and_fixed_token_type,
        address: address,
        token_type: "ERC-1155",
        token_id: ti.token_id,
        token_contract_address_hash: token.contract_address_hash
      )

      # --- ERC-404 ---
      token = insert(:token, type: "ERC-404")

      ti =
        insert(:token_instance,
          token_contract_address_hash: token.contract_address_hash
        )
        |> Repo.preload([:token])

      insert(:address_current_token_balance_with_token_id_and_fixed_token_type,
        address: address,
        token_type: "ERC-404",
        token_id: ti.token_id,
        token_contract_address_hash: token.contract_address_hash
      )

      request =
        conn |> put_req_cookie("show_scam_tokens", "true") |> get(endpoint.(address.hash), %{"type" => "ERC-721"})

      response = json_response(request, 200)

      assert List.first(response["items"])["token"]["reputation"] == "ok"

      assert response == conn |> get(endpoint.(address.hash), %{"type" => "ERC-721"}) |> json_response(200)

      request =
        conn |> put_req_cookie("show_scam_tokens", "true") |> get(endpoint.(address.hash), %{"type" => "ERC-1155"})

      response = json_response(request, 200)

      assert List.first(response["items"])["token"]["reputation"] == "ok"

      assert response == conn |> get(endpoint.(address.hash), %{"type" => "ERC-1155"}) |> json_response(200)

      request =
        conn |> put_req_cookie("show_scam_tokens", "true") |> get(endpoint.(address.hash), %{"type" => "ERC-404"})

      response = json_response(request, 200)

      assert List.first(response["items"])["token"]["reputation"] == "ok"

      assert response == conn |> get(endpoint.(address.hash), %{"type" => "ERC-404"}) |> json_response(200)
    end

    test "get token with scam reputation", %{conn: conn, endpoint: endpoint} do
      init_value = Application.get_env(:block_scout_web, :hide_scam_addresses)
      Application.put_env(:block_scout_web, :hide_scam_addresses, true)
      on_exit(fn -> Application.put_env(:block_scout_web, :hide_scam_addresses, init_value) end)
      address = insert(:address)
      # --- ERC-721 ---
      erc_721_token = insert(:token, type: "ERC-721")

      insert(:scam_badge_to_address, address_hash: erc_721_token.contract_address_hash)

      insert(:token_instance,
        owner_address_hash: address.hash,
        token_contract_address_hash: erc_721_token.contract_address_hash
      )

      # --- ERC-1155 ---
      token = insert(:token, type: "ERC-1155")

      insert(:scam_badge_to_address, address_hash: token.contract_address_hash)

      ti =
        insert(:token_instance,
          token_contract_address_hash: token.contract_address_hash
        )
        |> Repo.preload([:token])

      insert(:address_current_token_balance_with_token_id_and_fixed_token_type,
        address: address,
        token_type: "ERC-1155",
        token_id: ti.token_id,
        token_contract_address_hash: token.contract_address_hash
      )

      # --- ERC-404 ---
      token = insert(:token, type: "ERC-404")
      insert(:scam_badge_to_address, address_hash: token.contract_address_hash)

      ti =
        insert(:token_instance,
          token_contract_address_hash: token.contract_address_hash
        )
        |> Repo.preload([:token])

      insert(:address_current_token_balance_with_token_id_and_fixed_token_type,
        address: address,
        token_type: "ERC-404",
        token_id: ti.token_id,
        token_contract_address_hash: token.contract_address_hash
      )

      request =
        conn |> put_req_cookie("show_scam_tokens", "true") |> get(endpoint.(address.hash), %{"type" => "ERC-721"})

      response = json_response(request, 200)

      assert List.first(response["items"])["token"]["reputation"] == "scam"

      request = conn |> get(endpoint.(address.hash), %{"type" => "ERC-721"})
      response = json_response(request, 200)

      assert response["items"] == []

      # --- ERC-1155 ---
      request =
        conn |> put_req_cookie("show_scam_tokens", "true") |> get(endpoint.(address.hash), %{"type" => "ERC-1155"})

      response = json_response(request, 200)

      assert List.first(response["items"])["token"]["reputation"] == "scam"

      request = conn |> get(endpoint.(address.hash), %{"type" => "ERC-1155"})
      response = json_response(request, 200)

      assert response["items"] == []

      # --- ERC-404 ---
      request =
        conn |> put_req_cookie("show_scam_tokens", "true") |> get(endpoint.(address.hash), %{"type" => "ERC-404"})

      response = json_response(request, 200)

      assert List.first(response["items"])["token"]["reputation"] == "scam"

      request = conn |> get(endpoint.(address.hash), %{"type" => "ERC-404"})
      response = json_response(request, 200)

      assert response["items"] == []
    end

    test "get token with ok reputation with hide_scam_addresses=false", %{conn: conn, endpoint: endpoint} do
      init_value = Application.get_env(:block_scout_web, :hide_scam_addresses)
      Application.put_env(:block_scout_web, :hide_scam_addresses, false)
      on_exit(fn -> Application.put_env(:block_scout_web, :hide_scam_addresses, init_value) end)

      address = insert(:address)
      # --- ERC-721 ---
      erc_721_token = insert(:token, type: "ERC-721")

      insert(:token_instance,
        owner_address_hash: address.hash,
        token_contract_address_hash: erc_721_token.contract_address_hash
      )

      # --- ERC-1155 ---
      token = insert(:token, type: "ERC-1155")

      ti =
        insert(:token_instance,
          token_contract_address_hash: token.contract_address_hash
        )
        |> Repo.preload([:token])

      insert(:address_current_token_balance_with_token_id_and_fixed_token_type,
        address: address,
        token_type: "ERC-1155",
        token_id: ti.token_id,
        token_contract_address_hash: token.contract_address_hash
      )

      # --- ERC-404 ---
      token = insert(:token, type: "ERC-404")

      ti =
        insert(:token_instance,
          token_contract_address_hash: token.contract_address_hash
        )
        |> Repo.preload([:token])

      insert(:address_current_token_balance_with_token_id_and_fixed_token_type,
        address: address,
        token_type: "ERC-404",
        token_id: ti.token_id,
        token_contract_address_hash: token.contract_address_hash
      )

      request = conn |> get(endpoint.(address.hash), %{"type" => "ERC-721"})
      response = json_response(request, 200)

      assert List.first(response["items"])["token"]["reputation"] == "ok"

      request = conn |> get(endpoint.(address.hash), %{"type" => "ERC-1155"})
      response = json_response(request, 200)

      assert List.first(response["items"])["token"]["reputation"] == "ok"

      request = conn |> get(endpoint.(address.hash), %{"type" => "ERC-404"})
      response = json_response(request, 200)

      assert List.first(response["items"])["token"]["reputation"] == "ok"
    end

    test "get token with scam reputation with hide_scam_addresses=false", %{conn: conn, endpoint: endpoint} do
      init_value = Application.get_env(:block_scout_web, :hide_scam_addresses)
      Application.put_env(:block_scout_web, :hide_scam_addresses, false)
      on_exit(fn -> Application.put_env(:block_scout_web, :hide_scam_addresses, init_value) end)

      address = insert(:address)
      # --- ERC-721 ---
      erc_721_token = insert(:token, type: "ERC-721")

      insert(:scam_badge_to_address, address_hash: erc_721_token.contract_address_hash)

      insert(:token_instance,
        owner_address_hash: address.hash,
        token_contract_address_hash: erc_721_token.contract_address_hash
      )

      # --- ERC-1155 ---
      token = insert(:token, type: "ERC-1155")

      insert(:scam_badge_to_address, address_hash: token.contract_address_hash)

      ti =
        insert(:token_instance,
          token_contract_address_hash: token.contract_address_hash
        )
        |> Repo.preload([:token])

      insert(:address_current_token_balance_with_token_id_and_fixed_token_type,
        address: address,
        token_type: "ERC-1155",
        token_id: ti.token_id,
        token_contract_address_hash: token.contract_address_hash
      )

      # --- ERC-404 ---
      token = insert(:token, type: "ERC-404")
      insert(:scam_badge_to_address, address_hash: token.contract_address_hash)

      ti =
        insert(:token_instance,
          token_contract_address_hash: token.contract_address_hash
        )
        |> Repo.preload([:token])

      insert(:address_current_token_balance_with_token_id_and_fixed_token_type,
        address: address,
        token_type: "ERC-404",
        token_id: ti.token_id,
        token_contract_address_hash: token.contract_address_hash
      )

      request = conn |> get(endpoint.(address.hash), %{"type" => "ERC-721"})
      response = json_response(request, 200)

      assert List.first(response["items"])["token"]["reputation"] == "ok"

      request = conn |> get(endpoint.(address.hash), %{"type" => "ERC-1155"})
      response = json_response(request, 200)

      assert List.first(response["items"])["token"]["reputation"] == "ok"

      request = conn |> get(endpoint.(address.hash), %{"type" => "ERC-404"})
      response = json_response(request, 200)

      assert List.first(response["items"])["token"]["reputation"] == "ok"
    end

    test "get paginated ERC-721 nft", %{conn: conn, endpoint: endpoint} do
      address = insert(:address)

      insert_list(51, :token_instance)

      token_instances =
        for _ <- 0..50 do
          erc_721_token = insert(:token, type: "ERC-721")

          insert(:token_instance,
            owner_address_hash: address.hash,
            token_contract_address_hash: erc_721_token.contract_address_hash
          )
          |> Repo.preload([:token])
        end
        # works because one token_id per token, despite ordering in DB: [asc: ti.token_contract_address_hash, desc: ti.token_id]
        |> Enum.sort_by(&{&1.token_contract_address_hash, &1.token_id}, :desc)

      request = get(conn, endpoint.(address.hash))
      assert response = json_response(request, 200)

      request_2nd_page = get(conn, endpoint.(address.hash), response["next_page_params"])
      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, token_instances)
    end

    test "next_page_params does not leak original type filter", %{conn: conn, endpoint: endpoint} do
      address = insert(:address)

      # Create a mix of ERC-1155 and ERC-404 items exceeding one page
      insert_list(60, :address_current_token_balance_with_token_id)

      for _ <- 1..60 do
        token = insert(:token, type: "ERC-1155")

        ti =
          insert(:token_instance, token_contract_address_hash: token.contract_address_hash) |> Repo.preload([:token])

        ctb =
          insert(:address_current_token_balance_with_token_id_and_fixed_token_type,
            address: address,
            token_type: "ERC-1155",
            token_id: ti.token_id,
            token_contract_address_hash: token.contract_address_hash
          )

        %Instance{ti | current_token_balance: ctb}
      end

      response =
        conn
        |> get(endpoint.(address.hash), %{type: "ERC-404,ERC-1155"})
        |> json_response(200)

      assert not is_nil(response["next_page_params"])
      refute Map.has_key?(response["next_page_params"], "type")
      assert Map.has_key?(response["next_page_params"], "token_type")
    end

    test "get paginated ERC-1155 nft", %{conn: conn, endpoint: endpoint} do
      address = insert(:address)

      insert_list(51, :address_current_token_balance_with_token_id)

      token_instances =
        for _ <- 0..50 do
          token = insert(:token, type: "ERC-1155")

          ti =
            insert(:token_instance,
              token_contract_address_hash: token.contract_address_hash
            )
            |> Repo.preload([:token])

          current_token_balance =
            insert(:address_current_token_balance_with_token_id_and_fixed_token_type,
              address: address,
              token_type: "ERC-1155",
              token_id: ti.token_id,
              token_contract_address_hash: token.contract_address_hash
            )

          %Instance{ti | current_token_balance: current_token_balance}
        end
        |> Enum.sort_by(&{&1.token_contract_address_hash, &1.token_id}, :desc)

      request = get(conn, endpoint.(address.hash))
      assert response = json_response(request, 200)

      request_2nd_page = get(conn, endpoint.(address.hash), response["next_page_params"])
      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, token_instances)
    end

    test "get paginated ERC-404 nft", %{conn: conn, endpoint: endpoint} do
      address = insert(:address)

      insert_list(51, :address_current_token_balance_with_token_id)

      token_instances =
        for _ <- 0..50 do
          token = insert(:token, type: "ERC-404")

          ti =
            insert(:token_instance,
              token_contract_address_hash: token.contract_address_hash
            )
            |> Repo.preload([:token])

          current_token_balance =
            insert(:address_current_token_balance_with_token_id_and_fixed_token_type,
              address: address,
              token_type: "ERC-404",
              token_id: ti.token_id,
              token_contract_address_hash: token.contract_address_hash
            )

          %Instance{ti | current_token_balance: current_token_balance}
        end
        |> Enum.sort_by(&{&1.token_contract_address_hash, &1.token_id}, :desc)

      request = get(conn, endpoint.(address.hash))
      assert response = json_response(request, 200)

      request_2nd_page = get(conn, endpoint.(address.hash), response["next_page_params"])
      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, token_instances)
    end

    test "test filters", %{conn: conn, endpoint: endpoint} do
      address = insert(:address)

      insert_list(51, :token_instance)

      token_instances_721 =
        for _ <- 0..50 do
          erc_721_token = insert(:token, type: "ERC-721")

          insert(:token_instance,
            owner_address_hash: address.hash,
            token_contract_address_hash: erc_721_token.contract_address_hash
          )
          |> Repo.preload([:token])
        end
        |> Enum.sort_by(&{&1.token_contract_address_hash, &1.token_id}, :desc)

      insert_list(51, :address_current_token_balance_with_token_id)

      token_instances_1155 =
        for _ <- 0..50 do
          token = insert(:token, type: "ERC-1155")

          ti =
            insert(:token_instance,
              token_contract_address_hash: token.contract_address_hash
            )
            |> Repo.preload([:token])

          current_token_balance =
            insert(:address_current_token_balance_with_token_id_and_fixed_token_type,
              address: address,
              token_type: "ERC-1155",
              token_id: ti.token_id,
              token_contract_address_hash: token.contract_address_hash
            )

          %Instance{ti | current_token_balance: current_token_balance}
        end
        |> Enum.sort_by(&{&1.token_contract_address_hash, &1.token_id}, :desc)

      filter = %{"type" => "ERC-721"}
      request = get(conn, endpoint.(address.hash), filter)
      assert response = json_response(request, 200)

      request_2nd_page = get(conn, endpoint.(address.hash), Map.merge(response["next_page_params"], filter))
      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, token_instances_721)

      filter = %{"type" => "ERC-1155"}
      request = get(conn, endpoint.(address.hash), filter)
      assert response = json_response(request, 200)

      request_2nd_page = get(conn, endpoint.(address.hash), Map.merge(response["next_page_params"], filter))
      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, token_instances_1155)
    end

    test "return all token instances", %{conn: conn, endpoint: endpoint} do
      address = insert(:address)

      insert_list(51, :token_instance)

      token_instances_721 =
        for _ <- 0..50 do
          erc_721_token = insert(:token, type: "ERC-721")

          insert(:token_instance,
            owner_address_hash: address.hash,
            token_contract_address_hash: erc_721_token.contract_address_hash
          )
          |> Repo.preload([:token])
        end
        |> Enum.sort_by(&{&1.token_contract_address_hash, &1.token_id}, :desc)

      insert_list(51, :address_current_token_balance_with_token_id)

      token_instances_1155 =
        for _ <- 0..50 do
          token = insert(:token, type: "ERC-1155")

          ti =
            insert(:token_instance,
              token_contract_address_hash: token.contract_address_hash
            )
            |> Repo.preload([:token])

          current_token_balance =
            insert(:address_current_token_balance_with_token_id_and_fixed_token_type,
              address: address,
              token_type: "ERC-1155",
              token_id: ti.token_id,
              token_contract_address_hash: token.contract_address_hash
            )

          %Instance{ti | current_token_balance: current_token_balance}
        end
        |> Enum.sort_by(&{&1.token_contract_address_hash, &1.token_id}, :desc)

      request = get(conn, endpoint.(address.hash))
      assert response = json_response(request, 200)

      request_2nd_page = get(conn, endpoint.(address.hash), response["next_page_params"])
      assert response_2nd_page = json_response(request_2nd_page, 200)

      request_3rd_page = get(conn, endpoint.(address.hash), response_2nd_page["next_page_params"])
      assert response_3rd_page = json_response(request_3rd_page, 200)

      assert response["next_page_params"] != nil
      assert response_2nd_page["next_page_params"] != nil
      assert response_3rd_page["next_page_params"] == nil

      assert Enum.count(response["items"]) == 50
      assert Enum.count(response_2nd_page["items"]) == 50
      assert Enum.count(response_3rd_page["items"]) == 2

      compare_item(Enum.at(token_instances_721, 50), Enum.at(response["items"], 0))
      compare_item(Enum.at(token_instances_721, 1), Enum.at(response["items"], 49))

      compare_item(Enum.at(token_instances_721, 0), Enum.at(response_2nd_page["items"], 0))
      compare_item(Enum.at(token_instances_1155, 50), Enum.at(response_2nd_page["items"], 1))
      compare_item(Enum.at(token_instances_1155, 2), Enum.at(response_2nd_page["items"], 49))

      compare_item(Enum.at(token_instances_1155, 1), Enum.at(response_3rd_page["items"], 0))
      compare_item(Enum.at(token_instances_1155, 0), Enum.at(response_3rd_page["items"], 1))
    end

    test "paginates across types after intermediate type exhaustion (should include next type)", %{
      conn: conn,
      endpoint: endpoint
    } do
      address = insert(:address)

      # Insert 30 ERC-721 (owned directly)
      for _ <- 1..30 do
        erc_721_token = insert(:token, type: "ERC-721")

        insert(:token_instance,
          owner_address_hash: address.hash,
          token_contract_address_hash: erc_721_token.contract_address_hash
        )
      end

      # Insert 25 ERC-1155 (with balances)
      for _ <- 1..25 do
        token = insert(:token, type: "ERC-1155")

        ti =
          insert(:token_instance,
            token_contract_address_hash: token.contract_address_hash
          )
          |> Repo.preload([:token])

        insert(:address_current_token_balance_with_token_id_and_fixed_token_type,
          address: address,
          token_type: "ERC-1155",
          token_id: ti.token_id,
          token_contract_address_hash: token.contract_address_hash
        )
      end

      # Insert 10 ERC-404 (with balances)
      for _ <- 1..10 do
        token = insert(:token, type: "ERC-404")

        ti =
          insert(:token_instance,
            token_contract_address_hash: token.contract_address_hash
          )
          |> Repo.preload([:token])

        insert(:address_current_token_balance_with_token_id_and_fixed_token_type,
          address: address,
          token_type: "ERC-404",
          token_id: ti.token_id,
          token_contract_address_hash: token.contract_address_hash
        )
      end

      # Page 1
      page1_resp = conn |> get(endpoint.(address.hash)) |> json_response(200)
      assert Enum.count(page1_resp["items"]) == 50
      assert page1_resp["next_page_params"] != nil

      # Expect mixture of ERC-721 and ERC-1155 only on first page (by current logic order)
      assert %{
               "ERC-721" => 30,
               "ERC-1155" => 20
             } = Enum.frequencies_by(page1_resp["items"], & &1["token_type"])

      page2_resp = conn |> get(endpoint.(address.hash), page1_resp["next_page_params"]) |> json_response(200)

      assert Enum.count(page2_resp["items"]) == 15
      assert page2_resp["next_page_params"] == nil

      assert %{
               "ERC-1155" => 5,
               "ERC-404" => 10
             } = Enum.frequencies_by(page2_resp["items"], & &1["token_type"])
    end

    test "multi-type filter includes only requested types", %{conn: conn, endpoint: endpoint} do
      address = insert(:address)

      # ERC-721 tokens (should be excluded by filter)
      for _ <- 1..5 do
        erc_721_token = insert(:token, type: "ERC-721")

        insert(:token_instance,
          owner_address_hash: address.hash,
          token_contract_address_hash: erc_721_token.contract_address_hash
        )
      end

      # ERC-1155 tokens (should be included)
      for _ <- 1..5 do
        token = insert(:token, type: "ERC-1155")

        ti =
          insert(:token_instance,
            token_contract_address_hash: token.contract_address_hash
          )
          |> Repo.preload([:token])

        insert(:address_current_token_balance_with_token_id_and_fixed_token_type,
          address: address,
          token_type: "ERC-1155",
          token_id: ti.token_id,
          token_contract_address_hash: token.contract_address_hash
        )
      end

      # ERC-404 tokens (should be included)
      for _ <- 1..5 do
        token = insert(:token, type: "ERC-404")

        ti =
          insert(:token_instance,
            token_contract_address_hash: token.contract_address_hash
          )
          |> Repo.preload([:token])

        insert(:address_current_token_balance_with_token_id_and_fixed_token_type,
          address: address,
          token_type: "ERC-404",
          token_id: ti.token_id,
          token_contract_address_hash: token.contract_address_hash
        )
      end

      filter = %{"type" => "ERC-404,ERC-1155"}
      request = get(conn, endpoint.(address.hash), filter)
      response = json_response(request, 200)

      assert Enum.count(response["items"]) == 10
      assert Enum.all?(response["items"], fn item -> item["token_type"] in ["ERC-404", "ERC-1155"] end)
      refute Enum.any?(response["items"], fn item -> item["token_type"] == "ERC-721" end)
    end
  end

  describe "/addresses/{address_hash}/nft/collections" do
    setup do
      {:ok, endpoint: &"/api/v2/addresses/#{&1}/nft/collections"}
    end

    test "get nft collections with ok reputation", %{conn: conn} do
      init_value = Application.get_env(:block_scout_web, :hide_scam_addresses)
      Application.put_env(:block_scout_web, :hide_scam_addresses, true)
      on_exit(fn -> Application.put_env(:block_scout_web, :hide_scam_addresses, init_value) end)

      address = insert(:address)
      token = insert(:token, type: "ERC-721")
      amount = Enum.random(16..50)

      current_token_balance =
        insert(:address_current_token_balance,
          address: address,
          token_type: "ERC-721",
          token_id: nil,
          token_contract_address_hash: token.contract_address_hash,
          value: amount
        )
        |> Repo.preload([:token])

      for _ <- 0..(amount - 1) do
        ti =
          insert(:token_instance,
            token_contract_address_hash: token.contract_address_hash,
            owner_address_hash: address.hash
          )
          |> Repo.preload([:token])

        %Instance{ti | current_token_balance: current_token_balance}
      end

      token = insert(:token, type: "ERC-1155")
      amount = Enum.random(16..50)

      for _ <- 0..(amount - 1) do
        ti =
          insert(:token_instance,
            token_contract_address_hash: token.contract_address_hash,
            owner_address_hash: address.hash
          )
          |> Repo.preload([:token])

        current_token_balance =
          insert(:address_current_token_balance,
            address: address,
            token_type: "ERC-1155",
            token_id: ti.token_id,
            token_contract_address_hash: token.contract_address_hash,
            value: Enum.random(1..100_000)
          )
          |> Repo.preload([:token])

        %Instance{ti | current_token_balance: current_token_balance}
      end

      token = insert(:token, type: "ERC-404")
      amount = Enum.random(16..50)

      for _ <- 0..(amount - 1) do
        ti =
          insert(:token_instance,
            token_contract_address_hash: token.contract_address_hash,
            owner_address_hash: address.hash
          )
          |> Repo.preload([:token])

        current_token_balance =
          insert(:address_current_token_balance,
            address: address,
            token_type: "ERC-404",
            token_id: ti.token_id,
            token_contract_address_hash: token.contract_address_hash,
            value: Enum.random(1..100_000)
          )
          |> Repo.preload([:token])

        %Instance{ti | current_token_balance: current_token_balance}
      end

      request =
        conn
        |> put_req_cookie("show_scam_tokens", "true")
        |> get("/api/v2/addresses/#{address.hash}/nft/collections", %{type: "ERC-721"})

      response = json_response(request, 200)

      assert List.first(response["items"])["token"]["reputation"] == "ok"

      assert response ==
               conn
               |> get("/api/v2/addresses/#{address.hash}/nft/collections", %{type: "ERC-721"})
               |> json_response(200)

      request =
        conn
        |> put_req_cookie("show_scam_tokens", "true")
        |> get("/api/v2/addresses/#{address.hash}/nft/collections", %{type: "ERC-1155"})

      response = json_response(request, 200)

      assert List.first(response["items"])["token"]["reputation"] == "ok"

      assert response ==
               conn
               |> get("/api/v2/addresses/#{address.hash}/nft/collections", %{type: "ERC-1155"})
               |> json_response(200)

      request =
        conn
        |> put_req_cookie("show_scam_tokens", "true")
        |> get("/api/v2/addresses/#{address.hash}/nft/collections", %{type: "ERC-404"})

      response = json_response(request, 200)

      assert List.first(response["items"])["token"]["reputation"] == "ok"

      assert response ==
               conn
               |> get("/api/v2/addresses/#{address.hash}/nft/collections", %{type: "ERC-404"})
               |> json_response(200)
    end

    test "get nft collections with scam reputation", %{conn: conn} do
      init_value = Application.get_env(:block_scout_web, :hide_scam_addresses)
      Application.put_env(:block_scout_web, :hide_scam_addresses, true)
      on_exit(fn -> Application.put_env(:block_scout_web, :hide_scam_addresses, init_value) end)

      address = insert(:address)

      token = insert(:token, type: "ERC-721")
      insert(:scam_badge_to_address, address_hash: token.contract_address_hash)

      amount = Enum.random(16..50)

      current_token_balance =
        insert(:address_current_token_balance,
          address: address,
          token_type: "ERC-721",
          token_id: nil,
          token_contract_address_hash: token.contract_address_hash,
          value: amount
        )
        |> Repo.preload([:token])

      for _ <- 0..(amount - 1) do
        ti =
          insert(:token_instance,
            token_contract_address_hash: token.contract_address_hash,
            owner_address_hash: address.hash
          )
          |> Repo.preload([:token])

        %Instance{ti | current_token_balance: current_token_balance}
      end

      token = insert(:token, type: "ERC-1155")
      insert(:scam_badge_to_address, address_hash: token.contract_address_hash)
      amount = Enum.random(16..50)

      for _ <- 0..(amount - 1) do
        ti =
          insert(:token_instance,
            token_contract_address_hash: token.contract_address_hash,
            owner_address_hash: address.hash
          )
          |> Repo.preload([:token])

        current_token_balance =
          insert(:address_current_token_balance,
            address: address,
            token_type: "ERC-1155",
            token_id: ti.token_id,
            token_contract_address_hash: token.contract_address_hash,
            value: Enum.random(1..100_000)
          )
          |> Repo.preload([:token])

        %Instance{ti | current_token_balance: current_token_balance}
      end

      token = insert(:token, type: "ERC-404")
      insert(:scam_badge_to_address, address_hash: token.contract_address_hash)
      amount = Enum.random(16..50)

      for _ <- 0..(amount - 1) do
        ti =
          insert(:token_instance,
            token_contract_address_hash: token.contract_address_hash,
            owner_address_hash: address.hash
          )
          |> Repo.preload([:token])

        current_token_balance =
          insert(:address_current_token_balance,
            address: address,
            token_type: "ERC-404",
            token_id: ti.token_id,
            token_contract_address_hash: token.contract_address_hash,
            value: Enum.random(1..100_000)
          )
          |> Repo.preload([:token])

        %Instance{ti | current_token_balance: current_token_balance}
      end

      request =
        conn
        |> put_req_cookie("show_scam_tokens", "true")
        |> get("/api/v2/addresses/#{address.hash}/nft/collections", %{type: "ERC-721"})

      response = json_response(request, 200)

      assert List.first(response["items"])["token"]["reputation"] == "scam"

      request = conn |> get("/api/v2/addresses/#{address.hash}/nft/collections", %{type: "ERC-721"})
      response = json_response(request, 200)

      assert response["items"] == []

      request =
        conn
        |> put_req_cookie("show_scam_tokens", "true")
        |> get("/api/v2/addresses/#{address.hash}/nft/collections", %{type: "ERC-1155"})

      response = json_response(request, 200)

      assert List.first(response["items"])["token"]["reputation"] == "scam"

      request = conn |> get("/api/v2/addresses/#{address.hash}/nft/collections", %{type: "ERC-1155"})
      response = json_response(request, 200)

      assert response["items"] == []

      request =
        conn
        |> put_req_cookie("show_scam_tokens", "true")
        |> get("/api/v2/addresses/#{address.hash}/nft/collections", %{type: "ERC-404"})

      response = json_response(request, 200)

      assert List.first(response["items"])["token"]["reputation"] == "scam"

      request = conn |> get("/api/v2/addresses/#{address.hash}/nft/collections", %{type: "ERC-404"})
      response = json_response(request, 200)

      assert response["items"] == []
    end

    test "get nft collections with ok reputation with hide_scam_addresses=false", %{conn: conn} do
      init_value = Application.get_env(:block_scout_web, :hide_scam_addresses)
      Application.put_env(:block_scout_web, :hide_scam_addresses, false)
      on_exit(fn -> Application.put_env(:block_scout_web, :hide_scam_addresses, init_value) end)
      address = insert(:address)

      token = insert(:token, type: "ERC-721")

      amount = Enum.random(16..50)

      current_token_balance =
        insert(:address_current_token_balance,
          address: address,
          token_type: "ERC-721",
          token_id: nil,
          token_contract_address_hash: token.contract_address_hash,
          value: amount
        )
        |> Repo.preload([:token])

      for _ <- 0..(amount - 1) do
        ti =
          insert(:token_instance,
            token_contract_address_hash: token.contract_address_hash,
            owner_address_hash: address.hash
          )
          |> Repo.preload([:token])

        %Instance{ti | current_token_balance: current_token_balance}
      end

      token = insert(:token, type: "ERC-1155")
      amount = Enum.random(16..50)

      for _ <- 0..(amount - 1) do
        ti =
          insert(:token_instance,
            token_contract_address_hash: token.contract_address_hash,
            owner_address_hash: address.hash
          )
          |> Repo.preload([:token])

        current_token_balance =
          insert(:address_current_token_balance,
            address: address,
            token_type: "ERC-1155",
            token_id: ti.token_id,
            token_contract_address_hash: token.contract_address_hash,
            value: Enum.random(1..100_000)
          )
          |> Repo.preload([:token])

        %Instance{ti | current_token_balance: current_token_balance}
      end

      token = insert(:token, type: "ERC-404")
      amount = Enum.random(16..50)

      for _ <- 0..(amount - 1) do
        ti =
          insert(:token_instance,
            token_contract_address_hash: token.contract_address_hash,
            owner_address_hash: address.hash
          )
          |> Repo.preload([:token])

        current_token_balance =
          insert(:address_current_token_balance,
            address: address,
            token_type: "ERC-404",
            token_id: ti.token_id,
            token_contract_address_hash: token.contract_address_hash,
            value: Enum.random(1..100_000)
          )
          |> Repo.preload([:token])

        %Instance{ti | current_token_balance: current_token_balance}
      end

      request = conn |> get("/api/v2/addresses/#{address.hash}/nft/collections", %{type: "ERC-721"})
      response = json_response(request, 200)

      assert List.first(response["items"])["token"]["reputation"] == "ok"

      request = conn |> get("/api/v2/addresses/#{address.hash}/nft/collections", %{type: "ERC-1155"})
      response = json_response(request, 200)

      assert List.first(response["items"])["token"]["reputation"] == "ok"

      request = conn |> get("/api/v2/addresses/#{address.hash}/nft/collections", %{type: "ERC-404"})
      response = json_response(request, 200)

      assert List.first(response["items"])["token"]["reputation"] == "ok"
    end

    test "get nft collections with scam reputation with hide_scam_addresses=false", %{conn: conn} do
      init_value = Application.get_env(:block_scout_web, :hide_scam_addresses)
      Application.put_env(:block_scout_web, :hide_scam_addresses, false)
      on_exit(fn -> Application.put_env(:block_scout_web, :hide_scam_addresses, init_value) end)

      address = insert(:address)

      token = insert(:token, type: "ERC-721")
      insert(:scam_badge_to_address, address_hash: token.contract_address_hash)

      amount = Enum.random(16..50)

      current_token_balance =
        insert(:address_current_token_balance,
          address: address,
          token_type: "ERC-721",
          token_id: nil,
          token_contract_address_hash: token.contract_address_hash,
          value: amount
        )
        |> Repo.preload([:token])

      for _ <- 0..(amount - 1) do
        ti =
          insert(:token_instance,
            token_contract_address_hash: token.contract_address_hash,
            owner_address_hash: address.hash
          )
          |> Repo.preload([:token])

        %Instance{ti | current_token_balance: current_token_balance}
      end

      token = insert(:token, type: "ERC-1155")
      insert(:scam_badge_to_address, address_hash: token.contract_address_hash)

      amount = Enum.random(16..50)

      for _ <- 0..(amount - 1) do
        ti =
          insert(:token_instance,
            token_contract_address_hash: token.contract_address_hash,
            owner_address_hash: address.hash
          )
          |> Repo.preload([:token])

        current_token_balance =
          insert(:address_current_token_balance,
            address: address,
            token_type: "ERC-1155",
            token_id: ti.token_id,
            token_contract_address_hash: token.contract_address_hash,
            value: Enum.random(1..100_000)
          )
          |> Repo.preload([:token])

        %Instance{ti | current_token_balance: current_token_balance}
      end

      token = insert(:token, type: "ERC-404")
      insert(:scam_badge_to_address, address_hash: token.contract_address_hash)

      amount = Enum.random(16..50)

      for _ <- 0..(amount - 1) do
        ti =
          insert(:token_instance,
            token_contract_address_hash: token.contract_address_hash,
            owner_address_hash: address.hash
          )
          |> Repo.preload([:token])

        current_token_balance =
          insert(:address_current_token_balance,
            address: address,
            token_type: "ERC-404",
            token_id: ti.token_id,
            token_contract_address_hash: token.contract_address_hash,
            value: Enum.random(1..100_000)
          )
          |> Repo.preload([:token])

        %Instance{ti | current_token_balance: current_token_balance}
      end

      request = conn |> get("/api/v2/addresses/#{address.hash}/nft/collections", %{type: "ERC-721"})
      response = json_response(request, 200)

      assert List.first(response["items"])["token"]["reputation"] == "ok"

      request = conn |> get("/api/v2/addresses/#{address.hash}/nft/collections", %{type: "ERC-1155"})
      response = json_response(request, 200)

      assert List.first(response["items"])["token"]["reputation"] == "ok"

      request = conn |> get("/api/v2/addresses/#{address.hash}/nft/collections", %{type: "ERC-404"})
      response = json_response(request, 200)

      assert List.first(response["items"])["token"]["reputation"] == "ok"
    end

    test "get 200 on non existing address", %{conn: conn, endpoint: endpoint} do
      address = build(:address)

      request = get(conn, endpoint.(address.hash))

      response = json_response(request, 200)
      assert %{"items" => [], "next_page_params" => nil} = response
    end

    test "get 422 on invalid address", %{conn: conn, endpoint: endpoint} do
      request = get(conn, endpoint.("0x"))

      json_response = json_response(request, 422)

      assert %{
               "errors" => [
                 %{
                   "detail" => "Invalid format. Expected ~r/^0x([A-Fa-f0-9]{40})$/",
                   "source" => %{"pointer" => "/address_hash_param"},
                   "title" => "Invalid value"
                 }
               ]
             } = json_response
    end

    test "get paginated erc-721 collection", %{conn: conn, endpoint: endpoint} do
      address = insert(:address)

      insert_list(51, :address_current_token_balance_with_token_id)
      insert_list(51, :token_instance)

      ctbs =
        for _ <- 0..50 do
          token = insert(:token, type: "ERC-721")
          amount = Enum.random(16..50)

          current_token_balance =
            insert(:address_current_token_balance,
              address: address,
              token_type: "ERC-721",
              token_id: nil,
              token_contract_address_hash: token.contract_address_hash,
              value: amount
            )
            |> Repo.preload([:token])

          token_instances =
            for _ <- 0..(amount - 1) do
              ti =
                insert(:token_instance,
                  token_contract_address_hash: token.contract_address_hash,
                  owner_address_hash: address.hash
                )
                |> Repo.preload([:token])

              %Instance{ti | current_token_balance: current_token_balance}
            end
            |> Enum.sort_by(&{&1.token_contract_address_hash, &1.token_id}, :desc)

          {current_token_balance, token_instances}
        end
        |> Enum.sort_by(&elem(&1, 0).token_contract_address_hash, :desc)

      request = get(conn, endpoint.(address.hash))
      assert response = json_response(request, 200)

      request_2nd_page = get(conn, endpoint.(address.hash), response["next_page_params"])
      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, ctbs)
    end

    test "get paginated erc-1155 collection", %{conn: conn, endpoint: endpoint} do
      address = insert(:address)

      insert_list(51, :address_current_token_balance_with_token_id)
      insert_list(51, :token_instance)

      collections =
        for _ <- 0..50 do
          token = insert(:token, type: "ERC-1155")
          amount = Enum.random(16..50)

          token_instances =
            for _ <- 0..(amount - 1) do
              ti =
                insert(:token_instance,
                  token_contract_address_hash: token.contract_address_hash
                )
                |> Repo.preload([:token])

              current_token_balance =
                insert(:address_current_token_balance,
                  address: address,
                  token_type: "ERC-1155",
                  token_id: ti.token_id,
                  token_contract_address_hash: token.contract_address_hash,
                  value: Enum.random(1..100_000)
                )
                |> Repo.preload([:token])

              %Instance{ti | current_token_balance: current_token_balance}
            end
            |> Enum.sort_by(& &1.token_id, :desc)

          {token, amount, token_instances}
        end
        |> Enum.sort_by(&elem(&1, 0).contract_address_hash, :desc)

      request = get(conn, endpoint.(address.hash))
      assert response = json_response(request, 200)

      request_2nd_page = get(conn, endpoint.(address.hash), response["next_page_params"])
      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, collections)
    end

    test "test filters", %{conn: conn, endpoint: endpoint} do
      address = insert(:address)

      insert_list(51, :address_current_token_balance_with_token_id)
      insert_list(51, :token_instance)

      ctbs =
        for _ <- 0..50 do
          token = insert(:token, type: "ERC-721")
          amount = Enum.random(16..50)

          current_token_balance =
            insert(:address_current_token_balance,
              address: address,
              token_type: "ERC-721",
              token_id: nil,
              token_contract_address_hash: token.contract_address_hash,
              value: amount
            )
            |> Repo.preload([:token])

          token_instances =
            for _ <- 0..(amount - 1) do
              ti =
                insert(:token_instance,
                  token_contract_address_hash: token.contract_address_hash,
                  owner_address_hash: address.hash
                )
                |> Repo.preload([:token])

              %Instance{ti | current_token_balance: current_token_balance}
            end
            |> Enum.sort_by(& &1.token_id, :desc)

          {current_token_balance, token_instances}
        end
        |> Enum.sort_by(&elem(&1, 0).token_contract_address_hash, :desc)

      collections =
        for _ <- 0..50 do
          token = insert(:token, type: "ERC-1155")
          amount = Enum.random(16..50)

          token_instances =
            for _ <- 0..(amount - 1) do
              ti =
                insert(:token_instance,
                  token_contract_address_hash: token.contract_address_hash,
                  owner_address_hash: address.hash
                )
                |> Repo.preload([:token])

              current_token_balance =
                insert(:address_current_token_balance,
                  address: address,
                  token_type: "ERC-1155",
                  token_id: ti.token_id,
                  token_contract_address_hash: token.contract_address_hash,
                  value: Enum.random(1..100_000)
                )
                |> Repo.preload([:token])

              %Instance{ti | current_token_balance: current_token_balance}
            end
            |> Enum.sort_by(& &1.token_id, :desc)

          {token, amount, token_instances}
        end
        |> Enum.sort_by(&elem(&1, 0).contract_address_hash, :desc)

      filter = %{"type" => "ERC-721"}
      request = get(conn, endpoint.(address.hash), filter)
      assert response = json_response(request, 200)

      request_2nd_page = get(conn, endpoint.(address.hash), Map.merge(response["next_page_params"], filter))
      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, ctbs)

      filter = %{"type" => "ERC-1155"}
      request = get(conn, endpoint.(address.hash), filter)
      assert response = json_response(request, 200)

      request_2nd_page = get(conn, endpoint.(address.hash), Map.merge(response["next_page_params"], filter))
      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, collections)
    end

    test "return all collections", %{conn: conn, endpoint: endpoint} do
      address = insert(:address)

      insert_list(51, :address_current_token_balance_with_token_id)
      insert_list(51, :token_instance)

      collections_721 =
        for _ <- 0..50 do
          token = insert(:token, type: "ERC-721")
          amount = Enum.random(16..50)

          current_token_balance =
            insert(:address_current_token_balance,
              address: address,
              token_type: "ERC-721",
              token_id: nil,
              token_contract_address_hash: token.contract_address_hash,
              value: amount
            )
            |> Repo.preload([:token])

          token_instances =
            for _ <- 0..(amount - 1) do
              ti =
                insert(:token_instance,
                  token_contract_address_hash: token.contract_address_hash,
                  owner_address_hash: address.hash
                )
                |> Repo.preload([:token])

              %Instance{ti | current_token_balance: current_token_balance}
            end
            |> Enum.sort_by(& &1.token_id, :desc)

          {current_token_balance, token_instances}
        end
        |> Enum.sort_by(&elem(&1, 0).token_contract_address_hash, :desc)

      collections_1155 =
        for _ <- 0..50 do
          token = insert(:token, type: "ERC-1155")
          amount = Enum.random(16..50)

          token_instances =
            for _ <- 0..(amount - 1) do
              ti =
                insert(:token_instance,
                  token_contract_address_hash: token.contract_address_hash,
                  owner_address_hash: address.hash
                )
                |> Repo.preload([:token])

              current_token_balance =
                insert(:address_current_token_balance,
                  address: address,
                  token_type: "ERC-1155",
                  token_id: ti.token_id,
                  token_contract_address_hash: token.contract_address_hash,
                  value: Enum.random(1..100_000)
                )
                |> Repo.preload([:token])

              %Instance{ti | current_token_balance: current_token_balance}
            end
            |> Enum.sort_by(& &1.token_id, :desc)

          {token, amount, token_instances}
        end
        |> Enum.sort_by(&elem(&1, 0).contract_address_hash, :desc)

      request = get(conn, endpoint.(address.hash))
      assert response = json_response(request, 200)

      request_2nd_page = get(conn, endpoint.(address.hash), response["next_page_params"])
      assert response_2nd_page = json_response(request_2nd_page, 200)

      request_3rd_page = get(conn, endpoint.(address.hash), response_2nd_page["next_page_params"])
      assert response_3rd_page = json_response(request_3rd_page, 200)

      assert response["next_page_params"] != nil
      assert response_2nd_page["next_page_params"] != nil
      assert response_3rd_page["next_page_params"] == nil

      assert Enum.count(response["items"]) == 50
      assert Enum.count(response_2nd_page["items"]) == 50
      assert Enum.count(response_3rd_page["items"]) == 2

      compare_item(Enum.at(collections_721, 50), Enum.at(response["items"], 0))
      compare_item(Enum.at(collections_721, 1), Enum.at(response["items"], 49))

      compare_item(Enum.at(collections_721, 0), Enum.at(response_2nd_page["items"], 0))
      compare_item(Enum.at(collections_1155, 50), Enum.at(response_2nd_page["items"], 1))
      compare_item(Enum.at(collections_1155, 2), Enum.at(response_2nd_page["items"], 49))

      compare_item(Enum.at(collections_1155, 1), Enum.at(response_3rd_page["items"], 0))
      compare_item(Enum.at(collections_1155, 0), Enum.at(response_3rd_page["items"], 1))
    end
  end

  if @chain_type == :ethereum do
    describe "/addresses/{address_hash}/beacon/deposits" do
      test "get empty list on non-existing address", %{conn: conn} do
        address = build(:address)

        request = get(conn, "/api/v2/addresses/#{address.hash}/beacon/deposits")
        response = json_response(request, 200)

        assert %{"items" => [], "next_page_params" => nil} = response
      end

      test "get 422 on invalid address", %{conn: conn} do
        request = get(conn, "/api/v2/addresses/invalid/beacon/deposits")
        response = json_response(request, 422)

        assert %{
                 "errors" => [
                   %{
                     "detail" => "Invalid format. Expected ~r/^0x([A-Fa-f0-9]{40})$/",
                     "source" => %{"pointer" => "/address_hash_param"},
                     "title" => "Invalid value"
                   }
                 ]
               } = response
      end

      test "get deposits", %{conn: conn} do
        address = insert(:address)

        deposits = insert_list(51, :beacon_deposit, from_address: address)

        request = get(conn, "/api/v2/addresses/#{address.hash}/beacon/deposits")
        assert response = json_response(request, 200)

        request_2nd_page =
          get(conn, "/api/v2/addresses/#{address.hash}/beacon/deposits", response["next_page_params"])

        assert response_2nd_page = json_response(request_2nd_page, 200)

        check_paginated_response(response, response_2nd_page, deposits)
      end
    end
  end

  defp compare_item(%Address{} = address, json) do
    assert Address.checksum(address.hash) == json["hash"]
    assert to_string(address.transactions_count) == json["transactions_count"]
  end

  defp compare_item(%Transaction{} = transaction, json) do
    assert to_string(transaction.hash) == json["hash"]
    assert transaction.block_number == json["block_number"]
    assert to_string(transaction.value.value) == json["value"]
    assert Address.checksum(transaction.from_address_hash) == json["from"]["hash"]
    assert Address.checksum(transaction.to_address_hash) == json["to"]["hash"]
  end

  defp compare_item(%InternalTransaction{} = internal_transaction, json) do
    assert internal_transaction.block_number == json["block_number"]
    assert to_string(internal_transaction.gas) == json["gas_limit"]
    assert internal_transaction.index == json["index"]
    assert to_string(internal_transaction.transaction_hash) == json["transaction_hash"]
    assert Address.checksum(internal_transaction.from_address_hash) == json["from"]["hash"]
    assert Address.checksum(internal_transaction.to_address_hash) == json["to"]["hash"]
  end

  defp compare_item(%Block{} = block, json) do
    assert to_string(block.hash) == json["hash"]
    assert block.number == json["height"]
  end

  defp compare_item(%CurrentTokenBalance{} = ctb, json) do
    assert to_string(ctb.value) == json["value"]
    assert (ctb.token_id && to_string(ctb.token_id)) == json["token_id"]
    compare_item(ctb.token, json["token"])
  end

  defp compare_item(%CoinBalance{} = cb, json) do
    assert to_string(cb.value.value) == json["value"]
    assert cb.block_number == json["block_number"]

    assert Jason.encode!(Repo.get_by(Block, number: cb.block_number).timestamp) =~
             String.replace(json["block_timestamp"], "Z", "")
  end

  defp compare_item(%Token{} = token, json) do
    assert Address.checksum(token.contract_address_hash) == json["address_hash"]
    assert to_string(token.symbol) == json["symbol"]
    assert to_string(token.name) == json["name"]
    assert to_string(token.type) == json["type"]
    assert to_string(token.decimals) == json["decimals"]
    assert (token.holder_count && to_string(token.holder_count)) == json["holders_count"]
    assert Map.has_key?(json, "exchange_rate")
  end

  defp compare_item(%Log{} = log, json) do
    assert log.index == json["index"]
    assert to_string(log.data) == json["data"]
    assert Address.checksum(log.address_hash) == json["address"]["hash"]
    assert to_string(log.transaction_hash) == json["transaction_hash"]
    assert json["block_number"] == log.block_number
    assert json["block_hash"] == to_string(log.block_hash)
    assert json["block_timestamp"] != nil
  end

  defp compare_item(%Withdrawal{} = withdrawal, json) do
    assert withdrawal.index == json["index"]
  end

  defp compare_item(%Instance{token: %Token{} = token} = instance, json) do
    token_type = token.type
    value = to_string(value(token.type, instance))
    id = to_string(instance.token_id)
    metadata = instance.metadata
    token_address_hash = Address.checksum(token.contract_address_hash)
    app_url = instance.metadata["external_url"]
    animation_url = instance.metadata["animation_url"]
    image_url = instance.metadata["image_url"]
    token_name = token.name

    assert %{
             "token_type" => ^token_type,
             "value" => ^value,
             "id" => ^id,
             "metadata" => ^metadata,
             "owner" => nil,
             "token" => %{"address_hash" => ^token_address_hash, "name" => ^token_name, "type" => ^token_type},
             "external_app_url" => ^app_url,
             "animation_url" => ^animation_url,
             "image_url" => ^image_url,
             "is_unique" => nil
           } = json
  end

  defp compare_item({%CurrentTokenBalance{token: token} = ctb, token_instances}, json) do
    token_type = token.type
    token_address_hash = Address.checksum(token.contract_address_hash)
    token_name = token.name
    amount = to_string(ctb.distinct_token_instances_count || ctb.value)

    assert Enum.count(json["token_instances"]) == @instances_amount_in_collection

    token_instances
    |> Enum.take(@instances_amount_in_collection)
    |> Enum.with_index()
    |> Enum.each(fn {instance, index} ->
      compare_token_instance_in_collection(instance, Enum.at(json["token_instances"], index))
    end)

    assert %{
             "token" => %{"address_hash" => ^token_address_hash, "name" => ^token_name, "type" => ^token_type},
             "amount" => ^amount
           } = json
  end

  defp compare_item(%BeaconDeposit{} = deposit, json) do
    index = deposit.index
    transaction_hash = to_string(deposit.transaction_hash)
    block_hash = to_string(deposit.block_hash)
    block_number = deposit.block_number
    pubkey = to_string(deposit.pubkey)
    withdrawal_credentials = to_string(deposit.withdrawal_credentials)
    signature = to_string(deposit.signature)
    from_address_hash = Address.checksum(deposit.from_address_hash)

    if deposit.withdrawal_address_hash do
      withdrawal_address_hash = Address.checksum(deposit.withdrawal_address_hash)

      assert %{
               "index" => ^index,
               "transaction_hash" => ^transaction_hash,
               "block_hash" => ^block_hash,
               "block_number" => ^block_number,
               "pubkey" => ^pubkey,
               "withdrawal_credentials" => ^withdrawal_credentials,
               "withdrawal_address" => %{"hash" => ^withdrawal_address_hash},
               "signature" => ^signature,
               "from_address" => %{"hash" => ^from_address_hash}
             } = json
    else
      assert %{
               "index" => ^index,
               "transaction_hash" => ^transaction_hash,
               "block_hash" => ^block_hash,
               "block_number" => ^block_number,
               "pubkey" => ^pubkey,
               "withdrawal_credentials" => ^withdrawal_credentials,
               "withdrawal_address" => nil,
               "signature" => ^signature,
               "from_address" => %{"hash" => ^from_address_hash}
             } = json
    end
  end

  defp compare_item({token, amount, token_instances}, json) do
    token_type = token.type
    token_address_hash = Address.checksum(token.contract_address_hash)
    token_name = token.name
    amount = to_string(amount)

    assert Enum.count(json["token_instances"]) == @instances_amount_in_collection

    token_instances
    |> Enum.take(@instances_amount_in_collection)
    |> Enum.with_index()
    |> Enum.each(fn {instance, index} ->
      compare_token_instance_in_collection(instance, Enum.at(json["token_instances"], index))
    end)

    assert %{
             "token" => %{"address_hash" => ^token_address_hash, "name" => ^token_name, "type" => ^token_type},
             "amount" => ^amount
           } = json
  end

  defp compare_item(%TokenTransfer{} = token_transfer, json, allow_nil_method? \\ false) do
    assert Address.checksum(token_transfer.from_address_hash) == json["from"]["hash"]
    assert Address.checksum(token_transfer.to_address_hash) == json["to"]["hash"]
    assert to_string(token_transfer.transaction_hash) == to_string(json["transaction_hash"])
    assert json["timestamp"] != nil

    if not allow_nil_method? do
      assert json["method"] != nil
    end

    assert to_string(token_transfer.block_hash) == json["block_hash"]
    assert token_transfer.log_index == json["log_index"]
    assert check_total(Repo.preload(token_transfer, [{:token, :contract_address}]).token, json["total"], token_transfer)
  end

  defp compare_token_instance_in_collection(%Instance{token: %Token{} = token} = instance, json) do
    token_type = token.type
    value = to_string(value(token.type, instance))
    id = to_string(instance.token_id)
    metadata = instance.metadata
    app_url = instance.metadata["external_url"]
    animation_url = instance.metadata["animation_url"]
    image_url = instance.metadata["image_url"]

    assert %{
             "token_type" => ^token_type,
             "value" => ^value,
             "id" => ^id,
             "metadata" => ^metadata,
             "owner" => nil,
             "token" => nil,
             "external_app_url" => ^app_url,
             "animation_url" => ^animation_url,
             "image_url" => ^image_url,
             "is_unique" => nil
           } = json
  end

  defp value("ERC-721", _), do: 1
  defp value(_, nft), do: nft.current_token_balance.value

  defp check_paginated_response(first_page_resp, second_page_resp, list) do
    assert Enum.count(first_page_resp["items"]) == 50
    assert first_page_resp["next_page_params"] != nil
    compare_item(Enum.at(list, 50), Enum.at(first_page_resp["items"], 0))
    compare_item(Enum.at(list, 1), Enum.at(first_page_resp["items"], 49))

    assert Enum.count(second_page_resp["items"]) == 1
    assert second_page_resp["next_page_params"] == nil
    compare_item(Enum.at(list, 0), Enum.at(second_page_resp["items"], 0))
  end

  # with the current implementation no transfers should come with list in totals
  def check_total(%Token{type: nft}, json, _token_transfer) when nft in ["ERC-721", "ERC-1155"] and is_list(json) do
    false
  end

  def check_total(%Token{type: nft}, json, token_transfer) when nft in ["ERC-1155"] do
    json["token_id"] in Enum.map(token_transfer.token_ids, fn x -> to_string(x) end) and
      json["value"] == to_string(token_transfer.amount)
  end

  def check_total(%Token{type: nft}, json, token_transfer) when nft in ["ERC-721"] do
    json["token_id"] in Enum.map(token_transfer.token_ids, fn x -> to_string(x) end)
  end

  def check_total(_, _, _), do: true
end
