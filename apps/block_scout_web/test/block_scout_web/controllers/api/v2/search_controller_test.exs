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

    test "check pagination #3 (ens and metadata tags added)", %{conn: conn} do
      bypass = Bypass.open()
      metadata_envs = Application.get_env(:explorer, Explorer.MicroserviceInterfaces.Metadata)
      bens_envs = Application.get_env(:explorer, Explorer.MicroserviceInterfaces.BENS)
      old_chain_id = Application.get_env(:block_scout_web, :chain_id)
      chain_id = 1
      Application.put_env(:block_scout_web, :chain_id, chain_id)
      old_hide_scam_addresses = Application.get_env(:block_scout_web, :hide_scam_addresses)
      Application.put_env(:block_scout_web, :hide_scam_addresses, true)

      on_exit(fn ->
        Bypass.down(bypass)
        Application.put_env(:explorer, Explorer.MicroserviceInterfaces.Metadata, metadata_envs)
        Application.put_env(:explorer, Explorer.MicroserviceInterfaces.BENS, bens_envs)
        Application.put_env(:block_scout_web, :chain_id, old_chain_id)
        Application.put_env(:block_scout_web, :hide_scam_addresses, old_hide_scam_addresses)
      end)

      Application.put_env(:explorer, Explorer.MicroserviceInterfaces.Metadata,
        service_url: "http://localhost:#{bypass.port}",
        enabled: true
      )

      Application.put_env(:explorer, Explorer.MicroserviceInterfaces.BENS,
        service_url: "http://localhost:#{bypass.port}",
        enabled: true
      )

      name = "contract.eth"

      contracts =
        for(i <- 0..50, do: insert(:smart_contract, name: "#{name |> String.replace(".", " ")} #{i}"))
        |> Enum.sort_by(fn x -> x.name end)

      tokens =
        for i <- 0..50,
            do: insert(:token, name: "#{name |> String.replace(".", " ")} #{i}", fiat_value: 10000 - i, holder_count: 0)

      labels =
        for(
          i <- 0..50,
          do:
            insert(:address_to_tag, tag: build(:address_tag, display_name: "#{name |> String.replace(".", " ")} #{i}"))
        )
        |> Enum.sort_by(fn x -> x.tag.display_name end)

      address_1 = insert(:address)
      address_2 = insert(:address)
      address_3 = build(:address)
      address_4 = build(:address)
      address_5 = insert(:address)

      metadata_response_1 =
        %{
          "items" =>
            for(
              i <- 0..24,
              do: %{
                "tag" => %{
                  "slug" => "#{name} #{i}",
                  "name" => "#{name} #{i}",
                  "tagType" => "name",
                  "ordinal" => 0,
                  "meta" => "{}"
                },
                "addresses" => [
                  to_string(address_1)
                ]
              }
            ) ++
              for(
                i <- 0..23,
                do: %{
                  "tag" => %{
                    "slug" => "#{name} #{25 + i}",
                    "name" => "#{name} #{25 + i}",
                    "tagType" => "name",
                    "ordinal" => 0,
                    "meta" => "{}"
                  },
                  "addresses" => [
                    to_string(address_2)
                  ]
                }
              ) ++
              [
                %{
                  "tag" => %{
                    "slug" => "#{name} 49",
                    "name" => "#{name} 49",
                    "tagType" => "name",
                    "ordinal" => 0,
                    "meta" => "{}"
                  },
                  "addresses" => [
                    to_string(address_3),
                    to_string(address_4)
                  ]
                }
              ],
          "next_page_params" => %{
            "page_token" => "0,celo:_eth_helper,name",
            "page_size" => 50
          }
        }

      metadata_response_2 = %{
        "items" =>
          for(
            i <- 22..23,
            do: %{
              "tag" => %{
                "slug" => "#{name} #{25 + i}",
                "name" => "#{name} #{25 + i}",
                "tagType" => "name",
                "ordinal" => 0,
                "meta" => "{}"
              },
              "addresses" => [
                to_string(address_2)
              ]
            }
          ) ++
            [
              %{
                "tag" => %{
                  "slug" => "#{name} 49",
                  "name" => "#{name} 49",
                  "tagType" => "name",
                  "ordinal" => 0,
                  "meta" => "{}"
                },
                "addresses" => [
                  to_string(address_3),
                  to_string(address_4)
                ]
              }
            ] ++
            [
              %{
                "tag" => %{
                  "slug" => "#{name} 0",
                  "name" => "#{name} 0",
                  "tagType" => "name",
                  "ordinal" => 0,
                  "meta" => "{}"
                },
                "addresses" => [
                  to_string(address_5)
                ]
              }
            ],
        "next_page_params" => nil
      }

      page_token_1 = "0,#{name} #{47},name"

      Bypass.expect(
        bypass,
        "GET",
        "/api/v1/tags%3Asearch",
        fn conn ->
          assert conn.params["name"] == name

          case conn.params["page_token"] do
            nil -> Plug.Conn.resp(conn, 200, Jason.encode!(metadata_response_1))
            ^page_token_1 -> Plug.Conn.resp(conn, 200, Jason.encode!(metadata_response_2))
            _ -> raise "Unexpected page_token"
          end
        end
      )

      ens_address = insert(:address)

      ens_response = """
      {
      "items": [
          {
              "id": "0xee6c4522aab0003e8d14cd40a6af439055fd2577951148c14b6cea9a53475835",
              "name": "#{name}",
              "resolved_address": {
                  "hash": "#{to_string(ens_address)}"
              },
              "owner": {
                  "hash": "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"
              },
              "wrapped_owner": null,
              "registration_date": "2017-06-18T08:39:14.000Z",
              "expiry_date": null,
              "protocol": {
                  "id": "ens",
                  "short_name": "ENS",
                  "title": "Ethereum Name Service",
                  "description": "The Ethereum Name Service (ENS) is a distributed, open, and extensible naming system based on the Ethereum blockchain.",
                  "deployment_blockscout_base_url": "https://eth.blockscout.com/",
                  "tld_list": [
                      "eth"
                  ],
                  "icon_url": "https://i.imgur.com/GOfUwCb.jpeg",
                  "docs_url": "https://docs.ens.domains/"
              }
          }
      ],
      "next_page_params": null
      }
      """

      Bypass.expect(
        bypass,
        "GET",
        "/api/v1/1/domains%3Alookup",
        fn conn ->
          assert conn.params["name"] == name

          Plug.Conn.resp(conn, 200, ens_response)
        end
      )

      request = get(conn, "/api/v2/search?q=#{name}")
      assert response = json_response(request, 200)

      assert Enum.count(response["items"]) == 50
      assert response["next_page_params"] != nil
      assert Enum.at(response["items"], 0)["type"] == "ens_domain"
      assert Enum.slice(response["items"], 1, 49) |> Enum.all?(fn x -> x["type"] == "label" end)

      request_2 = get(conn, "/api/v2/search", response["next_page_params"] |> Query.encode() |> Query.decode())
      assert response_2 = json_response(request_2, 200)

      assert Enum.count(response_2["items"]) == 50
      assert response_2["next_page_params"] != nil
      assert Enum.at(response_2["items"], 0)["type"] == "label"
      assert Enum.at(response_2["items"], 1)["type"] == "label"
      assert Enum.slice(response_2["items"], 2, 48) |> Enum.all?(fn x -> x["type"] == "token" end)

      request_3 = get(conn, "/api/v2/search", response_2["next_page_params"] |> Query.encode() |> Query.decode())
      assert response_3 = json_response(request_3, 200)

      assert Enum.count(response_3["items"]) == 50
      assert response_3["next_page_params"] != nil

      assert Enum.slice(response_3["items"], 0, 3) |> Enum.all?(fn x -> x["type"] == "token" end)
      assert Enum.slice(response_3["items"], 3, 47) |> Enum.all?(fn x -> x["type"] == "metadata_tag" end)

      request_4 = get(conn, "/api/v2/search", response_3["next_page_params"] |> Query.encode() |> Query.decode())
      assert response_4 = json_response(request_4, 200)

      assert Enum.count(response_4["items"]) == 50
      assert response_4["next_page_params"] != nil

      assert Enum.slice(response_4["items"], 0, 5) |> Enum.all?(fn x -> x["type"] == "metadata_tag" end)
      assert Enum.slice(response_4["items"], 5, 45) |> Enum.all?(fn x -> x["type"] == "contract" end)

      request_5 = get(conn, "/api/v2/search", response_4["next_page_params"] |> Query.encode() |> Query.decode())
      assert response_5 = json_response(request_5, 200)

      assert Enum.count(response_5["items"]) == 6
      assert response_5["next_page_params"] == nil

      assert Enum.all?(response_5["items"], fn x -> x["type"] == "contract" end)

      labels_from_api = Enum.slice(response["items"], 1, 49) ++ Enum.slice(response_2["items"], 0, 2)

      assert labels
             |> Enum.zip(labels_from_api)
             |> Enum.all?(fn {label, item} ->
               label.tag.display_name == item["name"] && item["type"] == "label" &&
                 item["address"] == Address.checksum(label.address_hash)
             end)

      tokens_from_api = Enum.slice(response_2["items"], 2, 48) ++ Enum.slice(response_3["items"], 0, 3)

      assert tokens
             |> Enum.zip(tokens_from_api)
             |> Enum.all?(fn {token, item} ->
               token.name == item["name"] && item["type"] == "token" &&
                 item["address"] == Address.checksum(token.contract_address_hash)
             end)

      contracts_from_api = Enum.slice(response_4["items"], 5, 45) ++ response_5["items"]

      assert contracts
             |> Enum.zip(contracts_from_api)
             |> Enum.all?(fn {contract, item} ->
               contract.name == item["name"] && item["type"] == "contract" &&
                 item["address"] == Address.checksum(contract.address_hash)
             end)

      metadata_tags_from_api = Enum.slice(response_3["items"], 3, 47) ++ Enum.slice(response_4["items"], 0, 5)

      metadata_tags =
        ((metadata_response_1["items"] |> Enum.drop(-3)) ++ metadata_response_2["items"])
        |> Enum.reduce([], fn x, acc ->
          acc ++
            Enum.map(x["addresses"], fn addr ->
              {addr, x["tag"]}
            end)
        end)

      assert metadata_tags
             |> Enum.zip(metadata_tags_from_api)
             |> Enum.all?(fn {{address_hash, tag}, api_item} ->
               tag["name"] == api_item["metadata"]["name"] && tag["slug"] == api_item["metadata"]["slug"] &&
                 api_item["type"] == "metadata_tag" &&
                 api_item["address"] == address_hash
             end)

      ens = Enum.at(response["items"], 0)
      assert ens["address"] == to_string(ens_address)
      assert ens["ens_info"]["name"] == name
    end

    test "check pagination #4 (ens and metadata tags (complex case) added)", %{conn: conn} do
      bypass = Bypass.open()
      metadata_envs = Application.get_env(:explorer, Explorer.MicroserviceInterfaces.Metadata)
      bens_envs = Application.get_env(:explorer, Explorer.MicroserviceInterfaces.BENS)
      old_chain_id = Application.get_env(:block_scout_web, :chain_id)
      chain_id = 1
      Application.put_env(:block_scout_web, :chain_id, chain_id)

      on_exit(fn ->
        Bypass.down(bypass)
        Application.put_env(:explorer, Explorer.MicroserviceInterfaces.Metadata, metadata_envs)
        Application.put_env(:explorer, Explorer.MicroserviceInterfaces.BENS, bens_envs)
        Application.put_env(:block_scout_web, :chain_id, old_chain_id)
      end)

      Application.put_env(:explorer, Explorer.MicroserviceInterfaces.Metadata,
        service_url: "http://localhost:#{bypass.port}",
        enabled: true
      )

      Application.put_env(:explorer, Explorer.MicroserviceInterfaces.BENS,
        service_url: "http://localhost:#{bypass.port}",
        enabled: true
      )

      name = "contract.eth"

      contracts =
        for(i <- 0..50, do: insert(:smart_contract, name: "#{name |> String.replace(".", " ")} #{i}"))
        |> Enum.sort_by(fn x -> x.name end)

      tokens =
        for i <- 0..50,
            do: insert(:token, name: "#{name |> String.replace(".", " ")} #{i}", fiat_value: 10000 - i, holder_count: 0)

      labels =
        for(
          i <- 0..50,
          do:
            insert(:address_to_tag, tag: build(:address_tag, display_name: "#{name |> String.replace(".", " ")} #{i}"))
        )
        |> Enum.sort_by(fn x -> x.tag.display_name end)

      address_1 = insert(:address)
      address_2 = insert(:address)
      address_3 = build(:address)
      address_4 = build(:address)
      address_5 = insert(:address)

      metadata_response_1 =
        %{
          "items" =>
            for(
              i <- 0..24,
              do: %{
                "tag" => %{
                  "slug" => "#{name} #{i}",
                  "name" => "#{name} #{i}",
                  "tagType" => "name",
                  "ordinal" => 0,
                  "meta" => "{}"
                },
                "addresses" => [
                  to_string(address_1)
                ]
              }
            ) ++
              for(
                i <- 0..20,
                do: %{
                  "tag" => %{
                    "slug" => "#{name} #{25 + i}",
                    "name" => "#{name} #{25 + i}",
                    "tagType" => "name",
                    "ordinal" => 0,
                    "meta" => "{}"
                  },
                  "addresses" => [
                    to_string(address_2)
                  ]
                }
              ) ++
              [
                %{
                  "tag" => %{
                    "slug" => "#{name} #{25 + 21}",
                    "name" => "#{name} #{25 + 21}",
                    "tagType" => "name",
                    "ordinal" => 0,
                    "meta" => "{}"
                  },
                  "addresses" => [
                    to_string(address_2),
                    to_string(address_3)
                  ]
                }
              ] ++
              for(
                i <- 22..23,
                do: %{
                  "tag" => %{
                    "slug" => "#{name} #{25 + i}",
                    "name" => "#{name} #{25 + i}",
                    "tagType" => "name",
                    "ordinal" => 0,
                    "meta" => "{}"
                  },
                  "addresses" => [
                    to_string(address_2)
                  ]
                }
              ) ++
              [
                %{
                  "tag" => %{
                    "slug" => "#{name} 49",
                    "name" => "#{name} 49",
                    "tagType" => "name",
                    "ordinal" => 0,
                    "meta" => "{}"
                  },
                  "addresses" => [
                    to_string(address_4)
                  ]
                }
              ],
          "next_page_params" => %{
            "page_token" => "0,celo:_eth_helper,name",
            "page_size" => 50
          }
        }

      metadata_response_2 = %{
        "items" =>
          [
            %{
              "tag" => %{
                "slug" => "#{name} #{25 + 21}",
                "name" => "#{name} #{25 + 21}",
                "tagType" => "name",
                "ordinal" => 0,
                "meta" => "{}"
              },
              "addresses" => [
                to_string(address_2),
                to_string(address_3)
              ]
            }
          ] ++
            for(
              i <- 22..23,
              do: %{
                "tag" => %{
                  "slug" => "#{name} #{25 + i}",
                  "name" => "#{name} #{25 + i}",
                  "tagType" => "name",
                  "ordinal" => 0,
                  "meta" => "{}"
                },
                "addresses" => [
                  to_string(address_2)
                ]
              }
            ) ++
            [
              %{
                "tag" => %{
                  "slug" => "#{name} 49",
                  "name" => "#{name} 49",
                  "tagType" => "name",
                  "ordinal" => 0,
                  "meta" => "{}"
                },
                "addresses" => [
                  to_string(address_4)
                ]
              }
            ] ++
            [
              %{
                "tag" => %{
                  "slug" => "#{name} 0",
                  "name" => "#{name} 0",
                  "tagType" => "name",
                  "ordinal" => 0,
                  "meta" => "{}"
                },
                "addresses" => [
                  to_string(address_5)
                ]
              }
            ],
        "next_page_params" => nil
      }

      page_token_1 = "0,#{name} #{46},name"

      Bypass.expect(
        bypass,
        "GET",
        "/api/v1/tags%3Asearch",
        fn conn ->
          assert conn.params["name"] == name

          case conn.params["page_token"] do
            nil -> Plug.Conn.resp(conn, 200, Jason.encode!(metadata_response_1))
            ^page_token_1 -> Plug.Conn.resp(conn, 200, Jason.encode!(metadata_response_2))
            _ -> raise "Unexpected page_token"
          end
        end
      )

      ens_address = insert(:address)

      ens_response = """
      {
      "items": [
          {
              "id": "0xee6c4522aab0003e8d14cd40a6af439055fd2577951148c14b6cea9a53475835",
              "name": "#{name}",
              "resolved_address": {
                  "hash": "#{to_string(ens_address)}"
              },
              "owner": {
                  "hash": "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"
              },
              "wrapped_owner": null,
              "registration_date": "2017-06-18T08:39:14.000Z",
              "expiry_date": null,
              "protocol": {
                  "id": "ens",
                  "short_name": "ENS",
                  "title": "Ethereum Name Service",
                  "description": "The Ethereum Name Service (ENS) is a distributed, open, and extensible naming system based on the Ethereum blockchain.",
                  "deployment_blockscout_base_url": "https://eth.blockscout.com/",
                  "tld_list": [
                      "eth"
                  ],
                  "icon_url": "https://i.imgur.com/GOfUwCb.jpeg",
                  "docs_url": "https://docs.ens.domains/"
              }
          }
      ],
      "next_page_params": null
      }
      """

      Bypass.expect(
        bypass,
        "GET",
        "/api/v1/1/domains%3Alookup",
        fn conn ->
          assert conn.params["name"] == name

          Plug.Conn.resp(conn, 200, ens_response)
        end
      )

      request = get(conn, "/api/v2/search?q=#{name}")
      assert response = json_response(request, 200)

      assert Enum.count(response["items"]) == 50
      assert response["next_page_params"] != nil
      assert Enum.at(response["items"], 0)["type"] == "ens_domain"
      assert Enum.slice(response["items"], 1, 49) |> Enum.all?(fn x -> x["type"] == "label" end)

      request_2 = get(conn, "/api/v2/search", response["next_page_params"] |> Query.encode() |> Query.decode())
      assert response_2 = json_response(request_2, 200)

      assert Enum.count(response_2["items"]) == 50
      assert response_2["next_page_params"] != nil
      assert Enum.at(response_2["items"], 0)["type"] == "label"
      assert Enum.at(response_2["items"], 1)["type"] == "label"
      assert Enum.slice(response_2["items"], 2, 48) |> Enum.all?(fn x -> x["type"] == "token" end)

      request_3 = get(conn, "/api/v2/search", response_2["next_page_params"] |> Query.encode() |> Query.decode())
      assert response_3 = json_response(request_3, 200)

      assert Enum.count(response_3["items"]) == 50
      assert response_3["next_page_params"] != nil

      assert Enum.slice(response_3["items"], 0, 3) |> Enum.all?(fn x -> x["type"] == "token" end)
      assert Enum.slice(response_3["items"], 3, 47) |> Enum.all?(fn x -> x["type"] == "metadata_tag" end)

      request_4 = get(conn, "/api/v2/search", response_3["next_page_params"] |> Query.encode() |> Query.decode())
      assert response_4 = json_response(request_4, 200)

      assert Enum.count(response_4["items"]) == 50
      assert response_4["next_page_params"] != nil

      assert Enum.slice(response_4["items"], 0, 5) |> Enum.all?(fn x -> x["type"] == "metadata_tag" end)
      assert Enum.slice(response_4["items"], 5, 45) |> Enum.all?(fn x -> x["type"] == "contract" end)

      request_5 = get(conn, "/api/v2/search", response_4["next_page_params"] |> Query.encode() |> Query.decode())
      assert response_5 = json_response(request_5, 200)

      assert Enum.count(response_5["items"]) == 6
      assert response_5["next_page_params"] == nil

      assert Enum.all?(response_5["items"], fn x -> x["type"] == "contract" end)

      labels_from_api = Enum.slice(response["items"], 1, 49) ++ Enum.slice(response_2["items"], 0, 2)

      assert labels
             |> Enum.zip(labels_from_api)
             |> Enum.all?(fn {label, item} ->
               label.tag.display_name == item["name"] && item["type"] == "label" &&
                 item["address"] == Address.checksum(label.address_hash)
             end)

      tokens_from_api = Enum.slice(response_2["items"], 2, 48) ++ Enum.slice(response_3["items"], 0, 3)

      assert tokens
             |> Enum.zip(tokens_from_api)
             |> Enum.all?(fn {token, item} ->
               token.name == item["name"] && item["type"] == "token" &&
                 item["address"] == Address.checksum(token.contract_address_hash)
             end)

      contracts_from_api = Enum.slice(response_4["items"], 5, 45) ++ response_5["items"]

      assert contracts
             |> Enum.zip(contracts_from_api)
             |> Enum.all?(fn {contract, item} ->
               contract.name == item["name"] && item["type"] == "contract" &&
                 item["address"] == Address.checksum(contract.address_hash)
             end)

      metadata_tags_from_api = Enum.slice(response_3["items"], 3, 47) ++ Enum.slice(response_4["items"], 0, 5)

      metadata_tags =
        ((metadata_response_1["items"] |> Enum.drop(-4)) ++ metadata_response_2["items"])
        |> Enum.reduce([], fn x, acc ->
          acc ++
            Enum.map(x["addresses"], fn addr ->
              {addr, x["tag"]}
            end)
        end)

      assert metadata_tags
             |> Enum.zip(metadata_tags_from_api)
             |> Enum.all?(fn {{address_hash, tag}, api_item} ->
               tag["name"] == api_item["metadata"]["name"] && tag["slug"] == api_item["metadata"]["slug"] &&
                 api_item["type"] == "metadata_tag" &&
                 api_item["address"] == address_hash
             end)

      ens = Enum.at(response["items"], 0)
      assert ens["address"] == to_string(ens_address)
      assert ens["ens_info"]["name"] == name
    end

    test "finds a TAC operation", %{conn: conn} do
      bypass = Bypass.open()
      tac_envs = Application.get_env(:explorer, Explorer.MicroserviceInterfaces.TACOperationLifecycle)

      Application.put_env(:explorer, Explorer.MicroserviceInterfaces.TACOperationLifecycle,
        service_url: "http://localhost:#{bypass.port}",
        enabled: true
      )

      on_exit(fn ->
        Bypass.down(bypass)
        Application.put_env(:explorer, Explorer.MicroserviceInterfaces.TACOperationLifecycle, tac_envs)
      end)

      operation_id = "0xd06b6d3dbefcd1e4a5bb5806d0fdad87ae963bcc7d48d9a39ed361167958c09b"

      tac_response = """
      {
          "operation_id": "#{operation_id}",
          "sender": null,
          "status_history": [
              {
                  "is_exist": true,
                  "is_success": true,
                  "note": null,
                  "timestamp": "1746444308",
                  "transactions": [
                      {
                          "hash": "0x5626d3aaf5f7666f0d82919178b0ba0880683e8531b6718a83ca946d337a81c9",
                          "type": "TON"
                      }
                  ],
                  "type": "COLLECTED_IN_TAC"
              }
          ],
          "timestamp": "1746444308",
          "type": "PENDING"
      }
      """

      Bypass.expect(
        bypass,
        "GET",
        "/api/v1/tac/operations/#{operation_id}",
        fn conn -> Plug.Conn.resp(conn, 200, tac_response) end
      )

      request = get(conn, "/api/v2/search?q=#{operation_id}")

      assert %{
               "items" => [
                 %{
                   "priority" => 0,
                   "tac_operation" => %{
                     "operation_id" => operation_id,
                     "sender" => nil,
                     "status_history" => [
                       %{
                         "is_exist" => true,
                         "is_success" => true,
                         "note" => nil,
                         "timestamp" => "1746444308",
                         "transactions" => [
                           %{
                             "hash" => "0x5626d3aaf5f7666f0d82919178b0ba0880683e8531b6718a83ca946d337a81c9",
                             "type" => "TON"
                           }
                         ],
                         "type" => "COLLECTED_IN_TAC"
                       }
                     ],
                     "timestamp" => "1746444308",
                     "type" => "PENDING"
                   },
                   "type" => "tac_operation"
                 }
               ],
               "next_page_params" => nil
             } == json_response(request, 200)
    end

    test "handles 404 from TAC microservice", %{conn: conn} do
      bypass = Bypass.open()
      tac_envs = Application.get_env(:explorer, Explorer.MicroserviceInterfaces.TACOperationLifecycle)

      Application.put_env(:explorer, Explorer.MicroserviceInterfaces.TACOperationLifecycle,
        service_url: "http://localhost:#{bypass.port}",
        enabled: true
      )

      on_exit(fn ->
        Bypass.down(bypass)
        Application.put_env(:explorer, Explorer.MicroserviceInterfaces.TACOperationLifecycle, tac_envs)
      end)

      operation_id = "0xd06b6d3dbefcd1e4a5bb5806d0fdad87ae963bcc7d48d9a39ed361167958c09b"

      tac_response = """
      {
          "code": 5,
          "message": "cannot find operation id"
      }
      """

      Bypass.expect(
        bypass,
        "GET",
        "/api/v1/tac/operations/#{operation_id}",
        fn conn -> Plug.Conn.resp(conn, 404, tac_response) end
      )

      request = get(conn, "/api/v2/search?q=#{operation_id}")

      assert %{
               "items" => [],
               "next_page_params" => nil
             } == json_response(request, 200)
    end

    test "finds a TAC operation with transaction", %{conn: conn} do
      bypass = Bypass.open()
      tac_envs = Application.get_env(:explorer, Explorer.MicroserviceInterfaces.TACOperationLifecycle)

      Application.put_env(:explorer, Explorer.MicroserviceInterfaces.TACOperationLifecycle,
        service_url: "http://localhost:#{bypass.port}",
        enabled: true
      )

      on_exit(fn ->
        Bypass.down(bypass)
        Application.put_env(:explorer, Explorer.MicroserviceInterfaces.TACOperationLifecycle, tac_envs)
      end)

      transaction = insert(:transaction) |> with_block()

      operation_id = "#{transaction.hash}"

      tac_response = """
      {
          "operation_id": "#{operation_id}",
          "sender": null,
          "status_history": [
              {
                  "is_exist": true,
                  "is_success": true,
                  "note": null,
                  "timestamp": "1746444308",
                  "transactions": [
                      {
                          "hash": "0x5626d3aaf5f7666f0d82919178b0ba0880683e8531b6718a83ca946d337a81c9",
                          "type": "TON"
                      }
                  ],
                  "type": "COLLECTED_IN_TAC"
              }
          ],
          "timestamp": "1746444308",
          "type": "PENDING"
      }
      """

      Bypass.expect(
        bypass,
        "GET",
        "/api/v1/tac/operations/#{operation_id}",
        fn conn -> Plug.Conn.resp(conn, 200, tac_response) end
      )

      request = get(conn, "/api/v2/search?q=#{operation_id}")
      assert response = json_response(request, 200)

      # tl to check order
      assert %{
               "priority" => 0,
               "tac_operation" => %{
                 "operation_id" => operation_id,
                 "sender" => nil,
                 "status_history" => [
                   %{
                     "is_exist" => true,
                     "is_success" => true,
                     "note" => nil,
                     "timestamp" => "1746444308",
                     "transactions" => [
                       %{
                         "hash" => "0x5626d3aaf5f7666f0d82919178b0ba0880683e8531b6718a83ca946d337a81c9",
                         "type" => "TON"
                       }
                     ],
                     "type" => "COLLECTED_IN_TAC"
                   }
                 ],
                 "timestamp" => "1746444308",
                 "type" => "PENDING"
               },
               "type" => "tac_operation"
             } in tl(response["items"])

      assert %{
               "priority" => 0,
               "transaction_hash" => "#{transaction.hash}",
               "type" => "transaction",
               "timestamp" => "#{transaction.block_timestamp}" |> String.replace(" ", "T"),
               "url" => "/tx/#{transaction.hash}"
             } in response["items"]
    end

    test "finds a TAC operation with block", %{conn: conn} do
      bypass = Bypass.open()
      tac_envs = Application.get_env(:explorer, Explorer.MicroserviceInterfaces.TACOperationLifecycle)

      Application.put_env(:explorer, Explorer.MicroserviceInterfaces.TACOperationLifecycle,
        service_url: "http://localhost:#{bypass.port}",
        enabled: true
      )

      on_exit(fn ->
        Bypass.down(bypass)
        Application.put_env(:explorer, Explorer.MicroserviceInterfaces.TACOperationLifecycle, tac_envs)
      end)

      transaction = insert(:transaction) |> with_block()

      operation_id = "#{transaction.block_hash}"

      tac_response = """
      {
          "operation_id": "#{operation_id}",
          "sender": null,
          "status_history": [
              {
                  "is_exist": true,
                  "is_success": true,
                  "note": null,
                  "timestamp": "1746444308",
                  "transactions": [
                      {
                          "hash": "0x5626d3aaf5f7666f0d82919178b0ba0880683e8531b6718a83ca946d337a81c9",
                          "type": "TON"
                      }
                  ],
                  "type": "COLLECTED_IN_TAC"
              }
          ],
          "timestamp": "1746444308",
          "type": "PENDING"
      }
      """

      Bypass.expect(
        bypass,
        "GET",
        "/api/v1/tac/operations/#{operation_id}",
        fn conn -> Plug.Conn.resp(conn, 200, tac_response) end
      )

      request = get(conn, "/api/v2/search?q=#{operation_id}")
      assert response = json_response(request, 200)

      # tl to check order
      assert %{
               "priority" => 0,
               "tac_operation" => %{
                 "operation_id" => operation_id,
                 "sender" => nil,
                 "status_history" => [
                   %{
                     "is_exist" => true,
                     "is_success" => true,
                     "note" => nil,
                     "timestamp" => "1746444308",
                     "transactions" => [
                       %{
                         "hash" => "0x5626d3aaf5f7666f0d82919178b0ba0880683e8531b6718a83ca946d337a81c9",
                         "type" => "TON"
                       }
                     ],
                     "type" => "COLLECTED_IN_TAC"
                   }
                 ],
                 "timestamp" => "1746444308",
                 "type" => "PENDING"
               },
               "type" => "tac_operation"
             } in tl(response["items"])

      assert %{
               "block_hash" => "#{transaction.block_hash}",
               "block_number" => transaction.block_number,
               "block_type" => "block",
               "priority" => 3,
               "type" => "block",
               "timestamp" => "#{transaction.block_timestamp}" |> String.replace(" ", "T"),
               "url" => "/block/#{transaction.block_hash}"
             } in response["items"]
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

    test "check that all categories are in response list (ens + metadata included)", %{conn: conn} do
      bypass = Bypass.open()
      metadata_envs = Application.get_env(:explorer, Explorer.MicroserviceInterfaces.Metadata)
      bens_envs = Application.get_env(:explorer, Explorer.MicroserviceInterfaces.BENS)
      old_chain_id = Application.get_env(:block_scout_web, :chain_id)
      chain_id = 1
      Application.put_env(:block_scout_web, :chain_id, chain_id)

      on_exit(fn ->
        Bypass.down(bypass)
        Application.put_env(:explorer, Explorer.MicroserviceInterfaces.Metadata, metadata_envs)
        Application.put_env(:explorer, Explorer.MicroserviceInterfaces.BENS, bens_envs)
        Application.put_env(:block_scout_web, :chain_id, old_chain_id)
      end)

      Application.put_env(:explorer, Explorer.MicroserviceInterfaces.Metadata,
        service_url: "http://localhost:#{bypass.port}",
        enabled: true
      )

      Application.put_env(:explorer, Explorer.MicroserviceInterfaces.BENS,
        service_url: "http://localhost:#{bypass.port}",
        enabled: true
      )

      name = "qwe.eth"

      tags =
        for _ <- 0..50 do
          insert(:address_to_tag, tag: build(:address_tag, display_name: name |> String.replace(".", " ")))
        end

      contracts = insert_list(50, :smart_contract, name: name |> String.replace(".", " "))
      tokens = insert_list(50, :token, name: name |> String.replace(".", " "))
      ens_address = insert(:address)
      address_1 = build(:address)

      metadata_response =
        %{
          "items" =>
            for(
              i <- 0..49,
              do: %{
                "tag" => %{
                  "slug" => "#{name} #{i}",
                  "name" => "#{name} #{i}",
                  "tagType" => "name",
                  "ordinal" => 0,
                  "meta" => "{}"
                },
                "addresses" => [
                  to_string(address_1)
                ]
              }
            ),
          "next_page_params" => %{
            "page_token" => "0,celo:_eth_helper,name",
            "page_size" => 50
          }
        }

      Bypass.expect(
        bypass,
        "GET",
        "/api/v1/tags%3Asearch",
        fn conn ->
          assert conn.params["name"] == name

          Plug.Conn.resp(conn, 200, Jason.encode!(metadata_response))
        end
      )

      ens_response = """
      {
      "items": [
          {
              "id": "0xee6c4522aab0003e8d14cd40a6af439055fd2577951148c14b6cea9a53475835",
              "name": "#{name}",
              "resolved_address": {
                  "hash": "#{to_string(ens_address)}"
              },
              "owner": {
                  "hash": "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"
              },
              "wrapped_owner": null,
              "registration_date": "2017-06-18T08:39:14.000Z",
              "expiry_date": null,
              "protocol": {
                  "id": "ens",
                  "short_name": "ENS",
                  "title": "Ethereum Name Service",
                  "description": "The Ethereum Name Service (ENS) is a distributed, open, and extensible naming system based on the Ethereum blockchain.",
                  "deployment_blockscout_base_url": "https://eth.blockscout.com/",
                  "tld_list": [
                      "eth"
                  ],
                  "icon_url": "https://i.imgur.com/GOfUwCb.jpeg",
                  "docs_url": "https://docs.ens.domains/"
              }
          }
      ],
      "next_page_params": null
      }
      """

      Bypass.expect(
        bypass,
        "GET",
        "/api/v1/1/domains%3Alookup",
        fn conn ->
          assert conn.params["name"] == name

          Plug.Conn.resp(conn, 200, ens_response)
        end
      )

      request = get(conn, "/api/v2/search/quick?q=#{name}")
      assert response = json_response(request, 200)
      assert Enum.count(response) == 50

      assert response |> Enum.filter(fn x -> x["type"] == "label" end) |> Enum.map(fn x -> x["address"] end) ==
               tags |> Enum.reverse() |> Enum.take(12) |> Enum.map(fn tag -> Address.checksum(tag.address.hash) end)

      assert response |> Enum.filter(fn x -> x["type"] == "contract" end) |> Enum.map(fn x -> x["address"] end) ==
               contracts
               |> Enum.reverse()
               |> Enum.take(12)
               |> Enum.map(fn contract -> Address.checksum(contract.address_hash) end)

      assert response |> Enum.filter(fn x -> x["type"] == "token" end) |> Enum.map(fn x -> x["address"] end) ==
               tokens
               |> Enum.reverse()
               |> Enum.sort_by(fn x -> x.is_verified_via_admin_panel end, :desc)
               |> Enum.take(13)
               |> Enum.map(fn token -> Address.checksum(token.contract_address_hash) end)

      assert response |> Enum.filter(fn x -> x["type"] == "ens_domain" end) |> Enum.map(fn x -> x["address"] end) == [
               to_string(ens_address)
             ]

      metadata_tags = response |> Enum.filter(fn x -> x["type"] == "metadata_tag" end)

      assert Enum.count(metadata_tags) == 12

      assert metadata_tags
             |> Enum.with_index()
             |> Enum.all?(fn {x, index} ->
               x["address"] == to_string(address_1) && x["metadata"]["name"] == "#{name} #{index}"
             end)
    end

    test "finds a TAC operation", %{conn: conn} do
      bypass = Bypass.open()
      tac_envs = Application.get_env(:explorer, Explorer.MicroserviceInterfaces.TACOperationLifecycle)

      Application.put_env(:explorer, Explorer.MicroserviceInterfaces.TACOperationLifecycle,
        service_url: "http://localhost:#{bypass.port}",
        enabled: true
      )

      on_exit(fn ->
        Bypass.down(bypass)
        Application.put_env(:explorer, Explorer.MicroserviceInterfaces.TACOperationLifecycle, tac_envs)
      end)

      operation_id = "0xd06b6d3dbefcd1e4a5bb5806d0fdad87ae963bcc7d48d9a39ed361167958c09b"

      tac_response = """
      {
          "operation_id": "#{operation_id}",
          "sender": null,
          "status_history": [
              {
                  "is_exist": true,
                  "is_success": true,
                  "note": null,
                  "timestamp": "1746444308",
                  "transactions": [
                      {
                          "hash": "0x5626d3aaf5f7666f0d82919178b0ba0880683e8531b6718a83ca946d337a81c9",
                          "type": "TON"
                      }
                  ],
                  "type": "COLLECTED_IN_TAC"
              }
          ],
          "timestamp": "1746444308",
          "type": "PENDING"
      }
      """

      Bypass.expect(
        bypass,
        "GET",
        "/api/v1/tac/operations/#{operation_id}",
        fn conn -> Plug.Conn.resp(conn, 200, tac_response) end
      )

      request = get(conn, "/api/v2/search/quick?q=#{operation_id}")

      assert [
               %{
                 "priority" => 0,
                 "tac_operation" => %{
                   "operation_id" => operation_id,
                   "sender" => nil,
                   "status_history" => [
                     %{
                       "is_exist" => true,
                       "is_success" => true,
                       "note" => nil,
                       "timestamp" => "1746444308",
                       "transactions" => [
                         %{
                           "hash" => "0x5626d3aaf5f7666f0d82919178b0ba0880683e8531b6718a83ca946d337a81c9",
                           "type" => "TON"
                         }
                       ],
                       "type" => "COLLECTED_IN_TAC"
                     }
                   ],
                   "timestamp" => "1746444308",
                   "type" => "PENDING"
                 },
                 "type" => "tac_operation"
               }
             ] == json_response(request, 200)
    end

    test "finds a TAC operation with transaction", %{conn: conn} do
      bypass = Bypass.open()
      tac_envs = Application.get_env(:explorer, Explorer.MicroserviceInterfaces.TACOperationLifecycle)

      Application.put_env(:explorer, Explorer.MicroserviceInterfaces.TACOperationLifecycle,
        service_url: "http://localhost:#{bypass.port}",
        enabled: true
      )

      on_exit(fn ->
        Bypass.down(bypass)
        Application.put_env(:explorer, Explorer.MicroserviceInterfaces.TACOperationLifecycle, tac_envs)
      end)

      transaction = insert(:transaction) |> with_block()

      operation_id = "#{transaction.hash}"

      tac_response = """
      {
          "operation_id": "#{operation_id}",
          "sender": null,
          "status_history": [
              {
                  "is_exist": true,
                  "is_success": true,
                  "note": null,
                  "timestamp": "1746444308",
                  "transactions": [
                      {
                          "hash": "0x5626d3aaf5f7666f0d82919178b0ba0880683e8531b6718a83ca946d337a81c9",
                          "type": "TON"
                      }
                  ],
                  "type": "COLLECTED_IN_TAC"
              }
          ],
          "timestamp": "1746444308",
          "type": "PENDING"
      }
      """

      Bypass.expect(
        bypass,
        "GET",
        "/api/v1/tac/operations/#{operation_id}",
        fn conn -> Plug.Conn.resp(conn, 200, tac_response) end
      )

      request = get(conn, "/api/v2/search/quick?q=#{operation_id}")
      assert response = json_response(request, 200)

      # tl to check order
      assert %{
               "priority" => 0,
               "tac_operation" => %{
                 "operation_id" => operation_id,
                 "sender" => nil,
                 "status_history" => [
                   %{
                     "is_exist" => true,
                     "is_success" => true,
                     "note" => nil,
                     "timestamp" => "1746444308",
                     "transactions" => [
                       %{
                         "hash" => "0x5626d3aaf5f7666f0d82919178b0ba0880683e8531b6718a83ca946d337a81c9",
                         "type" => "TON"
                       }
                     ],
                     "type" => "COLLECTED_IN_TAC"
                   }
                 ],
                 "timestamp" => "1746444308",
                 "type" => "PENDING"
               },
               "type" => "tac_operation"
             } in tl(response)

      assert %{
               "priority" => 0,
               "transaction_hash" => "#{transaction.hash}",
               "type" => "transaction",
               "timestamp" => "#{transaction.block_timestamp}" |> String.replace(" ", "T"),
               "url" => "/tx/#{transaction.hash}"
             } in response
    end

    test "finds a TAC operation with block", %{conn: conn} do
      bypass = Bypass.open()
      tac_envs = Application.get_env(:explorer, Explorer.MicroserviceInterfaces.TACOperationLifecycle)

      Application.put_env(:explorer, Explorer.MicroserviceInterfaces.TACOperationLifecycle,
        service_url: "http://localhost:#{bypass.port}",
        enabled: true
      )

      on_exit(fn ->
        Bypass.down(bypass)
        Application.put_env(:explorer, Explorer.MicroserviceInterfaces.TACOperationLifecycle, tac_envs)
      end)

      transaction = insert(:transaction) |> with_block()

      operation_id = "#{transaction.block_hash}"

      tac_response = """
      {
          "operation_id": "#{operation_id}",
          "sender": null,
          "status_history": [
              {
                  "is_exist": true,
                  "is_success": true,
                  "note": null,
                  "timestamp": "1746444308",
                  "transactions": [
                      {
                          "hash": "0x5626d3aaf5f7666f0d82919178b0ba0880683e8531b6718a83ca946d337a81c9",
                          "type": "TON"
                      }
                  ],
                  "type": "COLLECTED_IN_TAC"
              }
          ],
          "timestamp": "1746444308",
          "type": "PENDING"
      }
      """

      Bypass.expect(
        bypass,
        "GET",
        "/api/v1/tac/operations/#{operation_id}",
        fn conn -> Plug.Conn.resp(conn, 200, tac_response) end
      )

      request = get(conn, "/api/v2/search/quick?q=#{operation_id}")
      assert response = json_response(request, 200)

      # tl to check order
      assert %{
               "priority" => 0,
               "tac_operation" => %{
                 "operation_id" => operation_id,
                 "sender" => nil,
                 "status_history" => [
                   %{
                     "is_exist" => true,
                     "is_success" => true,
                     "note" => nil,
                     "timestamp" => "1746444308",
                     "transactions" => [
                       %{
                         "hash" => "0x5626d3aaf5f7666f0d82919178b0ba0880683e8531b6718a83ca946d337a81c9",
                         "type" => "TON"
                       }
                     ],
                     "type" => "COLLECTED_IN_TAC"
                   }
                 ],
                 "timestamp" => "1746444308",
                 "type" => "PENDING"
               },
               "type" => "tac_operation"
             } in tl(response)

      assert %{
               "block_hash" => "#{transaction.block_hash}",
               "block_number" => transaction.block_number,
               "block_type" => "block",
               "priority" => 3,
               "type" => "block",
               "timestamp" => "#{transaction.block_timestamp}" |> String.replace(" ", "T"),
               "url" => "/block/#{transaction.block_hash}"
             } in response
    end

    test "returns empty list and don't crash", %{conn: conn} do
      request = get(conn, "/api/v2/search/quick?q=qwertyuioiuytrewertyuioiuytrertyuio")
      assert [] = json_response(request, 200)
    end
  end
end
