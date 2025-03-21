defmodule BlockScoutWeb.V2.TokenChannel do
  @moduledoc """
  Establishes pub/sub channel for live updates of token transfer events for API V2.
  """
  use BlockScoutWeb, :channel

  def join("tokens:" <> _transaction_hash, _params, socket) do
    {:ok, %{}, socket}
  end
end
