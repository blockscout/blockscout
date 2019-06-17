defmodule BlockScoutWeb.RewardChannel do
  @moduledoc """
  Establishes pub/sub channel for live updates of block reward events.
  """
  use BlockScoutWeb, :channel

  alias BlockScoutWeb.TransactionView
  alias Explorer.Chain
  alias Phoenix.View

  intercept(["new_reward"])

  def join("rewards:" <> address_hash, _params, socket) do
    with {:ok, hash} <- Chain.string_to_address_hash(address_hash),
         {:ok, address} <- Chain.hash_to_address(hash) do
      {:ok, %{}, assign(socket, :current_address, address)}
    end
  end

  def handle_out("new_reward", %{emission_funds: emission_funds, validator: validator}, socket) do
    Gettext.put_locale(BlockScoutWeb.Gettext, socket.assigns.locale)

    rendered_reward =
      View.render_to_string(
        TransactionView,
        "_emission_reward_tile.html",
        current_address: socket.assigns.current_address,
        emission_funds: emission_funds,
        validator: validator
      )

    push(socket, "new_reward", %{reward_html: rendered_reward})

    {:noreply, socket}
  end
end
