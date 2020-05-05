defmodule BlockScoutWeb.RecentTransactionsControllerTest do
  use BlockScoutWeb.ConnCase

  import BlockScoutWeb.WebRouter.Helpers, only: [recent_transactions_path: 2]

  alias Explorer.Chain.Hash

  describe "GET index/2" do
    test "returns a transaction", %{conn: conn} do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      conn =
        conn
        |> put_req_header("x-requested-with", "xmlhttprequest")
        |> get(recent_transactions_path(conn, :index))

      assert response = json_response(conn, 200)["transactions"]

      response_hashes = Enum.map(response, & &1["transaction_hash"])

      assert Enum.member?(response_hashes, Hash.to_string(transaction.hash))
    end

    test "only returns transactions with an associated block", %{conn: conn} do
      associated =
        :transaction
        |> insert()
        |> with_block()

      unassociated = insert(:transaction)

      conn =
        conn
        |> put_req_header("x-requested-with", "xmlhttprequest")
        |> get(recent_transactions_path(conn, :index))

      assert response = json_response(conn, 200)["transactions"]

      response_hashes = Enum.map(response, & &1["transaction_hash"])

      assert Enum.member?(response_hashes, Hash.to_string(associated.hash))
      refute Enum.member?(response_hashes, Hash.to_string(unassociated.hash))
    end

    test "only responds to ajax requests", %{conn: conn} do
      conn = get(conn, recent_transactions_path(conn, :index))

      assert conn.status == 422
    end
  end
end
