defmodule BlockScoutWeb.API.V2.ShibariumController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain,
    only: [
      next_page_params: 3,
      paging_options: 1,
      split_list_by_page: 1
    ]

  alias Explorer.Chain.Cache.Counters.Shibarium.DepositsAndWithdrawalsCount
  alias Explorer.Chain.Shibarium.Reader

  @api_true [api?: true]

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  @spec deposits(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def deposits(conn, params) do
    {deposits, next_page} =
      params
      |> paging_options()
      |> Keyword.put(:api?, true)
      |> Reader.deposits()
      |> split_list_by_page()

    next_page_params = next_page_params(next_page, deposits, params)

    conn
    |> put_status(200)
    |> render(:shibarium_deposits, %{
      deposits: deposits,
      next_page_params: next_page_params
    })
  end

  @spec deposits_count(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def deposits_count(conn, _params) do
    count =
      case @api_true |> DepositsAndWithdrawalsCount.deposits_count() |> Decimal.to_integer() do
        0 -> Reader.deposits_count(@api_true)
        value -> value
      end

    conn
    |> put_status(200)
    |> render(:shibarium_items_count, %{count: count})
  end

  @spec withdrawals(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def withdrawals(conn, params) do
    {withdrawals, next_page} =
      params
      |> paging_options()
      |> Keyword.put(:api?, true)
      |> Reader.withdrawals()
      |> split_list_by_page()

    next_page_params = next_page_params(next_page, withdrawals, params)

    conn
    |> put_status(200)
    |> render(:shibarium_withdrawals, %{
      withdrawals: withdrawals,
      next_page_params: next_page_params
    })
  end

  @spec withdrawals_count(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def withdrawals_count(conn, _params) do
    count =
      case @api_true |> DepositsAndWithdrawalsCount.withdrawals_count() |> Decimal.to_integer() do
        0 -> Reader.withdrawals_count(@api_true)
        value -> value
      end

    conn
    |> put_status(200)
    |> render(:shibarium_items_count, %{count: count})
  end
end
