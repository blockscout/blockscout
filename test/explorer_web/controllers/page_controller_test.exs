defmodule ExplorerWeb.PageControllerTest do
  use ExplorerWeb.ConnCase

  describe "GET index/2 without a locale" do
    test "redirects to the en locale", %{conn: conn} do
      conn = get conn, "/"
      assert redirected_to(conn) == "/en"
    end
  end

  describe "GET index/2 with a locale" do
    test "returns a welcome message", %{conn: conn} do
      conn = get conn, "/en"
      assert html_response(conn, 200) =~ "POA"
    end

    test "returns a block", %{conn: conn} do
      insert(:block, %{number: 23})
      conn = get conn, "/en"
      assert(List.first(conn.assigns.blocks).number == 23)
    end

    test "excludes all but the most recent five blocks", %{conn: conn} do
      old_block = insert(:block)
      insert_list(5, :block)
      conn = get conn, "/en"
      refute(Enum.member?(conn.assigns.blocks, old_block))
    end

    test "returns a transaction", %{conn: conn} do
      block = insert(:block, number: 33)
      insert(:transaction, hash: "0xDECAFBAD", block: block)
      conn = get conn, "/en"

      assert(List.first(conn.assigns.transactions).hash == "0xDECAFBAD")
      assert(List.first(conn.assigns.transactions).block.number == 33)
    end

    test "returns only the five most recent transactions", %{conn: conn} do
      block_mined_today = insert(:block, timestamp: Timex.now |> Timex.shift(hours: -1))
      insert(:transaction, hash: "0xStuff", inserted_at: Timex.now |> Timex.shift(hours: -1), block: block_mined_today)

      block_mined_last_week = insert(:block, timestamp: Timex.now |> Timex.shift(weeks: -1))
      insert_list(5, :transaction, block: block_mined_last_week)

      conn = get conn, "/en"

      assert Enum.count(conn.assigns.transactions) == 5
      assert List.first(conn.assigns.transactions).hash == "0xStuff"
    end
  end
end
