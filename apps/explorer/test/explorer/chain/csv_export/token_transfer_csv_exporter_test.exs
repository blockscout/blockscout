defmodule Explorer.CSV.Export.TokenTransferCsvExporterTest do
  use Explorer.DataCase

  alias Explorer.Chain.AddressTokenTransferCsvExporter

  describe "export/3" do
    test "exports token transfers to csv" do
      address = insert(:address)

      transaction =
        :transaction
        |> insert(from_address: address)
        |> with_block()

      token_transfer =
        insert(:token_transfer,
          transaction: transaction,
          from_address: address,
          block_number: transaction.block_number,
          block: transaction.block
        )

      from_period = Timex.format!(Timex.shift(Timex.now(), minutes: -1), "%Y-%m-%d", :strftime)
      to_period = Timex.format!(Timex.now(), "%Y-%m-%d", :strftime)

      {:ok, csv} = Explorer.Export.CSV.export_token_transfers(address, from_period, to_period, [])

      [result] =
        csv
        |> Enum.drop(1)
        |> Enum.map(fn [
                         tx_hash,
                         _,
                         block_number,
                         _,
                         timestamp,
                         _,
                         from_address,
                         _,
                         to_address,
                         _,
                         token_contract_address,
                         _,
                         type,
                         _,
                         token_symbol,
                         _,
                         tokens_transferred,
                         _,
                         transaction_fee,
                         _,
                         transaction_currency,
                         _,
                         status,
                         _,
                         err_code,
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
            transaction_currency: transaction_currency,
            status: status,
            err_code: err_code
          }
        end)

      assert result.block_number == [[], to_string(transaction.block_number)]
      assert result.tx_hash == [[], to_string(transaction.hash)]
      assert result.from_address == [[], token_transfer.from_address_hash |> to_string() |> String.downcase()]
      assert result.to_address == [[], token_transfer.to_address_hash |> to_string() |> String.downcase()]
      assert result.timestamp == [[], to_string(transaction.block.timestamp)]
      assert result.transaction_currency == [[], "CELO"]
      assert result.type == [[], "OUT"]
    end
  end
end
