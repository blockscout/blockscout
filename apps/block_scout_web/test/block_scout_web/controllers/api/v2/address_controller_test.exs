defmodule BlockScoutWeb.API.V2.AddressControllerTest do
  use BlockScoutWeb.ConnCase

  alias Explorer.Chain
  alias Explorer.Chain.{Address, Transaction}

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

      correct_reponse = %{
        "hash" => Address.checksum(address.hash),
        "implementation_name" => nil,
        "is_contract" => false,
        "is_verified" => false,
        "name" => nil,
        "private_tags" => [],
        "public_tags" => [],
        "watchlist_names" => []
      }

      request = get(conn, "/api/v2/addresses/#{Address.checksum(address.hash)}")
      assert ^correct_reponse = json_response(request, 200)

      request = get(conn, "/api/v2/addresses/#{String.downcase(to_string(address.hash))}")
      assert ^correct_reponse = json_response(request, 200)
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
               "transaction_count" => "0",
               "token_transfer_count" => "0",
               "gas_usage_count" => "0",
               "validation_count" => "0"
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
               "transaction_count" => "2",
               "token_transfer_count" => "2",
               "gas_usage_count" => ^gas_used,
               "validation_count" => "1"
             } = json_response(request, 200)
    end
  end

  describe "/addresses/{address_hash}/transactions" do
    test "get empty list on non existing address", %{conn: conn} do
      address = build(:address)

      request = get(conn, "/api/v2/addresses/#{address.hash}/transactions")

      assert response = json_response(request, 200)
      assert response["items"] == []
      assert response["next_page_params"] == nil
    end

    test "get 422 on invalid address", %{conn: conn} do
      request = get(conn, "/api/v2/addresses/0x/counters")

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
  end

  defp compare_item(%Transaction{} = transaction, json) do
    assert to_string(transaction.hash) == json["hash"]
    assert transaction.block_number == json["block"]
    assert to_string(transaction.value.value) == json["value"]
    assert Address.checksum(transaction.from_address_hash) == json["from"]["hash"]
    assert Address.checksum(transaction.to_address_hash) == json["to"]["hash"]
  end
end
