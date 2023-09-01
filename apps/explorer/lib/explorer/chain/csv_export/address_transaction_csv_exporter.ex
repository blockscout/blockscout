defmodule Explorer.Chain.CSVExport.AddressTransactionCsvExporter do
  @moduledoc """
  Exports transactions to a csv file.
  """

  import Ecto.Query,
    only: [
      from: 2
    ]

  alias Explorer.{Chain, Market, PagingOptions, Repo}
  alias Explorer.Market.MarketHistory
  alias Explorer.Chain.{Address, Transaction, Wei}
  alias Explorer.Chain.CSVExport.Helper

  @necessity_by_association [
    necessity_by_association: %{
      :block => :required
    }
  ]

  @paging_options %PagingOptions{page_size: Helper.limit()}

  @spec export(Address.t(), String.t(), String.t(), String.t() | nil, String.t() | nil) :: Enumerable.t()
  def export(address_hash, from_period, to_period, filter_type \\ nil, filter_value \\ nil) do
    {from_block, to_block} = Helper.block_from_period(from_period, to_period)
    exchange_rate = Market.get_coin_exchange_rate()

    address_hash
    |> fetch_transactions(from_block, to_block, filter_type, filter_value, @paging_options)
    |> to_csv_format(address_hash, exchange_rate)
    |> Helper.dump_to_stream()
  end

  # sobelow_skip ["DOS.StringToAtom"]
  def fetch_transactions(address_hash, from_block, to_block, filter_type, filter_value, paging_options) do
    options =
      @necessity_by_association
      |> Keyword.put(:paging_options, paging_options)
      |> Keyword.put(:from_block, from_block)
      |> Keyword.put(:to_block, to_block)
      |> (&if(Helper.is_valid_filter?(filter_type, filter_value, "transactions"),
            do: &1 |> Keyword.put(:direction, String.to_atom(filter_value)),
            else: &1
          )).()

    Chain.address_to_transactions_without_rewards(address_hash, options)
  end

  defp to_csv_format(transactions, address_hash, exchange_rate) do
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
      "TxDateClosingPrice"
    ]

    date_to_prices =
      Enum.reduce(transactions, %{}, fn tx, acc ->
        date = DateTime.to_date(tx.block.timestamp)

        if Map.has_key?(acc, date) do
          acc
        else
          Map.put(acc, date, price_at_date(date))
        end
      end)

    transaction_lists =
      transactions
      |> Stream.map(fn transaction ->
        {opening_price, closing_price} = date_to_prices[DateTime.to_date(transaction.block.timestamp)]

        [
          to_string(transaction.hash),
          transaction.block_number,
          transaction.block.timestamp,
          Address.checksum(transaction.from_address_hash),
          Address.checksum(transaction.to_address_hash),
          Address.checksum(transaction.created_contract_address_hash),
          type(transaction, address_hash),
          Wei.to(transaction.value, :wei),
          fee(transaction),
          transaction.status,
          transaction.error,
          exchange_rate.usd_value,
          opening_price,
          closing_price
        ]
      end)

    Stream.concat([row_names], transaction_lists)
  end

  defp type(%Transaction{from_address_hash: address_hash}, address_hash), do: "OUT"

  defp type(%Transaction{to_address_hash: address_hash}, address_hash), do: "IN"

  defp type(_, _), do: ""

  defp fee(transaction) do
    transaction
    |> Chain.fee(:wei)
    |> case do
      {:actual, value} -> value
      {:maximum, value} -> "Max of #{value}"
    end
  end

  defp price_at_date(date) do
    query =
      from(
        mh in MarketHistory,
        where: mh.date == ^date
      )

    case Repo.one(query) do
      nil -> {nil, nil}
      price -> {price.opening_price, price.closing_price}
    end
  end
end
