defmodule NFTMediaHandler.Media.Fetcher do
  @moduledoc """
    Module fetches media from various sources
  """

  @supported_image_types ["png", "jpeg", "gif", "webp"]
  @supported_video_types ["mp4"]

  import Utils.TokenInstanceHelper, only: [media_type: 3]

  @doc """
  Fetches media from the given URL with the specified headers.

  ## Parameters

    - url: A binary string representing the URL to fetch the media from.
    - headers: A list of headers to include in the request.

  ## Returns

  The fetched media content.

  ## Examples

      iex> fetch_media("http://example.com/media", [{"Authorization", "Bearer token"}])
      {:ok, media_content}

  """
  @spec fetch_media(binary(), list()) :: {:error, any()} | {:ok, nil | tuple(), any()}
  def fetch_media(url, headers) when is_binary(url) do
    with media_type <- media_type(url, headers, false),
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

  @spec media_type_supported?(any()) :: boolean()
  defp media_type_supported?({"image", image_type}) when image_type in @supported_image_types do
    true
  end

  defp media_type_supported?({"video", video_type}) when video_type in @supported_video_types do
    true
  end

  defp media_type_supported?(_) do
    false
  end
end
