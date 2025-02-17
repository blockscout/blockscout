defmodule BlockScoutWeb.AddressInternalTransactionControllerTest do
  use BlockScoutWeb.ConnCase, async: true

  import BlockScoutWeb.Routers.WebRouter.Helpers,
    only: [address_internal_transaction_path: 3, address_internal_transaction_path: 4]

  alias Explorer.Chain.{Address, Block, InternalTransaction, Transaction}
  alias Explorer.Market.Token

  describe "GET index/3" do
    test "with invalid address hash", %{conn: conn} do
      conn =
        conn
        |> get(address_internal_transaction_path(BlockScoutWeb.Endpoint, :index, "invalid_address"))

      assert html_response(conn, 404)
    end

    if Application.compile_env(:explorer, :chain_type) !== :rsk do
      test "with valid address hash without address", %{conn: conn} do
        conn =
          get(
            conn,
            address_internal_transaction_path(
              conn,
              :index,
              Address.checksum("0x8bf38d4764929064f2d4d3a56520a76ab3df415b")
            )
          )

        assert html_response(conn, 200)
      end
    end

    test "includes USD exchange rate value for address in assigns", %{conn: conn} do
      address = insert(:address)

      conn =
        get(conn, address_internal_transaction_path(BlockScoutWeb.Endpoint, :index, Address.checksum(address.hash)))

      assert %Token{} = conn.assigns.exchange_rate
    end

    test "returns internal transactions for the address", %{conn: conn} do
      address = insert(:address)

      transaction =
        :transaction
        |> insert()
        |> with_block(insert(:block, number: 1))

      from_internal_transaction =
        insert(:internal_transaction,
          transaction: transaction,
          from_address: address,
          index: 1,
          block_number: transaction.block_number,
          transaction_index: transaction.index,
          block_hash: transaction.block_hash,
          block_index: 1
        )

      to_internal_transaction =
        insert(:internal_transaction,
          transaction: transaction,
          to_address: address,
          index: 2,
          block_number: transaction.block_number,
          transaction_index: transaction.index,
          block_hash: transaction.block_hash,
          block_index: 2
        )

      path = address_internal_transaction_path(conn, :index, Address.checksum(address), %{"type" => "JSON"})
      conn = get(conn, path)

      internal_transaction_tiles = json_response(conn, 200)["items"]

      assert Enum.all?([from_internal_transaction, to_internal_transaction], fn internal_transaction ->
               Enum.any?(internal_transaction_tiles, fn tile ->
                 String.contains?(tile, to_string(internal_transaction.transaction_hash)) &&
                   String.contains?(tile, "data-internal-transaction-index=\"#{internal_transaction.index}\"")
               end)
             end)
    end

    test "returns internal transactions coming from the address", %{conn: conn} do
      address = insert(:address)

      transaction =
        :transaction
        |> insert()
        |> with_block(insert(:block, number: 1))

      from_internal_transaction =
        insert(:internal_transaction,
          transaction: transaction,
          from_address: address,
          index: 1,
          block_number: transaction.block_number,
          transaction_index: transaction.index,
          block_hash: transaction.block_hash,
          block_index: 1
        )

      to_internal_transaction =
        insert(:internal_transaction,
          transaction: transaction,
          to_address: address,
          index: 2,
          block_number: transaction.block_number,
          transaction_index: transaction.index,
          block_hash: transaction.block_hash,
          block_index: 2
        )

      path =
        address_internal_transaction_path(conn, :index, Address.checksum(address), %{
          "filter" => "from",
          "type" => "JSON"
        })

      conn = get(conn, path)

      internal_transaction_tiles = json_response(conn, 200)["items"]

      assert Enum.any?(internal_transaction_tiles, fn tile ->
               String.contains?(tile, to_string(from_internal_transaction.transaction_hash)) &&
                 String.contains?(tile, "data-internal-transaction-index=\"#{from_internal_transaction.index}\"")
             end)

      refute Enum.any?(internal_transaction_tiles, fn tile ->
               String.contains?(tile, to_string(to_internal_transaction.transaction_hash)) &&
                 String.contains?(tile, "data-internal-transaction-index=\"#{to_internal_transaction.index}\"")
             end)
    end

    test "returns internal transactions going to the address", %{conn: conn} do
      address = insert(:address)

      transaction =
        :transaction
        |> insert()
        |> with_block(insert(:block, number: 1))

      from_internal_transaction =
        insert(:internal_transaction,
          transaction: transaction,
          from_address: address,
          index: 1,
          block_number: transaction.block_number,
          transaction_index: transaction.index,
          block_hash: transaction.block_hash,
          block_index: 1
        )

      to_internal_transaction =
        insert(:internal_transaction,
          transaction: transaction,
          to_address: address,
          index: 2,
          block_number: transaction.block_number,
          transaction_index: transaction.index,
          block_hash: transaction.block_hash,
          block_index: 2
        )

      path =
        address_internal_transaction_path(conn, :index, Address.checksum(address), %{"filter" => "to", "type" => "JSON"})

      conn = get(conn, path)

      internal_transaction_tiles = json_response(conn, 200)["items"]

      assert Enum.any?(internal_transaction_tiles, fn tile ->
               String.contains?(tile, to_string(to_internal_transaction.transaction_hash)) &&
                 String.contains?(tile, "data-internal-transaction-index=\"#{to_internal_transaction.index}\"")
             end)

      refute Enum.any?(internal_transaction_tiles, fn tile ->
               String.contains?(tile, to_string(from_internal_transaction.transaction_hash)) &&
                 String.contains?(tile, "data-internal-transaction-index=\"#{from_internal_transaction.index}\"")
             end)
    end

    test "returns internal an transaction that created the address", %{conn: conn} do
      address = insert(:address)

      transaction =
        :transaction
        |> insert()
        |> with_block(insert(:block, number: 1))

      from_internal_transaction =
        insert(:internal_transaction,
          transaction: transaction,
          from_address: address,
          index: 1,
          block_number: transaction.block_number,
          transaction_index: transaction.index,
          block_hash: transaction.block_hash,
          block_index: 1
        )

      to_internal_transaction =
        insert(:internal_transaction,
          transaction: transaction,
          to_address: nil,
          created_contract_address: address,
          index: 2,
          block_number: transaction.block_number,
          transaction_index: transaction.index,
          block_hash: transaction.block_hash,
          block_index: 2
        )

      path =
        address_internal_transaction_path(conn, :index, Address.checksum(address), %{"filter" => "to", "type" => "JSON"})

      conn = get(conn, path)

      internal_transaction_tiles = json_response(conn, 200)["items"]

      assert Enum.any?(internal_transaction_tiles, fn tile ->
               String.contains?(tile, to_string(to_internal_transaction.transaction_hash)) &&
                 String.contains?(tile, "data-internal-transaction-index=\"#{to_internal_transaction.index}\"")
             end)

      refute Enum.any?(internal_transaction_tiles, fn tile ->
               String.contains?(tile, to_string(from_internal_transaction.transaction_hash)) &&
                 String.contains?(tile, "data-internal-transaction-index=\"#{from_internal_transaction.index}\"")
             end)
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
            index: index,
            block_number: transaction_1.block_number,
            transaction_index: transaction_1.index,
            block_hash: a_block.hash,
            block_index: index
          )
        end)

      transaction_2_hashes =
        1..20
        |> Enum.map(fn index ->
          insert(
            :internal_transaction,
            transaction: transaction_2,
            from_address: address,
            index: index,
            block_number: transaction_2.block_number,
            transaction_index: transaction_2.index,
            block_hash: a_block.hash,
            block_index: 20 + index
          )
        end)

      transaction_3_hashes =
        1..10
        |> Enum.map(fn index ->
          insert(
            :internal_transaction,
            transaction: transaction_3,
            from_address: address,
            index: index,
            block_number: transaction_3.block_number,
            transaction_index: transaction_3.index,
            block_hash: b_block.hash,
            block_index: index
          )
        end)

      second_page = transaction_1_hashes ++ transaction_2_hashes ++ transaction_3_hashes

      %InternalTransaction{index: index} =
        insert(
          :internal_transaction,
          transaction: transaction_3,
          from_address: address,
          index: 11,
          block_number: transaction_3.block_number,
          transaction_index: transaction_3.index,
          block_hash: b_block.hash,
          block_index: 11
        )

      conn =
        get(conn, address_internal_transaction_path(BlockScoutWeb.Endpoint, :index, Address.checksum(address.hash)), %{
          "block_number" => Integer.to_string(b_block.number),
          "transaction_index" => Integer.to_string(transaction_3.index),
          "index" => Integer.to_string(index),
          "type" => "JSON"
        })

      internal_transaction_tiles = json_response(conn, 200)["items"]

      assert Enum.all?(second_page, fn internal_transaction ->
               Enum.any?(internal_transaction_tiles, fn tile ->
                 String.contains?(tile, to_string(internal_transaction.transaction_hash)) &&
                   String.contains?(tile, "data-internal-transaction-index=\"#{internal_transaction.index}\"")
               end)
             end)
    end

    test "next page doesn't miss internal transactions", %{conn: conn} do
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

      from_internal_transactions =
        1..55
        |> Enum.map(fn index ->
          insert(
            :internal_transaction,
            transaction: transaction_1,
            from_address: address,
            index: index,
            block_number: transaction_1.block_number,
            transaction_index: transaction_1.index,
            block_hash: a_block.hash,
            block_index: index
          )
        end)

      to_internal_transactions =
        1..55
        |> Enum.map(fn index ->
          insert(
            :internal_transaction,
            transaction: transaction_2,
            to_address: address,
            index: index,
            block_number: transaction_2.block_number,
            transaction_index: transaction_2.index,
            block_hash: a_block.hash,
            block_index: 55 + index
          )
        end)

      created_contract_internal_transactions =
        1..55
        |> Enum.map(fn index ->
          insert(
            :internal_transaction,
            transaction: transaction_3,
            created_contract_address: address,
            index: index,
            block_number: transaction_3.block_number,
            transaction_index: transaction_3.index,
            block_hash: b_block.hash,
            block_index: index
          )
        end)

      {second_page_contract_items, first_page_items} = Enum.split(created_contract_internal_transactions, 5)
      {third_page_to_items, second_page_to_items} = Enum.split(to_internal_transactions, 10)
      {fourth_page_items, third_page_from_items} = Enum.split(from_internal_transactions, 15)

      second_page_items = second_page_contract_items ++ second_page_to_items
      third_page_items = third_page_to_items ++ third_page_from_items

      path = address_internal_transaction_path(BlockScoutWeb.Endpoint, :index, Address.checksum(address.hash))

      empty_page_response =
        conn
        |> get(path, %{
          "block_number" => Integer.to_string(0),
          "transaction_index" => Integer.to_string(0),
          "index" => "0",
          "type" => "JSON"
        })
        |> json_response(200)
        |> Map.get("items")

      assert Enum.count(empty_page_response) == 0

      first_page_response =
        conn
        |> get(path, %{"type" => "JSON"})
        |> json_response(200)
        |> Map.get("items")

      second_page_response =
        conn
        |> get(path, %{
          "block_number" => Integer.to_string(b_block.number),
          "transaction_index" => Integer.to_string(transaction_3.index),
          "index" => "6",
          "type" => "JSON"
        })
        |> json_response(200)
        |> Map.get("items")

      third_page_response =
        conn
        |> get(path, %{
          "block_number" => Integer.to_string(a_block.number),
          "transaction_index" => Integer.to_string(transaction_2.index),
          "index" => "11",
          "type" => "JSON"
        })
        |> json_response(200)
        |> Map.get("items")

      fourth_page_response =
        conn
        |> get(path, %{
          "block_number" => Integer.to_string(a_block.number),
          "transaction_index" => Integer.to_string(transaction_1.index),
          "index" => "16",
          "type" => "JSON"
        })
        |> json_response(200)
        |> Map.get("items")

      assert Enum.count(first_page_response) == 50

      assert Enum.all?(first_page_items, fn internal_transaction ->
               Enum.any?(first_page_response, fn tile ->
                 String.contains?(tile, to_string(internal_transaction.transaction_hash)) &&
                   String.contains?(tile, "data-internal-transaction-index=\"#{internal_transaction.index}\"")
               end)
             end)

      assert Enum.count(second_page_response) == 50

      assert Enum.all?(second_page_items, fn internal_transaction ->
               Enum.any?(second_page_response, fn tile ->
                 String.contains?(tile, to_string(internal_transaction.transaction_hash)) &&
                   String.contains?(tile, "data-internal-transaction-index=\"#{internal_transaction.index}\"")
               end)
             end)

      assert Enum.count(third_page_response) == 50

      assert Enum.all?(third_page_items, fn internal_transaction ->
               Enum.any?(third_page_response, fn tile ->
                 String.contains?(tile, to_string(internal_transaction.transaction_hash)) &&
                   String.contains?(tile, "data-internal-transaction-index=\"#{internal_transaction.index}\"")
               end)
             end)

      assert Enum.count(fourth_page_response) == 15

      assert Enum.all?(fourth_page_items, fn internal_transaction ->
               Enum.any?(fourth_page_response, fn tile ->
                 String.contains?(tile, to_string(internal_transaction.transaction_hash)) &&
                   String.contains?(tile, "data-internal-transaction-index=\"#{internal_transaction.index}\"")
               end)
             end)
    end

    test "next_page_params exist if not on last page", %{conn: conn} do
      address = insert(:address)
      block = %Block{number: number} = insert(:block, number: 7000)

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
          index: index,
          block_number: transaction.block_number,
          transaction_index: transaction.index,
          block_hash: transaction.block_hash,
          block_index: index
        )
      end)

      conn =
        get(
          conn,
          address_internal_transaction_path(BlockScoutWeb.Endpoint, :index, Address.checksum(address.hash), %{
            "type" => "JSON"
          })
        )

      expected_response =
        address_internal_transaction_path(BlockScoutWeb.Endpoint, :index, address.hash, %{
          block_number: number,
          index: 11,
          transaction_index: transaction_index,
          items_count: "50"
        })

      assert expected_response == json_response(conn, 200)["next_page_path"]
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
          index: index,
          block_hash: transaction.block_hash,
          block_index: index,
          block_number: transaction.block_number
        )
      end)

      conn =
        get(
          conn,
          address_internal_transaction_path(BlockScoutWeb.Endpoint, :index, Address.checksum(address.hash), %{
            "type" => "JSON"
          })
        )

      assert %{"next_page_path" => nil} = json_response(conn, 200)
    end
  end
end
