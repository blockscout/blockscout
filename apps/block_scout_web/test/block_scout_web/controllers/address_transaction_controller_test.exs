defmodule BlockScoutWeb.AddressTransactionControllerTest do
  use BlockScoutWeb.ConnCase, async: true

  import BlockScoutWeb.WebRouter.Helpers, only: [address_transaction_path: 3, address_transaction_path: 4]
  import Mox

  alias Explorer.Chain.{Address, Transaction}
  alias Explorer.ExchangeRates.Token

  describe "GET index/2" do
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
      conn = get(conn, address_transaction_path(conn, :index, "invalid_address"))

      assert html_response(conn, 422)
    end

    test "with valid address hash without address in the DB", %{conn: conn} do
      conn =
        get(
          conn,
          address_transaction_path(conn, :index, Address.checksum("0x8bf38d4764929064f2d4d3a56520a76ab3df415b"), %{
            "type" => "JSON"
          })
        )

      assert json_response(conn, 200)
      transaction_tiles = json_response(conn, 200)["items"]
      assert transaction_tiles |> length() == 0
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

      conn = get(conn, address_transaction_path(conn, :index, Address.checksum(address), %{"type" => "JSON"}))

      transaction_tiles = json_response(conn, 200)["items"]
      transaction_hashes = Enum.map([to_transaction.hash, from_transaction.hash], &to_string(&1))

      assert Enum.all?(transaction_hashes, fn transaction_hash ->
               Enum.any?(transaction_tiles, &String.contains?(&1, transaction_hash))
             end)
    end

    test "includes USD exchange rate value for address in assigns", %{conn: conn} do
      address = insert(:address)

      conn = get(conn, address_transaction_path(BlockScoutWeb.Endpoint, :index, Address.checksum(address.hash)))

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
        get(conn, address_transaction_path(BlockScoutWeb.Endpoint, :index, Address.checksum(address.hash)), %{
          "block_number" => Integer.to_string(block_number),
          "index" => Integer.to_string(index),
          "type" => "JSON"
        })

      transaction_tiles = json_response(conn, 200)["items"]

      assert Enum.all?(second_page_hashes, fn address_hash ->
               Enum.any?(transaction_tiles, &String.contains?(&1, to_string(address_hash)))
             end)
    end

    test "next_page_params exist if not on last page", %{conn: conn} do
      address = insert(:address)
      block = insert(:block)

      60
      |> insert_list(:transaction, from_address: address)
      |> with_block(block)

      conn = get(conn, address_transaction_path(conn, :index, Address.checksum(address.hash), %{"type" => "JSON"}))

      assert json_response(conn, 200)["next_page_path"]
    end

    test "next_page_params are empty if on last page", %{conn: conn} do
      address = insert(:address)

      :transaction
      |> insert(from_address: address)
      |> with_block()

      conn = get(conn, address_transaction_path(conn, :index, Address.checksum(address.hash), %{"type" => "JSON"}))

      refute json_response(conn, 200)["next_page_path"]
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
        transaction: transaction,
        block_hash: block.hash,
        block_index: 0
      )

      conn = get(conn, address_transaction_path(conn, :index, Address.checksum(address)), %{"type" => "JSON"})

      transaction_tiles = json_response(conn, 200)["items"]

      assert Enum.all?([transaction.hash], fn transaction_hash ->
               Enum.any?(transaction_tiles, &String.contains?(&1, to_string(transaction_hash)))
             end)
    end
  end

  describe "GET token_transfers_csv/2" do
    test "exports token transfers to csv", %{conn: conn} do
      address = insert(:address)

      transaction =
        :transaction
        |> insert(from_address: address)
        |> with_block()

      insert(:token_transfer, transaction: transaction, from_address: address)
      insert(:token_transfer, transaction: transaction, to_address: address)

      conn = get(conn, "/token_transfers_csv", %{"address_id" => Address.checksum(address.hash)})

      assert conn.resp_body |> String.split("\n") |> Enum.count() == 4
    end
  end

  describe "GET transactions_csv/2" do
    test "download csv file with transactions", %{conn: conn} do
      address = insert(:address)

      :transaction
      |> insert(from_address: address)
      |> with_block()

      :transaction
      |> insert(from_address: address)
      |> with_block()

      conn = get(conn, "/transactions_csv", %{"address_id" => Address.checksum(address.hash)})

      assert conn.resp_body |> String.split("\n") |> Enum.count() == 4
    end
  end
end
