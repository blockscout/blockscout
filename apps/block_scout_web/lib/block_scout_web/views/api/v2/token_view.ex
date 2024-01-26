defmodule BlockScoutWeb.API.V2.TokenView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.V2.Helper
  alias BlockScoutWeb.NFTHelper
  alias Ecto.Association.NotLoaded
  alias Explorer.Chain.{Address, BridgedToken}
  alias Explorer.Chain.Token.Instance

  def render("token.json", %{token: nil = token, contract_address_hash: contract_address_hash}) do
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
    |> maybe_append_bridged_info(token)
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
    |> maybe_append_bridged_info(token)
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

  def render("bridged_tokens.json", %{tokens: tokens, next_page_params: next_page_params}) do
    %{"items" => Enum.map(tokens, &render("bridged_token.json", %{token: &1})), "next_page_params" => next_page_params}
  end

  def render("bridged_token.json", %{token: {token, bridged_token}}) do
    "token.json"
    |> render(%{token: token})
    |> Map.merge(%{
      foreign_address: Address.checksum(bridged_token.foreign_token_contract_address_hash),
      bridge_type: bridged_token.type,
      origin_chain_id: bridged_token.foreign_chain_id
    })
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
  def prepare_token_instance(instance, token) do
    %{
      "id" => instance.token_id,
      "metadata" => instance.metadata,
      "owner" => token_instance_owner(instance.is_unique, instance),
      "token" => render("token.json", %{token: token}),
      "external_app_url" => NFTHelper.external_url(instance),
      "animation_url" => instance.metadata && NFTHelper.retrieve_image(instance.metadata["animation_url"]),
      "image_url" => instance.metadata && NFTHelper.get_media_src(instance.metadata, false),
      "is_unique" => instance.is_unique
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

  defp prepare_holders_count(nil), do: nil
  defp prepare_holders_count(count) when count < 0, do: prepare_holders_count(0)
  defp prepare_holders_count(count), do: to_string(count)

  defp maybe_append_bridged_info(map, token) do
    if BridgedToken.enabled?() do
      (token && Map.put(map, "is_bridged", token.bridged || false)) || map
    else
      map
    end
  end
end
