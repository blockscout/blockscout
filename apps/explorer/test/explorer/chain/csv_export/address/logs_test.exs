defmodule Explorer.Chain.Address.LogsTest do
  use Explorer.DataCase

  alias Explorer.Chain.Address
  alias Explorer.Chain.CsvExport.Address.Logs, as: AddressLogsCsvExporter

  @first_topic_hex_string_1 "0x7fcf532c15f0a6db0bd6d0e038bea71d30d808c7d98cb3bf7268a95bf5081b65"
  @second_topic_hex_string_1 "0x00000000000000000000000098a9dc37d3650b5b30d6c12789b3881ee0b70c16"
  @third_topic_hex_string_1 "0x0000000000000000000000005079fc00f00f30000e0c8c083801cfde000008b6"
  @fourth_topic_hex_string_1 "0x8c9b7729443a4444242342b2ca385a239a5c1d76a88473e1cd2ab0c70dd1b9c7"

  defp topic(topic_hex_string) do
    {:ok, topic} = Explorer.Chain.Hash.Full.cast(topic_hex_string)
    topic
  end

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
          first_topic: topic(@first_topic_hex_string_1),
          second_topic: topic(@second_topic_hex_string_1),
          third_topic: topic(@third_topic_hex_string_1),
          fourth_topic: topic(@fourth_topic_hex_string_1)
        )

      {:ok, now} = DateTime.now("Etc/UTC")

      from_period = DateTime.add(now, -1, :minute) |> DateTime.to_iso8601()
      to_period = now |> DateTime.to_iso8601()

      [result] =
        address.hash
        |> AddressLogsCsvExporter.export(from_period, to_period, [])
        |> Enum.to_list()
        |> Enum.drop(1)
        |> Enum.map(fn [
                         [[], transaction_hash],
                         _,
                         [[], index],
                         _,
                         [[], block_number],
                         _,
                         [[], block_hash],
                         _,
                         [[], address],
                         _,
                         [[], data],
                         _,
                         [[], first_topic],
                         _,
                         [[], second_topic],
                         _,
                         [[], third_topic],
                         _,
                         [[], fourth_topic],
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
      assert result.address == Address.checksum(log.address.hash)
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

      {:ok, now} = DateTime.now("Etc/UTC")

      from_period = DateTime.add(now, -1, :minute) |> DateTime.to_iso8601()
      to_period = now |> DateTime.to_iso8601()

      result =
        address.hash
        |> AddressLogsCsvExporter.export(from_period, to_period, [])
        |> Enum.to_list()
        |> Enum.drop(1)

      assert Enum.count(result) == 200
    end
  end
end
