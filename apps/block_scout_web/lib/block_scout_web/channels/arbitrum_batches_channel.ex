defmodule BlockScoutWeb.ArbitrumBatchesChannel do
  @moduledoc """
  Establishes pub/sub channel for live updates of new Arbitrum batch events.
  """
  use BlockScoutWeb, :channel

  alias BlockScoutWeb.API.V2.ArbitrumView

  intercept(["new_arbitrum_batch"])

  def join("arbitrum_batches:new_arbitrum_batch", _params, socket) do
    {:ok, %{}, socket}
  end

  def handle_out(
        "new_arbitrum_batch",
        %{batch: batch},
        %Phoenix.Socket{handler: BlockScoutWeb.UserSocketV2} = socket
      ) do
    rendered_batches = ArbitrumView.render("arbitrum_batches.json", %{batches: [batch], socket: nil})

    push(socket, "new_arbitrum_batch", %{
      batch: List.first(rendered_batches.items)
    })

    {:noreply, socket}
  end
end
