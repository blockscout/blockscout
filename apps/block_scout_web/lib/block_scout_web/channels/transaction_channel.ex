defmodule BlockScoutWeb.TransactionChannel do
  @moduledoc """
  Establishes pub/sub channel for live updates of transaction events.
  """
  use BlockScoutWeb, :channel

  alias BlockScoutWeb.TransactionView
  alias Explorer.Chain
  alias Explorer.Chain.Hash
  alias Phoenix.View

  intercept(["pending_transaction", "transaction"])

  {:ok, burn_address_hash} = Chain.string_to_address_hash("0x0000000000000000000000000000000000000000")
  @burn_address_hash burn_address_hash

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
        burn_address_hash: @burn_address_hash,
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
        burn_address_hash: @burn_address_hash,
        conn: socket
      )

    push(socket, "transaction", %{
      transaction_hash: Hash.to_string(transaction.hash),
      transaction_html: rendered_transaction
    })

    {:noreply, socket}
  end
end
