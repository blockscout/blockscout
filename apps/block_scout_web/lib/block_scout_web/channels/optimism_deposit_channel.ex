defmodule BlockScoutWeb.OptimismDepositChannel do
  @moduledoc """
  Establishes pub/sub channel for live updates of Optimism deposit events.
  """
  use BlockScoutWeb, :channel

  intercept(["deposit"])

  def join("optimism_deposits:new_deposit", _params, socket) do
    {:ok, %{}, socket}
  end

  def handle_out(
        "deposit",
        %{deposit: _deposit},
        %Phoenix.Socket{handler: BlockScoutWeb.UserSocketV2} = socket
      ) do
    push(socket, "deposit", %{deposit: 1})

    {:noreply, socket}
  end
end
