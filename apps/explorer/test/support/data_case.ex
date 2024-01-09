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
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Explorer.Repo.PolygonEdge)
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Explorer.Repo.PolygonZkevm)
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Explorer.Repo.RSK)
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Explorer.Repo.Suave)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(Explorer.Repo, {:shared, self()})
      Ecto.Adapters.SQL.Sandbox.mode(Explorer.Repo.Account, {:shared, self()})
      Ecto.Adapters.SQL.Sandbox.mode(Explorer.Repo.PolygonEdge, {:shared, self()})
      Ecto.Adapters.SQL.Sandbox.mode(Explorer.Repo.PolygonZkevm, {:shared, self()})
      Ecto.Adapters.SQL.Sandbox.mode(Explorer.Repo.RSK, {:shared, self()})
      Ecto.Adapters.SQL.Sandbox.mode(Explorer.Repo.Suave, {:shared, self()})
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
    producer.()
  rescue
    [DBConnection.ConnectionError, Ecto.NoResultsError] ->
      Process.sleep(100)
      wait_for_results(producer)
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
