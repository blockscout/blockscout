defmodule Explorer.Chain.CSVExport.AddressInternalTransactionCsvExporterTest do
  use Explorer.DataCase

  alias Explorer.Chain.CSVExport.AddressInternalTransactionCsvExporter
  alias Explorer.Chain.Wei

  describe "export/3" do
    test "exports address internal transactions to csv" do
      address = insert(:address)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      internal_transaction =
        insert(:internal_transaction,
          index: 1,
          transaction: transaction,
          from_address: address,
          block_number: transaction.block_number,
          block_hash: transaction.block_hash,
          block_index: 1,
          transaction_index: transaction.index
        )

      from_period = Timex.format!(Timex.shift(Timex.now(), minutes: -1), "%Y-%m-%d", :strftime)
      to_period = Timex.format!(Timex.now(), "%Y-%m-%d", :strftime)

      res =
        address
        |> AddressInternalTransactionCsvExporter.export(from_period, to_period)
        |> Enum.to_list()
        |> Enum.drop(1)

      [result] =
        res
        |> Enum.map(fn [
                         [[], transaction_hash],
                         _,
                         [[], index],
                         _,
                         [[], block_number],
                         _,
                         [[], block_hash],
                         _,
                         [[], block_index],
                         _,
                         [[], transaction_index],
                         _,
                         [[], timestamp],
                         _,
                         [[], from_address_hash],
                         _,
                         [[], to_address_hash],
                         _,
                         [[], created_contract_address_hash],
                         _,
                         [[], type],
                         _,
                         [[], call_type],
                         _,
                         [[], gas],
                         _,
                         [[], gas_used],
                         _,
                         [[], value],
                         _,
                         [[], input],
                         _,
                         [[], output],
                         _,
                         [[], error],
                         _
                       ] ->
          %{
            transaction_hash: transaction_hash,
            index: index,
            block_number: block_number,
            block_index: block_index,
            block_hash: block_hash,
            transaction_index: transaction_index,
            timestamp: timestamp,
            from_address_hash: from_address_hash,
            to_address_hash: to_address_hash,
            created_contract_address_hash: created_contract_address_hash,
            type: type,
            call_type: call_type,
            gas: gas,
            gas_used: gas_used,
            value: value,
            input: input,
            output: output,
            error: error
          }
        end)

      assert result.transaction_hash == to_string(internal_transaction.transaction_hash)
      assert result.index == to_string(internal_transaction.index)
      assert result.block_number == to_string(internal_transaction.block_number)
      assert result.block_index == to_string(internal_transaction.block_index)
      assert result.block_hash == to_string(internal_transaction.block_hash)
      assert result.transaction_index == to_string(internal_transaction.transaction_index)
      assert result.timestamp
      assert result.from_address_hash == to_string(internal_transaction.from_address_hash)
      assert result.to_address_hash == to_string(internal_transaction.to_address_hash)
      assert result.created_contract_address_hash == to_string(internal_transaction.created_contract_address_hash)
      assert result.type == to_string(internal_transaction.type)
      assert result.call_type == to_string(internal_transaction.call_type)
      assert result.gas == to_string(internal_transaction.gas)
      assert result.gas_used == to_string(internal_transaction.gas_used)
      assert result.value == internal_transaction.value |> Wei.to(:wei) |> to_string()
      assert result.input == to_string(internal_transaction.input)
      assert result.output == to_string(internal_transaction.output)
      assert result.error == to_string(internal_transaction.error)
    end

    test "fetches all internal transactions" do
      address = insert(:address)

      1..200
      |> Enum.map(fn index ->
        transaction =
          :transaction
          |> insert()
          |> with_block()

        insert(:internal_transaction,
          index: index,
          transaction: transaction,
          from_address: address,
          block_number: transaction.block_number,
          block_hash: transaction.block_hash,
          block_index: index,
          transaction_index: transaction.index
        )
      end)
      |> Enum.count()

      1..200
      |> Enum.map(fn index ->
        transaction =
          :transaction
          |> insert()
          |> with_block()

        insert(:internal_transaction,
          index: index,
          transaction: transaction,
          to_address: address,
          block_number: transaction.block_number,
          block_hash: transaction.block_hash,
          block_index: index,
          transaction_index: transaction.index
        )
      end)
      |> Enum.count()

      1..200
      |> Enum.map(fn index ->
        transaction =
          :transaction
          |> insert()
          |> with_block()

        insert(:internal_transaction,
          index: index,
          transaction: transaction,
          created_contract_address: address,
          block_number: transaction.block_number,
          block_hash: transaction.block_hash,
          block_index: index,
          transaction_index: transaction.index
        )
      end)
      |> Enum.count()

      from_period = Timex.format!(Timex.shift(Timex.now(), minutes: -1), "%Y-%m-%d", :strftime)
      to_period = Timex.format!(Timex.now(), "%Y-%m-%d", :strftime)

      result =
        address
        |> AddressInternalTransactionCsvExporter.export(from_period, to_period)
        |> Enum.to_list()
        |> Enum.drop(1)

      assert Enum.count(result) == 600
    end
  end
end
