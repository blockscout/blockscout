defmodule BlockScoutWeb.AddressController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain, only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1]

  alias Explorer.{Chain, Market}
  alias Explorer.Chain.Address
  alias Explorer.ExchangeRates.Token

  def index(conn, params) do
    full_options = paging_options(params)

    addresses_plus_one = Chain.list_top_addresses(full_options)

    {addresses, next_page} = split_list_by_page(addresses_plus_one)

    render(conn, "index.html",
      addresses: addresses,
      exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null(),
      next_page_params: next_page_params(next_page, addresses, params)
    )
  end

  def show(conn, %{"id" => id}) do
    redirect(conn, to: address_transaction_path(conn, :index, id))
  end

  def transaction_count(%Address{} = address) do
    Chain.address_to_transaction_count_estimate(address)
  end
end
