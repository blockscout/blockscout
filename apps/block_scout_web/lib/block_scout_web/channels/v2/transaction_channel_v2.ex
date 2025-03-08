defmodule BlockScoutWeb.TransactionChannelV2 do
  @moduledoc """
  Establishes pub/sub channel for live updates of transaction events.
  """
  use BlockScoutWeb, :channel

  def join("transactions:new_transaction", _params, socket) do
    {:ok, %{}, socket}
  end

  def join("transactions:new_pending_transaction", _params, socket) do
    {:ok, %{}, socket}
  end

  def join("transactions:stats", _params, socket) do
    {:ok, %{}, socket}
  end

  def join("transactions:" <> _transaction_hash, _params, socket) do
    {:ok, %{}, socket}
  end
end
