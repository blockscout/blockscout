defmodule BlockScoutWeb.API.V2.TokenControllerTest do
  use EthereumJSONRPC.Case, async: false
  use BlockScoutWeb.ConnCase
  use BlockScoutWeb.ChannelCase, async: false

  import Mox

  alias Explorer.{Repo, TestHelper}

  alias Explorer.Chain.{Address, Token, Token.Instance, TokenTransfer}
  alias Explorer.Chain.Address.CurrentTokenBalance
  alias Explorer.Chain.Events.Subscriber

  alias Indexer.Fetcher.OnDemand.TokenInstanceMetadataRefetch, as: TokenInstanceMetadataRefetchOnDemand
  alias Indexer.Fetcher.OnDemand.NFTCollectionMetadataRefetch, as: NFTCollectionMetadataRefetchOnDemand

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
      assert json_response(request, 200)

      Process.sleep(500)
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
          transaction = insert(:transaction, input: "0xabcd010203040506") |> with_block()

          insert(:token_transfer,
            transaction: transaction,
            block: transaction.block,
            block_number: transaction.block_number,
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
          transaction = insert(:transaction, input: "0xabcd010203040506") |> with_block()

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
          transaction = insert(:transaction, input: "0xabcd010203040506") |> with_block()

          insert(:token_transfer,
            transaction: transaction,
            block: transaction.block,
            block_number: transaction.block_number,
            token_contract_address: token.contract_address,
            token_ids: [i],
            token_type: "ERC-721"
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
      transaction = insert(:transaction, input: "0xabcd010203040506") |> with_block()

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

      transaction_1 = insert(:transaction, input: "0xabcd010203040506") |> with_block()

      tt_1 =
        insert(:token_transfer,
          transaction: transaction_1,
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
          block: transaction_2.block,
          block_number: transaction_2.block_number,
          token_contract_address: token.contract_address,
          token_ids: [50],
          token_type: "ERC-1155",
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

      transaction_1 = insert(:transaction, input: "0xabcd010203040506") |> with_block()

      tt_1 =
        insert(:token_transfer,
          transaction: transaction_1,
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

      check_holders_paginated_response(response, response_2nd_page, token_balances)
    end

    test "check pagination with the same values", %{conn: conn} do
      token = insert(:token)

      token_balances =
        for _ <- 0..50 do
          insert(
            :address_current_token_balance,
            token_contract_address_hash: token.contract_address_hash,
            value: 1000
          )
        end
        |> Enum.sort_by(fn x -> x.address_hash end, :asc)

      request = get(conn, "/api/v2/tokens/#{token.contract_address.hash}/holders")
      assert response = json_response(request, 200)

      request_2nd_page =
        get(conn, "/api/v2/tokens/#{token.contract_address.hash}/holders", response["next_page_params"])

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_holders_paginated_response(response, response_2nd_page, token_balances)
    end
  end

  describe "/tokens" do
    defp check_tokens_pagination(tokens, conn, additional_params \\ %{}) do
      request = get(conn, "/api/v2/tokens", additional_params)
      assert response = json_response(request, 200)
      request_2nd_page = get(conn, "/api/v2/tokens", additional_params |> Map.merge(response["next_page_params"]))
      assert response_2nd_page = json_response(request_2nd_page, 200)
      check_paginated_response(response, response_2nd_page, tokens)

      # by fiat_value
      tokens_ordered_by_fiat_value = Enum.sort(tokens, &(Decimal.compare(&1.fiat_value, &2.fiat_value) in [:eq, :lt]))

      request_ordered_by_fiat_value =
        get(conn, "/api/v2/tokens", additional_params |> Map.merge(%{"sort" => "fiat_value", "order" => "desc"}))

      assert response_ordered_by_fiat_value = json_response(request_ordered_by_fiat_value, 200)

      request_ordered_by_fiat_value_2nd_page =
        get(
          conn,
          "/api/v2/tokens",
          additional_params
          |> Map.merge(%{"sort" => "fiat_value", "order" => "desc"})
          |> Map.merge(response_ordered_by_fiat_value["next_page_params"])
        )

      assert response_ordered_by_fiat_value_2nd_page = json_response(request_ordered_by_fiat_value_2nd_page, 200)

      check_paginated_response(
        response_ordered_by_fiat_value,
        response_ordered_by_fiat_value_2nd_page,
        tokens_ordered_by_fiat_value
      )

      tokens_ordered_by_fiat_value_asc =
        Enum.sort(tokens, &(Decimal.compare(&1.fiat_value, &2.fiat_value) in [:eq, :gt]))

      request_ordered_by_fiat_value_asc =
        get(conn, "/api/v2/tokens", additional_params |> Map.merge(%{"sort" => "fiat_value", "order" => "asc"}))

      assert response_ordered_by_fiat_value_asc = json_response(request_ordered_by_fiat_value_asc, 200)

      request_ordered_by_fiat_value_asc_2nd_page =
        get(
          conn,
          "/api/v2/tokens",
          additional_params
          |> Map.merge(%{"sort" => "fiat_value", "order" => "asc"})
          |> Map.merge(response_ordered_by_fiat_value_asc["next_page_params"])
        )

      assert response_ordered_by_fiat_value_asc_2nd_page =
               json_response(request_ordered_by_fiat_value_asc_2nd_page, 200)

      check_paginated_response(
        response_ordered_by_fiat_value_asc,
        response_ordered_by_fiat_value_asc_2nd_page,
        tokens_ordered_by_fiat_value_asc
      )

      # by holders
      tokens_ordered_by_holders = Enum.sort(tokens, &(&1.holder_count <= &2.holder_count))

      request_ordered_by_holders =
        get(conn, "/api/v2/tokens", additional_params |> Map.merge(%{"sort" => "holder_count", "order" => "desc"}))

      assert response_ordered_by_holders = json_response(request_ordered_by_holders, 200)

      request_ordered_by_holders_2nd_page =
        get(
          conn,
          "/api/v2/tokens",
          additional_params
          |> Map.merge(%{"sort" => "holder_count", "order" => "desc"})
          |> Map.merge(response_ordered_by_holders["next_page_params"])
        )

      assert response_ordered_by_holders_2nd_page = json_response(request_ordered_by_holders_2nd_page, 200)

      check_paginated_response(
        response_ordered_by_holders,
        response_ordered_by_holders_2nd_page,
        tokens_ordered_by_holders
      )

      tokens_ordered_by_holders_asc = Enum.sort(tokens, &(&1.holder_count >= &2.holder_count))

      request_ordered_by_holders_asc =
        get(conn, "/api/v2/tokens", additional_params |> Map.merge(%{"sort" => "holder_count", "order" => "asc"}))

      assert response_ordered_by_holders_asc = json_response(request_ordered_by_holders_asc, 200)

      request_ordered_by_holders_asc_2nd_page =
        get(
          conn,
          "/api/v2/tokens",
          additional_params
          |> Map.merge(%{"sort" => "holder_count", "order" => "asc"})
          |> Map.merge(response_ordered_by_holders_asc["next_page_params"])
        )

      assert response_ordered_by_holders_asc_2nd_page = json_response(request_ordered_by_holders_asc_2nd_page, 200)

      check_paginated_response(
        response_ordered_by_holders_asc,
        response_ordered_by_holders_asc_2nd_page,
        tokens_ordered_by_holders_asc
      )

      :timer.sleep(200)

      # by circulating_market_cap
      tokens_ordered_by_circulating_market_cap =
        Enum.sort(tokens, &(&1.circulating_market_cap <= &2.circulating_market_cap))

      request_ordered_by_circulating_market_cap =
        get(
          conn,
          "/api/v2/tokens",
          additional_params |> Map.merge(%{"sort" => "circulating_market_cap", "order" => "desc"})
        )

      assert response_ordered_by_circulating_market_cap = json_response(request_ordered_by_circulating_market_cap, 200)

      request_ordered_by_circulating_market_cap_2nd_page =
        get(
          conn,
          "/api/v2/tokens",
          additional_params
          |> Map.merge(%{"sort" => "circulating_market_cap", "order" => "desc"})
          |> Map.merge(response_ordered_by_circulating_market_cap["next_page_params"])
        )

      assert response_ordered_by_circulating_market_cap_2nd_page =
               json_response(request_ordered_by_circulating_market_cap_2nd_page, 200)

      check_paginated_response(
        response_ordered_by_circulating_market_cap,
        response_ordered_by_circulating_market_cap_2nd_page,
        tokens_ordered_by_circulating_market_cap
      )

      tokens_ordered_by_circulating_market_cap_asc =
        Enum.sort(tokens, &(&1.circulating_market_cap >= &2.circulating_market_cap))

      request_ordered_by_circulating_market_cap_asc =
        get(
          conn,
          "/api/v2/tokens",
          additional_params |> Map.merge(%{"sort" => "circulating_market_cap", "order" => "asc"})
        )

      assert response_ordered_by_circulating_market_cap_asc =
               json_response(request_ordered_by_circulating_market_cap_asc, 200)

      request_ordered_by_circulating_market_cap_asc_2nd_page =
        get(
          conn,
          "/api/v2/tokens",
          additional_params
          |> Map.merge(%{"sort" => "circulating_market_cap", "order" => "asc"})
          |> Map.merge(response_ordered_by_circulating_market_cap_asc["next_page_params"])
        )

      assert response_ordered_by_circulating_market_cap_asc_2nd_page =
               json_response(request_ordered_by_circulating_market_cap_asc_2nd_page, 200)

      check_paginated_response(
        response_ordered_by_circulating_market_cap_asc,
        response_ordered_by_circulating_market_cap_asc_2nd_page,
        tokens_ordered_by_circulating_market_cap_asc
      )
    end

    test "get empty list", %{conn: conn} do
      request = get(conn, "/api/v2/tokens")

      assert %{"items" => [], "next_page_params" => nil} = json_response(request, 200)
    end

    test "ignores wrong ordering params", %{conn: conn} do
      tokens =
        for i <- 0..50 do
          insert(:token, fiat_value: i)
        end

      request = get(conn, "/api/v2/tokens", %{"sort" => "foo", "order" => "bar"})

      assert response = json_response(request, 200)

      request_2nd_page =
        get(conn, "/api/v2/tokens", %{"sort" => "foo", "order" => "bar"} |> Map.merge(response["next_page_params"]))

      assert response_2nd_page = json_response(request_2nd_page, 200)
      check_paginated_response(response, response_2nd_page, tokens)
    end

    test "tokens are filtered by single type", %{conn: conn} do
      erc_20_tokens =
        for i <- 0..50 do
          insert(:token, fiat_value: i)
        end

      erc_721_tokens =
        for _i <- 0..50 do
          insert(:token, type: "ERC-721")
        end

      erc_1155_tokens =
        for _i <- 0..50 do
          insert(:token, type: "ERC-1155")
        end

      erc_404_tokens =
        for _i <- 0..50 do
          insert(:token, type: "ERC-404")
        end

      check_tokens_pagination(erc_20_tokens, conn, %{"type" => "ERC-20"})
      check_tokens_pagination(erc_721_tokens |> Enum.reverse(), conn, %{"type" => "ERC-721"})
      check_tokens_pagination(erc_1155_tokens |> Enum.reverse(), conn, %{"type" => "ERC-1155"})
      check_tokens_pagination(erc_404_tokens |> Enum.reverse(), conn, %{"type" => "ERC-404"})
    end

    test "tokens are filtered by multiple type", %{conn: conn} do
      erc_20_tokens =
        for i <- 11..36 do
          insert(:token, fiat_value: i)
        end

      erc_721_tokens =
        for _i <- 0..25 do
          insert(:token, type: "ERC-721")
        end

      erc_1155_tokens =
        for _i <- 0..24 do
          insert(:token, type: "ERC-1155")
        end

      erc_404_tokens =
        for _i <- 0..24 do
          insert(:token, type: "ERC-404")
        end

      check_tokens_pagination(
        erc_721_tokens |> Kernel.++(erc_1155_tokens) |> Enum.reverse(),
        conn,
        %{
          "type" => "ERC-1155,ERC-721"
        }
      )

      check_tokens_pagination(
        erc_1155_tokens |> Enum.reverse() |> Kernel.++(erc_20_tokens),
        conn,
        %{
          "type" => "[erc-20,ERC-1155]"
        }
      )

      check_tokens_pagination(
        erc_404_tokens |> Enum.reverse() |> Kernel.++(erc_20_tokens),
        conn,
        %{
          "type" => "[erc-20,ERC-404]"
        }
      )
    end

    test "sorting by fiat_value", %{conn: conn} do
      tokens =
        for i <- 0..50 do
          insert(:token, fiat_value: i)
        end

      check_tokens_pagination(tokens, conn)
    end

    # these tests that tokens paginates by each parameter separately and by any combination of them
    test "pagination by address", %{conn: conn} do
      tokens =
        for _i <- 0..50 do
          insert(:token, name: nil)
        end
        |> Enum.reverse()

      check_tokens_pagination(tokens, conn)
    end

    test "pagination by name", %{conn: conn} do
      named_token = insert(:token, holder_count: 0)
      empty_named_token = insert(:token, name: "", holder_count: 0)

      tokens =
        for i <- 1..49 do
          insert(:token, holder_count: i)
        end

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
        for _i <- 0..50 do
          insert(:token)
        end
        |> Enum.reverse()

      check_tokens_pagination(tokens, conn)
    end

    test "pagination by holders and address", %{conn: conn} do
      tokens =
        for _i <- 0..50 do
          insert(:token, holder_count: 1, name: nil)
        end
        |> Enum.reverse()

      check_tokens_pagination(tokens, conn)
    end

    test "pagination by circulating_market_cap and address", %{conn: conn} do
      tokens =
        for _i <- 0..50 do
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
        for _i <- 0..50 do
          insert(:token, holder_count: 1)
        end
        |> Enum.reverse()

      check_tokens_pagination(tokens, conn)
    end

    test "pagination by circulating_market_cap, name and address", %{conn: conn} do
      tokens =
        for _i <- 0..50 do
          insert(:token, circulating_market_cap: 1)
        end
        |> Enum.reverse()

      check_tokens_pagination(tokens, conn)
    end

    test "pagination by circulating_market_cap, holders and address", %{conn: conn} do
      tokens =
        for _i <- 0..50 do
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
        for _i <- 0..50 do
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

    test "get instances list by holder erc-721", %{conn: conn} do
      token = insert(:token, type: "ERC-721")

      insert_list(51, :token_instance, token_contract_address_hash: token.contract_address_hash)

      address = insert(:address, contract_code: Enum.random([nil, "0x010101"]))

      insert_list(51, :token_instance)

      token_instances =
        for _ <- 0..50 do
          insert(:token_instance,
            owner_address_hash: address.hash,
            token_contract_address_hash: token.contract_address_hash
          )
          |> Repo.preload([:token, :owner])
        end

      filter = %{"holder_address_hash" => to_string(address.hash)}

      request = get(conn, "/api/v2/tokens/#{token.contract_address_hash}/instances", filter)
      assert response = json_response(request, 200)

      request_2nd_page =
        get(
          conn,
          "/api/v2/tokens/#{token.contract_address_hash}/instances",
          Map.merge(response["next_page_params"], filter)
        )

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, token_instances)
    end

    test "get instances list by holder erc-1155", %{conn: conn} do
      token = insert(:token, type: "ERC-1155")

      insert_list(51, :token_instance, token_contract_address_hash: token.contract_address_hash)

      address = insert(:address, contract_code: Enum.random([nil, "0x010101"]))

      insert_list(51, :token_instance)

      token_instances =
        for _ <- 0..50 do
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
              token_contract_address_hash: token.contract_address_hash,
              value: Enum.random(1..2)
            )

          %Instance{ti | current_token_balance: current_token_balance, owner: address}
        end

      filter = %{"holder_address_hash" => to_string(address.hash)}

      request = get(conn, "/api/v2/tokens/#{token.contract_address_hash}/instances", filter)
      assert response = json_response(request, 200)

      request_2nd_page =
        get(
          conn,
          "/api/v2/tokens/#{token.contract_address_hash}/instances",
          Map.merge(response["next_page_params"], filter)
        )

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, token_instances)
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

      _transfer =
        insert(:token_transfer,
          token_contract_address: token.contract_address,
          transaction: transaction,
          token_ids: [0],
          token_type: "ERC-721"
        )

      for _ <- 1..50 do
        insert(:token_instance, token_contract_address_hash: token.contract_address_hash)
      end

      request = get(conn, "/api/v2/tokens/#{token.contract_address.hash}/instances/0")

      assert data = json_response(request, 200)
      assert compare_item(instance, data)
      assert Address.checksum(instance.owner_address_hash) == data["owner"]["hash"]
    end

    test "get 404 on token instance which is not presented in DB", %{conn: conn} do
      token = insert(:token, type: "ERC-721")

      request = get(conn, "/api/v2/tokens/#{token.contract_address.hash}/instances/0")

      assert %{"message" => "Not found"} = json_response(request, 404)
    end

    # https://github.com/blockscout/blockscout/issues/9906
    test "regression for #9906", %{conn: conn} do
      token = insert(:token, type: "ERC-721")

      insert(:token_instance,
        token_id: 0,
        token_contract_address_hash: token.contract_address_hash,
        metadata: %{
          "image_url" => "ipfs://QmTQBtvkCQKnxbUejwYHrs2G74JR2qFwxPUqRb3BQ6BM3S/gm%20gm%20feelin%20blue%204k.png"
        }
      )

      request = get(conn, "/api/v2/tokens/#{token.contract_address.hash}/instances/0")

      assert %{
               "image_url" =>
                 "https://ipfs.io/ipfs/QmTQBtvkCQKnxbUejwYHrs2G74JR2qFwxPUqRb3BQ6BM3S/gm%20gm%20feelin%20blue%204k.png"
             } = json_response(request, 200)
    end

    # https://github.com/blockscout/blockscout/issues/11149
    test "regression for #11149", %{conn: conn} do
      token = insert(:token, type: "ERC-721")

      old_env = Application.get_env(:indexer, :ipfs)

      public_ipfs_gateway = "https://ipfs_custom.io/ipfs"

      Application.put_env(
        :indexer,
        :ipfs,
        Keyword.merge(old_env,
          gateway_url_param_key: "secret_key",
          gateway_url_param_value: "secret_value",
          gateway_url_param_location: :query,
          gateway_url: "http://localhost/",
          public_gateway_url: public_ipfs_gateway
        )
      )

      insert(:token_instance,
        token_id: 0,
        token_contract_address_hash: token.contract_address_hash,
        metadata: %{
          "image_url" => "ipfs://QmTQBtvkCQKnxbUejwYHrs2G74JR2qFwxPUqRb3BQ6BM3S/123.png"
        }
      )

      request = get(conn, "/api/v2/tokens/#{token.contract_address.hash}/instances/0")

      assert %{
               "image_url" => "https://ipfs_custom.io/ipfs/QmTQBtvkCQKnxbUejwYHrs2G74JR2qFwxPUqRb3BQ6BM3S/123.png"
             } = json_response(request, 200)

      Application.put_env(:indexer, :ipfs, old_env)
    end

    test "metadata dropped on token uri on demand filler", %{conn: conn} do
      token = insert(:token, type: "ERC-721")

      insert(:token_instance,
        token_id: 0,
        token_contract_address_hash: token.contract_address_hash,
        metadata: %{"awesome" => "metadata"}
      )

      encoded_url_1 =
        "0x" <>
          (ABI.TypeEncoder.encode(["http://240.0.0.0/api/metadata.json"], %ABI.FunctionSelector{
             function: nil,
             types: [
               :string
             ]
           })
           |> Base.encode16(case: :lower))

      token_contract_address_hash_string = to_string(token.contract_address_hash)

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        fn [
             %{
               id: id_1,
               jsonrpc: "2.0",
               method: "eth_call",
               params: [
                 %{
                   data: "0xc87b56dd0000000000000000000000000000000000000000000000000000000000000000",
                   to: ^token_contract_address_hash_string
                 },
                 "latest"
               ]
             }
           ],
           _options ->
          {:ok, [%{id: id_1, jsonrpc: "2.0", result: encoded_url_1}]}
        end
      )

      request = get(conn, "/api/v2/tokens/#{token.contract_address.hash}/instances/0")

      assert data = json_response(request, 200)
      assert data["metadata"] == nil

      instance = Repo.one(Instance)
      assert instance.metadata == nil
      assert instance.error == "blacklist"
      assert instance.skip_metadata_url == false
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
        token_type: "ERC-1155",
        amounts: [1]
      )

      transfers_0 =
        insert_list(26, :token_transfer,
          token_contract_address: token.contract_address,
          transaction: transaction,
          token_ids: [id, id + 1],
          token_type: "ERC-1155",
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
            token_ids: [id],
            token_type: "ERC-1155"
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

    test "check that pagination works for 404 tokens", %{conn: conn} do
      token = insert(:token, type: "ERC-404")

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
        token_type: "ERC-404",
        amounts: [1]
      )

      transfers_0 =
        insert_list(26, :token_transfer,
          token_contract_address: token.contract_address,
          transaction: transaction,
          token_ids: [id, id + 1],
          token_type: "ERC-404",
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
            token_ids: [id],
            token_type: "ERC-404"
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
          transaction = insert(:transaction, input: "0xabcd010203040506") |> with_block()

          insert(:token_transfer,
            transaction: transaction,
            block: transaction.block,
            block_number: transaction.block_number,
            token_contract_address: token.contract_address,
            token_ids: [id],
            token_type: "ERC-721"
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

      transaction = insert(:transaction, input: "0xabcd010203040506") |> with_block()

      tt =
        insert(:token_transfer,
          transaction: transaction,
          block: transaction.block,
          block_number: transaction.block_number,
          token_contract_address: token.contract_address,
          token_ids: Enum.map(0..50, fn _x -> id end),
          token_type: "ERC-1155",
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

      transaction = insert(:transaction, input: "0xabcd010203040506") |> with_block()

      tt =
        for _ <- 0..50 do
          insert(:token_transfer,
            transaction: transaction,
            block: transaction.block,
            block_number: transaction.block_number,
            token_contract_address: token.contract_address,
            token_ids: Enum.map(0..50, fn x -> x end) ++ [id],
            token_type: "ERC-1155",
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

      check_holders_paginated_response(response, response_2nd_page, token_balances)
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
        token_ids: [0],
        token_type: "ERC-721"
      )

      request = get(conn, "/api/v2/tokens/#{token.contract_address.hash}/instances/0/transfers-count")

      assert %{"transfers_count" => ^count} = json_response(request, 200)
    end
  end

  describe "/tokens/{address_hash}/instances/{token_id}/refetch-metadata" do
    setup :set_mox_from_context

    setup :verify_on_exit!

    setup %{json_rpc_named_arguments: json_rpc_named_arguments} do
      original_config = :persistent_term.get(:rate_limit_config)
      old_recaptcha_env = Application.get_env(:block_scout_web, :recaptcha)
      original_api_rate_limit = Application.get_env(:block_scout_web, :api_rate_limit)

      v2_secret_key = "v2_secret_key"
      v3_secret_key = "v3_secret_key"

      Application.put_env(:block_scout_web, :recaptcha,
        v2_secret_key: v2_secret_key,
        v3_secret_key: v3_secret_key,
        is_disabled: false
      )

      mocked_json_rpc_named_arguments = Keyword.put(json_rpc_named_arguments, :transport, EthereumJSONRPC.Mox)

      start_supervised!({Task.Supervisor, name: Indexer.TaskSupervisor})

      start_supervised!(
        {TokenInstanceMetadataRefetchOnDemand,
         [mocked_json_rpc_named_arguments, [name: TokenInstanceMetadataRefetchOnDemand]]}
      )

      %{json_rpc_named_arguments: mocked_json_rpc_named_arguments}

      Subscriber.to(:fetched_token_instance_metadata, :on_demand)
      Subscriber.to(:not_fetched_token_instance_metadata, :on_demand)

      Application.put_env(:block_scout_web, :api_rate_limit, Keyword.put(original_api_rate_limit, :disabled, false))

      config = %{
        static_match: %{},
        wildcard_match: %{},
        parametrized_match: %{
          ["api", "v2", "tokens", ":param", "instances", ":param", "refetch-metadata"] => %{
            ip: %{period: 3_600_000, limit: 1},
            recaptcha_to_bypass_429: true,
            bypass_token_scope: "token_instance_refetch_metadata",
            bucket_key_prefix: "api/v2/tokens/:param/instances/:param/refetch-metadata_",
            isolate_rate_limit?: true
          }
        }
      }

      :persistent_term.put(:rate_limit_config, config)

      on_exit(fn ->
        :persistent_term.put(:rate_limit_config, original_config)
        Application.put_env(:block_scout_web, :recaptcha, old_recaptcha_env)
        Application.put_env(:block_scout_web, :api_rate_limit, original_api_rate_limit)
        :ets.delete_all_objects(BlockScoutWeb.RateLimit.Hammer.ETS)
      end)

      {:ok, %{v2_secret_key: v2_secret_key, v3_secret_key: v3_secret_key}}
    end

    test "token instance metadata on-demand re-fetcher is called; recaptcha is required after rate limit is exceeded",
         %{conn: conn, v2_secret_key: v2_secret_key} do
      token = insert(:token, type: "ERC-721")
      token_id = 1

      insert(:token_instance,
        token_id: token_id,
        token_contract_address_hash: token.contract_address_hash,
        metadata: %{}
      )

      metadata = %{"name" => "Super Token"}
      url = "http://metadata.endpoint.com"
      token_contract_address_hash_string = to_string(token.contract_address_hash)

      TestHelper.fetch_token_uri_mock(url, token_contract_address_hash_string)

      Tesla.Test.expect_tesla_call(
        times: 1,
        returns: fn %{url: ^url}, _opts ->
          {:ok,
           %Tesla.Env{
             status: 200,
             body: Jason.encode!(metadata)
           }}
        end
      )

      topic = "token_instances:#{token_contract_address_hash_string}"

      {:ok, _reply, _socket} =
        BlockScoutWeb.V2.UserSocket
        |> socket("no_id", %{})
        |> subscribe_and_join(topic)

      request =
        patch(conn, "/api/v2/tokens/#{token.contract_address.hash}/instances/#{token_id}/refetch-metadata", %{})

      assert %{"message" => "OK"} = json_response(request, 200)

      :timer.sleep(100)

      assert_receive(
        {:chain_event, :fetched_token_instance_metadata, :on_demand,
         [^token_contract_address_hash_string, ^token_id, ^metadata]}
      )

      assert_receive %Phoenix.Socket.Message{
                       payload: %{token_id: ^token_id, fetched_metadata: ^metadata},
                       event: "fetched_token_instance_metadata",
                       topic: ^topic
                     },
                     :timer.seconds(1)

      token_instance_from_db =
        Repo.get_by(Instance, token_id: token_id, token_contract_address_hash: token.contract_address_hash)

      assert(token_instance_from_db)
      assert token_instance_from_db.metadata == metadata

      expected_body = "secret=#{v2_secret_key}&response=123"

      Tesla.Test.expect_tesla_call(
        times: 1,
        returns: fn %{body: ^expected_body}, _opts ->
          {:ok,
           %Tesla.Env{
             status: 200,
             body:
               Jason.encode!(%{
                 "success" => true,
                 "hostname" => Application.get_env(:block_scout_web, BlockScoutWeb.Endpoint)[:url][:host]
               })
           }}
        end
      )

      TestHelper.fetch_token_uri_mock(url, token_contract_address_hash_string)

      Tesla.Test.expect_tesla_call(
        times: 1,
        returns: fn %{url: ^url}, _opts ->
          {:ok,
           %Tesla.Env{
             status: 200,
             body: Jason.encode!(metadata)
           }}
        end
      )

      request =
        Phoenix.ConnTest.build_conn()
        |> put_req_header("user-agent", "test-agent")
        |> patch("/api/v2/tokens/#{token.contract_address.hash}/instances/#{token_id}/refetch-metadata", %{})

      assert json_response(request, 429)

      request =
        Phoenix.ConnTest.build_conn()
        |> put_req_header("user-agent", "test-agent")
        |> put_req_header("recaptcha-v2-response", "123")
        |> patch("/api/v2/tokens/#{token.contract_address.hash}/instances/#{token_id}/refetch-metadata", %{})

      assert %{"message" => "OK"} = json_response(request, 200)

      :timer.sleep(100)

      assert_receive(
        {:chain_event, :fetched_token_instance_metadata, :on_demand,
         [^token_contract_address_hash_string, ^token_id, ^metadata]}
      )

      assert_receive %Phoenix.Socket.Message{
                       payload: %{token_id: ^token_id, fetched_metadata: ^metadata},
                       event: "fetched_token_instance_metadata",
                       topic: ^topic
                     },
                     :timer.seconds(1)

      token_instance_from_db =
        Repo.get_by(Instance, token_id: token_id, token_contract_address_hash: token.contract_address_hash)

      assert(token_instance_from_db)
      assert token_instance_from_db.metadata == metadata
    end

    test "don't fetch token instance metadata for non-existent token instance", %{
      conn: conn,
      v2_secret_key: v2_secret_key
    } do
      token = insert(:token, type: "ERC-721")
      token_id = 0

      insert(:token_instance, token_id: token_id, token_contract_address_hash: token.contract_address_hash)

      request =
        patch(conn, "/api/v2/tokens/#{token.contract_address.hash}/instances/1/refetch-metadata", %{})

      assert %{"message" => "Not found"} = json_response(request, 404)
    end

    test "fetch token instance metadata for existing token instance with no metadata", %{
      conn: conn
    } do
      token = insert(:token, type: "ERC-721")
      token_id = 1

      insert(:token_instance,
        token_id: token_id,
        token_contract_address_hash: token.contract_address_hash,
        metadata: nil
      )

      metadata = %{"name" => "Super Token"}
      url = "http://metadata.endpoint.com"
      token_contract_address_hash_string = to_string(token.contract_address_hash)

      TestHelper.fetch_token_uri_mock(url, token_contract_address_hash_string)

      Tesla.Test.expect_tesla_call(
        times: 1,
        returns: fn %{url: ^url}, _opts ->
          {:ok,
           %Tesla.Env{
             status: 200,
             body: Jason.encode!(metadata)
           }}
        end
      )

      topic = "token_instances:#{token_contract_address_hash_string}"

      {:ok, _reply, _socket} =
        BlockScoutWeb.V2.UserSocket
        |> socket("no_id", %{})
        |> subscribe_and_join(topic)

      request =
        patch(conn, "/api/v2/tokens/#{token.contract_address.hash}/instances/#{token_id}/refetch-metadata", %{})

      assert %{"message" => "OK"} = json_response(request, 200)

      :timer.sleep(100)

      assert_receive(
        {:chain_event, :fetched_token_instance_metadata, :on_demand,
         [^token_contract_address_hash_string, ^token_id, ^metadata]}
      )

      assert_receive %Phoenix.Socket.Message{
                       payload: %{token_id: ^token_id, fetched_metadata: ^metadata},
                       event: "fetched_token_instance_metadata",
                       topic: ^topic
                     },
                     :timer.seconds(1)

      token_instance_from_db =
        Repo.get_by(Instance, token_id: token_id, token_contract_address_hash: token.contract_address_hash)

      assert(token_instance_from_db)
      assert token_instance_from_db.metadata == metadata
    end

    test "emit not_fetched_token_instance_metadata event when fetching token instance metadata fails", %{
      conn: conn
    } do
      token = insert(:token, type: "ERC-721")
      token_id = 1

      insert(:token_instance,
        token_id: token_id,
        token_contract_address_hash: token.contract_address_hash,
        metadata: nil
      )

      url = "http://metadata.endpoint.com"
      token_contract_address_hash_string = to_string(token.contract_address_hash)

      TestHelper.fetch_token_uri_mock(url, token_contract_address_hash_string)

      Tesla.Test.expect_tesla_call(
        times: 1,
        returns: fn %{url: ^url}, _opts ->
          {:ok,
           %Tesla.Env{
             status: 500,
             body: "Error"
           }}
        end
      )

      topic = "token_instances:#{token_contract_address_hash_string}"

      {:ok, _reply, _socket} =
        BlockScoutWeb.V2.UserSocket
        |> socket("no_id", %{})
        |> subscribe_and_join(topic)

      request =
        patch(conn, "/api/v2/tokens/#{token.contract_address.hash}/instances/#{token_id}/refetch-metadata", %{
          "recaptcha_response" => "123"
        })

      assert %{"message" => "OK"} = json_response(request, 200)

      :timer.sleep(100)

      assert_receive(
        {:chain_event, :not_fetched_token_instance_metadata, :on_demand,
         [^token_contract_address_hash_string, ^token_id, "error"]}
      )

      assert_receive %Phoenix.Socket.Message{
                       payload: %{token_id: ^token_id, reason: "error"},
                       event: "not_fetched_token_instance_metadata",
                       topic: ^topic
                     },
                     :timer.seconds(1)

      token_instance_from_db =
        Repo.get_by(Instance, token_id: token_id, token_contract_address_hash: token.contract_address_hash)

      assert(token_instance_from_db)
      assert is_nil(token_instance_from_db.metadata)
    end

    test "fetch token instance metadata using scoped bypass api key", %{conn: conn} do
      # Configure scoped bypass api key for this test
      old_recaptcha_env = Application.get_env(:block_scout_web, :recaptcha)
      scoped_bypass_token = "test_scoped_token_123"

      Application.put_env(
        :block_scout_web,
        :recaptcha,
        Keyword.merge(old_recaptcha_env,
          scoped_bypass_tokens: [
            token_instance_refetch_metadata: scoped_bypass_token
          ]
        )
      )

      on_exit(fn ->
        Application.put_env(:block_scout_web, :recaptcha, old_recaptcha_env)
      end)

      token = insert(:token, type: "ERC-721")
      token_id = 1

      insert(:token_instance,
        token_id: token_id,
        token_contract_address_hash: token.contract_address_hash,
        metadata: %{}
      )

      metadata = %{"name" => "Super Token"}
      url = "http://metadata.endpoint.com"
      token_contract_address_hash_string = to_string(token.contract_address_hash)

      TestHelper.fetch_token_uri_mock(url, token_contract_address_hash_string)

      Tesla.Test.expect_tesla_call(
        times: 1,
        returns: fn %{url: ^url}, _opts ->
          {:ok,
           %Tesla.Env{
             status: 200,
             body: Jason.encode!(metadata)
           }}
        end
      )

      topic = "token_instances:#{token_contract_address_hash_string}"

      {:ok, _reply, _socket} =
        BlockScoutWeb.V2.UserSocket
        |> socket("no_id", %{})
        |> subscribe_and_join(topic)

      request =
        patch(conn, "/api/v2/tokens/#{token.contract_address.hash}/instances/#{token_id}/refetch-metadata", %{})

      assert %{"message" => "OK"} = json_response(request, 200)

      :timer.sleep(100)

      assert_receive(
        {:chain_event, :fetched_token_instance_metadata, :on_demand,
         [^token_contract_address_hash_string, ^token_id, ^metadata]}
      )

      assert_receive %Phoenix.Socket.Message{
                       payload: %{token_id: ^token_id, fetched_metadata: ^metadata},
                       event: "fetched_token_instance_metadata",
                       topic: ^topic
                     },
                     :timer.seconds(1)

      token_instance_from_db =
        Repo.get_by(Instance, token_id: token_id, token_contract_address_hash: token.contract_address_hash)

      assert(token_instance_from_db)
      assert token_instance_from_db.metadata == metadata

      request =
        Phoenix.ConnTest.build_conn()
        |> put_req_header("user-agent", "test-agent")
        |> patch("/api/v2/tokens/#{token.contract_address.hash}/instances/#{token_id}/refetch-metadata", %{})

      assert json_response(request, 429)

      TestHelper.fetch_token_uri_mock(url, token_contract_address_hash_string)

      Tesla.Test.expect_tesla_call(
        times: 1,
        returns: fn %{url: ^url}, _opts ->
          {:ok,
           %Tesla.Env{
             status: 200,
             body: Jason.encode!(metadata)
           }}
        end
      )

      request =
        Phoenix.ConnTest.build_conn()
        |> put_req_header("user-agent", "test-agent")
        |> put_req_header("scoped-recaptcha-bypass-token", scoped_bypass_token)
        |> patch("/api/v2/tokens/#{token.contract_address.hash}/instances/#{token_id}/refetch-metadata", %{})

      assert %{"message" => "OK"} = json_response(request, 200)

      :timer.sleep(100)

      assert_receive(
        {:chain_event, :fetched_token_instance_metadata, :on_demand,
         [^token_contract_address_hash_string, ^token_id, ^metadata]}
      )

      assert_receive %Phoenix.Socket.Message{
                       payload: %{token_id: ^token_id, fetched_metadata: ^metadata},
                       event: "fetched_token_instance_metadata",
                       topic: ^topic
                     },
                     :timer.seconds(1)

      token_instance_from_db =
        Repo.get_by(Instance, token_id: token_id, token_contract_address_hash: token.contract_address_hash)

      assert(token_instance_from_db)
      assert token_instance_from_db.metadata == metadata
    end

    test "falls back to normal reCAPTCHA when incorrect scoped bypass api key is supplied", %{
      conn: conn,
      v2_secret_key: v2_secret_key
    } do
      # Configure scoped bypass api key for this test
      old_recaptcha_env = Application.get_env(:block_scout_web, :recaptcha)
      scoped_bypass_token = "test_scoped_token_123"

      Application.put_env(
        :block_scout_web,
        :recaptcha,
        Keyword.merge(old_recaptcha_env,
          scoped_bypass_tokens: [
            token_instance_refetch_metadata: scoped_bypass_token
          ]
        )
      )

      on_exit(fn ->
        Application.put_env(:block_scout_web, :recaptcha, old_recaptcha_env)
      end)

      token = insert(:token, type: "ERC-721")
      token_id = 1

      insert(:token_instance,
        token_id: token_id,
        token_contract_address_hash: token.contract_address_hash,
        metadata: %{}
      )

      metadata = %{"name" => "Super Token"}
      url = "http://metadata.endpoint.com"
      token_contract_address_hash_string = to_string(token.contract_address_hash)

      TestHelper.fetch_token_uri_mock(url, token_contract_address_hash_string)

      request =
        patch(conn, "/api/v2/tokens/#{token.contract_address.hash}/instances/#{token_id}/refetch-metadata", %{})

      assert %{"message" => "OK"} = json_response(request, 200)

      # First request after hitting rate limit with wrong scoped token - should fail
      request =
        Phoenix.ConnTest.build_conn()
        |> put_req_header("user-agent", "test-agent")
        |> put_req_header("scoped-recaptcha-bypass-token", "wrong_scoped_token")
        |> patch("/api/v2/tokens/#{token.contract_address.hash}/instances/#{token_id}/refetch-metadata", %{})

      assert %{"message" => "Too Many Requests"} = json_response(request, 429)

      # Set up normal reCAPTCHA validation for the second request
      expected_body = "secret=#{v2_secret_key}&response=correct_recaptcha_token"

      Tesla.Test.expect_tesla_call(
        times: 1,
        returns: fn %{body: ^expected_body}, _opts ->
          {:ok,
           %Tesla.Env{
             status: 200,
             body:
               Jason.encode!(%{
                 "success" => true,
                 "hostname" => Application.get_env(:block_scout_web, BlockScoutWeb.Endpoint)[:url][:host]
               })
           }}
        end
      )

      Tesla.Test.expect_tesla_call(
        times: 1,
        returns: fn %{url: ^url}, _opts ->
          {:ok,
           %Tesla.Env{
             status: 200,
             body: Jason.encode!(%{"name" => "test"})
           }}
        end
      )

      TestHelper.fetch_token_uri_mock(url, token_contract_address_hash_string)

      Tesla.Test.expect_tesla_call(
        times: 1,
        returns: fn %{url: ^url}, _opts ->
          {:ok,
           %Tesla.Env{
             status: 200,
             body: Jason.encode!(metadata)
           }}
        end
      )

      topic = "token_instances:#{token_contract_address_hash_string}"

      {:ok, _reply, _socket} =
        BlockScoutWeb.V2.UserSocket
        |> socket("no_id", %{})
        |> subscribe_and_join(topic)

      # Second request with correct reCAPTCHA token - should work
      request =
        Phoenix.ConnTest.build_conn()
        |> put_req_header("user-agent", "test-agent")
        |> put_req_header("recaptcha-v2-response", "correct_recaptcha_token")
        |> patch("/api/v2/tokens/#{token.contract_address.hash}/instances/#{token_id}/refetch-metadata", %{})

      assert %{"message" => "OK"} = json_response(request, 200)

      :timer.sleep(100)

      assert_receive(
        {:chain_event, :fetched_token_instance_metadata, :on_demand,
         [^token_contract_address_hash_string, ^token_id, ^metadata]}
      )

      token_instance_from_db =
        Repo.get_by(Instance, token_id: token_id, token_contract_address_hash: token.contract_address_hash)

      assert(token_instance_from_db)
      assert token_instance_from_db.metadata == metadata
    end

    test "rejects scoped bypass api key when scoped tokens are not configured", %{
      conn: conn,
      v2_secret_key: v2_secret_key
    } do
      # Make sure we don't have scoped tokens configured
      old_recaptcha_env = Application.get_env(:block_scout_web, :recaptcha)

      # Ensure there are no scoped_bypass_tokens in the configuration
      Application.put_env(
        :block_scout_web,
        :recaptcha,
        Keyword.merge(old_recaptcha_env,
          scoped_bypass_tokens: [
            token_instance_refetch_metadata: nil
          ]
        )
      )

      on_exit(fn ->
        Application.put_env(:block_scout_web, :recaptcha, old_recaptcha_env)
      end)

      token = insert(:token, type: "ERC-721")
      token_id = 1

      insert(:token_instance,
        token_id: token_id,
        token_contract_address_hash: token.contract_address_hash,
        metadata: %{}
      )

      metadata = %{"name" => "Super Token"}
      url = "http://metadata.endpoint.com"
      token_contract_address_hash_string = to_string(token.contract_address_hash)
      TestHelper.fetch_token_uri_mock(url, token_contract_address_hash_string)

      request =
        patch(conn, "/api/v2/tokens/#{token.contract_address.hash}/instances/#{token_id}/refetch-metadata", %{})

      assert %{"message" => "OK"} = json_response(request, 200)

      # First request after hitting rate limit with a scoped token that isn't configured - should fail
      request =
        Phoenix.ConnTest.build_conn()
        |> put_req_header("user-agent", "test-agent")
        |> put_req_header("scoped-recaptcha-bypass-token", "some_token_that_does_not_exist")
        |> patch("/api/v2/tokens/#{token.contract_address.hash}/instances/#{token_id}/refetch-metadata", %{})

      assert %{"message" => "Too Many Requests"} = json_response(request, 429)

      request =
        Phoenix.ConnTest.build_conn()
        |> put_req_header("user-agent", "test-agent")
        |> put_req_header("scoped-recaptcha-bypass-token", "some_token_that_does_not_exist")
        |> patch("/api/v2/tokens/#{token.contract_address.hash}/instances/#{token_id}/refetch-metadata", %{})

      assert %{"message" => "Too Many Requests"} = json_response(request, 429)

      request =
        Phoenix.ConnTest.build_conn()
        |> put_req_header("user-agent", "test-agent")
        |> put_req_header("scoped-recaptcha-bypass-token", "")
        |> patch("/api/v2/tokens/#{token.contract_address.hash}/instances/#{token_id}/refetch-metadata", %{})

      assert %{"message" => "Too Many Requests"} = json_response(request, 429)

      # Set up normal reCAPTCHA validation for the second request
      expected_body = "secret=#{v2_secret_key}&response=correct_recaptcha_token"

      Tesla.Test.expect_tesla_call(
        times: 1,
        returns: fn %{body: ^expected_body}, _opts ->
          {:ok,
           %Tesla.Env{
             status: 200,
             body:
               Jason.encode!(%{
                 "success" => true,
                 "hostname" => Application.get_env(:block_scout_web, BlockScoutWeb.Endpoint)[:url][:host]
               })
           }}
        end
      )

      Tesla.Test.expect_tesla_call(
        times: 1,
        returns: fn %{url: ^url}, _opts ->
          {:ok,
           %Tesla.Env{
             status: 200,
             body: Jason.encode!(%{"name" => "test"})
           }}
        end
      )

      TestHelper.fetch_token_uri_mock(url, token_contract_address_hash_string)

      Tesla.Test.expect_tesla_call(
        times: 1,
        returns: fn %{url: ^url}, _opts ->
          {:ok,
           %Tesla.Env{
             status: 200,
             body: Jason.encode!(metadata)
           }}
        end
      )

      # Second request with correct reCAPTCHA token - should work
      request =
        Phoenix.ConnTest.build_conn()
        |> put_req_header("user-agent", "test-agent")
        |> put_req_header("recaptcha-v2-response", "correct_recaptcha_token")
        |> patch("/api/v2/tokens/#{token.contract_address.hash}/instances/#{token_id}/refetch-metadata", %{})

      assert %{"message" => "OK"} = json_response(request, 200)

      :timer.sleep(100)

      token_instance_from_db =
        Repo.get_by(Instance, token_id: token_id, token_contract_address_hash: token.contract_address.hash)

      assert(token_instance_from_db)
      assert token_instance_from_db.metadata == metadata
    end
  end

  describe "/tokens/{address_hash}/instances/refetch-metadata" do
    setup :set_mox_from_context

    setup :verify_on_exit!

    setup %{json_rpc_named_arguments: json_rpc_named_arguments} do
      Application.put_env(:block_scout_web, :sensitive_endpoints_api_key, "abc")
      mocked_json_rpc_named_arguments = Keyword.put(json_rpc_named_arguments, :transport, EthereumJSONRPC.Mox)

      start_supervised!({Task.Supervisor, name: Indexer.TaskSupervisor})

      start_supervised!(
        {NFTCollectionMetadataRefetchOnDemand,
         [mocked_json_rpc_named_arguments, [name: NFTCollectionMetadataRefetchOnDemand]]}
      )

      %{json_rpc_named_arguments: mocked_json_rpc_named_arguments}

      on_exit(fn ->
        Application.put_env(:block_scout_web, :sensitive_endpoints_api_key, nil)
      end)

      :ok
    end

    test "token instance metadata on-demand re-fetcher is called", %{conn: conn} do
      token = insert(:token, type: "ERC-721")

      for id <- 1..5 do
        insert(:token_instance,
          token_id: id,
          token_contract_address_hash: token.contract_address_hash,
          metadata: %{}
        )
      end

      request =
        patch(
          conn,
          "/api/v2/tokens/#{token.contract_address.hash}/instances/refetch-metadata",
          %{
            "api_key" => "abc"
          }
        )

      assert %{"message" => "OK"} = json_response(request, 200)

      :timer.sleep(100)

      token_instances_from_db = Repo.all(Instance, token_contract_address_hash: token.contract_address_hash)

      assert(token_instances_from_db)

      for token_instance_from_db <- token_instances_from_db do
        assert token_instance_from_db.metadata == nil
        assert token_instance_from_db.error == ":marked_to_refetch"
      end
    end

    test "don't trigger metadata re-fetch, if no admin api key is provided", %{conn: conn} do
      token = insert(:token, type: "ERC-721")

      request =
        patch(conn, "/api/v2/tokens/#{token.contract_address.hash}/instances/refetch-metadata")

      assert %{"message" => "Wrong API key"} = json_response(request, 401)
    end
  end

  defp compare_holders_item(%CurrentTokenBalance{} = ctb, json) do
    assert Address.checksum(ctb.address_hash) == json["address"]["hash"]
    assert (ctb.token_id && to_string(ctb.token_id)) == json["token_id"]
    assert to_string(ctb.value) == json["value"]
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
    assert to_string(token_transfer.transaction_hash) == json["transaction_hash"]
    assert json["timestamp"] != nil
    assert json["method"] != nil
    assert to_string(token_transfer.block_hash) == json["block_hash"]
    assert token_transfer.log_index == json["log_index"]
    assert check_total(Repo.preload(token_transfer, [{:token, :contract_address}]).token, json["total"], token_transfer)
  end

  def compare_item(%CurrentTokenBalance{} = ctb, json) do
    compare_holders_item(ctb, json)
    compare_item(Repo.preload(ctb, [{:token, :contract_address}]).token, json["token"])
  end

  def compare_item(%Instance{token: %Token{} = token} = instance, json) do
    token_type = token.type
    value = to_string(value(token.type, instance))
    id = to_string(instance.token_id)
    metadata = instance.metadata
    token_address_hash = Address.checksum(token.contract_address_hash)
    app_url = instance.metadata["external_url"]
    animation_url = instance.metadata["animation_url"]
    image_url = instance.metadata["image_url"]
    token_name = token.name
    owner_address_hash = Address.checksum(instance.owner.hash)
    is_contract = !is_nil(instance.owner.contract_code)
    is_unique = value == "1"

    assert %{
             "token_type" => ^token_type,
             "value" => ^value,
             "id" => ^id,
             "metadata" => ^metadata,
             "token" => %{"address" => ^token_address_hash, "name" => ^token_name, "type" => ^token_type},
             "external_app_url" => ^app_url,
             "animation_url" => ^animation_url,
             "image_url" => ^image_url,
             "is_unique" => ^is_unique
           } = json

    if is_unique do
      assert owner_address_hash == json["owner"]["hash"]
      assert is_contract == json["owner"]["is_contract"]
    else
      assert json["owner"] == nil
    end
  end

  def compare_item(%Instance{} = instance, json) do
    assert to_string(instance.token_id) == json["id"]
    assert Jason.decode!(Jason.encode!(instance.metadata)) == json["metadata"]
    assert json["is_unique"]
    compare_item(Repo.preload(instance, [{:token, :contract_address}]).token, json["token"])
  end

  defp value("ERC-721", _), do: 1
  defp value(_, nft), do: nft.current_token_balance.value

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

  defp check_holders_paginated_response(first_page_resp, second_page_resp, list) do
    assert Enum.count(first_page_resp["items"]) == 50
    assert first_page_resp["next_page_params"] != nil
    compare_holders_item(Enum.at(list, 50), Enum.at(first_page_resp["items"], 0))
    compare_holders_item(Enum.at(list, 1), Enum.at(first_page_resp["items"], 49))

    assert Enum.count(second_page_resp["items"]) == 1
    assert second_page_resp["next_page_params"] == nil
    compare_holders_item(Enum.at(list, 0), Enum.at(second_page_resp["items"], 0))
  end
end
