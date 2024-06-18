defmodule BlockScoutWeb.BlockWithdrawalControllerTest do
  use BlockScoutWeb.ConnCase

  import BlockScoutWeb.Routers.WebRouter.Helpers, only: [block_withdrawal_path: 3]

  describe "GET index/2" do
    test "with invalid block number", %{conn: conn} do
      conn = get(conn, block_withdrawal_path(conn, :index, "unknown"))

      assert html_response(conn, 404)
    end

    test "with valid block number below the tip", %{conn: conn} do
      insert(:block, number: 666)

      conn = get(conn, block_withdrawal_path(conn, :index, "1"))

      assert html_response(conn, 404) =~ "This block has not been processed yet."
    end

    test "with valid block number above the tip", %{conn: conn} do
      block = insert(:block)

      conn = get(conn, block_withdrawal_path(conn, :index, block.number + 1))

      assert_block_above_tip(conn)
    end

    test "returns withdrawals for the block", %{conn: conn} do
      block = insert(:block, withdrawals: insert_list(3, :withdrawal))

      # to check that we can render a block overview
      get(conn, block_withdrawal_path(BlockScoutWeb.Endpoint, :index, block))
      conn = get(conn, block_withdrawal_path(BlockScoutWeb.Endpoint, :index, block), %{type: "JSON"})

      assert json_response(conn, 200)

      {:ok, %{"items" => items}} =
        conn.resp_body
        |> Poison.decode()

      assert Enum.count(items) == 3
    end

    test "non-consensus block number without consensus blocks is treated as consensus number above tip", %{conn: conn} do
      block = insert(:block, consensus: false)

      transaction = insert(:transaction)
      insert(:transaction_fork, hash: transaction.hash, uncle_hash: block.hash)

      conn = get(conn, block_withdrawal_path(conn, :index, block.number))

      assert_block_above_tip(conn)
    end

    test "non-consensus block number above consensus block number is treated as consensus number above tip", %{
      conn: conn
    } do
      consensus_block = insert(:block, consensus: true, number: 1)
      block = insert(:block, consensus: false, number: consensus_block.number + 1)

      transaction = insert(:transaction)
      insert(:transaction_fork, hash: transaction.hash, uncle_hash: block.hash)

      conn = get(conn, block_withdrawal_path(conn, :index, block.number))

      assert_block_above_tip(conn)
    end

    test "does not return transactions for invalid block hash", %{conn: conn} do
      conn = get(conn, block_withdrawal_path(conn, :index, "0x0"))

      assert html_response(conn, 404)
    end

    test "with valid not-indexed hash", %{conn: conn} do
      conn = get(conn, block_withdrawal_path(conn, :index, block_hash()))

      assert html_response(conn, 404) =~ "Block not found, please try again later."
    end

    test "does not return unrelated transactions", %{conn: conn} do
      insert(:withdrawal)
      block = insert(:block)

      conn = get(conn, block_withdrawal_path(BlockScoutWeb.Endpoint, :index, block), %{type: "JSON"})

      assert json_response(conn, 200)

      {:ok, %{"items" => items}} =
        conn.resp_body
        |> Poison.decode()

      assert Enum.empty?(items)
    end

    test "next_page_path exists if not on last page", %{conn: conn} do
      block = insert(:block, withdrawals: insert_list(60, :withdrawal))

      conn = get(conn, block_withdrawal_path(BlockScoutWeb.Endpoint, :index, block), %{type: "JSON"})

      {:ok, %{"next_page_path" => next_page_path}} =
        conn.resp_body
        |> Poison.decode()

      assert next_page_path
    end

    test "next_page_path is empty if on last page", %{conn: conn} do
      block = insert(:block, withdrawals: insert_list(1, :withdrawal))

      conn = get(conn, block_withdrawal_path(BlockScoutWeb.Endpoint, :index, block), %{type: "JSON"})

      {:ok, %{"next_page_path" => next_page_path}} =
        conn.resp_body
        |> Poison.decode()

      refute next_page_path
    end

    test "displays miner primary address name", %{conn: conn} do
      miner_name = "POA Miner Pool"
      %{address: miner_address} = insert(:address_name, name: miner_name, primary: true)

      block = insert(:block, miner: miner_address, miner_hash: nil)

      conn = get(conn, block_withdrawal_path(conn, :index, block))
      assert html_response(conn, 200) =~ miner_name
    end
  end

  defp assert_block_above_tip(conn) do
    assert conn
           |> html_response(404)
           |> Floki.find(~S|.error-descr|)
           |> Floki.text()
           |> String.trim() == "Easy Cowboy! This block does not exist yet!"
  end
end
