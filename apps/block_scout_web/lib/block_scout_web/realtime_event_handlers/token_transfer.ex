# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.RealtimeEventHandlers.TokenTransfer do
  @moduledoc """
  Subscribing process for token transfer broadcast events from realtime.
  """

  use BlockScoutWeb.RealtimeEventHandler

  alias Explorer.Chain.Events.Subscriber

  @impl BlockScoutWeb.RealtimeEventHandler
  def subscribe do
    Subscriber.to(:token_transfers, :realtime)
  end
end
