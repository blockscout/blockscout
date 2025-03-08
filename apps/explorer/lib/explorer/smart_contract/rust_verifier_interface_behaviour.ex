defmodule Explorer.SmartContract.RustVerifierInterfaceBehaviour do
  @moduledoc """
    This behaviour module was created in order to add possibility to extend the functionality of RustVerifierInterface
  """
  defmacro __using__(_) do
    # credo:disable-for-next-line
    quote([]) do
      alias Explorer.Utility.Microservice
      alias Mint.HTTP, as: MintHTTP
      require Logger

      @post_timeout :timer.minutes(5)
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
            metadata
          ) do
        http_post_request(solidity_multiple_files_verification_url(), append_metadata(body, metadata), true)
      end

      def verify_standard_json_input(
            %{
              "bytecode" => _,
              "bytecodeType" => _,
              "compilerVersion" => _,
              "input" => _
            } = body,
            metadata
          ) do
        http_post_request(solidity_standard_json_verification_url(), append_metadata(body, metadata), true)
      end

      def zksync_verify_standard_json_input(
            %{
              "code" => _,
              "solcCompiler" => _,
              "zkCompiler" => _,
              "input" => _
            } = body,
            metadata
          ) do
        http_post_request(solidity_standard_json_verification_url(), append_metadata(body, metadata), true)
      end

      def vyper_verify_multipart(
            %{
              "bytecode" => _,
              "bytecodeType" => _,
              "compilerVersion" => _,
              "sourceFiles" => _
            } = body,
            metadata
          ) do
        http_post_request(vyper_multiple_files_verification_url(), append_metadata(body, metadata), true)
      end

      def vyper_verify_standard_json(
            %{
              "bytecode" => _,
              "bytecodeType" => _,
              "compilerVersion" => _,
              "input" => _
            } = body,
            metadata
          ) do
        http_post_request(vyper_standard_json_verification_url(), append_metadata(body, metadata), true)
      end

      def http_post_request(url, body, is_verification_request?, options \\ []) do
        headers = maybe_put_api_key_header([{"Content-Type", "application/json"}], is_verification_request?)

        case do_request(url, "POST", body, headers) do
          {:ok, %{data: body, status: _}} ->
            process_verifier_response(body, options)

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

      defp maybe_put_api_key_header(headers, false), do: headers

      defp maybe_put_api_key_header(headers, true) do
        api_key = Application.get_env(:explorer, Explorer.SmartContract.RustVerifierInterfaceBehaviour)[:api_key]

        if api_key do
          [{"x-api-key", api_key} | headers]
        else
          headers
        end
      end

      def http_get_request(url) do
        case do_request(url, "GET") do
          {:ok, %{data: body, status: 200}} ->
            process_verifier_response(body, [])

          {:ok, %{data: body, status: _}} ->
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

      def process_verifier_response(body, options) when is_binary(body) do
        case Jason.decode(body) do
          {:ok, decoded} ->
            process_verifier_response(decoded, options)

          _ ->
            {:error, body}
        end
      end

      def process_verifier_response(%{"status" => "SUCCESS", "source" => source}, _) do
        {:ok, source}
      end

      # zksync
      def process_verifier_response(%{"verificationSuccess" => success}, _) do
        {:ok, success}
      end

      # zksync
      def process_verifier_response(%{"verificationFailure" => %{"message" => error}}, _) do
        {:error, error}
      end

      # zksync
      def process_verifier_response(%{"compilationFailure" => %{"message" => error}}, _) do
        {:error, error}
      end

      def process_verifier_response(%{"status" => "FAILURE", "message" => error}, _) do
        {:error, error}
      end

      def process_verifier_response(%{"compilerVersions" => versions}, _), do: {:ok, versions}

      # zksync
      def process_verifier_response(%{"solcCompilers" => solc_compilers, "zkCompilers" => zk_compilers}, _),
        do: {:ok, {solc_compilers, zk_compilers}}

      def process_verifier_response(other, res) do
        {:error, other}
      end

      # Uses url encoded ("%3A") version of ':', as ':' symbol breaks `Bypass` library during tests.
      # https://github.com/PSPDFKit-labs/bypass/issues/122

      def solidity_multiple_files_verification_url,
        do: base_api_url() <> "/verifier/solidity/sources%3Averify-multi-part"

      def vyper_multiple_files_verification_url,
        do: base_api_url() <> "/verifier/vyper/sources%3Averify-multi-part"

      def vyper_standard_json_verification_url,
        do: base_api_url() <> "/verifier/vyper/sources%3Averify-standard-json"

      def solidity_standard_json_verification_url do
        base_api_url() <> verifier_path() <> "/solidity/sources%3Averify-standard-json"
      end

      def versions_list_url do
        base_api_url() <> verifier_path() <> "/solidity/versions"
      end

      defp verifier_path do
        if Application.get_env(:explorer, :chain_type) == :zksync do
          "/zksync-verifier"
        else
          "/verifier"
        end
      end

      def vyper_versions_list_url, do: base_api_url() <> "/verifier/vyper/versions"

      def base_api_url, do: "#{base_url()}" <> "/api/v2"

      def base_url do
        Microservice.base_url(Explorer.SmartContract.RustVerifierInterfaceBehaviour)
      end

      def enabled?, do: Application.get_env(:explorer, Explorer.SmartContract.RustVerifierInterfaceBehaviour)[:enabled]

      defp append_metadata(body, metadata) when is_map(body) do
        body
        |> Map.put("metadata", metadata)
      end

      # sobelow_skip ["DOS.StringToAtom"]
      defp do_request(url, method, body \\ nil, headers \\ []) do
        %{scheme: scheme, host: host, port: port, path: path} = URI.parse(url)

        with {:ok, conn} <- MintHTTP.connect(String.to_atom(scheme || "http"), host, port),
             {:ok, conn, _ref} <- MintHTTP.request(conn, method, path || "/", headers, Jason.encode!(body)) do
          try do
            handle_response(conn, %{data: [], done: false})
          after
            MintHTTP.close(conn)
          end
        end
      end

      defp handle_response(conn, state) do
        receive do
          message ->
            case MintHTTP.stream(conn, message) do
              {:ok, conn, responses} ->
                case Enum.reduce(responses, state, &handle_res/2) do
                  %{done: true} = state -> {:ok, state}
                  %{done: false} = state -> handle_response(conn, state)
                end

              {:error, _, reason, _} ->
                {:error, reason}

              :unknown ->
                handle_response(conn, state)
            end
        after
          @post_timeout -> {:error, :timeout}
        end
      end

      defp handle_res({:status, _, status}, state),
        do: Map.put(state, :status, status)

      defp handle_res({:headers, _, headers}, state),
        do: Map.put(state, :headers, headers)

      defp handle_res({:data, _, data}, state),
        do: Map.update!(state, :data, fn acc -> [data | acc] end)

      defp handle_res({:done, _}, state) do
        state
        |> Map.update!(:data, fn acc ->
          acc
          |> Enum.reverse()
          |> Enum.join("")
        end)
        |> Map.put(:done, true)
      end
    end
  end
end
