defmodule BlockScoutWeb.Plug.CheckChainType do
  @moduledoc """
  A plug that restricts access to routes based on the current chain type.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [put_view: 2, render: 3]

  alias BlockScoutWeb.API.V2.ApiView

  @doc """
  Initializes the plug with the required chain type.
  """
  def init(chain_type), do: chain_type

  @doc """
  Checks if the current chain type matches the required chain type. If not,
  returns a 404 Not Found response.
  """
  def call(conn, required_chain_type) do
    current_chain_type = Application.get_env(:explorer, :chain_type)

    if current_chain_type == required_chain_type do
      conn
    else
      conn
      |> put_status(:not_found)
      |> put_view(ApiView)
      |> render(:message, %{message: "Endpoint not available for current chain type"})
      |> halt()
    end
  end
end
