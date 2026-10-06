defmodule Explorer.Migrator.FillLogsCompressedDataTest do
  use Explorer.DataCase, async: false

  import Ecto.Query

  alias Explorer.Chain.Log
  alias Explorer.Migrator.{FillLogsCompressedData, FillLogsOptimizedFields, MigrationStatus}
  alias Explorer.Repo

  test "fills compressed_data and empties data" do
    transaction = :transaction |> insert() |> with_block()

    initial_logs =
      10
      |> insert_list(:log, transaction: transaction, compressed_data: nil)
      |> Enum.sort_by(&{&1.block_number, &1.index})

    MigrationStatus.set_status(FillLogsOptimizedFields.migration_name(), "completed")

    assert Enum.all?(initial_logs, &(not is_nil(&1.data) and is_nil(&1.compressed_data)))
    assert MigrationStatus.get_status("fill_logs_compressed_data") == nil

    Application.put_env(:explorer, FillLogsCompressedData, batch_size: 100, timeout: 0)

    FillLogsCompressedData.start_link([])

    wait_for_results(fn ->
      Repo.one!(
        from(ms in MigrationStatus,
          where: ms.migration_name == ^"fill_logs_compressed_data" and ms.status == "completed"
        )
      )
    end)

    processed_logs =
      Log
      |> Repo.all()
      |> Enum.sort_by(&{&1.block_number, &1.index})

    zipped_logs = Enum.zip(initial_logs, processed_logs)

    assert Enum.all?(zipped_logs, fn {initial_log, processed_log} ->
             initial_log.data == processed_log.compressed_data and is_nil(processed_log.data)
           end)
  end
end
