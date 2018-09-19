defmodule BlockScoutWeb.AddressTokenTransferController do
  use BlockScoutWeb, :controller

  alias Explorer.{Chain, Market}
  alias Explorer.ExchangeRates.Token

  import BlockScoutWeb.AddressController, only: [transaction_count: 1]

  import BlockScoutWeb.Chain,
    only: [next_page_params: 3, paging_options: 1, split_list_by_page: 1]

  def index(
        conn,
        %{"address_id" => address_hash_string, "address_token_id" => token_hash_string} = params
      ) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, token_hash} <- Chain.string_to_address_hash(token_hash_string),
         {:ok, address} <- Chain.hash_to_address(address_hash),
         {:ok, token} <- Chain.token_from_address_hash(token_hash) do
      transactions =
        Chain.address_to_transactions_with_token_tranfers(
          address_hash,
          token_hash,
          paging_options(params)
        )

      {transactions_paginated, next_page} = split_list_by_page(transactions)

      render(
        conn,
        "index.html",
        address: address,
        exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null(),
        next_page_params: next_page_params(next_page, transactions_paginated, params),
        token: token,
        transaction_count: transaction_count(address),
        transactions: transactions_paginated
      )
    else
      :error ->
        unprocessable_entity(conn)

      {:error, :not_found} ->
        not_found(conn)
    end
  end
end
