defmodule BlockScoutWeb.Tokens.Instance.TransferController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.Tokens.TransferView
  alias Explorer.{Chain, Market}
  alias Explorer.Chain.Address
  alias Phoenix.View

  import BlockScoutWeb.Chain, only: [split_list_by_page: 1, paging_options: 1, next_page_params: 3]

  {:ok, burn_address_hash} = Chain.string_to_address_hash("0x0000000000000000000000000000000000000000")
  @burn_address_hash burn_address_hash

  def index(conn, %{"token_id" => token_address_hash, "instance_id" => token_id, "type" => "JSON"} = params) do
    with {:ok, hash} <- Chain.string_to_address_hash(token_address_hash),
         {:ok, token} <- Chain.token_from_address_hash(hash),
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
              token_id,
              Address.checksum(token.contract_address_hash),
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

  def index(conn, %{"token_id" => token_address_hash, "instance_id" => token_id}) do
    options = [necessity_by_association: %{[contract_address: :smart_contract] => :optional}]

    with {:ok, hash} <- Chain.string_to_address_hash(token_address_hash),
         {:ok, token} <- Chain.token_from_address_hash(hash, options),
         {:ok, token_transfer} <-
           Chain.erc721_token_instance_from_token_id_and_token_address(token_id, hash) do
      render(
        conn,
        "index.html",
        token_instance: token_transfer,
        current_path: current_path(conn),
        token: Market.add_price(token),
        total_token_transfers: Chain.count_token_transfers_from_token_hash_and_token_id(hash, token_id)
      )
    else
      _ ->
        not_found(conn)
    end
  end

  def index(conn, _) do
    not_found(conn)
  end
end
