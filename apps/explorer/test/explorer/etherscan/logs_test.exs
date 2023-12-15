defmodule Explorer.Etherscan.LogsTest do
  use Explorer.DataCase

  import Explorer.Factory

  alias Explorer.Etherscan.Logs
  alias Explorer.Chain.Transaction

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

      log = insert(:log, address: contract_address, block_number: block.number, transaction: transaction)

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

      insert_list(2, :log, address: contract_address, transaction: transaction, block_number: block.number)

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

      insert(:log, address: contract_address, transaction: transaction_block1, block_number: first_block.number)
      insert(:log, address: contract_address, transaction: transaction_block2, block_number: second_block.number)

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

      insert(:log, address: contract_address, transaction: transaction_block1, block_number: first_block.number)
      insert(:log, address: contract_address, transaction: transaction_block2, block_number: second_block.number)

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

      transaction =
        %Transaction{block: block} =
        :transaction
        |> insert(to_address: contract_address)
        |> with_block()

      inserted_records =
        insert_list(2000, :log, address: contract_address, transaction: transaction, block_number: block.number)

      filter = %{
        from_block: block.number,
        to_block: block.number,
        address_hash: contract_address.hash
      }

      first_found_logs = Logs.list_logs(filter)

      assert Enum.count(first_found_logs) == 1_000

      last_record = List.last(first_found_logs)

      next_page_params = %{
        log_index: last_record.index,
        block_number: transaction.block_number
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
        first_topic: "some topic"
      ]

      log2_details = [
        address: contract_address,
        transaction: transaction,
        first_topic: "some other topic"
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
        first_topic: "some first topic",
        second_topic: "some second topic"
      ]

      log2_details = [
        address: contract_address,
        transaction: transaction,
        first_topic: "some first topic",
        second_topic: "some OTHER second topic"
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
        first_topic: "some first topic",
        second_topic: "some second topic"
      ]

      log2_details = [
        address: contract_address,
        transaction: transaction,
        first_topic: "some OTHER first topic",
        second_topic: "some OTHER second topic"
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
        first_topic: "some first topic",
        block_number: block.number
      ]

      log2_details = [
        address: contract_address,
        transaction: transaction,
        first_topic: "some OTHER first topic",
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
        first_topic: "some first topic",
        second_topic: "some second topic",
        block_number: block.number
      ]

      log2_details = [
        address: contract_address,
        transaction: transaction,
        first_topic: "some OTHER first topic",
        second_topic: "some OTHER second topic",
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
        first_topic: "some first topic",
        second_topic: "some second topic",
        third_topic: "some third topic",
        block_number: block.number
      ]

      log2_details = [
        address: contract_address,
        transaction: transaction,
        first_topic: "some OTHER first topic",
        second_topic: "some OTHER second topic",
        third_topic: "some OTHER third topic",
        block_number: block.number
      ]

      log3_details = [
        address: contract_address,
        transaction: transaction,
        first_topic: "some ALT first topic",
        second_topic: "some ALT second topic",
        third_topic: "some ALT third topic",
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
        first_topic: "some first topic",
        second_topic: "some second topic",
        third_topic: "some third topic",
        block_number: block.number
      ]

      log2_details = [
        address: contract_address,
        transaction: transaction,
        first_topic: "some OTHER first topic",
        second_topic: "some OTHER second topic",
        third_topic: "some OTHER third topic",
        block_number: block.number
      ]

      log3_details = [
        address: contract_address,
        transaction: transaction,
        first_topic: "some ALT first topic",
        second_topic: "some ALT second topic",
        third_topic: "some ALT third topic",
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
        first_topic: "some topic",
        second_topic: "some second topic",
        third_topic: "some third topic",
        block_number: block.number
      ]

      log2_details = [
        address: contract_address,
        transaction: transaction,
        first_topic: "some topic",
        second_topic: "some OTHER second topic",
        third_topic: "some third topic",
        block_number: block.number
      ]

      log3_details = [
        address: contract_address,
        transaction: transaction,
        first_topic: "some topic",
        second_topic: "some second topic",
        third_topic: "some third topic",
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
        first_topic: "some topic",
        second_topic: "some second topic",
        block_number: block.number
      ]

      log2_details = [
        address: contract_address,
        transaction: transaction,
        first_topic: "some OTHER topic",
        second_topic: "some OTHER second topic",
        third_topic: "some OTHER third topic",
        fourth_topic: "some fourth topic",
        block_number: block.number
      ]

      log3_details = [
        address: contract_address,
        transaction: transaction,
        first_topic: "some topic",
        second_topic: "some second topic",
        third_topic: "some third topic",
        fourth_topic: "some fourth topic",
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

      insert(:log, address: contract_address, transaction: transaction_block3)
      insert(:log, address: contract_address, transaction: transaction_block1)
      insert(:log, address: contract_address, transaction: transaction_block2)

      filter = %{
        from_block: first_block.number,
        to_block: third_block.number,
        address_hash: contract_address.hash
      }

      found_logs = Logs.list_logs(filter)

      block_number_order = Enum.map(found_logs, & &1.block_number)

      assert block_number_order == Enum.sort(block_number_order)
    end
  end
end
