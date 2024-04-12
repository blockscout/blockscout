defmodule BlockScoutWeb.API.V2.AdvancedFilterView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.V2.{Helper, TokenView, TransactionView}
  alias Explorer.Chain.{Address, Transaction}
  alias Explorer.Market
  alias Explorer.Market.MarketHistory

  def render("advanced_filters.json", %{advanced_filters: advanced_filters, next_page_params: next_page_params}) do
    {decoded_transactions, _, _} =
      advanced_filters
      |> Enum.map(fn af -> %Transaction{to_address: af.to_address, input: af.input, hash: af.hash} end)
      |> TransactionView.decode_transactions(true)

    %{
      items:
        advanced_filters
        |> Enum.zip(decoded_transactions)
        |> Enum.map(fn {af, decoded_input} -> prepare_advanced_filter(af, decoded_input) end),
      next_page_params: next_page_params
    }
  end

  def render("methods.json", %{methods: methods}) do
    methods
  end

  def to_csv_format(advanced_filters) do
    exchange_rate = Market.get_coin_exchange_rate()

    date_to_prices =
      Enum.reduce(advanced_filters, %{}, fn af, acc ->
        date = DateTime.to_date(af.timestamp)

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

    row_names = [
      "TxHash",
      "Type",
      "MethodId",
      "UtcTimestamp",
      "FromAddress",
      "ToAddress",
      "Value",
      "TokenContractAddressHash",
      "TokenDecimals",
      "TokenSymbol",
      "BlockNumber",
      "Fee",
      "CurrentPrice",
      "TxDateOpeningPrice",
      "TxDateClosingPrice"
    ]

    af_lists =
      advanced_filters
      |> Stream.map(fn advanced_filter ->
        method_id =
          case advanced_filter.input do
            %{bytes: <<method_id::binary-size(4), _::binary>>} -> method_id
            _ -> nil
          end

        {opening_price, closing_price} = date_to_prices[DateTime.to_date(advanced_filter.timestamp)]

        [
          to_string(advanced_filter.hash),
          advanced_filter.type,
          method_id,
          advanced_filter.timestamp,
          Address.checksum(advanced_filter.from_address.hash),
          Address.checksum(advanced_filter.to_address.hash),
          advanced_filter.value,
          if(advanced_filter.type != "coin_transfer",
            do: advanced_filter.token_transfer.token.contract_address_hash,
            else: nil
          ),
          if(advanced_filter.type != "coin_transfer", do: advanced_filter.token_transfer.token.decimals, else: nil),
          if(advanced_filter.type != "coin_transfer", do: advanced_filter.token_transfer.token.symbol, else: nil),
          advanced_filter.block_number,
          advanced_filter.fee,
          exchange_rate.usd_value,
          opening_price,
          closing_price
        ]
      end)

    Stream.concat([row_names], af_lists)
  end

  defp prepare_advanced_filter(advanced_filter, decoded_input) do
    %{
      hash: advanced_filter.hash,
      type: advanced_filter.type,
      raw_input: advanced_filter.input,
      method:
        TransactionView.method_name(
          %Transaction{to_address: advanced_filter.to_address, input: advanced_filter.input},
          decoded_input
        ),
      from:
        Helper.address_with_info(
          nil,
          advanced_filter.from_address,
          advanced_filter.from_address.hash,
          false
        ),
      to:
        Helper.address_with_info(
          nil,
          advanced_filter.to_address,
          advanced_filter.to_address.hash,
          false
        ),
      value: advanced_filter.value,
      total:
        if(advanced_filter.type != "coin_transfer",
          do: TransactionView.prepare_token_transfer_total(advanced_filter.token_transfer),
          else: nil
        ),
      token:
        if(advanced_filter.type != "coin_transfer",
          do: TokenView.render("token.json", %{token: advanced_filter.token_transfer.token}),
          else: nil
        ),
      timestamp: advanced_filter.timestamp,
      block_number: advanced_filter.block_number,
      transaction_index: advanced_filter.transaction_index,
      internal_transaction_index: advanced_filter.internal_transaction_index,
      token_transfer_index: advanced_filter.token_transfer_index
    }
  end
end
