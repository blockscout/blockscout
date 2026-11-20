# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.HeavyDbIndexOperation.ReindexTokenTransfersTokenContractAddressHashIndexesTest do
  use Explorer.DataCase, async: false

  alias Explorer.Migrator.{HeavyDbIndexOperation, MigrationStatus}

  alias Explorer.Migrator.HeavyDbIndexOperation.{
    Helper,
    ReindexTokenTransfersTokenContractAddressHashBlockNumberDescLogIndexDescIndex,
    ReindexTokenTransfersTokenContractAddressHashTokenIdsIndex,
    VacuumTokenTransfersAfterEip7708Sanitizing
  }

  alias Explorer.Repo

  @btree_index_name "token_transfers_token_contract_address_hash__block_number_DESC_"
  @gin_index_name "token_transfers_token_contract_address_hash_token_ids_index"

  # The names PostgreSQL gives to the transient indexes of `REINDEX INDEX CONCURRENTLY`: the
  # name of the rebuilt index, truncated to fit into 63 bytes together with the suffix.
  @btree_leftover_index_name "token_transfers_token_contract_address_hash__block_number_ccnew"
  @gin_leftover_index_name "token_transfers_token_contract_address_hash_token_ids_ind_ccnew"

  setup do
    configuration = Application.get_env(:explorer, HeavyDbIndexOperation)
    Application.put_env(:explorer, HeavyDbIndexOperation, Keyword.merge(configuration || [], check_interval: 200))

    on_exit(fn ->
      Application.put_env(:explorer, HeavyDbIndexOperation, configuration)
    end)

    :ok
  end

  describe "Rebuilds heavy index `#{@btree_index_name}`" do
    test "only after the table is vacuumed" do
      migration_name = ReindexTokenTransfersTokenContractAddressHashBlockNumberDescLogIndexDescIndex.migration_name()
      vacuum_migration_name = VacuumTokenTransfersAfterEip7708Sanitizing.migration_name()

      assert migration_name ==
               "heavy_indexes_reindex_token_transfers_token_contract_address_hash__block_number_desc_"

      assert ReindexTokenTransfersTokenContractAddressHashBlockNumberDescLogIndexDescIndex.dependent_from_migrations() ==
               [vacuum_migration_name]

      index_file_before = index_file(@btree_index_name)

      {:ok, pid} = ReindexTokenTransfersTokenContractAddressHashBlockNumberDescLogIndexDescIndex.start_link([])
      Process.sleep(300)

      # Should not start until the vacuum is completed
      assert MigrationStatus.get_status(migration_name) == nil

      insert(:db_migration_status, migration_name: vacuum_migration_name, status: "started")
      Process.sleep(300)

      assert MigrationStatus.get_status(migration_name) == nil
      assert index_file(@btree_index_name) == index_file_before

      MigrationStatus.set_status(vacuum_migration_name, "completed")
      await_normal_termination(pid)

      assert %{status: "completed", meta: %{"db_operation_finished" => true}} = MigrationStatus.fetch(migration_name)

      # A rebuilt index is stored in a new file
      assert index_file(@btree_index_name) != index_file_before
      assert Helper.db_index_exists_and_valid?(@btree_index_name) == %{exists?: true, valid?: true}
    end

    test "after dropping the invalid index left by an interrupted rebuild" do
      migration_name = ReindexTokenTransfersTokenContractAddressHashBlockNumberDescLogIndexDescIndex.migration_name()

      insert(:db_migration_status,
        migration_name: VacuumTokenTransfersAfterEip7708Sanitizing.migration_name(),
        status: "completed"
      )

      # On an empty DB the operation is run right on start, without looking at its status
      insert(:block)

      # Emulates `REINDEX INDEX CONCURRENTLY` interrupted in the middle
      insert(:db_migration_status, migration_name: migration_name, status: "started")

      create_invalid_index(
        @btree_leftover_index_name,
        "btree (token_contract_address_hash, block_number DESC, log_index DESC)"
      )

      assert Helper.db_index_reindexing_status(@btree_index_name, migration_name) == :not_completed

      index_file_before = index_file(@btree_index_name)

      {:ok, pid} = ReindexTokenTransfersTokenContractAddressHashBlockNumberDescLogIndexDescIndex.start_link([])
      await_normal_termination(pid)

      assert MigrationStatus.get_status(migration_name) == "completed"
      assert Helper.db_index_exists_and_valid?(@btree_leftover_index_name) == %{exists?: false, valid?: nil}
      assert index_file(@btree_index_name) != index_file_before
    end
  end

  describe "Rebuilds heavy index `#{@gin_index_name}`" do
    test "only after the previous index is rebuilt" do
      migration_name = ReindexTokenTransfersTokenContractAddressHashTokenIdsIndex.migration_name()

      previous_migration_name =
        ReindexTokenTransfersTokenContractAddressHashBlockNumberDescLogIndexDescIndex.migration_name()

      assert migration_name == "heavy_indexes_reindex_token_transfers_token_contract_address_hash_token_ids_index"

      assert ReindexTokenTransfersTokenContractAddressHashTokenIdsIndex.dependent_from_migrations() ==
               [previous_migration_name]

      index_file_before = index_file(@gin_index_name)

      {:ok, pid} = ReindexTokenTransfersTokenContractAddressHashTokenIdsIndex.start_link([])
      Process.sleep(300)

      assert MigrationStatus.get_status(migration_name) == nil

      insert(:db_migration_status, migration_name: previous_migration_name, status: "completed")
      await_normal_termination(pid)

      assert MigrationStatus.get_status(migration_name) == "completed"
      assert index_file(@gin_index_name) != index_file_before
      assert Helper.db_index_exists_and_valid?(@gin_index_name) == %{exists?: true, valid?: true}
    end

    test "drops only its own leftovers, and only once the previous index is rebuilt" do
      migration_name = ReindexTokenTransfersTokenContractAddressHashTokenIdsIndex.migration_name()

      previous_migration_name =
        ReindexTokenTransfersTokenContractAddressHashBlockNumberDescLogIndexDescIndex.migration_name()

      insert(:block)

      # Emulates the rebuild of the previous index being in progress: its transient index
      # is invalid until the rebuild finishes.
      insert(:db_migration_status, migration_name: previous_migration_name, status: "started")

      create_invalid_index(
        @btree_leftover_index_name,
        "btree (token_contract_address_hash, block_number DESC, log_index DESC)"
      )

      # An invalid index of another operation is not a leftover of this one
      assert Helper.db_index_reindexing_status(@gin_index_name, migration_name) == :not_initialized
      assert Helper.drop_interrupted_reindex_leftovers(@gin_index_name) == :ok
      assert Helper.db_index_exists_and_valid?(@btree_leftover_index_name) == %{exists?: true, valid?: false}

      # Emulates the rebuild of this index interrupted in the middle
      insert(:db_migration_status, migration_name: migration_name, status: "started")
      create_invalid_index(@gin_leftover_index_name, "gin (token_contract_address_hash, token_ids)")

      assert Helper.db_index_reindexing_status(@gin_index_name, migration_name) == :not_completed

      {:ok, pid} = ReindexTokenTransfersTokenContractAddressHashTokenIdsIndex.start_link([])
      Process.sleep(300)

      # The cleanup doesn't start until the previous index is rebuilt
      assert Helper.db_index_exists_and_valid?(@gin_leftover_index_name) == %{exists?: true, valid?: false}
      assert Helper.db_index_exists_and_valid?(@btree_leftover_index_name) == %{exists?: true, valid?: false}

      MigrationStatus.set_status(previous_migration_name, "completed")
      await_normal_termination(pid)

      assert MigrationStatus.get_status(migration_name) == "completed"
      assert Helper.db_index_exists_and_valid?(@gin_leftover_index_name) == %{exists?: false, valid?: nil}
      assert Helper.db_index_exists_and_valid?(@btree_leftover_index_name) == %{exists?: true, valid?: false}
    end

    test "is completed without a rebuild if the index doesn't exist" do
      migration_name = ReindexTokenTransfersTokenContractAddressHashTokenIdsIndex.migration_name()

      insert(:db_migration_status,
        migration_name: ReindexTokenTransfersTokenContractAddressHashBlockNumberDescLogIndexDescIndex.migration_name(),
        status: "completed"
      )

      # On an empty DB the operation is run right on start, and the process isn't started
      insert(:block)
      Repo.query!(~s(DROP INDEX "#{@gin_index_name}"))

      {:ok, pid} = ReindexTokenTransfersTokenContractAddressHashTokenIdsIndex.start_link([])
      await_normal_termination(pid)

      assert MigrationStatus.get_status(migration_name) == "completed"
      assert Helper.db_index_exists_and_valid?(@gin_index_name) == %{exists?: false, valid?: nil}
    end
  end

  describe "running_other_heavy_migration_for_table_exists?/2" do
    test "takes running vacuum and reindex operations into account" do
      vacuum_migration_name = VacuumTokenTransfersAfterEip7708Sanitizing.migration_name()
      reindex_migration_name = ReindexTokenTransfersTokenContractAddressHashTokenIdsIndex.migration_name()

      refute MigrationStatus.running_other_heavy_migration_for_table_exists?(:token_transfers, "other")

      insert(:db_migration_status, migration_name: vacuum_migration_name, status: "started")

      assert MigrationStatus.running_other_heavy_migration_for_table_exists?(:token_transfers, "other")
      refute MigrationStatus.running_other_heavy_migration_for_table_exists?(:token_transfers, vacuum_migration_name)
      refute MigrationStatus.running_other_heavy_migration_for_table_exists?(:logs, "other")

      MigrationStatus.set_status(vacuum_migration_name, "completed")
      insert(:db_migration_status, migration_name: reindex_migration_name, status: "started")

      assert MigrationStatus.running_other_heavy_migration_for_table_exists?(:token_transfers, "other")
      refute MigrationStatus.running_other_heavy_migration_for_table_exists?(:token_transfers, reindex_migration_name)
    end
  end

  # Waits for the migrator to finish. The process may have terminated before it is
  # monitored, in which case the monitor reports `:noproc`.
  defp await_normal_termination(pid) do
    ref = Process.monitor(pid)

    assert_receive {:DOWN, ^ref, :process, ^pid, reason}, :timer.seconds(30)
    assert reason in [:normal, :noproc]
  end

  defp create_invalid_index(index_name, definition) do
    Repo.query!(~s(CREATE INDEX "#{index_name}" ON token_transfers USING #{definition}))

    Repo.query!("UPDATE pg_index SET indisvalid = false WHERE indexrelid = $1::text::regclass", [~s("#{index_name}")])

    assert Helper.db_index_exists_and_valid?(index_name) == %{exists?: true, valid?: false}
  end

  defp index_file(index_name) do
    %{rows: [[file]]} = Repo.query!("SELECT relfilenode FROM pg_class WHERE relname = $1", [index_name])

    file
  end
end
