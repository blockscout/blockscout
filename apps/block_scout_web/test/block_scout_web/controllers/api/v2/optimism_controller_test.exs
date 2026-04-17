defmodule BlockScoutWeb.API.V2.OptimismControllerTest do
  use BlockScoutWeb.ConnCase
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  import Mox

  alias Explorer.Chain.{Address, Data}
  alias Explorer.Chain.Optimism.Deposit
  alias Explorer.TestHelper

  setup :set_mox_global

  describe "/optimism/deposits" do
    if @chain_type == :optimism do
      test "deposits with next_page_params", %{conn: conn} do
        deposits = insert_list(51, :op_deposit)

        request = get(conn, "/api/v2/optimism/deposits")
        assert response = json_response(request, 200)

        request_2nd_page = get(conn, "/api/v2/optimism/deposits", response["next_page_params"])
        assert response_2nd_page = json_response(request_2nd_page, 200)

        check_paginated_response(response, response_2nd_page, deposits)
      end
    end
  end

  describe "/optimism/interop/messages" do
    if @chain_type == :optimism do
      test "handles message with 0x prefixed payload", %{conn: conn} do
        insert(:op_interop_message,
          payload: %Data{
            bytes: <<48, 120, 120, 73, 33, 116, 36, 121, 34, 115, 113, 39, 119, 112, 117, 118, 105, 106, 108, 93>>
          }
        )

        insert(:op_interop_message, payload: "0x30787849217424792273712777707576696a6c5d")

        TestHelper.get_chain_id_mock()

        conn = get(conn, "/api/v2/optimism/interop/messages")

        assert %{
                 "items" => [
                   %{
                     "payload" => "0x30787849217424792273712777707576696a6c5d"
                   },
                   %{
                     "payload" => "0x30787849217424792273712777707576696a6c5d"
                   }
                 ],
                 "next_page_params" => nil
               } = json_response(conn, 200)
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

  defp compare_item(%Deposit{} = deposit, json) do
    assert deposit.l1_block_number == json["l1_block_number"]
    assert DateTime.to_iso8601(deposit.l1_block_timestamp) == json["l1_block_timestamp"]
    assert to_string(deposit.l1_transaction_hash) == json["l1_transaction_hash"]
    assert Address.checksum(deposit.l1_transaction_origin) == Address.checksum(json["l1_transaction_origin"])
    assert to_string(deposit.l2_transaction.hash) == json["l2_transaction_hash"]
    assert to_string(deposit.l2_transaction.gas) == json["l2_transaction_gas_limit"]
  end
end
