defmodule Explorer.Export.CSV.TransactionExporter do
  @moduledoc "Export all Transaction instances for a given account between two dates"

  import Ecto.Query
  alias Explorer.Chain
  alias Explorer.Chain.{Address, Transaction, Wei}
  import Explorer.Export.CSV.Utils

  @behaviour Explorer.Export.CSV.Exporter

  @preloads [
    created_contract_address: [],
    from_address: [],
    to_address: [],
    gas_currency: :token,
    block: []
  ]

  @row_header [
    "TxHash",
    "BlockNumber",
    "Timestamp",
    "FromAddress",
    "ToAddress",
    "CreatedContractAddress",
    "Type",
    "Value",
    "Fee",
    "FeeCurrency",
    "Status",
    "ErrCode"
  ]

  @impl true
  def query(%Address{hash: address_hash}, from, to) do
    from_block = Chain.convert_date_to_min_block(from)
    to_block = Chain.convert_date_to_max_block(to)

    Transaction
    |> order_by([transaction], desc: transaction.block_number, desc: transaction.index)
    |> Chain.where_block_number_in_period(from_block, to_block)
    |> where(
      [t],
      t.from_address_hash == ^address_hash or t.to_address_hash == ^address_hash or
        t.created_contract_address_hash == ^address_hash
    )
  end

  @impl true
  def associations, do: @preloads

  @impl true
  def row_names, do: @row_header

  @impl true
  def transform(transaction, address) do
    [
      to_string(transaction.hash),
      transaction.block_number,
      transaction.block.timestamp,
      to_string(transaction.from_address),
      to_string(transaction.to_address),
      to_string(transaction.created_contract_address),
      type(transaction, address.hash),
      Wei.to(transaction.value, :wei),
      fee(transaction),
      fee_currency(transaction),
      transaction.status,
      transaction.error
    ]
  end
end
