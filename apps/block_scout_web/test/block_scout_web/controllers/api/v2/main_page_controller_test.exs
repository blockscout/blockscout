defmodule BlockScoutWeb.API.V2.MainPageControllerTest do
  use BlockScoutWeb.ConnCase

  alias Explorer.Chain.{Address, Block, Transaction}

  setup do
    Supervisor.terminate_child(Explorer.Supervisor, Explorer.Chain.Cache.Blocks.child_id())
    Supervisor.restart_child(Explorer.Supervisor, Explorer.Chain.Cache.Blocks.child_id())
    Supervisor.terminate_child(Explorer.Supervisor, Explorer.Chain.Cache.TransactionsApiV2.child_id())
    Supervisor.restart_child(Explorer.Supervisor, Explorer.Chain.Cache.TransactionsApiV2.child_id())

    :ok
  end

  describe "/main-page/blocks" do
    test "get empty list when no blocks", %{conn: conn} do
      request = get(conn, "/api/v2/main-page/blocks")
      assert [] = json_response(request, 200)
    end

    test "get last 4 blocks", %{conn: conn} do
      blocks = insert_list(10, :block) |> Enum.take(-4) |> Enum.reverse()

      request = get(conn, "/api/v2/main-page/blocks")
      assert response = json_response(request, 200)
      assert Enum.count(response) == 4

      for i <- 0..3 do
        compare_item(Enum.at(blocks, i), Enum.at(response, i))
      end
    end
  end

  describe "/main-page/transactions" do
    test "get empty list when no txs", %{conn: conn} do
      request = get(conn, "/api/v2/main-page/transactions")
      assert [] = json_response(request, 200)
    end

    test "get last 5 txs", %{conn: conn} do
      txs = insert_list(10, :transaction) |> with_block() |> Enum.take(-6) |> Enum.reverse()

      request = get(conn, "/api/v2/main-page/transactions")
      assert response = json_response(request, 200)
      assert Enum.count(response) == 6

      for i <- 0..5 do
        compare_item(Enum.at(txs, i), Enum.at(response, i))
      end
    end
  end

  describe "/main-page/indexing-status" do
    test "get indexing status", %{conn: conn} do
      request = get(conn, "/api/v2/main-page/indexing-status")
      assert request = json_response(request, 200)

      assert Map.has_key?(request, "finished_indexing_blocks")
      assert Map.has_key?(request, "finished_indexing")
      assert Map.has_key?(request, "indexed_blocks_ratio")
      assert Map.has_key?(request, "indexed_internal_transactions_ratio")
    end
  end

  defp compare_item(%Block{} = block, json) do
    assert to_string(block.hash) == json["hash"]
    assert block.number == json["height"]
  end

  defp compare_item(%Transaction{} = transaction, json) do
    assert to_string(transaction.hash) == json["hash"]
    assert transaction.block_number == json["block"]
    assert to_string(transaction.value.value) == json["value"]
    assert Address.checksum(transaction.from_address_hash) == json["from"]["hash"]
    assert Address.checksum(transaction.to_address_hash) == json["to"]["hash"]
  end
end
