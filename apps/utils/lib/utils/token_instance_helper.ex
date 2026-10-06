# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Utils.TokenInstanceHelper do
  @moduledoc """
  Auxiliary functions for NFTs
  """

  alias Utils.HttpClient.SafeFetch

  @doc """
  Determines the media type of the given URL.

  ## Parameters

    - url: The URL to check the media type for.
    - headers: Optional list of headers to include in the request. Defaults to an empty list.
    - treat_data_as_valid_media_type?: Optional boolean flag to treat url of `data:image/` format as a valid media type. Defaults to true.
    - validate_host?: Optional boolean flag to validate the host against the SSRF blacklist. Defaults to true. Pass `false` for URLs already resolved to an operator-configured gateway (IPFS/Arweave/Swarm), which may legitimately live on a private address.

  ## Returns

  The media type of the given URL, or nil
  """
  @spec media_type(binary(), list(), boolean(), boolean()) :: {binary(), binary()} | nil
  def media_type(url, headers \\ [], treat_data_as_valid_media_type? \\ true, validate_host? \\ true)

  def media_type("data:image/" <> _data, _headers, true, _validate_host?) do
    {"image", ""}
  end

  def media_type("data:video/" <> _data, _headers, true, _validate_host?) do
    {"video", ""}
  end

  def media_type("data:" <> _data, _headers, _, _validate_host?) do
    nil
  end

  def media_type(media_src, headers, _, validate_host?) when not is_nil(media_src) do
    ext = media_src |> Path.extname() |> String.trim()

    mime_type =
      if ext == "" do
        process_missing_extension(media_src, headers, validate_host?)
      else
        ext_with_dot =
          media_src
          |> Path.extname()

        "." <> ext = ext_with_dot

        ext
        |> MIME.type()
      end

    if mime_type do
      mime_type |> String.split("/") |> List.to_tuple()
    else
      nil
    end
  end

  def media_type(nil, _headers, _, _validate_host?), do: nil

  @doc """
  Same as `media_type/4` but reports why detection failed instead of returning `nil`.

  ## Parameters

    - url: The URL to check the media type for.
    - headers: Optional list of headers to include in the request. Defaults to an empty list.
    - validate_host?: Optional boolean flag to validate the host against the SSRF blacklist. Defaults to true. Pass `false` for URLs already resolved to an operator-configured gateway (IPFS/Arweave/Swarm), which may live on a private address.

  ## Returns

    - `{:ok, {type, subtype}}` with the media type split on `/`, e.g. `{"image", "png"}`. For
      `data:image/` and `data:video/` URLs the subtype is an empty string.
    - `{:error, reason}` with a human-readable binary reason when the URL is nil, uses an
      unsupported `data:` scheme, is rejected by host validation, or when the HEAD request
      fails or returns no `content-type` header.
  """
  @spec media_type_detailed(binary(), list(), boolean()) :: {:ok, {binary(), binary()}} | {:error, binary()}
  def media_type_detailed(url, headers \\ [], validate_host? \\ true)

  def media_type_detailed("data:image/" <> _data, _headers, _validate_host?), do: {:ok, {"image", ""}}
  def media_type_detailed("data:video/" <> _data, _headers, _validate_host?), do: {:ok, {"video", ""}}

  def media_type_detailed("data:" <> data, _headers, _validate_host?),
    do: {:error, "unsupported data URI scheme: #{String.slice(data, 0, 20)}"}

  def media_type_detailed(nil, _headers, _validate_host?), do: {:error, "nil URL"}

  def media_type_detailed(media_src, headers, validate_host?) do
    ext = media_src |> Path.extname() |> String.trim()

    if ext == "" do
      case process_missing_extension_detailed(media_src, headers, validate_host?) do
        {:ok, mime_type} -> {:ok, mime_type |> String.split("/") |> List.to_tuple()}
        {:error, _} = error -> error
      end
    else
      "." <> ext_without_dot = Path.extname(media_src)
      {:ok, ext_without_dot |> MIME.type() |> String.split("/") |> List.to_tuple()}
    end
  end

  defp process_missing_extension(media_src, headers, validate_host?) do
    case safe_head(media_src, headers, validate_host?) do
      {:ok, %HTTPoison.Response{status_code: 200, headers: headers}} ->
        headers_map = Map.new(headers, fn {key, value} -> {String.downcase(key), value} end)
        headers_map["content-type"]

      _ ->
        nil
    end
  end

  defp process_missing_extension_detailed(media_src, headers, validate_host?) do
    case safe_head(media_src, headers, validate_host?) do
      {:ok, %HTTPoison.Response{status_code: 200, headers: headers}} ->
        headers_map = Map.new(headers, fn {key, value} -> {String.downcase(key), value} end)

        case headers_map["content-type"] do
          nil -> {:error, "no content-type header in response"}
          mime_type -> {:ok, mime_type}
        end

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        {:error, "HTTP HEAD returned #{status_code}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "HTTP HEAD failed: #{inspect(reason)}"}

      {:error, reason} ->
        {:error, "HTTP HEAD failed: #{inspect(reason)}"}
    end
  end

  # Issues a HEAD request that validates the host (and any redirect target) against the
  # SSRF blacklist, following redirects manually since the media URL is attacker-controlled.
  defp safe_head(media_src, headers, validate_host?) do
    SafeFetch.request(
      media_src,
      headers,
      [validate_host?: validate_host?, transport_opts: [timeout: 30_000, recv_timeout: 30_000]],
      fn url, request_headers, opts -> HTTPoison.head(url, request_headers, opts) end
    )
  end
end
