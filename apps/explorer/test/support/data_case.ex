# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  it cannot be async. For this reason, every test runs
  inside a transaction which is reset at the beginning
  of the test unless the test case is marked as async.
  """

  use ExUnit.CaseTemplate

  alias Ecto.Changeset
  alias Explorer.Chain.Cache.BackgroundMigrations

  using do
    quote do
      use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Explorer.DataCase
      import Explorer.Factory

      alias Explorer.Repo
    end
  end

  setup tags do
    ExVCR.Config.cassette_library_dir("test/support/fixture/vcr_cassettes")

    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Explorer.Repo)
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Explorer.Repo.Account)
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Explorer.Repo.EventNotifications)

    if !tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(Explorer.Repo, {:shared, self()})
      Ecto.Adapters.SQL.Sandbox.mode(Explorer.Repo.Account, {:shared, self()})
      Ecto.Adapters.SQL.Sandbox.mode(Explorer.Repo.EventNotifications, {:shared, self()})
    end

    Supervisor.terminate_child(Explorer.Supervisor, Explorer.Chain.Cache.BlockNumber.child_id())
    Supervisor.restart_child(Explorer.Supervisor, Explorer.Chain.Cache.BlockNumber.child_id())
    Supervisor.terminate_child(Explorer.Supervisor, Explorer.Chain.Cache.Blocks.child_id())
    Supervisor.restart_child(Explorer.Supervisor, Explorer.Chain.Cache.Blocks.child_id())
    Supervisor.terminate_child(Explorer.Supervisor, Explorer.Chain.Cache.Transactions.child_id())
    Supervisor.restart_child(Explorer.Supervisor, Explorer.Chain.Cache.Transactions.child_id())
    Supervisor.terminate_child(Explorer.Supervisor, Explorer.Chain.Cache.Accounts.child_id())
    Supervisor.restart_child(Explorer.Supervisor, Explorer.Chain.Cache.Accounts.child_id())

    :ok
  end

  def wait_for_results(producer) do
    wait_for_results(producer, 30)
  end

  def wait_for_results(_producer, 0) do
    raise "wait_for_results timed out after exhausting retries"
  end

  def wait_for_results(producer, retries) when retries > 0 do
    Process.sleep(100)
    producer.()
  rescue
    _error in [DBConnection.ConnectionError, Ecto.NoResultsError] ->
      Process.sleep(300)
      wait_for_results(producer, retries - 1)
  end

  @doc """
  Emulates the state when the `fill_logs_optimized_fields` migration is started
  but not finished yet, so logs are stored either with the new `address_id` or
  with the legacy `address_hash`.

  Both cached statuses are set explicitly and restored afterwards:
  `Explorer.Chain.Cache.BackgroundMigrations` is a process-wide cache which is
  not rolled back by the sandbox, so another test completing the migration
  leaks a finished status into the whole test run.
  """
  def set_fill_logs_optimized_fields_migration_started do
    initial_started? = BackgroundMigrations.get_create_logs_block_number_transaction_index_index_unique_index_finished()
    initial_finished? = BackgroundMigrations.get_fill_logs_optimized_fields_finished()

    BackgroundMigrations.set_create_logs_block_number_transaction_index_index_unique_index_finished(true)
    BackgroundMigrations.set_fill_logs_optimized_fields_finished(false)

    ExUnit.Callbacks.on_exit(fn ->
      BackgroundMigrations.set_create_logs_block_number_transaction_index_index_unique_index_finished(initial_started?)
      BackgroundMigrations.set_fill_logs_optimized_fields_finished(initial_finished?)
    end)
  end

  @doc """
  Converts a changeset to a map of fields with lists of formatted error messages.
  """
  def changeset_errors(%Changeset{} = changeset) do
    Changeset.traverse_errors(changeset, fn {error_message, opts} ->
      Enum.reduce(opts, error_message, fn {key, value}, error_message ->
        String.replace(error_message, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
