defmodule BlockScoutWeb.StakingEventHandler do
  @moduledoc """
  Subscribing process for broadcast events from staking app.
  """

  use GenServer

  alias BlockScoutWeb.Endpoint
  alias Explorer.Chain.Events.Subscriber
  alias Explorer.Staking.ContractState

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init([]) do
    Subscriber.to(:staking_update, :realtime)
    {:ok, []}
  end

  @impl true
  def handle_info({:chain_event, :staking_update, :realtime, data}, state) do
    last_known_block_number = ContractState.get(:last_known_block_number, 0)
    require Logger

    Logger.warn(
      "staking_event_handler.ex: received :staking_update and broadcasts stakes:staking_update to Endpoint. last_known_block_number = #{
        last_known_block_number
      }. passed_block_number = #{data.block_number}"
    )

    Endpoint.broadcast("stakes:staking_update", "staking_update", data)
    {:noreply, state}
  end
end
