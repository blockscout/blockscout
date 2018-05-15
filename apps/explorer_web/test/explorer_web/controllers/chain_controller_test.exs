defmodule ExplorerWeb.ChainControllerTest do
  use ExplorerWeb.ConnCase

  import ExplorerWeb.Router.Helpers, only: [chain_path: 3, block_path: 4, transaction_path: 4, address_path: 4]

  describe "GET index/2 without a locale" do
    test "redirects to the en locale", %{conn: conn} do
      conn = get(conn, "/")

      assert(redirected_to(conn) == "/en")
    end
  end

  describe "GET index/2 with a locale" do
    test "returns a welcome message", %{conn: conn} do
      conn = get(conn, chain_path(ExplorerWeb.Endpoint, :show, %{locale: :en}))

      assert(html_response(conn, 200) =~ "POA")
    end

    test "returns a block", %{conn: conn} do
      insert(:block, %{number: 23})
      conn = get(conn, "/en")

      assert(List.first(conn.assigns.chain.blocks).number == 23)
    end

    test "excludes all but the most recent five blocks", %{conn: conn} do
      old_block = insert(:block)
      insert_list(5, :block)
      conn = get(conn, "/en")

      refute(Enum.member?(conn.assigns.chain.blocks, old_block))
    end

    test "only returns transactions with an associated block", %{conn: conn} do
      block = insert(:block, number: 33)

      associated = insert(:transaction, block_hash: block.hash, index: 0)
      unassociated = insert(:transaction)

      conn = get(conn, "/en")

      transaction_hashes = Enum.map(conn.assigns.chain.transactions, fn transaction -> transaction.hash end)

      assert(Enum.member?(transaction_hashes, associated.hash))
      refute(Enum.member?(transaction_hashes, unassociated.hash))
    end

    test "returns a transaction", %{conn: conn} do
      block = insert(:block, number: 33)

      transaction = insert(:transaction, block_hash: block.hash, index: 0)

      conn = get(conn, "/en")

      assert(List.first(conn.assigns.chain.transactions).hash == transaction.hash)
    end

    test "returns market history data", %{conn: conn} do
      today = Date.utc_today()
      for day <- -40..0, do: insert(:market_history, date: Date.add(today, day))

      conn = get(conn, "/en")

      assert Map.has_key?(conn.assigns, :market_history_data)
      assert length(conn.assigns.market_history_data) == 30
    end
  end

  describe "GET q/2" do
    test "finds a block by block number", %{conn: conn} do
      insert(:block, number: 37)
      conn = get(conn, "/en/search?q=37")

      assert redirected_to(conn) == block_path(conn, :show, "en", "37")
    end

    test "finds a transaction by hash", %{conn: conn} do
      block = insert(:block)
      transaction = insert(:transaction, block_hash: block.hash, index: 0)
      conn = get(conn, "/en/search?q=#{to_string(transaction.hash)}")

      assert redirected_to(conn) == transaction_path(conn, :show, "en", transaction)
    end

    test "finds an address by hash", %{conn: conn} do
      address = insert(:address)
      conn = get(conn, "en/search?q=#{to_string(address.hash)}")

      assert redirected_to(conn) == address_path(conn, :show, "en", address)
    end

    test "finds an address by hash when there are extra spaces", %{conn: conn} do
      address = insert(:address)
      conn = get(conn, "en/search?q=#{to_string(address.hash)}    ")

      assert redirected_to(conn) == address_path(conn, :show, "en", address)
    end

    test "redirects to 404 when it finds nothing", %{conn: conn} do
      conn = get(conn, "en/search?q=zaphod")
      assert conn.status == 404
    end
  end
end
