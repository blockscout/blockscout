defmodule ExplorerWeb.FeatureCase do
  use ExUnit.CaseTemplate

  # Types on  Wallaby.Browser.resize_window don't allow session from start_session to be passed, so setup breaks
  @dialyzer {:nowarn_function, __ex_unit_setup_0: 1}

  using do
    quote do
      use Wallaby.DSL

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Explorer.Factory
      import ExplorerWeb.Router.Helpers

      alias Explorer.Repo
    end
  end

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Explorer.Repo)

    metadata = Phoenix.Ecto.SQL.Sandbox.metadata_for(Explorer.Repo, self())
    {:ok, session} = Wallaby.start_session(metadata: metadata)
    session = Wallaby.Browser.resize_window(session, 1200, 800)
    {:ok, session: session}
  end
end
