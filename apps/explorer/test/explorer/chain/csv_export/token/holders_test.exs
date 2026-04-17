defmodule Explorer.Chain.CsvExport.Token.HoldersTest do
  use Explorer.DataCase

  alias Explorer.Chain.Address
  alias Explorer.Chain.CsvExport.Token.Holders, as: TokenHoldersExporter

  setup do
    original_limit = Application.get_env(:explorer, :csv_export_limit)
    Application.put_env(:explorer, :csv_export_limit, 150)

    on_exit(fn ->
      if original_limit do
        Application.put_env(:explorer, :csv_export_limit, original_limit)
      else
        Application.delete_env(:explorer, :csv_export_limit)
      end
    end)

    :ok
  end

  describe "export/6" do
    test "exports token holders to csv with header and holder rows" do
      token = insert(:token, type: "ERC-20", decimals: 18)

      holder1 =
        insert(:address_current_token_balance,
          token_contract_address_hash: token.contract_address_hash,
          address: insert(:address),
          value: 100_000_000_000_000_000_000
        )

      holder2 =
        insert(:address_current_token_balance,
          token_contract_address_hash: token.contract_address_hash,
          address: insert(:address),
          value: 50_000_000_000_000_000_000
        )

      csv_string =
        token.contract_address_hash
        |> TokenHoldersExporter.export("2020-01-01", "2025-12-31", [], nil, nil)
        |> Enum.to_list()
        |> IO.iodata_to_binary()

      [header | rows] = String.split(csv_string, "\r\n", trim: true)
      assert header =~ "HolderAddress"
      assert header =~ "Balance"

      assert length(rows) == 2

      assert Enum.any?(rows, fn row ->
               row =~ Address.checksum(holder1.address_hash) and row =~ "100"
             end)

      assert Enum.any?(rows, fn row ->
               row =~ Address.checksum(holder2.address_hash) and row =~ "50"
             end)
    end

    test "formats holder address as checksummed and balance with correct decimals" do
      token = insert(:token, type: "ERC-20", decimals: 6)

      holder =
        insert(:address_current_token_balance,
          token_contract_address_hash: token.contract_address_hash,
          address: insert(:address),
          value: 1_234_567_890
        )

      csv_string =
        token.contract_address_hash
        |> TokenHoldersExporter.export("2020-01-01", "2025-12-31", [], nil, nil)
        |> Enum.to_list()
        |> IO.iodata_to_binary()

      [header | rows] = String.split(csv_string, "\r\n", trim: true)

      assert header =~ "HolderAddress"
      assert header =~ "Balance"

      assert length(rows) == 1
      row = hd(rows)
      assert row =~ Address.checksum(holder.address_hash)
      assert row =~ "1234.56789"
    end

    test "respects pagination with many holders" do
      token = insert(:token, type: "ERC-20", decimals: 18)

      Enum.each(1..200, fn _ ->
        insert(:address_current_token_balance,
          token_contract_address_hash: token.contract_address_hash,
          address: insert(:address),
          value: 1_000_000_000_000_000_000
        )
      end)

      csv_string =
        token.contract_address_hash
        |> TokenHoldersExporter.export("2020-01-01", "2025-12-31", [], nil, nil)
        |> Enum.to_list()
        |> IO.iodata_to_binary()

      [header | rows] = String.split(csv_string, "\r\n", trim: true)

      assert header =~ "HolderAddress"
      assert header =~ "Balance"
      assert length(rows) == 150
    end
  end
end
