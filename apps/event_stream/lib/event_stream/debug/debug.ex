defmodule EventStream.Debug.Constants do
  @moduledoc "Constant values for debug use in the EventStream app"
  defmacro __using__(_opts \\ []) do
    quote do
      @debug_event_name "EventStream.Debug.EventName"
    end
  end
end

defmodule EventStream.Debug do
  @moduledoc "Helper functions for debugging purposes"

  alias Explorer.Chain.CeloContractEvent
  alias Phoenix.PubSub

  use EventStream.Debug.Constants

  @doc "Creates and publishes an event to the stream via the same mechanism as cluster pubsub"
  def publish_debug_event(id \\ 88_888_888) do
    event_data = generate_debug_event(%{id: id})
    publish_debug_events([event_data])
  end

  @doc "Publishes a predefined list of events to the stream"
  def publish_debug_events(events) when is_list(events) do
    payload =
      {:chain_event, :celo_contract_event, :realtime, events}
      |> :erlang.term_to_binary([:compressed])

    PubSub.broadcast(:chain_pubsub, "chain_event", {:chain_event, payload})
  end

  @doc "Generates an event with optional values"
  def generate_debug_event(overrides \\ %{}) do
    %CeloContractEvent{
      block_number: 777_777_777,
      contract_address_hash: "0x7777777777777777777777777777777777777777",
      inserted_at: DateTime.utc_now(),
      log_index: 77_777_777,
      name: @debug_event_name,
      params: %{
        "from" => "\\x7777777777777777777777777777777777777777",
        "to" => "\\x7777777777777777777777777777777777777777",
        "value" => 7_777_777_777_777_777
      },
      topic: "0x7777777777777777777777777777777777777777777777777777777777777777",
      transaction_hash: "0x7777777777777777777777777777777777777777777777777777777777777777",
      updated_at: DateTime.utc_now()
    }
    |> Map.merge(overrides)
  end

  def debug_event_name, do: "EventStream.Debug.Event"
end
