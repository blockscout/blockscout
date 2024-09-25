defmodule NFTMediaHandlerDispatcher do
  @moduledoc """
  Documentation for `NFTMediaHandlerDispatcher`.
  """

  @spec get_media_url_from_metadata(nil | map()) :: nil | binary()
  def get_media_url_from_metadata(metadata) when is_map(metadata) do
    result =
      cond do
        metadata["image_url"] ->
          metadata["image_url"]

        metadata["image"] ->
          metadata["image"]

        is_map(metadata["properties"]) && is_binary(metadata["properties"]["image"]) ->
          metadata["properties"]["image"]

        metadata["animation_url"] ->
          metadata["animation_url"]

        true ->
          nil
      end

    if result && String.trim(result) == "", do: nil, else: result
  end

  def get_media_url_from_metadata(nil), do: nil
end
