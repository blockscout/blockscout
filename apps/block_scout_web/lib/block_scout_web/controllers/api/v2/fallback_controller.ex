defmodule BlockScoutWeb.API.V2.FallbackController do
  use Phoenix.Controller

  require Logger

  alias BlockScoutWeb.Account.API.V2.UserView
  alias BlockScoutWeb.API.V2.ApiView
  alias Ecto.Changeset

  @invalid_parameters "Invalid parameter(s)"
  @invalid_address_hash "Invalid address hash"
  @invalid_hash "Invalid hash"
  @invalid_number "Invalid number"
  @invalid_url "Invalid URL"
  @invalid_celo_election_reward_type "Invalid Celo reward type, allowed types are: validator, group, voter, delegated-payment"
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
  @address_not_found "Address not found"
  @address_is_not_smart_contract "Address is not smart-contract"
  @vyper_smart_contract_is_not_supported "Vyper smart-contracts are not supported by SolidityScan"
  @unverified_smart_contract "Smart-contract is unverified"
  @empty_response "Empty response"
  @transaction_interpreter_service_disabled "Transaction Interpretation Service is disabled"
  @disabled "API endpoint is disabled"
  @service_disabled "Service is disabled"
  @not_a_smart_contract "Address is not a smart-contract"

  def call(conn, {:format, _params}) do
    Logger.error(fn ->
      ["#{@invalid_parameters}"]
    end)

    conn
    |> put_status(:unprocessable_entity)
    |> put_view(ApiView)
    |> render(:message, %{message: @invalid_parameters})
  end

  def call(conn, {:format_address, _}) do
    Logger.error(fn ->
      ["#{@invalid_address_hash}"]
    end)

    conn
    |> put_status(:unprocessable_entity)
    |> put_view(ApiView)
    |> render(:message, %{message: @invalid_address_hash})
  end

  def call(conn, {:format_url, _}) do
    Logger.error(fn ->
      ["#{@invalid_url}"]
    end)

    conn
    |> put_status(:unprocessable_entity)
    |> put_view(ApiView)
    |> render(:message, %{message: @invalid_url})
  end

  def call(conn, {:not_found, _, :empty_items_with_next_page_params}) do
    Logger.error(fn ->
      [":empty_items_with_next_page_params"]
    end)

    conn
    |> json(%{"items" => [], "next_page_params" => nil})
  end

  def call(conn, {:not_found, _}) do
    Logger.error(fn ->
      ["#{@not_found}"]
    end)

    conn
    |> put_status(:not_found)
    |> put_view(ApiView)
    |> render(:message, %{message: @not_found})
  end

  def call(conn, {:contract_interaction_disabled, _}) do
    Logger.error(fn ->
      ["#{@contract_interaction_disabled}"]
    end)

    conn
    |> put_status(:forbidden)
    |> put_view(ApiView)
    |> render(:message, %{message: @contract_interaction_disabled})
  end

  def call(conn, {:error, {:invalid, entity}})
      when entity in ~w(hash number celo_election_reward_type)a do
    message =
      case entity do
        :hash -> @invalid_hash
        :number -> @invalid_number
        :celo_election_reward_type -> @invalid_celo_election_reward_type
      end

    Logger.error(fn ->
      ["#{message}"]
    end)

    conn
    |> put_status(:unprocessable_entity)
    |> put_view(ApiView)
    |> render(:message, %{message: message})
  end

  def call(conn, {:error, :not_found}) do
    Logger.error(fn ->
      [":not_found"]
    end)

    conn
    |> call({:not_found, nil})
  end

  def call(conn, {:error, %Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(UserView)
    |> render(:changeset_errors, changeset: changeset)
  end

  def call(conn, {:error, :badge_creation_failed}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(UserView)
    |> render(:message, %{message: "Badge creation failed"})
  end

  def call(conn, {:restricted_access, true}) do
    Logger.error(fn ->
      ["#{@restricted_access}"]
    end)

    conn
    |> put_status(:forbidden)
    |> put_view(ApiView)
    |> render(:message, %{message: @restricted_access})
  end

  def call(conn, {:already_verified, _}) do
    Logger.error(fn ->
      ["#{@already_verified}"]
    end)

    conn
    |> put_view(ApiView)
    |> render(:message, %{message: @already_verified})
  end

  def call(conn, {:no_json_file, _}) do
    Logger.error(fn ->
      ["#{@json_not_found}"]
    end)

    conn
    |> put_view(ApiView)
    |> render(:message, %{message: @json_not_found})
  end

  def call(conn, {:file_error, _}) do
    Logger.error(fn ->
      ["#{@error_while_reading_json}"]
    end)

    conn
    |> put_view(ApiView)
    |> render(:message, %{message: @error_while_reading_json})
  end

  def call(conn, {:libs_format, _}) do
    Logger.error(fn ->
      ["#{@error_in_libraries}"]
    end)

    conn
    |> put_view(ApiView)
    |> render(:message, %{message: @error_in_libraries})
  end

  def call(conn, {:lost_consensus, {:ok, block}}) do
    Logger.error(fn ->
      ["#{@block_lost_consensus}"]
    end)

    conn
    |> put_status(:not_found)
    |> json(%{message: @block_lost_consensus, hash: to_string(block.hash)})
  end

  def call(conn, {:lost_consensus, {:error, :not_found}}) do
    Logger.error(fn ->
      ["#{@block_lost_consensus}"]
    end)

    conn
    |> call({:not_found, nil})
  end

  def call(conn, {:recaptcha, _}) do
    Logger.error(fn ->
      ["#{@invalid_captcha_resp}"]
    end)

    conn
    |> put_status(:forbidden)
    |> put_view(ApiView)
    |> render(:message, %{message: @invalid_captcha_resp})
  end

  def call(conn, {:auth, _}) do
    Logger.error(fn ->
      ["#{@unauthorized}"]
    end)

    conn
    |> put_status(:unauthorized)
    |> put_view(ApiView)
    |> render(:message, %{message: @unauthorized})
  end

  def call(conn, {:sensitive_endpoints_api_key, _}) do
    Logger.error(fn ->
      ["#{@not_configured_api_key}"]
    end)

    conn
    |> put_status(:forbidden)
    |> put_view(ApiView)
    |> render(:message, %{message: @not_configured_api_key})
  end

  def call(conn, {:api_key, _}) do
    Logger.error(fn ->
      ["#{@wrong_api_key}"]
    end)

    conn
    |> put_status(:unauthorized)
    |> put_view(ApiView)
    |> render(:message, %{message: @wrong_api_key})
  end

  def call(conn, {:address, {:error, :not_found}}) do
    conn
    |> put_status(:not_found)
    |> put_view(ApiView)
    |> render(:message, %{message: @address_not_found})
  end

  def call(conn, {:is_smart_contract, result}) when is_nil(result) or result == false do
    conn
    |> put_status(:not_found)
    |> put_view(ApiView)
    |> render(:message, %{message: @address_is_not_smart_contract})
  end

  def call(conn, {:language, :vyper}) do
    conn
    |> put_status(:not_found)
    |> put_view(ApiView)
    |> render(:message, %{message: @vyper_smart_contract_is_not_supported})
  end

  def call(conn, {:is_verified_smart_contract, result}) when result == false do
    conn
    |> put_status(:not_found)
    |> put_view(ApiView)
    |> render(:message, %{message: @unverified_smart_contract})
  end

  def call(conn, {:is_empty_response, true}) do
    conn
    |> put_status(500)
    |> put_view(ApiView)
    |> render(:message, %{message: @empty_response})
  end

  def call(conn, {:transaction_interpreter_enabled, false}) do
    conn
    |> put_status(:forbidden)
    |> put_view(ApiView)
    |> render(:message, %{message: @transaction_interpreter_service_disabled})
  end

  def call(conn, {:disabled, _}) do
    conn
    |> put_status(:forbidden)
    |> put_view(ApiView)
    |> render(:message, %{message: @disabled})
  end

  def call(conn, {:error, :disabled}) do
    conn
    |> put_status(501)
    |> put_view(ApiView)
    |> render(:message, %{message: @service_disabled})
  end

  def call(conn, {:not_a_smart_contract, _}) do
    conn
    |> put_status(:not_found)
    |> put_view(ApiView)
    |> render(:message, %{message: @not_a_smart_contract})
  end

  def call(conn, {:average_block_time, {:error, :disabled}}) do
    conn
    |> put_status(501)
    |> put_view(ApiView)
    |> render(:message, %{message: "Average block time calculating is disabled, so getblockcountdown is not available"})
  end

  def call(conn, {stage, _}) when stage in ~w(max_block average_block_time)a do
    conn
    |> put_status(200)
    |> put_view(ApiView)
    |> render(:message, %{message: "Chain is indexing now, try again later"})
  end

  def call(conn, {:remaining_blocks, _}) do
    conn
    |> put_status(200)
    |> put_view(ApiView)
    |> render(:message, %{message: "Error! Block number already pass"})
  end

  def call(conn, {code, response}) when is_integer(code) do
    conn
    |> put_status(code)
    |> json(response)
  end
end
