defmodule BlockScoutWeb.PendingTransactionControllerTest do
  use BlockScoutWeb.ConnCase
  alias Explorer.Chain.{Hash, Transaction}

  import BlockScoutWeb.Router.Helpers, only: [pending_transaction_path: 2]

  describe "GET index/2" do
    test "returns no transactions that are in a block", %{conn: conn} do
      :transaction
      |> insert()
      |> with_block()

      conn = get(conn, pending_transaction_path(BlockScoutWeb.Endpoint, :index))

      assert html_response(conn, 200)
      assert Enum.empty?(conn.assigns.transactions)
    end

    test "does not count transactions that have a block", %{conn: conn} do
      :transaction
      |> insert()
      |> with_block()

      conn = get(conn, pending_transaction_path(BlockScoutWeb.Endpoint, :index))

      assert html_response(conn, 200)
      assert Enum.empty?(conn.assigns.transactions)
    end

    test "returns pending transactions", %{conn: conn} do
      transaction = insert(:transaction)

      conn = get(conn, pending_transaction_path(BlockScoutWeb.Endpoint, :index))

      actual_transaction_hashes =
        conn.assigns.transactions
        |> Enum.map(fn transaction -> transaction.hash end)

      assert html_response(conn, 200)
      assert Enum.member?(actual_transaction_hashes, transaction.hash)
    end

    test "returns a count of pending transactions", %{conn: conn} do
      insert(:transaction)

      conn = get(conn, pending_transaction_path(BlockScoutWeb.Endpoint, :index))

      assert html_response(conn, 200)
      assert 1 == conn.assigns.pending_transaction_count
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

      {:ok, %{"pending_transactions" => pending_transactions}} = conn.resp_body |> Poison.decode()

      actual_hashes =
        pending_transactions
        |> Enum.map(& &1["transaction_hash"])
        |> Enum.reverse()

      assert second_page_hashes == actual_hashes
    end

    test "next_page_params exist if not on last page", %{conn: conn} do
      %Transaction{inserted_at: inserted_at, hash: hash} =
        60
        |> insert_list(:transaction)
        |> Enum.fetch!(10)

      converted_date = DateTime.to_iso8601(inserted_at)

      conn = get(conn, pending_transaction_path(BlockScoutWeb.Endpoint, :index))

      assert %{"inserted_at" => ^converted_date, "hash" => ^hash} = conn.assigns.next_page_params
    end

    test "next_page_params are empty if on last page", %{conn: conn} do
      insert(:transaction)

      conn = get(conn, pending_transaction_path(BlockScoutWeb.Endpoint, :index))

      refute conn.assigns.next_page_params
    end
  end
end
