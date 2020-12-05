defmodule BlockScoutWeb.AddressWriteContractControllerTest do
  use BlockScoutWeb.ConnCase, async: true
  use ExUnit.Case, async: false

  alias Explorer.ExchangeRates.Token
  alias Explorer.Chain.Address

  import Mox

  describe "GET index/3" do
    setup :set_mox_global

    setup do
      configuration = Application.get_env(:explorer, :checksum_function)
      Application.put_env(:explorer, :checksum_function, :eth)

      :ok

      on_exit(fn ->
        Application.put_env(:explorer, :checksum_function, configuration)
      end)
    end

    test "with invalid address hash", %{conn: conn} do
      conn = get(conn, address_write_contract_path(BlockScoutWeb.Endpoint, :index, "invalid_address"))

      assert html_response(conn, 404)
    end

    test "with valid address that is not a contract", %{conn: conn} do
      address = insert(:address)

      conn = get(conn, address_write_contract_path(BlockScoutWeb.Endpoint, :index, Address.checksum(address.hash)))

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
        get(conn, address_write_contract_path(BlockScoutWeb.Endpoint, :index, Address.checksum(contract_address.hash)))

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
        get(conn, address_write_contract_path(BlockScoutWeb.Endpoint, :index, Address.checksum(contract_address.hash)))

      assert html_response(conn, 404)
    end
  end
end
