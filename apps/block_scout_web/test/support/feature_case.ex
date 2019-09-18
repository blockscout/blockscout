defmodule BlockScoutWeb.FeatureCase do
  use ExUnit.CaseTemplate
  use Wallaby.DSL

  # Types on  Wallaby.Browser.resize_window don't allow session from start_session to be passed, so setup breaks
  @dialyzer {:nowarn_function, __ex_unit_setup_0: 1}

  using do
    quote do
      use Wallaby.DSL

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Explorer.Factory
      import BlockScoutWeb.FeatureCase
      import BlockScoutWeb.Router.Helpers

      alias Explorer.Repo
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Explorer.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(Explorer.Repo, {:shared, self()})
    end

    Supervisor.terminate_child(Explorer.Supervisor, Explorer.Chain.Cache.Transactions.child_id())
    Supervisor.restart_child(Explorer.Supervisor, Explorer.Chain.Cache.Transactions.child_id())
    Supervisor.terminate_child(Explorer.Supervisor, Explorer.Chain.Cache.Accounts.child_id())
    Supervisor.restart_child(Explorer.Supervisor, Explorer.Chain.Cache.Accounts.child_id())

    metadata = Phoenix.Ecto.SQL.Sandbox.metadata_for(Explorer.Repo, self())
    {:ok, session} = Wallaby.start_session(metadata: metadata)
    session = Wallaby.Browser.resize_window(session, 1200, 800)
    {:ok, session: session}
  end
end
