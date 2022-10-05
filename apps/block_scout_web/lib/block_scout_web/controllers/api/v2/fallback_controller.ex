defmodule BlockScoutWeb.API.V2.FallbackController do
  use Phoenix.Controller

  alias BlockScoutWeb.API.V2.ApiView

  def call(conn, {:format, _}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(ApiView)
    |> render(:message, %{message: "Invalid parameter(s)"})
  end

  def call(conn, {:not_found, _}) do
    conn
    |> put_status(:not_found)
    |> put_view(ApiView)
    |> render(:message, %{message: "Not found"})
  end

  def call(conn, {:error, {:invalid, :hash}}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(ApiView)
    |> render(:message, %{message: "Invalid hash"})
  end

  def call(conn, {:error, {:invalid, :number}}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(ApiView)
    |> render(:message, %{message: "Invalid number"})
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> call({:not_found, nil})
  end
end
