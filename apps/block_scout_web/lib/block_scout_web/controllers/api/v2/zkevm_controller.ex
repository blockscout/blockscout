defmodule BlockScoutWeb.API.V2.ZkevmController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain,
    only: [
      next_page_params: 3,
      paging_options: 1,
      split_list_by_page: 1
    ]

  alias Explorer.Chain

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  @batch_necessity_by_association %{
    :sequence_transaction => :optional,
    :verify_transaction => :optional,
    :l2_transactions => :required
  }

  @batches_necessity_by_association %{
    :sequence_transaction => :optional
  }

  def batch(conn, %{"batch_number" => batch_number} = _params) do
    {:ok, batch} =
      Chain.zkevm_batch(
        batch_number,
        necessity_by_association: @batch_necessity_by_association,
        api?: true
      )

    conn
    |> put_status(200)
    |> render(:zkevm_batch, %{batch: batch})
  end

  def batch_latest_number(conn, _params) do
    conn
    |> put_status(200)
    |> render(:zkevm_batch_latest_number, %{number: batch_latest_number()})
  end

  def batches(conn, params) do
    {batches, next_page} =
      params
      |> paging_options()
      |> Keyword.put(:necessity_by_association, @batches_necessity_by_association)
      |> Keyword.put(:api?, true)
      |> Chain.zkevm_batches()
      |> split_list_by_page()

    next_page_params = next_page_params(next_page, batches, params)

    conn
    |> put_status(200)
    |> render(:zkevm_batches, %{
      batches: batches,
      next_page_params: next_page_params
    })
  end

  def batches_count(conn, _params) do
    conn
    |> put_status(200)
    |> render(:zkevm_batches_count, %{count: batch_latest_number()})
  end

  def batches_confirmed(conn, _params) do
    batches =
      []
      |> Keyword.put(:necessity_by_association, @batches_necessity_by_association)
      |> Keyword.put(:api?, true)
      |> Keyword.put(:confirmed?, true)
      |> Chain.zkevm_batches()

    conn
    |> put_status(200)
    |> render(:zkevm_batches, %{batches: batches})
  end

  defp batch_latest_number do
    case Chain.zkevm_batch(:latest, api?: true) do
      {:ok, batch} -> batch.number
      {:error, :not_found} -> 0
    end
  end
end
