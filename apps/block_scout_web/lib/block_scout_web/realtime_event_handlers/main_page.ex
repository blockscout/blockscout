# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.RealtimeEventHandlers.MainPage do
  @moduledoc """
  Subscribing process for main page broadcast events from realtime.
  """

  use BlockScoutWeb.RealtimeEventHandler

  alias Explorer.Chain.Cache.Counters.Helper
  alias Explorer.Chain.Events.Subscriber

  @impl GenServer
  def init([]) do
    Helper.create_cache_table(:last_broadcasted_block)

    super([])
  end

  @impl BlockScoutWeb.RealtimeEventHandler
  def subscribe do
    Subscriber.to(:blocks, :realtime)
    Subscriber.to(:transactions, :realtime)
  end
end
