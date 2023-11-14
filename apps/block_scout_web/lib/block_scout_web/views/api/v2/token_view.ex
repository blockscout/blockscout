defmodule BlockScoutWeb.API.V2.TokenView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.V2.Helper
  alias BlockScoutWeb.NFTHelper
  alias Ecto.Association.NotLoaded
  alias Explorer.Chain
  alias Explorer.Chain.Address
  alias Explorer.Chain.Address.CurrentTokenBalance
  alias Explorer.Chain.Token.Instance

  @api_true [api?: true]

  def render("token.json", %{token: nil, contract_address_hash: contract_address_hash}) do
    %{
      "address" => Address.checksum(contract_address_hash),
      "symbol" => nil,
      "name" => nil,
      "decimals" => nil,
      "type" => nil,
      "holders" => nil,
      "exchange_rate" => nil,
      "total_supply" => nil,
      "icon_url" => nil,
      "circulating_market_cap" => nil
    }
  end

  def render("token.json", %{token: nil}) do
    nil
  end

  def render("token.json", %{token: token}) do
    %{
      "address" => Address.checksum(token.contract_address_hash),
      "symbol" => token.symbol,
      "name" => token.name,
      "decimals" => token.decimals,
      "type" => token.type,
      "holders" => prepare_holders_count(token.holder_count),
      "exchange_rate" => exchange_rate(token),
      "total_supply" => token.total_supply,
      "icon_url" => token.icon_url,
      "circulating_market_cap" => token.circulating_market_cap
    }
  end

  def render("token_balances.json", %{
        token_balances: token_balances,
        next_page_params: next_page_params,
        token: token
      }) do
    %{
      "items" => Enum.map(token_balances, &prepare_token_balance(&1, token)),
      "next_page_params" => next_page_params
    }
  end

  def render("token_instance.json", %{token_instance: token_instance, token: token}) do
    prepare_token_instance(token_instance, token)
  end

  def render("tokens.json", %{tokens: tokens, next_page_params: next_page_params}) do
    %{"items" => Enum.map(tokens, &render("token.json", %{token: &1})), "next_page_params" => next_page_params}
  end

  def render("token_instances.json", %{
        token_instances: token_instances,
        next_page_params: next_page_params,
        token: token
      }) do
    %{
      "items" => Enum.map(token_instances, &render("token_instance.json", %{token_instance: &1, token: token})),
      "next_page_params" => next_page_params
    }
  end

  def exchange_rate(%{fiat_value: fiat_value}) when not is_nil(fiat_value), do: to_string(fiat_value)
  def exchange_rate(_), do: nil

  def prepare_token_balance(token_balance, token) do
    %{
      "address" => Helper.address_with_info(nil, token_balance.address, token_balance.address_hash, false),
      "value" => token_balance.value,
      "token_id" => token_balance.token_id,
      "token" => render("token.json", %{token: token})
    }
  end

  @doc """
    Internal json rendering function
  """
  def prepare_token_instance(instance, token, need_uniqueness_and_owner? \\ true) do
    is_unique = is_unique?(need_uniqueness_and_owner?, instance, token)

    %{
      "id" => instance.token_id,
      "metadata" => instance.metadata,
      "owner" => token_instance_owner(is_unique, instance),
      "token" => render("token.json", %{token: token}),
      "external_app_url" => NFTHelper.external_url(instance),
      "animation_url" => instance.metadata && NFTHelper.retrieve_image(instance.metadata["animation_url"]),
      "image_url" => instance.metadata && NFTHelper.get_media_src(instance.metadata, false),
      "is_unique" => is_unique
    }
  end

  defp token_instance_owner(false, _instance), do: nil
  defp token_instance_owner(nil, _instance), do: nil

  defp token_instance_owner(_is_unique, %Instance{owner: %NotLoaded{}} = instance),
    do: Helper.address_with_info(nil, nil, instance.owner_address_hash, false)

  defp token_instance_owner(_is_unique, %Instance{owner: nil} = instance),
    do: Helper.address_with_info(nil, nil, instance.owner_address_hash, false)

  defp token_instance_owner(_is_unique, instance),
    do: instance.owner && Helper.address_with_info(nil, instance.owner, instance.owner.hash, false)

  defp is_unique?(false, _instance, _token), do: nil

  defp is_unique?(
         not_ignore?,
         %Instance{current_token_balance: %CurrentTokenBalance{value: %Decimal{} = value}} = instance,
         token
       ) do
    if Decimal.compare(value, 1) == :gt do
      false
    else
      is_unique?(not_ignore?, %Instance{instance | current_token_balance: nil}, token)
    end
  end

  defp is_unique?(_not_ignore?, %Instance{current_token_balance: %CurrentTokenBalance{value: value}}, _token)
       when value > 1,
       do: false

  defp is_unique?(_, instance, token),
    do:
      not (token.type == "ERC-1155") or
        Chain.token_id_1155_is_unique?(token.contract_address_hash, instance.token_id, @api_true)

  defp prepare_holders_count(nil), do: nil
  defp prepare_holders_count(count) when count < 0, do: prepare_holders_count(0)
  defp prepare_holders_count(count), do: to_string(count)
end
