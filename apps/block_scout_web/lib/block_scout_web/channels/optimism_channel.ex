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

  # todo: the `optimism_deposits:new_deposits` socket topic is for backward compatibility
  # for the frontend and should be removed after the frontend starts to use the `optimism:new_deposits`
  def join("optimism_deposits:new_deposits", _params, socket) do
    {:ok, %{}, socket}
  end
end
