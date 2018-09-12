defmodule BlockScoutWeb.AddressController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain, only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1]

  alias Explorer.Chain
  alias Explorer.Chain.Address

  def index(conn, params) do
    full_options =
      Keyword.merge(
        [
          necessity_by_association: %{
            transactions: :optional
          }
        ],
        paging_options(params)
      )

    addresses_plus_one = []

    # addresses_plus_one = Chain.list_top_addresses(full_options)

    {addresses, next_page} = split_list_by_page(addresses_plus_one)

    render(conn, "index.html", addresses: addresses, next_page_params: next_page_params(next_page, addresses, params))
  end

  def show(conn, %{"id" => id}) do
    redirect(conn, to: address_transaction_path(conn, :index, id))
  end

  def transaction_count(%Address{} = address) do
    Chain.address_to_transaction_count_estimate(address)
  end
end
