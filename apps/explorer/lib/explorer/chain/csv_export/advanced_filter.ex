defmodule Explorer.Chain.CsvExport.AdvancedFilter do
  @moduledoc """
  Module responsible for exporting advanced filters to CSV.
  """

  alias Explorer.Chain.Address
  alias Explorer.Chain.CsvExport.Helper
  alias Explorer.Chain.{AdvancedFilter, TokenTransfer, MethodIdentifier}
  alias Explorer.Market
  alias Explorer.Market.MarketHistory

  @spec export(Keyword.t()) ::
          Enumerable.t()
  def export(full_options) do
    full_options
    |> AdvancedFilter.list()
    |> to_csv_format()
    |> Helper.dump_to_stream()
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
    token_transfer_total = prepare_token_transfer_total(advanced_filter.token_transfer)

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

  defp decimal_to_string(nil, _), do: nil
  defp decimal_to_string(decimal, type), do: Decimal.to_string(decimal, type)

  # duplicate of BlockScoutWeb.API.V2.TokenTransferView.prepare_token_transfer_total/1 but without the token_instance
  defp prepare_token_transfer_total(token_transfer) do
    case TokenTransfer.token_transfer_amount_for_api(token_transfer) do
      {:ok, :erc721_instance} ->
        %{
          "token_id" => token_transfer.token_ids && List.first(token_transfer.token_ids)
        }

      {:ok, :erc1155_erc404_instance, value, decimals} ->
        %{
          "token_id" => token_transfer.token_ids && List.first(token_transfer.token_ids),
          "value" => value,
          "decimals" => decimals
        }

      {:ok, :erc1155_erc404_instance, values, token_ids, decimals} ->
        %{
          "token_id" => token_ids && List.first(token_ids),
          "value" => values && List.first(values),
          "decimals" => decimals
        }

      {:ok, value, decimals} ->
        %{"value" => value, "decimals" => decimals}

      _ ->
        nil
    end
  end
end
