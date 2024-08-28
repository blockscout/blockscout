defmodule BlockScoutWeb.API.V2.ScrollController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain,
    only: [
      next_page_params: 3,
      paging_options: 1,
      split_list_by_page: 1
    ]

  alias Explorer.Chain.Scroll.Reader

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  @doc """
    Function to handle GET requests to `/api/v2/scroll/deposits` endpoint.
  """
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
    |> render(:scroll_bridge_items, %{
      items: deposits,
      next_page_params: next_page_params
    })
  end

  @doc """
    Function to handle GET requests to `/api/v2/scroll/deposits/count` endpoint.
  """
  @spec deposits_count(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def deposits_count(conn, _params) do
    count = Reader.deposits_count(api?: true)

    conn
    |> put_status(200)
    |> render(:scroll_bridge_items_count, %{count: count})
  end

  @doc """
    Function to handle GET requests to `/api/v2/scroll/withdrawals` endpoint.
  """
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
    |> render(:scroll_bridge_items, %{
      items: withdrawals,
      next_page_params: next_page_params
    })
  end

  @doc """
    Function to handle GET requests to `/api/v2/scroll/withdrawals/count` endpoint.
  """
  @spec withdrawals_count(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def withdrawals_count(conn, _params) do
    count = Reader.withdrawals_count(api?: true)

    conn
    |> put_status(200)
    |> render(:scroll_bridge_items_count, %{count: count})
  end
end
