defmodule BlockScoutWeb.RewardChannel do
  @moduledoc """
  Establishes pub/sub channel for live updates of block reward events.
  """
  use BlockScoutWeb, :channel

  alias BlockScoutWeb.TransactionView
  alias Explorer.Chain
  alias Phoenix.View

  intercept(["new_reward"])

  def join("rewards_old:" <> address_hash_string, _params, socket) do
    case valid_address_hash_and_not_restricted_access?(address_hash_string) do
      :ok ->
        {:ok, address_hash} = Chain.string_to_address_hash(address_hash_string)
        {:ok, address} = Chain.hash_to_address(address_hash)
        {:ok, %{}, assign(socket, :current_address, address)}

      reason ->
        {:error, %{reason: reason}}
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
