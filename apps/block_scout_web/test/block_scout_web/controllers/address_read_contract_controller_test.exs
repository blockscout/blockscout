defmodule BlockScoutWeb.AddressReadContractControllerTest do
  use BlockScoutWeb.ConnCase

  alias Explorer.ExchangeRates.Token

  describe "GET index/3" do
    test "with invalid address hash", %{conn: conn} do
      conn = get(conn, address_read_contract_path(BlockScoutWeb.Endpoint, :index, "invalid_address"))

      assert html_response(conn, 404)
    end

    test "with valid address that is not a contract", %{conn: conn} do
      address = insert(:address)

      conn = get(conn, address_read_contract_path(BlockScoutWeb.Endpoint, :index, address.hash))

      assert html_response(conn, 404)
    end

    test "successfully renders the page when the address is a contract", %{conn: conn} do
      contract_address = insert(:contract_address)

      transaction = insert(:transaction, from_address: contract_address)

      insert(
        :internal_transaction_create,
        index: 0,
        transaction: transaction,
        created_contract_address: contract_address
      )

      insert(:smart_contract, address_hash: contract_address.hash)

      conn = get(conn, address_read_contract_path(BlockScoutWeb.Endpoint, :index, contract_address.hash))

      assert html_response(conn, 200)
      assert contract_address.hash == conn.assigns.address.hash
      assert %Token{} = conn.assigns.exchange_rate
      assert conn.assigns.transaction_count
    end
  end
end
