defmodule BlockScoutWeb.API.V2.FallbackController do
  use Phoenix.Controller

  alias BlockScoutWeb.API.V2.ApiView

  def call(conn, {:format, _}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(ApiView)
    |> render(:message, %{message: "Invalid parameter(s)"})
  end

  def call(conn, {:not_found, _, :empty_items_with_next_page_params}) do
    conn
    |> json(%{"items" => [], "next_page_params" => nil})
  end

  def call(conn, {:not_found, _}) do
    conn
    |> put_status(:not_found)
    |> put_view(ApiView)
    |> render(:message, %{message: "Not found"})
  end

  def call(conn, {:contract_interaction_disabled, _}) do
    conn
    |> put_status(:forbidden)
    |> put_view(ApiView)
    |> render(:message, %{message: "Contract interaction disabled"})
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

  def call(conn, {:restricted_access, true}) do
    conn
    |> put_status(:forbidden)
    |> put_view(ApiView)
    |> render(:message, %{message: "Restricted access"})
  end

  def call(conn, {:already_verified, true}) do
    conn
    |> put_view(ApiView)
    |> render(:message, %{message: "Already verified"})
  end

  def call(conn, {:no_json_file, _}) do
    conn
    |> put_view(ApiView)
    |> render(:message, %{message: "JSON files not found"})
  end

  def call(conn, {:file_error, _}) do
    conn
    |> put_view(ApiView)
    |> render(:message, %{message: "Error while reading JSON file"})
  end

  def call(conn, {:libs_format, _}) do
    conn
    |> put_view(ApiView)
    |> render(:message, %{message: "Libraries are not valid JSON map"})
  end

  def call(conn, {:lost_consensus, {:ok, block}}) do
    conn
    |> put_status(:not_found)
    |> json(%{message: "Block lost consensus", hash: to_string(block.hash)})
  end

  def call(conn, {:lost_consensus, {:error, :not_found}}) do
    conn
    |> call({:not_found, nil})
  end

  def call(conn, {:recaptcha, _}) do
    conn
    |> put_status(:forbidden)
    |> put_view(ApiView)
    |> render(:message, %{message: "Invalid reCAPTCHA response"})
  end
end
