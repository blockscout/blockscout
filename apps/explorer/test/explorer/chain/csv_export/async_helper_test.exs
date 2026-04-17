defmodule Explorer.Chain.CsvExport.AsyncHelperTest do
  use Explorer.DataCase, async: false

  alias Explorer.Chain.CsvExport.{AsyncHelper, Request}

  setup do
    original_config = Application.get_env(:explorer, Explorer.Chain.CsvExport)

    config =
      (original_config || [])
      |> Keyword.put(:tmp_dir, System.tmp_dir!() <> "/csv_export_async_test_#{:rand.uniform(100_000)}")

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

  describe "actualize_csv_export_request/1" do
    test "returns request as-is when file_id is nil (pending)" do
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

      assert actualized = AsyncHelper.actualize_csv_export_request(request)
      assert actualized.id == request.id
      assert actualized.file_id == nil
    end

    test "returns nil when input is nil" do
      assert nil == AsyncHelper.actualize_csv_export_request(nil)
    end
  end

  describe "stream_to_temp_file/2" do
    test "writes stream content to temp file and returns file path" do
      uuid = Ecto.UUID.generate()
      stream = Stream.map(["a", "b", "c"], & &1)

      path = AsyncHelper.stream_to_temp_file(stream, uuid)

      assert path =~ "csv_export_#{uuid}.csv"
      assert File.exists?(path)
      assert File.read!(path) == "abc"
    end
  end
end
