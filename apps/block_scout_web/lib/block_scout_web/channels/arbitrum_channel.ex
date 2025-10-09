defmodule BlockScoutWeb.ArbitrumChannel do
  @moduledoc """
  Establishes pub/sub channel for live updates of Arbitrum related events.
  """
  use BlockScoutWeb, :channel

  def join("arbitrum:new_batch", _params, socket) do
    {:ok, %{}, socket}
  end

  def join("arbitrum:new_messages_to_rollup_amount", _params, socket) do
    {:ok, %{}, socket}
  end
end
