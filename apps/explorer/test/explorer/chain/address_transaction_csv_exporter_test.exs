defmodule Explorer.Chain.AddressTransactionCsvExporterTest do
  use Explorer.DataCase

  alias Explorer.Chain.{AddressTransactionCsvExporter, Wei}

  describe "export/3" do
    test "exports address transactions to csv" do
      address = insert(:address)

      transaction =
        :transaction
        |> insert(from_address: address)
        |> with_block()
        |> Repo.preload(:token_transfers)

      from_period = Timex.format!(Timex.shift(Timex.now(), minutes: -1), "%Y-%m-%d", :strftime)
      to_period = Timex.format!(Timex.now(), "%Y-%m-%d", :strftime)

      [result] =
        address
        |> AddressTransactionCsvExporter.export(from_period, to_period)
        |> Enum.to_list()
        |> Enum.drop(1)
        |> Enum.map(fn [
                         [[], hash],
                         _,
                         [[], block_number],
                         _,
                         [[], timestamp],
                         _,
                         [[], from_address],
                         _,
                         [[], to_address],
                         _,
                         [[], created_address],
                         _,
                         [[], type],
                         _,
                         [[], value],
                         _,
                         [[], fee],
                         _,
                         [[], status],
                         _,
                         [[], error],
                         _,
                         [[], cur_price],
                         _,
                         [[], op_price],
                         _,
                         [[], cl_price],
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
            status: status,
            error: error,
            current_price: cur_price,
            opening_price: op_price,
            closing_price: cl_price
          }
        end)

      assert result.block_number == to_string(transaction.block_number)
      assert result.timestamp
      assert result.created_address == to_string(transaction.created_contract_address_hash)
      assert result.from_address == to_string(transaction.from_address)
      assert result.to_address == to_string(transaction.to_address)
      assert result.hash == to_string(transaction.hash)
      assert result.type == "OUT"
      assert result.value == transaction.value |> Wei.to(:wei) |> to_string()
      assert result.fee
      assert result.status == to_string(transaction.status)
      assert result.error == to_string(transaction.error)
      assert result.current_price
      assert result.opening_price
      assert result.closing_price
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

      1..200
      |> Enum.map(fn _ ->
        :transaction
        |> insert(to_address: address)
        |> with_block()
      end)
      |> Enum.count()

      1..200
      |> Enum.map(fn _ ->
        :transaction
        |> insert(created_contract_address: address)
        |> with_block()
      end)
      |> Enum.count()

      from_period = Timex.format!(Timex.shift(Timex.now(), minutes: -1), "%Y-%m-%d", :strftime)
      to_period = Timex.format!(Timex.now(), "%Y-%m-%d", :strftime)

      result =
        address
        |> AddressTransactionCsvExporter.export(from_period, to_period)
        |> Enum.to_list()
        |> Enum.drop(1)

      assert Enum.count(result) == 600
    end
  end
end
