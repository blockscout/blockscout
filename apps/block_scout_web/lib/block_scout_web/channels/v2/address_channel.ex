defmodule BlockScoutWeb.V2.AddressChannel do
  @moduledoc """
  Establishes pub/sub channel for address page live updates for API V2.
  """
  use BlockScoutWeb, :channel

  def join("addresses:" <> address_hash_string, _params, socket) do
    case valid_address_hash_and_not_restricted_access?(address_hash_string) do
      :ok ->
        {:ok, %{}, assign(socket, :address_hash, address_hash_string)}

      reason ->
        {:error, %{reason: reason}}
    end
  end
end
