defmodule BlockScoutWeb.V2.RewardChannel do
  @moduledoc """
  Establishes pub/sub channel for live updates of block reward events for API V2.
  """
  use BlockScoutWeb, :channel

  def join("rewards:" <> address_hash_string, _params, socket) do
    case valid_address_hash_and_not_restricted_access?(address_hash_string) do
      :ok -> {:ok, %{}, socket}
      reason -> {:error, %{reason: reason}}
    end
  end
end
