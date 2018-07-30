defmodule ExplorerWeb.TransactionChannel do
  @moduledoc """
  Establishes pub/sub channel for live updates of transaction events.
  """
  use ExplorerWeb, :channel

  alias ExplorerWeb.ChainView
  alias Phoenix.View

  intercept(["new_transaction"])

  def join("transactions:new_transaction", _params, socket) do
    {:ok, %{}, socket}
  end

  def handle_out("new_transaction", %{transaction: transaction}, socket) do
    Gettext.put_locale(ExplorerWeb.Gettext, socket.assigns.locale)

    rendered_homepage_transaction =
      View.render_to_string(
        ChainView,
        "_transaction.html",
        locale: socket.assigns.locale,
        transaction: transaction
      )

    push(socket, "new_transaction", %{
      homepage_transaction_html: rendered_homepage_transaction
    })

    {:noreply, socket}
  end
end
