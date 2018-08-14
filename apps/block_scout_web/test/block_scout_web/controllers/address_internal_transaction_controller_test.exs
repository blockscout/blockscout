defmodule BlockScoutWeb.AddressInternalTransactionControllerTest do
  use BlockScoutWeb.ConnCase

  import BlockScoutWeb.Router.Helpers, only: [address_internal_transaction_path: 4]

  alias Explorer.Chain.{Block, InternalTransaction, Transaction}
  alias Explorer.ExchangeRates.Token

  describe "GET index/3" do
    test "with invalid address hash", %{conn: conn} do
      conn =
        conn
        |> get(address_internal_transaction_path(BlockScoutWeb.Endpoint, :index, :en, "invalid_address"))

      assert html_response(conn, 404)
    end

    test "with valid address hash without address", %{conn: conn} do
      conn =
        get(conn, address_internal_transaction_path(conn, :index, :en, "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"))

      assert html_response(conn, 404)
    end

    test "returns internal transactions for the address", %{conn: conn} do
      address = insert(:address)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      from_internal_transaction =
        insert(:internal_transaction, transaction: transaction, from_address: address, index: 1)

      to_internal_transaction = insert(:internal_transaction, transaction: transaction, to_address: address, index: 2)

      path = address_internal_transaction_path(conn, :index, :en, address)
      conn = get(conn, path)

      actual_transaction_ids =
        conn.assigns.internal_transactions
        |> Enum.map(fn internal_transaction -> internal_transaction.id end)

      assert Enum.member?(actual_transaction_ids, from_internal_transaction.id)
      assert Enum.member?(actual_transaction_ids, to_internal_transaction.id)
    end

    test "includes USD exchange rate value for address in assigns", %{conn: conn} do
      address = insert(:address)

      conn = get(conn, address_internal_transaction_path(BlockScoutWeb.Endpoint, :index, :en, address.hash))

      assert %Token{} = conn.assigns.exchange_rate
    end

    test "returns next page of results based on last seen internal transaction", %{conn: conn} do
      address = insert(:address)

      a_block = insert(:block, number: 1000)
      b_block = insert(:block, number: 2000)

      transaction_1 =
        :transaction
        |> insert()
        |> with_block(a_block)

      transaction_2 =
        :transaction
        |> insert()
        |> with_block(a_block)

      transaction_3 =
        :transaction
        |> insert()
        |> with_block(b_block)

      transaction_1_hashes =
        1..20
        |> Enum.map(fn index ->
          insert(
            :internal_transaction,
            transaction: transaction_1,
            from_address: address,
            index: index
          )
        end)
        |> Enum.map(&"#{&1.transaction_hash}.#{&1.index}")

      transaction_2_hashes =
        1..20
        |> Enum.map(fn index ->
          insert(
            :internal_transaction,
            transaction: transaction_2,
            from_address: address,
            index: index
          )
        end)
        |> Enum.map(&"#{&1.transaction_hash}.#{&1.index}")

      transaction_3_hashes =
        1..10
        |> Enum.map(fn index ->
          insert(
            :internal_transaction,
            transaction: transaction_3,
            from_address: address,
            index: index
          )
        end)
        |> Enum.map(&"#{&1.transaction_hash}.#{&1.index}")

      second_page_hashes = transaction_1_hashes ++ transaction_2_hashes ++ transaction_3_hashes

      %InternalTransaction{index: index} =
        :internal_transaction
        |> insert(transaction: transaction_3, from_address: address, index: 11)

      conn =
        get(conn, address_internal_transaction_path(BlockScoutWeb.Endpoint, :index, :en, address.hash), %{
          "block_number" => Integer.to_string(b_block.number),
          "transaction_index" => Integer.to_string(transaction_3.index),
          "index" => Integer.to_string(index)
        })

      actual_hashes =
        conn.assigns.internal_transactions
        |> Enum.map(&"#{&1.transaction_hash}.#{&1.index}")
        |> Enum.reverse()

      assert second_page_hashes == actual_hashes
    end

    test "next_page_params exist if not on last page", %{conn: conn} do
      address = insert(:address)
      block = %Block{number: number} = insert(:block)

      transaction =
        %Transaction{index: transaction_index} =
        :transaction
        |> insert()
        |> with_block(block)

      1..60
      |> Enum.map(fn index ->
        insert(
          :internal_transaction,
          transaction: transaction,
          from_address: address,
          index: index
        )
      end)

      conn = get(conn, address_internal_transaction_path(BlockScoutWeb.Endpoint, :index, :en, address.hash))

      assert %{"block_number" => ^number, "index" => 11, "transaction_index" => ^transaction_index} =
               conn.assigns.next_page_params
    end

    test "next_page_params are empty if on last page", %{conn: conn} do
      address = insert(:address)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      1..2
      |> Enum.map(fn index ->
        insert(
          :internal_transaction,
          transaction: transaction,
          from_address: address,
          index: index
        )
      end)

      conn = get(conn, address_internal_transaction_path(BlockScoutWeb.Endpoint, :index, :en, address.hash))

      refute conn.assigns.next_page_params
    end
  end
end
