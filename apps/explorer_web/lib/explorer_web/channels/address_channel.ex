defmodule ExplorerWeb.AddressChannel do
  @moduledoc """
  Establishes pub/sub channel for address page live updates.
  """
  use ExplorerWeb, :channel

  alias ExplorerWeb.{AddressTransactionView, AddressView}
  alias Phoenix.View

  intercept(["overview", "transaction"])

  def join("addresses:" <> _address_hash, _params, socket) do
    {:ok, %{}, socket}
  end

  def handle_out("transaction", %{transaction: transaction}, socket) do
    Gettext.put_locale(ExplorerWeb.Gettext, socket.assigns.locale)

    rendered =
      View.render_to_string(
        AddressTransactionView,
        "_transaction.html",
        locale: socket.assigns.locale,
        transaction: transaction
      )

    push(socket, "transaction", %{
      to_address_hash: to_string(transaction.to_address_hash),
      from_address_hash: to_string(transaction.from_address_hash),
      transaction_html: rendered
    })

    {:noreply, socket}
  end

  def handle_out(
        "overview",
        %{address: address, exchange_rate: exchange_rate, transaction_count: transaction_count},
        socket
      ) do
    Gettext.put_locale(ExplorerWeb.Gettext, socket.assigns.locale)

    rendered =
      View.render_to_string(
        AddressView,
        "_values.html",
        locale: socket.assigns.locale,
        address: address,
        exchange_rate: exchange_rate,
        transaction_count: transaction_count
      )

    push(socket, "overview", %{overview: rendered})
    {:noreply, socket}
  end
end
