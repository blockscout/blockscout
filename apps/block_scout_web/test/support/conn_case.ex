defmodule BlockScoutWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  it cannot be async. For this reason, every test runs
  inside a transaction which is reset at the beginning
  of the test unless the test case is marked as async.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with connections
      use Phoenix.ConnTest
      import BlockScoutWeb.Router.Helpers
      import BlockScoutWeb.WebRouter.Helpers, except: [static_path: 2]

      # The default endpoint for testing
      @endpoint BlockScoutWeb.Endpoint

      import Explorer.Factory

      alias BlockScoutWeb.AdminRouter.Helpers, as: AdminRoutes
      alias BlockScoutWeb.ApiRouter.Helpers, as: ApiRoutes
    end
  end

  @dialyzer {:nowarn_function, __ex_unit_setup_0: 1}
  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Explorer.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(Explorer.Repo, {:shared, self()})
    end

    Supervisor.terminate_child(Explorer.Supervisor, Explorer.Chain.Cache.Transactions.child_id())
    Supervisor.restart_child(Explorer.Supervisor, Explorer.Chain.Cache.Transactions.child_id())
    Supervisor.terminate_child(Explorer.Supervisor, Explorer.Chain.Cache.Accounts.child_id())
    Supervisor.restart_child(Explorer.Supervisor, Explorer.Chain.Cache.Accounts.child_id())
    Supervisor.terminate_child(Explorer.Supervisor, Explorer.Chain.Cache.PendingTransactions.child_id())
    Supervisor.restart_child(Explorer.Supervisor, Explorer.Chain.Cache.PendingTransactions.child_id())

    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
