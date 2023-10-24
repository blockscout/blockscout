defmodule Explorer.Market.History.Source.TVL.DefiLlama do
  @moduledoc """
  Adapter for fetching current market from DefiLlama.
  """

  alias Explorer.ExchangeRates.Source
  alias Explorer.ExchangeRates.Source.DefiLlama, as: ExchangeRatesSourceDefiLlama
  alias Explorer.Market.History.Source.Price.CryptoCompare
  alias Explorer.Market.History.Source.TVL, as: SourceTVL

  @behaviour SourceTVL

  @impl SourceTVL
  def fetch_tvl(previous_days) do
    coin_id = Application.get_env(:explorer, Explorer.ExchangeRates.Source.DefiLlama, [])[:coin_id]

    if coin_id do
      url =
        ExchangeRatesSourceDefiLlama.history_url(previous_days) <>
          "/" <> coin_id

      case Source.http_request(url, ExchangeRatesSourceDefiLlama.headers()) do
        {:ok, data} ->
          result =
            data
            |> format_data()

          {:ok, result}

        _ ->
          :error
      end
    else
      {:ok, []}
    end
  end

  @spec format_data(term()) :: SourceTVL.record() | nil
  defp format_data(nil), do: nil

  defp format_data(data) do
    Enum.map(data, fn %{"date" => date, "tvl" => tvl} ->
      %{
        tvl: Decimal.new(to_string(tvl)),
        date: CryptoCompare.date(date)
      }
    end)
  end
end
