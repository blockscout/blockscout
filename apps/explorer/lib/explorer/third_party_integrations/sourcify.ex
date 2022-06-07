defmodule Explorer.ThirdPartyIntegrations.Sourcify do
  @moduledoc """
  Adapter for contracts verification with https://sourcify.dev/
  """
  use Tesla

  alias HTTPoison.{Error, Response}
  alias Tesla.Multipart

  def check_by_address(address_hash_string) do
    chain_id = config(:chain_id)
    params = [addresses: address_hash_string, chainIds: chain_id]
    http_get_request(check_by_address_url(), params)
  end

  def check_by_address_any(address_hash_string) do
    get_metadata_full_url = get_metadata_any_url() <> "/" <> address_hash_string
    http_get_request(get_metadata_full_url, [])
  end

  def get_metadata(address_hash_string) do
    get_metadata_full_url = get_metadata_url() <> "/" <> address_hash_string
    http_get_request(get_metadata_full_url, [])
  end

  def verify(address_hash_string, files) do
    chain_id = config(:chain_id)

    multipart_text_params =
      Multipart.new()
      |> Multipart.add_field("chain", chain_id)
      |> Multipart.add_field("address", address_hash_string)

    multipart_body =
      files
      |> Enum.reduce(multipart_text_params, fn file, acc ->
        if file do
          acc
          |> Multipart.add_file(file.path,
            name: "files",
            file_name: Path.basename(file.path)
          )
        else
          acc
        end
      end)

    http_post_request(verify_url(), multipart_body)
  end

  def http_get_request(url, params) do
    request = HTTPoison.get(url, [], params: params)

    case request do
      {:ok, %Response{body: body, status_code: 200}} ->
        process_sourcify_response(url, body)

      {:ok, %Response{body: body, status_code: status_code}} when status_code in 400..526 ->
        parse_http_error_response(body)

      {:ok, %Response{status_code: status_code}} when status_code in 300..308 ->
        {:error, "Sourcify redirected"}

      {:ok, %Response{status_code: _status_code}} ->
        {:error, "Sourcify unexpected status code"}

      {:error, %Error{reason: reason}} ->
        {:error, reason}

      {:error, :nxdomain} ->
        {:error, "Sourcify is not responsive"}

      {:error, _} ->
        {:error, "Unexpected response from Sourcify"}
    end
  end

  def http_post_request(url, body) do
    request = Tesla.post(url, body)

    case request do
      {:ok, %Tesla.Env{body: body}} ->
        process_sourcify_response(url, body)

      _ ->
        {:error, "Unexpected response from Sourcify verify method"}
    end
  end

  defp process_sourcify_response(url, body) do
    cond do
      url =~ "check-by-addresses" ->
        parse_check_by_address_http_response(body)

      url =~ "/verify" ->
        parse_verify_http_response(body)

      url =~ "/files/any" ->
        parse_get_metadata_any_http_response(body)

      url =~ "/files/" ->
        parse_get_metadata_http_response(body)

      true ->
        {:error, body}
    end
  end

  defp parse_verify_http_response(body) do
    body_json = decode_json(body)

    case body_json do
      %{"result" => [%{"status" => "perfect"}]} ->
        {:ok, body_json}

      %{"result" => [%{"status" => unknown_status}]} ->
        {:error, unknown_status}

      body ->
        {:error, body}
    end
  end

  defp parse_check_by_address_http_response(body) do
    body_json = decode_json(body)

    case body_json do
      [%{"status" => "perfect"}] ->
        {:ok, body_json}

      [%{"status" => "false"}] ->
        {:error, "Contract is not verified"}

      [%{"status" => unknown_status}] ->
        {:error, unknown_status}

      body ->
        {:error, body}
    end
  end

  defp parse_get_metadata_http_response(body) do
    body_json = decode_json(body)

    case body_json do
      %{"message" => message, "errors" => errors} ->
        {:error, "#{message}: #{decode_json(errors)}"}

      metadata ->
        {:ok, metadata}
    end
  end

  defp parse_get_metadata_any_http_response(body) do
    body_json = decode_json(body)

    case body_json do
      %{"message" => message, "errors" => errors} ->
        {:error, "#{message}: #{decode_json(errors)}"}

      %{"status" => status, "files" => metadata} ->
        {:ok, status, metadata}

      _ ->
        {:error, "Unknown Error"}
    end
  end

  defp parse_http_error_response(body) do
    body_json = decode_json(body)

    if is_map(body_json) do
      {:error, body_json["error"]}
    else
      {:error, body}
    end
  end

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
        compilation_target_file_name = Map.get(full_params_acc, "compilation_target_file_name")

        if String.downcase(name) == String.downcase(compilation_target_file_name) do
          %{
            "params_to_publish" => extract_primary_source_code(content, Map.get(full_params_acc, "params_to_publish")),
            "abi" => Map.get(full_params_acc, "abi"),
            "secondary_sources" => Map.get(full_params_acc, "secondary_sources"),
            "compilation_target_file_path" => Map.get(full_params_acc, "compilation_target_file_path"),
            "compilation_target_file_name" => compilation_target_file_name
          }
        else
          secondary_sources = [
            prepare_additional_source(address_hash_string, param) | Map.get(full_params_acc, "secondary_sources")
          ]

          %{
            "params_to_publish" => Map.get(full_params_acc, "params_to_publish"),
            "abi" => Map.get(full_params_acc, "abi"),
            "secondary_sources" => secondary_sources,
            "compilation_target_file_path" => Map.get(full_params_acc, "compilation_target_file_path"),
            "compilation_target_file_name" => compilation_target_file_name
          }
        end
      end)
    end
  end

  defp parse_json_from_sourcify_for_insertion(verification_metadata_json) do
    %{"name" => _, "content" => content} = verification_metadata_json
    content_json = decode_json(content)
    compiler_version = "v" <> (content_json |> Map.get("compiler") |> Map.get("version"))
    abi = content_json |> Map.get("output") |> Map.get("abi")
    settings = Map.get(content_json, "settings")
    compilation_target_file_path = settings |> Map.get("compilationTarget") |> Map.keys() |> Enum.at(0)
    compilation_target_file_name = compilation_target_file_path |> String.split("/") |> Enum.at(-1)
    contract_name = settings |> Map.get("compilationTarget") |> Map.get("#{compilation_target_file_path}")
    optimizer = Map.get(settings, "optimizer")

    params =
      %{}
      |> Map.put("name", contract_name)
      |> Map.put("compiler_version", compiler_version)
      |> Map.put("evm_version", Map.get(settings, "evmVersion"))
      |> Map.put("optimization", Map.get(optimizer, "enabled"))
      |> Map.put("optimization_runs", Map.get(optimizer, "runs"))
      |> Map.put("external_libraries", Map.get(settings, "libraries"))
      |> Map.put("verified_via_sourcify", true)

    %{
      "params_to_publish" => params,
      "abi" => abi,
      "compilation_target_file_path" => compilation_target_file_path,
      "compilation_target_file_name" => compilation_target_file_name,
      "secondary_sources" => []
    }
  end

  defp prepare_additional_source(address_hash_string, %{"name" => _name, "content" => content, "path" => path}) do
    splitted_path =
      path
      |> String.split("/")

    trimmed_path =
      splitted_path
      |> Enum.slice(9..Enum.count(splitted_path))
      |> Enum.join("/")

    %{
      "address_hash" => address_hash_string,
      "file_name" => "/" <> trimmed_path,
      "contract_source_code" => content
    }
  end

  defp extract_primary_source_code(content, params) do
    params
    |> Map.put("contract_source_code", content)
  end

  def decode_json(data) do
    Jason.decode!(data)
  rescue
    _ -> data
  end

  defp config(key) do
    :explorer
    |> Application.get_env(__MODULE__)
    |> Keyword.get(key)
  end

  defp base_server_url do
    config(:server_url)
  end

  defp verify_url do
    "#{base_server_url()}" <> "/verify"
  end

  defp check_by_address_url do
    "#{base_server_url()}" <> "/check-by-addresses"
  end

  defp get_metadata_url do
    chain_id = config(:chain_id)
    "#{base_server_url()}" <> "/files/" <> chain_id
  end

  defp get_metadata_any_url do
    chain_id = config(:chain_id)
    "#{base_server_url()}" <> "/files/any/" <> chain_id
  end
end
