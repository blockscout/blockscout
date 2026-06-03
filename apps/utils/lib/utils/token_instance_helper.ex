# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Utils.TokenInstanceHelper do
  @moduledoc """
  Auxiliary functions for NFTs
  """

  @doc """
  Determines the media type of the given URL.

  ## Parameters

    - url: The URL to check the media type for.
    - headers: Optional list of headers to include in the request. Defaults to an empty list.
    - treat_data_as_valid_media_type?: Optional boolean flag to treat url of `data:image/` format as a valid media type. Defaults to true.

  ## Returns

  The media type of the given URL, or nil
  """
  @spec media_type(binary(), list(), boolean()) :: {binary(), binary()} | nil
  def media_type(url, headers \\ [], treat_data_as_valid_media_type? \\ true)

  def media_type("data:image/" <> _data, _headers, true) do
    {"image", ""}
  end

  def media_type("data:video/" <> _data, _headers, true) do
    {"video", ""}
  end

  def media_type("data:" <> _data, _headers, _) do
    nil
  end

  def media_type(media_src, headers, _) when not is_nil(media_src) do
    ext = media_src |> Path.extname() |> String.trim()

    mime_type =
      if ext == "" do
        process_missing_extension(media_src, headers)
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

  def media_type(nil, _headers, _), do: nil

  @doc """
  Same as `media_type/3` but returns `{:ok, {type, subtype}}` or `{:error, reason}`.
  """
  @spec media_type_detailed(binary(), list()) :: {:ok, {binary(), binary()}} | {:error, binary()}
  def media_type_detailed(url, headers \\ [])

  def media_type_detailed("data:image/" <> _data, _headers), do: {:ok, {"image", ""}}
  def media_type_detailed("data:video/" <> _data, _headers), do: {:ok, {"video", ""}}

  def media_type_detailed("data:" <> data, _headers),
    do: {:error, "unsupported data URI scheme: #{String.slice(data, 0, 20)}"}

  def media_type_detailed(nil, _headers), do: {:error, "nil URL"}

  def media_type_detailed(media_src, headers) do
    ext = media_src |> Path.extname() |> String.trim()

    if ext == "" do
      case process_missing_extension_detailed(media_src, headers) do
        {:ok, mime_type} -> {:ok, mime_type |> String.split("/") |> List.to_tuple()}
        {:error, _} = error -> error
      end
    else
      "." <> ext_without_dot = Path.extname(media_src)
      {:ok, ext_without_dot |> MIME.type() |> String.split("/") |> List.to_tuple()}
    end
  end

  defp process_missing_extension(media_src, headers) do
    case HTTPoison.head(media_src, headers, follow_redirect: true, timeout: 30_000, recv_timeout: 30_000) do
      {:ok, %HTTPoison.Response{status_code: 200, headers: headers}} ->
        headers_map = Map.new(headers, fn {key, value} -> {String.downcase(key), value} end)
        headers_map["content-type"]

      _ ->
        nil
    end
  end

  defp process_missing_extension_detailed(media_src, headers) do
    case HTTPoison.head(media_src, headers, follow_redirect: true, timeout: 30_000, recv_timeout: 30_000) do
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
    end
  end
end
