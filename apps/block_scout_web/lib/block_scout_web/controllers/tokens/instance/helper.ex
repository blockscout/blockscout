defmodule BlockScoutWeb.Tokens.Instance.Helper do
  @moduledoc """
  Token instance controllers common helper
  """

  use BlockScoutWeb, :controller

  alias BlockScoutWeb.Controller
  alias Explorer.Chain

  def render(conn, token_instance, hash, token_id, token) do
    render(
      conn,
      "index.html",
      token_instance: %{instance: token_instance, token_id: Decimal.new(token_id)},
      current_path: Controller.current_full_path(conn),
      token: token,
      total_token_transfers: Chain.count_token_transfers_from_token_hash_and_token_id(hash, token_id)
    )
  end
end
