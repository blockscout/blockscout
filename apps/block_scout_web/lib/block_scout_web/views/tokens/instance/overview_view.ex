defmodule BlockScoutWeb.Tokens.Instance.OverviewView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.{CurrencyHelper, NFTHelper}
  alias Explorer.Chain
  alias Explorer.Chain.{Address, SmartContract, Token}
  alias Explorer.SmartContract.Helper

  import BlockScoutWeb.APIDocsView, only: [blockscout_url: 1]
  import BlockScoutWeb.NFTHelper, only: [external_url: 1]

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
    NFTHelper.get_media_src(instance.metadata, high_quality_media?) || media_src(nil)
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
        process_missing_extension(media_src)
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

  defp process_missing_extension(media_src) do
    case HTTPoison.head(media_src, [], follow_redirect: true) do
      {:ok, %HTTPoison.Response{status_code: 200, headers: headers}} ->
        headers_map = Map.new(headers, fn {key, value} -> {String.downcase(key), value} end)
        headers_map["content-type"]

      _ ->
        nil
    end
  end

  def total_supply_usd(token) do
    tokens = CurrencyHelper.divide_decimals(token.total_supply, token.decimals)
    price = token.fiat_value
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

    url_prefix = blockscout_url(false)

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

  defp tab_name(["token-transfers"]), do: gettext("Token Transfers")
  defp tab_name(["metadata"]), do: gettext("Metadata")
end
