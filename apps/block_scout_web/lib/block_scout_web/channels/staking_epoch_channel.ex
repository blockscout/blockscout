defmodule BlockScoutWeb.StakingEpochChannel do
  @moduledoc """
  Establishes pub/sub channel for staking page live updates.
  """
  use BlockScoutWeb, :channel

  intercept(["new_epoch"])

  def join("staking_epoch:new_epoch", _params, socket) do
    {:ok, %{}, socket}
  end

  def handle_out("new_epoch", data, socket) do
    push(socket, "new_epoch", data)

    {:noreply, socket}
  end
end
