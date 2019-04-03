defmodule BlockScoutWeb.ChainControllerTest do
  use BlockScoutWeb.ConnCase,
    # ETS table is shared in `Explorer.Counters.AddressesWithBalanceCounter`
    async: false

  import BlockScoutWeb.Router.Helpers, only: [chain_path: 2, block_path: 3, transaction_path: 3, address_path: 3]

  alias Explorer.Chain.Block
  alias Explorer.Counters.AddressesWithBalanceCounter

  setup do
    start_supervised!(AddressesWithBalanceCounter)
    AddressesWithBalanceCounter.consolidate()

    :ok
  end

  describe "GET index/2" do
    test "returns a welcome message", %{conn: conn} do
      conn = get(conn, chain_path(BlockScoutWeb.Endpoint, :show))

      assert(html_response(conn, 200) =~ "POA")
    end

    test "returns a block" do
      insert(:block, %{number: 23})

      conn =
        build_conn()
        |> put_req_header("x-requested-with", "xmlhttprequest")
        |> get("/chain_blocks")

      response = json_response(conn, 200)

      assert(List.first(response["blocks"])["block_number"] == 23)
    end

    test "excludes all but the most recent five blocks" do
      old_block = insert(:block)
      insert_list(5, :block)

      conn =
        build_conn()
        |> put_req_header("x-requested-with", "xmlhttprequest")
        |> get("/chain_blocks")

      response = json_response(conn, 200)

      refute(Enum.member?(response["blocks"], old_block))
    end

    test "displays miner primary address names" do
      miner_name = "POA Miner Pool"
      %{address: miner_address} = insert(:address_name, name: miner_name, primary: true)

      insert(:block, miner: miner_address, miner_hash: nil)

      conn =
        build_conn()
        |> put_req_header("x-requested-with", "xmlhttprequest")
        |> get("/chain_blocks")

      response = List.first(json_response(conn, 200)["blocks"])

      assert response["chain_block_html"] =~ miner_name
    end
  end

  describe "GET token_autocomplete/2" do
    test "finds matching tokens" do
      insert(:token, name: "MaGiC")

      conn = get(conn(), "/token_autocomplete?q=magic")

      Enum.count(json_response(conn, 200)) == 1
    end
  end

  describe "GET search/2" do
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
