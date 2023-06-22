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
      [created_contract_address: :names] => :optional,
      [from_address: :names] => :optional,
      [to_address: :names] => :optional,
      [token_transfers: :token] => :optional,
      [token_transfers: :to_address] => :optional,
      [token_transfers: :from_address] => :optional,
      [token_transfers: :token_contract_address] => :optional,
      :block => :required
    }
  ]

  @paging_options %PagingOptions{page_size: Helper.page_size() + 1}

  @spec export(Address.t(), String.t(), String.t(), String.t() | nil, String.t() | nil) :: Enumerable.t()
  def export(address, from_period, to_period, filter_type \\ nil, filter_value \\ nil) do
    {from_block, to_block} = Helper.block_from_period(from_period, to_period)
    exchange_rate = Market.get_coin_exchange_rate()

    address.hash
    |> fetch_all_transactions(from_block, to_block, filter_type, filter_value, @paging_options)
    |> to_csv_format(address, exchange_rate)
    |> Helper.dump_to_stream()
  end

  # sobelow_skip ["DOS.StringToAtom"]
  def fetch_all_transactions(address_hash, from_block, to_block, filter_type, filter_value, paging_options, acc \\ []) do
    options =
      @necessity_by_association
      |> Keyword.put(:paging_options, paging_options)
      |> Keyword.put(:from_block, from_block)
      |> Keyword.put(:to_block, to_block)
      |> (&if(Helper.is_valid_filter?(filter_type, filter_value, "transactions"),
            do: &1 |> Keyword.put(:direction, String.to_atom(filter_value)),
            else: &1
          )).()

    transactions = Chain.address_to_transactions_without_rewards(address_hash, options)
    new_acc = transactions ++ acc

    case Enum.split(transactions, Helper.page_size()) do
      {_transactions, [%Transaction{block_number: block_number, index: index}]} ->
        new_paging_options = %{@paging_options | key: {block_number, index}}

        fetch_all_transactions(
          address_hash,
          from_block,
          to_block,
          filter_type,
          filter_value,
          new_paging_options,
          new_acc
        )

      {_, []} ->
        new_acc
    end
  end

  defp to_csv_format(transactions, address, exchange_rate) do
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

    transaction_lists =
      transactions
      |> Stream.map(fn transaction ->
        {opening_price, closing_price} = price_at_date(transaction.block.timestamp)

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

  defp price_at_date(datetime) do
    date = DateTime.to_date(datetime)

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
