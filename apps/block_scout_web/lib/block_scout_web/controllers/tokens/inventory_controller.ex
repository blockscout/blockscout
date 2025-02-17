defmodule BlockScoutWeb.Tokens.InventoryController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.AccessHelper
  alias BlockScoutWeb.Tokens.{HolderController, InventoryView}
  alias Explorer.Chain
  alias Explorer.Chain.Token.Instance
  alias Phoenix.View

  import BlockScoutWeb.Chain,
    only: [
      split_list_by_page: 1,
      unique_tokens_paging_options: 1,
      unique_tokens_next_page: 3
    ]

  def index(conn, %{"token_id" => address_hash_string, "type" => "JSON"} = params) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, token} <- Chain.token_from_address_hash(address_hash),
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params) do
      unique_token_instances =
        Instance.address_to_unique_tokens(
          token.contract_address_hash,
          token,
          unique_tokens_paging_options(params)
        )

      {unique_token_instances_paginated, next_page} = split_list_by_page(unique_token_instances)

      next_page_path =
        case unique_tokens_next_page(next_page, unique_token_instances_paginated, params) do
          nil ->
            nil

          next_page_params ->
            token_inventory_path(
              conn,
              :index,
              address_hash_string,
              Map.delete(next_page_params, "type")
            )
        end

      items =
        unique_token_instances_paginated
        |> Enum.map(fn instance ->
          View.render_to_string(
            InventoryView,
            "_token.html",
            instance: instance,
            token: token,
            conn: conn
          )
        end)

      json(
        conn,
        %{
          items: items,
          next_page_path: next_page_path
        }
      )
    else
      {:restricted_access, _} ->
        not_found(conn)

      :error ->
        not_found(conn)

      {:error, :not_found} ->
        not_found(conn)
    end
  end

  def index(conn, params) do
    HolderController.index(conn, params)
  end
end
