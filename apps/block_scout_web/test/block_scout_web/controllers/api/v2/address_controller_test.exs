defmodule BlockScoutWeb.API.V2.AddressControllerTest do
  use BlockScoutWeb.ConnCase

  alias BlockScoutWeb.Models.UserFromAuth
  alias Explorer.{Chain, Repo}

  alias Explorer.Chain.{
    Address,
    Address.CoinBalance,
    Block,
    InternalTransaction,
    Log,
    Token,
    TokenTransfer,
    Transaction
  }

  alias Explorer.Account.WatchlistAddress
  alias Explorer.Chain.Address.CurrentTokenBalance

  import Explorer.Chain, only: [hash_to_lower_case_string: 1]

  describe "/addresses/{address_hash}" do
    test "get 404 on non existing address", %{conn: conn} do
      address = build(:address)

      request = get(conn, "/api/v2/addresses/#{address.hash}")

      assert %{"message" => "Not found"} = json_response(request, 404)
    end

    test "get 422 on invalid address", %{conn: conn} do
      request = get(conn, "/api/v2/addresses/0x")

      assert %{"message" => "Invalid parameter(s)"} = json_response(request, 422)
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
        "creation_tx_hash" => nil,
        "token" => nil,
        "coin_balance" => nil,
        "exchange_rate" => nil,
        "implementation_name" => nil,
        "implementation_address" => nil,
        "block_number_balance_updated_at" => nil,
        "has_custom_methods_read" => false,
        "has_custom_methods_write" => false,
        "has_methods_read" => false,
        "has_methods_write" => false,
        "has_methods_read_proxy" => false,
        "has_methods_write_proxy" => false,
        "has_decompiled_code" => false,
        "has_validated_blocks" => false,
        "has_logs" => false,
        "has_tokens" => false,
        "has_token_transfers" => false,
        "watchlist_address_id" => nil
      }

      request = get(conn, "/api/v2/addresses/#{Address.checksum(address.hash)}")
      assert ^correct_response = json_response(request, 200)

      request = get(conn, "/api/v2/addresses/#{String.downcase(to_string(address.hash))}")
      assert ^correct_response = json_response(request, 200)
    end

    test "get watchlist id", %{conn: conn} do
      auth = build(:auth)
      address = insert(:address)
      {:ok, user} = UserFromAuth.find_or_create(auth)

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

      request = get(conn, "/api/v2/addresses/#{Address.checksum(address.hash)}")
      assert response = json_response(request, 200)

      assert response["watchlist_address_id"] == watchlist_address.id
    end
  end

  describe "/addresses/{address_hash}/counters" do
    test "get 404 on non existing address", %{conn: conn} do
      address = build(:address)

      request = get(conn, "/api/v2/addresses/#{address.hash}/counters")

      assert %{"message" => "Not found"} = json_response(request, 404)
    end

    test "get 422 on invalid address", %{conn: conn} do
      request = get(conn, "/api/v2/addresses/0x/counters")

      assert %{"message" => "Invalid parameter(s)"} = json_response(request, 422)
    end

    test "get counters with 0s", %{conn: conn} do
      address = insert(:address)

      request = get(conn, "/api/v2/addresses/#{address.hash}/counters")

      assert %{
               "transactions_count" => "0",
               "token_transfers_count" => "0",
               "gas_usage_count" => "0",
               "validations_count" => "0"
             } = json_response(request, 200)
    end

    test "get counters", %{conn: conn} do
      address = insert(:address)

      tx_from = insert(:transaction, from_address: address) |> with_block()
      insert(:transaction, to_address: address) |> with_block()
      another_tx = insert(:transaction) |> with_block()

      insert(:token_transfer,
        from_address: address,
        transaction: another_tx,
        block: another_tx.block,
        block_number: another_tx.block_number
      )

      insert(:token_transfer,
        to_address: address,
        transaction: another_tx,
        block: another_tx.block,
        block_number: another_tx.block_number
      )

      insert(:block, miner: address)

      Chain.transaction_count(address)
      Chain.token_transfers_count(address)
      Chain.gas_usage_count(address)

      request = get(conn, "/api/v2/addresses/#{address.hash}/counters")

      gas_used = to_string(tx_from.gas_used)

      assert %{
               "transactions_count" => "2",
               "token_transfers_count" => "2",
               "gas_usage_count" => ^gas_used,
               "validations_count" => "1"
             } = json_response(request, 200)
    end
  end

  describe "/addresses/{address_hash}/transactions" do
    test "get empty list on non existing address", %{conn: conn} do
      address = build(:address)

      request = get(conn, "/api/v2/addresses/#{address.hash}/transactions")

      assert %{"message" => "Not found"} = json_response(request, 404)
    end

    test "get 422 on invalid address", %{conn: conn} do
      request = get(conn, "/api/v2/addresses/0x/transactions")

      assert %{"message" => "Invalid parameter(s)"} = json_response(request, 422)
    end

    test "get relevant transaction", %{conn: conn} do
      address = insert(:address)

      tx = insert(:transaction, from_address: address) |> with_block()

      insert(:transaction) |> with_block()

      request = get(conn, "/api/v2/addresses/#{address.hash}/transactions")

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 1
      assert response["next_page_params"] == nil
      compare_item(tx, Enum.at(response["items"], 0))
    end

    test "get pending transaction", %{conn: conn} do
      address = insert(:address)

      tx = insert(:transaction, from_address: address) |> with_block()
      pending_tx = insert(:transaction, from_address: address)

      insert(:transaction) |> with_block()
      insert(:transaction)

      request = get(conn, "/api/v2/addresses/#{address.hash}/transactions")

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 2
      assert response["next_page_params"] == nil
      compare_item(pending_tx, Enum.at(response["items"], 0))
      compare_item(tx, Enum.at(response["items"], 1))
    end

    test "get only :to transaction", %{conn: conn} do
      address = insert(:address)

      insert(:transaction, from_address: address) |> with_block()
      tx = insert(:transaction, to_address: address) |> with_block()

      request = get(conn, "/api/v2/addresses/#{address.hash}/transactions", %{"filter" => "to"})

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 1
      assert response["next_page_params"] == nil
      compare_item(tx, Enum.at(response["items"], 0))
    end

    test "get only :from transactions", %{conn: conn} do
      address = insert(:address)

      tx = insert(:transaction, from_address: address) |> with_block()
      insert(:transaction, to_address: address) |> with_block()

      request = get(conn, "/api/v2/addresses/#{address.hash}/transactions", %{"filter" => "from"})

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 1
      assert response["next_page_params"] == nil
      compare_item(tx, Enum.at(response["items"], 0))
    end

    test "validated txs can paginate", %{conn: conn} do
      address = insert(:address)

      txs = insert_list(51, :transaction, from_address: address) |> with_block()

      request = get(conn, "/api/v2/addresses/#{address.hash}/transactions")
      assert response = json_response(request, 200)

      request_2nd_page = get(conn, "/api/v2/addresses/#{address.hash}/transactions", response["next_page_params"])
      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, txs)
    end

    test "pending txs can paginate", %{conn: conn} do
      address = insert(:address)

      txs = insert_list(51, :transaction, from_address: address)

      request = get(conn, "/api/v2/addresses/#{address.hash}/transactions")
      assert response = json_response(request, 200)

      request_2nd_page = get(conn, "/api/v2/addresses/#{address.hash}/transactions", response["next_page_params"])
      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, txs)
    end

    test "pending + validated txs can paginate", %{conn: conn} do
      address = insert(:address)

      txs_pending = insert_list(51, :transaction, from_address: address)
      txs_validated = insert_list(50, :transaction, to_address: address) |> with_block()

      request = get(conn, "/api/v2/addresses/#{address.hash}/transactions")
      assert response = json_response(request, 200)

      request_2nd_page = get(conn, "/api/v2/addresses/#{address.hash}/transactions", response["next_page_params"])
      assert response_2nd_page = json_response(request_2nd_page, 200)

      assert Enum.count(response["items"]) == 50
      assert response["next_page_params"] != nil
      compare_item(Enum.at(txs_pending, 50), Enum.at(response["items"], 0))
      compare_item(Enum.at(txs_pending, 1), Enum.at(response["items"], 49))

      assert Enum.count(response_2nd_page["items"]) == 50
      assert response_2nd_page["next_page_params"] != nil
      compare_item(Enum.at(txs_pending, 0), Enum.at(response_2nd_page["items"], 0))
      compare_item(Enum.at(txs_validated, 49), Enum.at(response_2nd_page["items"], 1))
      compare_item(Enum.at(txs_validated, 1), Enum.at(response_2nd_page["items"], 49))

      request = get(conn, "/api/v2/addresses/#{address.hash}/transactions", response_2nd_page["next_page_params"])
      assert response = json_response(request, 200)

      check_paginated_response(response_2nd_page, response, txs_validated ++ [Enum.at(txs_pending, 0)])
    end

    test ":to txs can paginate", %{conn: conn} do
      address = insert(:address)

      txs = insert_list(51, :transaction, to_address: address) |> with_block()
      insert_list(51, :transaction, from_address: address) |> with_block()

      filter = %{"filter" => "to"}
      request = get(conn, "/api/v2/addresses/#{address.hash}/transactions", filter)
      assert response = json_response(request, 200)

      request_2nd_page =
        get(conn, "/api/v2/addresses/#{address.hash}/transactions", Map.merge(response["next_page_params"], filter))

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, txs)
    end

    test ":from txs can paginate", %{conn: conn} do
      address = insert(:address)

      insert_list(51, :transaction, to_address: address) |> with_block()
      txs = insert_list(51, :transaction, from_address: address) |> with_block()

      filter = %{"filter" => "from"}
      request = get(conn, "/api/v2/addresses/#{address.hash}/transactions", filter)
      assert response = json_response(request, 200)

      request_2nd_page =
        get(conn, "/api/v2/addresses/#{address.hash}/transactions", Map.merge(response["next_page_params"], filter))

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, txs)
    end

    test ":from + :to txs can paginate", %{conn: conn} do
      address = insert(:address)

      txs_from = insert_list(50, :transaction, from_address: address) |> with_block()
      txs_to = insert_list(51, :transaction, to_address: address) |> with_block()

      request = get(conn, "/api/v2/addresses/#{address.hash}/transactions")
      assert response = json_response(request, 200)

      request_2nd_page = get(conn, "/api/v2/addresses/#{address.hash}/transactions", response["next_page_params"])
      assert response_2nd_page = json_response(request_2nd_page, 200)

      assert Enum.count(response["items"]) == 50
      assert response["next_page_params"] != nil
      compare_item(Enum.at(txs_to, 50), Enum.at(response["items"], 0))
      compare_item(Enum.at(txs_to, 1), Enum.at(response["items"], 49))

      assert Enum.count(response_2nd_page["items"]) == 50
      assert response_2nd_page["next_page_params"] != nil
      compare_item(Enum.at(txs_to, 0), Enum.at(response_2nd_page["items"], 0))
      compare_item(Enum.at(txs_from, 49), Enum.at(response_2nd_page["items"], 1))
      compare_item(Enum.at(txs_from, 1), Enum.at(response_2nd_page["items"], 49))

      request = get(conn, "/api/v2/addresses/#{address.hash}/transactions", response_2nd_page["next_page_params"])
      assert response = json_response(request, 200)

      check_paginated_response(response_2nd_page, response, txs_from ++ [Enum.at(txs_to, 0)])
    end
  end

  describe "/addresses/{address_hash}/token-transfers" do
    test "get 404 on non existing address", %{conn: conn} do
      address = build(:address)

      request = get(conn, "/api/v2/addresses/#{address.hash}/token-transfers")

      assert %{"message" => "Not found"} = json_response(request, 404)
    end

    test "get 422 on invalid address", %{conn: conn} do
      request = get(conn, "/api/v2/addresses/0x/token-transfers")

      assert %{"message" => "Invalid parameter(s)"} = json_response(request, 422)
    end

    test "get 404 on non existing address of token", %{conn: conn} do
      address = insert(:address)

      token = build(:address)

      request = get(conn, "/api/v2/addresses/#{address.hash}/token-transfers", %{"token" => to_string(token.hash)})

      assert %{"message" => "Not found"} = json_response(request, 404)
    end

    test "get 422 on invalid token address hash", %{conn: conn} do
      address = insert(:address)

      request = get(conn, "/api/v2/addresses/#{address.hash}/token-transfers", %{"token" => "0x"})

      assert %{"message" => "Invalid parameter(s)"} = json_response(request, 422)
    end

    test "get relevant token transfer", %{conn: conn} do
      address = insert(:address)

      tx = insert(:transaction, input: "0xabcd010203040506") |> with_block()

      insert(:token_transfer, transaction: tx, block: tx.block, block_number: tx.block_number)

      token_transfer =
        insert(:token_transfer, transaction: tx, block: tx.block, block_number: tx.block_number, from_address: address)

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

      tx =
        insert(:transaction,
          input:
            "0x731133e9000000000000000000000000bb36c792b9b45aaf8b848a1392b0d6559202729e000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000001700000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000000"
        )
        |> with_block()

      insert(:token_transfer, transaction: tx, block: tx.block, block_number: tx.block_number)

      token_transfer =
        insert(:token_transfer, transaction: tx, block: tx.block, block_number: tx.block_number, from_address: address)

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

      tx = insert(:transaction, input: "0xabcd010203040506") |> with_block()

      insert(:token_transfer, transaction: tx, block: tx.block, block_number: tx.block_number)

      insert(:token_transfer, transaction: tx, block: tx.block, block_number: tx.block_number, from_address: address)

      token_transfer =
        insert(:token_transfer,
          transaction: tx,
          block: tx.block,
          block_number: tx.block_number,
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
          tx = insert(:transaction, input: "0xabcd010203040506") |> with_block()

          insert(:token_transfer, transaction: tx, block: tx.block, block_number: tx.block_number, from_address: address)

          insert(:token_transfer,
            transaction: tx,
            block: tx.block,
            block_number: tx.block_number,
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

      tx = insert(:transaction, input: "0xabcd010203040506") |> with_block()

      insert(:token_transfer, transaction: tx, block: tx.block, block_number: tx.block_number, from_address: address)

      token_transfer =
        insert(:token_transfer, transaction: tx, block: tx.block, block_number: tx.block_number, to_address: address)

      request = get(conn, "/api/v2/addresses/#{address.hash}/token-transfers", %{"filter" => "to"})

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 1
      assert response["next_page_params"] == nil
      compare_item(token_transfer, Enum.at(response["items"], 0))
    end

    test "get only :from token transfer", %{conn: conn} do
      address = insert(:address)

      tx = insert(:transaction, input: "0xabcd010203040506") |> with_block()

      token_transfer =
        insert(:token_transfer, transaction: tx, block: tx.block, block_number: tx.block_number, from_address: address)

      insert(:token_transfer, transaction: tx, block: tx.block, block_number: tx.block_number, to_address: address)
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
          tx = insert(:transaction, input: "0xabcd010203040506") |> with_block()

          insert(:token_transfer, transaction: tx, block: tx.block, block_number: tx.block_number, from_address: address)
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
        tx = insert(:transaction, input: "0xabcd010203040506") |> with_block()
        insert(:token_transfer, transaction: tx, block: tx.block, block_number: tx.block_number, from_address: address)
      end

      token_transfers =
        for _ <- 0..50 do
          tx = insert(:transaction, input: "0xabcd010203040506") |> with_block()
          insert(:token_transfer, transaction: tx, block: tx.block, block_number: tx.block_number, to_address: address)
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
          tx = insert(:transaction, input: "0xabcd010203040506") |> with_block()

          insert(:token_transfer, transaction: tx, block: tx.block, block_number: tx.block_number, from_address: address)
        end

      for _ <- 0..50 do
        tx = insert(:transaction, input: "0xabcd010203040506") |> with_block()
        insert(:token_transfer, transaction: tx, block: tx.block, block_number: tx.block_number, to_address: address)
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
          tx = insert(:transaction, input: "0xabcd010203040506") |> with_block()

          insert(:token_transfer, transaction: tx, block: tx.block, block_number: tx.block_number, from_address: address)
        end

      tt_to =
        for _ <- 0..50 do
          tx = insert(:transaction, input: "0xabcd010203040506") |> with_block()
          insert(:token_transfer, transaction: tx, block: tx.block, block_number: tx.block_number, to_address: address)
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

      request = get(conn, "/api/v2/addresses/#{address.hash}/token-transfers", response_2nd_page["next_page_params"])
      assert response = json_response(request, 200)

      check_paginated_response(response_2nd_page, response, tt_from ++ [Enum.at(tt_to, 0)])
    end

    test "check token type filters", %{conn: conn} do
      address = insert(:address)

      erc_20_token = insert(:token, type: "ERC-20")

      erc_20_tt =
        for _ <- 0..50 do
          tx = insert(:transaction, input: "0xabcd010203040506") |> with_block()

          insert(:token_transfer,
            transaction: tx,
            block: tx.block,
            block_number: tx.block_number,
            from_address: address,
            token_contract_address: erc_20_token.contract_address
          )
        end

      erc_721_token = insert(:token, type: "ERC-721")

      erc_721_tt =
        for x <- 0..50 do
          tx = insert(:transaction, input: "0xabcd010203040506") |> with_block()

          insert(:token_transfer,
            transaction: tx,
            block: tx.block,
            block_number: tx.block_number,
            from_address: address,
            token_contract_address: erc_721_token.contract_address,
            token_ids: [x]
          )
        end

      erc_1155_token = insert(:token, type: "ERC-1155")

      erc_1155_tt =
        for x <- 0..50 do
          tx = insert(:transaction, input: "0xabcd010203040506") |> with_block()

          insert(:token_transfer,
            transaction: tx,
            block: tx.block,
            block_number: tx.block_number,
            from_address: address,
            token_contract_address: erc_1155_token.contract_address,
            token_ids: [x]
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

      # two filters simultaneously
      filter = %{"type" => "ERC-1155,ERC-20"}
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
          tx = insert(:transaction, input: "0xabcd010203040506") |> with_block()

          insert(:token_transfer,
            transaction: tx,
            block: tx.block,
            block_number: tx.block_number,
            from_address: address,
            token_contract_address: erc_20_token.contract_address
          )
        end

      erc_721_token = insert(:token, type: "ERC-721")

      erc_721_tt =
        for x <- 0..50 do
          tx = insert(:transaction, input: "0xabcd010203040506") |> with_block()

          insert(:token_transfer,
            transaction: tx,
            block: tx.block,
            block_number: tx.block_number,
            to_address: address,
            token_contract_address: erc_721_token.contract_address,
            token_ids: [x]
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
        get(conn, "/api/v2/addresses/#{address.hash}/token-transfers", Map.merge(response["next_page_params"], filter))

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
          tx = insert(:transaction, input: "0xabcd010203040506") |> with_block()

          insert(:token_transfer,
            to_address: address,
            transaction: tx,
            block: tx.block,
            block_number: tx.block_number,
            token_contract_address: token.contract_address,
            token_ids: Enum.map(0..50, fn _x -> id end),
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
          tx = insert(:transaction, input: "0xabcd010203040506") |> with_block()

          insert(:token_transfer,
            transaction: tx,
            to_address: address,
            block: tx.block,
            block_number: tx.block_number,
            token_contract_address: token.contract_address,
            token_ids: [i]
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
      tx = insert(:transaction, input: "0xabcd010203040506") |> with_block()

      tt =
        insert(:token_transfer,
          transaction: tx,
          to_address: address,
          block: tx.block,
          block_number: tx.block_number,
          token_contract_address: token.contract_address,
          token_ids: Enum.map(0..50, fn x -> x end),
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
      assert %{"items" => [], "next_page_params" => nil} = json_response(request, 200)
    end

    test "check that pagination works fine with 1155 batches #2 some batches on the first page and one on the second",
         %{conn: conn} do
      address = insert(:address)

      token = insert(:token, type: "ERC-1155")

      tx_1 = insert(:transaction, input: "0xabcd010203040506") |> with_block()

      tt_1 =
        insert(:token_transfer,
          transaction: tx_1,
          to_address: address,
          block: tx_1.block,
          block_number: tx_1.block_number,
          token_contract_address: token.contract_address,
          token_ids: Enum.map(0..24, fn x -> x end),
          amounts: Enum.map(0..24, fn x -> x end)
        )

      token_transfers_1 =
        for i <- 0..24 do
          %TokenTransfer{tt_1 | token_ids: [i], amount: i}
        end

      tx_2 = insert(:transaction, input: "0xabcd010203040506") |> with_block()

      tt_2 =
        insert(:token_transfer,
          transaction: tx_2,
          to_address: address,
          block: tx_2.block,
          block_number: tx_2.block_number,
          token_contract_address: token.contract_address,
          token_ids: Enum.map(25..49, fn x -> x end),
          amounts: Enum.map(25..49, fn x -> x end)
        )

      token_transfers_2 =
        for i <- 25..49 do
          %TokenTransfer{tt_2 | token_ids: [i], amount: i}
        end

      tt_3 =
        insert(:token_transfer,
          transaction: tx_2,
          from_address: address,
          block: tx_2.block,
          block_number: tx_2.block_number,
          token_contract_address: token.contract_address,
          token_ids: [50],
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

      tx_1 = insert(:transaction, input: "0xabcd010203040506") |> with_block()

      tt_1 =
        insert(:token_transfer,
          transaction: tx_1,
          from_address: address,
          block: tx_1.block,
          block_number: tx_1.block_number,
          token_contract_address: token.contract_address,
          token_ids: Enum.map(0..24, fn x -> x end),
          amounts: Enum.map(0..24, fn x -> x end)
        )

      token_transfers_1 =
        for i <- 0..24 do
          %TokenTransfer{tt_1 | token_ids: [i], amount: i}
        end

      tx_2 = insert(:transaction, input: "0xabcd010203040506") |> with_block()

      tt_2 =
        insert(:token_transfer,
          transaction: tx_2,
          to_address: address,
          block: tx_2.block,
          block_number: tx_2.block_number,
          token_contract_address: token.contract_address,
          token_ids: Enum.map(25..50, fn x -> x end),
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
  end

  describe "/addresses/{address_hash}/internal-transactions" do
    test "get empty list on non existing address", %{conn: conn} do
      address = build(:address)

      request = get(conn, "/api/v2/addresses/#{address.hash}/internal-transactions")

      assert %{"message" => "Not found"} = json_response(request, 404)
    end

    test "get 422 on invalid address", %{conn: conn} do
      request = get(conn, "/api/v2/addresses/0x/internal-transactions")

      assert %{"message" => "Invalid parameter(s)"} = json_response(request, 422)
    end

    test "get internal tx and filter working", %{conn: conn} do
      address = insert(:address)

      tx =
        :transaction
        |> insert()
        |> with_block()

      internal_tx_from =
        insert(:internal_transaction,
          transaction: tx,
          index: 1,
          block_number: tx.block_number,
          transaction_index: tx.index,
          block_hash: tx.block_hash,
          block_index: 1,
          from_address: address
        )

      internal_tx_to =
        insert(:internal_transaction,
          transaction: tx,
          index: 2,
          block_number: tx.block_number,
          transaction_index: tx.index,
          block_hash: tx.block_hash,
          block_index: 2,
          to_address: address
        )

      request = get(conn, "/api/v2/addresses/#{address.hash}/internal-transactions")

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 2
      assert response["next_page_params"] == nil

      compare_item(internal_tx_from, Enum.at(response["items"], 1))
      compare_item(internal_tx_to, Enum.at(response["items"], 0))

      request = get(conn, "/api/v2/addresses/#{address.hash}/internal-transactions", %{"filter" => "from"})

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 1
      assert response["next_page_params"] == nil
      compare_item(internal_tx_from, Enum.at(response["items"], 0))

      request = get(conn, "/api/v2/addresses/#{address.hash}/internal-transactions", %{"filter" => "to"})

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 1
      assert response["next_page_params"] == nil
      compare_item(internal_tx_to, Enum.at(response["items"], 0))
    end

    test "internal txs can paginate", %{conn: conn} do
      address = insert(:address)

      tx =
        :transaction
        |> insert()
        |> with_block()

      itxs_from =
        for i <- 1..51 do
          insert(:internal_transaction,
            transaction: tx,
            index: i,
            block_number: tx.block_number,
            transaction_index: tx.index,
            block_hash: tx.block_hash,
            block_index: i,
            from_address: address
          )
        end

      request = get(conn, "/api/v2/addresses/#{address.hash}/internal-transactions")
      assert response = json_response(request, 200)

      request_2nd_page =
        get(conn, "/api/v2/addresses/#{address.hash}/internal-transactions", response["next_page_params"])

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, itxs_from)

      itxs_to =
        for i <- 52..102 do
          insert(:internal_transaction,
            transaction: tx,
            index: i,
            block_number: tx.block_number,
            transaction_index: tx.index,
            block_hash: tx.block_hash,
            block_index: i,
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

      check_paginated_response(response, response_2nd_page, itxs_to)

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

      check_paginated_response(response, response_2nd_page, itxs_from)
    end
  end

  describe "/addresses/{address_hash}/blocks-validated" do
    test "get empty list on non existing address", %{conn: conn} do
      address = build(:address)

      request = get(conn, "/api/v2/addresses/#{address.hash}/blocks-validated")

      assert %{"message" => "Not found"} = json_response(request, 404)
    end

    test "get 422 on invalid address", %{conn: conn} do
      request = get(conn, "/api/v2/addresses/0x/blocks-validated")

      assert %{"message" => "Invalid parameter(s)"} = json_response(request, 422)
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
    test "get empty list on non existing address", %{conn: conn} do
      address = build(:address)

      request = get(conn, "/api/v2/addresses/#{address.hash}/token-balances")

      assert %{"message" => "Not found"} = json_response(request, 404)
    end

    test "get 422 on invalid address", %{conn: conn} do
      request = get(conn, "/api/v2/addresses/0x/token-balances")

      assert %{"message" => "Invalid parameter(s)"} = json_response(request, 422)
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

      assert %{"message" => "Not found"} = json_response(request, 404)
    end

    test "get 422 on invalid address", %{conn: conn} do
      request = get(conn, "/api/v2/addresses/0x/coin-balance-history")

      assert %{"message" => "Invalid parameter(s)"} = json_response(request, 422)
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

      assert %{"message" => "Not found"} = json_response(request, 404)
    end

    test "get 422 on invalid address", %{conn: conn} do
      request = get(conn, "/api/v2/addresses/0x/coin-balance-history-by-day")

      assert %{"message" => "Invalid parameter(s)"} = json_response(request, 422)
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

      assert [
               %{"date" => _, "value" => "2000"},
               %{"date" => _, "value" => "1000"},
               %{"date" => _, "value" => "1000"}
             ] = response
    end
  end

  describe "/addresses/{address_hash}/logs" do
    test "get empty list on non existing address", %{conn: conn} do
      address = build(:address)

      request = get(conn, "/api/v2/addresses/#{address.hash}/logs")

      assert %{"message" => "Not found"} = json_response(request, 404)
    end

    test "get 422 on invalid address", %{conn: conn} do
      request = get(conn, "/api/v2/addresses/0x/logs")

      assert %{"message" => "Invalid parameter(s)"} = json_response(request, 422)
    end

    test "get log", %{conn: conn} do
      address = insert(:address)

      tx =
        :transaction
        |> insert()
        |> with_block()

      log =
        insert(:log,
          transaction: tx,
          index: 1,
          block: tx.block,
          block_number: tx.block_number,
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
          tx =
            :transaction
            |> insert()
            |> with_block()

          insert(:log,
            transaction: tx,
            index: x,
            block: tx.block,
            block_number: tx.block_number,
            address: address
          )
        end

      request = get(conn, "/api/v2/addresses/#{address.hash}/logs")
      assert response = json_response(request, 200)

      request_2nd_page = get(conn, "/api/v2/addresses/#{address.hash}/logs", response["next_page_params"])
      assert response_2nd_page = json_response(request_2nd_page, 200)
      check_paginated_response(response, response_2nd_page, logs)
    end

    test "logs can be filtered by topic", %{conn: conn} do
      address = insert(:address)

      for x <- 0..20 do
        tx =
          :transaction
          |> insert()
          |> with_block()

        insert(:log,
          transaction: tx,
          index: x,
          block: tx.block,
          block_number: tx.block_number,
          address: address
        )
      end

      tx =
        :transaction
        |> insert()
        |> with_block()

      log =
        insert(:log,
          transaction: tx,
          block: tx.block,
          block_number: tx.block_number,
          address: address,
          first_topic: "0x123456789123456789"
        )

      request = get(conn, "/api/v2/addresses/#{address.hash}/logs?topic=0x123456789123456789")
      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 1
      assert response["next_page_params"] == nil
      compare_item(log, Enum.at(response["items"], 0))
    end
  end

  describe "/addresses/{address_hash}/tokens" do
    test "get empty list on non existing address", %{conn: conn} do
      address = build(:address)

      request = get(conn, "/api/v2/addresses/#{address.hash}/tokens")

      assert %{"message" => "Not found"} = json_response(request, 404)
    end

    test "get 422 on invalid address", %{conn: conn} do
      request = get(conn, "/api/v2/addresses/0x/tokens")

      assert %{"message" => "Invalid parameter(s)"} = json_response(request, 422)
    end

    test "get tokens", %{conn: conn} do
      address = insert(:address)

      ctbs_erc_20 =
        for _ <- 0..50 do
          insert(:address_current_token_balance_with_token_id, address: address, token_type: "ERC-20", token_id: nil)
          |> Repo.preload([:token])
        end
        |> Enum.sort_by(fn x -> x.value end, :asc)

      ctbs_erc_721 =
        for _ <- 0..50 do
          insert(:address_current_token_balance_with_token_id, address: address, token_type: "ERC-721", token_id: nil)
          |> Repo.preload([:token])
        end
        |> Enum.sort_by(fn x -> x.value end, :asc)

      ctbs_erc_1155 =
        for _ <- 0..50 do
          insert(:address_current_token_balance_with_token_id,
            address: address,
            token_type: "ERC-1155",
            token_id: Enum.random(1..100_000)
          )
          |> Repo.preload([:token])
        end
        |> Enum.sort_by(fn x -> x.value end, :asc)

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
    end
  end

  describe "/addresses" do
    test "get empty list", %{conn: conn} do
      request = get(conn, "/api/v2/addresses")

      total_supply = to_string(Chain.total_supply())

      assert %{"items" => [], "next_page_params" => nil, "exchange_rate" => nil, "total_supply" => ^total_supply} =
               json_response(request, 200)
    end

    test "check pagination", %{conn: conn} do
      addresses =
        for i <- 0..50 do
          insert(:address, nonce: i, fetched_coin_balance: i + 1)
        end

      request = get(conn, "/api/v2/addresses")
      assert response = json_response(request, 200)

      request_2nd_page = get(conn, "/api/v2/addresses", response["next_page_params"])

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, addresses)

      assert Enum.at(response["items"], 0)["coin_balance"] ==
               to_string(Enum.at(addresses, 50).fetched_coin_balance.value)
    end

    test "check nil", %{conn: conn} do
      address = insert(:address, nonce: 1, fetched_coin_balance: 1)

      request = get(conn, "/api/v2/addresses")

      assert %{"items" => [address_json], "next_page_params" => nil} = json_response(request, 200)

      compare_item(address, address_json)
    end
  end

  defp compare_item(%Address{} = address, json) do
    assert Address.checksum(address.hash) == json["hash"]
    assert to_string(address.nonce + 1) == json["tx_count"]
  end

  defp compare_item(%Transaction{} = transaction, json) do
    assert to_string(transaction.hash) == json["hash"]
    assert transaction.block_number == json["block"]
    assert to_string(transaction.value.value) == json["value"]
    assert Address.checksum(transaction.from_address_hash) == json["from"]["hash"]
    assert Address.checksum(transaction.to_address_hash) == json["to"]["hash"]
  end

  defp compare_item(%TokenTransfer{} = token_transfer, json) do
    assert Address.checksum(token_transfer.from_address_hash) == json["from"]["hash"]
    assert Address.checksum(token_transfer.to_address_hash) == json["to"]["hash"]
    assert to_string(token_transfer.transaction_hash) == json["tx_hash"]
    assert json["timestamp"] != nil
    assert json["method"] != nil
    assert to_string(token_transfer.block_hash) == json["block_hash"]
    assert to_string(token_transfer.log_index) == json["log_index"]
    assert check_total(Repo.preload(token_transfer, [{:token, :contract_address}]).token, json["total"], token_transfer)
  end

  defp compare_item(%InternalTransaction{} = internal_tx, json) do
    assert internal_tx.block_number == json["block"]
    assert to_string(internal_tx.gas) == json["gas_limit"]
    assert internal_tx.index == json["index"]
    assert to_string(internal_tx.transaction_hash) == json["transaction_hash"]
    assert Address.checksum(internal_tx.from_address_hash) == json["from"]["hash"]
    assert Address.checksum(internal_tx.to_address_hash) == json["to"]["hash"]
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
    assert Address.checksum(token.contract_address_hash) == json["address"]
    assert to_string(token.symbol) == json["symbol"]
    assert to_string(token.name) == json["name"]
    assert to_string(token.type) == json["type"]
    assert to_string(token.decimals) == json["decimals"]
    assert (token.holder_count && to_string(token.holder_count)) == json["holders"]
    assert Map.has_key?(json, "exchange_rate")
  end

  defp compare_item(%Log{} = log, json) do
    assert log.index == json["index"]
    assert to_string(log.data) == json["data"]
    assert Address.checksum(log.address_hash) == json["address"]["hash"]
    assert to_string(log.transaction_hash) == json["tx_hash"]
  end

  defp check_paginated_response(first_page_resp, second_page_resp, list) do
    assert Enum.count(first_page_resp["items"]) == 50
    assert first_page_resp["next_page_params"] != nil
    compare_item(Enum.at(list, 50), Enum.at(first_page_resp["items"], 0))
    compare_item(Enum.at(list, 1), Enum.at(first_page_resp["items"], 49))

    assert Enum.count(second_page_resp["items"]) == 1
    assert second_page_resp["next_page_params"] == nil
    compare_item(Enum.at(list, 0), Enum.at(second_page_resp["items"], 0))
  end

  def check_total(%Token{type: nft}, json, token_transfer) when nft in ["ERC-1155"] do
    json["token_id"] in Enum.map(token_transfer.token_ids, fn x -> to_string(x) end) and
      json["value"] == to_string(token_transfer.amount)
  end

  def check_total(%Token{type: nft}, json, token_transfer) when nft in ["ERC-721"] do
    json["token_id"] in Enum.map(token_transfer.token_ids, fn x -> to_string(x) end)
  end

  # with the current implementation no transfers should come with list in totals
  def check_total(%Token{type: nft}, json, _token_transfer) when nft in ["ERC-721", "ERC-1155"] and is_list(json) do
    false
  end

  def check_total(_, _, _), do: true
end
