defmodule BlockScoutWeb.AddressTransactionControllerTest do
  use BlockScoutWeb.ConnCase

  import BlockScoutWeb.Router.Helpers, only: [address_transaction_path: 3]

  alias Explorer.Chain.{Block, Transaction}
  alias Explorer.ExchangeRates.Token

  describe "GET index/2" do
    test "with invalid address hash", %{conn: conn} do
      conn = get(conn, address_transaction_path(conn, :index, "invalid_address"))

      assert html_response(conn, 422)
    end

    test "with valid address hash without address", %{conn: conn} do
      conn = get(conn, address_transaction_path(conn, :index, "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"))

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

      conn = get(conn, address_transaction_path(conn, :index, address))

      transactions_hashes = Enum.map(conn.assigns.transactions, &Map.get(&1, :hash))

      assert transactions_hashes == [to_transaction.hash, from_transaction.hash]
    end

    test "includes USD exchange rate value for address in assigns", %{conn: conn} do
      address = insert(:address)

      conn = get(conn, address_transaction_path(BlockScoutWeb.Endpoint, :index, address.hash))

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
        get(conn, address_transaction_path(BlockScoutWeb.Endpoint, :index, address.hash), %{
          "block_number" => Integer.to_string(block_number),
          "index" => Integer.to_string(index)
        })

      actual_hashes =
        conn.assigns.transactions
        |> Enum.reverse()
        |> Enum.map(& &1.hash)

      assert second_page_hashes == actual_hashes
    end

    test "next_page_params exist if not on last page", %{conn: conn} do
      address = insert(:address)
      block = %Block{number: number} = insert(:block)

      60
      |> insert_list(:transaction, from_address: address)
      |> with_block(block)

      conn = get(conn, address_transaction_path(BlockScoutWeb.Endpoint, :index, address.hash))

      expected_next_page_params = %{
        "address_id" => to_string(address.hash),
        "block_number" => number,
        "index" => 10
      }

      assert conn.assigns.next_page_params == expected_next_page_params
    end

    test "next_page_params are empty if on last page", %{conn: conn} do
      address = insert(:address)

      :transaction
      |> insert(from_address: address)
      |> with_block()

      conn = get(conn, address_transaction_path(BlockScoutWeb.Endpoint, :index, address.hash))

      refute conn.assigns.next_page_params
    end

    test "returns parent transaction for a contract address", %{conn: conn} do
      address = insert(:address, contract_code: data(:address_contract_code))
      block = insert(:block)

      transaction =
        :transaction
        |> insert(to_address: nil, created_contract_address_hash: address.hash)
        |> with_block(block)
        |> Explorer.Repo.preload([[created_contract_address: :names], [from_address: :names], :token_transfers])

      insert(
        :internal_transaction_create,
        index: 0,
        created_contract_address: address,
        to_address: nil,
        transaction: transaction
      )

      conn = get(conn, address_transaction_path(conn, :index, address), %{"type" => "JSON"})

      transaction_hashes = Enum.map(conn.assigns.transactions, & &1.hash)

      assert [transaction.hash] == transaction_hashes
    end
  end
end
