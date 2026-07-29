# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.RealtimeEventHandler do
  @moduledoc """
  Common part of the `BlockScoutWeb.RealtimeEventHandlers.*` processes.

  A handler subscribes to its own set of chain events and forwards them to
  `BlockScoutWeb.Notifier`. Events are taken from the mailbox in batches, and the
  ones carrying a plain list of items are merged into a single event, so that the
  notifier preloads and broadcasts the data of the whole batch at once instead of
  doing it per event.

  ## Usage

      defmodule BlockScoutWeb.RealtimeEventHandlers.SomeEvents do
        use BlockScoutWeb.RealtimeEventHandler

        @impl BlockScoutWeb.RealtimeEventHandler
        def subscribe do
          Subscriber.to(:some_event, :realtime)
        end
      end
  """

  alias BlockScoutWeb.Notifier

  @callback subscribe() :: any()

  # The data of these events is a plain list of items that the notifier iterates
  # over, so the lists of the whole batch can be concatenated into a single
  # event. The data of the other events is either a scalar, a tuple or a list of
  # positional values, hence they are passed to the notifier one by one.
  @mergeable_events [
    addresses: :realtime,
    addresses: :on_demand,
    address_coin_balances: :realtime,
    address_coin_balances: :on_demand,
    address_current_token_balances: :realtime,
    address_current_token_balances: :on_demand,
    address_token_balances: :on_demand,
    blocks: :realtime,
    block_rewards: :realtime,
    internal_transactions: :realtime,
    token_transfers: :realtime,
    transactions: :realtime
  ]

  defmacro __using__(_opts) do
    quote do
      use GenServer

      @behaviour BlockScoutWeb.RealtimeEventHandler

      def start_link(_) do
        GenServer.start_link(__MODULE__, [], name: __MODULE__)
      end

      @impl GenServer
      def init([]) do
        subscribe()

        {:ok, []}
      end

      @impl GenServer
      def handle_info(event, state) do
        BlockScoutWeb.RealtimeEventHandler.handle_event_batch(event)

        {:noreply, state}
      end

      defoverridable init: 1
    end
  end

  @doc """
  Handles the given event together with the events that are already waiting in
  the mailbox of the calling process.
  """
  @spec handle_event_batch(term()) :: :ok
  def handle_event_batch(event) do
    [event]
    |> drain_events(Application.get_env(:block_scout_web, __MODULE__)[:max_batch_size] - 1)
    |> merge_events()
    |> Enum.each(&Notifier.handle_event/1)
  end

  defp drain_events(events, 0), do: Enum.reverse(events)

  # Only the chain events are taken, so that the `GenServer` callbacks and the
  # system messages are still handled as usual.
  defp drain_events(events, count) do
    receive do
      {:chain_event, _event_type, _broadcast_type, _data} = event -> drain_events([event | events], count - 1)
      {:chain_event, _event_type} = event -> drain_events([event | events], count - 1)
    after
      0 -> Enum.reverse(events)
    end
  end

  # Groups the batch by event, keeping the order in which the events first
  # appeared, and merges the data of each group into a single event.
  defp merge_events(events) do
    events_by_key = Enum.group_by(events, &merge_key/1)

    events
    |> Enum.map(&merge_key/1)
    |> Enum.uniq()
    |> Enum.map(&merge_group(&1, events_by_key[&1]))
  end

  defp merge_group({:merge, {event_type, broadcast_type}}, events) do
    merged_data = Enum.flat_map(events, fn {:chain_event, _event_type, _broadcast_type, data} -> data end)

    {:chain_event, event_type, broadcast_type, merged_data}
  end

  # A group of unmergeable events consists of the very same event repeated, so
  # handling one of them is enough.
  defp merge_group({:keep, event}, _events), do: event

  defp merge_key({:chain_event, event_type, broadcast_type, _data} = event) do
    if {event_type, broadcast_type} in @mergeable_events do
      {:merge, {event_type, broadcast_type}}
    else
      {:keep, event}
    end
  end

  defp merge_key(event), do: {:keep, event}
end
