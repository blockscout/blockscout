defmodule BlockScoutWeb.TokenInstanceChannel do
  @moduledoc """
  Establishes pub/sub channel for live updates of token instances events.
  """
  use BlockScoutWeb, :channel

  def join("token_instances:" <> _token_contract_address_hash, _params, socket) do
    {:ok, %{}, socket}
  end
end
