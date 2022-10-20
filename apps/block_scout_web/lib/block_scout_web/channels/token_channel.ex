defmodule BlockScoutWeb.TokenChannel do
  @moduledoc """
  Establishes pub/sub channel for live updates of token transfer events.
  """
  use BlockScoutWeb, :channel

  alias BlockScoutWeb.Tokens.TransferView
  alias Explorer.Chain
  alias Explorer.Chain.Hash
  alias Phoenix.View

  intercept(["token_transfer"])

  {:ok, burn_address_hash} = Chain.string_to_address_hash("0x0000000000000000000000000000000000000000")
  @burn_address_hash burn_address_hash

  def join("tokens:new_token_transfer", _params, socket) do
    {:ok, %{}, socket}
  end

  def join("tokens:" <> _transaction_hash, _params, socket) do
    {:ok, %{}, socket}
  end

  def handle_out(
        "token_transfer",
        %{token_transfer: _token_transfer},
        %Phoenix.Socket{handler: BlockScoutWeb.UserSocketV2} = socket
      ) do
    push(socket, "token_transfer", %{token_transfer: 1})

    {:noreply, socket}
  end

  def handle_out("token_transfer", %{token_transfer: token_transfer}, socket) do
    Gettext.put_locale(BlockScoutWeb.Gettext, socket.assigns.locale)

    rendered_token_transfer =
      View.render_to_string(
        TransferView,
        "_token_transfer.html",
        conn: socket,
        token: token_transfer.token,
        token_transfer: token_transfer,
        burn_address_hash: @burn_address_hash
      )

    push(socket, "token_transfer", %{
      token_transfer_hash: Hash.to_string(token_transfer.transaction_hash),
      token_transfer_html: rendered_token_transfer
    })

    {:noreply, socket}
  end
end
