defmodule Explorer.SmartContract.RustVerifierInterface do
  @moduledoc """
    Adapter for contracts verification with https://github.com/blockscout/blockscout-rs/tree/main/verification
  """
  alias HTTPoison.Response
  require Logger

  @post_timeout :infinity
  @request_error_msg "Error while sending request to verification microservice"

  def verify_multi_part(
        %{
          "creation_bytecode" => _,
          "deployed_bytecode" => _,
          "compiler_version" => _,
          "sources" => _,
          "evm_version" => _,
          "optimization_runs" => _,
          "contract_libraries" => _
        } = body
      ) do
    http_post_request(multiple_files_verification_url(), body)
  end

  def verify_standard_json_input(
        %{
          "creation_bytecode" => _,
          "deployed_bytecode" => _,
          "compiler_version" => _,
          "input" => _
        } = body
      ) do
    http_post_request(standard_json_input_verification_url(), body)
  end

  def http_post_request(url, body) do
    headers = [{"Content-Type", "application/json"}]

    case HTTPoison.post(url, Jason.encode!(body), headers, recv_timeout: @post_timeout) do
      {:ok, %Response{body: body, status_code: 200}} ->
        proccess_verifier_response(body)

      {:ok, %Response{body: body, status_code: _}} ->
        proccess_verifier_response(body)

      {:error, error} ->
        Logger.error(fn ->
          [
            "Error while sending request to verification microservice url: #{url}, body: #{inspect(body, limit: :infinity, printable_limit: :infinity)}: ",
            inspect(error, limit: :infinity, printable_limit: :infinity)
          ]
        end)

        {:error, @request_error_msg}
    end
  end

  def http_get_request(url) do
    case HTTPoison.get(url) do
      {:ok, %Response{body: body, status_code: 200}} ->
        proccess_verifier_response(body)

      {:ok, %Response{body: body, status_code: _}} ->
        {:error, body}

      {:error, error} ->
        Logger.error(fn ->
          [
            "Error while sending request to verification microservice url: #{url}: ",
            inspect(error, limit: :infinity, printable_limit: :infinity)
          ]
        end)

        {:error, @request_error_msg}
    end
  end

  def get_versions_list do
    http_get_request(versions_list_url())
  end

  def proccess_verifier_response(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} ->
        proccess_verifier_response(decoded)

      _ ->
        {:error, body}
    end
  end

  def proccess_verifier_response(%{"status" => zero, "result" => result}) when zero in ["0", 0] do
    {:ok, result}
  end

  def proccess_verifier_response(%{"status" => one, "message" => error}) when one in ["1", 1] do
    {:error, error}
  end

  def proccess_verifier_response(%{"versions" => versions}), do: {:ok, versions}

  def proccess_verifier_response(other), do: {:error, other}

  def multiple_files_verification_url, do: "#{base_api_url()}" <> "/solidity/verify/multiple-files"

  def standard_json_input_verification_url, do: "#{base_api_url()}" <> "/solidity/verify/standard-json"

  def versions_list_url, do: "#{base_api_url()}" <> "/solidity/versions"

  def base_api_url, do: "#{base_url()}" <> "/api/v1"

  def base_url do
    url = Application.get_env(:explorer, __MODULE__)[:service_url]

    if String.ends_with?(url, "/") do
      url
      |> String.slice(0..(String.length(url) - 2))
    else
      url
    end
  end

  def enabled?, do: Application.get_env(:explorer, __MODULE__)[:enabled]
end
