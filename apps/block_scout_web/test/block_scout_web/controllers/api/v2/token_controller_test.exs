defmodule BlockScoutWeb.API.V2.TokenControllerTest do
  use BlockScoutWeb.ConnCase

  alias Explorer.Repo

  alias Explorer.Chain.{Address, Token, Token.Instance, TokenTransfer}

  alias Explorer.Chain.Address.CurrentTokenBalance

  describe "/tokens/{address_hash}" do
    test "get 404 on non existing address", %{conn: conn} do
      token = build(:token)

      request = get(conn, "/api/v2/tokens/#{token.contract_address.hash}")

      assert %{"message" => "Not found"} = json_response(request, 404)
    end

    test "get 422 on invalid address", %{conn: conn} do
      request = get(conn, "/api/v2/tokens/0x")

      assert %{"message" => "Invalid parameter(s)"} = json_response(request, 422)
    end

    test "get token", %{conn: conn} do
      token = insert(:token)

      request = get(conn, "/api/v2/tokens/#{token.contract_address.hash}")

      assert response = json_response(request, 200)

      compare_item(token, response)
    end
  end

  describe "/tokens/{address_hash}/counters" do
    test "get 404 on non existing address", %{conn: conn} do
      token = build(:token)

      request = get(conn, "/api/v2/tokens/#{token.contract_address.hash}/counters")

      assert %{"message" => "Not found"} = json_response(request, 404)
    end

    test "get 422 on invalid address", %{conn: conn} do
      request = get(conn, "/api/v2/tokens/0x/counters")

      assert %{"message" => "Invalid parameter(s)"} = json_response(request, 422)
    end

    test "get counters", %{conn: conn} do
      token = insert(:token)

      request = get(conn, "/api/v2/tokens/#{token.contract_address.hash}/counters")

      assert response = json_response(request, 200)

      assert response["transfers_count"] == "0"
      assert response["token_holders_count"] == "0"
    end

    test "get not zero counters", %{conn: conn} do
      contract_token_address = insert(:contract_address)
      token = insert(:token, contract_address: contract_token_address)

      transaction =
        :transaction
        |> insert(to_address: contract_token_address)
        |> with_block()

      insert_list(
        3,
        :token_transfer,
        transaction: transaction,
        token_contract_address: contract_token_address
      )

      _second_page_token_balances =
        1..5
        |> Enum.map(
          &insert(
            :address_current_token_balance,
            token_contract_address_hash: token.contract_address_hash,
            value: &1 + 1000
          )
        )

      request = get(conn, "/api/v2/tokens/#{token.contract_address.hash}/counters")

      assert response = json_response(request, 200)

      assert response["transfers_count"] == "3"
      assert response["token_holders_count"] == "5"
    end
  end

  describe "/tokens/{address_hash}/transfers" do
    test "get 200 on non existing address", %{conn: conn} do
      token = build(:token)

      request = get(conn, "/api/v2/tokens/#{token.contract_address.hash}/transfers")

      assert %{"message" => "Not found"} = json_response(request, 404)
    end

    test "get 422 on invalid address", %{conn: conn} do
      request = get(conn, "/api/v2/tokens/0x/transfers")

      assert %{"message" => "Invalid parameter(s)"} = json_response(request, 422)
    end

    test "get empty list", %{conn: conn} do
      token = insert(:token)

      request = get(conn, "/api/v2/tokens/#{token.contract_address.hash}/transfers")

      assert %{"items" => [], "next_page_params" => nil} = json_response(request, 200)
    end

    test "check pagination", %{conn: conn} do
      token = insert(:token)

      token_transfers =
        for _ <- 0..50 do
          tx = insert(:transaction, input: "0xabcd010203040506") |> with_block()

          insert(:token_transfer,
            transaction: tx,
            block: tx.block,
            block_number: tx.block_number,
            token_contract_address: token.contract_address
          )
        end

      request = get(conn, "/api/v2/tokens/#{token.contract_address.hash}/transfers")
      assert response = json_response(request, 200)

      request_2nd_page =
        get(conn, "/api/v2/tokens/#{token.contract_address.hash}/transfers", response["next_page_params"])

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, token_transfers)
    end

    test "check that same token_ids within batch squashes", %{conn: conn} do
      token = insert(:token, type: "ERC-1155")

      id = 0

      insert(:token_instance, token_id: id, token_contract_address_hash: token.contract_address_hash)

      tt =
        for _ <- 0..50 do
          tx = insert(:transaction, input: "0xabcd010203040506") |> with_block()

          insert(:token_transfer,
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

      request = get(conn, "/api/v2/tokens/#{token.contract_address.hash}/transfers")
      assert response = json_response(request, 200)

      request_2nd_page =
        get(conn, "/api/v2/tokens/#{token.contract_address.hash}/transfers", response["next_page_params"])

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, token_transfers)
    end

    test "check that pagination works for 721 tokens", %{conn: conn} do
      token = insert(:token, type: "ERC-721")

      token_transfers =
        for i <- 0..50 do
          tx = insert(:transaction, input: "0xabcd010203040506") |> with_block()

          insert(:token_transfer,
            transaction: tx,
            block: tx.block,
            block_number: tx.block_number,
            token_contract_address: token.contract_address,
            token_ids: [i]
          )
        end

      request = get(conn, "/api/v2/tokens/#{token.contract_address.hash}/transfers")
      assert response = json_response(request, 200)

      request_2nd_page =
        get(conn, "/api/v2/tokens/#{token.contract_address.hash}/transfers", response["next_page_params"])

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, token_transfers)
    end

    test "check that pagination works fine with 1155 batches #1 (large batch)", %{conn: conn} do
      token = insert(:token, type: "ERC-1155")
      tx = insert(:transaction, input: "0xabcd010203040506") |> with_block()

      tt =
        insert(:token_transfer,
          transaction: tx,
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

      request = get(conn, "/api/v2/tokens/#{token.contract_address.hash}/transfers")
      assert response = json_response(request, 200)

      request_2nd_page =
        get(conn, "/api/v2/tokens/#{token.contract_address.hash}/transfers", response["next_page_params"])

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, token_transfers)
    end

    test "check that pagination works fine with 1155 batches #2 some batches on the first page and one on the second",
         %{conn: conn} do
      token = insert(:token, type: "ERC-1155")

      tx_1 = insert(:transaction, input: "0xabcd010203040506") |> with_block()

      tt_1 =
        insert(:token_transfer,
          transaction: tx_1,
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
          block: tx_2.block,
          block_number: tx_2.block_number,
          token_contract_address: token.contract_address,
          token_ids: [50],
          amounts: [50]
        )

      request = get(conn, "/api/v2/tokens/#{token.contract_address.hash}/transfers")
      assert response = json_response(request, 200)

      request_2nd_page =
        get(conn, "/api/v2/tokens/#{token.contract_address.hash}/transfers", response["next_page_params"])

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, token_transfers_1 ++ token_transfers_2 ++ [tt_3])
    end

    test "check that pagination works fine with 1155 batches #3", %{conn: conn} do
      token = insert(:token, type: "ERC-1155")

      tx_1 = insert(:transaction, input: "0xabcd010203040506") |> with_block()

      tt_1 =
        insert(:token_transfer,
          transaction: tx_1,
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

      request = get(conn, "/api/v2/tokens/#{token.contract_address.hash}/transfers")
      assert response = json_response(request, 200)

      request_2nd_page =
        get(conn, "/api/v2/tokens/#{token.contract_address.hash}/transfers", response["next_page_params"])

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, token_transfers_1 ++ token_transfers_2)
    end
  end

  describe "/tokens/{address_hash}/holders" do
    test "get 200 on non existing address", %{conn: conn} do
      token = build(:token)

      request = get(conn, "/api/v2/tokens/#{token.contract_address.hash}/holders")

      assert %{"message" => "Not found"} = json_response(request, 404)
    end

    test "get 422 on invalid address", %{conn: conn} do
      request = get(conn, "/api/v2/tokens/0x/holders")

      assert %{"message" => "Invalid parameter(s)"} = json_response(request, 422)
    end

    test "get empty list", %{conn: conn} do
      token = insert(:token)

      request = get(conn, "/api/v2/tokens/#{token.contract_address.hash}/holders")

      assert %{"items" => [], "next_page_params" => nil} = json_response(request, 200)
    end

    test "check pagination", %{conn: conn} do
      token = insert(:token)

      token_balances =
        for i <- 0..50 do
          insert(
            :address_current_token_balance,
            token_contract_address_hash: token.contract_address_hash,
            value: i + 1000
          )
        end

      request = get(conn, "/api/v2/tokens/#{token.contract_address.hash}/holders")
      assert response = json_response(request, 200)

      request_2nd_page =
        get(conn, "/api/v2/tokens/#{token.contract_address.hash}/holders", response["next_page_params"])

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, token_balances)
    end
  end

  describe "/tokens" do
    defp check_tokens_pagination(tokens, conn) do
      request = get(conn, "/api/v2/tokens")
      assert response = json_response(request, 200)
      request_2nd_page = get(conn, "/api/v2/tokens", response["next_page_params"])
      assert response_2nd_page = json_response(request_2nd_page, 200)
      check_paginated_response(response, response_2nd_page, tokens)
    end

    test "get empty list", %{conn: conn} do
      request = get(conn, "/api/v2/tokens")

      assert %{"items" => [], "next_page_params" => nil} = json_response(request, 200)
    end

    # these tests that tokens paginates by each parameter separately and by any combination of them
    test "pagination by address", %{conn: conn} do
      tokens =
        for i <- 0..50 do
          insert(:token, name: nil)
        end
        |> Enum.reverse()

      check_tokens_pagination(tokens, conn)
    end

    test "pagination by name", %{conn: conn} do
      tokens =
        for i <- 0..48 do
          insert(:token, holder_count: i)
        end

      empty_named_token = insert(:token, name: "")
      named_token = insert(:token)

      tokens = [named_token, empty_named_token | tokens]

      check_tokens_pagination(tokens, conn)
    end

    test "pagination by holders", %{conn: conn} do
      tokens =
        for i <- 0..50 do
          insert(:token, holder_count: i, name: nil)
        end

      check_tokens_pagination(tokens, conn)
    end

    test "pagination by circulating_market_cap", %{conn: conn} do
      tokens =
        for i <- 0..50 do
          insert(:token, circulating_market_cap: i, name: nil)
        end

      check_tokens_pagination(tokens, conn)
    end

    test "pagination by name and address", %{conn: conn} do
      tokens =
        for i <- 0..50 do
          insert(:token)
        end
        |> Enum.reverse()

      check_tokens_pagination(tokens, conn)
    end

    test "pagination by holders and address", %{conn: conn} do
      tokens =
        for i <- 0..50 do
          insert(:token, holder_count: 1, name: nil)
        end
        |> Enum.reverse()

      check_tokens_pagination(tokens, conn)
    end

    test "pagination by circulating_market_cap and address", %{conn: conn} do
      tokens =
        for i <- 0..50 do
          insert(:token, circulating_market_cap: 1, name: nil)
        end
        |> Enum.reverse()

      check_tokens_pagination(tokens, conn)
    end

    test "pagination by holders and name", %{conn: conn} do
      tokens =
        for i <- 1..51 do
          insert(:token, holder_count: 1, name: List.to_string([i]))
        end
        |> Enum.reverse()

      check_tokens_pagination(tokens, conn)
    end

    test "pagination by circulating_market_cap and name", %{conn: conn} do
      tokens =
        for i <- 1..51 do
          insert(:token, circulating_market_cap: 1, name: List.to_string([i]))
        end
        |> Enum.reverse()

      check_tokens_pagination(tokens, conn)
    end

    test "pagination by circulating_market_cap and holders", %{conn: conn} do
      tokens =
        for i <- 0..50 do
          insert(:token, circulating_market_cap: 1, holder_count: i, name: nil)
        end

      check_tokens_pagination(tokens, conn)
    end

    test "pagination by holders, name and address", %{conn: conn} do
      tokens =
        for i <- 0..50 do
          insert(:token, holder_count: 1)
        end
        |> Enum.reverse()

      check_tokens_pagination(tokens, conn)
    end

    test "pagination by circulating_market_cap, name and address", %{conn: conn} do
      tokens =
        for i <- 0..50 do
          insert(:token, circulating_market_cap: 1)
        end
        |> Enum.reverse()

      check_tokens_pagination(tokens, conn)
    end

    test "pagination by circulating_market_cap, holders and address", %{conn: conn} do
      tokens =
        for i <- 0..50 do
          insert(:token, circulating_market_cap: 1, holder_count: 1, name: nil)
        end
        |> Enum.reverse()

      check_tokens_pagination(tokens, conn)
    end

    test "pagination by circulating_market_cap, holders and name", %{conn: conn} do
      tokens =
        for i <- 1..51 do
          insert(:token, circulating_market_cap: 1, holder_count: 1, name: List.to_string([i]))
        end
        |> Enum.reverse()

      check_tokens_pagination(tokens, conn)
    end

    test "pagination by circulating_market_cap, holders, name and address", %{conn: conn} do
      tokens =
        for i <- 0..50 do
          insert(:token, holder_count: 1, circulating_market_cap: 1)
        end
        |> Enum.reverse()

      check_tokens_pagination(tokens, conn)
    end

    test "check nil", %{conn: conn} do
      token = insert(:token)

      request = get(conn, "/api/v2/tokens")

      assert %{"items" => [token_json], "next_page_params" => nil} = json_response(request, 200)

      compare_item(token, token_json)
    end
  end

  describe "/tokens/{address_hash}/instances" do
    test "get 404 on non existing address", %{conn: conn} do
      token = build(:token)

      request = get(conn, "/api/v2/tokens/#{token.contract_address.hash}/instances")

      assert %{"message" => "Not found"} = json_response(request, 404)
    end

    test "get 422 on invalid address", %{conn: conn} do
      request = get(conn, "/api/v2/tokens/0x/instances")

      assert %{"message" => "Invalid parameter(s)"} = json_response(request, 422)
    end

    test "get empty list", %{conn: conn} do
      token = insert(:token)

      request = get(conn, "/api/v2/tokens/#{token.contract_address.hash}/instances")

      assert %{"items" => [], "next_page_params" => nil} = json_response(request, 200)
    end

    test "get instances list", %{conn: conn} do
      token = insert(:token)

      for _ <- 0..50 do
        insert(:token_instance)
      end

      instances =
        for _ <- 0..50 do
          insert(:token_instance, token_contract_address_hash: token.contract_address_hash)
        end

      request = get(conn, "/api/v2/tokens/#{token.contract_address_hash}/instances")
      assert response = json_response(request, 200)

      request_2nd_page =
        get(conn, "/api/v2/tokens/#{token.contract_address_hash}/instances", response["next_page_params"])

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, instances)
    end
  end

  describe "/tokens/{address_hash}/instances/{token_id}" do
    test "get 404 on non existing address", %{conn: conn} do
      token = build(:token)

      request = get(conn, "/api/v2/tokens/#{token.contract_address.hash}/instances/12")

      assert %{"message" => "Not found"} = json_response(request, 404)
    end

    test "get 422 on invalid address", %{conn: conn} do
      request = get(conn, "/api/v2/tokens/0x/instances/12")

      assert %{"message" => "Invalid parameter(s)"} = json_response(request, 422)
    end

    test "get token instance by token id", %{conn: conn} do
      token = insert(:token, type: "ERC-721")

      for _ <- 0..50 do
        insert(:token_instance, token_id: 0)
      end

      transaction =
        :transaction
        |> insert()
        |> with_block()

      instance = insert(:token_instance, token_id: 0, token_contract_address_hash: token.contract_address_hash)

      transfer =
        insert(:token_transfer,
          token_contract_address: token.contract_address,
          transaction: transaction,
          token_ids: [0]
        )

      for _ <- 1..50 do
        insert(:token_instance, token_contract_address_hash: token.contract_address_hash)
      end

      request = get(conn, "/api/v2/tokens/#{token.contract_address.hash}/instances/0")

      assert data = json_response(request, 200)
      assert compare_item(instance, data)
      assert compare_item(transfer.to_address, data["owner"])
    end
  end

  describe "/tokens/{address_hash}/instances/{token_id}/transfers" do
    test "get 404 on non existing address", %{conn: conn} do
      token = build(:token)

      request = get(conn, "/api/v2/tokens/#{token.contract_address.hash}/instances/12/transfers")

      assert %{"message" => "Not found"} = json_response(request, 404)
    end

    test "get 422 on invalid address", %{conn: conn} do
      request = get(conn, "/api/v2/tokens/0x/instances/12/transfers")

      assert %{"message" => "Invalid parameter(s)"} = json_response(request, 422)
    end

    test "get token transfers by instance", %{conn: conn} do
      token = insert(:token, type: "ERC-1155")

      for _ <- 0..50 do
        insert(:token_instance, token_id: 0)
      end

      id = :rand.uniform(1_000_000)

      transaction =
        :transaction
        |> insert(input: "0xabcd010203040506")
        |> with_block()

      insert(:token_instance, token_id: id, token_contract_address_hash: token.contract_address_hash)

      insert_list(100, :token_transfer,
        token_contract_address: token.contract_address,
        transaction: transaction,
        token_ids: [id + 1],
        amounts: [1]
      )

      transfers_0 =
        insert_list(26, :token_transfer,
          token_contract_address: token.contract_address,
          transaction: transaction,
          token_ids: [id, id + 1],
          amounts: [1, 2]
        )

      transfers_1 =
        for _ <- 26..50 do
          transaction =
            :transaction
            |> insert(input: "0xabcd010203040506")
            |> with_block()

          insert(:token_transfer,
            token_contract_address: token.contract_address,
            transaction: transaction,
            token_ids: [id]
          )
        end

      request = get(conn, "/api/v2/tokens/#{token.contract_address_hash}/instances/#{id}/transfers")
      assert response = json_response(request, 200)

      request_2nd_page =
        get(
          conn,
          "/api/v2/tokens/#{token.contract_address_hash}/instances/#{id}/transfers",
          response["next_page_params"]
        )

      assert response_2nd_page = json_response(request_2nd_page, 200)
      check_paginated_response(response, response_2nd_page, transfers_0 ++ transfers_1)
    end

    test "check that pagination works for 721 tokens", %{conn: conn} do
      token = insert(:token, type: "ERC-721")
      id = 0
      insert(:token_instance, token_id: id, token_contract_address_hash: token.contract_address_hash)

      token_transfers =
        for _i <- 0..50 do
          tx = insert(:transaction, input: "0xabcd010203040506") |> with_block()

          insert(:token_transfer,
            transaction: tx,
            block: tx.block,
            block_number: tx.block_number,
            token_contract_address: token.contract_address,
            token_ids: [id]
          )
        end

      request = get(conn, "/api/v2/tokens/#{token.contract_address.hash}/instances/#{id}/transfers")
      assert response = json_response(request, 200)

      request_2nd_page =
        get(
          conn,
          "/api/v2/tokens/#{token.contract_address.hash}/instances/#{id}/transfers",
          response["next_page_params"]
        )

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, token_transfers)
    end

    test "check that same token_ids within batch squashes", %{conn: conn} do
      token = insert(:token, type: "ERC-1155")

      id = 0

      insert(:token_instance, token_id: id, token_contract_address_hash: token.contract_address_hash)

      tx = insert(:transaction, input: "0xabcd010203040506") |> with_block()

      tt =
        insert(:token_transfer,
          transaction: tx,
          block: tx.block,
          block_number: tx.block_number,
          token_contract_address: token.contract_address,
          token_ids: Enum.map(0..50, fn _x -> id end),
          amounts: Enum.map(0..50, fn x -> x end)
        )

      token_transfer = %TokenTransfer{tt | token_ids: [id], amount: Decimal.new(1275)}

      request = get(conn, "/api/v2/tokens/#{token.contract_address.hash}/instances/#{id}/transfers")
      assert %{"next_page_params" => nil, "items" => [item]} = json_response(request, 200)
      compare_item(token_transfer, item)
    end

    test "check that pagination works fine with 1155 batches #1 (51 batch with twice repeated id. Repeated id squashed into one element)",
         %{conn: conn} do
      token = insert(:token, type: "ERC-1155")

      id = 0
      amount = 101
      insert(:token_instance, token_id: id, token_contract_address_hash: token.contract_address_hash)

      tx = insert(:transaction, input: "0xabcd010203040506") |> with_block()

      tt =
        for _ <- 0..50 do
          insert(:token_transfer,
            transaction: tx,
            block: tx.block,
            block_number: tx.block_number,
            token_contract_address: token.contract_address,
            token_ids: Enum.map(0..50, fn x -> x end) ++ [id],
            amounts: Enum.map(1..51, fn x -> x end) ++ [amount]
          )
        end

      token_transfers =
        for i <- tt do
          %TokenTransfer{i | token_ids: [id], amount: amount + 1}
        end

      request = get(conn, "/api/v2/tokens/#{token.contract_address.hash}/instances/#{id}/transfers")
      assert response = json_response(request, 200)

      request_2nd_page =
        get(
          conn,
          "/api/v2/tokens/#{token.contract_address.hash}/instances/#{id}/transfers",
          response["next_page_params"]
        )

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, token_transfers)
    end
  end

  describe "/tokens/{address_hash}/instances/{token_id}/holders" do
    test "get 404 on non existing address", %{conn: conn} do
      token = build(:token)

      request = get(conn, "/api/v2/tokens/#{token.contract_address.hash}/instances/12/holders")

      assert %{"message" => "Not found"} = json_response(request, 404)
    end

    test "get 422 on invalid address", %{conn: conn} do
      request = get(conn, "/api/v2/tokens/0x/instances/12/holders")

      assert %{"message" => "Invalid parameter(s)"} = json_response(request, 422)
    end

    test "get 422 on invalid id", %{conn: conn} do
      token = insert(:token, type: "ERC-1155")

      request = get(conn, "/api/v2/tokens/#{token.contract_address_hash}/instances/123ab/holders")

      assert %{"message" => "Invalid parameter(s)"} = json_response(request, 422)
    end

    test "get token transfers by instance", %{conn: conn} do
      token = insert(:token, type: "ERC-1155")

      id = :rand.uniform(1_000_000)
      insert(:token_instance, token_id: id - 1, token_contract_address_hash: token.contract_address_hash)

      insert(
        :address_current_token_balance,
        token_contract_address_hash: token.contract_address_hash,
        value: 1000,
        token_id: id - 1
      )

      insert(:token_instance, token_id: id, token_contract_address_hash: token.contract_address_hash)

      token_balances =
        for i <- 0..50 do
          insert(
            :address_current_token_balance_with_token_id,
            token_contract_address_hash: token.contract_address_hash,
            value: i + 1000,
            token_id: id
          )
        end

      request = get(conn, "/api/v2/tokens/#{token.contract_address.hash}/instances/#{id}/holders")
      assert response = json_response(request, 200)

      request_2nd_page =
        get(conn, "/api/v2/tokens/#{token.contract_address.hash}/instances/#{id}/holders", response["next_page_params"])

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, token_balances)
    end
  end

  describe "/tokens/{address_hash}/instances/{token_id}/transfers-count" do
    test "get 404 on non existing address", %{conn: conn} do
      token = build(:token)

      request = get(conn, "/api/v2/tokens/#{token.contract_address.hash}/instances/12/transfers-count")

      assert %{"message" => "Not found"} = json_response(request, 404)
    end

    test "get 422 on invalid address", %{conn: conn} do
      request = get(conn, "/api/v2/tokens/0x/instances/12/transfers-count")

      assert %{"message" => "Invalid parameter(s)"} = json_response(request, 422)
    end

    test "receive 0 count", %{conn: conn} do
      token = insert(:token, type: "ERC-721")

      insert(:token_instance, token_id: 0, token_contract_address_hash: token.contract_address_hash)

      request = get(conn, "/api/v2/tokens/#{token.contract_address.hash}/instances/0/transfers-count")

      assert %{"transfers_count" => 0} = json_response(request, 200)
    end

    test "get count > 0", %{conn: conn} do
      token = insert(:token, type: "ERC-721")

      for _ <- 0..50 do
        insert(:token_instance, token_id: 0)
      end

      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(:token_instance, token_id: 0, token_contract_address_hash: token.contract_address_hash)

      count = :rand.uniform(1000)

      insert_list(count, :token_transfer,
        token_contract_address: token.contract_address,
        transaction: transaction,
        token_ids: [0]
      )

      request = get(conn, "/api/v2/tokens/#{token.contract_address.hash}/instances/0/transfers-count")

      assert %{"transfers_count" => ^count} = json_response(request, 200)
    end
  end

  def compare_item(%Address{} = address, json) do
    assert Address.checksum(address.hash) == json["hash"]
  end

  def compare_item(%Token{} = token, json) do
    assert Address.checksum(token.contract_address.hash) == json["address"]
    assert token.symbol == json["symbol"]
    assert token.name == json["name"]
    assert to_string(token.decimals) == json["decimals"]
    assert token.type == json["type"]

    assert (is_nil(token.holder_count) and is_nil(json["holders"])) or
             (to_string(token.holder_count) == json["holders"] and !is_nil(token.holder_count))

    assert to_string(token.total_supply) == json["total_supply"]
    assert Map.has_key?(json, "exchange_rate")
  end

  def compare_item(%TokenTransfer{} = token_transfer, json) do
    assert Address.checksum(token_transfer.from_address_hash) == json["from"]["hash"]
    assert Address.checksum(token_transfer.to_address_hash) == json["to"]["hash"]
    assert to_string(token_transfer.transaction_hash) == json["tx_hash"]
    assert json["timestamp"] != nil
    assert json["method"] != nil
    assert to_string(token_transfer.block_hash) == json["block_hash"]
    assert to_string(token_transfer.log_index) == json["log_index"]
    assert check_total(Repo.preload(token_transfer, [{:token, :contract_address}]).token, json["total"], token_transfer)
  end

  def compare_item(%CurrentTokenBalance{} = ctb, json) do
    assert Address.checksum(ctb.address_hash) == json["address"]["hash"]
    assert (ctb.token_id && to_string(ctb.token_id)) == json["token_id"]
    assert to_string(ctb.value) == json["value"]
    compare_item(Repo.preload(ctb, [{:token, :contract_address}]).token, json["token"])
  end

  def compare_item(%Instance{} = instance, json) do
    assert to_string(instance.token_id) == json["id"]
    assert Jason.decode!(Jason.encode!(instance.metadata)) == json["metadata"]
    assert json["is_unique"]
    compare_item(Repo.preload(instance, [{:token, :contract_address}]).token, json["token"])
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

  defp check_paginated_response(first_page_resp, second_page_resp, list) do
    assert Enum.count(first_page_resp["items"]) == 50
    assert first_page_resp["next_page_params"] != nil
    compare_item(Enum.at(list, 50), Enum.at(first_page_resp["items"], 0))
    compare_item(Enum.at(list, 1), Enum.at(first_page_resp["items"], 49))

    assert Enum.count(second_page_resp["items"]) == 1
    assert second_page_resp["next_page_params"] == nil
    compare_item(Enum.at(list, 0), Enum.at(second_page_resp["items"], 0))
  end
end
