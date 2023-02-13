defmodule BlockScoutWeb.NFTHelpers do
  @moduledoc """
    Module with functions for NFT view
  """
  def get_media_src(nil, _), do: nil

  def get_media_src(metadata, high_quality_media?) do
    result =
      cond do
        metadata["animation_url"] && high_quality_media? ->
          retrieve_image(metadata["animation_url"])

        metadata["image_url"] ->
          retrieve_image(metadata["image_url"])

        metadata["image"] ->
          retrieve_image(metadata["image"])

        metadata["properties"]["image"]["description"] ->
          metadata["properties"]["image"]["description"]

        true ->
          nil
      end

    if result && String.trim(result) == "", do: nil, else: result
  end

  def external_url(nil), do: nil

  def external_url(instance) do
    result =
      if instance.metadata && instance.metadata["external_url"] do
        instance.metadata["external_url"]
      else
        external_url(nil)
      end

    if !result || (result && String.trim(result)) == "", do: external_url(nil), else: result
  end

  def retrieve_image(image) when is_nil(image), do: nil

  def retrieve_image(image) when is_map(image) do
    image["description"]
  end

  def retrieve_image(image) when is_list(image) do
    image_url = image |> Enum.at(0)
    retrieve_image(image_url)
  end

  def retrieve_image(image_url) do
    image_url
    |> URI.encode()
    |> compose_ipfs_url()
  end

  def compose_ipfs_url(image_url) do
    cond do
      image_url =~ ~r/^ipfs:\/\/ipfs/ ->
        "ipfs://ipfs" <> ipfs_uid = image_url
        "https://ipfs.io/ipfs/" <> ipfs_uid

      image_url =~ ~r/^ipfs:\/\// ->
        "ipfs://" <> ipfs_uid = image_url
        "https://ipfs.io/ipfs/" <> ipfs_uid

      true ->
        image_url
    end
  end
end
