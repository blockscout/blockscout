defmodule BlockScoutWeb.V2.BlockChannel do
  @moduledoc """
  Establishes pub/sub channel for live updates of block events for API V2.
  """
  use BlockScoutWeb, :channel

  def join("blocks:new_block", _params, socket) do
    {:ok, %{}, socket}
  end

  def join("blocks:" <> miner_address, _params, socket) do
    case valid_address_hash_and_not_restricted_access?(miner_address) do
      :ok -> {:ok, %{}, socket}
      reason -> {:error, %{reason: reason}}
    end
  end
end
