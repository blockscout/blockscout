defmodule ExplorerWeb.Notifier do
  alias Explorer.{Chain, Market}
  alias Explorer.ExchangeRates.Token
  alias ExplorerWeb.Endpoint

  def handle_event({:chain_event, :blocks, []}), do: IO.inspect("EMPTY BLOCKS")

  def handle_event({:chain_event, :blocks, blocks}) do
    max_numbered_block = Enum.max_by(blocks, & &1.number).number
    Endpoint.broadcast("transactions:confirmations", "update", %{block_number: max_numbered_block})
  end

  def handle_event({:chain_event, :transactions, transactions}) do
    transactions
    |> Enum.each(&broadcast_transaction/1)
  end

  def handle_event({:chain_event, :balance_updates, address_hashes}) do
    address_hashes
    |> Enum.each(&broadcast_balance/1)
  end

  def handle_event(event), do: IO.inspect({:error, event})

  defp broadcast_balance(address_hash) do
    {:ok, address} = Chain.hash_to_address(address_hash)

    ExplorerWeb.Endpoint.broadcast("addresses:#{address.hash}", "balance_update", %{
      address: address,
      exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null()
    })
  end

  defp broadcast_transaction(transaction_hash) do
    {:ok, transaction} =
      Chain.hash_to_transaction(
        transaction_hash,
        necessity_by_association: %{
          block: :required,
          from_address: :optional,
          to_address: :optional
        }
      )

    ExplorerWeb.Endpoint.broadcast("addresses:#{transaction.from_address_hash}", "transaction", %{
      address: transaction.from_address,
      transaction: transaction
    })

    if transaction.to_address && transaction.to_address != transaction.from_address do
      ExplorerWeb.Endpoint.broadcast("addresses:#{transaction.to_address_hash}", "transaction", %{
        address: transaction.to_address,
        transaction: transaction
      })
    end
  end
end
