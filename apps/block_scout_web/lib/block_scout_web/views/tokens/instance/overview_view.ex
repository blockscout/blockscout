defmodule BlockScoutWeb.Tokens.Instance.OverviewView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.CurrencyHelpers
  alias Explorer.Chain.{Address, SmartContract, Token}
  alias Explorer.SmartContract.Helper
  alias FileInfo
  alias MIME
  alias Path

  import BlockScoutWeb.APIDocsView, only: [blockscout_url: 1, blockscout_url: 2]

  @tabs ["token-transfers", "metadata"]

  def token_name?(%Token{name: nil}), do: false
  def token_name?(%Token{name: _}), do: true

  def decimals?(%Token{decimals: nil}), do: false
  def decimals?(%Token{decimals: _}), do: true

  def total_supply?(%Token{total_supply: nil}), do: false
  def total_supply?(%Token{total_supply: _}), do: true

  def media_src(nil), do: "/images/controller.svg"

  def media_src(instance) do
    result =
      cond do
        instance.metadata && instance.metadata["image_url"] ->
          retrieve_image(instance.metadata["image_url"])

        instance.metadata && instance.metadata["image"] ->
          retrieve_image(instance.metadata["image"])

        instance.metadata && instance.metadata["properties"]["image"]["description"] ->
          instance.metadata["properties"]["image"]["description"]

        true ->
          media_src(nil)
      end

    if String.trim(result) == "", do: media_src(nil), else: result
  end

  def media_type(media_src) when not is_nil(media_src) do
    ext = media_src |> Path.extname() |> String.trim()

    mime_type =
      if ext == "" do
        case HTTPoison.get(media_src) do
          {:ok, %HTTPoison.Response{body: body, status_code: 200}} ->
            {:ok, path} = Briefly.create()

            File.write!(path, body)

            case FileInfo.get_info([path]) do
              %{^path => %FileInfo.Mime{subtype: subtype}} ->
                subtype
                |> MIME.type()

              _ ->
                nil
            end

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
    Enum.any?(token.contract_address.smart_contract.abi, &Helper.queriable_method?(&1))
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

  defp retrieve_image(image) when is_map(image) do
    image["description"]
  end

  defp retrieve_image(image_url) do
    image_url
    |> URI.encode()
    |> compose_ipfs_url()
  end

  defp compose_ipfs_url(image_url) do
    cond do
      image_url =~ "ipfs://ipfs" ->
        "ipfs://ipfs" <> ipfs_uid = image_url
        "https://ipfs.io/ipfs/" <> ipfs_uid

      image_url =~ "ipfs://" ->
        "ipfs://" <> ipfs_uid = image_url
        "https://ipfs.io/ipfs/" <> ipfs_uid

      true ->
        image_url
    end
  end

  defp tab_name(["token-transfers"]), do: gettext("Token Transfers")
  defp tab_name(["metadata"]), do: gettext("Metadata")
end
