defmodule ExplorerWeb.TransactionChannel do
  @moduledoc """
  Establishes pub/sub channel for transaction page live updates.
  """
  use ExplorerWeb, :channel

  alias ExplorerWeb.TransactionView
  alias Phoenix.View

  intercept(["confirmations"])

  def join("transactions:" <> _transaction_hash, _params, socket) do
    {:ok, %{}, socket}
  end

  def handle_out("confirmations", %{max_block_number: max_block_number, transaction: transaction}, socket) do
    Gettext.put_locale(ExplorerWeb.Gettext, socket.assigns.locale)

    rendered =
      View.render_to_string(
        TransactionView,
        "_confirmations.html",
        locale: socket.assigns.locale,
        max_block_number: max_block_number,
        transaction: transaction
      )

    push(socket, "confirmations", %{confirmations: rendered})

    {:noreply, socket}
  end
end
