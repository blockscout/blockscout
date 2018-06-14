defmodule ExplorerWeb.AddressChannel do
  use ExplorerWeb, :channel

  intercept ["transaction"]

  def join("addresses:" <> _address_hash, _params, socket) do
    {:ok, %{}, socket}
  end

  def handle_out("transaction", %{transaction: transaction}, socket) do
    rendered = Phoenix.View.render_to_string(ExplorerWeb.AddressTransactionView, "_transaction.html", locale: socket.assigns.locale, transaction: transaction)
    push socket, "transaction", %{transaction: rendered}
    {:noreply, socket}
  end
end
