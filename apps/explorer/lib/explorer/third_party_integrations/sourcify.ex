# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.ThirdPartyIntegrations.Sourcify do
  @moduledoc """
  Adapter for contracts verification with https://sourcify.dev/

  Uses the Sourcify API v2 (https://docs.sourcify.dev/docs/api/). The legacy v1
  endpoints (`/check-by-addresses`, `/files`, `/verify`) have been deprecated and
  shut down (https://docs.sourcify.dev/blog/api-v1-brownouts/).

  The public functions keep their historic return contracts so that the callers in
  `Explorer.SmartContract.Solidity.PublishHelper` and the RPC contract controller do
  not need to change: the v2 responses are adapted back into the legacy
  metadata-file-list shape and the `exact_match`/`match` statuses are mapped onto the
  legacy `perfect`/`partial`/`full` tokens.
  """

  alias Explorer.Helper, as: ExplorerHelper
  alias Explorer.HttpClient
  alias Explorer.SmartContract.{Helper, RustVerifierInterface}

  @post_timeout :timer.seconds(30)
  @no_metadata_message "Sourcify did not return metadata"
  @failed_verification_message "Unsuccessful Sourcify verification"
  @not_verified_message "Contract is not verified"
  @timeout_message "Sourcify verification timed out"

  @default_poll_interval_ms :timer.seconds(3)
  @default_poll_max_attempts 20

  def check_by_address(address_hash_string) do
    case do_lookup(address_hash_string, nil) do
      {:ok, "exact_match", _body} ->
        {:ok, [%{"status" => "perfect"}]}

      {:ok, "match", _body} ->
        {:error, "partial"}

      :not_verified ->
        {:error, @not_verified_message}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def check_by_address_any(address_hash_string) do
    case do_lookup(address_hash_string, :with_sources) do
      {:ok, "exact_match", body} ->
        {:ok, "full", reconstruct_file_list(body)}

      {:ok, "match", body} ->
        {:ok, "partial", reconstruct_file_list(body)}

      :not_verified ->
        {:error, @not_verified_message}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def get_metadata(address_hash_string) do
    case do_lookup(address_hash_string, :with_sources) do
      # v1 `/files/{chainId}/{address}` returned full matches only
      {:ok, "exact_match", body} ->
        {:ok, reconstruct_file_list(body)}

      {:ok, "match", _body} ->
        {:error, %{"error" => @not_verified_message}}

      :not_verified ->
        {:error, %{"error" => @not_verified_message}}

      {:error, reason} ->
        {:error, %{"error" => reason}}
    end
  end

  def verify(address_hash_string, files, chosen_contract) do
    if RustVerifierInterface.enabled?() do
      verify_via_rust_microservice(address_hash_string, files, chosen_contract)
    else
      verify_via_sourcify_server(address_hash_string, files)
    end
  end

  def verify_via_sourcify_server(address_hash_string, files) do
    with normalized_files <- normalize_files(files),
         {:ok, metadata, sources} <- extract_metadata_and_sources(normalized_files) do
      body = %{"sources" => sources, "metadata" => metadata}
      submit_and_poll_verification(verify_metadata_url(address_hash_string), body)
    end
  end

  def verify_via_rust_microservice(address_hash_string, files, chosen_contract) do
    chain_id = config(__MODULE__, :chain_id)

    body_params =
      Map.new()
      |> Map.put("chain", chain_id)
      |> Map.put("address", address_hash_string)
      |> add_chosen_contract(chosen_contract)

    files_body = prepare_body_for_microservice(files)

    body =
      body_params
      |> Map.put("files", files_body)

    http_post_request_rust_microservice(verify_url_rust_microservice(), body)
  end

  defp add_chosen_contract(params, index) when is_binary(index) do
    case Integer.parse(index) do
      {integer, ""} ->
        Map.put(params, "chosenContract", integer)

      _ ->
        params
    end
  end

  defp add_chosen_contract(params, index) when is_number(index) do
    Map.put(params, "chosenContract", index)
  end

  defp add_chosen_contract(params, _index), do: params

  defp prepare_body_for_microservice(files) when is_map(files) do
    files
    |> Enum.reduce(Map.new(), fn {name, content}, acc ->
      if content do
        file_content = get_file_content(name, content)

        acc
        |> Map.put(name, file_content)
      else
        acc
      end
    end)
  end

  # sobelow_skip ["Traversal.FileModule"]
  defp prepare_body_for_microservice(files) do
    files
    |> Enum.reduce(Map.new(), fn file, acc ->
      if file do
        {:ok, file_content} = File.read(file.path)

        file_content = get_file_content(file.filename, file_content)

        acc
        |> Map.put(file.filename, file_content)
      else
        acc
      end
    end)
  end

  defp get_file_content(name, content) do
    if Helper.json_file?(name) do
      content
      |> Utils.JSON.decode!()
      |> Utils.JSON.encode!()
    else
      content
    end
  end

  # Normalizes the incoming files into a flat `%{relative_name => content}` map.
  # Files arrive either as a `name => content` map or as a list of upload structs
  # (`%Plug.Upload{}` / `%{path:, filename:}`) - see the controllers building them.
  defp normalize_files(files) when is_map(files) do
    Enum.reduce(files, %{}, fn {name, content}, acc ->
      if content, do: Map.put(acc, name, content), else: acc
    end)
  end

  # sobelow_skip ["Traversal.FileModule"]
  defp normalize_files(files) when is_list(files) do
    Enum.reduce(files, %{}, fn
      %{path: path} = file, acc when not is_nil(path) ->
        case File.read(path) do
          {:ok, content} ->
            name = Map.get(file, :filename) || Path.basename(path)
            Map.put(acc, name, content)

          _ ->
            acc
        end

      _file, acc ->
        acc
    end)
  end

  defp normalize_files(_files), do: %{}

  # Splits the normalized files into the `metadata` object and the `sources` map
  # expected by the v2 `POST /v2/verify/metadata/{chainId}/{address}` endpoint.
  defp extract_metadata_and_sources(files_map) do
    {metadata_files, source_files} =
      Enum.split_with(files_map, fn {name, _content} ->
        Path.basename(name) == "metadata.json"
      end)

    case metadata_files do
      [{_name, metadata_content} | _] ->
        {:ok, ExplorerHelper.decode_json(metadata_content), Map.new(source_files)}

      [] ->
        {:error, @no_metadata_message}
    end
  end

  defp submit_and_poll_verification(url, body) do
    request =
      HttpClient.post(url, Utils.JSON.encode!(body), [{"Content-Type", "application/json"}],
        recv_timeout: @post_timeout
      )

    case request do
      {:ok, %{body: response_body, status_code: status_code}} when status_code in [200, 202] ->
        case ExplorerHelper.decode_json(response_body) do
          %{"verificationId" => verification_id} ->
            poll_verification(verification_id, poll_max_attempts())

          _ ->
            {:error, @failed_verification_message}
        end

      {:ok, %{body: response_body, status_code: status_code}} when status_code in 400..526 ->
        parse_http_error_response(response_body)

      _ ->
        {:error, "Unexpected response from Sourcify verify method"}
    end
  end

  defp poll_verification(_verification_id, attempts_left) when attempts_left <= 0 do
    {:error, @timeout_message}
  end

  defp poll_verification(verification_id, attempts_left) do
    request = HttpClient.get(verify_job_url(verification_id), [], recv_timeout: @post_timeout)

    case request do
      {:ok, %{body: body, status_code: 200}} ->
        handle_verification_job(ExplorerHelper.decode_json(body), verification_id, attempts_left)

      {:ok, %{body: body, status_code: status_code}} when status_code in 400..526 ->
        parse_http_error_response(body)

      _ ->
        {:error, "Unexpected response from Sourcify verify method"}
    end
  end

  defp handle_verification_job(%{"isJobCompleted" => true, "error" => error}, _id, _attempts)
       when not is_nil(error) do
    {:error, verification_error_message(error)}
  end

  defp handle_verification_job(%{"isJobCompleted" => true} = body, _id, _attempts) do
    {:ok, body}
  end

  # Not completed yet (or an unexpected shape): wait and poll again.
  defp handle_verification_job(_body, verification_id, attempts_left) do
    Process.sleep(poll_interval_ms())
    poll_verification(verification_id, attempts_left - 1)
  end

  defp verification_error_message(%{"message" => message}) when is_binary(message), do: message
  defp verification_error_message(error) when is_binary(error), do: error
  defp verification_error_message(_error), do: @failed_verification_message

  # Fetches a contract from the v2 `GET /v2/contract/{chainId}/{address}` endpoint.
  # `fields == :with_sources` additionally requests the `sources` and `metadata` fields.
  defp do_lookup(address_hash_string, fields) do
    params = if fields == :with_sources, do: [fields: "sources,metadata"], else: []

    case HttpClient.get(contract_lookup_url(address_hash_string), [], params: params) do
      {:ok, %{body: body, status_code: 200}} ->
        parse_lookup_response(ExplorerHelper.decode_json(body))

      {:ok, %{status_code: 404}} ->
        :not_verified

      {:ok, %{body: body, status_code: status_code}} when status_code in 400..526 ->
        parse_http_error_response(body)

      {:ok, %{status_code: status_code}} when status_code in 300..308 ->
        {:error, "Sourcify redirected"}

      {:ok, %{status_code: _status_code}} ->
        {:error, "Sourcify unexpected status code"}

      {:error, reason} ->
        {:error, reason}

      _ ->
        {:error, "Unexpected response from Sourcify"}
    end
  end

  defp parse_lookup_response(%{"match" => match} = body) when match in ["exact_match", "match"] do
    {:ok, match, body}
  end

  defp parse_lookup_response(%{"match" => nil}), do: :not_verified

  defp parse_lookup_response(_body), do: {:error, "Unexpected response from Sourcify"}

  # Rebuilds the legacy v1 metadata-file-list `[%{"name","path","content"}]` from the
  # v2 `sources` map and `metadata` object so that `parse_params_from_sourcify/2` keeps
  # working unchanged. The metadata content must be a JSON string because the parser
  # decodes it downstream.
  defp reconstruct_file_list(body_json) do
    sources = Map.get(body_json, "sources") || %{}
    metadata = Map.get(body_json, "metadata")

    source_files =
      Enum.map(sources, fn {path, content} ->
        %{"name" => Path.basename(path), "path" => path, "content" => source_content(content)}
      end)

    if is_map(metadata) do
      metadata_file = %{
        "name" => "metadata.json",
        "path" => "metadata.json",
        "content" => Utils.JSON.encode!(metadata)
      }

      [metadata_file | source_files]
    else
      source_files
    end
  end

  defp source_content(%{"content" => content}), do: content
  defp source_content(content) when is_binary(content), do: content
  defp source_content(content), do: content

  def http_post_request_rust_microservice(url, body) do
    request =
      HttpClient.post(url, Utils.JSON.encode!(body), [{"Content-Type", "application/json"}],
        recv_timeout: @post_timeout
      )

    case request do
      {:ok, %{body: body, status_code: 200}} ->
        parse_verify_http_response(body)

      _ ->
        {:error, "Unexpected response from Sourcify verify method"}
    end
  end

  defp parse_verify_http_response(body) do
    body_json = ExplorerHelper.decode_json(body)

    case body_json do
      # Success status code from Rust microservice
      %{"status" => "SUCCESS"} ->
        {:ok, body_json}

      %{"status" => "FAILURE", "message" => message} ->
        {:error, message}

      body ->
        {:error, body}
    end
  end

  @invalid_json_response "invalid http error json response"
  defp parse_http_error_response(body) do
    body_json = ExplorerHelper.decode_json(body)

    if is_map(body_json) do
      error = body_json["error"] || body_json["message"]

      parse_http_error_response_internal(error)
    else
      parse_http_error_response_internal(body)
    end
  end

  defp parse_http_error_response_internal(nil), do: {:error, @invalid_json_response}

  defp parse_http_error_response_internal(data), do: {:error, data}

  def parse_params_from_sourcify(address_hash_string, verification_metadata) do
    filtered_files =
      verification_metadata
      |> Enum.filter(&(Map.get(&1, "name") == "metadata.json"))

    if Enum.empty?(filtered_files) do
      {:error, :metadata}
    else
      verification_metadata_json = Enum.fetch!(filtered_files, 0)

      full_params_initial = parse_json_from_sourcify_for_insertion(verification_metadata_json)

      verification_metadata_sol =
        verification_metadata
        |> Enum.filter(fn %{"name" => name, "content" => _content} -> name =~ ".sol" end)

      verification_metadata_sol
      |> Enum.reduce(full_params_initial, fn %{"name" => name, "content" => content, "path" => _path} = param,
                                             full_params_acc ->
        construct_params_from_sourcify(name, full_params_acc, content, param, address_hash_string)
      end)
    end
  end

  defp construct_params_from_sourcify(name, full_params_acc, content, param, address_hash_string) do
    compilation_target_file_name = Map.get(full_params_acc, "compilation_target_file_name")

    {params_to_publish, secondary_sources} =
      if String.downcase(name) == String.downcase(compilation_target_file_name) do
        params_to_publish = extract_primary_source_code(content, Map.get(full_params_acc, "params_to_publish"))
        {params_to_publish, Map.get(full_params_acc, "secondary_sources")}
      else
        secondary_sources = [
          prepare_additional_source(address_hash_string, param) | Map.get(full_params_acc, "secondary_sources")
        ]

        {Map.get(full_params_acc, "params_to_publish"), secondary_sources}
      end

    %{
      "params_to_publish" => params_to_publish,
      "abi" => Map.get(full_params_acc, "abi"),
      "secondary_sources" => secondary_sources,
      "compilation_target_file_path" => Map.get(full_params_acc, "compilation_target_file_path"),
      "compilation_target_file_name" => compilation_target_file_name
    }
  end

  defp parse_json_from_sourcify_for_insertion(verification_metadata_json) do
    %{"name" => _, "content" => content} = verification_metadata_json
    content_json = ExplorerHelper.decode_json(content)
    compiler_version = "v" <> (content_json |> Map.get("compiler") |> Map.get("version"))
    abi = content_json |> Map.get("output") |> Map.get("abi")
    settings = Map.get(content_json, "settings")
    compilation_target_file_path = settings |> Map.get("compilationTarget") |> Map.keys() |> Enum.at(0)
    compilation_target_file_name = compilation_target_file_path |> String.split("/") |> Enum.at(-1)
    contract_name = settings |> Map.get("compilationTarget") |> Map.get("#{compilation_target_file_path}")
    optimizer = Map.get(settings, "optimizer")

    runs =
      optimizer
      |> Map.get("runs")
      |> (&if(Application.get_env(:explorer, :chain_type) == :zksync,
            do: to_string(&1),
            else: &1
          )).()

    params =
      %{}
      |> Map.put("name", contract_name)
      |> Map.put("compiler_version", compiler_version)
      |> Map.put("evm_version", Map.get(settings, "evmVersion"))
      |> Map.put("optimization", Map.get(optimizer, "enabled"))
      |> Map.put("optimization_runs", runs)
      |> Map.put("external_libraries", Map.get(settings, "libraries"))
      |> Map.put("verified_via_sourcify", true)
      |> Map.put("compiler_settings", settings)

    %{
      "params_to_publish" => params,
      "abi" => abi,
      "compilation_target_file_path" => compilation_target_file_path,
      "compilation_target_file_name" => compilation_target_file_name,
      "secondary_sources" => []
    }
  end

  defp prepare_additional_source(address_hash_string, %{"name" => _name, "content" => content, "path" => path}) do
    %{
      "address_hash" => address_hash_string,
      "file_name" => normalize_source_path(path),
      "contract_source_code" => content
    }
  end

  defp normalize_source_path("/" <> _rest = path), do: path
  defp normalize_source_path(path), do: "/" <> path

  defp extract_primary_source_code(content, params) do
    params
    |> Map.put("contract_source_code", content)
  end

  defp config(module, key) do
    :explorer
    |> Application.get_env(module)
    |> Keyword.get(key)
  end

  defp base_server_url do
    config(__MODULE__, :server_url)
  end

  defp contract_lookup_url(address_hash_string) do
    chain_id = config(__MODULE__, :chain_id)
    "#{base_server_url()}/v2/contract/#{chain_id}/#{address_hash_string}"
  end

  defp verify_metadata_url(address_hash_string) do
    chain_id = config(__MODULE__, :chain_id)
    "#{base_server_url()}/v2/verify/metadata/#{chain_id}/#{address_hash_string}"
  end

  defp verify_job_url(verification_id) do
    "#{base_server_url()}/v2/verify/#{verification_id}"
  end

  defp verify_url_rust_microservice do
    "#{RustVerifierInterface.base_api_url()}" <> "/verifier/sourcify/sources:verify"
  end

  defp poll_interval_ms do
    config(__MODULE__, :verification_poll_interval_ms) || @default_poll_interval_ms
  end

  defp poll_max_attempts do
    config(__MODULE__, :verification_max_attempts) || @default_poll_max_attempts
  end

  def no_metadata_message, do: @no_metadata_message

  def failed_verification_message, do: @failed_verification_message
end
