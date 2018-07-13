defmodule ExplorerWeb.TransactionChannel do
  @moduledoc """
  Establishes pub/sub channel for transaction page live updates.
  """
  use ExplorerWeb, :channel

  def join("transactions:confirmations", _params, socket) do
    {:ok, %{}, socket}
  end
end
