defmodule Explorer.Accounts.Notify.Notification do
  require Logger

  alias Explorer.Chain
  alias Explorer.Chain.Wei
  alias Explorer.Repo
  alias Explorer.Accounts.Notify.Notification
  alias Explorer.Accounts.Notify.Notifier

  defstruct [
    :transaction_hash,
    :from_address_hash,
    :to_address_hash,
    :method,
    :block_number,
    :amount,
    :tx_fee,
    :name,
    :type,
  ]

  def process(nil), do: nil
  def process([]), do: nil

  def process(transactions) when is_list(transactions) do
    Enum.map(transactions, fn transaction -> process(transaction) end)
  end

  def process(%Chain.Transaction{} = transaction) do
    summary = fetch_summary(transaction)
    preloaded_transaction = preload(transaction)

    handle_collection(transaction, preloaded_transaction.token_transfers)
    summary = fetch_summary(transaction)

    Notifier.process(summary)
  end

  def process(_), do: nil

  def handle_collection(transaction, []), do: log_entry("No transfers to handle")

  def handle_collection(transaction, transfers_list) do
    Enum.map(
      transfers_list,
      fn transfer ->
        summary = fetch_summary(transaction, transfer)
        IO.inspect(summary)
        log_entry(summary)
      end
    )
  end

  def fetch_summary(%Chain.Transaction{} = transaction) do
    # preloaded_transaction = Repo.preload(transaction, [:internal_transactions, token_transfers: :token])
    #
    # IO.inspect(transaction)

    %Notification{
      transaction_hash: transaction.hash,
      method: method(transaction),
      from_address_hash: transaction.from_address_hash,
      to_address_hash: transaction.to_address_hash,
      block_number: transaction.block_number,
      amount: amount(transaction),
      tx_fee: fee(transaction),
      name: Application.get_env(:explorer, :coin),
      type: "COIN"
    }
  end

  def fetch_summary(
        %Chain.Transaction{} = transaction,
        %Chain.TokenTransfer{} = transfer
      ) do
    %Notification{
      transaction_hash: transaction.hash,
      method: method(transfer),
      from_address_hash: transfer.from_address_hash,
      to_address_hash: transfer.to_address_hash,
      block_number: transfer.block_number,
      amount: amount(transfer),
      tx_fee: fee(transaction),
      name: transfer.token.name,
      type: transfer.token.type
    }
  end

  @burn_address "0x0000000000000000000000000000000000000000"

  def method(%{from_address_hash: from, to_address_hash: to}) do
    {:ok, burn_address} = format_address(@burn_address)

    cond do
      burn_address == from -> "mint"
      burn_address == to -> "burn"
      true -> "transfer"
    end
  end

  def format_address(address_hash_string) do
    Chain.string_to_address_hash(address_hash_string)
  end

  def amount(%Chain.Transaction{} = transaction) do
    Wei.to(transaction.value, :ether)
  end

  def amount(%Chain.TokenTransfer{} = transfer) do
    transfer.amount / transfer.token.decimals
  end

  def fetch_summary(%Chain.Address{}), do: %Notification{name: :skip_address}
  def fetch_summary(%Chain.Block{}), do: %Notification{name: :skip_block}
  def fetch_summary(%Chain.PendingBlockOperation{}), do: %Notification{name: :skip_pending}
  def fetch_summary(_), do: %Notification{name: :skip_other}

  def type(%Chain.Transaction{} = transaction), do: :coin
  def type(%Chain.InternalTransaction{} = transaction), do: :coin

  def fee(%Chain.Transaction{} = transaction) do
    {_, fee} = Chain.fee(transaction, :gwei)
    fee
  end

  defp log_entry(nil), do: nil
  defp log_entry([]), do: nil

  defp log_entry(entry) do
    Logger.info(entry)
  end

  def preload(%Chain.Transaction{} = transaction) do
    Repo.preload(transaction, [:internal_transactions, token_transfers: :token])
  end

  def preload(%Chain.TokenTransfer{} = transfer) do
    Repo.preload(transfer, [:transaction])
  end

  def preload(_), do: nil
end
