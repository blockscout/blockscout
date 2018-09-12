defmodule BlockScoutWeb.Tokens.TokenController do
  use BlockScoutWeb, :controller

  alias Explorer.Chain

  import BlockScoutWeb.Chain, only: [split_list_by_page: 1, paging_options: 1, next_page_params: 3]

  def show(conn, %{"id" => address_hash_string} = params) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, token} <- Chain.token_from_address_hash(address_hash),
         token_transfers <- Chain.fetch_token_transfers_from_token_hash(address_hash, paging_options(params)) do
      {token_transfers_paginated, next_page} = split_list_by_page(token_transfers)

      render(
        conn,
        "show.html",
        transfers: token_transfers_paginated,
        token: token,
        total_token_transfers: Chain.count_token_transfers_from_token_hash(address_hash),
        total_token_holders: Chain.count_token_holders_from_token_hash(address_hash),
        next_page_params: next_page_params(next_page, token_transfers_paginated, params)
      )
    else
      :error ->
        not_found(conn)

      {:error, :not_found} ->
        not_found(conn)
    end
  end
end
