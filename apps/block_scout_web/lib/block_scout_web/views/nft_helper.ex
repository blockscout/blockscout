# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.NFTHelper do
  @moduledoc """
    Module with functions for NFT view
  """
  alias Explorer.Token.MetadataRetriever

  def get_media_src(nil, _), do: nil

  # credo:disable-for-next-line /Complexity/
  def get_media_src(metadata, high_quality_media?) do
    result =
      cond do
        metadata["animation_url"] && high_quality_media? ->
          retrieve_image(metadata["animation_url"])

        metadata["image_url"] ->
          retrieve_image(metadata["image_url"])

        metadata["image"] ->
          retrieve_image(metadata["image"])

        image = is_map(metadata["properties"]) && metadata["properties"]["image"] ->
          if is_map(image), do: image["description"], else: image

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
    |> URI.decode()
    |> URI.encode()
    |> compose_resource_url()
  end

  @doc """
  Composes a full gateway URL from the given resource URL.

  Supports IPFS (`ipfs://`), Arweave (`ar://`), and Swarm (`bzz://`) resource
  URLs, resolving them against the corresponding configured gateway. Any other
  URL is returned unchanged.

  ## Parameters

    - image_url: The URL of the resource to be resolved to a gateway URL. It can be nil.

  ## Returns

    - A string representing the full gateway URL, the original URL, or nil.

  ## Examples

      iex> compose_resource_url("ipfs://QmTzQ1e1Y1e1Y1e1Y1e1Y1e1Y1e1Y1e1Y1e1Y1e1Y1")
      "https://ipfs.io/ipfs/QmTzQ1e1Y1e1Y1e1Y1e1Y1e1Y1e1Y1e1Y1e1Y1e1Y1"

      iex> compose_resource_url("ar://Ah3vCrgV-9hEkA2Zl4Yq0iL5wGuMD5-Zr9EAF9zjHDU")
      "https://arweave.net/Ah3vCrgV-9hEkA2Zl4Yq0iL5wGuMD5-Zr9EAF9zjHDU"

      iex> compose_resource_url("bzz://swarm-devrel.eth/assets/swarm-logo.svg")
      "https://gateway.ethswarm.org/bzz/swarm-devrel.eth/assets/swarm-logo.svg"

  """
  @spec compose_resource_url(String.t() | nil) :: String.t() | nil
  def compose_resource_url(nil), do: nil

  def compose_resource_url(image_url) do
    image_url_downcase =
      image_url
      |> String.downcase()

    cond do
      image_url_downcase =~ ~r/^ipfs:\/\/ipfs/ ->
        # take resource id after "ipfs://ipfs/" prefix
        resource_id = image_url |> String.slice(12..-1//1)
        MetadataRetriever.ipfs_link(resource_id, true)

      image_url_downcase =~ ~r/^ipfs:\/\// ->
        # take resource id after "ipfs://" prefix
        resource_id = image_url |> String.slice(7..-1//1)
        MetadataRetriever.ipfs_link(resource_id, true)

      image_url_downcase =~ ~r/^ar:\/\// ->
        # take resource id after "ar://" prefix
        resource_id = image_url |> String.slice(5..-1//1)
        MetadataRetriever.arweave_link(resource_id)

      image_url_downcase =~ ~r/^bzz:\/\// ->
        # take resource id after "bzz://" prefix
        resource_id = image_url |> String.slice(6..-1//1)
        MetadataRetriever.swarm_link(resource_id)

      true ->
        image_url
    end
  end
end
