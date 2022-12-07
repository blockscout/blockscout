defmodule Explorer.Export.CSV.TransactionExporterTest do
  use Explorer.DataCase

  alias Explorer.Chain.{AddressTransactionCsvExporter, Wei}

  describe "export/3" do
    test "exports address transactions to csv" do
      address = insert(:address)

      fee_currency = insert(:token, symbol: "TestSymbol", name: "TestName")

      transaction =
        :transaction
        |> insert(from_address: address, gas_currency: fee_currency.contract_address)
        |> with_block()
        |> Repo.preload(:token_transfers)

      from_period = Timex.format!(Timex.shift(Timex.now(), minutes: -1), "%Y-%m-%d", :strftime)
      to_period = Timex.format!(Timex.now(), "%Y-%m-%d", :strftime)

      {:ok, csv} = address |> Explorer.Export.CSV.export_transactions(from_period, to_period, [])

      [result] =
        csv
        |> Enum.drop(1)
        |> Enum.map(fn [
                         hash,
                         _,
                         block_number,
                         _,
                         timestamp,
                         _,
                         from_address,
                         _,
                         to_address,
                         _,
                         created_address,
                         _,
                         type,
                         _,
                         value,
                         _,
                         fee,
                         _,
                         currency,
                         _,
                         status,
                         _,
                         error,
                         _
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
            fee: fee,
            currency: currency,
            status: status,
            error: error
          }
        end)

      assert result.block_number == [[], to_string(transaction.block_number)]
      assert result.timestamp
      assert result.created_address == [[], to_string(transaction.created_contract_address_hash)]
      assert result.from_address == [[], to_string(transaction.from_address)]
      assert result.to_address == [[], to_string(transaction.to_address)]
      assert result.hash == [[], to_string(transaction.hash)]
      assert result.type == [[], "OUT"]
      assert result.value == [[], transaction.value |> Wei.to(:wei) |> to_string()]
      assert result.fee
      assert result.currency == [[], fee_currency.symbol]
      assert result.status == [[], to_string(transaction.status)]
      assert result.error == [[], to_string(transaction.error)]
    end

    test "exports transaction without explicit fee currency with CELO as currency" do
      address = insert(:address)

      transaction =
        :transaction
        |> insert(from_address: address)
        |> with_block()
        |> Repo.preload(:token_transfers)

      from_period = Timex.format!(Timex.shift(Timex.now(), minutes: -1), "%Y-%m-%d", :strftime)
      to_period = Timex.format!(Timex.now(), "%Y-%m-%d", :strftime)

      {:ok, csv} = address |> Explorer.Export.CSV.export_transactions(from_period, to_period, [])

      [result_currency] =
        csv
        |> Enum.drop(1)
        |> Enum.map(fn [
                         _hash,
                         _,
                         _block_number,
                         _,
                         _timestamp,
                         _,
                         _from_address,
                         _,
                         _to_address,
                         _,
                         _created_address,
                         _,
                         _type,
                         _,
                         _value,
                         _,
                         _fee,
                         _,
                         currency,
                         _,
                         _status,
                         _,
                         _error,
                         _
                       ] ->
          currency
        end)

      assert result_currency == [[], "CELO"]
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

      from_period = Timex.format!(Timex.shift(Timex.now(), minutes: -1), "%Y-%m-%d", :strftime)
      to_period = Timex.format!(Timex.now(), "%Y-%m-%d", :strftime)

      {:ok, csv} = address |> Explorer.Export.CSV.export_transactions(from_period, to_period, [])

      result = csv |> Enum.drop(1)

      assert Enum.count(result) == 200
    end
  end
end
