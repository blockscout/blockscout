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
          "address_id" => Address.checksum(address.hash),
          "from_period" => from_period,
          "to_period" => to_period
        })

      assert conn.status == 200

      conn =
        Phoenix.ConnTest.build_conn()
        |> put_req_header("user-agent", "test-agent")
        |> get("/api/v2/addresses/#{Address.checksum(address.hash)}/token-transfers/csv", %{
          "address_id" => Address.checksum(address.hash),
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
          "address_id" => Address.checksum(address.hash),
          "from_period" => from_period,
          "to_period" => to_period
        })

      assert conn.status == 200

      conn =
        Phoenix.ConnTest.build_conn()
        |> put_req_header("recaptcha-v2-response", "123")
        |> put_req_header("user-agent", "test-agent")
        |> get("/api/v2/addresses/#{Address.checksum(address.hash)}/token-transfers/csv", %{
          "address_id" => Address.checksum(address.hash),
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
          "address_id" => Address.checksum(address.hash),
          "from_period" => from_period,
          "to_period" => to_period
        })

      assert conn.status == 200
      assert conn.resp_body |> String.split("\n") |> Enum.count() == 4

      conn =
        Phoenix.ConnTest.build_conn()
        |> put_req_header("user-agent", "test-agent")
        |> get("/api/v2/addresses/#{Address.checksum(address.hash)}/token-transfers/csv", %{
          "address_id" => Address.checksum(address.hash),
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
          "address_id" => Address.checksum(address.hash),
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
          "address_id" => Address.checksum(address.hash),
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

      from_period = DateTime.add(now, -1, :minute) |> DateTime.to_iso8601()
      to_period = now |> DateTime.to_iso8601()

      conn =
        get(conn, "/api/v2/addresses/#{Address.checksum(address.hash)}/transactions/csv", %{
          "address_id" => Address.checksum(address.hash),
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
          "address_id" => Address.checksum(address.hash),
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
          "to_period" => to_period
        })

      assert conn.status == 200
      assert conn.resp_body |> String.split("\n") |> Enum.count() == 5

      conn =
        Phoenix.ConnTest.build_conn()
        |> put_req_header("recaptcha-v2-response", "123")
        |> put_req_header("user-agent", "test-agent")
        |> get("/api/v2/addresses/#{Address.checksum(address.hash)}/internal-transactions/csv", %{
          "address_id" => Address.checksum(address.hash),
          "from_period" => from_period,
          "to_period" => to_period
        })

      assert conn.status == 200
      assert conn.resp_body |> String.split("\n") |> Enum.count() == 5
    end
  end

  describe "GET logs_csv/2" do
    setup do
      csv_setup()
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
          "address_id" => Address.checksum(address.hash),
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
          "address_id" => Address.checksum(address.hash),
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
          "address_id" => Address.checksum(address.hash),
          "filter_type" => "null",
          "filter_value" => "null",
          "from_period" => from_period,
          "to_period" => to_period
        })

      assert conn.status == 200
      assert conn.resp_body |> String.split("\n") |> Enum.count() == 3
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
