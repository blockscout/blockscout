defmodule BlockScoutWeb.API.V2.ZkevmController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain,
    only: [
      next_page_params: 3,
      paging_options: 1,
      split_list_by_page: 1
    ]

  alias Explorer.Chain.Zkevm.Reader

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  @batch_necessity_by_association %{
    :sequence_transaction => :optional,
    :verify_transaction => :optional,
    :l2_transactions => :optional
  }

  @batches_necessity_by_association %{
    :sequence_transaction => :optional,
    :verify_transaction => :optional
  }

  @doc """
    Function to handle GET requests to `/api/v2/zkevm/batches/:batch_number` endpoint.
  """
  @spec batch(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def batch(conn, %{"batch_number" => batch_number} = _params) do
    case Reader.batch(
           batch_number,
           necessity_by_association: @batch_necessity_by_association,
           api?: true
         ) do
      {:ok, batch} ->
        conn
        |> put_status(200)
        |> render(:zkevm_batch, %{batch: batch})

      {:error, :not_found} = res ->
        res
    end
  end

  @doc """
    Function to handle GET requests to `/api/v2/main-page/zkevm/batches/latest-number` endpoint.
  """
  @spec batch_latest_number(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def batch_latest_number(conn, _params) do
    conn
    |> put_status(200)
    |> render(:zkevm_batch_latest_number, %{number: batch_latest_number()})
  end

  @doc """
    Function to handle GET requests to `/api/v2/zkevm/batches` endpoint.
  """
  @spec batches(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def batches(conn, params) do
    {batches, next_page} =
      params
      |> paging_options()
      |> Keyword.put(:necessity_by_association, @batches_necessity_by_association)
      |> Keyword.put(:api?, true)
      |> Reader.batches()
      |> split_list_by_page()

    next_page_params = next_page_params(next_page, batches, params)

    conn
    |> put_status(200)
    |> render(:zkevm_batches, %{
      batches: batches,
      next_page_params: next_page_params
    })
  end

  @doc """
    Function to handle GET requests to `/api/v2/zkevm/batches/count` endpoint.
  """
  @spec batches_count(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def batches_count(conn, _params) do
    conn
    |> put_status(200)
    |> render(:zkevm_batches_count, %{count: batch_latest_number()})
  end

  @doc """
    Function to handle GET requests to `/api/v2/main-page/zkevm/batches/confirmed` endpoint.
  """
  @spec batches_confirmed(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def batches_confirmed(conn, _params) do
    batches =
      []
      |> Keyword.put(:necessity_by_association, @batches_necessity_by_association)
      |> Keyword.put(:api?, true)
      |> Keyword.put(:confirmed?, true)
      |> Reader.batches()

    conn
    |> put_status(200)
    |> render(:zkevm_batches, %{batches: batches})
  end

  defp batch_latest_number do
    case Reader.batch(:latest, api?: true) do
      {:ok, batch} -> batch.number
      {:error, :not_found} -> 0
    end
  end
end
