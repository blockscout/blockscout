defmodule BlockScoutWeb.VerifiedContractsController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain,
    only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1, fetch_page_number: 1]


  alias BlockScoutWeb.{Controller, VerifiedContractsView}
  alias Explorer.{Chain, Market}
  alias Explorer.ExchangeRates.Token
  alias Phoenix.View

  @necessity_by_association %{[address: :token] => :required}

  def index(conn, %{"type" => "JSON"} = params) do
    full_options =
      [necessity_by_association: @necessity_by_association]
      |> Keyword.merge(paging_options(params))
      |> Keyword.merge(current_filter(params))
      |> Keyword.merge(search_query(params))
      |> IO.inspect(label: "options")

    verified_contracts_plus_one = Chain.verified_contracts(full_options)
    {verified_contracts, next_page} = split_list_by_page(verified_contracts_plus_one)

    items =
      for contract <- verified_contracts do
        token =
          if contract.address.token,
            do: Market.get_exchange_rate(contract.address.token.symbol),
            else: Token.null()

        View.render_to_string(VerifiedContractsView, "_contract.html",
          contract: contract,
          token: token
        )
      end

    next_page_path =
      case next_page_params(next_page, verified_contracts, params) do
        nil -> nil
        next_page_params -> verified_contracts_path(conn, :index, Map.delete(next_page_params, "type"))
      end

    json(conn, %{items: items, next_page_path: next_page_path})
  end

  def index(conn, params) do
    render(conn, "index.html",
      current_path: Controller.current_full_path(conn),
      filter: params["filter"]
    )
  end

  defp current_filter(%{"filter" => "solidity"}) do
    [filter: :solidity]
  end

  defp current_filter(%{"filter" => "vyper"}) do
    [filter: :vyper]
  end

  defp current_filter(_), do: []

  defp search_query(%{"search" => ""}), do: []

  defp search_query(%{"search" => search_string}) do
    [search: search_string]
  end

  defp search_query(_), do: []
end
