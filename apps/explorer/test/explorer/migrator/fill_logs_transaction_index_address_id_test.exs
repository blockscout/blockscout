defmodule Explorer.Migrator.FillLogsTransactionIndexAddressIdTest do
  use Explorer.DataCase, async: false

  import Ecto.Query

  alias Explorer.Chain.Log
  alias Explorer.Migrator.{FillLogsTransactionIndexAddressId, MigrationStatus}
  alias Explorer.Migrator.HeavyDbIndexOperation.CreateLogsBlockNumberTransactionIndexIndexUniqueIndex
  alias Explorer.Repo
  alias Explorer.Utility.AddressIdToAddressHash

  test "fills address_id" do
    transaction = :transaction |> insert() |> with_block()
    insert_list(10, :log, transaction: transaction, address_id: nil)

    MigrationStatus.set_status(
      CreateLogsBlockNumberTransactionIndexIndexUniqueIndex.migration_name(),
      "completed"
    )

    assert MigrationStatus.get_status("fill_logs_transaction_index_address_id") == nil

    Application.put_env(:explorer, FillLogsTransactionIndexAddressId, batch_size: 100, timeout: 0)

    FillLogsTransactionIndexAddressId.start_link([])

    wait_for_results(fn ->
      Repo.one!(
        from(ms in MigrationStatus,
          where: ms.migration_name == ^"fill_logs_transaction_index_address_id" and ms.status == "completed"
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
  end
end
