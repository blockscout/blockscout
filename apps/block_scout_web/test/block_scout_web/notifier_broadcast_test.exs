# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.NotifierBroadcastTest do
  use BlockScoutWeb.SubscriptionCase,
    async: false

  alias BlockScoutWeb.Notifier

  defmodule ClusterBroadcastSpy do
    @moduledoc false

    # Takes the place of the PubSub adapter, whose `broadcast/4` sends a broadcast
    # to the other nodes of the cluster, and reports such broadcasts to the test
    # process given as the adapter name.
    def broadcast(test_pid, topic, message, _dispatcher) do
      send(test_pid, {:cluster_broadcast, topic, message})
      :ok
    end

    def node_name(_test_pid), do: node()
  end

  setup do
    {:ok, {adapter, adapter_name, dispatcher}} = Registry.meta(BlockScoutWeb.PubSub, :pubsub)
    Registry.put_meta(BlockScoutWeb.PubSub, :pubsub, {ClusterBroadcastSpy, self(), dispatcher})
    on_exit(fn -> Registry.put_meta(BlockScoutWeb.PubSub, :pubsub, {adapter, adapter_name, dispatcher}) end)

    :ok
  end

  # Makes sure that the refutations in the other tests cannot pass vacuously.
  test "the spy detects a broadcast sent to the cluster" do
    topic = "test:#{System.unique_integer([:positive])}"

    @endpoint.broadcast(topic, "event", %{})

    assert_received {:cluster_broadcast, ^topic, _}
  end

  test "sends channel updates to the subscribers of the current node only" do
    address = insert(:address)
    topic = "addresses:#{address.hash}"
    @endpoint.subscribe(topic)

    Notifier.handle_event({:chain_event, :changed_bytecode, :on_demand, [address.hash]})

    assert_receive %Phoenix.Socket.Broadcast{topic: ^topic, event: "changed_bytecode"}
    refute_received {:cluster_broadcast, ^topic, _}
  end

  test "publishes GraphQL subscription updates on the current node only", %{socket: socket} do
    transaction = insert(:transaction)
    token_transfer = insert(:token_transfer, transaction: transaction)
    token_contract_address_hash = to_string(token_transfer.token_contract_address_hash)

    subscription = """
    subscription ($hash: AddressHash!) {
      token_transfers(token_contract_address_hash: $hash) {
        transaction_hash
      }
    }
    """

    ref = push_doc(socket, subscription, variables: %{"hash" => token_contract_address_hash})
    assert_reply(ref, :ok, %{subscriptionId: subscription_id})

    Notifier.handle_event({:chain_event, :token_transfers, :realtime, [token_transfer]})

    assert_push("subscription:data", push)

    assert push == %{
             result: %{
               data: %{
                 "token_transfers" => [%{"transaction_hash" => to_string(token_transfer.transaction_hash)}]
               }
             },
             subscriptionId: subscription_id
           }

    refute_received {:cluster_broadcast, "__absinthe__:proxy:" <> _, %{mutation_result: [^token_transfer]}}
  end
end
