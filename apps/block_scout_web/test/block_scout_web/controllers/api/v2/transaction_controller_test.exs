defmodule BlockScoutWeb.API.V2.TransactionControllerTest do
  use BlockScoutWeb.ConnCase

  use Utils.CompileTimeEnvHelper,
    chain_type: [:explorer, :chain_type],
    chain_identity: [:explorer, :chain_identity]

  import Explorer.Chain, only: [hash_to_lower_case_string: 1]
  import Mox

  alias Explorer.Account.{Identity, WatchlistAddress}
  alias Explorer.Chain.{Address, InternalTransaction, Log, Token, TokenTransfer, Transaction, Wei}
  alias Explorer.Chain.Beacon.Deposit, as: BeaconDeposit
  alias Explorer.{Repo, TestHelper}

  require Logger

  setup do
    Supervisor.terminate_child(Explorer.Supervisor, Explorer.Chain.Cache.Transactions.child_id())
    Supervisor.restart_child(Explorer.Supervisor, Explorer.Chain.Cache.Transactions.child_id())

    :ok
  end

  describe "/transactions" do
    test "empty list", %{conn: conn} do
      request = get(conn, "/api/v2/transactions")

      assert response = json_response(request, 200)
      assert response["items"] == []
      assert response["next_page_params"] == nil
    end

    test "non empty list", %{conn: conn} do
      1
      |> insert_list(:transaction)
      |> with_block()

      request = get(conn, "/api/v2/transactions")

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 1
      assert response["next_page_params"] == nil
    end

    test "transactions with next_page_params", %{conn: conn} do
      transactions =
        51
        |> insert_list(:transaction)
        |> with_block()

      request = get(conn, "/api/v2/transactions")
      assert response = json_response(request, 200)

      request_2nd_page = get(conn, "/api/v2/transactions", response["next_page_params"])
      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, transactions)
    end

    test "filter=pending", %{conn: conn} do
      pending_transactions =
        51
        |> insert_list(:transaction)

      _mined_transactions =
        51
        |> insert_list(:transaction)
        |> with_block()

      filter = %{"filter" => "pending"}

      request = get(conn, "/api/v2/transactions", filter)
      assert response = json_response(request, 200)

      request_2nd_page = get(conn, "/api/v2/transactions", Map.merge(response["next_page_params"], filter))
      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, pending_transactions)
    end

    test "filter=validated", %{conn: conn} do
      _pending_transactions =
        51
        |> insert_list(:transaction)

      mined_transactions =
        51
        |> insert_list(:transaction)
        |> with_block()

      filter = %{"filter" => "validated"}

      request = get(conn, "/api/v2/transactions", filter)
      assert response = json_response(request, 200)

      request_2nd_page = get(conn, "/api/v2/transactions", Map.merge(response["next_page_params"], filter))
      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, mined_transactions)
    end
  end

  describe "/transactions/watchlist" do
    test "unauthorized", %{conn: conn} do
      request = get(conn, "/api/v2/transactions/watchlist")

      assert %{"message" => "Unauthorized"} = json_response(request, 401)
    end

    test "empty list", %{conn: conn} do
      51
      |> insert_list(:transaction)
      |> with_block()

      auth = build(:auth)
      insert(:address)
      {:ok, user} = Identity.find_or_create(auth)

      conn = Plug.Test.init_test_session(conn, current_user: user)

      request = get(conn, "/api/v2/transactions/watchlist")
      assert response = json_response(request, 200)

      assert response["items"] == []
      assert response["next_page_params"] == nil
    end

    test "watchlist transactions can paginate", %{conn: conn} do
      auth = build(:auth)
      {:ok, user} = Identity.find_or_create(auth)

      conn = Plug.Test.init_test_session(conn, current_user: user)

      address_1 = insert(:address)

      watchlist_address_1 =
        Repo.account_repo().insert!(%WatchlistAddress{
          name: "wallet_1",
          watchlist_id: user.watchlist_id,
          address_hash: address_1.hash,
          address_hash_hash: hash_to_lower_case_string(address_1.hash),
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

      address_2 = insert(:address)

      watchlist_address_2 =
        Repo.account_repo().insert!(%WatchlistAddress{
          name: "wallet_2",
          watchlist_id: user.watchlist_id,
          address_hash: address_2.hash,
          address_hash_hash: hash_to_lower_case_string(address_2.hash),
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

      51
      |> insert_list(:transaction)

      51
      |> insert_list(:transaction)
      |> with_block()

      transactions_1 =
        25
        |> insert_list(:transaction, from_address: address_1)
        |> with_block()

      transactions_2 =
        1
        |> insert_list(:transaction, from_address: address_2, to_address: address_1)
        |> with_block()

      transactions_3 =
        25
        |> insert_list(:transaction, from_address: address_2)
        |> with_block()

      request = get(conn, "/api/v2/transactions/watchlist")
      assert response = json_response(request, 200)

      request_2nd_page = get(conn, "/api/v2/transactions/watchlist", response["next_page_params"])
      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, transactions_1 ++ transactions_2 ++ transactions_3, %{
        address_1.hash => watchlist_address_1.name,
        address_2.hash => watchlist_address_2.name
      })
    end
  end

  describe "/transactions/{transaction_hash}" do
    test "get token-transfers with ok reputation", %{conn: conn} do
      init_value = Application.get_env(:block_scout_web, :hide_scam_addresses)
      Application.put_env(:block_scout_web, :hide_scam_addresses, true)
      on_exit(fn -> Application.put_env(:block_scout_web, :hide_scam_addresses, init_value) end)

      token = insert(:token, type: "ERC-1155")

      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(:token_transfer,
        transaction: transaction,
        block: transaction.block,
        block_number: transaction.block_number,
        token_contract_address: token.contract_address,
        token_ids: Enum.map(0..50, fn x -> x end),
        token_type: "ERC-1155",
        amounts: Enum.map(0..50, fn x -> x end)
      )

      request = conn |> put_req_cookie("show_scam_tokens", "true") |> get("/api/v2/transactions/#{transaction.hash}")
      response = json_response(request, 200)

      assert List.first(response["token_transfers"])["token"]["reputation"] == "ok"

      assert response == conn |> get("/api/v2/transactions/#{transaction.hash}") |> json_response(200)
    end

    test "get smart-contract with scam reputation", %{conn: conn} do
      init_value = Application.get_env(:block_scout_web, :hide_scam_addresses)
      Application.put_env(:block_scout_web, :hide_scam_addresses, true)
      on_exit(fn -> Application.put_env(:block_scout_web, :hide_scam_addresses, init_value) end)

      token = insert(:token, type: "ERC-1155")

      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(:token_transfer,
        transaction: transaction,
        block: transaction.block,
        block_number: transaction.block_number,
        token_contract_address: token.contract_address,
        token_ids: Enum.map(0..50, fn x -> x end),
        token_type: "ERC-1155",
        amounts: Enum.map(0..50, fn x -> x end)
      )

      insert(:scam_badge_to_address, address_hash: token.contract_address_hash)

      request = conn |> put_req_cookie("show_scam_tokens", "true") |> get("/api/v2/transactions/#{transaction.hash}")
      response = json_response(request, 200)

      assert List.first(response["token_transfers"])["token"]["reputation"] == "scam"

      request = conn |> get("/api/v2/transactions/#{transaction.hash}")
      response = json_response(request, 200)

      assert response["token_transfers"] == []
    end

    test "get token-transfers with ok reputation with hide_scam_addresses=false", %{conn: conn} do
      init_value = Application.get_env(:block_scout_web, :hide_scam_addresses)
      Application.put_env(:block_scout_web, :hide_scam_addresses, false)
      on_exit(fn -> Application.put_env(:block_scout_web, :hide_scam_addresses, init_value) end)

      token = insert(:token, type: "ERC-1155")

      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(:token_transfer,
        transaction: transaction,
        block: transaction.block,
        block_number: transaction.block_number,
        token_contract_address: token.contract_address,
        token_ids: Enum.map(0..50, fn x -> x end),
        token_type: "ERC-1155",
        amounts: Enum.map(0..50, fn x -> x end)
      )

      request = conn |> get("/api/v2/transactions/#{transaction.hash}")
      response = json_response(request, 200)

      assert List.first(response["token_transfers"])["token"]["reputation"] == "ok"
    end

    test "get token-transfers with scam reputation with hide_scam_addresses=false", %{conn: conn} do
      init_value = Application.get_env(:block_scout_web, :hide_scam_addresses)
      Application.put_env(:block_scout_web, :hide_scam_addresses, false)
      on_exit(fn -> Application.put_env(:block_scout_web, :hide_scam_addresses, init_value) end)

      token = insert(:token, type: "ERC-1155")

      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(:token_transfer,
        transaction: transaction,
        block: transaction.block,
        block_number: transaction.block_number,
        token_contract_address: token.contract_address,
        token_ids: Enum.map(0..50, fn x -> x end),
        token_type: "ERC-1155",
        amounts: Enum.map(0..50, fn x -> x end)
      )

      insert(:scam_badge_to_address, address_hash: token.contract_address_hash)

      request = conn |> get("/api/v2/transactions/#{transaction.hash}")
      response = json_response(request, 200)

      assert List.first(response["token_transfers"])["token"]["reputation"] == "ok"
    end

    test "return 404 on non existing transaction", %{conn: conn} do
      transaction = build(:transaction)
      request = get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}")

      assert %{"message" => "Not found"} = json_response(request, 404)
    end

    test "return 422 on invalid transaction hash", %{conn: conn} do
      request = get(conn, "/api/v2/transactions/0x")

      assert %{
               "errors" => [
                 %{
                   "detail" => "Invalid format. Expected ~r/^0x([A-Fa-f0-9]{64})$/",
                   "source" => %{"pointer" => "/transaction_hash_param"},
                   "title" => "Invalid value"
                 }
               ]
             } = json_response(request, 422)
    end

    test "return existing transaction", %{conn: conn} do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      request = get(conn, "/api/v2/transactions/" <> to_string(transaction.hash))

      assert response = json_response(request, 200)
      compare_item(transaction, response)
    end

    test "includes is_pending_update field in response", %{conn: conn} do
      block_refetch_needed = insert(:block, refetch_needed: true)
      block_no_refetch = insert(:block, refetch_needed: false)

      transaction_refetch_needed =
        :transaction
        |> insert()
        |> with_block(block_refetch_needed)

      transaction_no_refetch =
        :transaction
        |> insert()
        |> with_block(block_no_refetch)

      request_1 = get(conn, "/api/v2/transactions/" <> to_string(transaction_refetch_needed.hash))
      assert response_1 = json_response(request_1, 200)
      assert response_1["is_pending_update"] == true

      request_2 = get(conn, "/api/v2/transactions/" <> to_string(transaction_no_refetch.hash))
      assert response_2 = json_response(request_2, 200)
      assert response_2["is_pending_update"] == false
    end

    test "includes is_pending_update field in transaction lists", %{conn: conn} do
      block_refetch_needed = insert(:block, refetch_needed: true)
      block_no_refetch = insert(:block, refetch_needed: false)

      transaction_refetch_needed =
        :transaction
        |> insert()
        |> with_block(block_refetch_needed)

      transaction_no_refetch =
        :transaction
        |> insert()
        |> with_block(block_no_refetch)

      request = get(conn, "/api/v2/transactions")
      assert response = json_response(request, 200)

      # Find the transactions in the response
      refetch_tx_response =
        Enum.find(response["items"], fn item -> item["hash"] == to_string(transaction_refetch_needed.hash) end)

      no_refetch_tx_response =
        Enum.find(response["items"], fn item -> item["hash"] == to_string(transaction_no_refetch.hash) end)

      assert refetch_tx_response["is_pending_update"] == true
      assert no_refetch_tx_response["is_pending_update"] == false
    end

    test "batch 1155 flattened", %{conn: conn} do
      token = insert(:token, type: "ERC-1155")

      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(:token_transfer,
        transaction: transaction,
        block: transaction.block,
        block_number: transaction.block_number,
        token_contract_address: token.contract_address,
        token_ids: Enum.map(0..50, fn x -> x end),
        token_type: "ERC-1155",
        amounts: Enum.map(0..50, fn x -> x end)
      )

      request = get(conn, "/api/v2/transactions/" <> to_string(transaction.hash))

      assert response = json_response(request, 200)
      compare_item(transaction, response)

      assert Enum.count(response["token_transfers"]) == 10
    end

    test "single 1155 flattened", %{conn: conn} do
      token = insert(:token, type: "ERC-1155")

      transaction =
        :transaction
        |> insert()
        |> with_block()

      tt =
        insert(:token_transfer,
          transaction: transaction,
          block: transaction.block,
          block_number: transaction.block_number,
          token_contract_address: token.contract_address,
          token_ids: [1],
          token_type: "ERC-1155",
          amounts: [2],
          amount: nil
        )

      request = get(conn, "/api/v2/transactions/" <> to_string(transaction.hash))

      assert response = json_response(request, 200)
      compare_item(transaction, response)

      assert Enum.count(response["token_transfers"]) == 1
      assert is_map(Enum.at(response["token_transfers"], 0)["total"])
      assert compare_item(%TokenTransfer{tt | amount: 2}, Enum.at(response["token_transfers"], 0))
    end

    test "return transaction with input starting with 0x", %{conn: conn} do
      contract =
        insert(:smart_contract,
          contract_code_md5: "123",
          abi: [
            %{
              "constant" => false,
              "inputs" => [%{"name" => "", "type" => "bytes"}],
              "name" => "set",
              "outputs" => [],
              "payable" => false,
              "stateMutability" => "nonpayable",
              "type" => "function"
            }
          ]
        )
        |> Repo.preload(:address)

      input_data =
        "set(bytes)"
        |> ABI.encode([
          <<48, 120, 253, 69, 39, 88, 49, 136, 89, 142, 21, 123, 116, 129, 248, 32, 77, 29, 224, 121, 49, 137, 216, 8,
            212, 195, 239, 11, 174, 75, 56, 126>>
        ])
        |> Base.encode16(case: :lower)

      transaction =
        :transaction
        |> insert(to_address: contract.address, input: "0x" <> input_data)
        |> Repo.preload(to_address: :smart_contract)

      request = get(conn, "/api/v2/transactions/" <> to_string(transaction.hash))

      assert json_response(request, 200)
    end

    if @chain_type == :suave do
      test "renders peeker starting with 0x", %{conn: conn} do
        bid_contract = insert(:address)

        old_env = Application.get_env(:explorer, Transaction, [])

        Application.put_env(
          :explorer,
          Transaction,
          Keyword.merge(old_env, suave_bid_contracts: to_string(bid_contract.hash))
        )

        on_exit(fn ->
          Application.put_env(:explorer, Transaction, old_env)
        end)

        transaction =
          insert(:transaction,
            to_address_hash: bid_contract.hash,
            to_address: bid_contract,
            execution_node_hash: bid_contract.hash
          )

        insert(:log,
          transaction_hash: transaction.hash,
          transaction: transaction,
          address: bid_contract,
          first_topic: "0x83481d5b04dea534715acad673a8177a46fc93882760f36bdc16ccac439d504e",
          data:
            "0x11111111111111111111111111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000010000000000000000000000003078505152535455565758595a5b5c5d5e5f6061"
        )

        request = get(conn, "/api/v2/transactions/#{transaction.hash}")

        assert %{"allowed_peekers" => ["0x3078505152535455565758595a5b5C5D5E5f6061"]} = json_response(request, 200)
      end
    end

    if @chain_type == :optimism do
      test "returns transaction with interop message", %{conn: conn} do
        transaction = insert(:transaction)

        insert(:op_interop_message,
          init_transaction_hash: transaction.hash,
          payload: "0x30787849009c24f10a91a327a9f2ed94ebc49ee9"
        )

        request = get(conn, "/api/v2/transactions/#{transaction.hash}")

        assert %{"op_interop_messages" => [%{"payload" => "0x30787849009c24f10a91a327a9f2ed94ebc49ee9"}]} =
                 json_response(request, 200)
      end
    end
  end

  describe "/transactions/{transaction_hash}/internal-transactions" do
    test "return 404 on non existing transaction", %{conn: conn} do
      transaction = build(:transaction)
      request = get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}/internal-transactions")

      assert %{"message" => "Not found"} = json_response(request, 404)
    end

    test "return 422 on invalid transaction hash", %{conn: conn} do
      request = get(conn, "/api/v2/transactions/0x/internal-transactions")

      assert %{
               "errors" => [
                 %{
                   "detail" => "Invalid format. Expected ~r/^0x([A-Fa-f0-9]{64})$/",
                   "source" => %{"pointer" => "/transaction_hash_param"},
                   "title" => "Invalid value"
                 }
               ]
             } = json_response(request, 422)
    end

    test "return empty list", %{conn: conn} do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      request = get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}/internal-transactions")

      assert response = json_response(request, 200)
      assert response["items"] == []
      assert response["next_page_params"] == nil
    end

    test "return relevant internal transaction", %{conn: conn} do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(:internal_transaction,
        transaction: transaction,
        index: 0,
        block_number: transaction.block_number,
        transaction_index: transaction.index,
        block_hash: transaction.block_hash
      )

      internal_transaction =
        insert(:internal_transaction,
          transaction: transaction,
          index: 1,
          block_number: transaction.block_number,
          transaction_index: transaction.index,
          block_hash: transaction.block_hash
        )

      transaction_1 =
        :transaction
        |> insert()
        |> with_block()

      0..5
      |> Enum.map(fn index ->
        insert(:internal_transaction,
          transaction: transaction_1,
          index: index,
          block_number: transaction_1.block_number,
          transaction_index: transaction_1.index,
          block_hash: transaction_1.block_hash
        )
      end)

      request = get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}/internal-transactions")

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 1
      assert response["next_page_params"] == nil
      compare_item(internal_transaction, Enum.at(response["items"], 0))
    end

    test "return list with next_page_params", %{conn: conn} do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(:internal_transaction,
        transaction: transaction,
        index: 0,
        block_number: transaction.block_number,
        transaction_index: transaction.index,
        block_hash: transaction.block_hash
      )

      internal_transactions =
        51..1//-1
        |> Enum.map(fn index ->
          insert(:internal_transaction,
            transaction: transaction,
            index: index,
            block_number: transaction.block_number,
            transaction_index: transaction.index,
            block_hash: transaction.block_hash
          )
        end)

      request = get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}/internal-transactions")
      assert response = json_response(request, 200)

      request_2nd_page =
        get(
          conn,
          "/api/v2/transactions/#{to_string(transaction.hash)}/internal-transactions",
          response["next_page_params"]
        )

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, internal_transactions)
    end
  end

  describe "/transactions/{transaction_hash}/logs" do
    test "return 404 on non existing transaction", %{conn: conn} do
      transaction = build(:transaction)
      request = get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}/logs")

      assert %{"message" => "Not found"} = json_response(request, 404)
    end

    test "return 422 on invalid transaction hash", %{conn: conn} do
      request = get(conn, "/api/v2/transactions/0x/logs")

      assert %{
               "errors" => [
                 %{
                   "detail" => "Invalid format. Expected ~r/^0x([A-Fa-f0-9]{64})$/",
                   "source" => %{"pointer" => "/transaction_hash_param"},
                   "title" => "Invalid value"
                 }
               ]
             } = json_response(request, 422)
    end

    test "return empty list", %{conn: conn} do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      request = get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}/logs")

      assert response = json_response(request, 200)
      assert response["items"] == []
      assert response["next_page_params"] == nil
    end

    test "return relevant log", %{conn: conn} do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      log =
        insert(:log,
          transaction: transaction,
          index: 1,
          block: transaction.block,
          block_number: transaction.block_number
        )

      transaction_1 =
        :transaction
        |> insert()
        |> with_block()

      0..5
      |> Enum.map(fn index ->
        insert(:log,
          transaction: transaction_1,
          index: index,
          block: transaction_1.block,
          block_number: transaction_1.block_number
        )
      end)

      request = get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}/logs")

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 1
      assert response["next_page_params"] == nil
      compare_item(log, Enum.at(response["items"], 0))
    end

    test "return list with next_page_params", %{conn: conn} do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      logs =
        50..0//-1
        |> Enum.map(fn index ->
          insert(:log,
            transaction: transaction,
            index: index,
            block: transaction.block,
            block_number: transaction.block_number
          )
        end)

      request = get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}/logs")
      assert response = json_response(request, 200)

      request_2nd_page =
        get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}/logs", response["next_page_params"])

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, logs)
    end
  end

  describe "/transactions/{transaction_hash}/token-transfers" do
    test "get token-transfers with ok reputation", %{conn: conn} do
      init_value = Application.get_env(:block_scout_web, :hide_scam_addresses)
      Application.put_env(:block_scout_web, :hide_scam_addresses, true)
      on_exit(fn -> Application.put_env(:block_scout_web, :hide_scam_addresses, init_value) end)

      token = insert(:token, type: "ERC-1155")

      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(:token_transfer,
        transaction: transaction,
        block: transaction.block,
        block_number: transaction.block_number,
        token_contract_address: token.contract_address,
        token_ids: Enum.map(0..50, fn x -> x end),
        token_type: "ERC-1155",
        amounts: Enum.map(0..50, fn x -> x end)
      )

      request =
        conn
        |> put_req_cookie("show_scam_tokens", "true")
        |> get("/api/v2/transactions/#{transaction.hash}/token-transfers")

      response = json_response(request, 200)

      assert List.first(response["items"])["token"]["reputation"] == "ok"

      assert response == conn |> get("/api/v2/transactions/#{transaction.hash}/token-transfers") |> json_response(200)
    end

    test "get smart-contract with scam reputation", %{conn: conn} do
      init_value = Application.get_env(:block_scout_web, :hide_scam_addresses)
      Application.put_env(:block_scout_web, :hide_scam_addresses, true)
      on_exit(fn -> Application.put_env(:block_scout_web, :hide_scam_addresses, init_value) end)

      token = insert(:token, type: "ERC-1155")

      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(:token_transfer,
        transaction: transaction,
        block: transaction.block,
        block_number: transaction.block_number,
        token_contract_address: token.contract_address,
        token_ids: Enum.map(0..50, fn x -> x end),
        token_type: "ERC-1155",
        amounts: Enum.map(0..50, fn x -> x end)
      )

      insert(:scam_badge_to_address, address_hash: token.contract_address_hash)

      request =
        conn
        |> put_req_cookie("show_scam_tokens", "true")
        |> get("/api/v2/transactions/#{transaction.hash}/token-transfers")

      response = json_response(request, 200)

      assert List.first(response["items"])["token"]["reputation"] == "scam"

      request = conn |> get("/api/v2/transactions/#{transaction.hash}/token-transfers")
      response = json_response(request, 200)

      assert response["items"] == []
    end

    test "get token-transfers with ok reputation with hide_scam_addresses=false", %{conn: conn} do
      init_value = Application.get_env(:block_scout_web, :hide_scam_addresses)
      Application.put_env(:block_scout_web, :hide_scam_addresses, false)
      on_exit(fn -> Application.put_env(:block_scout_web, :hide_scam_addresses, init_value) end)

      token = insert(:token, type: "ERC-1155")

      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(:token_transfer,
        transaction: transaction,
        block: transaction.block,
        block_number: transaction.block_number,
        token_contract_address: token.contract_address,
        token_ids: Enum.map(0..50, fn x -> x end),
        token_type: "ERC-1155",
        amounts: Enum.map(0..50, fn x -> x end)
      )

      request = conn |> get("/api/v2/transactions/#{transaction.hash}/token-transfers")
      response = json_response(request, 200)

      assert List.first(response["items"])["token"]["reputation"] == "ok"
    end

    test "get token-transfers with scam reputation with hide_scam_addresses=false", %{conn: conn} do
      init_value = Application.get_env(:block_scout_web, :hide_scam_addresses)
      Application.put_env(:block_scout_web, :hide_scam_addresses, false)
      on_exit(fn -> Application.put_env(:block_scout_web, :hide_scam_addresses, init_value) end)

      token = insert(:token, type: "ERC-1155")

      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(:token_transfer,
        transaction: transaction,
        block: transaction.block,
        block_number: transaction.block_number,
        token_contract_address: token.contract_address,
        token_ids: Enum.map(0..50, fn x -> x end),
        token_type: "ERC-1155",
        amounts: Enum.map(0..50, fn x -> x end)
      )

      insert(:scam_badge_to_address, address_hash: token.contract_address_hash)

      request = conn |> get("/api/v2/transactions/#{transaction.hash}/token-transfers")
      response = json_response(request, 200)

      assert List.first(response["items"])["token"]["reputation"] == "ok"
    end

    test "return 404 on non existing transaction", %{conn: conn} do
      transaction = build(:transaction)
      request = get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}/token-transfers")

      assert %{"message" => "Not found"} = json_response(request, 404)
    end

    test "return 422 on invalid transaction hash", %{conn: conn} do
      request = get(conn, "/api/v2/transactions/0x/token-transfers")

      assert %{
               "errors" => [
                 %{
                   "detail" => "Invalid format. Expected ~r/^0x([A-Fa-f0-9]{64})$/",
                   "source" => %{"pointer" => "/transaction_hash_param"},
                   "title" => "Invalid value"
                 }
               ]
             } = json_response(request, 422)
    end

    test "return empty list", %{conn: conn} do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      request = get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}/token-transfers")

      assert response = json_response(request, 200)
      assert response["items"] == []
      assert response["next_page_params"] == nil
    end

    test "return relevant token transfer", %{conn: conn} do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      token_transfer =
        insert(:token_transfer,
          transaction: transaction,
          block: transaction.block,
          block_number: transaction.block_number
        )

      transaction_1 =
        :transaction
        |> insert()
        |> with_block()

      insert_list(6, :token_transfer,
        transaction: transaction_1,
        block: transaction_1.block,
        block_number: transaction_1.block_number
      )

      request = get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}/token-transfers")

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 1
      assert response["next_page_params"] == nil
      compare_item(token_transfer, Enum.at(response["items"], 0))
    end

    test "return list with next_page_params", %{conn: conn} do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      token_transfers =
        insert_list(51, :token_transfer,
          transaction: transaction,
          block: transaction.block,
          block_number: transaction.block_number
        )
        |> Enum.reverse()

      request = get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}/token-transfers")
      assert response = json_response(request, 200)

      request_2nd_page =
        get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}/token-transfers", response["next_page_params"])

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, token_transfers)
    end

    test "check filters", %{conn: conn} do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      erc_1155_token = insert(:token, type: "ERC-1155")

      erc_1155_tt =
        for x <- 0..50 do
          insert(:token_transfer,
            transaction: transaction,
            block: transaction.block,
            block_number: transaction.block_number,
            token_contract_address: erc_1155_token.contract_address,
            token_ids: [x],
            token_type: "ERC-1155"
          )
        end
        |> Enum.reverse()

      erc_721_token = insert(:token, type: "ERC-721")

      erc_721_tt =
        for x <- 0..50 do
          insert(:token_transfer,
            transaction: transaction,
            block: transaction.block,
            block_number: transaction.block_number,
            token_contract_address: erc_721_token.contract_address,
            token_ids: [x],
            token_type: "ERC-721"
          )
        end
        |> Enum.reverse()

      erc_20_token = insert(:token, type: "ERC-20")

      erc_20_tt =
        for _ <- 0..50 do
          insert(:token_transfer,
            transaction: transaction,
            block: transaction.block,
            block_number: transaction.block_number,
            token_contract_address: erc_20_token.contract_address,
            token_type: "ERC-20"
          )
        end
        |> Enum.reverse()

      # -- ERC-20 --
      filter = %{"type" => "ERC-20"}
      request = get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}/token-transfers", filter)
      assert response = json_response(request, 200)

      request_2nd_page =
        get(
          conn,
          "/api/v2/transactions/#{to_string(transaction.hash)}/token-transfers",
          Map.merge(response["next_page_params"], filter)
        )

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, erc_20_tt)
      # -- ------ --

      # -- ERC-721 --
      filter = %{"type" => "ERC-721"}
      request = get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}/token-transfers", filter)
      assert response = json_response(request, 200)

      request_2nd_page =
        get(
          conn,
          "/api/v2/transactions/#{to_string(transaction.hash)}/token-transfers",
          Map.merge(response["next_page_params"], filter)
        )

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, erc_721_tt)
      # -- ------ --

      # -- ERC-1155 --
      filter = %{"type" => "ERC-1155"}
      request = get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}/token-transfers", filter)
      assert response = json_response(request, 200)

      request_2nd_page =
        get(
          conn,
          "/api/v2/transactions/#{to_string(transaction.hash)}/token-transfers",
          Map.merge(response["next_page_params"], filter)
        )

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, erc_1155_tt)
      # -- ------ --

      # two filters simultaneously
      filter = %{"type" => "ERC-1155,ERC-20,ERC-7984"}
      request = get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}/token-transfers", filter)
      assert response = json_response(request, 200)

      request_2nd_page =
        get(
          conn,
          "/api/v2/transactions/#{to_string(transaction.hash)}/token-transfers",
          Map.merge(response["next_page_params"], filter)
        )

      assert response_2nd_page = json_response(request_2nd_page, 200)

      # Note: filter now includes ERC-7984, but we didn't create any ERC-7984 transfers in this test
      # So the pagination behavior remains the same as before
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
          "/api/v2/transactions/#{to_string(transaction.hash)}/token-transfers",
          Map.merge(response_2nd_page["next_page_params"], filter)
        )

      assert response_3rd_page = json_response(request_3rd_page, 200)
      assert Enum.count(response_3rd_page["items"]) == 2
      assert response_3rd_page["next_page_params"] == nil
      compare_item(Enum.at(erc_20_tt, 1), Enum.at(response_3rd_page["items"], 0))
      compare_item(Enum.at(erc_20_tt, 0), Enum.at(response_3rd_page["items"], 1))
    end

    test "check that same token_ids within batch squashes", %{conn: conn} do
      token = insert(:token, type: "ERC-1155")

      id = 0

      insert(:token_instance, token_id: id, token_contract_address_hash: token.contract_address_hash)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      tt =
        for _ <- 0..50 do
          insert(:token_transfer,
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

      request = get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}/token-transfers")
      assert response = json_response(request, 200)

      request_2nd_page =
        get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}/token-transfers", response["next_page_params"])

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, Enum.reverse(token_transfers))
    end

    test "check that pagination works for 721 tokens", %{conn: conn} do
      token = insert(:token, type: "ERC-721")

      transaction =
        :transaction
        |> insert()
        |> with_block()

      token_transfers =
        for i <- 0..50 do
          insert(:token_transfer,
            transaction: transaction,
            block: transaction.block,
            block_number: transaction.block_number,
            token_contract_address: token.contract_address,
            token_ids: [i],
            token_type: "ERC-721"
          )
        end

      request = get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}/token-transfers")
      assert response = json_response(request, 200)

      request_2nd_page =
        get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}/token-transfers", response["next_page_params"])

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, Enum.reverse(token_transfers))
    end

    test "check that pagination works fine with 1155 batches #1 (large batch)", %{conn: conn} do
      token = insert(:token, type: "ERC-1155")

      transaction =
        :transaction
        |> insert()
        |> with_block()

      tt =
        insert(:token_transfer,
          transaction: transaction,
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

      request = get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}/token-transfers")
      assert response = json_response(request, 200)

      request_2nd_page =
        get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}/token-transfers", response["next_page_params"])

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, token_transfers)
    end

    test "check that pagination works fine with 1155 batches #2 some batches on the first page and one on the second",
         %{conn: conn} do
      token = insert(:token, type: "ERC-1155")

      transaction =
        :transaction
        |> insert()
        |> with_block()

      tt_1 =
        insert(:token_transfer,
          transaction: transaction,
          block: transaction.block,
          block_number: transaction.block_number,
          token_contract_address: token.contract_address,
          token_ids: Enum.map(0..24, fn x -> x end),
          token_type: "ERC-1155",
          amounts: Enum.map(0..24, fn x -> x end)
        )

      token_transfers_1 =
        for i <- 0..24 do
          %TokenTransfer{tt_1 | token_ids: [i], amount: i}
        end

      tt_2 =
        insert(:token_transfer,
          transaction: transaction,
          block: transaction.block,
          block_number: transaction.block_number,
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
          transaction: transaction,
          block: transaction.block,
          block_number: transaction.block_number,
          token_contract_address: token.contract_address,
          token_ids: [50],
          token_type: "ERC-1155",
          amounts: [50]
        )

      request = get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}/token-transfers")
      assert response = json_response(request, 200)

      request_2nd_page =
        get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}/token-transfers", response["next_page_params"])

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, [tt_3] ++ token_transfers_2 ++ token_transfers_1)
    end

    test "check that pagination works fine with 1155 batches #3", %{conn: conn} do
      token = insert(:token, type: "ERC-1155")

      transaction = insert(:transaction, input: "0xabcd010203040506") |> with_block()

      tt_1 =
        insert(:token_transfer,
          transaction: transaction,
          block: transaction.block,
          block_number: transaction.block_number,
          token_contract_address: token.contract_address,
          token_ids: Enum.map(0..24, fn x -> x end),
          token_type: "ERC-1155",
          amounts: Enum.map(0..24, fn x -> x end)
        )

      token_transfers_1 =
        for i <- 0..24 do
          %TokenTransfer{tt_1 | token_ids: [i], amount: i}
        end

      tt_2 =
        insert(:token_transfer,
          transaction: transaction,
          block: transaction.block,
          block_number: transaction.block_number,
          token_contract_address: token.contract_address,
          token_ids: Enum.map(25..50, fn x -> x end),
          token_type: "ERC-1155",
          amounts: Enum.map(25..50, fn x -> x end)
        )

      token_transfers_2 =
        for i <- 25..50 do
          %TokenTransfer{tt_2 | token_ids: [i], amount: i}
        end

      request = get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}/token-transfers")
      assert response = json_response(request, 200)

      request_2nd_page =
        get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}/token-transfers", response["next_page_params"])

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, token_transfers_2 ++ token_transfers_1)
    end
  end

  describe "/transactions/{transaction_hash}/state-changes" do
    test "return 404 on non existing transaction", %{conn: conn} do
      transaction = build(:transaction)
      request = get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}/state-changes")

      assert %{"message" => "Not found"} = json_response(request, 404)
    end

    test "return 422 on invalid transaction hash", %{conn: conn} do
      request = get(conn, "/api/v2/transactions/0x/state-changes")

      assert %{
               "errors" => [
                 %{
                   "detail" => "Invalid format. Expected ~r/^0x([A-Fa-f0-9]{64})$/",
                   "source" => %{"pointer" => "/transaction_hash_param"},
                   "title" => "Invalid value"
                 }
               ]
             } = json_response(request, 422)
    end

    test "accepts pagination params", %{conn: conn} do
      transaction =
        :transaction
        |> insert()
        |> with_block(status: :ok)

      request =
        get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}/state-changes?items_count=50&state_changes=null")

      assert %{} = json_response(request, 200)
    end

    test "return existing transaction", %{conn: conn} do
      block_before = insert(:block)

      transaction =
        :transaction
        |> insert()
        |> with_block(status: :ok)

      insert(:address_coin_balance,
        address: transaction.from_address,
        address_hash: transaction.from_address_hash,
        block_number: block_before.number
      )

      insert(:address_coin_balance,
        address: transaction.to_address,
        address_hash: transaction.to_address_hash,
        block_number: block_before.number
      )

      insert(:address_coin_balance,
        address: transaction.block.miner,
        address_hash: transaction.block.miner_hash,
        block_number: block_before.number
      )

      request = get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}/state-changes")

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 3
    end

    test "does not include internal transaction with index 0", %{conn: conn} do
      block_before = insert(:block)

      transaction =
        :transaction
        |> insert()
        |> with_block(status: :ok)

      internal_transaction_from = insert(:address)
      internal_transaction_to = insert(:address)

      insert(:internal_transaction,
        transaction: transaction,
        index: 0,
        block_number: transaction.block_number,
        transaction_index: transaction.index,
        block_hash: transaction.block_hash,
        value: %Wei{value: Decimal.new(7)},
        from_address_hash: internal_transaction_from.hash,
        from_address: internal_transaction_from,
        to_address_hash: internal_transaction_to.hash,
        to_address: internal_transaction_to
      )

      insert(:address_coin_balance,
        address: transaction.from_address,
        address_hash: transaction.from_address_hash,
        block_number: block_before.number
      )

      insert(:address_coin_balance,
        address: transaction.to_address,
        address_hash: transaction.to_address_hash,
        block_number: block_before.number
      )

      insert(:address_coin_balance,
        address: transaction.block.miner,
        address_hash: transaction.block.miner_hash,
        block_number: block_before.number
      )

      insert(:address_coin_balance,
        address: internal_transaction_from,
        address_hash: internal_transaction_from.hash,
        block_number: block_before.number
      )

      insert(:address_coin_balance,
        address: internal_transaction_to,
        address_hash: internal_transaction_to.hash,
        block_number: block_before.number
      )

      request = get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}/state-changes")

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 3
    end

    test "return entries from internal transaction", %{conn: conn} do
      block_before = insert(:block)

      transaction =
        :transaction
        |> insert()
        |> with_block(status: :ok)

      internal_transaction_from = insert(:address)
      internal_transaction_to = insert(:address)

      internal_transaction_from_delegatecall = insert(:address)
      internal_transaction_to_delegatecall = insert(:address)

      insert(:internal_transaction,
        call_type: :call,
        transaction: transaction,
        index: 0,
        block_number: transaction.block_number,
        transaction_index: transaction.index,
        block_hash: transaction.block_hash,
        value: %Wei{value: Decimal.new(7)},
        from_address_hash: internal_transaction_from.hash,
        from_address: internal_transaction_from,
        to_address_hash: internal_transaction_to.hash,
        to_address: internal_transaction_to
      )

      # must be ignored, hence we expect only 5 state changes
      insert(:internal_transaction,
        call_type: :delegatecall,
        transaction: transaction,
        index: 1,
        block_number: transaction.block_number,
        transaction_index: transaction.index,
        block_hash: transaction.block_hash,
        value: %Wei{value: Decimal.new(7)},
        from_address_hash: internal_transaction_from_delegatecall.hash,
        from_address: internal_transaction_from_delegatecall,
        to_address_hash: internal_transaction_to_delegatecall.hash,
        to_address: internal_transaction_to_delegatecall
      )

      insert(:internal_transaction,
        call_type: :call,
        transaction: transaction,
        index: 2,
        block_number: transaction.block_number,
        transaction_index: transaction.index,
        block_hash: transaction.block_hash,
        value: %Wei{value: Decimal.new(7)},
        from_address_hash: internal_transaction_from.hash,
        from_address: internal_transaction_from,
        to_address_hash: internal_transaction_to.hash,
        to_address: internal_transaction_to
      )

      insert(:address_coin_balance,
        address: transaction.from_address,
        address_hash: transaction.from_address_hash,
        block_number: block_before.number,
        value: %Wei{value: Decimal.new(1000)}
      )

      insert(:address_coin_balance,
        address: transaction.to_address,
        address_hash: transaction.to_address_hash,
        block_number: block_before.number,
        value: %Wei{value: Decimal.new(1000)}
      )

      insert(:address_coin_balance,
        address: transaction.block.miner,
        address_hash: transaction.block.miner_hash,
        block_number: block_before.number,
        value: %Wei{value: Decimal.new(1000)}
      )

      insert(:address_coin_balance,
        address: internal_transaction_from,
        address_hash: internal_transaction_from.hash,
        block_number: block_before.number,
        value: %Wei{value: Decimal.new(1000)}
      )

      insert(:address_coin_balance,
        address: internal_transaction_to,
        address_hash: internal_transaction_to.hash,
        block_number: block_before.number,
        value: %Wei{value: Decimal.new(1000)}
      )

      request = get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}/state-changes")

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 5
    end

    test "return state changes with token transfers and verify token is correctly loaded", %{conn: conn} do
      block_before = insert(:block)

      transaction =
        :transaction
        |> insert()
        |> with_block(status: :ok)

      token = insert(:token, type: "ERC-20", symbol: "TEST", name: "Test Token")
      from_address = insert(:address)
      to_address = insert(:address)

      # Create token transfer
      insert(:token_transfer,
        transaction: transaction,
        block: transaction.block,
        block_number: transaction.block_number,
        token_contract_address: token.contract_address,
        token_contract_address_hash: token.contract_address_hash,
        from_address: from_address,
        from_address_hash: from_address.hash,
        to_address: to_address,
        to_address_hash: to_address.hash,
        amount: Decimal.new(100),
        token: token,
        token_ids: nil
      )

      # Set up coin balances for transaction participants
      insert(:address_coin_balance,
        address: transaction.from_address,
        address_hash: transaction.from_address_hash,
        block_number: block_before.number,
        value: %Wei{value: Decimal.new(1000)}
      )

      insert(:address_coin_balance,
        address: transaction.to_address,
        address_hash: transaction.to_address_hash,
        block_number: block_before.number,
        value: %Wei{value: Decimal.new(1000)}
      )

      insert(:address_coin_balance,
        address: transaction.block.miner,
        address_hash: transaction.block.miner_hash,
        block_number: block_before.number,
        value: %Wei{value: Decimal.new(1000)}
      )

      # Set up token balances
      insert(:address_current_token_balance,
        address: from_address,
        address_hash: from_address.hash,
        token_contract_address_hash: token.contract_address_hash,
        block_number: block_before.number,
        value: Decimal.new(1000)
      )

      insert(:address_current_token_balance,
        address: to_address,
        address_hash: to_address.hash,
        token_contract_address_hash: token.contract_address_hash,
        block_number: block_before.number,
        value: Decimal.new(0)
      )

      request = get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}/state-changes")

      assert response = json_response(request, 200)
      assert is_list(response["items"])

      # Find the token state changes (should have at least from and to addresses)
      token_state_changes = Enum.filter(response["items"], fn item -> item["type"] == "token" end)
      assert length(token_state_changes) >= 2

      # Verify token information is properly loaded in at least one state change
      token_state_change = Enum.find(token_state_changes, fn item -> not is_nil(item["token"]) end)
      assert token_state_change

      token_data = token_state_change["token"]
      assert token_data["symbol"] == "TEST"
      assert token_data["name"] == "Test Token"
      assert token_data["type"] == "ERC-20"
      assert token_data["address_hash"] == to_string(token.contract_address)
      assert token_data["reputation"] == "ok"
    end

    test "return state changes with scam token reputation properly set", %{conn: conn} do
      init_value = Application.get_env(:block_scout_web, :hide_scam_addresses)
      Application.put_env(:block_scout_web, :hide_scam_addresses, true)
      on_exit(fn -> Application.put_env(:block_scout_web, :hide_scam_addresses, init_value) end)

      block_before = insert(:block)

      transaction =
        :transaction
        |> insert()
        |> with_block(status: :ok)

      # Create a token
      token = insert(:token, type: "ERC-20", symbol: "SCAM", name: "Scam Token")
      from_address = insert(:address)
      to_address = insert(:address)

      # Create scam badge for the token address to mark it as scam
      insert(:scam_badge_to_address, address_hash: token.contract_address_hash)

      # Create token transfer
      insert(:token_transfer,
        transaction: transaction,
        block: transaction.block,
        block_number: transaction.block_number,
        token_contract_address: token.contract_address,
        token_contract_address_hash: token.contract_address_hash,
        from_address: from_address,
        from_address_hash: from_address.hash,
        to_address: to_address,
        to_address_hash: to_address.hash,
        amount: Decimal.new(100),
        token: token,
        token_ids: nil
      )

      # Set up coin balances for transaction participants
      insert(:address_coin_balance,
        address: transaction.from_address,
        address_hash: transaction.from_address_hash,
        block_number: block_before.number,
        value: %Wei{value: Decimal.new(1000)}
      )

      insert(:address_coin_balance,
        address: transaction.to_address,
        address_hash: transaction.to_address_hash,
        block_number: block_before.number,
        value: %Wei{value: Decimal.new(1000)}
      )

      insert(:address_coin_balance,
        address: transaction.block.miner,
        address_hash: transaction.block.miner_hash,
        block_number: block_before.number,
        value: %Wei{value: Decimal.new(1000)}
      )

      # Set up token balances
      insert(:address_current_token_balance,
        address: from_address,
        address_hash: from_address.hash,
        token_contract_address_hash: token.contract_address_hash,
        block_number: block_before.number,
        value: Decimal.new(1000)
      )

      insert(:address_current_token_balance,
        address: to_address,
        address_hash: to_address.hash,
        token_contract_address_hash: token.contract_address_hash,
        block_number: block_before.number,
        value: Decimal.new(0)
      )

      request = get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}/state-changes")

      assert response = json_response(request, 200)
      assert is_list(response["items"])

      # Find the token state changes
      token_state_changes = Enum.filter(response["items"], fn item -> item["type"] == "token" end)
      assert length(token_state_changes) >= 2

      # Verify that the token has scam reputation
      token_state_change = Enum.find(token_state_changes, fn item -> not is_nil(item["token"]) end)
      assert token_state_change

      token_data = token_state_change["token"]
      assert token_data["reputation"] == "scam"
      assert token_data["symbol"] == "SCAM"
      assert token_data["name"] == "Scam Token"
      assert token_data["address_hash"] == to_string(token.contract_address)
    end
  end

  if @chain_identity == {:optimism, :celo} do
    describe "celo gas token" do
      test "when gas is paid with token and token is present in db", %{conn: conn} do
        token = insert(:token)

        transaction =
          :transaction
          |> insert(gas_token_contract_address: token.contract_address)
          |> with_block()

        request = get(conn, "/api/v2/transactions")

        token_address_hash = Address.checksum(token.contract_address_hash)
        token_type = token.type
        token_name = token.name
        token_symbol = token.symbol

        assert %{
                 "items" => [
                   %{
                     "celo" => %{
                       "gas_token" => %{
                         "address_hash" => ^token_address_hash,
                         "name" => ^token_name,
                         "symbol" => ^token_symbol,
                         "type" => ^token_type
                       }
                     }
                   }
                 ]
               } = json_response(request, 200)

        request = get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}")

        assert %{
                 "celo" => %{
                   "gas_token" => %{
                     "address_hash" => ^token_address_hash,
                     "name" => ^token_name,
                     "symbol" => ^token_symbol,
                     "type" => ^token_type
                   }
                 }
               } = json_response(request, 200)

        request = get(conn, "/api/v2/addresses/#{to_string(transaction.from_address_hash)}/transactions")

        assert %{
                 "items" => [
                   %{
                     "celo" => %{
                       "gas_token" => %{
                         "address_hash" => ^token_address_hash,
                         "name" => ^token_name,
                         "symbol" => ^token_symbol,
                         "type" => ^token_type
                       }
                     }
                   }
                 ]
               } = json_response(request, 200)

        request = get(conn, "/api/v2/main-page/transactions")

        assert [
                 %{
                   "celo" => %{
                     "gas_token" => %{
                       "address_hash" => ^token_address_hash,
                       "name" => ^token_name,
                       "symbol" => ^token_symbol,
                       "type" => ^token_type
                     }
                   }
                 }
               ] = json_response(request, 200)
      end

      test "when gas is paid with token and token is not present in db", %{conn: conn} do
        unknown_token_address = insert(:address)

        transaction =
          :transaction
          |> insert(gas_token_contract_address: unknown_token_address)
          |> with_block()

        unknown_token_address_hash = Address.checksum(unknown_token_address.hash)

        request = get(conn, "/api/v2/transactions")

        assert %{
                 "items" => [
                   %{
                     "celo" => %{
                       "gas_token" => %{
                         "address_hash" => ^unknown_token_address_hash
                       }
                     }
                   }
                 ]
               } = json_response(request, 200)

        request = get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}")

        assert %{
                 "celo" => %{
                   "gas_token" => %{
                     "address_hash" => ^unknown_token_address_hash
                   }
                 }
               } = json_response(request, 200)

        request = get(conn, "/api/v2/addresses/#{to_string(transaction.from_address_hash)}/transactions")

        assert %{
                 "items" => [
                   %{
                     "celo" => %{
                       "gas_token" => %{
                         "address_hash" => ^unknown_token_address_hash
                       }
                     }
                   }
                 ]
               } = json_response(request, 200)

        request = get(conn, "/api/v2/main-page/transactions")

        assert [
                 %{
                   "celo" => %{
                     "gas_token" => %{
                       "address_hash" => ^unknown_token_address_hash
                     }
                   }
                 }
               ] = json_response(request, 200)
      end

      test "when gas is paid in native coin", %{conn: conn} do
        transaction = :transaction |> insert() |> with_block()

        request = get(conn, "/api/v2/transactions")

        assert %{
                 "items" => [
                   %{
                     "celo" => %{"gas_token" => nil}
                   }
                 ]
               } = json_response(request, 200)

        request = get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}")

        assert %{
                 "celo" => %{"gas_token" => nil}
               } = json_response(request, 200)

        request = get(conn, "/api/v2/addresses/#{to_string(transaction.from_address_hash)}/transactions")

        assert %{
                 "items" => [
                   %{
                     "celo" => %{"gas_token" => nil}
                   }
                 ]
               } = json_response(request, 200)

        request = get(conn, "/api/v2/main-page/transactions")

        assert [
                 %{
                   "celo" => %{"gas_token" => nil}
                 }
               ] = json_response(request, 200)
      end
    end
  end

  describe "/transactions/{transaction_hash}/raw-trace" do
    test "returns raw trace from node", %{conn: conn} do
      transaction =
        :transaction
        |> insert()
        |> with_block(status: :ok)

      raw_trace = %{
        "action" => %{
          "callType" => "call",
          "from" => "0xa931c862e662134b85e4dc4baf5c70cc9ba74db4",
          "to" => "0x1469b17ebf82fedf56f04109e5207bdc4554288c",
          "gas" => "0x8600",
          "input" => "0xb118e2db0000000000000000000000000000000000000000000000000000000000000008",
          "value" => "0x174876e800"
        },
        "result" => %{
          "gasUsed" => "0x7d37",
          "output" => "0x"
        },
        "subtraces" => 0,
        "traceAddress" => [],
        "transactionHash" => to_string(transaction.hash),
        "type" => "call"
      }

      expect(EthereumJSONRPC.Mox, :json_rpc, fn _, _ -> {:ok, [raw_trace]} end)

      request = get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}/raw-trace")

      assert response = json_response(request, 200)
      assert response == [raw_trace]
    end

    test "returns correct error", %{conn: conn} do
      transaction =
        :transaction
        |> insert()
        |> with_block(status: :ok)

      expect(EthereumJSONRPC.Mox, :json_rpc, fn _, _ -> {:error, "error"} end)

      request = get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}/raw-trace")

      assert response = json_response(request, 500)
      assert response == "Error while raw trace fetching"
    end
  end

  if Application.compile_env(:explorer, :chain_type) == :stability do
    @first_topic_hex_string_1 "0x99e7b0ba56da2819c37c047f0511fd2bf6c9b4e27b4a979a19d6da0f74be8155"

    describe "stability fees" do
      test "check stability fees", %{conn: conn} do
        transaction = insert(:transaction) |> with_block()

        _log =
          insert(:log,
            transaction: transaction,
            index: 1,
            block: transaction.block,
            block_number: transaction.block_number,
            first_topic: TestHelper.topic(@first_topic_hex_string_1),
            data:
              "0x000000000000000000000000dc2b93f3291030f3f7a6d9363ac37757f7ad5c4300000000000000000000000000000000000000000000000000002824369a100000000000000000000000000046b555cb3962bf9533c437cbd04a2f702dfdb999000000000000000000000000000000000000000000000000000014121b4d0800000000000000000000000000faf7a981360c2fab3a5ab7b3d6d8d0cf97a91eb9000000000000000000000000000000000000000000000000000014121b4d0800"
          )

        insert(:token, contract_address: build(:address, hash: "0xDc2B93f3291030F3F7a6D9363ac37757f7AD5C43"))
        request = get(conn, "/api/v2/transactions")

        assert %{
                 "items" => [
                   %{
                     "stability_fee" => %{
                       "token" => %{"address_hash" => "0xDc2B93f3291030F3F7a6D9363ac37757f7AD5C43"},
                       "validator_address" => %{"hash" => "0x46B555CB3962bF9533c437cBD04A2f702dfdB999"},
                       "dapp_address" => %{"hash" => "0xFAf7a981360c2FAb3a5Ab7b3D6d8D0Cf97a91Eb9"},
                       "total_fee" => "44136000000000",
                       "dapp_fee" => "22068000000000",
                       "validator_fee" => "22068000000000"
                     }
                   }
                 ]
               } = json_response(request, 200)

        request = get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}")

        assert %{
                 "stability_fee" => %{
                   "token" => %{"address_hash" => "0xDc2B93f3291030F3F7a6D9363ac37757f7AD5C43"},
                   "validator_address" => %{"hash" => "0x46B555CB3962bF9533c437cBD04A2f702dfdB999"},
                   "dapp_address" => %{"hash" => "0xFAf7a981360c2FAb3a5Ab7b3D6d8D0Cf97a91Eb9"},
                   "total_fee" => "44136000000000",
                   "dapp_fee" => "22068000000000",
                   "validator_fee" => "22068000000000"
                 }
               } = json_response(request, 200)

        request = get(conn, "/api/v2/addresses/#{to_string(transaction.from_address_hash)}/transactions")

        assert %{
                 "items" => [
                   %{
                     "stability_fee" => %{
                       "token" => %{"address_hash" => "0xDc2B93f3291030F3F7a6D9363ac37757f7AD5C43"},
                       "validator_address" => %{"hash" => "0x46B555CB3962bF9533c437cBD04A2f702dfdB999"},
                       "dapp_address" => %{"hash" => "0xFAf7a981360c2FAb3a5Ab7b3D6d8D0Cf97a91Eb9"},
                       "total_fee" => "44136000000000",
                       "dapp_fee" => "22068000000000",
                       "validator_fee" => "22068000000000"
                     }
                   }
                 ]
               } = json_response(request, 200)
      end

      test "check stability if token absent in DB", %{conn: conn} do
        transaction = insert(:transaction) |> with_block()

        _log =
          insert(:log,
            transaction: transaction,
            index: 1,
            block: transaction.block,
            block_number: transaction.block_number,
            first_topic: TestHelper.topic(@first_topic_hex_string_1),
            data:
              "0x000000000000000000000000dc2b93f3291030f3f7a6d9363ac37757f7ad5c4300000000000000000000000000000000000000000000000000002824369a100000000000000000000000000046b555cb3962bf9533c437cbd04a2f702dfdb999000000000000000000000000000000000000000000000000000014121b4d0800000000000000000000000000faf7a981360c2fab3a5ab7b3d6d8d0cf97a91eb9000000000000000000000000000000000000000000000000000014121b4d0800"
          )

        request = get(conn, "/api/v2/transactions")

        assert %{
                 "items" => [
                   %{
                     "stability_fee" => %{
                       "token" => %{"address_hash" => "0xDc2B93f3291030F3F7a6D9363ac37757f7AD5C43"},
                       "validator_address" => %{"hash" => "0x46B555CB3962bF9533c437cBD04A2f702dfdB999"},
                       "dapp_address" => %{"hash" => "0xFAf7a981360c2FAb3a5Ab7b3D6d8D0Cf97a91Eb9"},
                       "total_fee" => "44136000000000",
                       "dapp_fee" => "22068000000000",
                       "validator_fee" => "22068000000000"
                     }
                   }
                 ]
               } = json_response(request, 200)

        request = get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}")

        assert %{
                 "stability_fee" => %{
                   "token" => %{"address_hash" => "0xDc2B93f3291030F3F7a6D9363ac37757f7AD5C43"},
                   "validator_address" => %{"hash" => "0x46B555CB3962bF9533c437cBD04A2f702dfdB999"},
                   "dapp_address" => %{"hash" => "0xFAf7a981360c2FAb3a5Ab7b3D6d8D0Cf97a91Eb9"},
                   "total_fee" => "44136000000000",
                   "dapp_fee" => "22068000000000",
                   "validator_fee" => "22068000000000"
                 }
               } = json_response(request, 200)

        request = get(conn, "/api/v2/addresses/#{to_string(transaction.from_address_hash)}/transactions")

        assert %{
                 "items" => [
                   %{
                     "stability_fee" => %{
                       "token" => %{"address_hash" => "0xDc2B93f3291030F3F7a6D9363ac37757f7AD5C43"},
                       "validator_address" => %{"hash" => "0x46B555CB3962bF9533c437cBD04A2f702dfdB999"},
                       "dapp_address" => %{"hash" => "0xFAf7a981360c2FAb3a5Ab7b3D6d8D0Cf97a91Eb9"},
                       "total_fee" => "44136000000000",
                       "dapp_fee" => "22068000000000",
                       "validator_fee" => "22068000000000"
                     }
                   }
                 ]
               } = json_response(request, 200)
      end
    end
  end

  if @chain_type == :ethereum do
    describe "transactions/{transaction_hash}/beacon/deposits" do
      test "get 404 on non-existing transaction", %{conn: conn} do
        transaction = build(:transaction)

        request = get(conn, "/api/v2/transactions/#{transaction.hash}/beacon/deposits")
        response = json_response(request, 404)
      end

      test "get deposits", %{conn: conn} do
        transaction = insert(:transaction)

        deposits = insert_list(51, :beacon_deposit, transaction: transaction)

        insert(:beacon_deposit)

        request = get(conn, "/api/v2/transactions/#{transaction.hash}/beacon/deposits")
        assert response = json_response(request, 200)

        request_2nd_page =
          get(conn, "/api/v2/transactions/#{transaction.hash}/beacon/deposits", response["next_page_params"])

        assert response_2nd_page = json_response(request_2nd_page, 200)

        check_paginated_response(response, response_2nd_page, deposits)
      end
    end
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

  defp compare_item(%Log{} = log, json) do
    assert to_string(log.data) == json["data"]
    assert log.index == json["index"]
    assert Address.checksum(log.address_hash) == json["address"]["hash"]
    assert to_string(log.transaction_hash) == json["transaction_hash"]
    assert json["block_number"] == log.block_number
    assert json["block_timestamp"] != nil
  end

  defp compare_item(%TokenTransfer{} = token_transfer, json) do
    assert Address.checksum(token_transfer.from_address_hash) == json["from"]["hash"]
    assert Address.checksum(token_transfer.to_address_hash) == json["to"]["hash"]
    assert to_string(token_transfer.transaction_hash) == json["transaction_hash"]
    assert json["timestamp"] == nil
    assert json["method"] == nil
    assert to_string(token_transfer.block_hash) == json["block_hash"]
    assert token_transfer.log_index == json["log_index"]
    assert check_total(Repo.preload(token_transfer, [{:token, :contract_address}]).token, json["total"], token_transfer)
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

  defp compare_item(%Transaction{} = transaction, json, wl_names) do
    assert to_string(transaction.hash) == json["hash"]
    assert transaction.block_number == json["block_number"]
    assert to_string(transaction.value.value) == json["value"]
    assert Address.checksum(transaction.from_address_hash) == json["from"]["hash"]
    assert Address.checksum(transaction.to_address_hash) == json["to"]["hash"]

    assert json["to"]["watchlist_names"] ==
             if(wl_names[transaction.to_address_hash],
               do: [
                 %{
                   "display_name" => wl_names[transaction.to_address_hash],
                   "label" => wl_names[transaction.to_address_hash]
                 }
               ],
               else: []
             )

    assert json["from"]["watchlist_names"] ==
             if(wl_names[transaction.from_address_hash],
               do: [
                 %{
                   "display_name" => wl_names[transaction.from_address_hash],
                   "label" => wl_names[transaction.from_address_hash]
                 }
               ],
               else: []
             )
  end

  defp check_paginated_response(first_page_resp, second_page_resp, transactions) do
    assert Enum.count(first_page_resp["items"]) == 50
    assert first_page_resp["next_page_params"] != nil
    compare_item(Enum.at(transactions, 50), Enum.at(first_page_resp["items"], 0))
    compare_item(Enum.at(transactions, 1), Enum.at(first_page_resp["items"], 49))

    assert Enum.count(second_page_resp["items"]) == 1
    assert second_page_resp["next_page_params"] == nil
    compare_item(Enum.at(transactions, 0), Enum.at(second_page_resp["items"], 0))
  end

  defp check_paginated_response(first_page_resp, second_page_resp, transactions, wl_names) do
    assert Enum.count(first_page_resp["items"]) == 50
    assert first_page_resp["next_page_params"] != nil
    compare_item(Enum.at(transactions, 50), Enum.at(first_page_resp["items"], 0), wl_names)
    compare_item(Enum.at(transactions, 1), Enum.at(first_page_resp["items"], 49), wl_names)

    assert Enum.count(second_page_resp["items"]) == 1
    assert second_page_resp["next_page_params"] == nil
    compare_item(Enum.at(transactions, 0), Enum.at(second_page_resp["items"], 0), wl_names)
  end

  # with the current implementation no transfers should come with list in totals
  defp check_total(%Token{type: nft}, json, _token_transfer) when nft in ["ERC-721", "ERC-1155"] and is_list(json) do
    false
  end

  defp check_total(%Token{type: nft}, json, token_transfer) when nft in ["ERC-1155"] do
    json["token_id"] in Enum.map(token_transfer.token_ids, fn x -> to_string(x) end) and
      json["value"] == to_string(token_transfer.amount)
  end

  defp check_total(%Token{type: nft}, json, token_transfer) when nft in ["ERC-721"] do
    json["token_id"] in Enum.map(token_transfer.token_ids, fn x -> to_string(x) end)
  end

  defp check_total(_, _, _), do: true

  describe "/transactions/{transaction_hash}/summary?just_request_body=true" do
    setup do
      original_config =
        Application.get_env(:block_scout_web, BlockScoutWeb.MicroserviceInterfaces.TransactionInterpretation)

      Application.put_env(:block_scout_web, BlockScoutWeb.MicroserviceInterfaces.TransactionInterpretation,
        enabled: true,
        service_url: "http://localhost:4000"
      )

      original_chain_id = Application.get_env(:block_scout_web, :chain_id)
      Application.put_env(:block_scout_web, :chain_id, 1)

      on_exit(fn ->
        Application.put_env(
          :block_scout_web,
          BlockScoutWeb.MicroserviceInterfaces.TransactionInterpretation,
          original_config
        )

        Application.put_env(:block_scout_web, :chain_id, original_chain_id)
      end)
    end

    test "return 404 on non existing transaction", %{conn: conn} do
      transaction = build(:transaction)
      request = get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}/summary?just_request_body=true")

      assert %{"message" => "Not found"} = json_response(request, 404)
    end

    test "return 422 on invalid transaction hash", %{conn: conn} do
      request = get(conn, "/api/v2/transactions/0x/summary?just_request_body=true")

      assert %{
               "errors" => [
                 %{
                   "detail" => "Invalid format. Expected ~r/^0x([A-Fa-f0-9]{64})$/",
                   "source" => %{"pointer" => "/transaction_hash_param"},
                   "title" => "Invalid value"
                 }
               ]
             } = json_response(request, 422)
    end

    test "return 403 when transaction interpretation service is disabled", %{conn: conn} do
      Application.put_env(:block_scout_web, BlockScoutWeb.MicroserviceInterfaces.TransactionInterpretation,
        enabled: false
      )

      transaction =
        :transaction
        |> insert()
        |> with_block()

      request = get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}/summary?just_request_body=true")

      assert %{"message" => "Transaction Interpretation Service is disabled"} = json_response(request, 403)
    end

    test "return request body for existing transaction", %{conn: conn} do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      request = get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}/summary?just_request_body=true")

      assert response = json_response(request, 200)

      # Verify the structure of the request body
      assert Map.has_key?(response, "data")
      assert Map.has_key?(response, "logs_data")
      assert Map.has_key?(response, "chain_id")

      # Verify data structure
      data = response["data"]
      assert Map.has_key?(data, "to")
      assert Map.has_key?(data, "from")
      assert Map.has_key?(data, "hash")
      assert Map.has_key?(data, "type")
      assert Map.has_key?(data, "value")
      assert Map.has_key?(data, "method")
      assert Map.has_key?(data, "status")
      assert Map.has_key?(data, "transaction_types")
      assert Map.has_key?(data, "raw_input")
      assert Map.has_key?(data, "decoded_input")
      assert Map.has_key?(data, "token_transfers")
      assert Map.has_key?(data, "internal_transactions")

      # Verify logs_data structure
      logs_data = response["logs_data"]
      assert Map.has_key?(logs_data, "items")
      assert is_list(logs_data["items"])

      # Verify chain_id is present and is an integer
      assert is_integer(response["chain_id"])

      # Verify transaction data matches
      assert to_string(transaction.hash) == data["hash"]
      assert transaction.type == data["type"]
      assert to_string(transaction.value.value) == data["value"]
      assert to_string(transaction.status) == data["status"]
    end

    test "return request body with token transfers", %{conn: conn} do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(:token_transfer,
        transaction: transaction,
        block: transaction.block,
        block_number: transaction.block_number
      )

      request = get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}/summary?just_request_body=true")

      assert response = json_response(request, 200)
      assert is_list(response["data"]["token_transfers"])
      assert Enum.count(response["data"]["token_transfers"]) >= 1
    end

    test "return request body with internal transactions", %{conn: conn} do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(:internal_transaction,
        transaction_hash: transaction.hash,
        index: 1,
        block_number: transaction.block_number,
        transaction_index: transaction.index,
        block_hash: transaction.block_hash,
        type: :reward
      )

      request = get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}/summary?just_request_body=true")

      assert response = json_response(request, 200)
      assert is_list(response["data"]["internal_transactions"])
      assert Enum.count(response["data"]["internal_transactions"]) >= 1
    end

    test "return request body with logs", %{conn: conn} do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(:log,
        transaction: transaction,
        index: 1,
        block: transaction.block,
        block_number: transaction.block_number
      )

      request = get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}/summary?just_request_body=true")

      assert response = json_response(request, 200)
      assert is_list(response["logs_data"]["items"])
      assert Enum.count(response["logs_data"]["items"]) >= 1
    end

    test "return request body with smart contract transaction", %{conn: conn} do
      contract =
        insert(:smart_contract,
          contract_code_md5: "123",
          abi: [
            %{
              "constant" => false,
              "inputs" => [%{"name" => "", "type" => "bytes"}],
              "name" => "set",
              "outputs" => [],
              "payable" => false,
              "stateMutability" => "nonpayable",
              "type" => "function"
            }
          ]
        )
        |> Repo.preload(:address)

      input_data =
        "set(bytes)"
        |> ABI.encode([
          <<48, 120, 253, 69, 39, 88, 49, 136, 89, 142, 21, 123, 116, 129, 248, 32, 77, 29, 224, 121, 49, 137, 216, 8,
            212, 195, 239, 11, 174, 75, 56, 126>>
        ])
        |> Base.encode16(case: :lower)

      transaction =
        :transaction
        |> insert(to_address: contract.address, input: "0x" <> input_data)
        |> with_block()
        |> Repo.preload(to_address: :smart_contract)

      EthereumJSONRPC.Mox
      |> TestHelper.mock_generic_proxy_requests()

      request = get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}/summary?just_request_body=true")

      assert response = json_response(request, 200)

      # Verify that the transaction has input data
      assert response["data"]["raw_input"] == "0x" <> input_data

      assert response["data"]["decoded_input"] == %{
               "method_call" => "set(bytes arg0)",
               "method_id" => "0399321e",
               "parameters" => [
                 %{
                   "name" => "arg0",
                   "type" => "bytes",
                   "value" => "0x3078fd4527583188598e157b7481f8204d1de0793189d808d4c3ef0bae4b387e"
                 }
               ]
             }
    end

    test "return request body with proper address information", %{conn: conn} do
      from_address = insert(:address)
      to_address = insert(:address)

      transaction =
        :transaction
        |> insert(from_address: from_address, to_address: to_address)
        |> with_block()

      request = get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}/summary?just_request_body=true")

      assert response = json_response(request, 200)

      # Verify from address
      from_data = response["data"]["from"]
      assert Map.has_key?(from_data, "hash")
      assert from_data["hash"] == Address.checksum(from_address.hash)

      # Verify to address
      to_data = response["data"]["to"]
      assert Map.has_key?(to_data, "hash")
      assert to_data["hash"] == Address.checksum(to_address.hash)
    end

    test "limits token transfers to 50 items", %{conn: conn} do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      # Insert more than 50 token transfers
      insert_list(60, :token_transfer,
        transaction: transaction,
        block: transaction.block,
        block_number: transaction.block_number
      )

      request = get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}/summary?just_request_body=true")

      assert response = json_response(request, 200)
      assert Enum.count(response["data"]["token_transfers"]) <= 50
    end

    test "limits internal transactions to 50 items", %{conn: conn} do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      # Insert more than 50 internal transactions
      for index <- 1..60 do
        insert(:internal_transaction,
          transaction: transaction,
          index: index,
          block_number: transaction.block_number,
          transaction_index: transaction.index,
          block_hash: transaction.block_hash
        )
      end

      request = get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}/summary?just_request_body=true")

      assert response = json_response(request, 200)
      assert Enum.count(response["data"]["internal_transactions"]) <= 50
    end

    test "limits logs to 50 items", %{conn: conn} do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      # Insert more than 50 logs
      for index <- 1..60 do
        insert(:log,
          transaction: transaction,
          index: index,
          block: transaction.block,
          block_number: transaction.block_number
        )
      end

      request = get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}/summary?just_request_body=true")

      assert response = json_response(request, 200)
      assert Enum.count(response["logs_data"]["items"]) <= 50
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

      insert(:log,
        transaction: transaction,
        first_topic: TestHelper.topic(topic1),
        second_topic: TestHelper.topic(topic2),
        third_topic: nil,
        fourth_topic: nil,
        data: log_data,
        address: address,
        block: transaction.block,
        block_number: transaction.block_number
      )

      insert(:proxy_implementation,
        proxy_address_hash: address.hash,
        proxy_type: "eip1167",
        address_hashes: [smart_contract.address_hash],
        names: ["Test"]
      )

      request = get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}/summary?just_request_body=true")

      assert response = json_response(request, 200)
      assert is_list(response["logs_data"]["items"])
      assert Enum.count(response["logs_data"]["items"]) == 1

      log_from_api = Enum.at(response["logs_data"]["items"], 0)
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

      insert(:log,
        transaction: transaction,
        first_topic: TestHelper.topic(topic1),
        second_topic: TestHelper.topic(topic2),
        third_topic: nil,
        fourth_topic: nil,
        data: log_data,
        address: address,
        block: transaction.block,
        block_number: transaction.block_number
      )

      insert(:proxy_implementation,
        proxy_address_hash: address.hash,
        proxy_type: "eip1167",
        address_hashes: [contract_address.hash],
        names: ["Test"]
      )

      request = get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}/summary?just_request_body=true")

      assert response = json_response(request, 200)
      assert is_list(response["logs_data"]["items"])
      assert Enum.count(response["logs_data"]["items"]) == 1

      log_from_api = Enum.at(response["logs_data"]["items"], 0)
      # In this case, the log should not be decoded since the smart contract is absent
      assert is_nil(log_from_api["decoded"])
    end
  end

  describe "/transactions/{transaction_hash}/summary" do
    setup do
      original_config =
        Application.get_env(:block_scout_web, BlockScoutWeb.MicroserviceInterfaces.TransactionInterpretation)

      original_tesla_adapter = Application.get_env(:tesla, :adapter)
      Application.put_env(:tesla, :adapter, Tesla.Adapter.Mint)

      on_exit(fn ->
        Application.put_env(
          :block_scout_web,
          BlockScoutWeb.MicroserviceInterfaces.TransactionInterpretation,
          original_config
        )

        Application.put_env(:tesla, :adapter, original_tesla_adapter)
      end)
    end

    test "success preload template variables", %{conn: conn} do
      bypass = Bypass.open()

      Application.put_env(:block_scout_web, BlockScoutWeb.MicroserviceInterfaces.TransactionInterpretation,
        enabled: true,
        service_url: "http://localhost:#{bypass.port}"
      )

      transaction =
        :transaction
        |> insert()
        |> with_block(status: :ok)

      token = insert(:token)
      address = insert(:address)

      tx_interpretation_response = """
       {
        "success": true,
        "data": {
            "summaries": [
                {
                    "summary_template": "{action_type} {outgoing_amount} {native} for {incoming_amount} {incoming_token} on {market}",
                    "summary_template_variables": {
                        "action_type": {
                            "type": "string",
                            "value": "Swap"
                        },
                        "outgoing_amount": {
                            "type": "currency",
                            "value": "0.3"
                        },
                        "incoming_amount": {
                            "type": "currency",
                            "value": "9693.997876398680187001"
                        },
                        "incoming_token": {
                            "type": "token",
                            "value": {
                                "address_hash": "#{token.contract_address_hash}"
                            }
                        },
                        "rnd_address": {
                            "type": "address",
                            "value": {
                                "hash": "#{address.hash}"
                            }
                        },
                        "market": {
                            "type": "dexTag",
                            "value": {
                                "name": "Uniswap V3",
                                "icon": "https://blockscout-content.s3.amazonaws.com/uniswap.png",
                                "url": "https://uniswap.org/?utm_source=Blockscout"
                            }
                        }
                    }
                }
            ]
        }
      }
      """

      Bypass.expect_once(
        bypass,
        "GET",
        "/cache/#{to_string(transaction.hash)}",
        fn conn ->
          Plug.Conn.resp(conn, 404, "Not Found")
        end
      )

      Bypass.expect_once(
        bypass,
        "POST",
        "/transactions/summary",
        fn conn ->
          Plug.Conn.resp(conn, 200, tx_interpretation_response)
        end
      )

      request = get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}/summary")
      assert response = json_response(request, 200)

      token_json = Enum.at(response["data"]["summaries"], 0)["summary_template_variables"]["incoming_token"]["value"]
      assert token_json["address_hash"] == to_string(token.contract_address_hash)
      assert token_json["symbol"] == token.symbol
      assert token_json["reputation"] == "ok"

      address_json = Enum.at(response["data"]["summaries"], 0)["summary_template_variables"]["rnd_address"]["value"]
      assert Map.has_key?(address_json, "ens_domain_name")
      assert address_json["hash"] == to_string(address.hash)

      Bypass.down(bypass)
    end

    test "success preload template variables when scam token", %{conn: conn} do
      init_value = Application.get_env(:block_scout_web, :hide_scam_addresses)
      Application.put_env(:block_scout_web, :hide_scam_addresses, true)
      on_exit(fn -> Application.put_env(:block_scout_web, :hide_scam_addresses, init_value) end)

      bypass = Bypass.open()

      Application.put_env(:block_scout_web, BlockScoutWeb.MicroserviceInterfaces.TransactionInterpretation,
        enabled: true,
        service_url: "http://localhost:#{bypass.port}"
      )

      transaction =
        :transaction
        |> insert()
        |> with_block(status: :ok)

      token = insert(:token)
      address = insert(:address)

      insert(:scam_badge_to_address, address_hash: token.contract_address_hash)
      insert(:scam_badge_to_address, address_hash: address.hash)

      tx_interpretation_response = """
       {
        "success": true,
        "data": {
            "summaries": [
                {
                    "summary_template": "{action_type} {outgoing_amount} {native} for {incoming_amount} {incoming_token} on {market}",
                    "summary_template_variables": {
                        "action_type": {
                            "type": "string",
                            "value": "Swap"
                        },
                        "outgoing_amount": {
                            "type": "currency",
                            "value": "0.3"
                        },
                        "incoming_amount": {
                            "type": "currency",
                            "value": "9693.997876398680187001"
                        },
                        "incoming_token": {
                            "type": "token",
                            "value": {
                                "address_hash": "#{token.contract_address_hash}"
                            }
                        },
                        "rnd_address": {
                            "type": "address",
                            "value": {
                                "hash": "#{address.hash}"
                            }
                        },
                        "market": {
                            "type": "dexTag",
                            "value": {
                                "name": "Uniswap V3",
                                "icon": "https://blockscout-content.s3.amazonaws.com/uniswap.png",
                                "url": "https://uniswap.org/?utm_source=Blockscout"
                            }
                        }
                    }
                }
            ]
        }
      }
      """

      Bypass.expect_once(
        bypass,
        "GET",
        "/cache/#{to_string(transaction.hash)}",
        fn conn ->
          Plug.Conn.resp(conn, 404, "Not Found")
        end
      )

      Bypass.expect_once(
        bypass,
        "POST",
        "/transactions/summary",
        fn conn ->
          Plug.Conn.resp(conn, 200, tx_interpretation_response)
        end
      )

      request = get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}/summary")
      assert response = json_response(request, 200)

      token_json = Enum.at(response["data"]["summaries"], 0)["summary_template_variables"]["incoming_token"]["value"]
      assert token_json["address_hash"] == to_string(token.contract_address_hash)
      assert token_json["symbol"] == token.symbol
      assert token_json["reputation"] == "scam"

      address_json = Enum.at(response["data"]["summaries"], 0)["summary_template_variables"]["rnd_address"]["value"]
      assert Map.has_key?(address_json, "ens_domain_name")
      assert address_json["hash"] == to_string(address.hash)
      assert address_json["reputation"] == "scam"
      assert address_json["is_scam"] == true

      Bypass.down(bypass)
    end
  end

  if @chain_type == :neon do
    import Ecto.Query, only: [from: 2]

    describe "neon linked transactions service" do
      test "fetches data from the node and caches in the db", %{conn: conn} do
        transaction = insert(:transaction)
        transaction_hash = to_string(transaction.hash)

        dummy_response =
          Enum.map(1..:rand.uniform(10), fn _ ->
            :crypto.strong_rand_bytes(64) |> Base.encode64()
          end)

        EthereumJSONRPC.Mox
        |> expect(
          :json_rpc,
          fn
            %{id: 1, params: [^transaction_hash], method: "neon_getSolanaTransactionByNeonTransaction", jsonrpc: "2.0"},
            _options ->
              {:ok, dummy_response}
          end
        )

        request = get(conn, "/api/v2/transactions/#{transaction_hash}/external-transactions")
        assert response = json_response(request, 200)
        assert ^response = dummy_response

        records =
          from(
            solanaTransaction in Explorer.Chain.Neon.LinkedSolanaTransactions,
            where: solanaTransaction.neon_transaction_hash == ^transaction.hash.bytes,
            select: solanaTransaction.solana_transaction_hash
          )
          |> Repo.all()

        assert length(dummy_response) == length(records) and
                 Enum.all?(dummy_response, fn dummy -> Enum.member?(records, dummy) end)

        EthereumJSONRPC.Mox
        |> expect(:json_rpc, fn _, _ -> {:error, "must use DB cache"} end)

        request = get(conn, "/api/v2/transactions/#{transaction_hash}/external-transactions")
        assert response = json_response(request, 200)

        assert length(response) == length(dummy_response) and
                 Enum.all?(dummy_response, fn dummy -> Enum.member?(response, dummy) end)
      end

      test "returns an error when RPC node request fails", %{conn: conn} do
        transaction = insert(:transaction)

        EthereumJSONRPC.Mox
        |> expect(:json_rpc, fn _, _ -> {:error, "must fail"} end)

        request = get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}/external-transactions")
        assert response = json_response(request, 500)

        assert response == %{
                 "error" => "Unable to fetch external linked transactions",
                 "reason" => "\"Unable to fetch data from the node: \\\"must fail\\\"\""
               }
      end

      test "returns empty list when RPC returns empty list", %{conn: conn} do
        transaction = insert(:transaction)

        EthereumJSONRPC.Mox
        |> expect(:json_rpc, fn _, _ -> {:ok, []} end)

        request = get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}/external-transactions")
        assert response = json_response(request, 200)
        assert ^response = []
      end

      test "returns 422 for invalid transaction hash", %{conn: conn} do
        request = get(conn, "/api/v2/transactions/invalid_hash/external-transactions")
        assert response = json_response(request, 422)

        assert response["errors"] == [
                 %{
                   "detail" => "Invalid format. Expected ~r/^0x([A-Fa-f0-9]{64})$/",
                   "source" => %{"pointer" => "/transaction_hash_param"},
                   "title" => "Invalid value"
                 }
               ]
      end
    end
  end
end
