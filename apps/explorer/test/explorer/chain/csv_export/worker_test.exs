defmodule Explorer.Chain.CsvExport.WorkerTest do
  use Explorer.DataCase, async: false
  use Oban.Testing, repo: Explorer.Repo

  alias Explorer.Chain.CsvExport.{Request, Worker}
  alias Plug.Conn

  setup do
    bypass = Bypass.open()
    original_config = Application.get_env(:explorer, Explorer.Chain.CsvExport)
    original_tesla = Application.get_env(:tesla, :adapter)

    config =
      (original_config || [])
      |> Keyword.put(:max_pending_tasks_per_ip, 5)
      |> Keyword.put(:async?, true)
      |> Keyword.put(:tmp_dir, System.tmp_dir!() <> "/csv_export_test_#{:rand.uniform(100_000)}")
      |> Keyword.put(:gokapi_url, "http://localhost:#{bypass.port}")
      |> Keyword.put(:gokapi_api_key, "test-api-key")
      |> Keyword.put(:chunk_size, 1024)
      |> Keyword.put(:gokapi_upload_expiry_days, 1)
      |> Keyword.put(:gokapi_upload_allowed_downloads, 1)
      |> Keyword.put(:db_timeout, 60_000)

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

  describe "perform/1 address-based export" do
    test "processes address-based export and updates request on success", %{bypass: bypass} do
      address = insert(:address)

      :transaction
      |> insert(from_address: address)
      |> with_block()

      args = %{
        address_hash: to_string(address.hash),
        from_period: DateTime.utc_now() |> DateTime.to_iso8601(),
        to_period: DateTime.utc_now() |> DateTime.to_iso8601(),
        show_scam_tokens?: nil,
        module: "Elixir.Explorer.Chain.CsvExport.Address.Transactions",
        filter_type: nil,
        filter_value: nil
      }

      {:ok, request} = Request.create("127.0.0.1", args)

      Bypass.expect(bypass, fn conn ->
        [path | _] = conn.request_path |> String.split("?")

        cond do
          path == "/api/chunk/add" ->
            Conn.resp(conn, 200, "")

          path == "/api/chunk/complete" ->
            Conn.resp(
              conn,
              200,
              Jason.encode!(%{"FileInfo" => %{"Id" => "test-file-id"}})
            )

          true ->
            Conn.resp(conn, 404, "Not found")
        end
      end)

      job_args = %{
        "request_id" => request.id,
        "address_hash" => args.address_hash,
        "from_period" => DateTime.utc_now() |> DateTime.to_iso8601(),
        "to_period" => DateTime.utc_now() |> DateTime.to_iso8601(),
        "show_scam_tokens?" => nil,
        "module" => args.module,
        "filter_type" => nil,
        "filter_value" => nil
      }

      assert :ok = perform_job(Worker, job_args)

      updated = Request.get_by_uuid(request.id)
      assert updated.status == :completed
      assert updated.file_id == "test-file-id"
    end
  end

  describe "perform/1 failure handling" do
    test "marks request as failed when upload fails", %{bypass: bypass} do
      address = insert(:address)

      :transaction
      |> insert(from_address: address)
      |> with_block()

      args = %{
        address_hash: to_string(address.hash),
        from_period: DateTime.utc_now() |> DateTime.to_iso8601(),
        to_period: DateTime.utc_now() |> DateTime.to_iso8601(),
        show_scam_tokens?: nil,
        module: "Elixir.Explorer.Chain.CsvExport.Address.Transactions",
        filter_type: nil,
        filter_value: nil
      }

      {:ok, request} = Request.create("127.0.0.1", args)

      Bypass.expect(bypass, fn conn ->
        [path | _] = conn.request_path |> String.split("?")

        cond do
          path == "/api/chunk/add" ->
            Conn.resp(conn, 200, "")

          path == "/api/chunk/complete" ->
            Conn.resp(conn, 500, "Internal Server Error")

          true ->
            Conn.resp(conn, 404, "")
        end
      end)

      job_args = %{
        "request_id" => request.id,
        "address_hash" => args.address_hash,
        "from_period" => DateTime.utc_now() |> DateTime.to_iso8601(),
        "to_period" => DateTime.utc_now() |> DateTime.to_iso8601(),
        "show_scam_tokens?" => nil,
        "module" => args.module,
        "filter_type" => nil,
        "filter_value" => nil
      }

      assert {:error, _} = perform_job(Worker, job_args)

      updated = Request.get_by_uuid(request.id)
      assert updated.status == :failed
    end
  end
end
