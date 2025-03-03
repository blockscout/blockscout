defmodule BlockScoutWeb.BlockChannelV2 do
  @moduledoc """
  Establishes pub/sub channel for live updates of block events.
  """
  use BlockScoutWeb, :channel

  def join("blocks:new_block", _params, socket) do
    {:ok, %{}, socket}
  end

  def join("blocks:" <> _miner_address, _params, socket) do
    {:ok, %{}, socket}
  end
end
