defmodule BlockScoutWeb.ZkevmConfirmedBatchChannel do
  @moduledoc """
  Establishes pub/sub channel for live updates of zkEVM confirmed batch events.
  """
  use BlockScoutWeb, :channel

  alias BlockScoutWeb.API.V2.ZkevmView

  intercept(["new_zkevm_confirmed_batch"])

  def join("zkevm_batches:new_zkevm_confirmed_batch", _params, socket) do
    {:ok, %{}, socket}
  end

  def handle_out(
        "new_zkevm_confirmed_batch",
        %{batch: batch},
        %Phoenix.Socket{handler: BlockScoutWeb.UserSocketV2} = socket
      ) do
    rendered_batch = ZkevmView.render("zkevm_batch.json", %{batch: batch, socket: nil})

    push(socket, "new_zkevm_confirmed_batch", %{
      batch: rendered_batch
    })

    {:noreply, socket}
  end
end
