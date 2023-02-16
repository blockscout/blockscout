defmodule BlockScoutWeb.API.V2.TokenView do
  alias BlockScoutWeb.API.V2.Helper
  alias BlockScoutWeb.NFTHelpers
  alias Explorer.Chain
  alias Explorer.Chain.Address

  @api_true [api?: true]

  def render("token.json", %{token: token}) do
    %{
      "address" => Address.checksum(token.contract_address_hash),
      "symbol" => token.symbol,
      "name" => token.name,
      "decimals" => token.decimals,
      "type" => token.type,
      "holders" => token.holder_count && to_string(token.holder_count),
      "exchange_rate" => exchange_rate(token),
      "total_supply" => token.total_supply
    }
  end

  def render("token_balances.json", %{
        token_balances: token_balances,
        next_page_params: next_page_params,
        conn: conn,
        token: token
      }) do
    %{
      "items" => Enum.map(token_balances, &prepare_token_balance(&1, conn, token)),
      "next_page_params" => next_page_params
    }
  end

  def render("token_instance.json", %{token_instance: token_instance, conn: conn, token: token}) do
    prepare_token_instance(token_instance, token, conn)
  end

  def render("tokens.json", %{tokens: tokens, next_page_params: next_page_params}) do
    %{"items" => Enum.map(tokens, &render("token.json", %{token: &1})), "next_page_params" => next_page_params}
  end

  def render("token_instances.json", %{
        token_instances: token_instances,
        next_page_params: next_page_params,
        conn: conn,
        token: token
      }) do
    %{
      "items" =>
        Enum.map(token_instances, &render("token_instance.json", %{token_instance: &1, conn: conn, token: token})),
      "next_page_params" => next_page_params
    }
  end

  def exchange_rate(%{fiat_value: fiat_value}) when not is_nil(fiat_value), do: to_string(fiat_value)
  def exchange_rate(_), do: nil

  def prepare_token_balance(token_balance, conn, token) do
    %{
      "address" => Helper.address_with_info(conn, token_balance.address, token_balance.address_hash),
      "value" => token_balance.value,
      "token_id" => token_balance.token_id,
      "token" => render("token.json", %{token: token})
    }
  end

  def prepare_token_instance(instance, token, conn) do
    %{
      "id" => instance.token_id,
      "metadata" => instance.metadata,
      "owner" => instance.owner && Helper.address_with_info(conn, instance.owner, instance.owner.hash),
      "token" => render("token.json", %{token: token}),
      "external_app_url" => NFTHelpers.external_url(instance),
      "animation_url" => instance.metadata && NFTHelpers.retrieve_image(instance.metadata["animation_url"]),
      "image_url" => instance.metadata && NFTHelpers.get_media_src(instance.metadata, false),
      "is_unique" =>
        not (token.type == "ERC-1155") or
          Chain.token_id_1155_is_unique?(token.contract_address_hash, instance.token_id, @api_true)
    }
  end
end
