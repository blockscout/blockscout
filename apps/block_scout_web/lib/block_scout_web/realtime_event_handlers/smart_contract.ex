# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.RealtimeEventHandlers.SmartContract do
  @moduledoc """
  Subscribing process for smart contract verification related broadcast events from realtime.
  """

  use BlockScoutWeb.RealtimeEventHandler

  alias Explorer.Chain.Events.Subscriber

  @impl BlockScoutWeb.RealtimeEventHandler
  def subscribe do
    Subscriber.to(:contract_verification_result, :on_demand)
    Subscriber.to(:smart_contract_was_verified, :on_demand)
    Subscriber.to(:smart_contract_was_not_verified, :on_demand)
    Subscriber.to(:eth_bytecode_db_lookup_started, :on_demand)
  end
end
