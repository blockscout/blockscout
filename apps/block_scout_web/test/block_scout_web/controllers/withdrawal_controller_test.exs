defmodule BlockScoutWeb.WithdrawalControllerTest do
  use BlockScoutWeb.ConnCase

  import BlockScoutWeb.WebRouter.Helpers, only: [withdrawal_path: 2, withdrawal_path: 3]

  alias Explorer.Chain.Withdrawal

  describe "GET index/2" do
    test "returns all withdrawals", %{conn: conn} do
      insert_list(4, :withdrawal)

      conn = get(conn, withdrawal_path(conn, :index), %{"type" => "JSON"})

      items = Map.get(json_response(conn, 200), "items")

      assert length(items) == 4
    end

    test "returns next page of results based on last withdrawal", %{conn: conn} do
      insert_list(50, :withdrawal)

      withdrawal = insert(:withdrawal)

      conn =
        get(conn, withdrawal_path(conn, :index), %{
          "type" => "JSON",
          "index" => Integer.to_string(withdrawal.index)
        })

      items = Map.get(json_response(conn, 200), "items")

      assert length(items) == 50
    end

    test "next_page_path exist if not on last page", %{conn: conn} do
      %Withdrawal{index: index} =
        60
        |> insert_list(:withdrawal)
        |> Enum.fetch!(10)

      conn = get(conn, withdrawal_path(conn, :index), %{"type" => "JSON"})

      expected_path =
        withdrawal_path(conn, :index, %{
          index: index,
          items_count: "50"
        })

      assert Map.get(json_response(conn, 200), "next_page_path") == expected_path
    end

    test "next_page_path is empty if on last page", %{conn: conn} do
      insert(:withdrawal)

      conn = get(conn, withdrawal_path(conn, :index), %{"type" => "JSON"})

      refute conn |> json_response(200) |> Map.get("next_page_path")
    end
  end
end
