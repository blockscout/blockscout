defmodule BlockScoutWeb.API.V2.ScrollControllerTest do
  use BlockScoutWeb.ConnCase
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  import Mox

  alias Explorer.Chain.Scroll.{Batch, Bridge}

  setup :set_mox_global

  describe "/scroll/deposits, /scroll/withdrawals, /scroll/batches" do
    if @chain_type == :scroll do
      test "deposits with next_page_params", %{conn: conn} do
        deposits = insert_list(51, :scroll_bridge, type: :deposit)

        request = get(conn, "/api/v2/scroll/deposits")
        assert response = json_response(request, 200)

        request_2nd_page = get(conn, "/api/v2/scroll/deposits", response["next_page_params"])
        assert response_2nd_page = json_response(request_2nd_page, 200)

        check_paginated_response(response, response_2nd_page, deposits)
      end

      test "withdrawals with next_page_params", %{conn: conn} do
        withdrawals = insert_list(51, :scroll_bridge, type: :withdrawal)

        request = get(conn, "/api/v2/scroll/withdrawals")
        assert response = json_response(request, 200)

        request_2nd_page = get(conn, "/api/v2/scroll/withdrawals", response["next_page_params"])
        assert response_2nd_page = json_response(request_2nd_page, 200)

        check_paginated_response(response, response_2nd_page, withdrawals)
      end

      test "batches with next_page_params", %{conn: conn} do
        bundle = insert(:scroll_batch_bundle)
        batches = insert_list(bundle.final_batch_number + 1, :scroll_batch, bundle_id: bundle.id)

        request = get(conn, "/api/v2/scroll/batches")
        assert response = json_response(request, 200)

        request_2nd_page = get(conn, "/api/v2/scroll/batches", response["next_page_params"])
        assert response_2nd_page = json_response(request_2nd_page, 200)

        check_paginated_response(response, response_2nd_page, batches)
      end
    end
  end

  defp check_paginated_response(first_page_resp, second_page_resp, items) do
    assert Enum.count(first_page_resp["items"]) == 50
    assert first_page_resp["next_page_params"] != nil
    compare_item(Enum.at(items, 50), Enum.at(first_page_resp["items"], 0))
    compare_item(Enum.at(items, 1), Enum.at(first_page_resp["items"], 49))

    assert Enum.count(second_page_resp["items"]) == 1
    assert second_page_resp["next_page_params"] == nil
    compare_item(Enum.at(items, 0), Enum.at(second_page_resp["items"], 0))
  end

  defp compare_item(%Batch{} = item, json) do
    assert item.number == json["number"]
    assert to_string(item.commit_transaction_hash) == json["commitment_transaction"]["hash"]
    assert item.commit_block_number == json["commitment_transaction"]["block_number"]
    assert DateTime.to_iso8601(item.commit_timestamp) == json["commitment_transaction"]["timestamp"]
    assert item.container == String.to_atom(json["data_availability"]["batch_data_container"])
  end

  defp compare_item(%Bridge{} = item, json) do
    assert item.index == json["id"]
    assert DateTime.to_iso8601(item.block_timestamp) == json["origination_timestamp"]
    assert item.block_number == json["origination_transaction_block_number"]
    assert to_string(item.amount) == json["value"]

    if item.type == :deposit do
      assert to_string(item.l1_transaction_hash) == json["origination_transaction_hash"]
      assert to_string(item.l2_transaction_hash) == json["completion_transaction_hash"]
    else
      assert to_string(item.l2_transaction_hash) == json["origination_transaction_hash"]
      assert to_string(item.l1_transaction_hash) == json["completion_transaction_hash"]
    end
  end
end
