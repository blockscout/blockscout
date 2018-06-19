defmodule ExplorerWeb.TransactionControllerTest do
  use ExplorerWeb.ConnCase
  alias Explorer.Chain.{Block, Transaction}

  import ExplorerWeb.Router.Helpers, only: [transaction_path: 4, transaction_internal_transaction_path: 4]

  describe "GET index/2" do
    test "returns a collated transactions", %{conn: conn} do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      conn = get(conn, "/en/transactions")

      assert List.first(conn.assigns.transactions).hash == transaction.hash
    end

    test "returns a count of transactions", %{conn: conn} do
      :transaction
      |> insert()
      |> with_block()

      conn = get(conn, "/en/transactions")

      assert is_integer(conn.assigns.transaction_estimated_count)
    end

    test "excludes pending transactions", %{conn: conn} do
      %Transaction{hash: hash} =
        :transaction
        |> insert()
        |> with_block()

      insert(:transaction)

      conn = get(conn, "/en/transactions")

      assert [%Transaction{hash: ^hash}] = conn.assigns.transactions
    end

    test "returns next page of results based on last seen transaction", %{conn: conn} do
      second_page_hashes =
        50
        |> insert_list(:transaction)
        |> with_block()
        |> Enum.map(& &1.hash)

      %Transaction{block_number: block_number, index: index} =
        :transaction
        |> insert()
        |> with_block()

      conn =
        get(conn, "/en/transactions", %{
          "block_number" => Integer.to_string(block_number),
          "index" => Integer.to_string(index)
        })

      actual_hashes =
        conn.assigns.transactions
        |> Enum.map(& &1.hash)
        |> Enum.reverse()

      assert second_page_hashes == actual_hashes
    end

    test "next_page_params exist if not on last page", %{conn: conn} do
      address = insert(:address)
      block = %Block{number: number} = insert(:block)

      60
      |> insert_list(:transaction, from_address: address)
      |> with_block(block)

      conn = get(conn, "/en/transactions")

      assert %{block_number: ^number, index: 10} = conn.assigns.next_page_params
    end

    test "next_page_params are empty if on last page", %{conn: conn} do
      address = insert(:address)

      :transaction
      |> insert(from_address: address)
      |> with_block()

      conn = get(conn, "/en/transactions")

      refute conn.assigns.next_page_params
    end

    test "works when there are no transactions", %{conn: conn} do
      conn = get(conn, "/en/transactions")

      assert conn.assigns.transactions == []
    end
  end

  describe "GET show/3" do
    test "redirects to transactions/:transaction_id/internal_transactions", %{conn: conn} do
      locale = "en"
      hash = "0x9"
      conn = get(conn, transaction_path(ExplorerWeb.Endpoint, :show, locale, hash))

      assert redirected_to(conn) =~ transaction_internal_transaction_path(ExplorerWeb.Endpoint, :index, locale, hash)
    end
  end
end
