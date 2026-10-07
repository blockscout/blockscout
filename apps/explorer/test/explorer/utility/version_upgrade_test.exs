# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Utility.VersionUpgradeTest do
  use Explorer.DataCase, async: false

  alias Explorer.Application.Constants
  alias Explorer.Migrator.{FillInternalTransactionsAddressIds, MigrationStatus, SanitizeDuplicatedLogIndexLogs}
  alias Explorer.Utility.VersionUpgrade

  setup do
    chain_type = Application.get_env(:explorer, :chain_type)
    on_exit(fn -> Application.put_env(:explorer, :chain_type, chain_type) end)

    # the rules may require chain type specific migrations
    Application.put_env(:explorer, :chain_type, :default)
  end

  describe "validate_upgrade/2" do
    test "allows an upgrade to a version without rules" do
      assert VersionUpgrade.validate_upgrade("1.0.0", "10.0.0") == :ok
    end

    test "allows an upgrade from an unknown version of an empty database" do
      assert VersionUpgrade.validate_upgrade(nil, "12.0.0") == :ok
    end

    test "rejects an upgrade from an unknown version of an indexed database" do
      insert(:block)

      assert_raise RuntimeError, ~r/Current previous version: \(empty\)/, fn ->
        VersionUpgrade.validate_upgrade(nil, "12.0.0")
      end
    end

    test "rejects an upgrade from a version below the minimal one" do
      assert_raise RuntimeError, ~r/allowed only from version 11\.0\.2 and higher/, fn ->
        VersionUpgrade.validate_upgrade("11.0.1", "12.0.0")
      end
    end

    test "rejects an upgrade until the required migrations are completed" do
      MigrationStatus.set_status(FillInternalTransactionsAddressIds.migration_name(), "started")

      assert_raise RuntimeError, ~r/required migrations are not completed/, fn ->
        VersionUpgrade.validate_upgrade("11.0.2", "12.0.0")
      end

      MigrationStatus.set_status(FillInternalTransactionsAddressIds.migration_name(), "completed")

      assert VersionUpgrade.validate_upgrade("11.0.2", "12.0.0") == :ok
    end

    test "requires a chain type specific migration only on its chain types" do
      MigrationStatus.set_status(FillInternalTransactionsAddressIds.migration_name(), "completed")

      assert VersionUpgrade.validate_upgrade("11.0.2", "12.0.0") == :ok

      Application.put_env(:explorer, :chain_type, :rsk)

      exception =
        assert_raise RuntimeError, fn ->
          VersionUpgrade.validate_upgrade("11.0.2", "12.0.0")
        end

      assert exception.message =~ SanitizeDuplicatedLogIndexLogs.migration_name()
    end
  end

  describe "validate_before_migrations/0" do
    setup do
      config = Application.get_env(:explorer, VersionUpgrade)
      on_exit(fn -> Application.put_env(:explorer, VersionUpgrade, config) end)

      put_enabled(true)
    end

    test "does nothing when disabled" do
      put_enabled(false)
      Constants.insert_current_backend_version("0.0.1")

      assert VersionUpgrade.validate_before_migrations() == :ok
    end

    test "validates the upgrade from the stored version" do
      Constants.insert_current_backend_version("0.0.1")

      assert_raise RuntimeError, ~r/Current previous version: 0\.0\.1/, fn ->
        VersionUpgrade.validate_before_migrations()
      end
    end

    test "allows the upgrade of a fresh database" do
      assert with_tables([], &VersionUpgrade.validate_before_migrations/0) == :ok
    end

    test "allows the upgrade of an empty database without the constants table" do
      assert with_tables(["blocks"], &VersionUpgrade.validate_before_migrations/0) == :ok
    end

    test "rejects the upgrade of an indexed database without the constants table" do
      assert_raise RuntimeError, ~r/Current previous version: \(empty\)/, fn ->
        with_tables(["blocks"], fn ->
          Repo.query!("INSERT INTO blocks VALUES (1)")
          VersionUpgrade.validate_before_migrations()
        end)
      end
    end
  end

  defp put_enabled(enabled?) do
    config = Application.get_env(:explorer, VersionUpgrade) || []
    Application.put_env(:explorer, VersionUpgrade, Keyword.merge(config, enabled: enabled?))
  end

  # Runs `fun` against a database which has only the given tables, as before the
  # migrations are applied. The tables of the test database are hidden from the
  # queries by a separate schema in `search_path`, everything is rolled back
  # after `fun` returns.
  defp with_tables(tables, fun) do
    {:error, {:result, result}} =
      Repo.transaction(fn ->
        Repo.query!("CREATE SCHEMA version_upgrade_test")
        Repo.query!("SET LOCAL search_path TO version_upgrade_test")

        for table <- tables do
          Repo.query!("CREATE TABLE #{table} (id bigint)")
        end

        Repo.rollback({:result, fun.()})
      end)

    result
  end
end
