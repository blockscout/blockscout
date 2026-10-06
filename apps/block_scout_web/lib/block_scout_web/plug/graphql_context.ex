# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Plug.GraphQLContext do
  @moduledoc """
  A plug that puts request-derived values into the Absinthe context.

  `Absinthe.Plug` does not expose the `conn` to the schema context, so values
  that depend on request headers or cookies (e.g. the scam token toggle) must
  be assigned here before the request is forwarded to `Absinthe.Plug`.
  """
  alias BlockScoutWeb.Chain

  def init(opts), do: opts

  def call(conn, _opts) do
    show_scam_tokens? =
      []
      |> Chain.fetch_scam_token_toggle(conn)
      |> Keyword.get(:show_scam_tokens?, false)

    Absinthe.Plug.assign_context(conn, :show_scam_tokens?, show_scam_tokens?)
  end
end
