defmodule ExplorerWeb.AddressChannel do
  @moduledoc """
  Establishes pub/sub channel for address page live updates.
  """
  use ExplorerWeb, :channel

  alias ExplorerWeb.{AddressTransactionView, AddressView}
  alias Phoenix.View

  intercept(["balance_update", "count", "transaction"])

  def join("addresses:" <> _address_hash, _params, socket) do
    {:ok, %{}, socket}
  end

  def handle_out(
        "balance_update",
        %{address: address, exchange_rate: exchange_rate},
        socket
      ) do
    Gettext.put_locale(ExplorerWeb.Gettext, socket.assigns.locale)

    rendered =
      View.render_to_string(
        AddressView,
        "_balance_card.html",
        locale: socket.assigns.locale,
        address: address,
        exchange_rate: exchange_rate
      )

    push(socket, "balance", %{balance: rendered})
    {:noreply, socket}
  end

  def handle_out("count", %{count: count}, socket) do
    Gettext.put_locale(ExplorerWeb.Gettext, socket.assigns.locale)

    push(socket, "count", %{count: Cldr.Number.to_string!(count, format: "#,###")})

    {:noreply, socket}
  end

  def handle_out("transaction", %{address: address, transaction: transaction}, socket) do
    Gettext.put_locale(ExplorerWeb.Gettext, socket.assigns.locale)

    rendered =
      View.render_to_string(
        AddressTransactionView,
        "_transaction.html",
        locale: socket.assigns.locale,
        address: address,
        transaction: transaction
      )

    push(socket, "transaction", %{
      to_address_hash: to_string(transaction.to_address_hash),
      from_address_hash: to_string(transaction.from_address_hash),
      transaction_html: rendered
    })

    {:noreply, socket}
  end
end
