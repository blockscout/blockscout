defmodule Explorer.Chain.AddressTransactionCsvExporterTest do
  use Explorer.DataCase

  alias Explorer.Chain.AddressTransactionCsvExporter

  describe "export/1" do
    test "exports address transactions to csv" do
      address = insert(:address)

      transaction =
        :transaction
        |> insert(from_address: address)
        |> with_block()
        |> Repo.preload(:token_transfers)

      [result] =
        address
        |> AddressTransactionCsvExporter.export()
        |> File.stream!()
        |> NimbleCSV.RFC4180.parse_stream()
        |> Stream.map(fn [hash, block_number, timestamp, from_address, to_address, created_address, type, value] ->
          %{
            hash: hash,
            block_number: block_number,
            timestamp: timestamp,
            from_address: from_address,
            to_address: to_address,
            created_address: created_address,
            type: type,
            value: value
          }
        end)
        |> Enum.to_list()

      assert result.block_number == to_string(transaction.block_number)
      assert result.created_address == to_string(transaction.created_contract_address_hash)
      assert result.from_address == to_string(transaction.from_address)
      assert result.to_address == to_string(transaction.to_address)
      assert result.hash == to_string(transaction.hash)
      assert result.type == "OUT"
    end
  end
end
