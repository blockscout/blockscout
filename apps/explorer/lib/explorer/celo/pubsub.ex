defmodule Explorer.Celo.PubSub do
  @moduledoc """
      Messages for cross cluster operations
  """

  alias Ecto.UUID
  alias Explorer.Celo.Telemetry
  alias Phoenix.PubSub

  require Logger

  @pubsub_name :operations

  @doc "Broadcast a message to publish a smart contract"
  def publish_smart_contract(address_hash, attrs) do
    msg_id = UUID.generate()

    Logger.info("Sending smart contract publish request #{msg_id}")
    PubSub.broadcast(@pubsub_name, "smart_contract_publish", {:smart_contract_publish, address_hash, attrs, msg_id})
    Telemetry.event(:smart_contract_publish_send, %{})
  end

  @doc "Subscribe to smart contract messages, messages are in the format {:smart_contract_publish, address_hash, attributes, msg_id}"
  def subscribe_to_smart_contract_publishing do
    PubSub.subscribe(@pubsub_name, "smart_contract_publish")
  end
end
