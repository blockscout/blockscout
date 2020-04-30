defmodule BlockScoutWeb.AddressTokenBalanceControllerTest do
  use BlockScoutWeb.ConnCase

  alias Explorer.Chain.Address
  alias Explorer.Factory

  describe "GET index/3" do
    test "without AJAX", %{conn: conn} do
      %Address{hash: hash} = Factory.insert(:address)

      response_conn = get(conn, address_token_balance_path(conn, :index, Address.checksum(hash)))

      assert html_response(response_conn, 404)
    end

    test "with AJAX without valid address", %{conn: conn} do
      ajax_conn = ajax(conn)

      response_conn = get(ajax_conn, address_token_balance_path(ajax_conn, :index, "invalid_address"))

      assert html_response(response_conn, 404)
    end

    test "with AJAX with valid address without address still returns token balances", %{conn: conn} do
      ajax_conn = ajax(conn)

      response_conn = get(ajax_conn, address_token_balance_path(ajax_conn, :index, Address.checksum(address_hash())))

      assert html_response(response_conn, 200)
    end

    test "with AJAX with valid address with address returns token balances", %{conn: conn} do
      %Address{hash: hash} = Factory.insert(:address)

      ajax_conn = ajax(conn)

      response_conn = get(ajax_conn, address_token_balance_path(ajax_conn, :index, Address.checksum(hash)))

      assert html_response(response_conn, 200)
    end
  end

  defp ajax(conn) do
    put_req_header(conn, "x-requested-with", "XMLHttpRequest")
  end
end
