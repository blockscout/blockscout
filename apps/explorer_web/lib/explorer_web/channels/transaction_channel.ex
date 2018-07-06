defmodule ExplorerWeb.TransactionChannel do
  @moduledoc """
  Establishes pub/sub channel for transaction page live updates.
  """
  use ExplorerWeb, :channel

  def join("transactions:" <> _transaction_hash, _params, socket) do
    {:ok, %{}, socket}
  end
end
