defmodule BlockScoutWeb.TokenChannelV2 do
  @moduledoc """
  Establishes pub/sub channel for live updates of token transfer events.
  """
  use BlockScoutWeb, :channel

  def join("tokens:" <> _transaction_hash, _params, socket) do
    {:ok, %{}, socket}
  end
end
