defmodule Explorer.Chain.CsvExport.HelperTest do
  use Explorer.DataCase, async: true

  alias Explorer.Chain.CsvExport.Helper

  setup do
    original_config = Application.get_env(:explorer, Explorer.Chain.CsvExport)

    Application.put_env(:explorer, Explorer.Chain.CsvExport, [
      {:async?, false}
      | (original_config || []) |> Keyword.drop([:async?])
    ])

    on_exit(fn ->
      if original_config do
        Application.put_env(:explorer, Explorer.Chain.CsvExport, original_config)
      else
        Application.delete_env(:explorer, Explorer.Chain.CsvExport)
      end
    end)

    :ok
  end

  describe "valid_filter?/3" do
    test "returns true for valid address filter to" do
      assert Helper.valid_filter?("address", "to", "transactions") == true
      assert Helper.valid_filter?("address", "to", "token-transfers") == true
      assert Helper.valid_filter?("address", "to", "internal-transactions") == true
    end

    test "returns true for valid address filter from" do
      assert Helper.valid_filter?("address", "from", "transactions") == true
    end

    test "returns false for invalid filter type" do
      assert Helper.valid_filter?("invalid", "to", "transactions") == false
    end

    test "returns false for invalid filter value for address" do
      assert Helper.valid_filter?("address", "invalid", "transactions") == false
    end

    test "returns false for nil or empty filter value" do
      refute Helper.valid_filter?("address", nil, "transactions")
      refute Helper.valid_filter?("address", "", "transactions")
    end
  end

  describe "supported_filters/1" do
    test "returns correct filters for each type" do
      assert Helper.supported_filters("internal-transactions") == ["address"]
      assert Helper.supported_filters("transactions") == ["address"]
      assert Helper.supported_filters("token-transfers") == ["address"]
      assert Helper.supported_filters("logs") == ["topic"]
      assert Helper.supported_filters("unknown") == []
    end
  end

  describe "async_enabled?/0" do
    test "returns config value" do
      Application.put_env(:explorer, Explorer.Chain.CsvExport, [async?: false] ++ [])
      assert Helper.async_enabled?() == false

      Application.put_env(:explorer, Explorer.Chain.CsvExport, [async?: true] ++ [])
      assert Helper.async_enabled?() == true
    end
  end

  describe "dump_to_stream/1" do
    test "produces CSV-formatted stream" do
      rows = [["a", "b", "c"], ["1", "2", "3"]]
      stream = Helper.dump_to_stream(rows)

      result = stream |> Enum.to_list() |> Enum.join("")
      assert result =~ "a,b,c"
      assert result =~ "1,2,3"
    end
  end
end
