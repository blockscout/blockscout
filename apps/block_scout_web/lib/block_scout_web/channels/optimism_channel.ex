defmodule BlockScoutWeb.OptimismChannel do
  @moduledoc """
  Establishes pub/sub channel for live updates of OP related events.
  """
  use BlockScoutWeb, :channel

  def join("optimism:new_batch", _params, socket) do
    {:ok, %{}, socket}
  end

  def join("optimism:new_deposits", _params, socket) do
    {:ok, %{}, socket}
  end
end
