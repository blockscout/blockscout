defmodule BlockScoutWeb.RewardChannelV2 do
  @moduledoc """
  Establishes pub/sub channel for live updates of block reward events.
  """
  use BlockScoutWeb, :channel

  def join("rewards:" <> _address_hash_string, _params, socket) do
    {:ok, %{}, socket}
  end
end
