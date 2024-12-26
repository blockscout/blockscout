defmodule BlockScoutWeb.API.V2.TransactionControllerTest do
  use BlockScoutWeb.ConnCase

  import Explorer.Chain, only: [hash_to_lower_case_string: 1]
  import Mox

  alias Explorer.Account.{Identity, WatchlistAddress}
  alias Explorer.Chain.{Address, InternalTransaction, Log, Token, TokenTransfer, Transaction, Wei}
  alias Explorer.Repo

  setup do
    Supervisor.terminate_child(Explorer.Supervisor, Explorer.Chain.Cache.TransactionsApiV2.child_id())
    Supervisor.restart_child(Explorer.Supervisor, Explorer.Chain.Cache.TransactionsApiV2.child_id())

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
    test "return 404 on non existing transaction", %{conn: conn} do
      transaction = build(:transaction)
      request = get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}")

      assert %{"message" => "Not found"} = json_response(request, 404)
    end

    test "return 422 on invalid transaction hash", %{conn: conn} do
      request = get(conn, "/api/v2/transactions/0x")

      assert %{"message" => "Invalid parameter(s)"} = json_response(request, 422)
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
  end

  describe "/transactions/{transaction_hash}/internal-transactions" do
    test "return 404 on non existing transaction", %{conn: conn} do
      transaction = build(:transaction)
      request = get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}/internal-transactions")

      assert %{"message" => "Not found"} = json_response(request, 404)
    end

    test "return 422 on invalid transaction hash", %{conn: conn} do
      request = get(conn, "/api/v2/transactions/0x/internal-transactions")

      assert %{"message" => "Invalid parameter(s)"} = json_response(request, 422)
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
        block_hash: transaction.block_hash,
        block_index: 0
      )

      internal_transaction =
        insert(:internal_transaction,
          transaction: transaction,
          index: 1,
          block_number: transaction.block_number,
          transaction_index: transaction.index,
          block_hash: transaction.block_hash,
          block_index: 1
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
          block_hash: transaction_1.block_hash,
          block_index: index
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
        block_hash: transaction.block_hash,
        block_index: 0
      )

      internal_transactions =
        51..1
        |> Enum.map(fn index ->
          insert(:internal_transaction,
            transaction: transaction,
            index: index,
            block_number: transaction.block_number,
            transaction_index: transaction.index,
            block_hash: transaction.block_hash,
            block_index: index
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

      assert %{"message" => "Invalid parameter(s)"} = json_response(request, 422)
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
        50..0
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
    test "return 404 on non existing transaction", %{conn: conn} do
      transaction = build(:transaction)
      request = get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}/token-transfers")

      assert %{"message" => "Not found"} = json_response(request, 404)
    end

    test "return 422 on invalid transaction hash", %{conn: conn} do
      request = get(conn, "/api/v2/transactions/0x/token-transfers")

      assert %{"message" => "Invalid parameter(s)"} = json_response(request, 422)
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
      filter = %{"type" => "ERC-1155,ERC-20"}
      request = get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}/token-transfers", filter)
      assert response = json_response(request, 200)

      request_2nd_page =
        get(
          conn,
          "/api/v2/transactions/#{to_string(transaction.hash)}/token-transfers",
          Map.merge(response["next_page_params"], filter)
        )

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

      assert %{"message" => "Invalid parameter(s)"} = json_response(request, 422)
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
        block_index: 0,
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
        block_index: 0,
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
        block_index: 1,
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
        block_index: 2,
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
  end

  if Application.compile_env(:explorer, :chain_type) == :celo do
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
                         "address" => ^token_address_hash,
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
                     "address" => ^token_address_hash,
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
                         "address" => ^token_address_hash,
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
                       "address" => ^token_address_hash,
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
                         "address" => ^unknown_token_address_hash
                       }
                     }
                   }
                 ]
               } = json_response(request, 200)

        request = get(conn, "/api/v2/transactions/#{to_string(transaction.hash)}")

        assert %{
                 "celo" => %{
                   "gas_token" => %{
                     "address" => ^unknown_token_address_hash
                   }
                 }
               } = json_response(request, 200)

        request = get(conn, "/api/v2/addresses/#{to_string(transaction.from_address_hash)}/transactions")

        assert %{
                 "items" => [
                   %{
                     "celo" => %{
                       "gas_token" => %{
                         "address" => ^unknown_token_address_hash
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
                       "address" => ^unknown_token_address_hash
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
        "traceAddress" => [],
        "type" => "call",
        "callType" => "call",
        "from" => "0xa931c862e662134b85e4dc4baf5c70cc9ba74db4",
        "to" => "0x1469b17ebf82fedf56f04109e5207bdc4554288c",
        "gas" => "0x8600",
        "gasUsed" => "0x7d37",
        "input" => "0xb118e2db0000000000000000000000000000000000000000000000000000000000000008",
        "output" => "0x",
        "value" => "0x174876e800",
        "transactionHash" => to_string(transaction.hash)
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

    defp topic(topic_hex_string) do
      {:ok, topic} = Explorer.Chain.Hash.Full.cast(topic_hex_string)
      topic
    end

    describe "stability fees" do
      test "check stability fees", %{conn: conn} do
        transaction = insert(:transaction) |> with_block()

        _log =
          insert(:log,
            transaction: transaction,
            index: 1,
            block: transaction.block,
            block_number: transaction.block_number,
            first_topic: topic(@first_topic_hex_string_1),
            data:
              "0x000000000000000000000000dc2b93f3291030f3f7a6d9363ac37757f7ad5c4300000000000000000000000000000000000000000000000000002824369a100000000000000000000000000046b555cb3962bf9533c437cbd04a2f702dfdb999000000000000000000000000000000000000000000000000000014121b4d0800000000000000000000000000faf7a981360c2fab3a5ab7b3d6d8d0cf97a91eb9000000000000000000000000000000000000000000000000000014121b4d0800"
          )

        insert(:token, contract_address: build(:address, hash: "0xDc2B93f3291030F3F7a6D9363ac37757f7AD5C43"))
        request = get(conn, "/api/v2/transactions")

        assert %{
                 "items" => [
                   %{
                     "stability_fee" => %{
                       "token" => %{"address" => "0xDc2B93f3291030F3F7a6D9363ac37757f7AD5C43"},
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
                   "token" => %{"address" => "0xDc2B93f3291030F3F7a6D9363ac37757f7AD5C43"},
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
                       "token" => %{"address" => "0xDc2B93f3291030F3F7a6D9363ac37757f7AD5C43"},
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
            first_topic: topic(@first_topic_hex_string_1),
            data:
              "0x000000000000000000000000dc2b93f3291030f3f7a6d9363ac37757f7ad5c4300000000000000000000000000000000000000000000000000002824369a100000000000000000000000000046b555cb3962bf9533c437cbd04a2f702dfdb999000000000000000000000000000000000000000000000000000014121b4d0800000000000000000000000000faf7a981360c2fab3a5ab7b3d6d8d0cf97a91eb9000000000000000000000000000000000000000000000000000014121b4d0800"
          )

        request = get(conn, "/api/v2/transactions")

        assert %{
                 "items" => [
                   %{
                     "stability_fee" => %{
                       "token" => %{"address" => "0xDc2B93f3291030F3F7a6D9363ac37757f7AD5C43"},
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
                   "token" => %{"address" => "0xDc2B93f3291030F3F7a6D9363ac37757f7AD5C43"},
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
                       "token" => %{"address" => "0xDc2B93f3291030F3F7a6D9363ac37757f7AD5C43"},
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
end
