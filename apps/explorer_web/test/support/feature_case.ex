defmodule ExplorerWeb.FeatureCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      use Wallaby.DSL

      alias Explorer.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import ExplorerWeb.Router.Helpers
      import Explorer.Factory
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
