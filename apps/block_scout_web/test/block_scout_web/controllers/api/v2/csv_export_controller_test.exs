defmodule BlockScoutWeb.Api.V2.CsvExportControllerTest do
  use BlockScoutWeb.ConnCase, async: true
  use ExUnit.Case, async: false
  use Oban.Testing, repo: Explorer.Repo

  use Utils.CompileTimeEnvHelper, chain_identity: [:explorer, :chain_identity]

  alias Explorer.Chain.Address
  import Mox

  setup :verify_on_exit!

  describe "GET token-transfers-csv/2" do
    setup do
      csv_setup()
    end

    test "do not export token transfers to csv after rate limit is reached (1 per hour) without recaptcha recaptcha_response provided",
         %{conn: conn} do
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
        conn
        |> get("/api/v2/addresses/#{Address.checksum(address.hash)}/token-transfers/csv", %{
          "from_period" => from_period,
          "to_period" => to_period
        })

      assert conn.status == 200

      conn =
        Phoenix.ConnTest.build_conn()
        |> put_req_header("user-agent", "test-agent")
        |> get("/api/v2/addresses/#{Address.checksum(address.hash)}/token-transfers/csv", %{
          "from_period" => from_period,
          "to_period" => to_period
        })

      assert conn.status == 429
    end

    test "do not export token transfers to csv after rate limit is reached without recaptcha passed", %{
      conn: conn,
      v2_secret_key: recaptcha_secret_key
    } do
      expected_body = "secret=#{recaptcha_secret_key}&response=123"

      Tesla.Test.expect_tesla_call(
        times: 1,
        returns: fn %{body: ^expected_body}, _opts ->
          {:ok,
           %Tesla.Env{
             status: 200,
             body: Jason.encode!(%{"success" => false})
           }}
        end
      )

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
          "from_period" => from_period,
          "to_period" => to_period
        })

      assert conn.status == 200

      conn =
        Phoenix.ConnTest.build_conn()
        |> put_req_header("recaptcha-v2-response", "123")
        |> put_req_header("user-agent", "test-agent")
        |> get("/api/v2/addresses/#{Address.checksum(address.hash)}/token-transfers/csv", %{
          "from_period" => from_period,
          "to_period" => to_period
        })

      assert conn.status == 429
    end

    test "exports token transfers to csv after rate limit is reached without recaptcha if recaptcha is disabled", %{
      conn: conn
    } do
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
          "from_period" => from_period,
          "to_period" => to_period
        })

      assert conn.status == 200
      assert conn.resp_body |> String.split("\n") |> Enum.count() == 4

      conn =
        Phoenix.ConnTest.build_conn()
        |> put_req_header("user-agent", "test-agent")
        |> get("/api/v2/addresses/#{Address.checksum(address.hash)}/token-transfers/csv", %{
          "from_period" => from_period,
          "to_period" => to_period
        })

      assert conn.status == 200
      assert conn.resp_body |> String.split("\n") |> Enum.count() == 4

      Application.put_env(:block_scout_web, :recaptcha, init_config)
    end

    test "exports token transfers to csv", %{conn: conn, v2_secret_key: recaptcha_secret_key} do
      expected_body = "secret=#{recaptcha_secret_key}&response=123"

      Tesla.Test.expect_tesla_call(
        times: 1,
        returns: fn %{body: ^expected_body}, _opts ->
          {:ok,
           %Tesla.Env{
             status: 200,
             body:
               Jason.encode!(%{
                 "success" => true,
                 "hostname" => Application.get_env(:block_scout_web, BlockScoutWeb.Endpoint)[:url][:host]
               })
           }}
        end
      )

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
          "from_period" => from_period,
          "to_period" => to_period
        })

      assert conn.status == 200
      assert conn.resp_body |> String.split("\n") |> Enum.count() == 4

      conn =
        Phoenix.ConnTest.build_conn()
        |> put_req_header("recaptcha-v2-response", "123")
        |> put_req_header("user-agent", "test-agent")
        |> get("/api/v2/addresses/#{Address.checksum(address.hash)}/token-transfers/csv", %{
          "from_period" => from_period,
          "to_period" => to_period
        })

      assert conn.status == 200
      assert conn.resp_body |> String.split("\n") |> Enum.count() == 4
    end
  end

  describe "GET transactions_csv/2" do
    setup do
      csv_setup()
    end

    test "exports transactions to csv when recaptcha is disabled", %{conn: conn} do
      init_config = Application.get_env(:block_scout_web, :recaptcha)
      Application.put_env(:block_scout_web, :recaptcha, is_disabled: true)

      address = insert(:address)

      :transaction
      |> insert(from_address: address)
      |> with_block()

      {:ok, now} = DateTime.now("Etc/UTC")
      from_period = DateTime.add(now, -1, :minute) |> DateTime.to_iso8601()
      to_period = now |> DateTime.to_iso8601()

      conn =
        get(conn, "/api/v2/addresses/#{Address.checksum(address.hash)}/transactions/csv", %{
          "from_period" => from_period,
          "to_period" => to_period
        })

      assert conn.status == 200
      assert conn.resp_body =~ "TxHash"
      assert conn.resp_body |> String.split("\n") |> Enum.count() >= 2

      Application.put_env(:block_scout_web, :recaptcha, init_config)
    end

    test "download csv file with transactions", %{conn: conn, v2_secret_key: recaptcha_secret_key} do
      expected_body = "secret=#{recaptcha_secret_key}&response=123"

      Tesla.Test.expect_tesla_call(
        times: 1,
        returns: fn %{body: ^expected_body}, _opts ->
          {:ok,
           %Tesla.Env{
             status: 200,
             body:
               Jason.encode!(%{
                 "success" => true,
                 "hostname" => Application.get_env(:block_scout_web, BlockScoutWeb.Endpoint)[:url][:host]
               })
           }}
        end
      )

      address = insert(:address)

      :transaction
      |> insert(from_address: address)
      |> with_block()

      :transaction
      |> insert(from_address: address)
      |> with_block()

      {:ok, now} = DateTime.now("Etc/UTC")

      from_period = DateTime.add(now, -1, :minute) |> DateTime.to_iso8601() |> to_string()
      to_period = now |> DateTime.to_iso8601() |> to_string()

      conn =
        get(conn, "/api/v2/addresses/#{Address.checksum(address.hash)}/transactions/csv", %{
          "from_period" => from_period,
          "to_period" => to_period
        })

      assert conn.status == 200
      assert conn.resp_body |> String.split("\n") |> Enum.count() == 4

      conn =
        Phoenix.ConnTest.build_conn()
        |> put_req_header("recaptcha-v2-response", "123")
        |> put_req_header("user-agent", "test-agent")
        |> get("/api/v2/addresses/#{Address.checksum(address.hash)}/transactions/csv", %{
          "from_period" => from_period,
          "to_period" => to_period
        })

      assert conn.status == 200
      assert conn.resp_body |> String.split("\n") |> Enum.count() == 4
    end
  end

  describe "GET internal_transactions_csv/2" do
    setup do
      csv_setup()
    end

    test "exports internal transactions to csv when recaptcha is disabled", %{conn: conn} do
      init_config = Application.get_env(:block_scout_web, :recaptcha)
      Application.put_env(:block_scout_web, :recaptcha, is_disabled: true)

      address = insert(:address)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(:internal_transaction,
        index: 0,
        transaction: transaction,
        from_address: address,
        block_number: transaction.block_number,
        block_hash: transaction.block_hash,
        transaction_index: transaction.index
      )

      {:ok, now} = DateTime.now("Etc/UTC")
      from_period = DateTime.add(now, -1, :day) |> DateTime.to_iso8601()
      to_period = now |> DateTime.to_iso8601()

      conn =
        get(conn, "/api/v2/addresses/#{Address.checksum(address.hash)}/internal-transactions/csv", %{
          "from_period" => from_period,
          "to_period" => to_period
        })

      assert conn.status == 200
      assert conn.resp_body =~ "TxHash"
      assert conn.resp_body |> String.split("\n") |> Enum.count() >= 2

      Application.put_env(:block_scout_web, :recaptcha, init_config)
    end

    test "download csv file with internal transactions", %{conn: conn, v2_secret_key: recaptcha_secret_key} do
      expected_body = "secret=#{recaptcha_secret_key}&response=123"

      Tesla.Test.expect_tesla_call(
        times: 1,
        returns: fn %{body: ^expected_body}, _opts ->
          {:ok,
           %Tesla.Env{
             status: 200,
             body:
               Jason.encode!(%{
                 "success" => true,
                 "hostname" => Application.get_env(:block_scout_web, BlockScoutWeb.Endpoint)[:url][:host]
               })
           }}
        end
      )

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
        transaction_index: transaction_1.index
      )

      insert(:internal_transaction,
        index: 1,
        transaction: transaction_2,
        to_address: address,
        block_number: transaction_2.block_number,
        block_hash: transaction_2.block_hash,
        transaction_index: transaction_2.index
      )

      insert(:internal_transaction,
        index: 2,
        transaction: transaction_3,
        created_contract_address: address,
        to_address: nil,
        block_number: transaction_3.block_number,
        block_hash: transaction_3.block_hash,
        transaction_index: transaction_3.index
      )

      {:ok, now} = DateTime.now("Etc/UTC")

      from_period = DateTime.add(now, -1, :day) |> DateTime.to_iso8601()
      to_period = now |> DateTime.to_iso8601()

      conn =
        get(conn, "/api/v2/addresses/#{Address.checksum(address.hash)}/internal-transactions/csv", %{
          "from_period" => from_period,
          "to_period" => to_period
        })

      assert conn.status == 200
      assert conn.resp_body |> String.split("\n") |> Enum.count() == 5

      conn =
        Phoenix.ConnTest.build_conn()
        |> put_req_header("recaptcha-v2-response", "123")
        |> put_req_header("user-agent", "test-agent")
        |> get("/api/v2/addresses/#{Address.checksum(address.hash)}/internal-transactions/csv", %{
          "from_period" => from_period,
          "to_period" => to_period
        })

      assert conn.status == 200
      assert conn.resp_body |> String.split("\n") |> Enum.count() == 5
    end
  end

  describe "GET /api/v2/csv-exports/:uuid" do
    setup do
      bypass = Bypass.open()
      original_config = Application.get_env(:explorer, Explorer.Chain.CsvExport)
      original_tesla = Application.get_env(:tesla, :adapter)

      config =
        (original_config || [])
        |> Keyword.put(:max_pending_tasks_per_ip, 5)
        |> Keyword.put(:gokapi_url, "http://localhost:#{bypass.port}")
        |> Keyword.put(:gokapi_api_key, "test-api-key")
        |> Keyword.put(:gokapi_upload_expiry_days, 1)
        |> Keyword.put(:gokapi_upload_allowed_downloads, 1)

      Application.put_env(:explorer, Explorer.Chain.CsvExport, config)
      Application.put_env(:tesla, :adapter, Tesla.Adapter.Hackney)

      on_exit(fn ->
        Application.put_env(:tesla, :adapter, original_tesla)

        if original_config do
          Application.put_env(:explorer, Explorer.Chain.CsvExport, original_config)
        else
          Application.delete_env(:explorer, Explorer.Chain.CsvExport)
        end
      end)

      {:ok, bypass: bypass}
    end

    test "returns 200 with pending status for pending request", %{conn: conn} do
      ip_hash = :crypto.hash(:sha256, "127.0.0.1")

      request =
        %Explorer.Chain.CsvExport.Request{
          remote_ip_hash: ip_hash,
          file_id: nil,
          status: :pending
        }
        |> Explorer.Repo.insert!()

      conn = get(conn, "/api/v2/csv-exports/#{request.id}")

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["status"] == "pending"
      assert body["file_id"] == nil
    end

    test "returns 200 with completed status and file_id for completed request", %{
      conn: conn,
      bypass: bypass
    } do
      ip_hash = :crypto.hash(:sha256, "127.0.0.1")
      file_id = "test-file-123"

      request =
        %Explorer.Chain.CsvExport.Request{
          remote_ip_hash: ip_hash,
          file_id: file_id,
          status: :completed
        }
        |> Explorer.Repo.insert!()

      Bypass.expect(bypass, fn conn ->
        assert conn.request_path =~ "/api/files/list/#{file_id}"
        Plug.Conn.resp(conn, 200, "")
      end)

      conn = get(conn, "/api/v2/csv-exports/#{request.id}")

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["status"] == "completed"
      assert body["file_id"] == file_id
    end

    test "returns 200 with failed status for failed request", %{conn: conn} do
      ip_hash = :crypto.hash(:sha256, "127.0.0.1")

      request =
        %Explorer.Chain.CsvExport.Request{
          remote_ip_hash: ip_hash,
          file_id: nil,
          status: :failed
        }
        |> Explorer.Repo.insert!()

      conn = get(conn, "/api/v2/csv-exports/#{request.id}")

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["status"] == "failed"
      assert body["file_id"] == nil
    end

    test "returns 404 for non-existent UUID", %{conn: conn} do
      fake_uuid = "11111111-1111-1111-1111-111111111111"

      conn = get(conn, "/api/v2/csv-exports/#{fake_uuid}")

      assert conn.status == 404
    end

    test "returns 422 for malformed UUID", %{conn: conn} do
      conn = get(conn, "/api/v2/csv-exports/not-a-valid-uuid")

      assert conn.status == 422
    end

    test "returns 404 when file is removed on gokapi", %{
      conn: conn,
      bypass: bypass
    } do
      ip_hash = :crypto.hash(:sha256, "127.0.0.1")
      file_id = "test-file-123"

      request =
        %Explorer.Chain.CsvExport.Request{
          remote_ip_hash: ip_hash,
          file_id: file_id,
          status: :completed
        }
        |> Explorer.Repo.insert!()

      Bypass.expect(bypass, fn conn ->
        assert conn.request_path =~ "/api/files/list/#{file_id}"
        Plug.Conn.resp(conn, 404, "")
      end)

      conn = get(conn, "/api/v2/csv-exports/#{request.id}")

      assert conn.status == 404
    end
  end

  describe "async mode export endpoints" do
    setup do
      csv_setup()
      bypass = Bypass.open()
      original_config = Application.get_env(:explorer, Explorer.Chain.CsvExport)
      original_tesla = Application.get_env(:tesla, :adapter)

      config =
        (original_config || [])
        |> Keyword.put(:async?, true)
        |> Keyword.put(:max_pending_tasks_per_ip, 3)
        |> Keyword.put(:gokapi_url, "http://localhost:#{bypass.port}")
        |> Keyword.put(:gokapi_api_key, "test-api-key")
        |> Keyword.put(:gokapi_upload_expiry_days, 1)
        |> Keyword.put(:gokapi_upload_allowed_downloads, 1)

      Application.put_env(:explorer, Explorer.Chain.CsvExport, config)
      Application.put_env(:tesla, :adapter, Tesla.Adapter.Hackney)

      on_exit(fn ->
        Application.put_env(:tesla, :adapter, original_tesla)

        if original_config do
          Application.put_env(:explorer, Explorer.Chain.CsvExport, original_config)
        else
          Application.delete_env(:explorer, Explorer.Chain.CsvExport)
        end
      end)

      {:ok, bypass: bypass}
    end

    test "returns 202 with request_id for token-transfers export when async enabled", %{conn: conn} do
      address = insert(:address)

      :transaction
      |> insert(from_address: address)
      |> with_block()

      {:ok, now} = DateTime.now("Etc/UTC")
      from_period = DateTime.add(now, -1, :minute) |> DateTime.to_iso8601()
      to_period = now |> DateTime.to_iso8601()

      conn =
        get(conn, "/api/v2/addresses/#{Address.checksum(address.hash)}/token-transfers/csv", %{
          "from_period" => from_period,
          "to_period" => to_period
        })

      assert conn.status == 202
      body = Jason.decode!(conn.resp_body)
      assert Map.has_key?(body, "request_id")
      assert is_binary(body["request_id"])
    end

    test "returns 202 with request_id for transactions export when async enabled", %{conn: conn} do
      address = insert(:address)

      :transaction
      |> insert(from_address: address)
      |> with_block()

      {:ok, now} = DateTime.now("Etc/UTC")
      from_period = DateTime.add(now, -1, :minute) |> DateTime.to_iso8601()
      to_period = now |> DateTime.to_iso8601()

      conn =
        get(conn, "/api/v2/addresses/#{Address.checksum(address.hash)}/transactions/csv", %{
          "from_period" => from_period,
          "to_period" => to_period
        })

      assert conn.status == 202
      body = Jason.decode!(conn.resp_body)
      assert Map.has_key?(body, "request_id")
      assert is_binary(body["request_id"])
    end

    test "returns 202 with request_id for internal-transactions export when async enabled", %{
      conn: conn
    } do
      address = insert(:address)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(:internal_transaction,
        index: 0,
        transaction: transaction,
        from_address: address,
        block_number: transaction.block_number,
        block_hash: transaction.block_hash,
        transaction_index: transaction.index
      )

      {:ok, now} = DateTime.now("Etc/UTC")
      from_period = DateTime.add(now, -1, :day) |> DateTime.to_iso8601()
      to_period = now |> DateTime.to_iso8601()

      conn =
        get(conn, "/api/v2/addresses/#{Address.checksum(address.hash)}/internal-transactions/csv", %{
          "from_period" => from_period,
          "to_period" => to_period
        })

      assert conn.status == 202
      body = Jason.decode!(conn.resp_body)
      assert Map.has_key?(body, "request_id")
      assert is_binary(body["request_id"])
    end

    test "returns 202 with request_id for logs export when async enabled", %{conn: conn} do
      address = insert(:address)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(:log,
        address: address,
        index: 0,
        transaction: transaction,
        block: transaction.block,
        block_number: transaction.block_number
      )

      {:ok, now} = DateTime.now("Etc/UTC")
      from_period = DateTime.add(now, -1, :minute) |> DateTime.to_iso8601()
      to_period = now |> DateTime.to_iso8601()

      conn =
        get(conn, "/api/v2/addresses/#{Address.checksum(address.hash)}/logs/csv", %{
          "from_period" => from_period,
          "to_period" => to_period
        })

      assert conn.status == 202
      body = Jason.decode!(conn.resp_body)
      assert Map.has_key?(body, "request_id")
      assert is_binary(body["request_id"])
    end

    test "returns 202 with request_id for token holders export when async enabled", %{conn: conn} do
      token = insert(:token, type: "ERC-20", decimals: 18)

      insert(:address_current_token_balance,
        token_contract_address_hash: token.contract_address_hash,
        address: insert(:address),
        value: 100_000_000_000_000_000_000
      )

      conn = get(conn, "/api/v2/tokens/#{Address.checksum(token.contract_address_hash)}/holders/csv")

      assert conn.status == 202
      body = Jason.decode!(conn.resp_body)
      assert Map.has_key?(body, "request_id")
      assert is_binary(body["request_id"])
    end

    if @chain_identity == {:optimism, :celo} do
      test "returns 202 with request_id for celo election-rewards export when async enabled", %{
        conn: conn
      } do
        address = insert(:address)

        {:ok, now} = DateTime.now("Etc/UTC")
        from_period = DateTime.add(now, -1, :day) |> DateTime.to_iso8601()
        to_period = now |> DateTime.to_iso8601()

        conn =
          get(conn, "/api/v2/addresses/#{Address.checksum(address.hash)}/celo/election-rewards/csv", %{
            "from_period" => from_period,
            "to_period" => to_period
          })

        assert conn.status == 202
        body = Jason.decode!(conn.resp_body)
        assert Map.has_key?(body, "request_id")
        assert is_binary(body["request_id"])
      end
    end

    test "returns 429 when pending request limit is reached", %{conn: conn} do
      address = insert(:address)

      :transaction
      |> insert(from_address: address)
      |> with_block()

      {:ok, now} = DateTime.now("Etc/UTC")
      from_period = DateTime.add(now, -1, :minute) |> DateTime.to_iso8601()
      to_period = now |> DateTime.to_iso8601()

      args = %{
        address_hash: to_string(address.hash),
        from_period: from_period,
        to_period: to_period,
        filter_type: nil,
        filter_value: nil,
        show_scam_tokens?: nil,
        module: "Elixir.Explorer.Chain.CsvExport.Address.TokenTransfers"
      }

      1..3
      |> Enum.each(fn _ ->
        {:ok, _} = Explorer.Chain.CsvExport.Request.create("127.0.0.1", args)
      end)

      conn =
        conn
        |> get("/api/v2/addresses/#{Address.checksum(address.hash)}/token-transfers/csv", %{
          "from_period" => from_period,
          "to_period" => to_period
        })

      assert conn.status == 429
    end
  end

  describe "GET /api/v2/tokens/:hash/holders/csv" do
    setup do
      result = csv_setup()

      original_config = Application.get_env(:explorer, Explorer.Chain.CsvExport)
      config = (original_config || []) |> Keyword.put(:async?, false)
      Application.put_env(:explorer, Explorer.Chain.CsvExport, config)

      on_exit(fn ->
        if original_config do
          Application.put_env(:explorer, Explorer.Chain.CsvExport, original_config)
        else
          Application.delete_env(:explorer, Explorer.Chain.CsvExport)
        end
      end)

      result
    end

    test "exports token holders to csv in sync mode", %{conn: conn} do
      token = insert(:token, type: "ERC-20", decimals: 18)

      insert(:address_current_token_balance,
        token_contract_address_hash: token.contract_address_hash,
        address: insert(:address),
        value: 100_000_000_000_000_000_000
      )

      conn = get(conn, "/api/v2/tokens/#{Address.checksum(token.contract_address_hash)}/holders/csv")

      assert conn.status == 200
      assert conn.resp_body =~ "HolderAddress"
      assert conn.resp_body =~ "Balance"
    end

    test "returns 404 for non-existent token", %{conn: conn} do
      fake_hash = "0x0000000000000000000000000000000000000001"

      conn = get(conn, "/api/v2/tokens/#{fake_hash}/holders/csv")

      assert conn.status == 404
    end

    test "returns 422 for invalid token hash", %{conn: conn} do
      conn = get(conn, "/api/v2/tokens/not-a-valid-hash/holders/csv")

      assert conn.status == 422
    end
  end

  describe "GET logs_csv/2" do
    setup do
      csv_setup()
    end

    test "exports logs to csv when recaptcha is disabled", %{conn: conn} do
      init_config = Application.get_env(:block_scout_web, :recaptcha)
      Application.put_env(:block_scout_web, :recaptcha, is_disabled: true)

      address = insert(:address)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      insert(:log,
        address: address,
        index: 0,
        transaction: transaction,
        block: transaction.block,
        block_number: transaction.block_number
      )

      {:ok, now} = DateTime.now("Etc/UTC")
      from_period = DateTime.add(now, -1, :minute) |> DateTime.to_iso8601()
      to_period = now |> DateTime.to_iso8601()

      conn =
        get(conn, "/api/v2/addresses/#{Address.checksum(address.hash)}/logs/csv", %{
          "from_period" => from_period,
          "to_period" => to_period
        })

      assert conn.status == 200
      assert conn.resp_body =~ "TxHash"
      assert conn.resp_body |> String.split("\n") |> Enum.count() >= 2

      Application.put_env(:block_scout_web, :recaptcha, init_config)
    end

    test "download csv file with logs", %{conn: conn, v2_secret_key: recaptcha_secret_key} do
      expected_body = "secret=#{recaptcha_secret_key}&response=123"

      Tesla.Test.expect_tesla_call(
        times: 1,
        returns: fn %{body: ^expected_body}, _opts ->
          {:ok,
           %Tesla.Env{
             status: 200,
             body:
               Jason.encode!(%{
                 "success" => true,
                 "hostname" => Application.get_env(:block_scout_web, BlockScoutWeb.Endpoint)[:url][:host]
               })
           }}
        end
      )

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
          "from_period" => from_period,
          "to_period" => to_period
        })

      assert conn.status == 200
      assert conn.resp_body |> String.split("\n") |> Enum.count() == 5

      conn =
        Phoenix.ConnTest.build_conn()
        |> put_req_header("recaptcha-v2-response", "123")
        |> put_req_header("user-agent", "test-agent")
        |> get("/api/v2/addresses/#{Address.checksum(address.hash)}/logs/csv", %{
          "from_period" => from_period,
          "to_period" => to_period
        })

      assert conn.status == 200
      assert conn.resp_body |> String.split("\n") |> Enum.count() == 5
    end

    test "handles null filter", %{conn: conn} do
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
          "filter_type" => "null",
          "filter_value" => "null",
          "from_period" => from_period,
          "to_period" => to_period
        })

      assert conn.status == 200
      assert conn.resp_body |> String.split("\n") |> Enum.count() == 3
    end
  end

  if @chain_identity == {:optimism, :celo} do
    describe "GET celo/election-rewards/csv" do
      setup do
        csv_setup()
      end

      test "exports Celo election rewards to csv when recaptcha is disabled", %{conn: conn} do
        init_config = Application.get_env(:block_scout_web, :recaptcha)
        Application.put_env(:block_scout_web, :recaptcha, is_disabled: true)

        address = insert(:address)

        {:ok, now} = DateTime.now("Etc/UTC")
        from_period = DateTime.add(now, -1, :day) |> DateTime.to_iso8601()
        to_period = now |> DateTime.to_iso8601()

        conn =
          get(conn, "/api/v2/addresses/#{Address.checksum(address.hash)}/celo/election-rewards/csv", %{
            "from_period" => from_period,
            "to_period" => to_period
          })

        assert conn.status == 200
        assert conn.resp_body =~ "EpochNumber"
        assert conn.resp_body =~ "BlockNumber"

        Application.put_env(:block_scout_web, :recaptcha, init_config)
      end
    end
  end

  defp csv_setup() do
    original_config = :persistent_term.get(:rate_limit_config)
    old_recaptcha_env = Application.get_env(:block_scout_web, :recaptcha)
    original_api_rate_limit = Application.get_env(:block_scout_web, :api_rate_limit)

    v2_secret_key = "v2_secret_key"
    v3_secret_key = "v3_secret_key"

    Application.put_env(:block_scout_web, :recaptcha,
      v2_secret_key: v2_secret_key,
      v3_secret_key: v3_secret_key,
      is_disabled: false
    )

    Application.put_env(:block_scout_web, :api_rate_limit, Keyword.put(original_api_rate_limit, :disabled, false))

    config = %{
      static_match: %{},
      wildcard_match: %{},
      parametrized_match: %{
        ["api", "v2", "addresses", ":param", "election-rewards", "csv"] => %{
          ip: %{period: 3_600_000, limit: 1},
          recaptcha_to_bypass_429: true,
          bucket_key_prefix: "api/v2/addresses/:param/election-rewards/csv_",
          isolate_rate_limit?: true
        },
        ["api", "v2", "addresses", ":param", "celo", "election-rewards", "csv"] => %{
          ip: %{period: 3_600_000, limit: 1},
          recaptcha_to_bypass_429: true,
          bucket_key_prefix: "api/v2/addresses/:param/celo/election-rewards/csv_",
          isolate_rate_limit?: true
        },
        ["api", "v2", "addresses", ":param", "internal-transactions", "csv"] => %{
          ip: %{period: 3_600_000, limit: 1},
          recaptcha_to_bypass_429: true,
          bucket_key_prefix: "api/v2/addresses/:param/internal-transactions/csv_",
          isolate_rate_limit?: true
        },
        ["api", "v2", "addresses", ":param", "logs", "csv"] => %{
          ip: %{period: 3_600_000, limit: 1},
          recaptcha_to_bypass_429: true,
          bucket_key_prefix: "api/v2/addresses/:param/logs/csv_",
          isolate_rate_limit?: true
        },
        ["api", "v2", "addresses", ":param", "token-transfers", "csv"] => %{
          ip: %{period: 3_600_000, limit: 1},
          recaptcha_to_bypass_429: true,
          bucket_key_prefix: "api/v2/addresses/:param/token-transfers/csv_",
          isolate_rate_limit?: true
        },
        ["api", "v2", "addresses", ":param", "transactions", "csv"] => %{
          ip: %{period: 3_600_000, limit: 1},
          recaptcha_to_bypass_429: true,
          bucket_key_prefix: "api/v2/addresses/:param/transactions/csv_",
          isolate_rate_limit?: true
        },
        ["api", "v2", "tokens", ":param", "holders", "csv"] => %{
          ip: %{period: 3_600_000, limit: 1},
          recaptcha_to_bypass_429: true,
          bucket_key_prefix: "api/v2/tokens/:param/holders/csv_",
          isolate_rate_limit?: true
        }
      }
    }

    :persistent_term.put(:rate_limit_config, config)

    on_exit(fn ->
      :persistent_term.put(:rate_limit_config, original_config)
      Application.put_env(:block_scout_web, :recaptcha, old_recaptcha_env)
      :ets.delete_all_objects(BlockScoutWeb.RateLimit.Hammer.ETS)
      Application.put_env(:block_scout_web, :api_rate_limit, original_api_rate_limit)
    end)

    {:ok, %{v2_secret_key: v2_secret_key, v3_secret_key: v3_secret_key}}
  end
end
