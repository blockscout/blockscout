defmodule BlockScoutWeb.ChainControllerTest do
  use BlockScoutWeb.ConnCase,
    # ETS table is shared in `Explorer.Counters.AddressesCounter`
    async: false

  import BlockScoutWeb.WebRouter.Helpers, only: [chain_path: 2, block_path: 3, transaction_path: 3, address_path: 3]

  alias Explorer.Chain.Block
  alias Explorer.Counters.AddressesCounter

  setup do
    Supervisor.terminate_child(Explorer.Supervisor, Explorer.Chain.Cache.Blocks.child_id())
    Supervisor.restart_child(Explorer.Supervisor, Explorer.Chain.Cache.Blocks.child_id())
    Supervisor.terminate_child(Explorer.Supervisor, Explorer.Chain.Cache.Uncles.child_id())
    Supervisor.restart_child(Explorer.Supervisor, Explorer.Chain.Cache.Uncles.child_id())
    start_supervised!(AddressesCounter)
    AddressesCounter.consolidate()

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
      insert(:token, name: "Evil")

      conn = get(conn(), "/token_autocomplete?q=magic")

      assert Enum.count(json_response(conn, 200)) == 1
    end

    test "finds two matching tokens" do
      insert(:token, name: "MaGiC")
      insert(:token, name: "magic")

      conn = get(conn(), "/token_autocomplete?q=magic")

      assert Enum.count(json_response(conn, 200)) == 2
    end

    test "finds verified contract" do
      insert(:smart_contract, name: "SuperToken")

      conn = get(conn(), "/token_autocomplete?q=sup")

      assert Enum.count(json_response(conn, 200)) == 1
    end

    test "finds verified contract and token" do
      insert(:smart_contract, name: "MagicContract")
      insert(:token, name: "magicToken")

      conn = get(conn(), "/token_autocomplete?q=mag")

      assert Enum.count(json_response(conn, 200)) == 2
    end

    test "finds verified contracts and tokens" do
      insert(:smart_contract, name: "something")
      insert(:smart_contract, name: "MagicContract")
      insert(:token, name: "Magic3")
      insert(:smart_contract, name: "magicContract2")
      insert(:token, name: "magicToken")
      insert(:token, name: "OneMoreToken")

      conn = get(conn(), "/token_autocomplete?q=mag")

      assert Enum.count(json_response(conn, 200)) == 4
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

    test "finds a transaction by hash when there are not 0x prefix", %{conn: conn} do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      "0x" <> non_prefix_hash = to_string(transaction.hash)

      conn = get(conn, "search?q=#{to_string(non_prefix_hash)}")

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

    test "finds an address by hash when there are not 0x prefix", %{conn: conn} do
      address = insert(:address)
      "0x" <> non_prefix_hash = to_string(address.hash)

      conn = get(conn, "search?q=#{to_string(non_prefix_hash)}")

      assert redirected_to(conn) == address_path(conn, :show, address)
    end

    test "redirects to 404 when it finds nothing", %{conn: conn} do
      conn = get(conn, "search?q=zaphod")
      assert conn.status == 404
    end
  end
end
