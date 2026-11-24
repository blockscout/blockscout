# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.FeatureCase do
  use ExUnit.CaseTemplate

  using opts do
    quote do
      use Playwright.Test, unquote(opts)
      use Fluffy.Assert

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Explorer.Factory
      import Fluffy
      import Fluffy.Locator
      import BlockScoutWeb.FeatureCase
      import BlockScoutWeb.Router.Helpers

      alias Explorer.Repo

      setup do
        session =
          :playwright
          |> start_session()
          |> Fluffy.Playwright.set_viewport_size(%{width: 1200, height: 800})

        {:ok, session: session}
      end
    end
  end

  setup tags do
    # Fluffy passes the owner's sandbox metadata (`config :fluffy, ecto_repos`)
    # with every browser request, so the owner must outlive the browser session.
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Explorer.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)

    Supervisor.terminate_child(Explorer.Supervisor, Explorer.Chain.Cache.Transactions.child_id())
    Supervisor.restart_child(Explorer.Supervisor, Explorer.Chain.Cache.Transactions.child_id())
    Supervisor.terminate_child(Explorer.Supervisor, Explorer.Chain.Cache.Accounts.child_id())
    Supervisor.restart_child(Explorer.Supervisor, Explorer.Chain.Cache.Accounts.child_id())
    Supervisor.terminate_child(Explorer.Supervisor, Explorer.Chain.Cache.Blocks.child_id())
    Supervisor.restart_child(Explorer.Supervisor, Explorer.Chain.Cache.Blocks.child_id())
    Supervisor.terminate_child(Explorer.Supervisor, Explorer.Chain.Cache.Uncles.child_id())
    Supervisor.restart_child(Explorer.Supervisor, Explorer.Chain.Cache.Uncles.child_id())

    :ok
  end
end
