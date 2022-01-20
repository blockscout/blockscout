defmodule Explorer.Accounts.Notify.Summary do
  @moduledoc """
    Compose a summary from transactions
  """

  require AccountLogger

  alias Explorer.Accounts.Notify.Summary
  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Wei

  defstruct [
    :transaction_hash,
    :from_address_hash,
    :to_address_hash,
    :method,
    :block_number,
    :amount,
    :tx_fee,
    :name,
    :type
  ]

  def process(%Chain.Transaction{} = transaction) do
    preloaded_transaction = preload(transaction)

    transfers_summaries = handle_collection(transaction, preloaded_transaction.token_transfers)

    transaction_summary = fetch_summary(transaction)

    AccountLogger.debug("--- transaction summary")
    AccountLogger.debug(transaction_summary)
    AccountLogger.debug("--- transfer summary")
    AccountLogger.debug(transfers_summaries)

    [transaction_summary | transfers_summaries]
    |> Enum.filter(fn summary ->
      not (is_nil(summary) or
             is_nil(summary.amount) or
             summary.amount == Decimal.new(0))
    end)
  end

  def process(_), do: nil

  def handle_collection(_transaction, []), do: []

  def handle_collection(transaction, transfers_list) do
    Enum.map(
      transfers_list,
      fn transfer ->
        summary = fetch_summary(transaction, transfer)
        log_entry(summary)
        summary
      end
    )
  end

  def fetch_summary(%Chain.Transaction{block_number: nil}), do: nil

  def fetch_summary(%Chain.Transaction{} = transaction) do
    %Summary{
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

  def fetch_summary(_), do: :nothing

  def fetch_summary(%Chain.Transaction{block_number: nil}, _), do: nil

  def fetch_summary(
        %Chain.Transaction{} = transaction,
        %Chain.TokenTransfer{} = transfer
      ) do
    case transfer.token.type do
      "ERC-20" ->
        %Summary{
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

      "ERC-721" ->
        %Summary{
          transaction_hash: transaction.hash,
          method: method(transfer),
          from_address_hash: transfer.from_address_hash,
          to_address_hash: transfer.to_address_hash,
          block_number: transfer.block_number,
          amount: "Token ID: " <> to_string(transfer.token_id),
          tx_fee: fee(transaction),
          name: transfer.token.name,
          type: transfer.token.type
        }

      "ERC-1155" ->
        %Summary{
          transaction_hash: transaction.hash,
          method: method(transfer),
          from_address_hash: transfer.from_address_hash,
          to_address_hash: transfer.to_address_hash,
          block_number: transfer.block_number,
          amount: "Token ID: " <> to_string(transfer.token_id),
          tx_fee: fee(transaction),
          name: transfer.token.name,
          type: transfer.token.type
        }
    end
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

  def amount(%Chain.TokenTransfer{amount: amount}) when is_nil(amount), do: nil

  def amount(%Chain.TokenTransfer{amount: amount} = transfer) do
    decimals =
      Decimal.new(
        Integer.pow(
          10,
          Decimal.to_integer(token_decimals(transfer))
        )
      )

    Decimal.div(
      amount,
      decimals
    )
  end

  def token_decimals(%Chain.TokenTransfer{} = transfer) do
    transfer.token.decimals || Decimal.new(1)
  end

  def type(%Chain.Transaction{}), do: :coin
  def type(%Chain.InternalTransaction{}), do: :coin

  def fee(%Chain.Transaction{} = transaction) do
    {_, fee} = Chain.fee(transaction, :gwei)
    fee
  end

  defp log_entry(:nothing), do: nil

  defp log_entry(entry) do
    AccountLogger.info(entry)
  end

  def preload(%Chain.Transaction{} = transaction) do
    Repo.preload(transaction, [:internal_transactions, token_transfers: :token])
  end

  def preload(%Chain.TokenTransfer{} = transfer) do
    Repo.preload(transfer, [:transaction])
  end

  def preload(_), do: nil
end
