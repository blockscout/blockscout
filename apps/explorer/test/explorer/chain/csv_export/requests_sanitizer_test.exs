defmodule Explorer.Chain.CsvExport.RequestsSanitizerTest do
  use Explorer.DataCase, async: false
  use Oban.Testing, repo: Explorer.Repo

  alias Explorer.Chain.CsvExport.{Request, RequestsSanitizer}

  setup do
    original_config = Application.get_env(:explorer, Explorer.Chain.CsvExport)

    config =
      (original_config || [])
      |> Keyword.put(:max_pending_tasks_per_ip, 5)
      |> Keyword.put(:async?, true)
      |> Keyword.put(:gokapi_upload_expiry_days, 1)

    Application.put_env(:explorer, Explorer.Chain.CsvExport, config)

    on_exit(fn ->
      if original_config do
        Application.put_env(:explorer, Explorer.Chain.CsvExport, original_config)
      else
        Application.delete_env(:explorer, Explorer.Chain.CsvExport)
      end
    end)

    :ok
  end

  describe "perform/1" do
    test "deletes completed requests older than gokapi_upload_expiry_days" do
      {:ok, request1} =
        Request.create("127.0.0.1", %{
          address_hash: to_string(insert(:address).hash),
          from_period: nil,
          to_period: nil,
          show_scam_tokens?: nil,
          module: "Elixir.Explorer.Chain.CsvExport.Address.Transactions",
          filter_type: nil,
          filter_value: nil
        })

      Request.update_file_id(request1.id, "file-123")

      past_time = DateTime.add(DateTime.utc_now(), -2, :day)

      Request
      |> Ecto.Query.where([r], r.id == ^request1.id)
      |> Explorer.Repo.update_all(set: [updated_at: past_time])

      assert :ok = perform_job(RequestsSanitizer, %{})

      assert nil == Request.get_by_uuid(request1.id)
    end

    test "does not delete pending requests" do
      {:ok, request} =
        Request.create("127.0.0.1", %{
          address_hash: to_string(insert(:address).hash),
          from_period: nil,
          to_period: nil,
          show_scam_tokens?: nil,
          module: "Elixir.Explorer.Chain.CsvExport.Address.Transactions",
          filter_type: nil,
          filter_value: nil
        })

      assert :ok = perform_job(RequestsSanitizer, %{})

      assert Request.get_by_uuid(request.id) != nil
    end

    test "does not delete recently completed requests" do
      {:ok, request} =
        Request.create("127.0.0.1", %{
          address_hash: to_string(insert(:address).hash),
          from_period: nil,
          to_period: nil,
          show_scam_tokens?: nil,
          module: "Elixir.Explorer.Chain.CsvExport.Address.Transactions",
          filter_type: nil,
          filter_value: nil
        })

      Request.update_file_id(request.id, "recent-file")

      assert :ok = perform_job(RequestsSanitizer, %{})

      assert Request.get_by_uuid(request.id) != nil
    end
  end
end
