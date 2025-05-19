defmodule BlockScoutWeb.V2.AddressChannelTest do
  use BlockScoutWeb.ChannelCase,
    # ETS tables are shared in `Explorer.Chain.Cache.Counters.AddressesCount`
    async: false

  alias BlockScoutWeb.Notifier
  alias Explorer.Chain.Wei
  alias Explorer.Chain.Cache.Counters.AddressesCount

  test "subscribed user is notified of new_address count event" do
    topic = "addresses:new_address"
    @endpoint.subscribe(topic)

    address = insert(:address)

    start_supervised!(AddressesCount)
    AddressesCount.consolidate()

    Notifier.handle_event({:chain_event, :addresses, :realtime, [address]})

    assert_receive %Phoenix.Socket.Broadcast{topic: ^topic, event: "count", payload: %{count: _}}, :timer.seconds(5)
  end

  describe "user subscribed to address" do
    setup do
      address = insert(:address)
      topic = "addresses:#{address.hash}"
      @endpoint.subscribe(topic)
      {:ok, %{address: address, topic: topic}}
    end

    test "notified of balance_update for matching address", %{address: address, topic: topic} do
      {:ok, balance} = Wei.cast(1)
      address_with_balance = %{address | fetched_coin_balance: balance}

      start_supervised!(AddressesCount)
      AddressesCount.consolidate()

      Notifier.handle_event({:chain_event, :addresses, :realtime, [address_with_balance]})

      assert_receive %Phoenix.Socket.Broadcast{topic: ^topic, event: "balance", payload: payload},
                     :timer.seconds(5)

      assert payload.balance == balance.value
    end

    test "not notified of balance_update if fetched_coin_balance is nil", %{address: address} do
      start_supervised!(AddressesCount)
      AddressesCount.consolidate()

      Notifier.handle_event({:chain_event, :addresses, :realtime, [address]})

      refute_receive _, 100, "Message was broadcast for nil fetched_coin_balance."
    end

    test "notified of new_pending_transaction for matching from_address", %{address: address, topic: topic} do
      pending = insert(:transaction, from_address: address)

      Notifier.handle_event({:chain_event, :transactions, :realtime, [pending]})

      assert_receive %Phoenix.Socket.Broadcast{
                       topic: ^topic,
                       event: "pending_transaction",
                       payload: %{transactions: _} = payload
                     },
                     :timer.seconds(5)

      assert List.first(payload.transactions)["hash"] == pending.hash
    end

    test "notified of new_transaction for matching from_address", %{address: address, topic: topic} do
      transaction =
        :transaction
        |> insert(from_address: address)
        |> with_block()

      Notifier.handle_event({:chain_event, :transactions, :realtime, [transaction]})

      assert_receive %Phoenix.Socket.Broadcast{
                       topic: ^topic,
                       event: "transaction",
                       payload: %{transactions: _} = payload
                     },
                     :timer.seconds(5)

      assert List.first(payload.transactions)["hash"] == transaction.hash
    end

    test "notified of new_transaction for matching to_address", %{address: address, topic: topic} do
      transaction =
        :transaction
        |> insert(to_address: address)
        |> with_block()

      Notifier.handle_event({:chain_event, :transactions, :realtime, [transaction]})

      assert_receive %Phoenix.Socket.Broadcast{
                       topic: ^topic,
                       event: "transaction",
                       payload: %{transactions: _} = payload
                     },
                     :timer.seconds(5)

      assert List.first(payload.transactions)["hash"] == transaction.hash
    end

    test "not notified twice of new_transaction if to and from address are equal", %{address: address, topic: topic} do
      transaction =
        :transaction
        |> insert(from_address: address, to_address: address)
        |> with_block()

      Notifier.handle_event({:chain_event, :transactions, :realtime, [transaction]})

      assert_receive %Phoenix.Socket.Broadcast{
                       topic: ^topic,
                       event: "transaction",
                       payload: %{transactions: _} = payload
                     },
                     :timer.seconds(5)

      assert List.first(payload.transactions)["hash"] == transaction.hash

      refute_receive %Phoenix.Socket.Broadcast{topic: ^topic, event: "transaction", payload: %{transactions: _}},
                     100,
                     "Received duplicate broadcast."
    end
  end
end
