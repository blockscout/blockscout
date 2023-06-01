defmodule BlockScoutWeb.Tokens.Instance.OverviewView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.CurrencyHelpers
  alias Explorer.Chain
  alias Explorer.Chain.{Address, SmartContract, Token}
  alias Explorer.SmartContract.Helper
  alias FileInfo
  alias MIME
  alias Path

  import BlockScoutWeb.APIDocsView, only: [blockscout_url: 1, blockscout_url: 2]

  @tabs ["token-transfers", "metadata"]
  @stub_image "/images/controller.svg"

  def token_name?(%Token{name: nil}), do: false
  def token_name?(%Token{name: _}), do: true

  def decimals?(%Token{decimals: nil}), do: false
  def decimals?(%Token{decimals: _}), do: true

  def total_supply?(%Token{total_supply: nil}), do: false
  def total_supply?(%Token{total_supply: _}), do: true

  def media_src(instance, high_quality_media? \\ nil)
  def media_src(nil, _), do: @stub_image

  def media_src(instance, high_quality_media?) do
    result = get_media_src(instance.metadata, high_quality_media?)

    if String.trim(result) == "", do: media_src(nil), else: result
  end

  defp get_media_src(nil, _), do: media_src(nil)

  defp get_media_src(metadata, high_quality_media?) do
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
        media_src(nil)
    end
  end

  def media_type("data:image/" <> _data) do
    "image"
  end

  def media_type("data:video/" <> _data) do
    "video"
  end

  def media_type("data:" <> _data) do
    nil
  end

  def media_type(media_src) when not is_nil(media_src) do
    ext = media_src |> Path.extname() |> String.trim()

    mime_type =
      if ext == "" do
        case HTTPoison.head(media_src, [], follow_redirect: true) do
          {:ok, %HTTPoison.Response{status_code: 200, headers: headers}} ->
            headers_map = Map.new(headers, fn {key, value} -> {String.downcase(key), value} end)
            headers_map["content-type"]

          _ ->
            nil
        end
      else
        ext_with_dot =
          media_src
          |> Path.extname()

        "." <> ext = ext_with_dot

        ext
        |> MIME.type()
      end

    if mime_type do
      basic_mime_type = mime_type |> String.split("/") |> Enum.at(0)

      basic_mime_type
    else
      nil
    end
  end

  def media_type(nil), do: nil

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

  def total_supply_usd(token) do
    tokens = CurrencyHelpers.divide_decimals(token.total_supply, token.decimals)
    price = token.usd_value
    Decimal.mult(tokens, price)
  end

  def smart_contract_with_read_only_functions?(
        %Token{contract_address: %Address{smart_contract: %SmartContract{}}} = token
      ) do
    Enum.any?(token.contract_address.smart_contract.abi || [], &Helper.queriable_method?(&1))
  end

  def smart_contract_with_read_only_functions?(%Token{contract_address: %Address{smart_contract: nil}}), do: false

  def qr_code(conn, token_id, hash) do
    token_instance_path = token_instance_path(conn, :show, to_string(hash), to_string(token_id))

    url_params = Application.get_env(:block_scout_web, BlockScoutWeb.Endpoint)[:url]
    api_path = url_params[:api_path]
    path = url_params[:path]

    url_prefix =
      if String.length(path) > 0 && path != "/" do
        set_path = false
        blockscout_url(set_path)
      else
        if String.length(api_path) > 0 && api_path != "/" do
          is_api = true
          set_path = true
          blockscout_url(set_path, is_api)
        else
          set_path = false
          blockscout_url(set_path)
        end
      end

    url = Path.join(url_prefix, token_instance_path)

    url
    |> QRCode.to_png()
    |> Base.encode64()
  end

  def current_tab_name(request_path) do
    @tabs
    |> Enum.filter(&tab_active?(&1, request_path))
    |> tab_name()
  end

  defp retrieve_image(image) when is_nil(image), do: @stub_image

  defp retrieve_image(image) when is_map(image) do
    image["description"]
  end

  defp retrieve_image(image) when is_list(image) do
    image_url = image |> Enum.at(0)
    retrieve_image(image_url)
  end

  defp retrieve_image(image_url) do
    image_url
    |> URI.encode()
    |> compose_ipfs_url()
  end

  defp compose_ipfs_url(image_url) do
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

  defp tab_name(["token-transfers"]), do: gettext("Token Transfers")
  defp tab_name(["metadata"]), do: gettext("Metadata")
end
