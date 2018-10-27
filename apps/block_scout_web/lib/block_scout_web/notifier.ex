defmodule BlockScoutWeb.Notifier do
  @moduledoc """
  Responds to events from EventHandler by sending appropriate channel updates to front-end.
  """

  alias Explorer.{Chain, Market, Repo}
  alias Explorer.Chain.{Address, InternalTransaction, Transaction}
  alias Explorer.ExchangeRates.Token
  alias BlockScoutWeb.Endpoint

  def handle_event({:chain_event, :addresses, :realtime, addresses}) do
    Endpoint.broadcast("addresses:new_address", "count", %{count: Chain.address_estimated_count()})

    addresses
    |> Stream.reject(fn %Address{fetched_coin_balance: fetched_coin_balance} -> is_nil(fetched_coin_balance) end)
    |> Enum.each(&broadcast_balance/1)
  end

  def handle_event({:chain_event, :blocks, :catchup, _blocks}) do
    ratio = Chain.indexed_ratio()

    finished? =
      if ratio < 1 do
        false
      else
        Chain.finished_indexing?()
      end

    Endpoint.broadcast("blocks:indexing", "index_status", %{
      ratio: ratio,
      finished: finished?
    })
  end

  def handle_event({:chain_event, :blocks, :realtime, blocks}) do
    Enum.each(blocks, &broadcast_block/1)
  end

  def handle_event({:chain_event, :exchange_rate}) do
    exchange_rate = Market.get_exchange_rate(Explorer.coin()) || Token.null()

    market_history_data =
      case Market.fetch_recent_history(30) do
        [today | the_rest] -> [%{today | closing_price: exchange_rate.usd_value} | the_rest]
        data -> data
      end

    Endpoint.broadcast("exchange_rate:new_rate", "new_rate", %{
      exchange_rate: exchange_rate,
      market_history_data: Enum.map(market_history_data, fn day -> Map.take(day, [:closing_price, :date]) end)
    })
  end

  def handle_event({:chain_event, :internal_transactions, :realtime, internal_transactions}) do
    internal_transactions
    |> Stream.map(
      &(InternalTransaction
        |> Repo.get_by(transaction_hash: &1.transaction_hash, index: &1.index)
        |> Repo.preload([:from_address, :to_address, transaction: :block]))
    )
    |> Enum.each(&broadcast_internal_transaction/1)
  end

  def handle_event({:chain_event, :transactions, :realtime, transaction_hashes}) do
    transaction_hashes
    |> Chain.hashes_to_transactions(
      necessity_by_association: %{
        :block => :optional,
        [created_contract_address: :names] => :optional,
        [from_address: :names] => :optional,
        [to_address: :names] => :optional,
        :token_transfers => :optional
      }
    )
    |> Enum.each(&broadcast_transaction/1)
  end

  def handle_event(_), do: nil

  defp broadcast_balance(%Address{hash: address_hash} = address) do
    Endpoint.broadcast("addresses:#{address_hash}", "balance_update", %{
      address: address,
      exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null()
    })
  end

  defp broadcast_block(block) do
    preloaded_block = Repo.preload(block, [[miner: :names], :transactions])
    average_block_time = Chain.average_block_time()

    Endpoint.broadcast("blocks:new_block", "new_block", %{
      block: preloaded_block,
      average_block_time: average_block_time
    })

    Endpoint.broadcast("blocks:#{to_string(block.miner_hash)}", "new_block", %{
      block: preloaded_block,
      average_block_time: average_block_time
    })
  end

  defp broadcast_internal_transaction(internal_transaction) do
    Endpoint.broadcast("internal_transactions:new_internal_transaction", "new_internal_transaction", %{
      internal_transaction: internal_transaction
    })

    Endpoint.broadcast("addresses:#{internal_transaction.from_address_hash}", "internal_transaction", %{
      address: internal_transaction.from_address,
      internal_transaction: internal_transaction
    })

    if internal_transaction.to_address_hash != internal_transaction.from_address_hash do
      Endpoint.broadcast("addresses:#{internal_transaction.to_address_hash}", "internal_transaction", %{
        address: internal_transaction.to_address,
        internal_transaction: internal_transaction
      })
    end
  end

  defp broadcast_transaction(%Transaction{block_number: nil} = pending) do
    broadcast_transaction(pending, "transactions:new_pending_transaction", "pending_transaction")
  end

  defp broadcast_transaction(transaction) do
    broadcast_transaction(transaction, "transactions:new_transaction", "transaction")
  end

  defp broadcast_transaction(transaction, transaction_channel, event) do
    Endpoint.broadcast("transactions:#{transaction.hash}", "collated", %{})

    Endpoint.broadcast(transaction_channel, event, %{
      transaction: transaction
    })

    Endpoint.broadcast("addresses:#{transaction.from_address_hash}", event, %{
      address: transaction.from_address,
      transaction: transaction
    })

    if transaction.to_address_hash != transaction.from_address_hash do
      Endpoint.broadcast("addresses:#{transaction.to_address_hash}", event, %{
        address: transaction.to_address,
        transaction: transaction
      })
    end
  end
end
