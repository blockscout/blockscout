defmodule BlockScoutWeb.ChainControllerTest do
  use BlockScoutWeb.ConnCase,
    # ETS table is shared in `Explorer.Chain.Cache.Counters.AddressesCount`
    async: false

  import BlockScoutWeb.Routers.WebRouter.Helpers,
    only: [chain_path: 2, block_path: 3, transaction_path: 3, address_path: 3]

  alias Explorer.Chain.Block
  alias Explorer.Chain.Cache.Counters.AddressesCount

  setup do
    Supervisor.terminate_child(Explorer.Supervisor, Explorer.Chain.Cache.Blocks.child_id())
    Supervisor.restart_child(Explorer.Supervisor, Explorer.Chain.Cache.Blocks.child_id())
    Supervisor.terminate_child(Explorer.Supervisor, Explorer.Chain.Cache.Uncles.child_id())
    Supervisor.restart_child(Explorer.Supervisor, Explorer.Chain.Cache.Uncles.child_id())
    start_supervised!(AddressesCount)
    AddressesCount.consolidate()

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
        |> get("/chain-blocks")

      response = json_response(conn, 200)

      assert(List.first(response["blocks"])["block_number"] == 23)
    end

    test "excludes all but the most recent five blocks" do
      old_block = insert(:block)
      insert_list(5, :block)

      conn =
        build_conn()
        |> put_req_header("x-requested-with", "xmlhttprequest")
        |> get("/chain-blocks")

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
        |> get("/chain-blocks")

      response = List.first(json_response(conn, 200)["blocks"])

      assert response["chain_block_html"] =~ miner_name
    end
  end

  describe "GET token_autocomplete/2" do
    test "finds matching tokens" do
      insert(:token, name: "MaGiC")
      insert(:token, name: "Evil")

      conn =
        build_conn()
        |> get("/token-autocomplete?q=magic")

      assert Enum.count(json_response(conn, 200)) == 1
    end

    test "finds two matching tokens" do
      insert(:token, name: "MaGiC")
      insert(:token, name: "magic")

      conn =
        build_conn()
        |> get("/token-autocomplete?q=magic")

      assert Enum.count(json_response(conn, 200)) == 2
    end

    test "finds verified contract" do
      insert(:smart_contract, name: "SuperToken", contract_code_md5: "123")

      conn =
        build_conn()
        |> get("/token-autocomplete?q=sup")

      assert Enum.count(json_response(conn, 200)) == 1
    end

    test "finds verified contract and token" do
      insert(:smart_contract, name: "MagicContract", contract_code_md5: "123")
      insert(:token, name: "magicToken")

      conn =
        build_conn()
        |> get("/token-autocomplete?q=mag")

      assert Enum.count(json_response(conn, 200)) == 2
    end

    test "finds verified contracts and tokens" do
      insert(:smart_contract, name: "something", contract_code_md5: "123")
      insert(:smart_contract, name: "MagicContract", contract_code_md5: "123")
      insert(:token, name: "Magic3")
      insert(:smart_contract, name: "magicContract2", contract_code_md5: "123")
      insert(:token, name: "magicToken")
      insert(:token, name: "OneMoreToken")

      conn =
        build_conn()
        |> get("/token-autocomplete?q=mag")

      assert Enum.count(json_response(conn, 200)) == 4
    end

    test "find by several words" do
      insert(:token, name: "first Token")
      insert(:token, name: "second Token")

      conn =
        build_conn()
        |> get("/token-autocomplete?q=fir+tok")

      assert Enum.count(json_response(conn, 200)) == 1
    end

    test "find by empty query" do
      insert(:token, name: "MaGiCt0k3n")
      insert(:smart_contract, name: "MagicContract", contract_code_md5: "123")

      conn =
        build_conn()
        |> get("/token-autocomplete?q=")

      assert Enum.count(json_response(conn, 200)) == 0
    end

    test "find by non-latin characters" do
      insert(:token, name: "someToken")

      conn =
        build_conn()
        |> get("/token-autocomplete?q=%E0%B8%B5%E0%B8%AB")

      assert Enum.count(json_response(conn, 200)) == 0
    end
  end

  describe "GET search/2" do
    test "finds a consensus block by block number", %{conn: conn} do
      insert(:block, number: 37)
      conn = get(conn, "/search?q=37")

      assert redirected_to(conn) == block_path(conn, :show, "37")
    end

    test "redirects to search results page even for  searching non-consensus block by number", %{conn: conn} do
      %Block{number: number} = insert(:block, consensus: false)

      conn = get(conn, "/search?q=#{number}")

      assert conn.status == 302
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

      conn = get(conn, "/search?q=#{to_string(non_prefix_hash)}")

      assert redirected_to(conn) == transaction_path(conn, :show, transaction)
    end

    test "finds an address by hash", %{conn: conn} do
      address = insert(:address)
      conn = get(conn, "/search?q=#{to_string(address.hash)}")

      assert redirected_to(conn) == address_path(conn, :show, address)
    end

    test "finds an address by hash when there are extra spaces", %{conn: conn} do
      address = insert(:address)
      conn = get(conn, "/search?q=#{to_string(address.hash)}")

      assert redirected_to(conn) == address_path(conn, :show, address)
    end

    test "finds an address by hash when there are not 0x prefix", %{conn: conn} do
      address = insert(:address)
      "0x" <> non_prefix_hash = to_string(address.hash)

      conn = get(conn, "/search?q=#{to_string(non_prefix_hash)}")

      assert redirected_to(conn) == address_path(conn, :show, address)
    end

    test "redirects to result page when it finds nothing", %{conn: conn} do
      conn = get(conn, "/search?q=zaphod")
      assert conn.status == 302
    end
  end
end
