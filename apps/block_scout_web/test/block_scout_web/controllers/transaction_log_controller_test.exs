defmodule BlockScoutWeb.TransactionLogControllerTest do
  use BlockScoutWeb.ConnCase

  import Mox

  import BlockScoutWeb.WebRouter.Helpers, only: [transaction_log_path: 3]

  alias Explorer.Celo.CacheHelper
  alias Explorer.Chain.Address
  alias Explorer.ExchangeRates.Token

  setup :set_mox_global

  setup do
    CacheHelper.set_test_addresses(%{
      "Governance" => "0xD533Ca259b330c7A88f74E000a3FaEa2d63B7972"
    })

    :ok
  end

  describe "GET index/2" do
    test "with invalid transaction hash", %{conn: conn} do
      conn = get(conn, transaction_log_path(conn, :index, "invalid_transaction_string"))

      assert html_response(conn, 422)
    end

    test "with valid transaction hash without transaction", %{conn: conn} do
      conn =
        get(
          conn,
          transaction_log_path(conn, :index, "0x3a3eb134e6792ce9403ea4188e5e79693de9e4c94e499db132be086400da79e6")
        )

      assert html_response(conn, 404)
    end

    test "returns logs for the transaction", %{conn: conn} do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      address = insert(:address)

      insert(:log,
        address: address,
        transaction: transaction,
        block: transaction.block,
        block_number: transaction.block_number
      )

      conn = get(conn, transaction_log_path(conn, :index, transaction), %{type: "JSON"})

      {:ok, %{"items" => items}} = conn.resp_body |> Poison.decode()
      first_log = List.first(items)

      assert String.contains?(first_log, Address.checksum(address.hash))
    end

    test "returns logs for the transaction with nil to_address", %{conn: conn} do
      transaction =
        :transaction
        |> insert(to_address: nil)
        |> with_block()

      address = insert(:address)

      insert(:log,
        address: address,
        transaction: transaction,
        block: transaction.block,
        block_number: transaction.block_number
      )

      conn = get(conn, transaction_log_path(conn, :index, transaction), %{type: "JSON"})

      {:ok, %{"items" => items}} = conn.resp_body |> Poison.decode()
      first_log = List.first(items)

      assert String.contains?(first_log, Address.checksum(address.hash))
    end

    test "assigns no logs when there are none", %{conn: conn} do
      transaction = insert(:transaction)
      path = transaction_log_path(conn, :index, transaction)

      conn = get(conn, path, %{type: "JSON"})

      {:ok, %{"items" => items}} = conn.resp_body |> Poison.decode()

      assert Enum.empty?(items)
    end

    test "returns next page of results based on last seen transaction log", %{conn: conn} do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      log =
        insert(:log,
          transaction: transaction,
          index: 1,
          block: transaction.block,
          block_number: transaction.block_number
        )

      second_page_indexes =
        2..51
        |> Enum.map(fn index ->
          insert(:log,
            transaction: transaction,
            index: index,
            block: transaction.block,
            block_number: transaction.block_number
          )
        end)
        |> Enum.map(& &1.index)

      conn =
        get(conn, transaction_log_path(conn, :index, transaction), %{
          "index" => Integer.to_string(log.index),
          "block_number" => Integer.to_string(transaction.block_number),
          "type" => "JSON"
        })

      {:ok, %{"items" => items}} = conn.resp_body |> Poison.decode()

      assert Enum.count(items) == Enum.count(second_page_indexes)
    end

    test "next_page_path exists if not on last page", %{conn: conn} do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      1..60
      |> Enum.map(fn index ->
        insert(:log,
          transaction: transaction,
          index: index,
          block: transaction.block,
          block_number: transaction.block_number
        )
      end)

      conn = get(conn, transaction_log_path(conn, :index, transaction), %{type: "JSON"})

      {:ok, %{"next_page_path" => path}} = conn.resp_body |> Poison.decode()

      assert path
    end

    test "next_page_path is empty if on last page", %{conn: conn} do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      conn = get(conn, transaction_log_path(conn, :index, transaction), %{type: "JSON"})

      {:ok, %{"next_page_path" => path}} = conn.resp_body |> Poison.decode()

      refute path
    end
  end

  test "includes USD exchange rate value for address in assigns", %{conn: conn} do
    EthereumJSONRPC.Mox
    |> expect(:json_rpc, fn %{id: _id, method: "net_version", params: []}, _options ->
      {:ok, "100"}
    end)

    transaction = insert(:transaction)

    conn = get(conn, transaction_log_path(BlockScoutWeb.Endpoint, :index, transaction.hash))

    assert %Token{} = conn.assigns.exchange_rate
  end

  test "loads for transactions that created a contract", %{conn: conn} do
    EthereumJSONRPC.Mox
    |> expect(:json_rpc, fn %{id: _id, method: "net_version", params: []}, _options ->
      {:ok, "100"}
    end)

    contract_address = insert(:contract_address)

    transaction =
      :transaction
      |> insert(to_address: nil)
      |> with_contract_creation(contract_address)

    conn = get(conn, transaction_log_path(conn, :index, transaction))
    assert html_response(conn, 200)
  end
end
