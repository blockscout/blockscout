defmodule Explorer.Chain.AddressTokenTransferCsvExporter do
  @moduledoc """
  Exports token transfers to a csv file.
  """

  alias Explorer.{Chain, PagingOptions}
  alias Explorer.Chain.{Address, TokenTransfer}
  alias NimbleCSV.RFC4180

  @page_size 150
  @paging_options %PagingOptions{page_size: @page_size + 1, asc_order: true}

  @spec export(Address.t(), String.t(), String.t()) :: Enumerable.t()
  def export(address, from_period, to_period) do
    from_block = Chain.convert_date_to_min_block(from_period)
    to_block = Chain.convert_date_to_max_block(to_period)

    address.hash
    |> fetch_all_token_transfers(from_block, to_block, @paging_options)
    |> to_csv_format(address)
    |> dump_to_stream()
  end

  def fetch_all_token_transfers(address_hash, from_block, to_block, paging_options, acc \\ []) do
    options =
      []
      |> Keyword.put(:paging_options, paging_options)
      |> Keyword.put(:from_block, from_block)
      |> Keyword.put(:to_block, to_block)

    token_transfers = Chain.address_hash_to_token_transfers_including_contract(address_hash, options)

    new_acc = acc ++ token_transfers

    case Enum.split(token_transfers, @page_size) do
      {_token_transfers, [%TokenTransfer{block_number: block_number, log_index: log_index}]} ->
        new_paging_options = %{@paging_options | key: {block_number, log_index}}
        fetch_all_token_transfers(address_hash, from_block, to_block, new_paging_options, new_acc)

      {_, []} ->
        new_acc
    end
  end

  defp dump_to_stream(transactions) do
    transactions
    |> RFC4180.dump_to_stream()
  end

  defp to_csv_format(token_transfers, address) do
    row_names = [
      "TxHash",
      "BlockNumber",
      "UnixTimestamp",
      "FromAddress",
      "ToAddress",
      "TokenContractAddress",
      "Type",
      "TokenSymbol",
      "TokensTransferred",
      "TransactionFee",
      "Status",
      "ErrCode"
    ]

    token_transfer_lists =
      token_transfers
      |> Stream.map(fn token_transfer ->
        [
          to_string(token_transfer.transaction_hash),
          token_transfer.transaction.block_number,
          token_transfer.transaction.block.timestamp,
          token_transfer.from_address_hash |> to_string() |> String.downcase(),
          token_transfer.to_address_hash |> to_string() |> String.downcase(),
          token_transfer.token_contract_address_hash |> to_string() |> String.downcase(),
          type(token_transfer, address.hash),
          token_transfer.token.symbol,
          token_transfer.amount,
          fee(token_transfer.transaction),
          token_transfer.transaction.status,
          token_transfer.transaction.error
        ]
      end)

    Stream.concat([row_names], token_transfer_lists)
  end

  defp type(%TokenTransfer{from_address_hash: address_hash}, address_hash), do: "OUT"

  defp type(%TokenTransfer{to_address_hash: address_hash}, address_hash), do: "IN"

  defp type(_, _), do: ""

  defp fee(transaction) do
    transaction
    |> Chain.fee(:wei)
    |> case do
      {:actual, value} -> value
      {:maximum, value} -> "Max of #{value}"
    end
  end
end
