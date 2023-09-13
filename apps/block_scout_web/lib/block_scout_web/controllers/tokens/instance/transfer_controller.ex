defmodule BlockScoutWeb.Tokens.Instance.TransferController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.Tokens.Instance.Helper
  alias BlockScoutWeb.Tokens.TransferView
  alias Explorer.Chain
  alias Explorer.Chain.Address
  alias Phoenix.View

  import BlockScoutWeb.Chain, only: [split_list_by_page: 1, paging_options: 1, next_page_params: 3]
  import Explorer.Chain.SmartContract, only: [burn_address_hash_string: 0]

  {:ok, burn_address_hash} = Chain.string_to_address_hash(burn_address_hash_string())
  @burn_address_hash burn_address_hash

  def index(conn, %{"token_id" => token_address_hash, "instance_id" => token_id_str, "type" => "JSON"} = params) do
    with {:ok, hash} <- Chain.string_to_address_hash(token_address_hash),
         {:ok, token} <- Chain.token_from_address_hash(hash),
         false <- Chain.is_erc_20_token?(token),
         {token_id, ""} <- Integer.parse(token_id_str),
         token_transfers <-
           Chain.fetch_token_transfers_from_token_hash_and_token_id(hash, token_id, paging_options(params)) do
      {token_transfers_paginated, next_page} = split_list_by_page(token_transfers)

      next_page_path =
        case next_page_params(next_page, token_transfers_paginated, params) do
          nil ->
            nil

          next_page_params ->
            token_instance_transfer_path(
              conn,
              :index,
              Address.checksum(token.contract_address_hash),
              token_id,
              Map.delete(next_page_params, "type")
            )
        end

      transfers_json =
        Enum.map(token_transfers_paginated, fn transfer ->
          View.render_to_string(
            TransferView,
            "_token_transfer.html",
            conn: conn,
            token: token,
            token_transfer: transfer,
            burn_address_hash: @burn_address_hash
          )
        end)

      json(conn, %{items: transfers_json, next_page_path: next_page_path})
    else
      _ ->
        not_found(conn)
    end
  end

  def index(conn, %{"token_id" => token_address_hash, "instance_id" => token_id_str}) do
    options = [necessity_by_association: %{[contract_address: :smart_contract] => :optional}]

    with {:ok, hash} <- Chain.string_to_address_hash(token_address_hash),
         {:ok, token} <- Chain.token_from_address_hash(hash, options),
         false <- Chain.is_erc_20_token?(token),
         {token_id, ""} <- Integer.parse(token_id_str) do
      case Chain.erc721_or_erc1155_token_instance_from_token_id_and_token_address(token_id, hash) do
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
