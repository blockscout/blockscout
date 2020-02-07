defmodule BlockScoutWeb.AddressReadContractControllerTest do
  use BlockScoutWeb.ConnCase, async: true

  alias Explorer.ExchangeRates.Token
  alias Explorer.Chain.Address

  describe "GET index/3" do
    test "with invalid address hash", %{conn: conn} do
      conn = get(conn, address_read_contract_path(BlockScoutWeb.Endpoint, :index, "invalid_address"))

      assert html_response(conn, 404)
    end

    test "with valid address that is not a contract", %{conn: conn} do
      address = insert(:address)

      conn = get(conn, address_read_contract_path(BlockScoutWeb.Endpoint, :index, Address.checksum(address.hash)))

      assert html_response(conn, 404)
    end

    test "successfully renders the page when the address is a contract", %{conn: conn} do
      contract_address = insert(:contract_address)

      transaction = insert(:transaction, from_address: contract_address) |> with_block()

      insert(
        :internal_transaction_create,
        index: 0,
        transaction: transaction,
        created_contract_address: contract_address,
        block_hash: transaction.block_hash,
        block_index: 0
      )

      insert(:smart_contract, address_hash: contract_address.hash)

      conn =
        get(conn, address_read_contract_path(BlockScoutWeb.Endpoint, :index, Address.checksum(contract_address.hash)))

      assert html_response(conn, 200)
      assert contract_address.hash == conn.assigns.address.hash
      assert %Token{} = conn.assigns.exchange_rate
    end

    test "returns not found for an unverified contract", %{conn: conn} do
      contract_address = insert(:contract_address)

      transaction = insert(:transaction, from_address: contract_address) |> with_block()

      insert(
        :internal_transaction_create,
        index: 0,
        transaction: transaction,
        created_contract_address: contract_address,
        block_hash: transaction.block_hash,
        block_index: 0
      )

      conn =
        get(conn, address_read_contract_path(BlockScoutWeb.Endpoint, :index, Address.checksum(contract_address.hash)))

      assert html_response(conn, 404)
    end
  end
end
