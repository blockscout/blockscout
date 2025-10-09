defmodule BlockScoutWeb.Tokens.Instance.HolderController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.Tokens.HolderView
  alias BlockScoutWeb.Tokens.Instance.Helper
  alias Explorer.Chain
  alias Explorer.Chain.Address
  alias Explorer.Chain.Token.Instance
  alias Phoenix.View

  import BlockScoutWeb.Chain, only: [split_list_by_page: 1, paging_options: 1, next_page_params: 3]

  def index(conn, %{"token_id" => token_address_hash, "instance_id" => token_id_string, "type" => "JSON"} = params) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(token_address_hash),
         {:ok, token} <- Chain.token_from_address_hash(address_hash),
         false <- Chain.erc_20_token?(token),
         {token_id, ""} <- Integer.parse(token_id_string),
         token_holders <-
           Chain.fetch_token_holders_from_token_hash_and_token_id(address_hash, token_id, paging_options(params)) do
      {token_holders_paginated, next_page} = split_list_by_page(token_holders)

      next_page_path =
        case next_page_params(next_page, token_holders_paginated, params) do
          nil ->
            nil

          next_page_params ->
            token_instance_holder_path(
              conn,
              :index,
              Address.checksum(token.contract_address_hash),
              token_id,
              Map.delete(next_page_params, "type")
            )
        end

      holders_json =
        token_holders_paginated
        |> Enum.sort_by(& &1.value, &>=/2)
        |> Enum.map(fn current_token_balance ->
          View.render_to_string(
            HolderView,
            "_token_balances.html",
            address_hash: address_hash,
            token_balance: current_token_balance,
            token: token
          )
        end)

      json(conn, %{items: holders_json, next_page_path: next_page_path})
    else
      _ ->
        not_found(conn)
    end
  end

  def index(conn, %{"token_id" => token_address_hash, "instance_id" => token_id_string}) do
    options = [necessity_by_association: %{[contract_address: :smart_contract] => :optional}]

    with {:ok, hash} <- Chain.string_to_address_hash(token_address_hash),
         {:ok, token} <- Chain.token_from_address_hash(hash, options),
         false <- Chain.erc_20_token?(token),
         {token_id, ""} <- Integer.parse(token_id_string) do
      case Instance.nft_instance_by_token_id_and_token_address(token_id, hash) do
        {:ok, token_instance} -> Helper.render(conn, token_instance, hash, token_id, token)
        {:error, :not_found} -> Helper.render(conn, nil, hash, token_id, token)
      end
    else
      _ ->
        not_found(conn)
    end
  end

  def index(conn, _) do
    not_found(conn)
  end
end
