defmodule BlockScoutWeb.Account.Api.V2.AddressController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Account.AuthController, only: [current_user: 1]

  alias BlockScoutWeb.Account.Api.V2.AuthenticateController
  alias Explorer.ThirdPartyIntegrations.Auth0
  alias Plug.Conn

  action_fallback(BlockScoutWeb.Account.Api.V2.FallbackController)

  def link_address(conn, %{"message" => message, "signature" => signature}) do
    with %{uid: id} <- conn |> Conn.fetch_session() |> current_user(),
         {:ok, auth} <- Auth0.link_address(id, message, signature) do
      AuthenticateController.put_auth_to_session(conn, auth)
    end
  end
end
