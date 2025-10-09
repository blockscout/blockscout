defmodule BlockScoutWeb.V2.PolygonZkevmConfirmedBatchChannel do
  @moduledoc """
  Establishes pub/sub channel for live updates of zkEVM confirmed batch events for API V2.
  """
  use BlockScoutWeb, :channel

  def join("zkevm_batches:new_zkevm_confirmed_batch", _params, socket) do
    {:ok, %{}, socket}
  end
end
