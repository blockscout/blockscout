defmodule BlockScoutWeb.ChainControllerTest do
  use BlockScoutWeb.ConnCase

  import BlockScoutWeb.Router.Helpers, only: [chain_path: 2, block_path: 3, transaction_path: 3, address_path: 3]

  alias Explorer.Chain.Block

  describe "GET index/2" do
    test "returns a welcome message", %{conn: conn} do
      conn = get(conn, chain_path(BlockScoutWeb.Endpoint, :show))

      assert(html_response(conn, 200) =~ "POA")
    end

    test "returns a block", %{conn: conn} do
      insert(:block, %{number: 23})
      conn = get(conn, "/")

      assert(List.first(conn.assigns.blocks).number == 23)
    end

    test "excludes all but the most recent five blocks", %{conn: conn} do
      old_block = insert(:block)
      insert_list(5, :block)
      conn = get(conn, "/")

      refute(Enum.member?(conn.assigns.blocks, old_block))
    end

    test "only returns transactions with an associated block", %{conn: conn} do
      associated =
        :transaction
        |> insert()
        |> with_block()

      unassociated = insert(:transaction)

      conn = get(conn, "/")

      transaction_hashes = Enum.map(conn.assigns.transactions, fn transaction -> transaction.hash end)

      assert(Enum.member?(transaction_hashes, associated.hash))
      refute(Enum.member?(transaction_hashes, unassociated.hash))
    end

    test "returns a transaction", %{conn: conn} do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      conn = get(conn, "/")

      assert(List.first(conn.assigns.transactions).hash == transaction.hash)
    end

    test "returns market history data", %{conn: conn} do
      today = Date.utc_today()
      for day <- -40..0, do: insert(:market_history, date: Date.add(today, day))

      conn = get(conn, "/")

      assert Map.has_key?(conn.assigns, :market_history_data)
      assert length(conn.assigns.market_history_data) == 30
    end
  end

  describe "GET q/2" do
    test "finds a consensus block by block number", %{conn: conn} do
      insert(:block, number: 37)
      conn = get(conn, "/search?q=37")

      assert redirected_to(conn) == block_path(conn, :show, "37")
    end

    test "does not find non-consensus block by number", %{conn: conn} do
      %Block{number: number} = insert(:block, consensus: false)

      conn = get(conn, "/search?q=#{number}")

      assert conn.status == 404
    end

    test "finds non-consensus block by hash", %{conn: conn} do
      %Block{hash: hash} = insert(:block, consensus: false)

      conn = get(conn, "/search?q=#{hash}")

      assert redirected_to(conn) == block_path(conn, :show, hash)
    end

    test "finds a transaction by hash", %{conn: conn} do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      conn = get(conn, "/search?q=#{to_string(transaction.hash)}")

      assert redirected_to(conn) == transaction_path(conn, :show, transaction)
    end

    test "finds an address by hash", %{conn: conn} do
      address = insert(:address)
      conn = get(conn, "search?q=#{to_string(address.hash)}")

      assert redirected_to(conn) == address_path(conn, :show, address)
    end

    test "finds an address by hash when there are extra spaces", %{conn: conn} do
      address = insert(:address)
      conn = get(conn, "search?q=#{to_string(address.hash)}")

      assert redirected_to(conn) == address_path(conn, :show, address)
    end

    test "redirects to 404 when it finds nothing", %{conn: conn} do
      conn = get(conn, "search?q=zaphod")
      assert conn.status == 404
    end
  end
end
