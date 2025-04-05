defmodule BlockScoutWeb.Api.V2.CsvExportControllerTest do
  use BlockScoutWeb.ConnCase, async: true
  use ExUnit.Case, async: false
  alias Explorer.Chain.Address

  import Mox

  setup :verify_on_exit!

  describe "GET token-transfers-csv/2" do
    setup do
      csv_setup()
    end

    test "do not export token transfers to csv without recaptcha recaptcha_response provided", %{conn: conn} do
      address = insert(:address)

      transaction =
        :transaction
        |> insert(from_address: address)
        |> with_block()

      insert(:token_transfer, transaction: transaction, from_address: address, block_number: transaction.block_number)
      insert(:token_transfer, transaction: transaction, to_address: address, block_number: transaction.block_number)

      {:ok, now} = DateTime.now("Etc/UTC")

      from_period = DateTime.add(now, -1, :minute) |> DateTime.to_iso8601()
      to_period = now |> DateTime.to_iso8601()

      conn =
        get(conn, "/api/v2/addresses/#{Address.checksum(address.hash)}/token-transfers/csv", %{
          "address_id" => Address.checksum(address.hash),
          "from_period" => from_period,
          "to_period" => to_period
        })

      assert conn.status == 403
    end

    test "do not export token transfers to csv without recaptcha passed", %{
      conn: conn,
      v2_secret_key: recaptcha_secret_key
    } do
      expected_body = "secret=#{recaptcha_secret_key}&response=123"

      Explorer.Mox.HTTPoison
      |> expect(:post, fn _url, ^expected_body, _headers, _options ->
        {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(%{"success" => false})}}
      end)

      address = insert(:address)

      transaction =
        :transaction
        |> insert(from_address: address)
        |> with_block()

      insert(:token_transfer, transaction: transaction, from_address: address, block_number: transaction.block_number)
      insert(:token_transfer, transaction: transaction, to_address: address, block_number: transaction.block_number)

      {:ok, now} = DateTime.now("Etc/UTC")

      from_period = DateTime.add(now, -1, :minute) |> DateTime.to_iso8601()
      to_period = now |> DateTime.to_iso8601()

      conn =
        get(conn, "/api/v2/addresses/#{Address.checksum(address.hash)}/token-transfers/csv", %{
          "address_id" => Address.checksum(address.hash),
          "from_period" => from_period,
          "to_period" => to_period,
          "recaptcha_response" => "123"
        })

      assert conn.status == 403
    end

    test "exports token transfers to csv without recaptcha if recaptcha is disabled", %{conn: conn} do
      init_config = Application.get_env(:block_scout_web, :recaptcha)
      Application.put_env(:block_scout_web, :recaptcha, is_disabled: true)

      address = insert(:address)

      transaction =
        :transaction
        |> insert(from_address: address)
        |> with_block()

      insert(:token_transfer, transaction: transaction, from_address: address, block_number: transaction.block_number)
      insert(:token_transfer, transaction: transaction, to_address: address, block_number: transaction.block_number)

      {:ok, now} = DateTime.now("Etc/UTC")

      from_period = DateTime.add(now, -1, :minute) |> DateTime.to_iso8601()
      to_period = now |> DateTime.to_iso8601()

      conn =
        get(conn, "/api/v2/addresses/#{Address.checksum(address.hash)}/token-transfers/csv", %{
          "address_id" => Address.checksum(address.hash),
          "from_period" => from_period,
          "to_period" => to_period
        })

      assert conn.resp_body |> String.split("\n") |> Enum.count() == 4

      Application.put_env(:block_scout_web, :recaptcha, init_config)
    end

    test "exports token transfers to csv", %{conn: conn, v2_secret_key: recaptcha_secret_key} do
      expected_body = "secret=#{recaptcha_secret_key}&response=123"

      Explorer.Mox.HTTPoison
      |> expect(:post, fn _url, ^expected_body, _headers, _options ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body:
             Jason.encode!(%{
               "success" => true,
               "hostname" => Application.get_env(:block_scout_web, BlockScoutWeb.Endpoint)[:url][:host]
             })
         }}
      end)

      address = insert(:address)

      transaction =
        :transaction
        |> insert(from_address: address)
        |> with_block()

      insert(:token_transfer, transaction: transaction, from_address: address, block_number: transaction.block_number)
      insert(:token_transfer, transaction: transaction, to_address: address, block_number: transaction.block_number)

      {:ok, now} = DateTime.now("Etc/UTC")

      from_period = DateTime.add(now, -1, :minute) |> DateTime.to_iso8601()
      to_period = now |> DateTime.to_iso8601()

      conn =
        get(conn, "/api/v2/addresses/#{Address.checksum(address.hash)}/token-transfers/csv", %{
          "address_id" => Address.checksum(address.hash),
          "from_period" => from_period,
          "to_period" => to_period,
          "recaptcha_response" => "123"
        })

      assert conn.resp_body |> String.split("\n") |> Enum.count() == 4
    end
  end

  describe "GET transactions_csv/2" do
    setup do
      csv_setup()
    end

    test "download csv file with transactions", %{conn: conn, v2_secret_key: recaptcha_secret_key} do
      expected_body = "secret=#{recaptcha_secret_key}&response=123"

      Explorer.Mox.HTTPoison
      |> expect(:post, fn _url, ^expected_body, _headers, _options ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body:
             Jason.encode!(%{
               "success" => true,
               "hostname" => Application.get_env(:block_scout_web, BlockScoutWeb.Endpoint)[:url][:host]
             })
         }}
      end)

      address = insert(:address)

      :transaction
      |> insert(from_address: address)
      |> with_block()

      :transaction
      |> insert(from_address: address)
      |> with_block()

      {:ok, now} = DateTime.now("Etc/UTC")

      from_period = DateTime.add(now, -1, :minute) |> DateTime.to_iso8601()
      to_period = now |> DateTime.to_iso8601()

      conn =
        get(conn, "/api/v2/addresses/#{Address.checksum(address.hash)}/transactions/csv", %{
          "address_id" => Address.checksum(address.hash),
          "from_period" => from_period,
          "to_period" => to_period,
          "recaptcha_response" => "123"
        })

      assert conn.resp_body |> String.split("\n") |> Enum.count() == 4
    end
  end

  describe "GET internal_transactions_csv/2" do
    setup do
      csv_setup()
    end

    test "download csv file with internal transactions", %{conn: conn, v2_secret_key: recaptcha_secret_key} do
      expected_body = "secret=#{recaptcha_secret_key}&response=123"

      Explorer.Mox.HTTPoison
      |> expect(:post, fn _url, ^expected_body, _headers, _options ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body:
             Jason.encode!(%{
               "success" => true,
               "hostname" => Application.get_env(:block_scout_web, BlockScoutWeb.Endpoint)[:url][:host]
             })
         }}
      end)

      address = insert(:address)

      transaction_1 =
        :transaction
        |> insert()
        |> with_block()

      transaction_2 =
        :transaction
        |> insert()
        |> with_block()

      transaction_3 =
        :transaction
        |> insert()
        |> with_block()

      insert(:internal_transaction,
        index: 3,
        transaction: transaction_1,
        from_address: address,
        block_number: transaction_1.block_number,
        block_hash: transaction_1.block_hash,
        block_index: 0,
        transaction_index: transaction_1.index
      )

      insert(:internal_transaction,
        index: 1,
        transaction: transaction_2,
        to_address: address,
        block_number: transaction_2.block_number,
        block_hash: transaction_2.block_hash,
        block_index: 1,
        transaction_index: transaction_2.index
      )

      insert(:internal_transaction,
        index: 2,
        transaction: transaction_3,
        created_contract_address: address,
        block_number: transaction_3.block_number,
        block_hash: transaction_3.block_hash,
        block_index: 2,
        transaction_index: transaction_3.index
      )

      {:ok, now} = DateTime.now("Etc/UTC")

      from_period = DateTime.add(now, -1, :day) |> DateTime.to_iso8601()
      to_period = now |> DateTime.to_iso8601()

      conn =
        get(conn, "/api/v2/addresses/#{Address.checksum(address.hash)}/internal-transactions/csv", %{
          "address_id" => Address.checksum(address.hash),
          "from_period" => from_period,
          "to_period" => to_period,
          "recaptcha_response" => "123"
        })

      assert conn.resp_body |> String.split("\n") |> Enum.count() == 5
    end
  end

  describe "GET logs_csv/2" do
    setup do
      csv_setup()
    end

    test "download csv file with logs", %{conn: conn, v2_secret_key: recaptcha_secret_key} do
      expected_body = "secret=#{recaptcha_secret_key}&response=123"

      Explorer.Mox.HTTPoison
      |> expect(:post, fn _url, ^expected_body, _headers, _options ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body:
             Jason.encode!(%{
               "success" => true,
               "hostname" => Application.get_env(:block_scout_web, BlockScoutWeb.Endpoint)[:url][:host]
             })
         }}
      end)

      address = insert(:address)

      transaction_1 =
        :transaction
        |> insert()
        |> with_block()

      insert(:log,
        address: address,
        index: 3,
        transaction: transaction_1,
        block: transaction_1.block,
        block_number: transaction_1.block_number
      )

      transaction_2 =
        :transaction
        |> insert()
        |> with_block()

      insert(:log,
        address: address,
        index: 1,
        transaction: transaction_2,
        block: transaction_2.block,
        block_number: transaction_2.block_number
      )

      transaction_3 =
        :transaction
        |> insert()
        |> with_block()

      insert(:log,
        address: address,
        index: 2,
        transaction: transaction_3,
        block: transaction_3.block,
        block_number: transaction_3.block_number
      )

      {:ok, now} = DateTime.now("Etc/UTC")

      from_period = DateTime.add(now, -1, :minute) |> DateTime.to_iso8601()
      to_period = now |> DateTime.to_iso8601()

      conn =
        get(conn, "/api/v2/addresses/#{Address.checksum(address.hash)}/logs/csv", %{
          "address_id" => Address.checksum(address.hash),
          "from_period" => from_period,
          "to_period" => to_period,
          "recaptcha_response" => "123"
        })

      assert conn.resp_body |> String.split("\n") |> Enum.count() == 5
    end

    test "handles null filter", %{conn: conn, v2_secret_key: recaptcha_secret_key} do
      expected_body = "secret=#{recaptcha_secret_key}&response=123"

      Explorer.Mox.HTTPoison
      |> expect(:post, fn _url, ^expected_body, _headers, _options ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body:
             Jason.encode!(%{
               "success" => true,
               "hostname" => Application.get_env(:block_scout_web, BlockScoutWeb.Endpoint)[:url][:host]
             })
         }}
      end)

      address = insert(:address)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(:log,
        address: address,
        index: 3,
        transaction: transaction,
        block: transaction.block,
        block_number: transaction.block_number
      )

      {:ok, now} = DateTime.now("Etc/UTC")

      from_period = DateTime.add(now, -1, :minute) |> DateTime.to_iso8601()
      to_period = now |> DateTime.to_iso8601()

      conn =
        get(conn, "/api/v2/addresses/#{Address.checksum(address.hash)}/logs/csv", %{
          "address_id" => Address.checksum(address.hash),
          "filter_type" => "null",
          "filter_value" => "null",
          "from_period" => from_period,
          "to_period" => to_period,
          "recaptcha_response" => "123"
        })

      assert conn.resp_body |> String.split("\n") |> Enum.count() == 3
    end
  end

  defp csv_setup() do
    old_recaptcha_env = Application.get_env(:block_scout_web, :recaptcha)
    old_http_adapter = Application.get_env(:block_scout_web, :http_adapter)

    v2_secret_key = "v2_secret_key"
    v3_secret_key = "v3_secret_key"

    Application.put_env(:block_scout_web, :recaptcha,
      v2_secret_key: v2_secret_key,
      v3_secret_key: v3_secret_key,
      is_disabled: false
    )

    Application.put_env(:block_scout_web, :http_adapter, Explorer.Mox.HTTPoison)

    on_exit(fn ->
      Application.put_env(:block_scout_web, :recaptcha, old_recaptcha_env)
      Application.put_env(:block_scout_web, :http_adapter, old_http_adapter)
    end)

    {:ok, %{v2_secret_key: v2_secret_key, v3_secret_key: v3_secret_key}}
  end
end
