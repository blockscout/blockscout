defmodule Explorer.SmartContract.StylusVerifierInterface do
  @moduledoc """
    Adapter for Stylus smart contracts verification
  """
  alias Explorer.Utility.Microservice
  alias HTTPoison.Response
  require Logger

  @post_timeout :timer.minutes(5)
  @request_error_msg "Error while sending request to stylus verification microservice"

  def verify_github_repository(
        %{
          "deployment_transaction" => _,
          "rpc_endpoint" => _,
          "cargo_stylus_version" => _,
          "repository_url" => _,
          "commit" => _,
          "path_prefix" => _
        } = body
      ) do
    http_post_request(github_repository_verification_url(), body)
  end

  def http_post_request(url, body) do
    headers = [{"Content-Type", "application/json"}]

    case HTTPoison.post(url, Jason.encode!(body), headers, recv_timeout: @post_timeout) do
      {:ok, %Response{body: body, status_code: _}} ->
        process_verifier_response(body)

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
        process_verifier_response(body)

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

  def process_verifier_response(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} ->
        process_verifier_response(decoded)

      _ ->
        {:error, body}
    end
  end

  def process_verifier_response(%{"verificationSuccess" => source}) do
    {:ok, source}
  end

  def process_verifier_response(%{"verificationFailure" => %{"message" => error_message}}) do
    {:error, error_message}
  end

  def process_verifier_response(%{"versions" => versions}), do: {:ok, Enum.map(versions, &Map.fetch!(&1, "version"))}

  def process_verifier_response(other) do
    {:error, other}
  end

  # Uses url encoded ("%3A") version of ':', as ':' symbol breaks `Bypass` library during tests.
  # https://github.com/PSPDFKit-labs/bypass/issues/122

  def github_repository_verification_url,
    do: base_api_url() <> "%3Averify-github-repository"

  def versions_list_url, do: base_api_url() <> "/cargo-stylus-versions"

  def base_api_url, do: "#{base_url()}" <> "/api/v1/stylus-sdk-rs"

  def base_url, do: Microservice.base_url(__MODULE__)

  def enabled?,
    do: Application.get_env(:explorer, __MODULE__)[:enabled] && Application.get_env(:explorer, :chain_type) == :arbitrum
end
