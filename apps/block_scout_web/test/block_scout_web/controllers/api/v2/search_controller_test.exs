defmodule BlockScoutWeb.API.V2.SearchControllerTest do
  use BlockScoutWeb.ConnCase

  alias Explorer.Chain.{Address, Block}
  alias Explorer.Tags.AddressTag
  alias Plug.Conn.Query

  describe "/search" do
    test "search block", %{conn: conn} do
      block = insert(:block)

      request = get(conn, "/api/v2/search?q=#{block.hash}")
      assert response = json_response(request, 200)

      assert Enum.count(response["items"]) == 1
      assert response["next_page_params"] == nil

      item = Enum.at(response["items"], 0)

      assert item["type"] == "block"
      assert item["block_type"] == "block"
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
      assert item["timestamp"] == block.timestamp |> to_string() |> String.replace(" ", "T")
    end

    test "search block with small and short number", %{conn: conn} do
      block = insert(:block, number: 1)

      request = get(conn, "/api/v2/search?q=#{block.number}")
      assert response = json_response(request, 200)

      assert Enum.count(response["items"]) == 1
      assert response["next_page_params"] == nil

      item = Enum.at(response["items"], 0)

      assert item["type"] == "block"
      assert item["block_number"] == block.number
      assert item["block_hash"] == to_string(block.hash)
      assert item["url"] =~ to_string(block.hash)
      assert item["timestamp"] == block.timestamp |> to_string() |> String.replace(" ", "T")
    end

    test "search reorg", %{conn: conn} do
      block = insert(:block, consensus: false)

      request = get(conn, "/api/v2/search?q=#{block.hash}")
      assert response = json_response(request, 200)

      assert Enum.count(response["items"]) == 1
      assert response["next_page_params"] == nil

      item = Enum.at(response["items"], 0)

      assert item["type"] == "block"
      assert item["block_type"] == "reorg"
      assert item["block_number"] == block.number
      assert item["block_hash"] == to_string(block.hash)
      assert item["url"] =~ to_string(block.hash)

      request = get(conn, "/api/v2/search?q=#{block.number}")
      assert response = json_response(request, 200)

      assert Enum.count(response["items"]) == 1
      assert response["next_page_params"] == nil

      item = Enum.at(response["items"], 0)

      assert item["type"] == "block"
      assert item["block_type"] == "reorg"
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
      assert item["is_smart_contract_verified"] == address.verified
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
      assert item["is_smart_contract_verified"] == true
    end

    test "check pagination", %{conn: conn} do
      name = "contract"
      _contracts = insert_list(51, :smart_contract, name: name)

      request = get(conn, "/api/v2/search?q=#{name}")
      assert response = json_response(request, 200)

      assert Enum.count(response["items"]) == 50
      assert response["next_page_params"] != nil

      item = Enum.at(response["items"], 0)

      assert item["type"] == "contract"
      assert item["name"] == name

      request_2 = get(conn, "/api/v2/search", response["next_page_params"] |> Query.encode() |> Query.decode())
      assert response_2 = json_response(request_2, 200)

      assert Enum.count(response_2["items"]) == 1
      assert response_2["next_page_params"] == nil

      item = Enum.at(response_2["items"], 0)

      assert item["type"] == "contract"
      assert item["name"] == name

      assert item not in response["items"]
    end

    test "check pagination #1", %{conn: conn} do
      name = "contract"
      contracts = for(i <- 0..50, do: insert(:smart_contract, name: "#{name} #{i}")) |> Enum.sort_by(fn x -> x.name end)

      tokens =
        for i <- 0..50, do: insert(:token, name: "#{name} #{i}", circulating_market_cap: 10000 - i, holder_count: 0)

      labels =
        for(i <- 0..50, do: insert(:address_to_tag, tag: build(:address_tag, display_name: "#{name} #{i}")))
        |> Enum.sort_by(fn x -> x.tag.display_name end)

      request = get(conn, "/api/v2/search?q=#{name}")
      assert response = json_response(request, 200)

      assert Enum.count(response["items"]) == 50
      assert response["next_page_params"] != nil
      assert Enum.at(response["items"], 0)["type"] == "label"
      assert Enum.at(response["items"], 49)["type"] == "label"

      request_2 = get(conn, "/api/v2/search", response["next_page_params"] |> Query.encode() |> Query.decode())
      assert response_2 = json_response(request_2, 200)

      assert Enum.count(response_2["items"]) == 50
      assert response_2["next_page_params"] != nil
      assert Enum.at(response_2["items"], 0)["type"] == "label"
      assert Enum.at(response_2["items"], 1)["type"] == "token"
      assert Enum.at(response_2["items"], 49)["type"] == "token"

      request_3 = get(conn, "/api/v2/search", response_2["next_page_params"] |> Query.encode() |> Query.decode())
      assert response_3 = json_response(request_3, 200)

      assert Enum.count(response_3["items"]) == 50
      assert response_3["next_page_params"] != nil
      assert Enum.at(response_3["items"], 0)["type"] == "token"
      assert Enum.at(response_3["items"], 1)["type"] == "token"
      assert Enum.at(response_3["items"], 2)["type"] == "contract"
      assert Enum.at(response_3["items"], 49)["type"] == "contract"

      request_4 = get(conn, "/api/v2/search", response_3["next_page_params"] |> Query.encode() |> Query.decode())
      assert response_4 = json_response(request_4, 200)

      assert Enum.count(response_4["items"]) == 3
      assert response_4["next_page_params"] == nil
      assert Enum.all?(response_4["items"], fn x -> x["type"] == "contract" end)

      labels_from_api = response["items"] ++ [Enum.at(response_2["items"], 0)]

      assert labels
             |> Enum.zip(labels_from_api)
             |> Enum.all?(fn {label, item} ->
               label.tag.display_name == item["name"] && item["type"] == "label" &&
                 item["address"] == Address.checksum(label.address_hash)
             end)

      tokens_from_api = Enum.slice(response_2["items"], 1, 49) ++ Enum.slice(response_3["items"], 0, 2)

      assert tokens
             |> Enum.zip(tokens_from_api)
             |> Enum.all?(fn {token, item} ->
               token.name == item["name"] && item["type"] == "token" &&
                 item["address"] == Address.checksum(token.contract_address_hash)
             end)

      contracts_from_api = Enum.slice(response_3["items"], 2, 48) ++ response_4["items"]

      assert contracts
             |> Enum.zip(contracts_from_api)
             |> Enum.all?(fn {contract, item} ->
               contract.name == item["name"] && item["type"] == "contract" &&
                 item["address"] == Address.checksum(contract.address_hash)
             end)
    end

    test "check pagination #2 (token should be ranged by fiat_value)", %{conn: conn} do
      name = "contract"
      contracts = for(i <- 0..50, do: insert(:smart_contract, name: "#{name} #{i}")) |> Enum.sort_by(fn x -> x.name end)

      tokens =
        for i <- 0..50, do: insert(:token, name: "#{name} #{i}", fiat_value: 10000 - i, holder_count: 0)

      labels =
        for(i <- 0..50, do: insert(:address_to_tag, tag: build(:address_tag, display_name: "#{name} #{i}")))
        |> Enum.sort_by(fn x -> x.tag.display_name end)

      request = get(conn, "/api/v2/search?q=#{name}")
      assert response = json_response(request, 200)

      assert Enum.count(response["items"]) == 50
      assert response["next_page_params"] != nil
      assert Enum.at(response["items"], 0)["type"] == "label"
      assert Enum.at(response["items"], 49)["type"] == "label"

      request_2 = get(conn, "/api/v2/search", response["next_page_params"] |> Query.encode() |> Query.decode())
      assert response_2 = json_response(request_2, 200)

      assert Enum.count(response_2["items"]) == 50
      assert response_2["next_page_params"] != nil
      assert Enum.at(response_2["items"], 0)["type"] == "label"
      assert Enum.at(response_2["items"], 1)["type"] == "token"
      assert Enum.at(response_2["items"], 49)["type"] == "token"

      request_3 = get(conn, "/api/v2/search", response_2["next_page_params"] |> Query.encode() |> Query.decode())
      assert response_3 = json_response(request_3, 200)

      assert Enum.count(response_3["items"]) == 50
      assert response_3["next_page_params"] != nil
      assert Enum.at(response_3["items"], 0)["type"] == "token"
      assert Enum.at(response_3["items"], 1)["type"] == "token"
      assert Enum.at(response_3["items"], 2)["type"] == "contract"
      assert Enum.at(response_3["items"], 49)["type"] == "contract"

      request_4 = get(conn, "/api/v2/search", response_3["next_page_params"] |> Query.encode() |> Query.decode())
      assert response_4 = json_response(request_4, 200)

      assert Enum.count(response_4["items"]) == 3
      assert response_4["next_page_params"] == nil
      assert Enum.all?(response_4["items"], fn x -> x["type"] == "contract" end)

      labels_from_api = response["items"] ++ [Enum.at(response_2["items"], 0)]

      assert labels
             |> Enum.zip(labels_from_api)
             |> Enum.all?(fn {label, item} ->
               label.tag.display_name == item["name"] && item["type"] == "label" &&
                 item["address"] == Address.checksum(label.address_hash)
             end)

      tokens_from_api = Enum.slice(response_2["items"], 1, 49) ++ Enum.slice(response_3["items"], 0, 2)

      assert tokens
             |> Enum.zip(tokens_from_api)
             |> Enum.all?(fn {token, item} ->
               token.name == item["name"] && item["type"] == "token" &&
                 item["address"] == Address.checksum(token.contract_address_hash)
             end)

      contracts_from_api = Enum.slice(response_3["items"], 2, 48) ++ response_4["items"]

      assert contracts
             |> Enum.zip(contracts_from_api)
             |> Enum.all?(fn {contract, item} ->
               contract.name == item["name"] && item["type"] == "contract" &&
                 item["address"] == Address.checksum(contract.address_hash)
             end)
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
      assert item["token_type"] == token.type
      assert item["is_smart_contract_verified"] == token.contract_address.verified
      assert item["exchange_rate"] == (token.fiat_value && to_string(token.fiat_value))
      assert item["total_supply"] == to_string(token.total_supply)
      assert item["icon_url"] == token.icon_url
      assert item["is_verified_via_admin_panel"] == token.is_verified_via_admin_panel
    end

    test "search token by hash", %{conn: conn} do
      token = insert(:unique_token)

      request = get(conn, "/api/v2/search?q=#{token.contract_address_hash}")
      assert response = json_response(request, 200)

      assert Enum.count(response["items"]) == 2
      assert response["next_page_params"] == nil

      item = Enum.at(response["items"], 0)

      assert item["type"] == "token"
      assert item["name"] == token.name
      assert item["symbol"] == token.symbol
      assert item["address"] == Address.checksum(token.contract_address_hash)
      assert item["token_url"] =~ Address.checksum(token.contract_address_hash)
      assert item["address_url"] =~ Address.checksum(token.contract_address_hash)
      assert item["token_type"] == token.type
      assert item["is_smart_contract_verified"] == token.contract_address.verified
      assert item["exchange_rate"] == (token.fiat_value && to_string(token.fiat_value))
      assert item["total_supply"] == to_string(token.total_supply)
      assert item["icon_url"] == token.icon_url
      assert item["is_verified_via_admin_panel"] == token.is_verified_via_admin_panel

      item_1 = Enum.at(response["items"], 1)

      assert item_1["type"] == "address"
    end

    test "search transaction", %{conn: conn} do
      transaction = insert(:transaction, block_timestamp: nil)

      request = get(conn, "/api/v2/search?q=#{transaction.hash}")
      assert response = json_response(request, 200)

      assert Enum.count(response["items"]) == 1
      assert response["next_page_params"] == nil

      item = Enum.at(response["items"], 0)

      assert item["type"] == "transaction"
      assert item["transaction_hash"] == to_string(transaction.hash)
      assert item["url"] =~ to_string(transaction.hash)
      assert item["timestamp"] == nil
    end

    test "search transaction with timestamp", %{conn: conn} do
      transaction = :transaction |> insert()
      block = insert(:block, hash: transaction.hash)
      transaction |> with_block(block)

      request = get(conn, "/api/v2/search?q=#{transaction.hash}")
      assert response = json_response(request, 200)

      assert Enum.count(response["items"]) == 2
      assert response["next_page_params"] == nil

      transaction_item = Enum.find(response["items"], fn x -> x["type"] == "transaction" end)

      assert transaction_item["type"] == "transaction"
      assert transaction_item["transaction_hash"] == to_string(transaction.hash)
      assert transaction_item["url"] =~ to_string(transaction.hash)

      assert transaction_item["timestamp"] ==
               block.timestamp |> to_string() |> String.replace(" ", "T")

      block_item = Enum.find(response["items"], fn x -> x["type"] == "block" end)
      assert block_item["type"] == "block"
      assert block_item["block_hash"] == to_string(block.hash)
      assert block_item["url"] =~ to_string(block.hash)
      assert transaction_item["timestamp"] == block_item["timestamp"]
    end

    test "search tags", %{conn: conn} do
      tag = insert(:address_to_tag)

      request = get(conn, "/api/v2/search?q=#{tag.tag.display_name}")
      assert response = json_response(request, 200)

      assert Enum.count(response["items"]) == 1
      assert response["next_page_params"] == nil

      item = Enum.at(response["items"], 0)

      assert item["type"] == "label"
      assert item["address"] == Address.checksum(tag.address.hash)
      assert item["name"] == tag.tag.display_name
      assert item["url"] =~ Address.checksum(tag.address.hash)
      assert item["is_smart_contract_verified"] == tag.address.verified
    end

    test "check that simultaneous search of ", %{conn: conn} do
      block = insert(:block, number: 10000)

      insert(:smart_contract, name: to_string(block.number))
      insert(:token, name: to_string(block.number))

      insert(:address_to_tag,
        tag: %AddressTag{
          label: "qwerty",
          display_name: to_string(block.number)
        }
      )

      request = get(conn, "/api/v2/search?q=#{block.number}")
      assert response = json_response(request, 200)

      assert Enum.count(response["items"]) == 4
      assert response["next_page_params"] == nil
    end

    test "search for a big positive integer", %{conn: conn} do
      big_integer = :math.pow(2, 64) |> round |> :erlang.integer_to_binary()
      request = get(conn, "/api/v2/search?q=#{big_integer}")
      assert response = json_response(request, 200)

      assert Enum.count(response["items"]) == 0
      assert response["next_page_params"] == nil
    end

    test "search for a big negative integer", %{conn: conn} do
      big_integer = (:math.pow(2, 64) - 1) |> round |> :erlang.integer_to_binary()
      request = get(conn, "/api/v2/search?q=#{big_integer}")
      assert response = json_response(request, 200)

      assert Enum.count(response["items"]) == 0
      assert response["next_page_params"] == nil
    end
  end

  describe "/search/check-redirect" do
    test "finds a consensus block by block number", %{conn: conn} do
      block = insert(:block)

      hash = to_string(block.hash)

      request = get(conn, "/api/v2/search/check-redirect?q=#{block.number}")

      assert %{"redirect" => true, "type" => "block", "parameter" => ^hash} = json_response(request, 200)
    end

    test "redirects to search results page even for searching non-consensus block by number", %{conn: conn} do
      %Block{number: number} = insert(:block, consensus: false)

      request = get(conn, "/api/v2/search/check-redirect?q=#{number}")

      %{"redirect" => false, "type" => nil, "parameter" => nil} = json_response(request, 200)
    end

    test "finds non-consensus block by hash", %{conn: conn} do
      %Block{hash: hash} = insert(:block, consensus: false)

      conn = get(conn, "/search?q=#{hash}")

      hash = to_string(hash)

      request = get(conn, "/api/v2/search/check-redirect?q=#{hash}")

      assert %{"redirect" => true, "type" => "block", "parameter" => ^hash} = json_response(request, 200)
    end

    test "finds a transaction by hash", %{conn: conn} do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      hash = to_string(transaction.hash)

      request = get(conn, "/api/v2/search/check-redirect?q=#{hash}")

      assert %{"redirect" => true, "type" => "transaction", "parameter" => ^hash} = json_response(request, 200)
    end

    test "finds a transaction by hash when there are not 0x prefix", %{conn: conn} do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      hash = to_string(transaction.hash)

      "0x" <> non_prefix_hash = to_string(transaction.hash)

      request = get(conn, "/api/v2/search/check-redirect?q=#{non_prefix_hash}")

      assert %{"redirect" => true, "type" => "transaction", "parameter" => ^hash} = json_response(request, 200)
    end

    test "finds an address by hash", %{conn: conn} do
      address = insert(:address)

      hash = Address.checksum(address.hash)

      request = get(conn, "/api/v2/search/check-redirect?q=#{to_string(address.hash)}")

      assert %{"redirect" => true, "type" => "address", "parameter" => ^hash} = json_response(request, 200)
    end

    test "finds an address by hash when there are extra spaces", %{conn: conn} do
      address = insert(:address)

      hash = Address.checksum(address.hash)

      request = get(conn, "/api/v2/search/check-redirect?q=#{to_string(address.hash)} ")

      assert %{"redirect" => true, "type" => "address", "parameter" => ^hash} = json_response(request, 200)
    end

    test "finds an address by hash when there are not 0x prefix", %{conn: conn} do
      address = insert(:address)

      "0x" <> non_prefix_hash = to_string(address.hash)

      hash = Address.checksum(address.hash)

      request = get(conn, "/api/v2/search/check-redirect?q=#{non_prefix_hash}")

      assert %{"redirect" => true, "type" => "address", "parameter" => ^hash} = json_response(request, 200)
    end

    test "redirects to result page when it finds nothing", %{conn: conn} do
      request = get(conn, "/api/v2/search/check-redirect?q=qwerty")

      %{"redirect" => false, "type" => nil, "parameter" => nil} = json_response(request, 200)
    end
  end

  describe "/search/quick" do
    test "check that all categories are in response list", %{conn: conn} do
      name = "156000"

      tags =
        for _ <- 0..50 do
          insert(:address_to_tag, tag: build(:address_tag, display_name: name))
        end

      contracts = insert_list(50, :smart_contract, name: name)
      tokens = insert_list(50, :token, name: name)
      blocks = [insert(:block, number: name, consensus: false), insert(:block, number: name)]

      request = get(conn, "/api/v2/search/quick?q=#{name}")
      assert response = json_response(request, 200)
      assert Enum.count(response) == 50

      assert response |> Enum.filter(fn x -> x["type"] == "label" end) |> Enum.map(fn x -> x["address"] end) ==
               tags |> Enum.reverse() |> Enum.take(16) |> Enum.map(fn tag -> Address.checksum(tag.address.hash) end)

      assert response |> Enum.filter(fn x -> x["type"] == "contract" end) |> Enum.map(fn x -> x["address"] end) ==
               contracts
               |> Enum.reverse()
               |> Enum.take(16)
               |> Enum.map(fn contract -> Address.checksum(contract.address_hash) end)

      assert response |> Enum.filter(fn x -> x["type"] == "token" end) |> Enum.map(fn x -> x["address"] end) ==
               tokens
               |> Enum.reverse()
               |> Enum.sort_by(fn x -> x.is_verified_via_admin_panel end, :desc)
               |> Enum.take(16)
               |> Enum.map(fn token -> Address.checksum(token.contract_address_hash) end)

      block_hashes = response |> Enum.filter(fn x -> x["type"] == "block" end) |> Enum.map(fn x -> x["block_hash"] end)

      assert block_hashes == blocks |> Enum.reverse() |> Enum.map(fn block -> to_string(block.hash) end) ||
               block_hashes == blocks |> Enum.map(fn block -> to_string(block.hash) end)

      assert response |> Enum.filter(fn x -> x["block_type"] == "block" end) |> Enum.count() == 1
      assert response |> Enum.filter(fn x -> x["block_type"] == "reorg" end) |> Enum.count() == 1
    end

    test "returns empty list and don't crash", %{conn: conn} do
      request = get(conn, "/api/v2/search/quick?q=qwertyuioiuytrewertyuioiuytrertyuio")
      assert [] = json_response(request, 200)
    end
  end
end
