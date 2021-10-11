defmodule Explorer.Chain.AddressLogCsvExporterTest do
  use Explorer.DataCase

  alias Explorer.Chain.{AddressLogCsvExporter, Wei}

  describe "export/3" do
    test "exports address logs to csv" do
      address = insert(:address)

      transaction =
        :transaction
        |> insert()
        |> with_block()

      log =
        insert(:log,
          address: address,
          index: 1,
          transaction: transaction,
          block: transaction.block,
          block_number: transaction.block_number,
          data: "0x12",
          first_topic: "0x13",
          second_topic: "0x14",
          third_topic: "0x15",
          fourth_topic: "0x16"
        )

      from_period = Timex.format!(Timex.shift(Timex.now(), minutes: -1), "%Y-%m-%d", :strftime)
      to_period = Timex.format!(Timex.now(), "%Y-%m-%d", :strftime)

      [result] =
        address
        |> AddressLogCsvExporter.export(from_period, to_period)
        |> Enum.to_list()
        |> Enum.drop(1)
        |> Enum.map(fn [
                         transaction_hash,
                         _,
                         index,
                         _,
                         block_number,
                         _,
                         block_hash,
                         _,
                         address,
                         _,
                         data,
                         _,
                         first_topic,
                         _,
                         second_topic,
                         _,
                         third_topic,
                         _,
                         fourth_topic,
                         _
                       ] ->
          %{
            transaction_hash: transaction_hash,
            index: index,
            block_number: block_number,
            block_hash: block_hash,
            address: address,
            data: data,
            first_topic: first_topic,
            second_topic: second_topic,
            third_topic: third_topic,
            fourth_topic: fourth_topic
          }
        end)

      assert result.transaction_hash == to_string(log.transaction_hash)
      assert result.index == to_string(log.index)
      assert result.block_number == to_string(log.block_number)
      assert result.block_hash == to_string(log.block_hash)
      assert result.address == to_string(log.address)
      assert result.data == to_string(log.data)
      assert result.first_topic == to_string(log.first_topic)
      assert result.second_topic == to_string(log.second_topic)
      assert result.third_topic == to_string(log.third_topic)
      assert result.fourth_topic == to_string(log.fourth_topic)
    end

    test "fetches all logs" do
      address = insert(:address)

      1..200
      |> Enum.map(fn index ->
        transaction =
          :transaction
          |> insert()
          |> with_block()

        insert(:log,
          address: address,
          index: index,
          transaction: transaction,
          block: transaction.block,
          block_number: transaction.block_number
        )
      end)
      |> Enum.count()

      from_period = Timex.format!(Timex.shift(Timex.now(), minutes: -1), "%Y-%m-%d", :strftime)
      to_period = Timex.format!(Timex.now(), "%Y-%m-%d", :strftime)

      result =
        address
        |> AddressLogCsvExporter.export(from_period, to_period)
        |> Enum.to_list()
        |> Enum.drop(1)

      assert Enum.count(result) == 200
    end
  end
end
