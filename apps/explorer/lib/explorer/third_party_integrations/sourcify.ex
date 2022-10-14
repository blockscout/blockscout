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

    missing_files = get_missing_file_sources(files)

    case http_post_request(verify_url(), multipart_body) do
      {:ok, response} ->
        {:ok, response}

      {:error, error} ->
        if String.starts_with?(error["error"], "Resource missing") do
          {:error, %{"error" => "Resources missing: " <> Enum.join(missing_files, ", ")}}
        else
          {:error, error}
        end
    end
  end

  # sobelow_skip ["Traversal"]
  def get_missing_file_sources(files) do
    json_file =
      files
      |> Enum.find(&String.ends_with?(&1.filename, ".json"))

    with {:ok, body} <- File.read(json_file.path),
         {:ok, %{metadata: metadata}} <- Jason.decode(body),
         {:ok, metadata} <-
           metadata
           |> Jason.decode() do
      required_files =
        metadata
        |> Map.get("sources")
        |> Map.keys()
        |> List.flatten()
        |> Enum.reject(&is_nil/1)
        |> Enum.map(&Path.basename/1)

      uploaded_files =
        files
        |> Enum.map(& &1.filename)

      required_files -- uploaded_files
    end
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
