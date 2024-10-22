defmodule BlockScoutWeb.API.V2.ScrollController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain,
    only: [
      next_page_params: 3,
      paging_options: 1,
      split_list_by_page: 1
    ]

  import BlockScoutWeb.PagingHelper,
    only: [
      delete_parameters_from_next_page_params: 1
    ]

  alias Explorer.Chain.Scroll.Reader

  @api_true [api?: true]

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  @batch_necessity_by_association %{:bundle => :optional}

  @doc """
    Function to handle GET requests to `/api/v2/scroll/batches/:number` endpoint.
  """
  @spec batch(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def batch(conn, %{"number" => number}) do
    {number, ""} = Integer.parse(number)

    options =
      [necessity_by_association: @batch_necessity_by_association]
      |> Keyword.merge(@api_true)

    {_, batch} = Reader.batch(number, options)

    if batch == :not_found do
      {:error, :not_found}
    else
      conn
      |> put_status(200)
      |> render(:scroll_batch, %{batch: batch})
    end
  end

  @doc """
    Function to handle GET requests to `/api/v2/scroll/batches` endpoint.
  """
  @spec batches(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def batches(conn, params) do
    {batches, next_page} =
      params
      |> paging_options()
      |> Keyword.merge(@api_true)
      |> Reader.batches()
      |> split_list_by_page()

    next_page_params = next_page_params(next_page, batches, delete_parameters_from_next_page_params(params))

    conn
    |> put_status(200)
    |> render(:scroll_batches, %{
      batches: batches,
      next_page_params: next_page_params
    })
  end

  @doc """
    Function to handle GET requests to `/api/v2/scroll/batches/count` endpoint.
  """
  @spec batches_count(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def batches_count(conn, _params) do
    conn
    |> put_status(200)
    |> render(:scroll_batches_count, %{count: batch_latest_number() + 1})
  end

  @doc """
    Function to handle GET requests to `/api/v2/scroll/deposits` endpoint.
  """
  @spec deposits(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def deposits(conn, params) do
    {deposits, next_page} =
      params
      |> paging_options()
      |> Keyword.merge(@api_true)
      |> Reader.deposits()
      |> split_list_by_page()

    next_page_params = next_page_params(next_page, deposits, params)

    conn
    |> put_status(200)
    |> render(:scroll_bridge_items, %{
      items: deposits,
      next_page_params: next_page_params,
      type: :deposits
    })
  end

  @doc """
    Function to handle GET requests to `/api/v2/scroll/deposits/count` endpoint.
  """
  @spec deposits_count(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def deposits_count(conn, _params) do
    count = Reader.deposits_count(@api_true)

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
      |> Keyword.merge(@api_true)
      |> Reader.withdrawals()
      |> split_list_by_page()

    next_page_params = next_page_params(next_page, withdrawals, params)

    conn
    |> put_status(200)
    |> render(:scroll_bridge_items, %{
      items: withdrawals,
      next_page_params: next_page_params,
      type: :withdrawals
    })
  end

  @doc """
    Function to handle GET requests to `/api/v2/scroll/withdrawals/count` endpoint.
  """
  @spec withdrawals_count(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def withdrawals_count(conn, _params) do
    count = Reader.withdrawals_count(@api_true)

    conn
    |> put_status(200)
    |> render(:scroll_bridge_items_count, %{count: count})
  end

  defp batch_latest_number do
    case Reader.batch(:latest, @api_true) do
      {:ok, batch} -> batch.number
      {:error, :not_found} -> -1
    end
  end
end
