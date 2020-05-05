defmodule BlockScoutWeb.PendingTransactionControllerTest do
  use BlockScoutWeb.ConnCase
  alias Explorer.Chain.{Hash, Transaction}

  import BlockScoutWeb.WebRouter.Helpers, only: [pending_transaction_path: 2, pending_transaction_path: 3]

  describe "GET index/2" do
    test "returns no transactions that are in a block", %{conn: conn} do
      :transaction
      |> insert()
      |> with_block()

      conn = get(conn, pending_transaction_path(BlockScoutWeb.Endpoint, :index, %{"type" => "JSON"}))

      assert conn |> json_response(200) |> Map.get("items") |> Enum.empty?()
    end

    test "returns pending transactions", %{conn: conn} do
      transaction = insert(:transaction)

      conn = get(conn, pending_transaction_path(BlockScoutWeb.Endpoint, :index, %{"type" => "JSON"}))

      assert hd(json_response(conn, 200)["items"]) =~ to_string(transaction.hash)
    end

    test "does not show dropped/replaced transactions", %{conn: conn} do
      transaction = insert(:transaction)

      dropped_replaced =
        :transaction
        |> insert(status: 0, error: "dropped/replaced")
        |> with_block()

      conn = get(conn, pending_transaction_path(BlockScoutWeb.Endpoint, :index, %{"type" => "JSON"}))

      assert hd(json_response(conn, 200)["items"]) =~ to_string(transaction.hash)
      refute hd(json_response(conn, 200)["items"]) =~ to_string(dropped_replaced.hash)
    end

    test "works when there are no transactions", %{conn: conn} do
      conn = get(conn, pending_transaction_path(conn, :index))

      assert html_response(conn, 200)
    end

    test "returns next page of results based on last seen pending transaction", %{conn: conn} do
      second_page_hashes =
        50
        |> insert_list(:transaction)
        |> Enum.map(&to_string(&1.hash))

      %Transaction{inserted_at: inserted_at, hash: hash} = insert(:transaction)

      conn =
        get(conn, pending_transaction_path(BlockScoutWeb.Endpoint, :index), %{
          "type" => "JSON",
          "inserted_at" => DateTime.to_iso8601(inserted_at),
          "hash" => Hash.to_string(hash)
        })

      {:ok, %{"items" => pending_transactions}} = Poison.decode(conn.resp_body)

      assert length(pending_transactions) == length(second_page_hashes)
    end

    test "next_page_path exist if not on last page", %{conn: conn} do
      60
      |> insert_list(:transaction)
      |> Enum.fetch!(10)

      conn = get(conn, pending_transaction_path(BlockScoutWeb.Endpoint, :index, %{"type" => "JSON"}))

      assert json_response(conn, 200)["next_page_path"]
    end

    test "next_page_path is empty if on last page", %{conn: conn} do
      insert(:transaction)

      conn = get(conn, pending_transaction_path(BlockScoutWeb.Endpoint, :index, %{"type" => "JSON"}))

      refute json_response(conn, 200)["next_page_path"]
    end
  end
end
