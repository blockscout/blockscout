defmodule BlockScoutWeb.PolygonZkevmConfirmedBatchChannel do
  @moduledoc """
  Establishes pub/sub channel for live updates of zkEVM confirmed batch events.
  """
  use BlockScoutWeb, :channel

  def join("zkevm_batches:new_zkevm_confirmed_batch", _params, socket) do
    {:ok, %{}, socket}
  end
end
