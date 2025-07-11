defmodule BlockScoutWeb.AddressContractControllerTest do
  use BlockScoutWeb.ConnCase, async: true

  import BlockScoutWeb.Routers.WebRouter.Helpers, only: [address_contract_path: 3]

  alias Explorer.Chain.{Address, Hash}
  alias Explorer.Market.Token
  alias Explorer.{Factory, TestHelper}

  setup do
    Application.put_env(:tesla, :adapter, Tesla.Adapter.Mint)

    on_exit(fn ->
      Application.put_env(:tesla, :adapter, Explorer.Mock.TeslaAdapter)
    end)
  end

  describe "GET index/3" do
    test "returns not found for nonexistent address", %{conn: conn} do
      nonexistent_address_hash = Hash.to_string(Factory.address_hash())

      conn =
        get(conn, address_contract_path(BlockScoutWeb.Endpoint, :index, Address.checksum(nonexistent_address_hash)))

      assert html_response(conn, 404)
    end

    test "returns not found given an invalid address hash ", %{conn: conn} do
      invalid_hash = "invalid_hash"

      conn = get(conn, address_contract_path(BlockScoutWeb.Endpoint, :index, invalid_hash))

      assert html_response(conn, 404)
    end

    test "returns not found when the address isn't a contract", %{conn: conn} do
      address = insert(:address)

      conn = get(conn, address_contract_path(BlockScoutWeb.Endpoint, :index, Address.checksum(address)))

      assert html_response(conn, 404)
    end

    test "successfully renders the page when the address is a contract", %{conn: conn} do
      address = insert(:address, contract_code: Factory.data("contract_code"), smart_contract: nil)

      transaction = insert(:transaction, from_address: address) |> with_block()

      insert(
        :internal_transaction_create,
        index: 0,
        transaction: transaction,
        created_contract_address: address,
        block_hash: transaction.block_hash,
        block_index: 0
      )

      TestHelper.get_all_proxies_implementation_zero_addresses()

      conn = get(conn, address_contract_path(BlockScoutWeb.Endpoint, :index, Address.checksum(address)))

      assert html_response(conn, 200)
      assert address.hash == conn.assigns.address.hash
      assert %Token{} = conn.assigns.exchange_rate
    end
  end
end
