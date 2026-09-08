# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Etherscan.LogsTest do
  use Explorer.DataCase

  import Ecto.Query, only: [from: 2]
  import Explorer.Factory

  alias Explorer.Etherscan.Logs
  alias Explorer.Chain.{Block, Transaction}
  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Repo

  @first_topic_hex_string_1 "0x7fcf532c15f0a6db0bd6d0e038bea71d30d808c7d98cb3bf7268a95bf5081b65"
  @first_topic_hex_string_2 "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
  @first_topic_hex_string_3 "0xe1fffcc4923d04b559f4d29a8bfc6cda04eb5b0d3c460751c2402c5c5cc9109c"

  @second_topic_hex_string_1 "0x00000000000000000000000098a9dc37d3650b5b30d6c12789b3881ee0b70c16"
  @second_topic_hex_string_2 "0x000000000000000000000000e2680fd7cdbb04e9087a647ad4d023ef6c8fb4e2"
  @second_topic_hex_string_3 "0x0000000000000000000000005777d92f208679db4b9778590fa3cab3ac9e2168"

  @third_topic_hex_string_1 "0x0000000000000000000000005079fc00f00f30000e0c8c083801cfde000008b6"
  @third_topic_hex_string_2 "0x000000000000000000000000e2680fd7cdbb04e9087a647ad4d023ef6c8fb4e2"
  @third_topic_hex_string_3 "0x0000000000000000000000000f6d9bd6fc315bbf95b5c44f4eba2b2762f8c372"

  @fourth_topic_hex_string_1 "0x8c9b7729443a4444242342b2ca385a239a5c1d76a88473e1cd2ab0c70dd1b9c7"

  defp topic(topic_hex_string) do
    {:ok, topic} = Explorer.Chain.Hash.Full.cast(topic_hex_string)
    topic
  end

  describe "list_logs/1" do
    test "with empty db" do
      contract_address = build(:contract_address)

      filter = %{
        from_block: 0,
        to_block: 9999,
        address_hash: contract_address.hash
      }

      assert Logs.list_logs(filter) == []
    end

    test "with address with zero logs" do
      contract_address = insert(:contract_address)

      %Transaction{block: block} =
        :transaction
        |> insert(to_address: contract_address)
        |> with_block()

      filter = %{
        from_block: block.number,
        to_block: block.number,
        address_hash: contract_address.hash
      }

      assert Logs.list_logs(filter) == []
    end

    test "with address with one log response includes all required information" do
      contract_address = insert(:contract_address)
      block = insert(:block)

      transaction =
        %Transaction{} =
        :transaction
        |> insert(to_address: contract_address, block_timestamp: block.timestamp)
        |> with_block(block)

      log = insert(:log, address: contract_address, block: block, block_number: block.number, transaction: transaction)

      filter = %{
        from_block: block.number,
        to_block: block.number,
        address_hash: contract_address.hash
      }

      [found_log] = Logs.list_logs(filter)

      assert found_log.data == log.data
      assert found_log.first_topic == log.first_topic
      assert found_log.second_topic == log.second_topic
      assert found_log.third_topic == log.third_topic
      assert found_log.fourth_topic == log.fourth_topic
      assert found_log.index == log.index
      assert found_log.address_hash == log.address_hash
      assert found_log.transaction_hash == log.transaction_hash
      assert found_log.gas_price == transaction.gas_price
      assert found_log.gas_used == transaction.gas_used
      assert found_log.transaction_index == transaction.index
      assert found_log.block_number == block.number
      assert found_log.block_timestamp == block.timestamp
    end

    test "with address with two logs" do
      contract_address = insert(:contract_address)

      transaction =
        %Transaction{block: block} =
        :transaction
        |> insert(to_address: contract_address)
        |> with_block()

      insert_list(2, :log,
        address: contract_address,
        transaction: transaction,
        block_number: block.number,
        block: block
      )

      filter = %{
        from_block: block.number,
        to_block: block.number,
        address_hash: contract_address.hash
      }

      found_logs = Logs.list_logs(filter)

      assert length(found_logs) == 2
    end

    test "ignores logs with block below fromBlock" do
      first_block = insert(:block)
      second_block = insert(:block)

      contract_address = insert(:contract_address)

      transaction_block1 =
        %Transaction{} =
        :transaction
        |> insert(to_address: contract_address)
        |> with_block(first_block)

      transaction_block2 =
        %Transaction{} =
        :transaction
        |> insert(to_address: contract_address)
        |> with_block(second_block)

      insert(:log,
        address: contract_address,
        transaction: transaction_block1,
        block: first_block,
        block_number: first_block.number
      )

      insert(:log,
        address: contract_address,
        transaction: transaction_block2,
        block: second_block,
        block_number: second_block.number
      )

      filter = %{
        from_block: second_block.number,
        to_block: second_block.number,
        address_hash: contract_address.hash
      }

      [found_log] = Logs.list_logs(filter)

      assert found_log.block_number == second_block.number
      assert found_log.transaction_hash == transaction_block2.hash
    end

    test "ignores logs with block above toBlock" do
      first_block = insert(:block)
      second_block = insert(:block)

      contract_address = insert(:contract_address)

      transaction_block1 =
        %Transaction{} =
        :transaction
        |> insert(to_address: contract_address)
        |> with_block(first_block)

      transaction_block2 =
        %Transaction{} =
        :transaction
        |> insert(to_address: contract_address)
        |> with_block(second_block)

      insert(:log,
        address: contract_address,
        transaction: transaction_block1,
        block: first_block,
        block_number: first_block.number
      )

      insert(:log,
        address: contract_address,
        transaction: transaction_block2,
        block: second_block,
        block_number: second_block.number
      )

      filter = %{
        from_block: first_block.number,
        to_block: first_block.number,
        address_hash: contract_address.hash
      }

      [found_log] = Logs.list_logs(filter)

      assert found_log.block_number == first_block.number
      assert found_log.transaction_hash == transaction_block1.hash
    end

    test "paginates logs" do
      contract_address = insert(:contract_address)

      transaction_a =
        :transaction
        |> insert(to_address: contract_address)
        |> with_block()

      transaction_b =
        :transaction
        |> insert(to_address: contract_address)
        |> with_block()

      transaction_c =
        :transaction
        |> insert(to_address: contract_address)
        |> with_block()

      inserted_records =
        for i <- 1..700 do
          insert(:log,
            address: contract_address,
            transaction: transaction_a,
            block_number: transaction_a.block.number,
            block: transaction_a.block,
            index: i
          )
        end ++
          for i <- 1..700 do
            insert(:log,
              address: contract_address,
              transaction: transaction_b,
              block_number: transaction_b.block.number,
              block: transaction_b.block,
              index: i
            )
          end ++
          for i <- 1..600 do
            insert(:log,
              address: contract_address,
              transaction: transaction_c,
              block_number: transaction_c.block.number,
              block: transaction_c.block,
              index: i
            )
          end

      filter = %{
        from_block: transaction_a.block.number,
        to_block: transaction_c.block.number,
        address_hash: contract_address.hash
      }

      first_found_logs = Logs.list_logs(filter)

      assert Enum.count(first_found_logs) == 1_000

      last_record = List.last(first_found_logs)

      next_page_params = %{
        log_index: last_record.index,
        block_number: last_record.block_number
      }

      second_found_logs = Logs.list_logs(filter, next_page_params)

      assert Enum.count(second_found_logs) == 1_000

      all_found_logs = first_found_logs ++ second_found_logs

      assert Enum.all?(inserted_records, fn record ->
               Enum.any?(all_found_logs, fn found_log -> found_log.index == record.index end)
             end)
    end

    test "with a valid topic{x}" do
      contract_address = insert(:contract_address)

      transaction =
        %Transaction{block: block} =
        :transaction
        |> insert(to_address: contract_address)
        |> with_block()

      log1_details = [
        address: contract_address,
        transaction: transaction,
        block: block,
        block_number: block.number,
        first_topic: topic(@first_topic_hex_string_1)
      ]

      log2_details = [
        address: contract_address,
        transaction: transaction,
        block: block,
        block_number: block.number,
        first_topic: topic(@first_topic_hex_string_2)
      ]

      log1 = insert(:log, log1_details)
      _log2 = insert(:log, log2_details)

      filter = %{
        from_block: block.number,
        to_block: block.number,
        first_topic: log1.first_topic
      }

      [found_log] = Logs.list_logs(filter)

      assert found_log.first_topic == log1.first_topic
      assert found_log.index == log1.index
    end

    test "with a valid topic{x} AND another" do
      contract_address = insert(:contract_address)

      transaction =
        %Transaction{block: block} =
        :transaction
        |> insert(to_address: contract_address)
        |> with_block()

      log1_details = [
        address: contract_address,
        transaction: transaction,
        block: block,
        block_number: block.number,
        first_topic: topic(@first_topic_hex_string_1),
        second_topic: topic(@second_topic_hex_string_1)
      ]

      log2_details = [
        address: contract_address,
        transaction: transaction,
        block: block,
        block_number: block.number,
        first_topic: topic(@first_topic_hex_string_1),
        second_topic: topic(@second_topic_hex_string_2)
      ]

      _log1 = insert(:log, log1_details)
      log2 = insert(:log, log2_details)

      filter = %{
        from_block: block.number,
        to_block: block.number,
        first_topic: log2.first_topic,
        second_topic: log2.second_topic,
        topic0_1_opr: "and"
      }

      [found_log] = Logs.list_logs(filter)

      assert found_log.second_topic == log2.second_topic
      assert found_log.first_topic == log2.first_topic
      assert found_log.index == log2.index
    end

    test "with a valid topic{x} OR another" do
      contract_address = insert(:contract_address)

      transaction =
        %Transaction{block: block} =
        :transaction
        |> insert(to_address: contract_address)
        |> with_block()

      log1_details = [
        address: contract_address,
        transaction: transaction,
        block: block,
        block_number: block.number,
        first_topic: topic(@first_topic_hex_string_1),
        second_topic: topic(@second_topic_hex_string_1)
      ]

      log2_details = [
        address: contract_address,
        transaction: transaction,
        block: block,
        block_number: block.number,
        first_topic: topic(@first_topic_hex_string_2),
        second_topic: topic(@second_topic_hex_string_2)
      ]

      log1 = insert(:log, log1_details)
      log2 = insert(:log, log2_details)

      filter = %{
        from_block: block.number,
        to_block: block.number,
        first_topic: log1.first_topic,
        second_topic: log2.second_topic,
        topic0_1_opr: "or"
      }

      found_logs = Logs.list_logs(filter)

      assert length(found_logs) == 2
    end

    test "with address and topic{x}" do
      contract_address = insert(:contract_address)

      transaction =
        %Transaction{block: block} =
        :transaction
        |> insert(to_address: contract_address)
        |> with_block()

      log1_details = [
        address: contract_address,
        transaction: transaction,
        block: block,
        first_topic: topic(@first_topic_hex_string_1),
        block_number: block.number
      ]

      log2_details = [
        address: contract_address,
        transaction: transaction,
        block: block,
        first_topic: topic(@first_topic_hex_string_2),
        block_number: block.number
      ]

      _log1 = insert(:log, log1_details)
      log2 = insert(:log, log2_details)

      filter = %{
        from_block: block.number,
        to_block: block.number,
        address_hash: contract_address.hash,
        first_topic: log2.first_topic
      }

      [found_log] = Logs.list_logs(filter)

      assert found_log.index == log2.index
      assert found_log.first_topic == log2.first_topic
    end

    test "with address and multiple values for a topic{x}" do
      contract_address = insert(:contract_address)

      transaction =
        %Transaction{block: block} =
        :transaction
        |> insert(to_address: contract_address)
        |> with_block()

      log1_details = [
        address: contract_address,
        transaction: transaction,
        block: block,
        first_topic: topic(@first_topic_hex_string_1),
        block_number: block.number
      ]

      log2_details = [
        address: contract_address,
        transaction: transaction,
        block: block,
        first_topic: topic(@first_topic_hex_string_2),
        block_number: block.number
      ]

      log3_details = [
        address: contract_address,
        transaction: transaction,
        block: block,
        first_topic: topic(@first_topic_hex_string_3),
        block_number: block.number
      ]

      log1 = insert(:log, log1_details)
      log2 = insert(:log, log2_details)
      _log3 = insert(:log, log3_details)

      filter = %{
        from_block: block.number,
        to_block: block.number,
        address_hash: contract_address.hash,
        first_topic: [log1.first_topic, log2.first_topic]
      }

      found_logs = Logs.list_logs(filter)

      assert Enum.map(found_logs, & &1.index) == [log1.index, log2.index]
      assert Enum.map(found_logs, & &1.first_topic) == [log1.first_topic, log2.first_topic]
    end

    test "with address and two topic{x}s" do
      contract_address = insert(:contract_address)

      transaction =
        %Transaction{block: block} =
        :transaction
        |> insert(to_address: contract_address)
        |> with_block()

      log1_details = [
        address: contract_address,
        transaction: transaction,
        block: block,
        first_topic: topic(@first_topic_hex_string_1),
        second_topic: topic(@second_topic_hex_string_1),
        block_number: block.number
      ]

      log2_details = [
        address: contract_address,
        transaction: transaction,
        block: block,
        first_topic: topic(@first_topic_hex_string_2),
        second_topic: topic(@second_topic_hex_string_2),
        block_number: block.number
      ]

      _log1 = insert(:log, log1_details)
      log2 = insert(:log, log2_details)

      filter = %{
        from_block: block.number,
        to_block: block.number,
        address_hash: contract_address.hash,
        first_topic: log2.first_topic,
        second_topic: log2.second_topic,
        topic0_1_opr: "and"
      }

      [found_log] = Logs.list_logs(filter)

      assert found_log.index == log2.index
      assert found_log.first_topic == log2.first_topic
    end

    test "with address and three topic{x}s with AND operator" do
      contract_address = insert(:contract_address)

      transaction =
        %Transaction{block: block} =
        :transaction
        |> insert(to_address: contract_address)
        |> with_block()

      log1_details = [
        address: contract_address,
        transaction: transaction,
        block: block,
        first_topic: topic(@first_topic_hex_string_1),
        second_topic: topic(@second_topic_hex_string_1),
        third_topic: topic(@third_topic_hex_string_1),
        block_number: block.number
      ]

      log2_details = [
        address: contract_address,
        transaction: transaction,
        block: block,
        first_topic: topic(@first_topic_hex_string_2),
        second_topic: topic(@second_topic_hex_string_2),
        third_topic: topic(@third_topic_hex_string_2),
        block_number: block.number
      ]

      log3_details = [
        address: contract_address,
        transaction: transaction,
        block: block,
        first_topic: topic(@first_topic_hex_string_3),
        second_topic: topic(@second_topic_hex_string_3),
        third_topic: topic(@third_topic_hex_string_3),
        block_number: block.number
      ]

      _log1 = insert(:log, log1_details)
      log2 = insert(:log, log2_details)
      _log3 = insert(:log, log3_details)

      filter = %{
        from_block: block.number,
        to_block: block.number,
        address_hash: contract_address.hash,
        first_topic: log2.first_topic,
        second_topic: log2.second_topic,
        third_topic: log2.third_topic,
        topic0_1_opr: "and",
        topic0_2_opr: "and",
        topic1_2_opr: "and"
      }

      [found_log] = Logs.list_logs(filter)

      assert found_log.index == log2.index
      assert found_log.first_topic == log2.first_topic
      assert found_log.second_topic == log2.second_topic
      assert found_log.third_topic == log2.third_topic
    end

    test "with address and three topic{x}s with OR operator" do
      contract_address = insert(:contract_address)

      transaction =
        %Transaction{block: block} =
        :transaction
        |> insert(to_address: contract_address)
        |> with_block()

      log1_details = [
        address: contract_address,
        transaction: transaction,
        block: block,
        first_topic: topic(@first_topic_hex_string_1),
        second_topic: topic(@second_topic_hex_string_1),
        third_topic: topic(@third_topic_hex_string_1),
        block_number: block.number
      ]

      log2_details = [
        address: contract_address,
        transaction: transaction,
        block: block,
        first_topic: topic(@first_topic_hex_string_2),
        second_topic: topic(@second_topic_hex_string_2),
        third_topic: topic(@third_topic_hex_string_2),
        block_number: block.number
      ]

      log3_details = [
        address: contract_address,
        transaction: transaction,
        block: block,
        first_topic: topic(@first_topic_hex_string_3),
        second_topic: topic(@second_topic_hex_string_3),
        third_topic: topic(@third_topic_hex_string_3),
        block_number: block.number
      ]

      log1 = insert(:log, log1_details)
      log2 = insert(:log, log2_details)
      _log3 = insert(:log, log3_details)

      filter = %{
        from_block: block.number,
        to_block: block.number,
        address_hash: contract_address.hash,
        first_topic: log1.first_topic,
        second_topic: log2.second_topic,
        third_topic: log2.third_topic,
        topic0_1_opr: "or",
        topic0_2_opr: "or",
        topic1_2_opr: "or"
      }

      [found_log] = Logs.list_logs(filter)

      assert found_log.index == log2.index
      assert found_log.first_topic == log2.first_topic
      assert found_log.second_topic == log2.second_topic
      assert found_log.third_topic == log2.third_topic
    end

    test "three topic{x}s with OR and AND operator" do
      contract_address = insert(:contract_address)

      transaction =
        %Transaction{block: block} =
        :transaction
        |> insert(to_address: contract_address)
        |> with_block()

      log1_details = [
        address: contract_address,
        transaction: transaction,
        block: block,
        first_topic: topic(@first_topic_hex_string_1),
        second_topic: topic(@second_topic_hex_string_1),
        third_topic: topic(@third_topic_hex_string_1),
        block_number: block.number
      ]

      log2_details = [
        address: contract_address,
        transaction: transaction,
        block: block,
        first_topic: topic(@first_topic_hex_string_1),
        second_topic: topic(@second_topic_hex_string_2),
        third_topic: topic(@third_topic_hex_string_1),
        block_number: block.number
      ]

      log3_details = [
        address: contract_address,
        transaction: transaction,
        block: block,
        first_topic: topic(@first_topic_hex_string_1),
        second_topic: topic(@second_topic_hex_string_1),
        third_topic: topic(@third_topic_hex_string_1),
        block_number: block.number
      ]

      log1 = insert(:log, log1_details)
      log2 = insert(:log, log2_details)
      _log3 = insert(:log, log3_details)

      filter = %{
        from_block: block.number,
        to_block: block.number,
        address_hash: contract_address.hash,
        first_topic: log1.first_topic,
        second_topic: log2.second_topic,
        third_topic: log2.third_topic,
        topic0_1_opr: "or",
        topic0_2_opr: "or",
        topic1_2_opr: "and"
      }

      [found_log] = Logs.list_logs(filter)

      assert found_log.index == log2.index
      assert found_log.first_topic == log2.first_topic
      assert found_log.second_topic == log2.second_topic
      assert found_log.third_topic == log2.third_topic
    end

    test "four topic{x}s with all possible operators" do
      contract_address = insert(:contract_address)

      transaction =
        %Transaction{block: block} =
        :transaction
        |> insert(to_address: contract_address)
        |> with_block()

      log1_details = [
        address: contract_address,
        transaction: transaction,
        block: block,
        first_topic: topic(@first_topic_hex_string_1),
        second_topic: topic(@second_topic_hex_string_1),
        block_number: block.number
      ]

      log2_details = [
        address: contract_address,
        transaction: transaction,
        block: block,
        first_topic: topic(@first_topic_hex_string_2),
        second_topic: topic(@second_topic_hex_string_2),
        third_topic: topic(@third_topic_hex_string_2),
        fourth_topic: topic(@fourth_topic_hex_string_1),
        block_number: block.number
      ]

      log3_details = [
        address: contract_address,
        transaction: transaction,
        block: block,
        first_topic: topic(@first_topic_hex_string_1),
        second_topic: topic(@second_topic_hex_string_1),
        third_topic: topic(@third_topic_hex_string_1),
        fourth_topic: topic(@fourth_topic_hex_string_1),
        block_number: block.number
      ]

      log1 = insert(:log, log1_details)
      log2 = insert(:log, log2_details)
      _log3 = insert(:log, log3_details)

      filter = %{
        from_block: block.number,
        to_block: block.number,
        address_hash: contract_address.hash,
        first_topic: log1.first_topic,
        second_topic: log2.second_topic,
        third_topic: log2.third_topic,
        fourth_topic: log2.fourth_topic,
        topic0_1_opr: "or",
        topic0_2_opr: "or",
        topic0_3_opr: "or",
        topic1_2_opr: "and",
        topic1_3_opr: "and",
        topic2_3_opr: "and"
      }

      [found_log] = Logs.list_logs(filter)

      assert found_log.index == log2.index
      assert found_log.first_topic == log2.first_topic
      assert found_log.second_topic == log2.second_topic
      assert found_log.third_topic == log2.third_topic
    end

    test "returned logs are sorted by block" do
      first_block = insert(:block)
      second_block = insert(:block)
      third_block = insert(:block)

      contract_address = insert(:contract_address)

      transaction_block1 =
        %Transaction{} =
        :transaction
        |> insert(to_address: contract_address)
        |> with_block(first_block)

      transaction_block2 =
        %Transaction{} =
        :transaction
        |> insert(to_address: contract_address)
        |> with_block(second_block)

      transaction_block3 =
        %Transaction{} =
        :transaction
        |> insert(to_address: contract_address)
        |> with_block(third_block)

      insert(:log,
        address: contract_address,
        transaction: transaction_block3,
        block: third_block,
        block_number: third_block.number
      )

      insert(:log,
        address: contract_address,
        transaction: transaction_block1,
        block: first_block,
        block_number: first_block.number
      )

      insert(:log,
        address: contract_address,
        transaction: transaction_block2,
        block: second_block,
        block_number: second_block.number
      )

      filter = %{
        from_block: first_block.number,
        to_block: third_block.number,
        address_hash: contract_address.hash
      }

      found_logs = Logs.list_logs(filter)

      block_number_order = Enum.map(found_logs, & &1.block_number)

      assert block_number_order == Enum.sort(block_number_order)
    end

    test "paginates topic-only logs" do
      contract_address = insert(:contract_address)
      first_topic = topic(@first_topic_hex_string_1)

      transaction_a =
        :transaction
        |> insert(to_address: contract_address)
        |> with_block()

      transaction_b =
        :transaction
        |> insert(to_address: contract_address)
        |> with_block()

      transaction_c =
        :transaction
        |> insert(to_address: contract_address)
        |> with_block()

      inserted_records =
        for {transaction, count} <- [{transaction_a, 700}, {transaction_b, 700}, {transaction_c, 600}],
            i <- 1..count do
          insert(:log,
            address: contract_address,
            transaction: transaction,
            block_number: transaction.block.number,
            block: transaction.block,
            index: i,
            first_topic: first_topic
          )
        end

      # A log with a different topic in the same range must not be returned.
      insert(:log,
        address: contract_address,
        transaction: transaction_a,
        block_number: transaction_a.block.number,
        block: transaction_a.block,
        index: 701,
        first_topic: topic(@first_topic_hex_string_2)
      )

      filter = %{
        from_block: transaction_a.block.number,
        to_block: transaction_c.block.number,
        first_topic: first_topic
      }

      first_found_logs = Logs.list_logs(filter)

      assert Enum.count(first_found_logs) == 1_000

      last_record = List.last(first_found_logs)

      next_page_params = %{
        log_index: last_record.index,
        block_number: last_record.block_number
      }

      second_found_logs = Logs.list_logs(filter, next_page_params)

      assert Enum.count(second_found_logs) == 1_000

      all_found_logs = first_found_logs ++ second_found_logs

      assert Enum.all?(all_found_logs, &(&1.first_topic == first_topic))

      found_keys = MapSet.new(all_found_logs, &{&1.block_number, &1.index})
      inserted_keys = MapSet.new(inserted_records, &{&1.block_number, &1.index})

      assert MapSet.equal?(found_keys, inserted_keys)
    end

    test "topic-only logs are sorted by block and index" do
      first_block = insert(:block)
      second_block = insert(:block)
      third_block = insert(:block)

      contract_address = insert(:contract_address)
      first_topic = topic(@first_topic_hex_string_1)

      transaction_block1 =
        %Transaction{} =
        :transaction
        |> insert(to_address: contract_address)
        |> with_block(first_block)

      transaction_block2 =
        %Transaction{} =
        :transaction
        |> insert(to_address: contract_address)
        |> with_block(second_block)

      transaction_block3 =
        %Transaction{} =
        :transaction
        |> insert(to_address: contract_address)
        |> with_block(third_block)

      for {transaction, block, index} <- [
            {transaction_block3, third_block, 1},
            {transaction_block1, first_block, 2},
            {transaction_block2, second_block, 1},
            {transaction_block1, first_block, 1}
          ] do
        insert(:log,
          address: contract_address,
          transaction: transaction,
          block: block,
          block_number: block.number,
          index: index,
          first_topic: first_topic
        )
      end

      filter = %{
        from_block: first_block.number,
        to_block: third_block.number,
        first_topic: first_topic
      }

      found_logs = Logs.list_logs(filter)

      assert length(found_logs) == 4

      order = Enum.map(found_logs, &{&1.block_number, &1.index})

      assert order == Enum.sort(order)
    end

    test "topic-only logs skip a full page of non-consensus logs and still return later consensus logs" do
      contract_address = insert(:contract_address)
      first_topic = topic(@first_topic_hex_string_1)

      non_consensus_block = insert(:block)
      consensus_block = insert(:block, number: non_consensus_block.number + 1)

      non_consensus_transaction =
        :transaction
        |> insert(to_address: contract_address)
        |> with_block(non_consensus_block)

      consensus_transaction =
        :transaction
        |> insert(to_address: contract_address)
        |> with_block(consensus_block)

      for i <- 1..1_000 do
        insert(:log,
          address: contract_address,
          transaction: non_consensus_transaction,
          block: non_consensus_block,
          block_number: non_consensus_block.number,
          index: i,
          first_topic: first_topic
        )
      end

      consensus_log =
        insert(:log,
          address: contract_address,
          transaction: consensus_transaction,
          block: consensus_block,
          block_number: consensus_block.number,
          index: 1,
          first_topic: first_topic
        )

      # The factory only attaches transactions to consensus blocks, so the
      # reorg is simulated after the fact.
      Repo.update_all(from(b in Block, where: b.hash == ^non_consensus_block.hash), set: [consensus: false])

      Repo.update_all(from(t in Transaction, where: t.hash == ^non_consensus_transaction.hash),
        set: [block_consensus: false]
      )

      filter = %{
        from_block: non_consensus_block.number,
        to_block: consensus_block.number,
        first_topic: first_topic
      }

      [found_log] = Logs.list_logs(filter)

      assert found_log.block_number == consensus_log.block_number
      assert found_log.index == consensus_log.index
      assert found_log.block_consensus == true
    end

    test "topic-only logs skip a full page of logs whose transactions lost consensus while their block did not" do
      old_denormalization_finished = BackgroundMigrations.get_transactions_denormalization_finished()
      BackgroundMigrations.set_transactions_denormalization_finished(true)

      on_exit(fn ->
        BackgroundMigrations.set_transactions_denormalization_finished(old_denormalization_finished)
      end)

      contract_address = insert(:contract_address)
      first_topic = topic(@first_topic_hex_string_1)

      stale_block = insert(:block)
      consensus_block = insert(:block, number: stale_block.number + 1)

      stale_transaction =
        :transaction
        |> insert(to_address: contract_address)
        |> with_block(stale_block)

      consensus_transaction =
        :transaction
        |> insert(to_address: contract_address)
        |> with_block(consensus_block)

      for i <- 1..1_000 do
        insert(:log,
          address: contract_address,
          transaction: stale_transaction,
          block: stale_block,
          block_number: stale_block.number,
          index: i,
          first_topic: first_topic
        )
      end

      consensus_log =
        insert(:log,
          address: contract_address,
          transaction: consensus_transaction,
          block: consensus_block,
          block_number: consensus_block.number,
          index: 1,
          first_topic: first_topic
        )

      # `transactions.block_consensus` and `blocks.consensus` can diverge; the
      # block keeps consensus here while the denormalized flag says otherwise.
      Repo.update_all(from(t in Transaction, where: t.hash == ^stale_transaction.hash),
        set: [block_consensus: false]
      )

      filter = %{
        from_block: stale_block.number,
        to_block: consensus_block.number,
        first_topic: first_topic
      }

      [found_log] = Logs.list_logs(filter)

      assert found_log.block_number == consensus_log.block_number
      assert found_log.index == consensus_log.index
    end
  end
end
