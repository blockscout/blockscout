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
            bytes: <<48, 120, 120, 73, 0, 156, 36, 241, 10, 145, 163, 39, 169, 242, 237, 148, 235, 196, 158, 233>>
          }
        )

        insert(:op_interop_message, payload: "0x30787849009c24f10a91a327a9f2ed94ebc49ee9")

        TestHelper.get_chain_id_mock()

        conn = get(conn, "/api/v2/optimism/interop/messages")

        assert %{
                 "items" => [
                   %{
                     "payload" => "0x30787849009c24f10a91a327a9f2ed94ebc49ee9"
                   },
                   %{
                     "payload" => "0x30787849009c24f10a91a327a9f2ed94ebc49ee9"
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
