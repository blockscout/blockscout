defmodule Explorer.Chain.CSVExport.AddressTokenTransferCsvExporter do
  @moduledoc """
  Exports token transfers to a csv file.
  """

  import Ecto.Query,
    only: [
      limit: 2,
      preload: 2,
      order_by: 3,
      where: 3
    ]

  alias Explorer.{Chain, PagingOptions, Repo}
  alias Explorer.Chain.{Address, Hash, TokenTransfer}
  alias Explorer.Chain.CSVExport.Helper

  @paging_options %PagingOptions{page_size: Helper.limit(), asc_order: true}

  @spec export(Hash.Address.t(), String.t(), String.t(), String.t() | nil, String.t() | nil) :: Enumerable.t()
  def export(address_hash, from_period, to_period, filter_type \\ nil, filter_value \\ nil) do
    {from_block, to_block} = Helper.block_from_period(from_period, to_period)

    address_hash
    |> fetch_all_token_transfers(from_block, to_block, filter_type, filter_value, @paging_options)
    |> to_csv_format(address_hash)
    |> Helper.dump_to_stream()
  end

  def fetch_all_token_transfers(
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
      |> Keyword.put(:filter_type, filter_type)
      |> Keyword.put(:filter_value, filter_value)

    address_hash_to_token_transfers_including_contract(address_hash, options)
  end

  defp to_csv_format(token_transfers, address_hash) do
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
          Address.checksum(token_transfer.from_address_hash),
          Address.checksum(token_transfer.to_address_hash),
          Address.checksum(token_transfer.token_contract_address_hash),
          type(token_transfer, address_hash),
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

  @doc """
  address_hash_to_token_transfers_including_contract/2 function returns token transfers on address (to/from/contract).
  It is used by CSV export of token transfers button.
  """
  @spec address_hash_to_token_transfers_including_contract(Hash.Address.t(), Keyword.t()) :: [TokenTransfer.t()]
  def address_hash_to_token_transfers_including_contract(address_hash, options \\ []) do
    paging_options = Keyword.get(options, :paging_options, Helper.default_paging_options())
    from_block = Keyword.get(options, :from_block)
    to_block = Keyword.get(options, :to_block)
    filter_type = Keyword.get(options, :filter_type)
    filter_value = Keyword.get(options, :filter_value)

    query =
      from_block
      |> query_address_hash_to_token_transfers_including_contract(to_block, address_hash, filter_type, filter_value)
      |> order_by([token_transfer], asc: token_transfer.block_number, asc: token_transfer.log_index)

    query
    |> handle_token_transfer_paging_options(paging_options)
    |> preload(transaction: :block)
    |> preload(:token)
    |> Repo.all()
  end

  defp query_address_hash_to_token_transfers_including_contract(nil, to_block, address_hash, filter_type, filter_value)
       when not is_nil(to_block) do
    TokenTransfer
    |> Helper.where_address_hash(address_hash, filter_type, filter_value)
    |> where([token_transfer], token_transfer.block_number <= ^to_block)
  end

  defp query_address_hash_to_token_transfers_including_contract(
         from_block,
         nil,
         address_hash,
         filter_type,
         filter_value
       )
       when not is_nil(from_block) do
    TokenTransfer
    |> Helper.where_address_hash(address_hash, filter_type, filter_value)
    |> where([token_transfer], token_transfer.block_number >= ^from_block)
  end

  defp query_address_hash_to_token_transfers_including_contract(
         from_block,
         to_block,
         address_hash,
         filter_type,
         filter_value
       )
       when not is_nil(from_block) and not is_nil(to_block) do
    TokenTransfer
    |> Helper.where_address_hash(address_hash, filter_type, filter_value)
    |> where([token_transfer], token_transfer.block_number >= ^from_block and token_transfer.block_number <= ^to_block)
  end

  defp query_address_hash_to_token_transfers_including_contract(_, _, address_hash, filter_type, filter_value) do
    TokenTransfer
    |> Helper.where_address_hash(address_hash, filter_type, filter_value)
  end

  defp handle_token_transfer_paging_options(query, nil), do: query

  defp handle_token_transfer_paging_options(query, paging_options) do
    query
    |> TokenTransfer.page_token_transfer(paging_options)
    |> limit(^paging_options.page_size)
  end
end
