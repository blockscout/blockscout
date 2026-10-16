defmodule Explorer.Migrator.FillLogsOptimizedFieldsTest do
  use Explorer.DataCase, async: false

  import Ecto.Query

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Chain.{Log, TokenTransfer}
  alias Explorer.Migrator.{FillLogsOptimizedFields, MigrationStatus}
  alias Explorer.Migrator.HeavyDbIndexOperation.CreateLogsFirstTopicIdIndex
  alias Explorer.{Repo, TestHelper}
  alias Explorer.Utility.{AddressIdToAddressHash, LogFirstTopic}

  setup do
    initial_status = BackgroundMigrations.get_fill_logs_optimized_fields_finished()
    initial_config = Application.get_env(:explorer, FillLogsOptimizedFields)

    on_exit(fn ->
      BackgroundMigrations.set_fill_logs_optimized_fields_finished(initial_status)
      Application.put_env(:explorer, FillLogsOptimizedFields, initial_config)
    end)
  end

  test "fills relates fields" do
    transaction = :transaction |> insert() |> with_block()
    topic = TestHelper.topic("0x000000000000000000000000e8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca")

    insert_list(10, :log,
      transaction: transaction,
      address_id: nil,
      first_topic: TokenTransfer.constant(),
      transaction_index: nil,
      second_topic: topic,
      third_topic: topic,
      fourth_topic: topic
    )

    assert MigrationStatus.get_status("fill_logs_optimized_fields") == nil

    put_config(batch_size: 100, timeout: 0)

    run_migration()

    all_logs = Repo.all(Log)

    assert Enum.all?(all_logs, &(is_nil(&1.address_hash) and not is_nil(&1.address_id)))

    all_address_ids =
      all_logs
      |> Enum.map(& &1.address_id)
      |> Enum.uniq()
      |> Enum.reject(&is_nil/1)

    existing_address_ids =
      AddressIdToAddressHash
      |> Repo.all()
      |> Enum.map(& &1.address_id)

    assert Enum.all?(all_address_ids, &Enum.member?(existing_address_ids, &1))

    first_topic_id = LogFirstTopic.value_to_id(TokenTransfer.constant())

    assert Enum.all?(all_logs, &(is_nil(&1.first_topic) and &1.first_topic_id == first_topic_id))

    assert Enum.all?(all_logs, &(&1.transaction_index == transaction.index))

    assert Enum.all?(all_logs, &(&1.second_topic == topic and &1.third_topic == topic and &1.fourth_topic == topic))

    {:ok, %{rows: [[binary_topic, binary_topic, binary_topic]]}} =
      Repo.query("select second_topic, third_topic, fourth_topic from logs limit 1;")

    assert <<first, _::binary>> = binary_topic
    assert first != 0
  end

  test "keeps transaction_index of logs which are not linked to a transaction" do
    log = insert(:log, transaction: nil, transaction_index: 5)

    put_config(batch_size: 100, timeout: 0)

    run_migration()

    assert %Log{transaction_index: 5} = reload(log)
  end

  test "keeps logs which are already in the new format untouched" do
    old_format_block = insert(:block)
    new_format_block = insert(:block)

    old_format_log = insert_block_log(old_format_block)
    neighbour_new_format_log = insert_block_log(old_format_block)
    new_format_log = insert_block_log(new_format_block)

    to_old_format(old_format_log)
    to_new_format(neighbour_new_format_log)
    to_new_format(new_format_log)

    new_format_fields_before = Enum.map([neighbour_new_format_log, new_format_log], &(&1 |> reload() |> log_fields()))

    assert Enum.all?(new_format_fields_before, &(not is_nil(&1.address_id) and not is_nil(&1.first_topic_id)))

    put_config(batch_size: 100, timeout: 0)

    run_migration()

    assert Enum.map([neighbour_new_format_log, new_format_log], &(&1 |> reload() |> log_fields())) ==
             new_format_fields_before

    first_topic_id = LogFirstTopic.value_to_id(TokenTransfer.constant())

    assert %Log{address_hash: nil, first_topic: nil, first_topic_id: ^first_topic_id, address_id: address_id} =
             reload(old_format_log)

    refute is_nil(address_id)
  end

  test "processes logs of all blocks when windows are limited by the logs count" do
    logs_counts = [3, 1, 4, 2, 1]

    Enum.each(logs_counts, fn logs_count ->
      block = insert(:block)
      insert_list(logs_count, :log, block: block, block_number: block.number, first_topic: TokenTransfer.constant())
    end)

    Repo.update_all(Log, set: [address_id: nil, first_topic_id: nil])

    put_config(batch_size: 2, concurrency: 2, timeout: 0)

    run_migration()

    all_logs = Repo.all(Log)
    first_topic_id = LogFirstTopic.value_to_id(TokenTransfer.constant())

    assert Enum.count(all_logs) == Enum.sum(logs_counts)
    assert Enum.all?(all_logs, &(is_nil(&1.address_hash) and not is_nil(&1.address_id)))
    assert Enum.all?(all_logs, &(is_nil(&1.first_topic) and &1.first_topic_id == first_topic_id))
  end

  describe "split_into_batches/1" do
    test "groups whole blocks into batches of about batch_size logs" do
      put_config(batch_size: 3, concurrency: 3)

      assert FillLogsOptimizedFields.split_into_batches([10, 10, 10, 10, 9, 8, 8, 7]) == [[10], [9, 8], [7]]
    end

    test "returns no batches for no block numbers" do
      put_config(batch_size: 3, concurrency: 3)

      assert FillLogsOptimizedFields.split_into_batches([]) == []
    end
  end

  defp put_config(overrides) do
    config = Application.get_env(:explorer, FillLogsOptimizedFields) || []

    Application.put_env(:explorer, FillLogsOptimizedFields, Keyword.merge(config, overrides))
  end

  defp run_migration do
    MigrationStatus.set_status(CreateLogsFirstTopicIdIndex.migration_name(), "completed")

    FillLogsOptimizedFields.start_link([])

    wait_for_results(fn ->
      Repo.one!(
        from(ms in MigrationStatus,
          where: ms.migration_name == ^"fill_logs_optimized_fields" and ms.status == "completed"
        )
      )
    end)
  end

  defp insert_block_log(block) do
    transaction = :transaction |> insert() |> with_block(block)

    insert(:log,
      block: block,
      block_number: block.number,
      transaction: transaction,
      first_topic: TokenTransfer.constant()
    )
  end

  # Logs inserted before the upgrade have only the old fields filled
  defp to_old_format(log), do: update_log(log, address_id: nil, first_topic_id: nil)

  # Logs inserted by the indexer after the upgrade have only the new fields filled
  defp to_new_format(log), do: update_log(log, address_hash: nil, first_topic: nil)

  defp update_log(log, changes) do
    Log
    |> where([l], l.block_number == ^log.block_number and l.index == ^log.index)
    |> Repo.update_all(set: changes)
  end

  defp reload(log), do: Repo.get_by!(Log, block_number: log.block_number, index: log.index)

  defp log_fields(log),
    do: Map.take(log, [:address_id, :address_hash, :first_topic_id, :first_topic, :second_topic, :transaction_index])
end
