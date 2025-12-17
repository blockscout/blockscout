defmodule BlockScoutWeb.API.V2.AdvancedFilterView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.API.V2.{Helper, TokenTransferView, TokenView, TransactionView}
  alias Explorer.Chain.{Address, AdvancedFilter, Data, MethodIdentifier, Transaction}
  alias Explorer.Market
  alias Explorer.Market.MarketHistory

  def render("advanced_filters.json", %{
        advanced_filters: advanced_filters,
        decoded_transactions: decoded_transactions,
        search_params: %{
          method_ids: method_ids,
          tokens: tokens
        },
        next_page_params: next_page_params
      }) do
    %{
      items:
        advanced_filters
        |> Enum.zip(decoded_transactions)
        |> Enum.map(fn {af, decoded_input} -> prepare_advanced_filter(af, decoded_input) end),
      search_params: prepare_search_params(method_ids, tokens),
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
      "CreatedContractAddress",
      "Value",
      "TokenContractAddressHash",
      "TokenDecimals",
      "TokenSymbol",
      "TokenValue",
      "TokenID",
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
            %{bytes: <<method_id::binary-size(4), _::binary>>} ->
              {:ok, method_id} = MethodIdentifier.cast(method_id)
              to_string(method_id)

            _ ->
              nil
          end

        {opening_price, closing_price} = date_to_prices[DateTime.to_date(advanced_filter.timestamp)]

        prepare_advanced_filter_csv_row(advanced_filter, exchange_rate, opening_price, closing_price, method_id)
      end)

    Stream.concat([row_names], af_lists)
  end

  defp prepare_advanced_filter_csv_row(
         %AdvancedFilter{created_from: :token_transfer} = advanced_filter,
         _exchange_rate,
         _opening_price,
         _closing_price,
         method_id
       ) do
    token_transfer_total = TokenTransferView.prepare_token_transfer_total(advanced_filter.token_transfer)

    [
      to_string(advanced_filter.hash),
      advanced_filter.type,
      method_id,
      advanced_filter.timestamp,
      Address.checksum(advanced_filter.from_address_hash),
      Address.checksum(advanced_filter.to_address_hash),
      Address.checksum(advanced_filter.created_contract_address_hash),
      decimal_to_string(advanced_filter.value, :normal),
      Address.checksum(advanced_filter.token_transfer.token.contract_address_hash),
      decimal_to_string(token_transfer_total["decimals"], :normal),
      advanced_filter.token_transfer.token.symbol,
      case token_transfer_total["decimals"] do
        nil ->
          decimal_to_string(token_transfer_total["value"], :xsd)

        decimals ->
          token_transfer_total["value"] &&
            token_transfer_total["value"]
            |> Decimal.div(Integer.pow(10, Decimal.to_integer(decimals)))
            |> decimal_to_string(:xsd)
      end,
      token_transfer_total["token_id"],
      advanced_filter.block_number,
      decimal_to_string(advanced_filter.fee, :normal),
      nil,
      nil,
      nil
    ]
  end

  defp prepare_advanced_filter_csv_row(
         advanced_filter,
         exchange_rate,
         opening_price,
         closing_price,
         method_id
       ) do
    [
      to_string(advanced_filter.hash),
      advanced_filter.type,
      method_id,
      advanced_filter.timestamp,
      Address.checksum(advanced_filter.from_address_hash),
      Address.checksum(advanced_filter.to_address_hash),
      Address.checksum(advanced_filter.created_contract_address_hash),
      decimal_to_string(advanced_filter.value, :normal),
      nil,
      nil,
      nil,
      nil,
      nil,
      advanced_filter.block_number,
      decimal_to_string(advanced_filter.fee, :normal),
      decimal_to_string(exchange_rate.fiat_value, :xsd),
      decimal_to_string(opening_price, :xsd),
      decimal_to_string(closing_price, :xsd)
    ]
  end

  defp prepare_advanced_filter(advanced_filter, decoded_input) do
    %{
      hash: advanced_filter.hash,
      type: advanced_filter.type,
      status: TransactionView.format_status(advanced_filter.status),
      method:
        if(advanced_filter.created_from == :token_transfer,
          do:
            Transaction.method_name(
              %Transaction{
                to_address: %Address{
                  hash: advanced_filter.token_transfer.token.contract_address_hash,
                  contract_code: "0x" |> Data.cast() |> elem(1)
                },
                input: advanced_filter.input
              },
              decoded_input
            ),
          else:
            Transaction.method_name(
              %Transaction{to_address: advanced_filter.to_address, input: advanced_filter.input},
              decoded_input
            )
        ),
      from:
        Helper.address_with_info(
          nil,
          advanced_filter.from_address,
          advanced_filter.from_address_hash,
          false
        ),
      to:
        Helper.address_with_info(
          nil,
          advanced_filter.to_address,
          advanced_filter.to_address_hash,
          false
        ),
      created_contract:
        Helper.address_with_info(
          nil,
          advanced_filter.created_contract_address,
          advanced_filter.created_contract_address_hash,
          false
        ),
      value: advanced_filter.value,
      total:
        if(advanced_filter.created_from == :token_transfer,
          do: TokenTransferView.prepare_token_transfer_total(advanced_filter.token_transfer),
          else: nil
        ),
      token:
        if(advanced_filter.created_from == :token_transfer,
          do: TokenView.render("token.json", %{token: advanced_filter.token_transfer.token}),
          else: nil
        ),
      timestamp: advanced_filter.timestamp,
      block_number: advanced_filter.block_number,
      transaction_index: advanced_filter.transaction_index,
      internal_transaction_index: advanced_filter.internal_transaction_index,
      token_transfer_index: advanced_filter.token_transfer_index,
      token_transfer_batch_index: advanced_filter.token_transfer_batch_index,
      fee: advanced_filter.fee
    }
  end

  defp prepare_search_params(method_ids, tokens) do
    tokens_map =
      Map.new(tokens, fn {contract_address_hash, token} ->
        {contract_address_hash, TokenView.render("token.json", %{token: token})}
      end)

    %{methods: method_ids, tokens: tokens_map}
  end

  defp decimal_to_string(nil, _), do: nil
  defp decimal_to_string(decimal, type), do: Decimal.to_string(decimal, type)
end
