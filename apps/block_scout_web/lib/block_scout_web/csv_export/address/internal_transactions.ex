# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.CsvExport.Address.InternalTransactions do
  @moduledoc """
  Exports internal transactions to a csv file.
  """

  import BlockScoutWeb.Chain, only: [address_to_internal_transactions: 2]

  alias Explorer.Chain.{Address, Hash, InternalTransaction, Transaction, Wei}
  alias Explorer.Chain.CsvExport.{AsyncHelper, Helper}
  alias Explorer.PagingOptions

  @doc """
  Streams the internal transactions of `address_hash` within the given period as CSV rows.

  The internal transactions missing in the DB are fetched from the node. When the node fails to trace a block of
  the period, it raises instead of exporting the internal transactions partly.

  ## Options

    - `:include_zero_value` - when `false`, zero-value call-type internal
      transactions are excluded, mirroring the `include_zero_value` query
      parameter of the paginated internal transactions endpoints. Defaults to `true`.
  """
  @spec export(Hash.Address.t(), String.t(), String.t(), Keyword.t(), String.t() | nil, String.t() | nil) ::
          Enumerable.t()
  def export(address_hash, from_period, to_period, options, filter_type, filter_value) do
    {from_block, to_block} = Helper.block_from_period(from_period, to_period)
    include_zero_value? = Keyword.get(options, :include_zero_value, true)

    address_hash
    |> fetch_all_internal_transactions(
      from_block,
      to_block,
      filter_type,
      filter_value,
      include_zero_value?,
      Helper.paging_options()
    )
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
         include_zero_value?,
         paging_options
       ) do
    options =
      []
      |> Keyword.put(:paging_options, paging_options)
      |> Keyword.put(:from_block, from_block)
      |> Keyword.put(:to_block, to_block)
      |> Keyword.put(:include_zero_value, include_zero_value?)
      |> Keyword.put(:timeout, AsyncHelper.db_timeout())
      |> (&if(Helper.valid_filter?(filter_type, filter_value, "internal_transactions"),
            do: &1 |> Keyword.put(:direction, String.to_atom(filter_value)),
            else: &1
          )).()

    fetch_internal_transactions_of_period(address_hash, options)
  end

  # The internal transactions missing in the DB are fetched from the node within a limited scan (see
  # `BlockScoutWeb.Chain.address_to_internal_transactions/2`), so the export goes on with the block where the scan
  # stopped until the period or the export limit is covered. A scan that doesn't get past the block it goes on with
  # means that the node fails to trace that block: the export fails then instead of leaving its internal transactions
  # out.
  defp fetch_internal_transactions_of_period(address_hash, options, fetched \\ [], last_next_block_number \\ nil) do
    case address_to_internal_transactions(address_hash, options) do
      {:ok, internal_transactions} ->
        fetched ++ internal_transactions

      {:incomplete, _internal_transactions, ^last_next_block_number} ->
        raise "Failed to fetch internal transactions of block #{last_next_block_number} from the node"

      {:incomplete, internal_transactions, next_block_number} ->
        %PagingOptions{page_size: page_size} = paging_options = Keyword.fetch!(options, :paging_options)

        next_options =
          options
          |> Keyword.put(:to_block, next_block_number)
          |> Keyword.put(:paging_options, %{paging_options | page_size: page_size - length(internal_transactions)})

        fetch_internal_transactions_of_period(
          address_hash,
          next_options,
          fetched ++ internal_transactions,
          next_block_number
        )
    end
  end

  defp to_csv_format(internal_transactions) do
    row_names = [
      "TxHash",
      "Index",
      "BlockNumber",
      "TxIndex",
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
      "ErrCode",
      "Fee"
    ]

    internal_transaction_lists =
      internal_transactions
      |> Stream.map(fn internal_transaction ->
        gas_price =
          internal_transaction.transaction &&
            (internal_transaction.transaction.gas_price ||
               Transaction.effective_gas_price(internal_transaction.transaction, internal_transaction.block))

        [
          to_string(internal_transaction.transaction_hash),
          internal_transaction.index,
          internal_transaction.block_number,
          internal_transaction.transaction_index,
          internal_transaction.block && internal_transaction.block.timestamp,
          Address.checksum(internal_transaction.from_address_hash),
          Address.checksum(internal_transaction.to_address_hash),
          Address.checksum(internal_transaction.created_contract_address_hash),
          internal_transaction.type,
          InternalTransaction.call_type(internal_transaction),
          internal_transaction.gas || "0",
          internal_transaction.gas_used,
          Wei.to(internal_transaction.value || Wei.zero(), :wei),
          internal_transaction.input,
          internal_transaction.output,
          internal_transaction.error,
          gas_price && internal_transaction.gas_used &&
            gas_price |> Wei.mult(internal_transaction.gas_used) |> Wei.to(:wei)
        ]
      end)

    Stream.concat([row_names], internal_transaction_lists)
  end
end
