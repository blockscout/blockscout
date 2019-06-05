defmodule Explorer.Chain.AddressTransactionCsvExporterTest do
  use Explorer.DataCase

  alias Explorer.Chain.{AddressTransactionCsvExporter, Wei}

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
        |> Stream.map(fn [
                           hash,
                           block_number,
                           timestamp,
                           from_address,
                           to_address,
                           created_address,
                           type,
                           value,
                           status,
                           error
                         ] ->
          %{
            hash: hash,
            block_number: block_number,
            timestamp: timestamp,
            from_address: from_address,
            to_address: to_address,
            created_address: created_address,
            type: type,
            value: value,
            status: status,
            error: error
          }
        end)
        |> Enum.to_list()

      assert result.block_number == to_string(transaction.block_number)
      assert result.created_address == to_string(transaction.created_contract_address_hash)
      assert result.from_address == to_string(transaction.from_address)
      assert result.to_address == to_string(transaction.to_address)
      assert result.hash == to_string(transaction.hash)
      assert result.type == "OUT"
      assert result.value == transaction.value |> Wei.to(:wei) |> to_string()
      assert result.status == to_string(transaction.status)
      assert result.error == to_string(transaction.error)
    end

    test "fetches all transactions" do
      address = insert(:address)

      1..200
      |> Enum.map(fn _ ->
        :transaction
        |> insert(from_address: address)
        |> with_block()
      end)
      |> Enum.count()

      result =
        address
        |> AddressTransactionCsvExporter.export()
        |> File.stream!()
        |> NimbleCSV.RFC4180.parse_stream()
        |> Enum.to_list()

      assert Enum.count(result) == 200
    end
  end
end
