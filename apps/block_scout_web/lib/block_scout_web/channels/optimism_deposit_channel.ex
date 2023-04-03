defmodule BlockScoutWeb.OptimismDepositChannel do
  @moduledoc """
  Establishes pub/sub channel for live updates of Optimism deposit events.
  """
  use BlockScoutWeb, :channel

  intercept(["deposits"])

  def join("optimism_deposits:new_deposits", _params, socket) do
    {:ok, %{}, socket}
  end

  def handle_out(
        "deposits",
        %{deposits: deposits},
        %Phoenix.Socket{handler: BlockScoutWeb.UserSocketV2} = socket
      ) do
    push(socket, "deposits", %{deposits: Enum.count(deposits)})

    {:noreply, socket}
  end
end
