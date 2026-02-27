defmodule Explorer.Chain.CsvExport.RequestTest do
  use Explorer.DataCase, async: false
  use Oban.Testing, repo: Explorer.Repo

  alias Explorer.Chain.CsvExport.Request

  setup do
    original_config = Application.get_env(:explorer, Explorer.Chain.CsvExport)

    config =
      (original_config || [])
      |> Keyword.put(:max_pending_tasks_per_ip, 2)
      |> Keyword.put(:async?, true)

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

  defp address_export_args do
    address = insert(:address)

    %{
      address_hash: to_string(address.hash),
      from_period: nil,
      to_period: nil,
      filter_type: nil,
      filter_value: nil,
      show_scam_tokens?: nil,
      module: "Elixir.Explorer.Chain.CsvExport.Address.Transactions"
    }
  end

  describe "create/2" do
    test "creates a request with pending status and enqueues Oban job" do
      args = address_export_args()
      assert {:ok, request} = Request.create("127.0.0.1", args)

      assert %Request{} = request
      assert request.id != nil
      assert request.status == :pending
      assert request.file_id == nil
      assert request.remote_ip_hash != nil
      assert byte_size(request.remote_ip_hash) == 32

      assert [job] = all_enqueued(worker: Explorer.Chain.CsvExport.Worker)
      assert job.args["request_id"] == request.id
      assert job.args["address_hash"] == args.address_hash
    end

    test "allows up to max_pending_tasks_per_ip concurrent requests from same IP" do
      args = address_export_args()

      assert {:ok, _} = Request.create("127.0.0.1", args)
      assert {:ok, _} = Request.create("127.0.0.1", args)

      assert {:error, :too_many_pending_requests} = Request.create("127.0.0.1", args)
    end

    test "returns too_many_pending_requests when limit is reached" do
      args = address_export_args()

      Request.create("192.168.1.1", args)
      Request.create("192.168.1.1", args)

      assert {:error, :too_many_pending_requests} = Request.create("192.168.1.1", args)
    end

    test "allows new requests from different IPs" do
      args = address_export_args()

      assert {:ok, _} = Request.create("127.0.0.1", args)
      assert {:ok, _} = Request.create("127.0.0.1", args)
      assert {:ok, _} = Request.create("10.0.0.1", args)
    end
  end

  describe "update_file_id/2" do
    test "sets file_id and transitions status to completed" do
      {:ok, request} = Request.create("127.0.0.1", address_export_args())
      file_id = "gokapi-file-123"

      assert {1, nil} = Request.update_file_id(request.id, file_id)

      updated = Request.get_by_uuid(request.id)
      assert updated.file_id == file_id
      assert updated.status == :completed
    end
  end

  describe "mark_failed/1" do
    test "transitions status to failed" do
      {:ok, request} = Request.create("127.0.0.1", address_export_args())

      assert {1, nil} = Request.mark_failed(request.id)

      updated = Request.get_by_uuid(request.id)
      assert updated.status == :failed
    end
  end

  describe "get_by_uuid/2" do
    test "returns the request by UUID" do
      {:ok, request} = Request.create("127.0.0.1", address_export_args())

      found = Request.get_by_uuid(request.id)
      assert found.id == request.id
    end

    test "returns nil for non-existent UUID" do
      uuid = Ecto.UUID.generate()
      assert nil == Request.get_by_uuid(uuid)
    end
  end

  describe "delete/1" do
    test "removes the request" do
      {:ok, request} = Request.create("127.0.0.1", address_export_args())

      assert {1, nil} = Request.delete(request.id)
      assert nil == Request.get_by_uuid(request.id)
    end

    test "returns {0, nil} for non-existent UUID" do
      uuid = Ecto.UUID.generate()
      assert {0, nil} = Request.delete(uuid)
    end
  end
end
