defmodule BlockScoutWeb.API.V2.OptimismControllerTest do
  use BlockScoutWeb.ConnCase
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  import Mox

  alias Explorer.Chain.Data
  alias Explorer.TestHelper

  setup :set_mox_global

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
    else
      test "returns 404 in non optimism chain type", %{conn: conn} do
        conn = get(conn, "/api/v2/optimism/interop/messages")
        assert json_response(conn, 404) == %{"message" => "Endpoint not available for current chain type"}
      end
    end
  end
end
