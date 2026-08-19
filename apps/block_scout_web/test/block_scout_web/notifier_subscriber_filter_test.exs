# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.NotifierSubscriberFilterTest do
  use BlockScoutWeb.ChannelCase,
    async: false

  alias BlockScoutWeb.Notifier
  alias Explorer.Chain.{Transaction, Wei}
  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Chain.Cache.Counters.AddressesCount
  alias Explorer.Repo

  defp without_loaded_associations(%Transaction{hash: hash}), do: Repo.get!(Transaction, hash)

  defp create_token_transfer(opts \\ []) do
    from_address = opts[:from_address] || insert(:address)
    to_address = opts[:to_address] || insert(:address)

    token = insert(:token, type: "ERC-20")

    transaction =
      :transaction
      |> insert(from_address: from_address, to_address: token.contract_address)
      |> with_block()

    insert(:token_transfer,
      from_address: from_address,
      to_address: to_address,
      token_contract_address: token.contract_address,
      transaction: transaction,
      block: transaction.block,
      block_number: transaction.block_number,
      log_index: 0,
      token_type: "ERC-20",
      block_consensus: true
    )
  end

  describe "addresses event: subscriber filtering" do
    test "broadcasts balance only to subscribed address in a batch" do
      {:ok, balance} = Wei.cast(1)

      subscribed = insert(:address, fetched_coin_balance: balance, fetched_coin_balance_block_number: 1)
      unsubscribed = insert(:address, fetched_coin_balance: balance, fetched_coin_balance_block_number: 1)

      subscribed_topic = "addresses:#{subscribed.hash}"
      unsubscribed_topic = "addresses:#{unsubscribed.hash}"
      @endpoint.subscribe(subscribed_topic)
      @endpoint.subscribe(unsubscribed_topic)

      start_supervised!(AddressesCount)
      AddressesCount.consolidate()

      Phoenix.PubSub.unsubscribe(BlockScoutWeb.PubSub, unsubscribed_topic)

      Notifier.handle_event({:chain_event, :addresses, :realtime, [subscribed, unsubscribed]})

      assert_receive %Phoenix.Socket.Broadcast{topic: ^subscribed_topic, event: "balance"}, :timer.seconds(5)
      refute_receive %Phoenix.Socket.Broadcast{topic: ^unsubscribed_topic, event: "balance"}, 100
    end

    test "handles addresses event without error when no address has subscribers" do
      {:ok, balance} = Wei.cast(1)
      address = insert(:address, fetched_coin_balance: balance, fetched_coin_balance_block_number: 1)

      start_supervised!(AddressesCount)
      AddressesCount.consolidate()

      Notifier.handle_event({:chain_event, :addresses, :realtime, [address]})
    end
  end

  describe "address_coin_balances event: subscriber filtering" do
    test "handles event without error when no address has subscribers" do
      address = insert(:address)
      block = insert(:block)

      Notifier.handle_event(
        {:chain_event, :address_coin_balances, :realtime,
         [%{address_hash: address.hash, block_number: block.number, value: 1}]}
      )
    end

    test "skips unsubscribed addresses in a batch" do
      subscribed_address = insert(:address)
      unsubscribed_address = insert(:address)

      coin_balance =
        insert(:address_coin_balance,
          address: subscribed_address,
          address_hash: subscribed_address.hash,
          delta: 500
        )

      subscribed_topic = "addresses:#{subscribed_address.hash}"
      @endpoint.subscribe(subscribed_topic)

      Notifier.handle_event(
        {:chain_event, :address_coin_balances, :realtime,
         [
           %{address_hash: subscribed_address.hash, block_number: coin_balance.block_number, value: 1},
           %{address_hash: unsubscribed_address.hash, block_number: coin_balance.block_number, value: 1}
         ]}
      )

      assert_receive %Phoenix.Socket.Broadcast{topic: ^subscribed_topic, event: "coin_balance"}, :timer.seconds(5)
    end
  end

  describe "address_token_balances event: subscriber filtering" do
    test "handles event without error when no address has subscribers" do
      address = insert(:address)
      block = insert(:block)

      Notifier.handle_event(
        {:chain_event, :address_token_balances, :realtime, [%{address_hash: address.hash, block_number: block.number}]}
      )
    end
  end

  describe "internal_transactions event: subscriber filtering" do
    test "handles event without error when no address has subscribers" do
      transaction =
        :transaction
        |> insert()
        |> with_block()

      internal_transaction =
        insert(:internal_transaction,
          transaction: transaction,
          transaction_index: transaction.index,
          index: 0,
          block_number: transaction.block_number
        )

      Notifier.handle_event({:chain_event, :internal_transactions, :realtime, [internal_transaction]})
    end

    test "processes only internal transactions with subscribed addresses" do
      subscribed_address = insert(:address)

      transaction =
        :transaction
        |> insert(from_address: subscribed_address)
        |> with_block()

      subscribed_it =
        insert(:internal_transaction,
          transaction: transaction,
          from_address: subscribed_address,
          transaction_index: transaction.index,
          index: 0,
          block_number: transaction.block_number
        )

      unsubscribed_transaction =
        :transaction
        |> insert()
        |> with_block()

      unsubscribed_it =
        insert(:internal_transaction,
          transaction: unsubscribed_transaction,
          transaction_index: unsubscribed_transaction.index,
          index: 0,
          block_number: unsubscribed_transaction.block_number
        )

      topic = "addresses_old:#{subscribed_address.hash}"
      @endpoint.subscribe(topic)

      Notifier.handle_event({:chain_event, :internal_transactions, :realtime, [subscribed_it, unsubscribed_it]})

      assert_receive %Phoenix.Socket.Broadcast{
                       topic: ^topic,
                       event: "internal_transaction",
                       payload: %{internal_transaction: _}
                     },
                     :timer.seconds(5)

      refute_receive %Phoenix.Socket.Broadcast{event: "internal_transaction"}, 100
    end
  end

  describe "token_transfers event: subscriber filtering" do
    test "handles event without error when no channel has subscribers" do
      token_transfer = create_token_transfer()

      Notifier.handle_event({:chain_event, :token_transfers, :realtime, [token_transfer]})
    end

    test "processes transfers when subscribed to from_address channel" do
      token_transfer = create_token_transfer()
      topic = "addresses:#{token_transfer.from_address_hash}"
      @endpoint.subscribe(topic)

      Notifier.handle_event({:chain_event, :token_transfers, :realtime, [token_transfer]})

      assert_receive %Phoenix.Socket.Broadcast{
                       topic: ^topic,
                       event: "token_transfer",
                       payload: %{token_transfers: _}
                     },
                     :timer.seconds(5)
    end

    test "processes transfers when subscribed to to_address channel" do
      token_transfer = create_token_transfer()
      topic = "addresses:#{token_transfer.to_address_hash}"
      @endpoint.subscribe(topic)

      Notifier.handle_event({:chain_event, :token_transfers, :realtime, [token_transfer]})

      assert_receive %Phoenix.Socket.Broadcast{
                       topic: ^topic,
                       event: "token_transfer",
                       payload: %{token_transfers: _}
                     },
                     :timer.seconds(5)
    end

    test "processes transfers when subscribed to token channel" do
      token_transfer = create_token_transfer()
      topic = "tokens:#{token_transfer.token_contract_address_hash}"
      @endpoint.subscribe(topic)

      Notifier.handle_event({:chain_event, :token_transfers, :realtime, [token_transfer]})

      assert_receive %Phoenix.Socket.Broadcast{
                       topic: ^topic,
                       event: "token_transfer",
                       payload: %{token_transfer: 1}
                     },
                     :timer.seconds(5)
    end

    test "processes only relevant transfers in a mixed batch" do
      subscribed_address = insert(:address)
      subscribed_transfer = create_token_transfer(from_address: subscribed_address)
      unsubscribed_transfer = create_token_transfer()

      subscribed_topic = "addresses:#{subscribed_address.hash}"
      @endpoint.subscribe(subscribed_topic)

      Notifier.handle_event({:chain_event, :token_transfers, :realtime, [subscribed_transfer, unsubscribed_transfer]})

      assert_receive %Phoenix.Socket.Broadcast{
                       topic: ^subscribed_topic,
                       event: "token_transfer",
                       payload: %{token_transfers: _}
                     },
                     :timer.seconds(5)

      unsubscribed_topic = "addresses:#{unsubscribed_transfer.from_address_hash}"
      refute_receive %Phoenix.Socket.Broadcast{topic: ^unsubscribed_topic}, 100
    end
  end

  describe "transactions event: subscriber filtering" do
    test "handles event without error when no channel has subscribers" do
      transaction =
        :transaction
        |> insert()
        |> with_block()
        |> without_loaded_associations()

      Notifier.handle_event({:chain_event, :transactions, :realtime, [transaction]})
    end

    test "broadcasts the count of the batch to the default channel" do
      transactions =
        for _ <- 1..2 do
          :transaction
          |> insert()
          |> with_block()
          |> without_loaded_associations()
        end

      @endpoint.subscribe("transactions:new_transaction")

      Notifier.handle_event({:chain_event, :transactions, :realtime, transactions})

      assert_receive %Phoenix.Socket.Broadcast{
                       topic: "transactions:new_transaction",
                       event: "transaction",
                       payload: %{transaction: 2}
                     },
                     :timer.seconds(5)
    end

    test "renders the block data of a transaction when the denormalization is finished" do
      old_denormalization_finished = BackgroundMigrations.get_transactions_denormalization_finished()
      BackgroundMigrations.set_transactions_denormalization_finished(true)

      on_exit(fn ->
        BackgroundMigrations.set_transactions_denormalization_finished(old_denormalization_finished)
      end)

      subscribed_address = insert(:address)
      block = insert(:block, base_fee_per_gas: 1_000_000_000)

      transaction =
        :transaction
        |> insert(from_address: subscribed_address)
        |> with_block(block)
        |> without_loaded_associations()

      topic = "addresses:#{subscribed_address.hash}"
      @endpoint.subscribe(topic)

      Notifier.handle_event({:chain_event, :transactions, :realtime, [transaction]})

      assert_receive %Phoenix.Socket.Broadcast{
                       topic: ^topic,
                       event: "transaction",
                       payload: %{transactions: [%{"base_fee_per_gas" => base_fee_per_gas}]}
                     },
                     :timer.seconds(5)

      assert Decimal.equal?(Wei.to(base_fee_per_gas, :wei), 1_000_000_000)
    end

    test "processes only transactions of subscribed addresses in a mixed batch" do
      subscribed_address = insert(:address)

      subscribed_transaction =
        :transaction
        |> insert(from_address: subscribed_address)
        |> with_block()
        |> without_loaded_associations()

      unsubscribed_transaction =
        :transaction
        |> insert()
        |> with_block()
        |> without_loaded_associations()

      subscribed_topic = "addresses:#{subscribed_address.hash}"
      @endpoint.subscribe(subscribed_topic)

      Notifier.handle_event(
        {:chain_event, :transactions, :realtime, [subscribed_transaction, unsubscribed_transaction]}
      )

      assert_receive %Phoenix.Socket.Broadcast{
                       topic: ^subscribed_topic,
                       event: "transaction",
                       payload: %{transactions: [%{"hash" => hash}]}
                     },
                     :timer.seconds(5)

      assert hash == subscribed_transaction.hash
    end

    test "processes pending transactions of subscribed addresses" do
      subscribed_address = insert(:address)

      pending_transaction =
        :transaction
        |> insert(from_address: subscribed_address)
        |> without_loaded_associations()

      topic = "addresses:#{subscribed_address.hash}"
      @endpoint.subscribe(topic)

      Notifier.handle_event({:chain_event, :transactions, :realtime, [pending_transaction]})

      assert_receive %Phoenix.Socket.Broadcast{
                       topic: ^topic,
                       event: "pending_transaction",
                       payload: %{transactions: _}
                     },
                     :timer.seconds(5)
    end

    # TODO: delete this test when old UI becomes deprecated
    test "processes transactions of addresses subscribed to the old UI channel" do
      subscribed_address = insert(:address)

      subscribed_transaction =
        :transaction
        |> insert(from_address: subscribed_address)
        |> with_block()
        |> without_loaded_associations()

      unsubscribed_transaction =
        :transaction
        |> insert()
        |> with_block()
        |> without_loaded_associations()

      subscribed_topic = "addresses_old:#{subscribed_address.hash}"
      @endpoint.subscribe(subscribed_topic)

      Notifier.handle_event(
        {:chain_event, :transactions, :realtime, [subscribed_transaction, unsubscribed_transaction]}
      )

      assert_receive %Phoenix.Socket.Broadcast{
                       topic: ^subscribed_topic,
                       event: "transaction",
                       payload: %{transaction: %{hash: hash}}
                     },
                     :timer.seconds(5)

      assert hash == subscribed_transaction.hash
    end

    # TODO: delete this test when old UI becomes deprecated
    test "processes the whole batch when subscribed to the old UI default channel" do
      transaction =
        :transaction
        |> insert()
        |> with_block()
        |> without_loaded_associations()

      @endpoint.subscribe("transactions_old:new_transaction")

      Notifier.handle_event({:chain_event, :transactions, :realtime, [transaction]})

      assert_receive %Phoenix.Socket.Broadcast{
                       topic: "transactions_old:new_transaction",
                       event: "transaction",
                       payload: %{transaction: _}
                     },
                     :timer.seconds(5)
    end
  end

  describe "address_current_token_balances event: subscriber filtering" do
    test "handles event without error when address has no subscribers" do
      address = insert(:address)
      token_balance = insert(:address_current_token_balance, address: address)

      Notifier.handle_event({:chain_event, :address_current_token_balances, :realtime, [token_balance]})
    end

    test "processes balances when address has subscribers" do
      address = insert(:address)

      token_balance =
        insert(:address_current_token_balance,
          address: address,
          token_type: "ERC-20",
          value: 1_000_000_000_000_000_000
        )

      topic = "addresses:#{address.hash}"
      @endpoint.subscribe(topic)

      Notifier.handle_event({:chain_event, :address_current_token_balances, :realtime, [token_balance]})

      assert_receive %Phoenix.Socket.Broadcast{
                       topic: ^topic,
                       event: "updated_token_balances_erc_20",
                       payload: %{token_balances: _, overflow: _}
                     },
                     :timer.seconds(5)
    end
  end
end
