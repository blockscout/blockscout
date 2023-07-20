defmodule Explorer.Chain.AddressTokenTransferCsvExporterTest do
  use Explorer.DataCase

  alias Explorer.Chain.Address
  alias Explorer.Chain.CSVExport.AddressTokenTransferCsvExporter

  describe "export/3" do
    test "exports token transfers to csv" do
      address = insert(:address)

      transaction =
        :transaction
        |> insert(from_address: address)
        |> with_block()

      token_transfer =
        insert(:token_transfer, transaction: transaction, from_address: address, block_number: transaction.block_number)

      from_period = Timex.format!(Timex.shift(Timex.now(), minutes: -1), "%Y-%m-%d", :strftime)
      to_period = Timex.format!(Timex.now(), "%Y-%m-%d", :strftime)

      [result] =
        address.hash
        |> AddressTokenTransferCsvExporter.export(from_period, to_period)
        |> Enum.to_list()
        |> Enum.drop(1)
        |> Enum.map(fn [
                         [[], tx_hash],
                         _,
                         [[], block_number],
                         _,
                         [[], timestamp],
                         _,
                         [[], from_address],
                         _,
                         [[], to_address],
                         _,
                         [[], token_contract_address],
                         _,
                         [[], type],
                         _,
                         [[], token_symbol],
                         _,
                         [[], tokens_transferred],
                         _,
                         [[], transaction_fee],
                         _,
                         [[], status],
                         _,
                         [[], err_code],
                         _
                       ] ->
          %{
            tx_hash: tx_hash,
            block_number: block_number,
            timestamp: timestamp,
            from_address: from_address,
            to_address: to_address,
            token_contract_address: token_contract_address,
            type: type,
            token_symbol: token_symbol,
            tokens_transferred: tokens_transferred,
            transaction_fee: transaction_fee,
            status: status,
            err_code: err_code
          }
        end)

      assert result.block_number == to_string(transaction.block_number)
      assert result.tx_hash == to_string(transaction.hash)
      assert result.from_address == Address.checksum(token_transfer.from_address_hash)
      assert result.to_address == Address.checksum(token_transfer.to_address_hash)
      assert result.timestamp == to_string(transaction.block.timestamp)
      assert result.type == "OUT"
    end

    test "fetches all token transfers" do
      address = insert(:address)

      1..200
      |> Enum.map(fn _ ->
        transaction =
          :transaction
          |> insert(from_address: address)
          |> with_block()

        insert(:token_transfer,
          transaction: transaction,
          from_address: address,
          block_number: transaction.block_number
        )
      end)
      |> Enum.count()

      1..200
      |> Enum.map(fn _ ->
        transaction =
          :transaction
          |> insert(to_address: address)
          |> with_block()

        insert(:token_transfer,
          transaction: transaction,
          to_address: address,
          block_number: transaction.block_number
        )
      end)
      |> Enum.count()

      from_period = Timex.format!(Timex.shift(Timex.now(), minutes: -1), "%Y-%m-%d", :strftime)
      to_period = Timex.format!(Timex.now(), "%Y-%m-%d", :strftime)

      result =
        address.hash
        |> AddressTokenTransferCsvExporter.export(from_period, to_period)
        |> Enum.to_list()
        |> Enum.drop(1)

      assert Enum.count(result) == 400
    end
  end
end
