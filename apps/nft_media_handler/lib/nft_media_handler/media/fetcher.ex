defmodule NFTMediaHandler.Media.Fetcher do
  @moduledoc """
    Module fetches media from various sources
  """

  @supported_image_types ["png", "jpeg", "gif", "webp"]
  @supported_video_types ["mp4"]

  def fetch_media(url, headers) when is_binary(url) do
    with media_type <- media_type(url, headers),
         {:support, true} <- {:support, media_type_supported?(media_type)},
         {:ok, %HTTPoison.Response{status_code: 200, body: body}} <-
           HTTPoison.get(url, headers, follow_redirect: true, max_body_length: 20_000_000) do
      {:ok, media_type, body}
    else
      {:support, false} ->
        {:error, :unsupported_media_type}

      {:ok, %HTTPoison.Response{status_code: status_code, body: _body}} ->
        {:error, status_code}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  def media_type("data:" <> _data, _headers) do
    nil
  end

  def media_type(media_src, headers) when not is_nil(media_src) do
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

  def media_type(nil, _headers), do: nil

  @spec media_type_supported?(any()) :: boolean()
  def media_type_supported?({"image", image_type}) when image_type in @supported_image_types do
    true
  end

  def media_type_supported?({"video", video_type}) when video_type in @supported_video_types do
    true
  end

  def media_type_supported?(_) do
    false
  end

  def process_missing_extension(media_src, headers) do
    case HTTPoison.head(media_src, headers, follow_redirect: true) do
      {:ok, %HTTPoison.Response{status_code: 200, headers: headers}} ->
        headers_map = Map.new(headers, fn {key, value} -> {String.downcase(key), value} end)
        headers_map["content-type"]

      _ ->
        nil
    end
  end
end
