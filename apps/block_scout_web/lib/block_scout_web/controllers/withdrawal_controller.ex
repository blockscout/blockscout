defmodule BlockScoutWeb.WithdrawalController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain,
    only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1, fetch_page_number: 1]

  alias BlockScoutWeb.{Controller, WithdrawalView}
  alias Explorer.Chain
  alias Phoenix.View

  def index(conn, %{"type" => "JSON"} = params) do
    full_options =
      [necessity_by_association: %{address: :optional, block: :optional}]
      |> Keyword.merge(paging_options(params))

    withdrawals_plus_one = Chain.list_withdrawals(full_options)
    {withdrawals, next_page} = split_list_by_page(withdrawals_plus_one)

    items =
      for withdrawal <- withdrawals do
        View.render_to_string(WithdrawalView, "_withdrawal.html", withdrawal: withdrawal)
      end

    next_page_path =
      case next_page_params(next_page, withdrawals, params) do
        nil -> nil
        next_page_params -> withdrawal_path(conn, :index, Map.delete(next_page_params, "type"))
      end

    json(conn, %{items: items, next_page_path: next_page_path})
  end

  def index(conn, params) do
    render(conn, "index.html",
      current_path: Controller.current_full_path(conn),
      page_number: params |> fetch_page_number() |> Integer.to_string()
    )
  end
end
