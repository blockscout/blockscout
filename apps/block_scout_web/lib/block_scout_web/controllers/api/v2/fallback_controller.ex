defmodule BlockScoutWeb.API.V2.FallbackController do
  use Phoenix.Controller

  alias BlockScoutWeb.API.V2.ApiView
  alias Ecto.Changeset

  def call(conn, {:format, _}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(ApiView)
    |> render(:message, %{message: "Invalid parameter(s)"})
  end
end
