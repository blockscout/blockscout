defmodule BlockScoutWeb.API.V2.TokenControllerTest do
  use BlockScoutWeb.ConnCase

  alias Explorer.{Chain, Repo}

  alias Explorer.Chain.{Address, Token, TokenTransfer}

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

      second_page_token_balances =
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

      assert %{"items" => [], "next_page_params" => nil} = json_response(request, 200)
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

      token_tranfers =
        for _ <- 0..50 do
          tx = insert(:transaction) |> with_block()

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

      check_paginated_response(response, response_2nd_page, token_tranfers)
    end
  end

  describe "/tokens/{address_hash}/holders" do
    test "get 200 on non existing address", %{conn: conn} do
      token = build(:token)

      request = get(conn, "/api/v2/tokens/#{token.contract_address.hash}/holders")

      assert %{"items" => [], "next_page_params" => nil} = json_response(request, 200)
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
    test "get empty list", %{conn: conn} do
      request = get(conn, "/api/v2/tokens")

      assert %{"items" => [], "next_page_params" => nil} = json_response(request, 200)
    end

    test "check pagination", %{conn: conn} do
      tokens =
        for i <- 0..50 do
          insert(:token, holder_count: i)
        end

      request = get(conn, "/api/v2/tokens")
      assert response = json_response(request, 200)

      request_2nd_page = get(conn, "/api/v2/tokens", response["next_page_params"])

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, tokens)
    end

    test "check nil", %{conn: conn} do
      token = insert(:token)

      request = get(conn, "/api/v2/tokens")

      assert %{"items" => [token_json], "next_page_params" => nil} = json_response(request, 200)

      compare_item(token, token_json)
    end
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
  end

  def compare_item(%CurrentTokenBalance{} = ctb, json) do
    assert Address.checksum(ctb.address_hash) == json["address"]["hash"]
    assert ctb.token_id == json["token_id"]
    assert to_string(ctb.value) == json["value"]
    compare_item(Repo.preload(ctb, [{:token, :contract_address}]).token, json["token"])
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
end
