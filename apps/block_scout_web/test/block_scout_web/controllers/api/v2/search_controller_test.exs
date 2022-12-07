defmodule BlockScoutWeb.API.V2.SearchControllerTest do
  use BlockScoutWeb.ConnCase

  alias Explorer.Chain.Address

  setup do
    insert(:block)
    insert(:unique_smart_contract)
    insert(:unique_token)
    insert(:transaction)
    address = insert(:address)
    insert(:unique_address_name, address: address)

    :ok
  end

  describe "/search" do
    test "search block", %{conn: conn} do
      block = insert(:block)

      request = get(conn, "/api/v2/search?q=#{block.hash}")
      assert response = json_response(request, 200)

      assert Enum.count(response["items"]) == 1
      assert response["next_page_params"] == nil

      item = Enum.at(response["items"], 0)

      assert item["type"] == "block"
      assert item["block_number"] == block.number
      assert item["block_hash"] == to_string(block.hash)
      assert item["url"] =~ to_string(block.hash)

      request = get(conn, "/api/v2/search?q=#{block.number}")
      assert response = json_response(request, 200)

      assert Enum.count(response["items"]) == 1
      assert response["next_page_params"] == nil

      item = Enum.at(response["items"], 0)

      assert item["type"] == "block"
      assert item["block_number"] == block.number
      assert item["block_hash"] == to_string(block.hash)
      assert item["url"] =~ to_string(block.hash)
    end

    test "search address", %{conn: conn} do
      address = insert(:address)
      name = insert(:unique_address_name, address: address)

      request = get(conn, "/api/v2/search?q=#{address.hash}")
      assert response = json_response(request, 200)

      assert Enum.count(response["items"]) == 1
      assert response["next_page_params"] == nil

      item = Enum.at(response["items"], 0)

      assert item["type"] == "address"
      assert item["name"] == name.name
      assert item["address"] == Address.checksum(address.hash)
      assert item["url"] =~ Address.checksum(address.hash)
    end

    test "search contract", %{conn: conn} do
      contract = insert(:unique_smart_contract)

      request = get(conn, "/api/v2/search?q=#{contract.name}")
      assert response = json_response(request, 200)

      assert Enum.count(response["items"]) == 1
      assert response["next_page_params"] == nil

      item = Enum.at(response["items"], 0)

      assert item["type"] == "contract"
      assert item["name"] == contract.name
      assert item["address"] == Address.checksum(contract.address_hash)
      assert item["url"] =~ Address.checksum(contract.address_hash)
    end

    test "check pagination", %{conn: conn} do
      name = "contract"
      contracts = insert_list(51, :smart_contract, name: name)

      request = get(conn, "/api/v2/search?q=#{name}")
      assert response = json_response(request, 200)

      assert Enum.count(response["items"]) == 50
      assert response["next_page_params"] != nil

      item = Enum.at(response["items"], 0)

      assert item["type"] == "contract"
      assert item["name"] == name

      request_2 = get(conn, "/api/v2/search", response["next_page_params"])
      assert response_2 = json_response(request_2, 200)

      assert Enum.count(response_2["items"]) == 1
      assert response_2["next_page_params"] == nil

      item = Enum.at(response_2["items"], 0)

      assert item["type"] == "contract"
      assert item["name"] == name

      assert item not in response["items"]
    end

    test "search token", %{conn: conn} do
      token = insert(:unique_token)

      request = get(conn, "/api/v2/search?q=#{token.name}")
      assert response = json_response(request, 200)

      assert Enum.count(response["items"]) == 1
      assert response["next_page_params"] == nil

      item = Enum.at(response["items"], 0)

      assert item["type"] == "token"
      assert item["name"] == token.name
      assert item["symbol"] == token.symbol
      assert item["address"] == Address.checksum(token.contract_address_hash)
      assert item["token_url"] =~ Address.checksum(token.contract_address_hash)
      assert item["address_url"] =~ Address.checksum(token.contract_address_hash)
    end

    test "search transaction", %{conn: conn} do
      tx = insert(:transaction)

      request = get(conn, "/api/v2/search?q=#{tx.hash}")
      assert response = json_response(request, 200)

      assert Enum.count(response["items"]) == 1
      assert response["next_page_params"] == nil

      item = Enum.at(response["items"], 0)

      assert item["type"] == "transaction"
      assert item["tx_hash"] == to_string(tx.hash)
      assert item["url"] =~ to_string(tx.hash)
    end
  end
end
