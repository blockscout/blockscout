defmodule BlockScoutWeb.API.V2.FallbackController do
  use Phoenix.Controller

  require Logger

  alias BlockScoutWeb.API.V2.ApiView

  @verification_failed "API v2 smart-contract verification failed"
  @invalid_parameters "Invalid parameter(s)"
  @invalid_address_hash "Invalid address hash"
  @invalid_hash "Invalid hash"
  @invalid_number "Invalid number"
  @invalid_url "Invalid URL"
  @not_found "Not found"
  @contract_interaction_disabled "Contract interaction disabled"
  @restricted_access "Restricted access"
  @already_verified "Already verified"
  @json_not_found "JSON files not found"
  @error_while_reading_json "Error while reading JSON file"
  @error_in_libraries "Libraries are not valid JSON map"
  @block_lost_consensus "Block lost consensus"
  @invalid_captcha_resp "Invalid reCAPTCHA response"
  @unauthorized "Unauthorized"
  @not_configured_api_key "API key not configured on the server"
  @wrong_api_key "Wrong API key"

  def call(conn, {:format, _params}) do
    Logger.error(fn ->
      ["#{@verification_failed}: #{@invalid_parameters}"]
    end)

    conn
    |> put_status(:unprocessable_entity)
    |> put_view(ApiView)
    |> render(:message, %{message: @invalid_parameters})
  end

  def call(conn, {:format_address, _}) do
    Logger.error(fn ->
      ["#{@verification_failed}: #{@invalid_address_hash}"]
    end)

    conn
    |> put_status(:unprocessable_entity)
    |> put_view(ApiView)
    |> render(:message, %{message: @invalid_address_hash})
  end

  def call(conn, {:format_url, _}) do
    Logger.error(fn ->
      ["#{@verification_failed}: #{@invalid_url}"]
    end)

    conn
    |> put_status(:unprocessable_entity)
    |> put_view(ApiView)
    |> render(:message, %{message: @invalid_url})
  end

  def call(conn, {:not_found, _, :empty_items_with_next_page_params}) do
    Logger.error(fn ->
      ["#{@verification_failed}: :empty_items_with_next_page_params"]
    end)

    conn
    |> json(%{"items" => [], "next_page_params" => nil})
  end

  def call(conn, {:not_found, _}) do
    Logger.error(fn ->
      ["#{@verification_failed}: #{@not_found}"]
    end)

    conn
    |> put_status(:not_found)
    |> put_view(ApiView)
    |> render(:message, %{message: @not_found})
  end

  def call(conn, {:contract_interaction_disabled, _}) do
    Logger.error(fn ->
      ["#{@verification_failed}: #{@contract_interaction_disabled}"]
    end)

    conn
    |> put_status(:forbidden)
    |> put_view(ApiView)
    |> render(:message, %{message: @contract_interaction_disabled})
  end

  def call(conn, {:error, {:invalid, :hash}}) do
    Logger.error(fn ->
      ["#{@verification_failed}: #{@invalid_hash}"]
    end)

    conn
    |> put_status(:unprocessable_entity)
    |> put_view(ApiView)
    |> render(:message, %{message: @invalid_hash})
  end

  def call(conn, {:error, {:invalid, :number}}) do
    Logger.error(fn ->
      ["#{@verification_failed}: #{@invalid_number}"]
    end)

    conn
    |> put_status(:unprocessable_entity)
    |> put_view(ApiView)
    |> render(:message, %{message: @invalid_number})
  end

  def call(conn, {:error, :not_found}) do
    Logger.error(fn ->
      ["#{@verification_failed}: :not_found"]
    end)

    conn
    |> call({:not_found, nil})
  end

  def call(conn, {:restricted_access, true}) do
    Logger.error(fn ->
      ["#{@verification_failed}: #{@restricted_access}"]
    end)

    conn
    |> put_status(:forbidden)
    |> put_view(ApiView)
    |> render(:message, %{message: @restricted_access})
  end

  def call(conn, {:already_verified, _}) do
    Logger.error(fn ->
      ["#{@verification_failed}: #{@already_verified}"]
    end)

    conn
    |> put_view(ApiView)
    |> render(:message, %{message: @already_verified})
  end

  def call(conn, {:no_json_file, _}) do
    Logger.error(fn ->
      ["#{@verification_failed}: #{@json_not_found}"]
    end)

    conn
    |> put_view(ApiView)
    |> render(:message, %{message: @json_not_found})
  end

  def call(conn, {:file_error, _}) do
    Logger.error(fn ->
      ["#{@verification_failed}: #{@error_while_reading_json}"]
    end)

    conn
    |> put_view(ApiView)
    |> render(:message, %{message: @error_while_reading_json})
  end

  def call(conn, {:libs_format, _}) do
    Logger.error(fn ->
      ["#{@verification_failed}: #{@error_in_libraries}"]
    end)

    conn
    |> put_view(ApiView)
    |> render(:message, %{message: @error_in_libraries})
  end

  def call(conn, {:lost_consensus, {:ok, block}}) do
    Logger.error(fn ->
      ["#{@verification_failed}: #{@block_lost_consensus}"]
    end)

    conn
    |> put_status(:not_found)
    |> json(%{message: @block_lost_consensus, hash: to_string(block.hash)})
  end

  def call(conn, {:lost_consensus, {:error, :not_found}}) do
    Logger.error(fn ->
      ["#{@verification_failed}: #{@block_lost_consensus}"]
    end)

    conn
    |> call({:not_found, nil})
  end

  def call(conn, {:recaptcha, _}) do
    Logger.error(fn ->
      ["#{@verification_failed}: #{@invalid_captcha_resp}"]
    end)

    conn
    |> put_status(:forbidden)
    |> put_view(ApiView)
    |> render(:message, %{message: @invalid_captcha_resp})
  end

  def call(conn, {:auth, _}) do
    Logger.error(fn ->
      ["#{@verification_failed}: #{@unauthorized}"]
    end)

    conn
    |> put_status(:unauthorized)
    |> put_view(ApiView)
    |> render(:message, %{message: @unauthorized})
  end

  def call(conn, {:sensitive_endpoints_api_key, _}) do
    Logger.error(fn ->
      ["#{@verification_failed}: #{@not_configured_api_key}"]
    end)

    conn
    |> put_status(:forbidden)
    |> put_view(ApiView)
    |> render(:message, %{message: @not_configured_api_key})
  end

  def call(conn, {:api_key, _}) do
    Logger.error(fn ->
      ["#{@verification_failed}: #{@wrong_api_key}"]
    end)

    conn
    |> put_status(:unauthorized)
    |> put_view(ApiView)
    |> render(:message, %{message: @wrong_api_key})
  end
end
