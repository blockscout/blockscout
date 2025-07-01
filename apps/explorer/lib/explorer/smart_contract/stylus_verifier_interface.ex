defmodule Explorer.SmartContract.StylusVerifierInterface do
  @moduledoc """
    Provides an interface for verifying Stylus smart contracts by interacting with a verification
    microservice.

    Handles verification requests for Stylus contracts deployed from GitHub repositories by
    communicating with an external verification service.
  """
  alias Explorer.HttpClient
  require Logger

  @post_timeout :timer.minutes(5)
  @request_error_msg "Error while sending request to stylus verification microservice"

  @doc """
    Verifies a Stylus smart contract using source code from a GitHub repository.

    Sends verification request to the verification microservice with repository details
    and deployment information.

    ## Parameters
    - `body`: A map containing:
      - `deployment_transaction`: Transaction hash where contract was deployed
      - `rpc_endpoint`: RPC endpoint URL for the chain
      - `cargo_stylus_version`: Version of cargo-stylus used for deployment
      - `repository_url`: GitHub repository URL containing contract code
      - `commit`: Git commit hash used for deployment
      - `path_prefix`: Optional path prefix if contract is not in repository root

    ## Returns
    - `{:ok, map}` with verification details:
      - `abi`: Contract ABI (optional)
      - `contract_name`: Contract name (optional)
      - `package_name`: Package name
      - `files`: Map of file paths to contents used in verification
      - `cargo_stylus_version`: Version of cargo-stylus used
      - `github_repository_metadata`: Repository metadata (optional)
    - `{:error, any}` if verification fails
  """
  @spec verify_github_repository(map()) :: {:ok, map()} | {:error, any()}
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

  @spec http_post_request(String.t(), map()) :: {:ok, map()} | {:error, any()}
  defp http_post_request(url, body) do
    headers = [{"Content-Type", "application/json"}]

    case HttpClient.post(url, Jason.encode!(body), headers, recv_timeout: @post_timeout) do
      {:ok, %{body: body, status_code: _}} ->
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

  @spec http_get_request(String.t()) :: {:ok, [String.t()]} | {:error, any()}
  defp http_get_request(url) do
    case HttpClient.get(url) do
      {:ok, %{body: body, status_code: 200}} ->
        process_verifier_response(body)

      {:ok, %{body: body, status_code: _}} ->
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

  @doc """
    Retrieves a list of supported versions of Cargo Stylus package from the verification microservice.

    ## Returns
    - `{:ok, [String.t()]}` - List of versions on success
    - `{:error, any()}` - Error message if the request fails
  """
  @spec get_versions_list() :: {:ok, [String.t()]} | {:error, any()}
  def get_versions_list do
    http_get_request(versions_list_url())
  end

  @spec process_verifier_response(binary()) :: {:ok, map() | [String.t()]} | {:error, any()}
  defp process_verifier_response(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} ->
        process_verifier_response(decoded)

      _ ->
        {:error, body}
    end
  end

  # Handles response from `stylus-sdk-rs/verify-github-repository` of stylus verifier microservice
  @spec process_verifier_response(map()) :: {:ok, map()}
  defp process_verifier_response(%{"verification_success" => source}) do
    {:ok, source}
  end

  # Handles response from `stylus-sdk-rs/verify-github-repository` of stylus verifier microservice
  @spec process_verifier_response(map()) :: {:ok, map()}
  defp process_verifier_response(%{"verificationSuccess" => source}) do
    {:ok, source}
  end

  # Handles response from `stylus-sdk-rs/verify-github-repository` of stylus verifier microservice
  @spec process_verifier_response(map()) :: {:error, String.t()}
  defp process_verifier_response(%{"verification_failure" => %{"message" => error_message}}) do
    {:error, error_message}
  end

  # Handles response from `stylus-sdk-rs/verify-github-repository` of stylus verifier microservice
  @spec process_verifier_response(map()) :: {:error, String.t()}
  defp process_verifier_response(%{"verificationFailure" => %{"message" => error_message}}) do
    {:error, error_message}
  end

  # Handles response from `stylus-sdk-rs/cargo-stylus-versions` of stylus verifier microservice
  @spec process_verifier_response(map()) :: {:ok, [String.t()]}
  defp process_verifier_response(%{"versions" => versions}), do: {:ok, Enum.map(versions, &Map.fetch!(&1, "version"))}

  @spec process_verifier_response(any()) :: {:error, any()}
  defp process_verifier_response(other) do
    {:error, other}
  end

  # Uses url encoded ("%3A") version of ':', as ':' symbol breaks `Bypass` library during tests.
  # https://github.com/PSPDFKit-labs/bypass/issues/122

  defp github_repository_verification_url,
    do: base_api_url() <> "%3Averify-github-repository"

  defp versions_list_url, do: base_api_url() <> "/cargo-stylus-versions"

  defp base_api_url, do: "#{base_url()}" <> "/api/v1/stylus-sdk-rs"

  defp base_url, do: Application.get_env(:explorer, __MODULE__)[:service_url]

  def enabled?,
    do: !is_nil(base_url()) && Application.get_env(:explorer, :chain_type) == :arbitrum
end
