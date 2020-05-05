defmodule Explorer.Market.History.Source.BW do
  @moduledoc """
  Adapter for fetching market history from https://bw.com.

  The history is fetched for the configured coin. You can specify a
  different coin by changing the targeted coin.

      # In config.exs
      config :explorer, coin: "VLX"

  """

  alias Explorer.Market.History.Source
  alias HTTPoison.Response

  @behaviour Source

  @typep unix_timestamp :: non_neg_integer()

  @impl Source
  def fetch_history(previous_days) do
    url = history_url(previous_days)
    headers = [{"Content-Type", "application/json"}]

    case HTTPoison.get(url, headers) do
      {:ok, %Response{body: body, status_code: 200}} ->
        result =
          body
          |> format_data()
          |> reject_zeros()

        {:ok, result}

      _ ->
        :error
    end
  end

  @spec trade_pair :: String.t()
  defp trade_pair do
    String.downcase(Explorer.coin()) <> "_usdt"
  end

  # @spec market_id :: String.t()
  # defp market_id do
  #   url = "#{base_url()}/exchange/config/controller/website/marketcontroller/getByWebId"
  #   headers = [{"Content-Type", "application/json"}]

  #   {:ok, pairs} = case HTTPoison.get(url, headers) do
  #     {:ok, %Response{body: body, status_code: 200}} ->
  #       {:ok, Jason.decode!(body)}

  #     _ ->
  #       :error
  #   end

  #   pair_data =
  #     Enum.find(pairs["datas"], fn item ->
  #       item["name"] == trade_pair()
  #     end)

  #   pair_data["marketId"]
  # end

  @spec base_url :: String.t()
  defp base_url do
    configured_url = Application.get_env(:explorer, __MODULE__, [])[:base_url]
    configured_url || "https://www.bw.com"
  end

  @spec date(unix_timestamp()) :: Date.t()
  defp date(unix_timestamp) do
    unix_timestamp
    |> DateTime.from_unix!()
    |> DateTime.to_date()
  end

  @spec format_data(String.t()) :: [Source.record()]
  defp format_data(data) do
    json = Jason.decode!(data)
    for item <- json["datas"] do
      %{
        closing_price: Decimal.new(to_string(Enum.at(item, 7))),
        date: date(Enum.at(item, 3) |> String.to_integer()),
        opening_price: Decimal.new(to_string(Enum.at(item, 4)))
      }
    end
  end

  @spec history_url(non_neg_integer()) :: String.t()
  defp history_url(previous_days) do
    "#{base_url()}/api/data/v1/klines?marketName=#{trade_pair()}&type=1D&dataSize=#{previous_days}"
  end

  defp reject_zeros(items) do
    Enum.reject(items, fn item ->
      Decimal.equal?(item.closing_price, 0) && Decimal.equal?(item.opening_price, 0)
    end)
  end
end
