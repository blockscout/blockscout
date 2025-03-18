defmodule BlockScoutWeb.V2.RewardChannel do
  @moduledoc """
  Establishes pub/sub channel for live updates of block reward events for API V2.
  """
  use BlockScoutWeb, :channel

  def join("rewards:" <> _address_hash_string, _params, socket) do
    {:ok, %{}, socket}
  end
end
