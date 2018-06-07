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

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(Explorer.Repo, {:shared, self()})
    end

    :ok
  end

  def wait_for_results(producer) do
    producer.()
  rescue
    Ecto.NoResultsError ->
      Process.sleep(100)
      wait_for_results(producer)
  catch
    :exit,
    {:timeout,
     {GenServer, :call,
      [
        _,
        {:checkout, _, _, _},
        _
      ]}} ->
      Process.sleep(100)
      wait_for_results(producer)
  end
end
