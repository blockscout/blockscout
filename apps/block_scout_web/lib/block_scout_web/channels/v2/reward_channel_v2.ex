defmodule BlockScoutWeb.RewardChannelV2 do
  @moduledoc """
  Establishes pub/sub channel for live updates of block reward events.
  """
  use BlockScoutWeb, :channel

  alias Explorer.Chain

  def join("rewards:" <> address_hash_string, _params, socket) do
    case valid_address_hash_and_not_restricted_access?(address_hash_string) do
      :ok ->
        {:ok, address_hash} = Chain.string_to_address_hash(address_hash_string)
        {:ok, address} = Chain.hash_to_address(address_hash)
        {:ok, %{}, assign(socket, :current_address, address)}

      reason ->
        {:error, %{reason: reason}}
    end
  end
end
