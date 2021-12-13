defmodule Explorer.Export.CSV.TokenTransferExporter do
  @moduledoc "Export all TokenTransfer instances for a given account between two dates"

  import Ecto.Query
  alias Explorer.Chain
  alias Explorer.Chain.{Address, TokenTransfer}
  import Explorer.Export.CSV.Utils

  @behaviour Explorer.Export.CSV.Exporter

  @preloads [
    block: [],
    token: [],
    transaction: [gas_currency: :token]
  ]

  @row_header [
    "TxHash",
    "BlockNumber",
    "Timestamp",
    "FromAddress",
    "ToAddress",
    "TokenContractAddress",
    "Type",
    "TokenSymbol",
    "TokensTransferred",
    "TransactionFee",
    "TransactionFeeCurrency",
    "Status",
    "ErrCode"
  ]

  @impl true
  def query(%Address{hash: address_hash}, from, to) do
    from_block = Chain.convert_date_to_min_block(from)
    to_block = Chain.convert_date_to_max_block(to)

    TokenTransfer
    |> join(:left, [tt], t in assoc(tt, :transaction), as: :transaction)
    |> order_by([transaction: transaction], desc: transaction.block_number, desc: transaction.index)
    |> Chain.where_block_number_in_period(from_block, to_block)
    |> where([tt], tt.from_address_hash == ^address_hash or tt.to_address_hash == ^address_hash)
  end

  @impl true
  def associations, do: @preloads

  @impl true
  def row_names, do: @row_header

  @impl true
  def transform(token_transfer, address) do
    [
      to_string(token_transfer.transaction_hash),
      token_transfer.block_number,
      token_transfer.block.timestamp,
      token_transfer.from_address_hash |> to_string() |> String.downcase(),
      token_transfer.to_address_hash |> to_string() |> String.downcase(),
      token_transfer.token_contract_address |> to_string() |> String.downcase(),
      type(token_transfer, address.hash),
      token_transfer.token.symbol,
      token_transfer.amount,
      fee(token_transfer.transaction),
      fee_currency(token_transfer.transaction),
      token_transfer.transaction.status,
      token_transfer.transaction.error
    ]
  end
end
