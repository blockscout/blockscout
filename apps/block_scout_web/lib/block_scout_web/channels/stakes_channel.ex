defmodule BlockScoutWeb.StakesChannel do
  @moduledoc """
  Establishes pub/sub channel for staking page live updates.
  """
  use BlockScoutWeb, :channel

  alias BlockScoutWeb.StakesController

  intercept(["staking_update"])

  def join("stakes:staking_update", _params, socket) do
    {:ok, %{}, socket}
  end

  def handle_out("staking_update", _data, socket) do
    push(socket, "staking_update", %{
      top_html: StakesController.render_top()
    })

    {:noreply, socket}
  end
end
