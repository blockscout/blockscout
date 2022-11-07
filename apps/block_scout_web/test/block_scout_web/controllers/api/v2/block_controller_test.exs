defmodule BlockScoutWeb.API.V2.BlockControllerTest do
  use BlockScoutWeb.ConnCase

  alias Explorer.Chain.{Address, Block, Transaction}

  setup do
    Supervisor.terminate_child(Explorer.Supervisor, Explorer.Chain.Cache.Blocks.child_id())
    Supervisor.restart_child(Explorer.Supervisor, Explorer.Chain.Cache.Blocks.child_id())
    Supervisor.terminate_child(Explorer.Supervisor, Explorer.Chain.Cache.Uncles.child_id())
    Supervisor.restart_child(Explorer.Supervisor, Explorer.Chain.Cache.Uncles.child_id())

    :ok
  end

  describe "/blocks" do
    test "empty lists", %{conn: conn} do
      request = get(conn, "/api/v2/blocks")
      assert response = json_response(request, 200)
      assert response["items"] == []
      assert response["next_page_params"] == nil

      request = get(conn, "/api/v2/blocks", %{"type" => "uncle"})
      assert response = json_response(request, 200)
      assert response["items"] == []
      assert response["next_page_params"] == nil

      request = get(conn, "/api/v2/blocks", %{"type" => "reorg"})
      assert response = json_response(request, 200)
      assert response["items"] == []
      assert response["next_page_params"] == nil

      request = get(conn, "/api/v2/blocks", %{"type" => "block"})
      assert response = json_response(request, 200)
      assert response["items"] == []
      assert response["next_page_params"] == nil
    end

    test "get block", %{conn: conn} do
      block = insert(:block)

      request = get(conn, "/api/v2/blocks")

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 1
      assert response["next_page_params"] == nil
      compare_item(block, Enum.at(response["items"], 0))
    end

    test "type=block returns only consensus blocks", %{conn: conn} do
      blocks =
        4
        |> insert_list(:block)
        |> Enum.reverse()

      for index <- 0..3 do
        uncle = insert(:block, consensus: false)
        insert(:block_second_degree_relation, uncle_hash: uncle.hash, nephew: Enum.at(blocks, index))
      end

      2
      |> insert_list(:block, consensus: false)

      request = get(conn, "/api/v2/blocks", %{"type" => "block"})

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 4
      assert response["next_page_params"] == nil

      for index <- 0..3 do
        compare_item(Enum.at(blocks, index), Enum.at(response["items"], index))
      end
    end

    test "type=block can paginate", %{conn: conn} do
      blocks =
        51
        |> insert_list(:block)

      filter = %{"type" => "block"}

      request = get(conn, "/api/v2/blocks", filter)
      assert response = json_response(request, 200)

      request_2nd_page = get(conn, "/api/v2/blocks", Map.merge(response["next_page_params"], filter))

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, blocks)
    end

    test "type=reorg returns only non consensus blocks", %{conn: conn} do
      blocks =
        5
        |> insert_list(:block)

      for index <- 0..3 do
        uncle = insert(:block, consensus: false)
        insert(:block_second_degree_relation, uncle_hash: uncle.hash, nephew: Enum.at(blocks, index))
      end

      reorgs =
        4
        |> insert_list(:block, consensus: false)
        |> Enum.reverse()

      request = get(conn, "/api/v2/blocks", %{"type" => "reorg"})

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 4
      assert response["next_page_params"] == nil

      for index <- 0..3 do
        compare_item(Enum.at(reorgs, index), Enum.at(response["items"], index))
      end
    end

    test "type=reorg can paginate", %{conn: conn} do
      reorgs =
        51
        |> insert_list(:block, consensus: false)

      filter = %{"type" => "reorg"}
      request = get(conn, "/api/v2/blocks", filter)
      assert response = json_response(request, 200)

      request_2nd_page = get(conn, "/api/v2/blocks", Map.merge(response["next_page_params"], filter))

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, reorgs)
    end

    test "type=uncle returns only uncle blocks", %{conn: conn} do
      blocks =
        4
        |> insert_list(:block)
        |> Enum.reverse()

      uncles =
        for index <- 0..3 do
          uncle = insert(:block, consensus: false)
          insert(:block_second_degree_relation, uncle_hash: uncle.hash, nephew: Enum.at(blocks, index))
          uncle
        end
        |> Enum.reverse()

      4
      |> insert_list(:block, consensus: false)

      request = get(conn, "/api/v2/blocks", %{"type" => "uncle"})

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 4
      assert response["next_page_params"] == nil

      for index <- 0..3 do
        compare_item(Enum.at(uncles, index), Enum.at(response["items"], index))
      end
    end

    test "type=uncle can paginate", %{conn: conn} do
      blocks =
        51
        |> insert_list(:block)

      uncles =
        for index <- 0..50 do
          uncle = insert(:block, consensus: false)
          insert(:block_second_degree_relation, uncle_hash: uncle.hash, nephew: Enum.at(blocks, index))
          uncle
        end

      filter = %{"type" => "uncle"}
      request = get(conn, "/api/v2/blocks", filter)
      assert response = json_response(request, 200)

      request_2nd_page = get(conn, "/api/v2/blocks", Map.merge(response["next_page_params"], filter))

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, uncles)
    end
  end

  describe "/blocks/{block_hash_or_number}" do
    test "return 422 on invalid parameter", %{conn: conn} do
      request_1 = get(conn, "/api/v2/blocks/0x123123")
      assert %{"message" => "Invalid hash"} = json_response(request_1, 422)

      request_2 = get(conn, "/api/v2/blocks/123qwe")
      assert %{"message" => "Invalid number"} = json_response(request_2, 422)
    end

    test "return 404 on non existing block", %{conn: conn} do
      block = build(:block)

      request_1 = get(conn, "/api/v2/blocks/#{block.number}")
      assert %{"message" => "Not found"} = json_response(request_1, 404)

      request_2 = get(conn, "/api/v2/blocks/#{block.hash}")
      assert %{"message" => "Not found"} = json_response(request_2, 404)
    end

    test "get the same blocks by hash and number", %{conn: conn} do
      block = insert(:block)

      request_1 = get(conn, "/api/v2/blocks/#{block.number}")
      assert response_1 = json_response(request_1, 200)

      request_2 = get(conn, "/api/v2/blocks/#{block.hash}")
      assert response_2 = json_response(request_2, 200)

      assert response_2 == response_1
      compare_item(block, response_2)
    end
  end

  describe "/blocks/{block_hash_or_number}/transactions" do
    test "return 422 on invalid parameter", %{conn: conn} do
      request_1 = get(conn, "/api/v2/blocks/0x123123/transactions")
      assert %{"message" => "Invalid hash"} = json_response(request_1, 422)

      request_2 = get(conn, "/api/v2/blocks/123qwe/transactions")
      assert %{"message" => "Invalid number"} = json_response(request_2, 422)
    end

    test "return 404 on non existing block", %{conn: conn} do
      block = build(:block)

      request_1 = get(conn, "/api/v2/blocks/#{block.number}/transactions")
      assert %{"message" => "Not found"} = json_response(request_1, 404)

      request_2 = get(conn, "/api/v2/blocks/#{block.hash}/transactions")
      assert %{"message" => "Not found"} = json_response(request_2, 404)
    end

    test "get empty list", %{conn: conn} do
      block = insert(:block)

      request = get(conn, "/api/v2/blocks/#{block.number}/transactions")
      assert response = json_response(request, 200)
      assert response["items"] == []
      assert response["next_page_params"] == nil

      request = get(conn, "/api/v2/blocks/#{block.hash}/transactions")
      assert response = json_response(request, 200)
      assert response["items"] == []
      assert response["next_page_params"] == nil
    end

    test "get relevant tx", %{conn: conn} do
      10
      |> insert_list(:transaction)
      |> with_block()

      block = insert(:block)

      tx =
        :transaction
        |> insert()
        |> with_block(block)

      request = get(conn, "/api/v2/blocks/#{block.number}/transactions")
      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 1
      assert response["next_page_params"] == nil
      compare_item(tx, Enum.at(response["items"], 0))

      request = get(conn, "/api/v2/blocks/#{block.hash}/transactions")
      assert response_1 = json_response(request, 200)
      assert response_1 == response
    end

    test "get txs with working next_page_params", %{conn: conn} do
      2
      |> insert_list(:transaction)
      |> with_block()

      block = insert(:block)

      txs =
        51
        |> insert_list(:transaction)
        |> with_block(block)
        |> Enum.reverse()

      request = get(conn, "/api/v2/blocks/#{block.number}/transactions")
      assert response = json_response(request, 200)

      request_2nd_page = get(conn, "/api/v2/blocks/#{block.number}/transactions", response["next_page_params"])
      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, txs)

      request_1 = get(conn, "/api/v2/blocks/#{block.hash}/transactions")
      assert response_1 = json_response(request_1, 200)

      response_1 =
        Map.replace(
          response_1,
          "next_page_params",
          Map.replace(response_1["next_page_params"], "block_hash_or_number", to_string(block.number))
        )

      assert response_1 == response

      request_2 = get(conn, "/api/v2/blocks/#{block.hash}/transactions", response_1["next_page_params"])
      assert response_2 = json_response(request_2, 200)
      assert response_2 == response_2nd_page
    end
  end

  def compare_item(%Block{} = block, json) do
    assert to_string(block.hash) == json["hash"]
    assert block.number == json["height"]
  end

  def compare_item(%Transaction{} = transaction, json) do
    assert to_string(transaction.hash) == json["hash"]
    assert transaction.block_number == json["block"]
    assert to_string(transaction.value.value) == json["value"]
    assert Address.checksum(transaction.from_address_hash) == json["from"]["hash"]
    assert Address.checksum(transaction.to_address_hash) == json["to"]["hash"]
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
