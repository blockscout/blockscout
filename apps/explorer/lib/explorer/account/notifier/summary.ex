defmodule Explorer.Account.Notifier.Summary do
  @moduledoc """
    Compose a summary from transactions
  """

  import Explorer.Chain.SmartContract, only: [burn_address_hash_string: 0]

  alias Explorer
  alias Explorer.Account.Notifier.Summary
  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.{Transaction, Wei}

  @unknown "Unknown"

  defstruct [
    :transaction_hash,
    :from_address_hash,
    :to_address_hash,
    :method,
    :block_number,
    :amount,
    :transaction_fee,
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
             (summary.amount == Decimal.new(0) and summary.type != "ERC-7984"))
    end)
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

  defp fetch_summary(%Chain.Transaction{block_number: nil}), do: :nothing

  defp fetch_summary(%Chain.Transaction{created_contract_address_hash: nil} = transaction) do
    %Summary{
      transaction_hash: transaction.hash,
      method: method(transaction),
      from_address_hash: transaction.from_address_hash,
      to_address_hash: transaction.to_address_hash,
      block_number: transaction.block_number,
      amount: amount(transaction),
      transaction_fee: fee(transaction),
      name: Explorer.coin_name(),
      subject: "Coin transaction",
      type: "COIN"
    }
  end

  defp fetch_summary(%Chain.Transaction{to_address_hash: nil} = transaction) do
    %Summary{
      transaction_hash: transaction.hash,
      method: "contract_creation",
      from_address_hash: transaction.from_address_hash,
      to_address_hash: transaction.created_contract_address_hash,
      block_number: transaction.block_number,
      amount: amount(transaction),
      transaction_fee: fee(transaction),
      name: Explorer.coin_name(),
      subject: "Contract creation",
      type: "COIN"
    }
  end

  defp fetch_summary(_), do: :nothing

  defp fetch_summary(%Chain.Transaction{block_number: nil}, _), do: :nothing

  defp fetch_summary(
         %Chain.Transaction{} = transaction,
         %Chain.TokenTransfer{} = transfer
       ) do
    case transfer.token.type do
      type when type in ["ERC-20", "ZRC-2"] ->
        %Summary{
          transaction_hash: transaction.hash,
          method: method(transfer),
          from_address_hash: transfer.from_address_hash,
          to_address_hash: transfer.to_address_hash,
          block_number: transfer.block_number,
          amount: amount(transfer),
          subject: transfer.token.type,
          transaction_fee: fee(transaction),
          name: token_name(transfer),
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
          subject: to_string(transfer.token_ids && List.first(transfer.token_ids)),
          transaction_fee: fee(transaction),
          name: token_name(transfer),
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
          transaction_fee: fee(transaction),
          name: token_name(transfer),
          type: transfer.token.type
        }

      "ERC-404" ->
        token_ids_string = token_ids(transfer)

        %Summary{
          amount: amount(transfer),
          transaction_hash: transaction.hash,
          method: method(transfer),
          from_address_hash: transfer.from_address_hash,
          to_address_hash: transfer.to_address_hash,
          block_number: transfer.block_number,
          subject: if(token_ids_string == "", do: transfer.token.type, else: token_ids_string),
          transaction_fee: fee(transaction),
          name: token_name(transfer),
          type: transfer.token.type
        }

      "ERC-7984" ->
        %Summary{
          amount: Decimal.new(0),
          transaction_hash: transaction.hash,
          method: method(transfer),
          from_address_hash: transfer.from_address_hash,
          to_address_hash: transfer.to_address_hash,
          block_number: transfer.block_number,
          subject: "Confidential transfer",
          transaction_fee: fee(transaction),
          name: token_name(transfer),
          type: transfer.token.type
        }
    end
  end

  defp fetch_summary(_, _), do: :nothing

  defp method(%{from_address_hash: from, to_address_hash: to}) do
    {:ok, burn_address} = format_address(burn_address_hash_string())

    cond do
      burn_address == from -> "mint"
      burn_address == to -> "burn"
      true -> "transfer"
    end
  end

  defp format_address(address_hash_string) do
    Chain.string_to_address_hash(address_hash_string)
  end

  defp amount(%Chain.Transaction{} = transaction) do
    Wei.to(transaction.value, :ether)
  end

  defp amount(%Chain.TokenTransfer{amount: amount}) when is_nil(amount), do: nil

  defp amount(%Chain.TokenTransfer{amount: amount} = transfer) do
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

  defp token_ids(%Chain.TokenTransfer{token_ids: nil}), do: ""

  defp token_ids(%Chain.TokenTransfer{token_ids: token_ids}) do
    Enum.map_join(token_ids, ", ", fn id -> to_string(id) end)
  end

  defp token_name(%Chain.TokenTransfer{} = transfer) do
    transfer.token.name || @unknown
  end

  defp token_decimals(%Chain.TokenTransfer{} = transfer) do
    transfer.token.decimals || Decimal.new(0)
  end

  defp fee(%Chain.Transaction{} = transaction) do
    {_, fee} = Transaction.fee(transaction, :gwei)
    fee
  end

  defp preload(%Chain.Transaction{} = transaction) do
    Repo.preload(transaction, token_transfers: :token)
  end
end
