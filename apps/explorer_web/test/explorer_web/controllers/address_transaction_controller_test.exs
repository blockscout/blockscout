defmodule ExplorerWeb.AddressTransactionControllerTest do
  use ExplorerWeb.ConnCase

  import ExplorerWeb.Router.Helpers, only: [address_transaction_path: 4]

  alias Explorer.Chain.{Block, Transaction}
  alias Explorer.ExchangeRates.Token

  describe "GET index/2" do
    test "with invalid address hash", %{conn: conn} do
      conn = get(conn, address_transaction_path(conn, :index, :en, "invalid_address"))

      assert html_response(conn, 422)
    end

    test "with valid address hash without address", %{conn: conn} do
      conn = get(conn, address_transaction_path(conn, :index, :en, "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"))

      assert html_response(conn, 404)
    end

    test "returns transactions for the address", %{conn: conn} do
      address = insert(:address)

      block = insert(:block)

      from_transaction =
        :transaction
        |> insert(from_address: address)
        |> with_block(block)

      to_transaction =
        :transaction
        |> insert(to_address: address)
        |> with_block(block)

      conn = get(conn, address_transaction_path(conn, :index, :en, address))

      actual_transaction_hashes =
        conn.assigns.transactions
        |> Enum.map(& &1.hash)

      assert html_response(conn, 200)
      assert Enum.member?(actual_transaction_hashes, from_transaction.hash)
      assert Enum.member?(actual_transaction_hashes, to_transaction.hash)
    end

    test "does not return related transactions without a block", %{conn: conn} do
      address = insert(:address)

      insert(:transaction, from_address: address, to_address: address)

      conn = get(conn, address_transaction_path(ExplorerWeb.Endpoint, :index, :en, address))

      assert html_response(conn, 200)
      assert conn.status == 200
      assert Enum.empty?(conn.assigns.transactions)
      assert conn.status == 200
      assert Enum.empty?(conn.assigns.transactions)
    end

    test "includes USD exchange rate value for address in assigns", %{conn: conn} do
      address = insert(:address)

      conn = get(conn, address_transaction_path(ExplorerWeb.Endpoint, :index, :en, address.hash))

      assert %Token{} = conn.assigns.exchange_rate
    end

    test "returns next page of results based on last seen transaction", %{conn: conn} do
      address = insert(:address)

      second_page_hashes =
        50
        |> insert_list(:transaction, from_address: address)
        |> with_block()
        |> Enum.map(& &1.hash)

      %Transaction{block_number: block_number, index: index} =
        :transaction
        |> insert(from_address: address)
        |> with_block()

      conn =
        get(conn, address_transaction_path(ExplorerWeb.Endpoint, :index, :en, address.hash), %{
          "block_number" => Integer.to_string(block_number),
          "index" => Integer.to_string(index)
        })

      actual_hashes =
        conn.assigns.transactions
        |> Enum.map(& &1.hash)
        |> Enum.reverse()

      assert second_page_hashes == actual_hashes
    end

    test "next_page_params exist if not on last page", %{conn: conn} do
      address = insert(:address)
      block = %Block{number: number} = insert(:block)

      60
      |> insert_list(:transaction, from_address: address)
      |> with_block(block)

      conn = get(conn, address_transaction_path(ExplorerWeb.Endpoint, :index, :en, address.hash))

      assert %{"block_number" => ^number, "index" => 10} = conn.assigns.next_page_params
    end

    test "next_page_params are empty if on last page", %{conn: conn} do
      address = insert(:address)

      :transaction
      |> insert(from_address: address)
      |> with_block()

      conn = get(conn, address_transaction_path(ExplorerWeb.Endpoint, :index, :en, address.hash))

      refute conn.assigns.next_page_params
    end

    test "returns parent transaction for a contract address", %{conn: conn} do
      address = insert(:address, contract_code: data(:address_contract_code))
      block = insert(:block)

      transaction =
        :transaction
        |> insert(to_address: nil, created_contract_address_hash: address.hash)
        |> with_block(block)

      insert(
        :internal_transaction_create,
        index: 0,
        created_contract_address: address,
        to_address: nil,
        transaction: transaction
      )

      conn = get(conn, address_transaction_path(conn, :index, :en, address))

      assert [transaction] == conn.assigns.transactions
    end
  end
end
