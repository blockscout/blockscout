defmodule Explorer.Chain.CsvExport.Address.Transactions do
  @moduledoc """
  Exports transactions to a csv file.
  """

  alias Explorer.Market
  alias Explorer.Market.MarketHistory
  alias Explorer.Chain.{Address, DenormalizationHelper, Hash, Transaction, Wei}
  alias Explorer.Chain.CsvExport.Helper

  @spec export(Hash.Address.t(), String.t(), String.t(), Keyword.t(), String.t() | nil, String.t() | nil) ::
          Enumerable.t()
  def export(address_hash, from_period, to_period, _options, filter_type \\ nil, filter_value \\ nil) do
    {from_block, to_block} = Helper.block_from_period(from_period, to_period)
    exchange_rate = Market.get_coin_exchange_rate()

    transactions =
      address_hash
      |> fetch_transactions(from_block, to_block, filter_type, filter_value, Helper.paging_options())

    transactions
    |> Transaction.decode_transactions(true, api?: true)
    |> Enum.zip(transactions)
    |> to_csv_format(address_hash, exchange_rate)
    |> Helper.dump_to_stream()
  end

  # sobelow_skip ["DOS.StringToAtom"]
  def fetch_transactions(address_hash, from_block, to_block, filter_type, filter_value, paging_options) do
    options =
      [necessity_by_association: %{[to_address: :smart_contract] => :optional}]
      |> DenormalizationHelper.extend_block_necessity(:required)
      |> Keyword.put(:paging_options, paging_options)
      |> Keyword.put(:from_block, from_block)
      |> Keyword.put(:to_block, to_block)
      |> (&if(Helper.valid_filter?(filter_type, filter_value, "transactions"),
            do: &1 |> Keyword.put(:direction, String.to_atom(filter_value)),
            else: &1
          )).()

    Transaction.address_to_transactions_without_rewards(address_hash, options)
  end

  defp to_csv_format(transactions_with_decoded_data, address_hash, exchange_rate) do
    row_names = [
      "TxHash",
      "BlockNumber",
      "UnixTimestamp",
      "FromAddress",
      "ToAddress",
      "ContractAddress",
      "Type",
      "Value",
      "Fee",
      "Status",
      "ErrCode",
      "CurrentPrice",
      "TxDateOpeningPrice",
      "TxDateClosingPrice",
      "MethodName"
    ]

    date_to_prices =
      Enum.reduce(transactions_with_decoded_data, %{}, fn {_decoded_data, transaction}, acc ->
        date = transaction |> Transaction.block_timestamp() |> DateTime.to_date()

        if Map.has_key?(acc, date) do
          acc
        else
          market_history = MarketHistory.price_at_date(date)

          Map.put(
            acc,
            date,
            {market_history && market_history.opening_price, market_history && market_history.closing_price}
          )
        end
      end)

    transaction_lists =
      transactions_with_decoded_data
      |> Stream.map(fn {decoded_data, transaction} ->
        {opening_price, closing_price} = date_to_prices[DateTime.to_date(Transaction.block_timestamp(transaction))]

        [
          to_string(transaction.hash),
          transaction.block_number,
          Transaction.block_timestamp(transaction),
          Address.checksum(transaction.from_address_hash),
          Address.checksum(transaction.to_address_hash),
          Address.checksum(transaction.created_contract_address_hash),
          type(transaction, address_hash),
          Wei.to(transaction.value, :wei),
          fee(transaction),
          transaction.status,
          transaction.error,
          exchange_rate.fiat_value,
          opening_price,
          closing_price,
          Transaction.method_name(transaction, decoded_data)
        ]
      end)

    Stream.concat([row_names], transaction_lists)
  end

  defp type(%Transaction{from_address_hash: address_hash}, address_hash), do: "OUT"

  defp type(%Transaction{to_address_hash: address_hash}, address_hash), do: "IN"

  defp type(_, _), do: ""

  defp fee(transaction) do
    transaction
    |> Transaction.fee(:wei)
    |> case do
      {:actual, value} -> value
      {:maximum, value} -> "Max of #{value}"
    end
  end
end
