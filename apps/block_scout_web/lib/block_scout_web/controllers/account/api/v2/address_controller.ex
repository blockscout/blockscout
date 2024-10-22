defmodule BlockScoutWeb.Account.API.V2.AddressController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Account.AuthController, only: [current_user: 1]

  alias BlockScoutWeb.Account.API.V2.AuthenticateController
  alias Explorer.ThirdPartyIntegrations.Auth0
  alias Plug.Conn

  action_fallback(BlockScoutWeb.Account.API.V2.FallbackController)

  @doc """
  Links an Ethereum address to the current user's account.

  This function attempts to link a provided Ethereum address to the currently
  authenticated user's account. It verifies the provided message and signature,
  then uses the Auth0 service to associate the address with the user's account.

  ## Parameters
  - `conn`: The `Plug.Conn` struct representing the current connection.
  - `params`: A map containing:
    - `"message"`: The message that was signed.
    - `"signature"`: The signature of the message.

  ## Returns
  - `{:error, any()}`: Error and a description of the error.
  - `:error`: In case of unexpected error.
  - `Conn.t()`: A modified connection struct if the address is successfully
    linked. The connection will have updated session information.

  ## Notes
  - Errors are handled later in `BlockScoutWeb.Account.API.V2.FallbackController`.
  """
  @spec link_address(Plug.Conn.t(), map()) :: :error | {:error, any()} | Conn.t()
  def link_address(conn, %{"message" => message, "signature" => signature}) do
    with %{uid: id} <- conn |> current_user(),
         {:ok, auth} <- Auth0.link_address(id, message, signature) do
      AuthenticateController.put_auth_to_session(conn, auth)
    end
  end
end
