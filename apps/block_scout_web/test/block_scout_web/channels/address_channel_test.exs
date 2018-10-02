defmodule BlockScoutWeb.AddressChannelTest do
  use BlockScoutWeb.ChannelCase

  alias BlockScoutWeb.Notifier

  test "subscribed user is notified of new_address count event" do
    topic = "addresses:new_address"
    @endpoint.subscribe(topic)

    address = insert(:address)

    Notifier.handle_event({:chain_event, :addresses, [address]})

    receive do
      %Phoenix.Socket.Broadcast{topic: ^topic, event: "count", payload: %{count: _}} ->
        assert true
    after
      5_000 ->
        assert false, "Expected message received nothing."
    end
  end

  describe "user subscribed to address" do
    setup do
      address = insert(:address)
      topic = "addresses:#{address.hash}"
      @endpoint.subscribe(topic)
      {:ok, %{address: address, topic: topic}}
    end

    test "notified of balance_update for matching address", %{address: address, topic: topic} do
      address_with_balance = %{address | fetched_coin_balance: 1}
      Notifier.handle_event({:chain_event, :addresses, [address_with_balance]})

      receive do
        %Phoenix.Socket.Broadcast{topic: ^topic, event: "balance_update", payload: payload} ->
          assert payload.address.hash == address_with_balance.hash
      after
        5_000 ->
          assert false, "Expected message received nothing."
      end
    end

    test "not notified of balance_update if fetched_coin_balance is nil", %{address: address} do
      Notifier.handle_event({:chain_event, :addresses, [address]})

      receive do
        _ -> assert false, "Message was broadcast for nil fetched_coin_balance."
      after
        100 -> assert true
      end
    end

    test "notified of new_pending_transaction for matching from_address", %{address: address, topic: topic} do
      pending = insert(:transaction, from_address: address)

      Notifier.handle_event({:chain_event, :transactions, [pending.hash]})

      receive do
        %Phoenix.Socket.Broadcast{topic: ^topic, event: "pending_transaction", payload: payload} ->
          assert payload.address.hash == address.hash
          assert payload.transaction.hash == pending.hash
      after
        5_000 ->
          assert false, "Expected message received nothing."
      end
    end

    test "notified of new_transaction for matching from_address", %{address: address, topic: topic} do
      transaction =
        :transaction
        |> insert(from_address: address)
        |> with_block()

      Notifier.handle_event({:chain_event, :transactions, [transaction.hash]})

      receive do
        %Phoenix.Socket.Broadcast{topic: ^topic, event: "transaction", payload: payload} ->
          assert payload.address.hash == address.hash
          assert payload.transaction.hash == transaction.hash
      after
        5_000 ->
          assert false, "Expected message received nothing."
      end
    end

    test "notified of new_transaction for matching to_address", %{address: address, topic: topic} do
      transaction =
        :transaction
        |> insert(to_address: address)
        |> with_block()

      Notifier.handle_event({:chain_event, :transactions, [transaction.hash]})

      receive do
        %Phoenix.Socket.Broadcast{topic: ^topic, event: "transaction", payload: payload} ->
          assert payload.address.hash == address.hash
          assert payload.transaction.hash == transaction.hash
      after
        5_000 ->
          assert false, "Expected message received nothing."
      end
    end

    test "not notified twice of new_transaction if to and from address are equal", %{address: address, topic: topic} do
      transaction =
        :transaction
        |> insert(from_address: address, to_address: address)
        |> with_block()

      Notifier.handle_event({:chain_event, :transactions, [transaction.hash]})

      receive do
        %Phoenix.Socket.Broadcast{topic: ^topic, event: "transaction", payload: payload} ->
          assert payload.address.hash == address.hash
          assert payload.transaction.hash == transaction.hash
      after
        5_000 ->
          assert false, "Expected message received nothing."
      end

      receive do
        _ -> assert false, "Received duplicate broadcast."
      after
        100 -> assert true
      end
    end

    test "notified of new_internal_transaction for matching from_address", %{address: address, topic: topic} do
      transaction =
        :transaction
        |> insert(from_address: address)
        |> with_block()

      internal_transaction = insert(:internal_transaction, transaction: transaction, from_address: address, index: 0)

      Notifier.handle_event({:chain_event, :internal_transactions, [internal_transaction]})

      receive do
        %Phoenix.Socket.Broadcast{topic: ^topic, event: "internal_transaction", payload: payload} ->
          assert payload.address.hash == address.hash
          assert payload.internal_transaction.id == internal_transaction.id
      after
        5_000 ->
          assert false, "Expected message received nothing."
      end
    end

    test "notified of new_internal_transaction for matching to_address", %{address: address, topic: topic} do
      transaction =
        :transaction
        |> insert(to_address: address)
        |> with_block()

      internal_transaction = insert(:internal_transaction, transaction: transaction, to_address: address, index: 0)

      Notifier.handle_event({:chain_event, :internal_transactions, [internal_transaction]})

      receive do
        %Phoenix.Socket.Broadcast{topic: ^topic, event: "internal_transaction", payload: payload} ->
          assert payload.address.hash == address.hash
          assert payload.internal_transaction.id == internal_transaction.id
      after
        5_000 ->
          assert false, "Expected message received nothing."
      end
    end

    test "not notified twice of new_internal_transaction if to and from address are equal", %{
      address: address,
      topic: topic
    } do
      transaction =
        :transaction
        |> insert(from_address: address, to_address: address)
        |> with_block()

      internal_transaction =
        insert(:internal_transaction, transaction: transaction, from_address: address, to_address: address, index: 0)

      Notifier.handle_event({:chain_event, :internal_transactions, [internal_transaction]})

      receive do
        %Phoenix.Socket.Broadcast{topic: ^topic, event: "internal_transaction", payload: payload} ->
          assert payload.address.hash == address.hash
          assert payload.internal_transaction.id == internal_transaction.id
      after
        5_000 ->
          assert false, "Expected message received nothing."
      end

      receive do
        _ -> assert false, "Received duplicate broadcast."
      after
        100 -> assert true
      end
    end
  end
end
