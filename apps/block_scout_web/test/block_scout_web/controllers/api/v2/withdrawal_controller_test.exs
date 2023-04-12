defmodule BlockScoutWeb.API.V2.WithdrawalControllerTest do
  use BlockScoutWeb.ConnCase

  alias Explorer.Chain.Withdrawal

  describe "/withdrawals" do
    test "empty lists", %{conn: conn} do
      request = get(conn, "/api/v2/blocks")
      assert response = json_response(request, 200)
      assert response["items"] == []
      assert response["next_page_params"] == nil
    end

    test "get withdrawal", %{conn: conn} do
      block = insert(:withdrawal)

      request = get(conn, "/api/v2/withdrawals")

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 1
      assert response["next_page_params"] == nil
      compare_item(block, Enum.at(response["items"], 0))
    end

    test "can paginate", %{conn: conn} do
      withdrawals =
        51
        |> insert_list(:withdrawal)

      request = get(conn, "/api/v2/withdrawals")
      assert response = json_response(request, 200)

      request_2nd_page = get(conn, "/api/v2/withdrawals", response["next_page_params"])

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, withdrawals)
    end
  end

  defp compare_item(%Withdrawal{} = withdrawal, json) do
    assert withdrawal.index == json["index"]
  end

  defp check_paginated_response(first_page_resp, second_page_resp, list) do
    assert Enum.count(first_page_resp["items"]) == 50
    assert first_page_resp["next_page_params"] != nil
    compare_item(Enum.at(list, 50), Enum.at(first_page_resp["items"], 0))
    compare_item(Enum.at(list, 1), Enum.at(first_page_resp["items"], 49))

    assert Enum.count(second_page_resp["items"]) == 1
    assert second_page_resp["next_page_params"] == nil
    compare_item(Enum.at(list, 0), Enum.at(second_page_resp["items"], 0))
  end
end
