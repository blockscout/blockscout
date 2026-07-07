defmodule Explorer.Migrator.FillLogsOptimizedFieldsTest do
  use Explorer.DataCase, async: false

  import Ecto.Query

  alias Explorer.Chain.{Log, TokenTransfer}
  alias Explorer.Migrator.{FillLogsOptimizedFields, MigrationStatus}
  alias Explorer.Migrator.HeavyDbIndexOperation.CreateLogsBlockNumberTransactionIndexIndexUniqueIndex
  alias Explorer.{Repo, TestHelper}
  alias Explorer.Utility.{AddressIdToAddressHash, LogFirstTopic}

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

    MigrationStatus.set_status(
      CreateLogsBlockNumberTransactionIndexIndexUniqueIndex.migration_name(),
      "completed"
    )

    assert MigrationStatus.get_status("fill_logs_optimized_fields") == nil

    Application.put_env(:explorer, FillLogsOptimizedFields, batch_size: 100, timeout: 0)

    FillLogsOptimizedFields.start_link([])

    wait_for_results(fn ->
      Repo.one!(
        from(ms in MigrationStatus,
          where: ms.migration_name == ^"fill_logs_optimized_fields" and ms.status == "completed"
        )
      )
    end)

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
end
