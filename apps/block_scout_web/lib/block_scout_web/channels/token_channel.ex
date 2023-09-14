defmodule BlockScoutWeb.TokenChannel do
  @moduledoc """
  Establishes pub/sub channel for live updates of token transfer events.
  """
  use BlockScoutWeb, :channel

  import Explorer.Chain.SmartContract, only: [burn_address_hash_string: 0]

  alias BlockScoutWeb.{CurrencyHelper, TokensView}
  alias BlockScoutWeb.Tokens.TransferView
  alias Explorer.Chain
  alias Explorer.Chain.Hash
  alias Phoenix.View

  intercept(["token_transfer", "token_total_supply"])

  {:ok, burn_address_hash} = Chain.string_to_address_hash(burn_address_hash_string())
  @burn_address_hash burn_address_hash

  def join("tokens:" <> _transaction_hash, _params, socket) do
    {:ok, %{}, socket}
  end

  def handle_out(
        "token_transfer",
        %{token_transfers: token_transfers},
        %Phoenix.Socket{handler: BlockScoutWeb.UserSocketV2} = socket
      )
      when is_list(token_transfers) do
    push(socket, "token_transfer", %{token_transfer: Enum.count(token_transfers)})

    {:noreply, socket}
  end

  def handle_out(
        "token_transfer",
        %{token_transfer: token_transfer},
        %Phoenix.Socket{handler: BlockScoutWeb.UserSocket} = socket
      ) do
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

  def handle_out("token_transfer", _, socket) do
    {:noreply, socket}
  end

  def handle_out(
        "token_total_supply",
        %{token: %Explorer.Chain.Token{total_supply: total_supply}},
        %Phoenix.Socket{handler: BlockScoutWeb.UserSocketV2} = socket
      ) do
    push(socket, "total_supply", %{total_supply: to_string(total_supply)})

    {:noreply, socket}
  end

  def handle_out("token_total_supply", %{token: token}, socket) do
    push(socket, "total_supply", %{
      total_supply:
        if(TokensView.decimals?(token),
          do: CurrencyHelper.format_according_to_decimals(token.total_supply, token.decimals),
          else: CurrencyHelper.format_integer_to_currency(token.total_supply)
        )
    })

    {:noreply, socket}
  end
end
