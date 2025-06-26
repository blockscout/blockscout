defmodule BlockScoutWeb.TransactionChannel do
  @moduledoc """
  Establishes pub/sub channel for live updates of transaction events.
  """
  use BlockScoutWeb, :channel

  import Explorer.Chain.SmartContract, only: [burn_address_hash_string: 0]

  alias BlockScoutWeb.{TransactionRawTraceView, TransactionView}
  alias Explorer.Chain
  alias Explorer.Chain.{Hash, InternalTransaction}
  alias Phoenix.View

  intercept(["pending_transaction", "transaction", "raw_trace"])

  {:ok, burn_address_hash} = Chain.string_to_address_hash(burn_address_hash_string())
  @burn_address_hash burn_address_hash

  def join("transactions_old:new_transaction", _params, socket) do
    {:ok, %{}, socket}
  end

  def join("transactions_old:new_pending_transaction", _params, socket) do
    {:ok, %{}, socket}
  end

  def join("transactions_old:stats", _params, socket) do
    {:ok, %{}, socket}
  end

  def join("transactions_old:" <> _transaction_hash, _params, socket) do
    {:ok, %{}, socket}
  end

  def handle_out(
        "pending_transaction",
        %{transaction: transaction},
        %Phoenix.Socket{handler: BlockScoutWeb.UserSocket} = socket
      ) do
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

  def handle_out("pending_transaction", _, socket) do
    {:noreply, socket}
  end

  def handle_out(
        "transaction",
        %{transaction: transaction},
        %Phoenix.Socket{handler: BlockScoutWeb.UserSocket} = socket
      ) do
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

  def handle_out("transaction", _, socket) do
    {:noreply, socket}
  end

  def handle_out(
        "raw_trace",
        %{raw_trace_origin: transaction_hash},
        socket
      ) do
    internal_transactions = InternalTransaction.all_transaction_to_internal_transactions(transaction_hash)

    push(socket, "raw_trace", %{
      raw_trace:
        View.render_to_string(
          TransactionRawTraceView,
          "_card_body.html",
          internal_transactions: internal_transactions,
          conn: socket
        )
    })

    {:noreply, socket}
  end
end
