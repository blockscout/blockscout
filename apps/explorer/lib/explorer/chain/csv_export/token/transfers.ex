# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.CsvExport.Token.Transfers do
  @moduledoc """
  Exports token transfers for a specific token to a csv file.
  """

  import Ecto.Query,
    only: [
      limit: 2,
      order_by: 3,
      preload: 2,
      where: 3
    ]

  alias Explorer.Chain
  alias Explorer.Chain.{Address, DenormalizationHelper, Hash, TokenTransfer, Transaction}
  alias Explorer.Chain.CsvExport.{AsyncHelper, Helper}
  alias Explorer.{PagingOptions, Repo}

  @spec export(Hash.Address.t(), String.t(), String.t(), Keyword.t(), String.t() | nil, String.t() | nil) ::
          Enumerable.t()
  def export(token_address_hash, from_period, to_period, _options, _filter_type, _filter_value) do
    {from_block, to_block} = Helper.block_from_period(from_period, to_period)

    {:ok, token} = Chain.token_from_address_hash(token_address_hash, api?: true)

    paging_options = %PagingOptions{Helper.paging_options() | asc_order: true}

    token_address_hash
    |> fetch_all_token_transfers(from_block, to_block, paging_options)
    |> to_csv_format(token)
    |> Helper.dump_to_stream()
  end

  defp fetch_all_token_transfers(token_address_hash, from_block, to_block, paging_options) do
    token_address_hash
    |> token_transfers_query(from_block, to_block)
    |> order_by([tt], asc: tt.block_number, asc: tt.log_index)
    |> TokenTransfer.page_token_transfer(paging_options)
    |> limit(^paging_options.page_size)
    |> preload(^DenormalizationHelper.extend_transaction_preload([:transaction]))
    |> Repo.replica().all(timeout: AsyncHelper.db_timeout())
  end

  defp token_transfers_query(token_address_hash, from_block, to_block)
       when not is_nil(from_block) and not is_nil(to_block) do
    TokenTransfer.only_consensus_transfers_query()
    |> where([tt], tt.token_contract_address_hash == ^token_address_hash and not is_nil(tt.block_number))
    |> where([tt], tt.block_number >= ^from_block and tt.block_number <= ^to_block)
  end

  defp token_transfers_query(token_address_hash, from_block, nil) when not is_nil(from_block) do
    TokenTransfer.only_consensus_transfers_query()
    |> where([tt], tt.token_contract_address_hash == ^token_address_hash and not is_nil(tt.block_number))
    |> where([tt], tt.block_number >= ^from_block)
  end

  defp token_transfers_query(token_address_hash, nil, to_block) when not is_nil(to_block) do
    TokenTransfer.only_consensus_transfers_query()
    |> where([tt], tt.token_contract_address_hash == ^token_address_hash and not is_nil(tt.block_number))
    |> where([tt], tt.block_number <= ^to_block)
  end

  defp token_transfers_query(token_address_hash, _from_block, _to_block) do
    TokenTransfer.only_consensus_transfers_query()
    |> where([tt], tt.token_contract_address_hash == ^token_address_hash and not is_nil(tt.block_number))
  end

  defp to_csv_format(token_transfers, token) do
    row_names = [
      "TxHash",
      "BlockNumber",
      "UnixTimestamp",
      "FromAddress",
      "ToAddress",
      "TokenContractAddress",
      "TokenDecimals",
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
          Transaction.block_timestamp(token_transfer.transaction),
          Address.checksum(token_transfer.from_address_hash),
          Address.checksum(token_transfer.to_address_hash),
          Address.checksum(token_transfer.token_contract_address_hash),
          token.decimals,
          token.symbol,
          token_transfer.amount,
          fee(token_transfer.transaction),
          token_transfer.transaction.status,
          token_transfer.transaction.error
        ]
      end)

    Stream.concat([row_names], token_transfer_lists)
  end

  defp fee(transaction) do
    transaction
    |> Transaction.fee(:wei)
    |> case do
      {:actual, value} -> value
      {:maximum, value} -> "Max of #{value}"
    end
  end
end
