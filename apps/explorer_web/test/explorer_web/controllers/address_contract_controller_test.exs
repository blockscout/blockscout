defmodule ExplorerWeb.AddressContractControllerTest do
  use ExplorerWeb.ConnCase

  import ExplorerWeb.Router.Helpers, only: [address_contract_path: 4]

  alias Explorer.Factory
  alias Explorer.Chain.Hash
  alias Explorer.ExchangeRates.Token

  describe "GET index/3" do
    test "returns not found for unexistent address", %{conn: conn} do
      unexistent_address_hash = Hash.to_string(Factory.address_hash())

      conn = get(conn, address_contract_path(ExplorerWeb.Endpoint, :index, :en, unexistent_address_hash))

      assert html_response(conn, 404)
    end

    test "returns not found given an invalid address hash ", %{conn: conn} do
      invalid_hash = "invalid_hash"

      conn = get(conn, address_contract_path(ExplorerWeb.Endpoint, :index, :en, invalid_hash))

      assert html_response(conn, 404)
    end

    test "returns not found when the address doesn't have a contract", %{conn: conn} do
      address = insert(:address)

      conn = get(conn, address_contract_path(ExplorerWeb.Endpoint, :index, :en, address))

      assert html_response(conn, 404)
    end

    test "suscefully renders the page", %{conn: conn} do
      address = insert(:address, contract_code: Factory.data("contract_code"))

      conn = get(conn, address_contract_path(ExplorerWeb.Endpoint, :index, :en, address))

      assert html_response(conn, 200)
      assert address == conn.assigns.address
      assert %Token{} = conn.assigns.exchange_rate
      assert conn.assigns.transaction_count
    end
  end
end
