defmodule Explorer.SmartContract.RustVerifierInterfaceBehaviour do
  @moduledoc """
    This behaviour module was created in order to add possibility to extend the functionality of RustVerifierInterface
  """
  defmacro __using__(_) do
    quote([]) do
      alias Explorer.Utility.RustService
      alias HTTPoison.Response
      require Logger

      @post_timeout :timer.seconds(120)
      @request_error_msg "Error while sending request to verification microservice"

      def verify_multi_part(
            %{
              "bytecode" => _,
              "bytecodeType" => _,
              "compilerVersion" => _,
              "sourceFiles" => _,
              "evmVersion" => _,
              "optimizationRuns" => _,
              "libraries" => _
            } = body,
            address_hash
          ) do
        http_post_request(multiple_files_verification_url(), append_metadata(body, address_hash))
      end

      def verify_standard_json_input(
            %{
              "bytecode" => _,
              "bytecodeType" => _,
              "compilerVersion" => _,
              "input" => _
            } = body,
            address_hash
          ) do
        http_post_request(standard_json_input_verification_url(), append_metadata(body, address_hash))
      end

      def vyper_verify_multipart(
            %{
              "bytecode" => _,
              "bytecodeType" => _,
              "compilerVersion" => _,
              "sourceFiles" => _
            } = body,
            address_hash
          ) do
        http_post_request(vyper_multiple_files_verification_url(), append_metadata(body, address_hash))
      end

      def vyper_verify_standard_json(
            %{
              "bytecode" => _,
              "bytecodeType" => _,
              "compilerVersion" => _,
              "input" => _
            } = body,
            address_hash
          ) do
        http_post_request(vyper_standard_json_verification_url(), append_metadata(body, address_hash))
      end

      def http_post_request(url, body) do
        headers = [{"Content-Type", "application/json"}]

        case HTTPoison.post(url, Jason.encode!(body), headers, recv_timeout: @post_timeout) do
          {:ok, %Response{body: body, status_code: _}} ->
            process_verifier_response(body)

          {:error, error} ->
            old_truncate = Application.get_env(:logger, :truncate)
            Logger.configure(truncate: :infinity)

            Logger.error(fn ->
              [
                "Error while sending request to verification microservice url: #{url}, body: #{inspect(body, limit: :infinity, printable_limit: :infinity)}: ",
                inspect(error, limit: :infinity, printable_limit: :infinity)
              ]
            end)

            Logger.configure(truncate: old_truncate)
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
            old_truncate = Application.get_env(:logger, :truncate)
            Logger.configure(truncate: :infinity)

            Logger.error(fn ->
              [
                "Error while sending request to verification microservice url: #{url}: ",
                inspect(error, limit: :infinity, printable_limit: :infinity)
              ]
            end)

            Logger.configure(truncate: old_truncate)
            {:error, @request_error_msg}
        end
      end

      def get_versions_list do
        http_get_request(versions_list_url())
      end

      def vyper_get_versions_list do
        http_get_request(vyper_versions_list_url())
      end

      def process_verifier_response(body) when is_binary(body) do
        case Jason.decode(body) do
          {:ok, decoded} ->
            process_verifier_response(decoded)

          _ ->
            {:error, body}
        end
      end

      def process_verifier_response(%{"status" => "SUCCESS", "source" => source}) do
        {:ok, source}
      end

      def process_verifier_response(%{"status" => "FAILURE", "message" => error}) do
        {:error, error}
      end

      def process_verifier_response(%{"compilerVersions" => versions}), do: {:ok, versions}

      def process_verifier_response(other), do: {:error, other}

      def multiple_files_verification_url, do: "#{base_api_url()}" <> "/verifier/solidity/sources:verify-multi-part"

      def vyper_multiple_files_verification_url, do: "#{base_api_url()}" <> "/verifier/vyper/sources:verify-multi-part"

      def vyper_standard_json_verification_url,
        do: "#{base_api_url()}" <> "/verifier/vyper/sources:verify-standard-json"

      def standard_json_input_verification_url,
        do: "#{base_api_url()}" <> "/verifier/solidity/sources:verify-standard-json"

      def versions_list_url, do: "#{base_api_url()}" <> "/verifier/solidity/versions"

      def vyper_versions_list_url, do: "#{base_api_url()}" <> "/verifier/vyper/versions"

      def base_api_url, do: "#{base_url()}" <> "/api/v2"

      def base_url do
        RustService.base_url(Explorer.SmartContract.RustVerifierInterfaceBehaviour)
      end

      def enabled?, do: Application.get_env(:explorer, Explorer.SmartContract.RustVerifierInterfaceBehaviour)[:enabled]

      defp append_metadata(body, address_hash) when is_map(body) do
        body
        |> Map.put("metadata", %{
          "chainId" => Application.get_env(:block_scout_web, :chain_id),
          "contractAddress" => to_string(address_hash)
        })
      end
    end
  end
end
