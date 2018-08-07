defmodule BlockScoutWeb.Notifier do
  @moduledoc """
  Responds to events from EventHandler by sending appropriate channel updates to front-end.
  """

  alias Explorer.{Chain, Market, Repo}
  alias Explorer.Chain.Address
  alias Explorer.ExchangeRates.Token
  alias BlockScoutWeb.Endpoint

  def handle_event({:chain_event, :addresses, addresses}) do
    address_count_module = Application.get_env(:block_scout_web, :fake_adapter) || Chain
    Endpoint.broadcast("addresses:new_address", "count", %{count: address_count_module.address_estimated_count()})

    addresses
    |> Stream.reject(fn %Address{fetched_balance: fetched_balance} -> is_nil(fetched_balance) end)
    |> Enum.each(&broadcast_balance/1)
  end

  def handle_event({:chain_event, :blocks, blocks}) do
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
      market_history_data: market_history_data |> Enum.map(fn day -> Map.take(day, [:closing_price, :date]) end)
    })
  end

  def handle_event({:chain_event, :transactions, transaction_hashes}) do
    transaction_hashes
    |> Chain.hashes_to_transactions(
      necessity_by_association: %{
        block: :required,
        from_address: :optional,
        to_address: :optional,
        token_transfers: :optional
      }
    )
    |> Enum.each(&broadcast_transaction/1)
  end

  defp broadcast_balance(%Address{hash: address_hash} = address) do
    Endpoint.broadcast("addresses:#{address_hash}", "balance_update", %{
      address: address,
      exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null()
    })
  end

  defp broadcast_block(block) do
    preloaded_block = Repo.preload(block, [:miner, :transactions])

    Endpoint.broadcast("blocks:new_block", "new_block", %{
      block: preloaded_block,
      average_block_time: Chain.average_block_time()
    })
  end

  defp broadcast_transaction(transaction) do
    Endpoint.broadcast("transactions:new_transaction", "new_transaction", %{
      transaction: transaction
    })

    Endpoint.broadcast("addresses:#{transaction.from_address_hash}", "transaction", %{
      address: transaction.from_address,
      transaction: transaction
    })

    if transaction.to_address_hash && transaction.to_address_hash != transaction.from_address_hash do
      Endpoint.broadcast("addresses:#{transaction.to_address_hash}", "transaction", %{
        address: transaction.to_address,
        transaction: transaction
      })
    end
  end
end
