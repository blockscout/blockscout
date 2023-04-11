defmodule BlockScoutWeb.API.V2.WithdrawalController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain,
    only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1]

  import BlockScoutWeb.PagingHelper, only: [delete_parameters_from_next_page_params: 1]

  alias Explorer.Chain

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  def withdrawals_list(conn, params) do
    full_options =
      [necessity_by_association: %{address: :optional, block: :optional}, api?: true]
      |> Keyword.merge(paging_options(params))

    withdrawals_plus_one = Chain.list_withdrawals(full_options)
    {withdrawals, next_page} = split_list_by_page(withdrawals_plus_one)

    next_page_params = next_page |> next_page_params(withdrawals, params) |> delete_parameters_from_next_page_params()

    conn
    |> put_status(200)
    |> render(:withdrawals, %{withdrawals: withdrawals, next_page_params: next_page_params})
  end
end
