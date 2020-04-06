defmodule BlockScoutWeb.TransactionChannel do
  @moduledoc """
  Establishes pub/sub channel for live updates of transaction events.
  """
  use BlockScoutWeb, :channel

  alias BlockScoutWeb.TransactionView
  alias Explorer.Chain.Hash
  alias Phoenix.View

  intercept(["pending_transaction", "transaction"])

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

  def handle_out("pending_transaction", %{transaction: transaction}, socket) do
    Gettext.put_locale(BlockScoutWeb.Gettext, socket.assigns.locale)

    rendered_transaction =
      View.render_to_string(
        TransactionView,
        "_tile.html",
        transaction: transaction,
        conn: socket
      )

    push(socket, "pending_transaction", %{
      transaction_hash: Hash.to_string(transaction.hash),
      transaction_html: rendered_transaction
    })

    {:noreply, socket}
  end

  def handle_out("transaction", %{transaction: transaction}, socket) do
    Gettext.put_locale(BlockScoutWeb.Gettext, socket.assigns.locale)

    rendered_transaction =
      View.render_to_string(
        TransactionView,
        "_tile.html",
        transaction: transaction,
        conn: socket
      )

    push(socket, "transaction", %{
      transaction_hash: Hash.to_string(transaction.hash),
      transaction_html: rendered_transaction
    })

    {:noreply, socket}
  end
end
