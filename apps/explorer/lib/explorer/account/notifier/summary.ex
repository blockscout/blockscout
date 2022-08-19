defmodule Explorer.Account.Notifier.Summary do
  @moduledoc """
    Compose a summary from transactions
  """

  require Logger

  alias Explorer.Account.Notifier.Summary
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
    :subject,
    :type
  ]

  def process(%Chain.Transaction{} = transaction) do
    preloaded_transaction = preload(transaction)

    transfers_summaries =
      handle_collection(
        transaction,
        preloaded_transaction.token_transfers
      )

    transaction_summary = fetch_summary(transaction)

    [transaction_summary | transfers_summaries]
    |> Enum.filter(fn summary ->
      not (is_nil(summary) or
             summary == :nothing or
             is_nil(summary.amount) or
             summary.amount == Decimal.new(0))
    end)
  end

  def process(%Chain.TokenTransfer{} = transfer) do
    preloaded_transfer = preload(transfer)

    summary = fetch_summary(preloaded_transfer.transaction, preloaded_transfer)

    if summary != :nothing do
      [summary]
    else
      []
    end
  end

  def process(_), do: nil

  def handle_collection(_transaction, []), do: []

  def handle_collection(transaction, transfers_list) do
    Enum.map(
      transfers_list,
      fn transfer ->
        transaction
        |> fetch_summary(transfer)
      end
    )
  end

  def fetch_summary(%Chain.Transaction{block_number: nil}), do: :nothing

  def fetch_summary(%Chain.Transaction{created_contract_address_hash: nil} = transaction) do
    %Summary{
      transaction_hash: transaction.hash,
      method: method(transaction),
      from_address_hash: transaction.from_address_hash,
      to_address_hash: transaction.to_address_hash,
      block_number: transaction.block_number,
      amount: amount(transaction),
      tx_fee: fee(transaction),
      name: Application.get_env(:explorer, :coin_name),
      subject: "Coin transaction",
      type: "COIN"
    }
  end

  def fetch_summary(%Chain.Transaction{to_address_hash: nil} = transaction) do
    %Summary{
      transaction_hash: transaction.hash,
      method: "contract_creation",
      from_address_hash: transaction.from_address_hash,
      to_address_hash: transaction.created_contract_address_hash,
      block_number: transaction.block_number,
      amount: amount(transaction),
      tx_fee: fee(transaction),
      name: Application.get_env(:explorer, :coin_name),
      subject: "Contract creation",
      type: "COIN"
    }
  end

  def fetch_summary(_), do: :nothing

  def fetch_summary(%Chain.Transaction{block_number: nil}, _), do: :nothing

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
          subject: transfer.token.type,
          tx_fee: fee(transaction),
          name: transfer.token.name,
          type: transfer.token.type
        }

      "ERC-721" ->
        %Summary{
          amount: 0,
          transaction_hash: transaction.hash,
          method: method(transfer),
          from_address_hash: transfer.from_address_hash,
          to_address_hash: transfer.to_address_hash,
          block_number: transfer.block_number,
          subject: to_string(transfer.token_id),
          tx_fee: fee(transaction),
          name: transfer.token.name,
          type: transfer.token.type
        }

      "ERC-1155" ->
        %Summary{
          amount: 0,
          transaction_hash: transaction.hash,
          method: method(transfer),
          from_address_hash: transfer.from_address_hash,
          to_address_hash: transfer.to_address_hash,
          block_number: transfer.block_number,
          subject: token_ids(transfer),
          tx_fee: fee(transaction),
          name: transfer.token.name,
          type: transfer.token.type
        }
    end
  end

  def fetch_summary(_, _), do: :nothing

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

  def token_ids(%Chain.TokenTransfer{token_id: token_id, token_ids: token_ids}) do
    case token_id do
      nil ->
        Enum.map_join(token_ids, ", ", fn id -> to_string(id) end)

      _ ->
        to_string(token_id)
    end
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

  def preload(%Chain.Transaction{} = transaction) do
    Repo.preload(transaction, [:internal_transactions, token_transfers: :token])
  end

  def preload(%Chain.TokenTransfer{} = transfer) do
    Repo.preload(transfer, [:transaction, :token])
  end

  def preload(_), do: nil
end
