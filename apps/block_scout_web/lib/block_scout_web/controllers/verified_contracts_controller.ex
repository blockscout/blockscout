defmodule BlockScoutWeb.VerifiedContractsController do
  use BlockScoutWeb, :controller

  import Ecto.Query

  alias BlockScoutWeb.VerifiedContractsView
  alias Explorer.Chain.{SmartContract, SmartContractTransactionCount}
  alias Explorer.GenericPagingOptions, as: PagingOptions

  @default_page_size 50

  def index(conn, params) do
    filter = Map.get(params, "filter")
    contract_count = get_verified_contract_count(filter)

    paging_options =
      PagingOptions.extract_paging_options_from_params(
        params,
        contract_count,
        ["date", "txns", "name"],
        "desc",
        @default_page_size
      )

    contracts = get_verified_contracts(paging_options, filter, contract_count)

    render(conn, VerifiedContractsView, "index.html",
      conn: conn,
      params: Map.merge(params, paging_options),
      contracts: contracts,
      contract_count: contract_count
    )
  end

  defp get_verified_contracts(paging_options, filter, contract_count) when contract_count > 0 do
    SmartContract
    |> preload(:address)
    |> join(:left, [c], tc in SmartContractTransactionCount,
      on: c.address_hash == tc.address_hash,
      as: :transaction_count
    )
    |> select([c, tc], [c, tc])
    |> handle_filter(filter)
    |> handle_paging_options(paging_options)
    |> Explorer.Repo.all()
  end

  defp get_verified_contracts(_, _, _), do: []

  defp get_verified_contract_count(filter) do
    SmartContract
    |> handle_filter(filter)
    |> Explorer.Repo.aggregate(:count, :id)
  end

  defp handle_paging_options(query, paging_options) do
    offset = (paging_options.page_number - 1) * paging_options.page_size

    query
    |> handle_order_clause(paging_options.order_dir, paging_options.order_field)
    |> limit(^paging_options.page_size)
    |> offset(^offset)
  end

  defp handle_order_clause(query, "desc", "name"), do: query |> order_by(desc: :name)
  defp handle_order_clause(query, "asc", "name"), do: query |> order_by(asc: :name)

  defp handle_order_clause(query, "desc", "date"), do: query |> order_by(desc: :inserted_at)
  defp handle_order_clause(query, "asc", "date"), do: query |> order_by(asc: :inserted_at)

  defp handle_order_clause(query, "desc", "txns"),
    do: query |> order_by([c, ct], desc_nulls_last: ct.transaction_count)

  defp handle_order_clause(query, "asc", "txns"),
    do: query |> order_by([c, ct], asc_nulls_first: ct.transaction_count)

  defp handle_filter(query, nil), do: query
  defp handle_filter(query, filter), do: query |> where([c], ilike(c.name, ^"%#{filter}%"))
end
