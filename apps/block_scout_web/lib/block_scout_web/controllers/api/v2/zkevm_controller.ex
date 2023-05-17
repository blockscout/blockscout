defmodule BlockScoutWeb.API.V2.ZkevmController do
  use BlockScoutWeb, :controller

  alias Explorer.Chain

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  @batch_necessity_by_association %{
    :sequence_transaction => :optional,
    :verify_transaction => :optional,
    :l2_transactions => :required
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
end
