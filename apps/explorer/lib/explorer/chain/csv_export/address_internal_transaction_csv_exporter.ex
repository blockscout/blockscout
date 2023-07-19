defmodule Explorer.Chain.CSVExport.AddressInternalTransactionCsvExporter do
  @moduledoc """
  Exports internal transactions to a csv file.
  """

  alias Explorer.{Chain, PagingOptions}
  alias Explorer.Chain.{Address, Hash, Wei}
  alias Explorer.Chain.CSVExport.Helper

  @paging_options %PagingOptions{page_size: Helper.limit()}

  @spec export(Hash.Address.t(), String.t(), String.t(), String.t() | nil, String.t() | nil) :: Enumerable.t()
  def export(address_hash, from_period, to_period, filter_type \\ nil, filter_value \\ nil) do
    {from_block, to_block} = Helper.block_from_period(from_period, to_period)

    address_hash
    |> fetch_all_internal_transactions(from_block, to_block, filter_type, filter_value, @paging_options)
    |> Enum.sort_by(&{&1.block_number, &1.index, &1.transaction_index}, :desc)
    |> to_csv_format()
    |> Helper.dump_to_stream()
  end

  # sobelow_skip ["DOS.StringToAtom"]
  defp fetch_all_internal_transactions(
         address_hash,
         from_block,
         to_block,
         filter_type,
         filter_value,
         paging_options
       ) do
    options =
      []
      |> Keyword.put(:paging_options, paging_options)
      |> Keyword.put(:from_block, from_block)
      |> Keyword.put(:to_block, to_block)
      |> (&if(Helper.is_valid_filter?(filter_type, filter_value, "internal_transactions"),
            do: &1 |> Keyword.put(:direction, String.to_atom(filter_value)),
            else: &1
          )).()

    Chain.address_to_internal_transactions(address_hash, options)
  end

  defp to_csv_format(internal_transactions) do
    row_names = [
      "TxHash",
      "Index",
      "BlockNumber",
      "BlockHash",
      "TxIndex",
      "BlockIndex",
      "UnixTimestamp",
      "FromAddress",
      "ToAddress",
      "ContractAddress",
      "Type",
      "CallType",
      "Gas",
      "GasUsed",
      "Value",
      "Input",
      "Output",
      "ErrCode"
    ]

    internal_transaction_lists =
      internal_transactions
      |> Stream.map(fn internal_transaction ->
        [
          to_string(internal_transaction.transaction_hash),
          internal_transaction.index,
          internal_transaction.block_number,
          internal_transaction.block_hash,
          internal_transaction.block_index,
          internal_transaction.transaction_index,
          internal_transaction.block.timestamp,
          Address.checksum(internal_transaction.from_address_hash),
          Address.checksum(internal_transaction.to_address_hash),
          Address.checksum(internal_transaction.created_contract_address_hash),
          internal_transaction.type,
          internal_transaction.call_type,
          internal_transaction.gas,
          internal_transaction.gas_used,
          Wei.to(internal_transaction.value, :wei),
          internal_transaction.input,
          internal_transaction.output,
          internal_transaction.error
        ]
      end)

    Stream.concat([row_names], internal_transaction_lists)
  end
end
