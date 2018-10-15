defmodule BlockScoutWeb.Plug.FetchUserFromSession do
  @moduledoc """
  Fetches a `t:Explorer.Accounts.User.t/0` record if a user id is found in the session.
  """

  import Plug.Conn

  alias Explorer.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    with user_id when not is_nil(user_id) <- get_session(conn, :user_id),
         {:ok, user} <- Accounts.fetch_user(user_id) do
      assign(conn, :user, user)
    else
      _ -> conn
    end
  end
end
