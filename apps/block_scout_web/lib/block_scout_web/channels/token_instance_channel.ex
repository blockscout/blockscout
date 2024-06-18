defmodule BlockScoutWeb.TokenInstanceChannel do
  @moduledoc """
  Establishes pub/sub channel for live updates of token instances events.
  """
  use BlockScoutWeb, :channel

  intercept(["fetched_token_instance_metadata"])

  def join("fetched_token_instance_metadata", _params, socket) do
    {:ok, %{}, socket}
  end

  def join("token_instances:" <> _token_contract_address_hash, _params, socket) do
    {:ok, %{}, socket}
  end

  def handle_out(
        "fetched_token_instance_metadata",
        res,
        %Phoenix.Socket{handler: BlockScoutWeb.UserSocketV2} = socket
      ) do
    push(socket, "fetched_token_instance_metadata", res)

    {:noreply, socket}
  end
end
