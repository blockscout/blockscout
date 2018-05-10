defmodule Explorer.Market.MarketHistoryFactory do
  defmacro __using__(_opts) do
    quote do
      alias Explorer.Merket.MarketHistory
      alias Explorer.Repo

      def market_history_factory do
        %Explorer.Market.MarketHistory{
          closing_price: Decimal.new(Enum.random(1..10_000) / 100),
          opening_price: Decimal.new(Enum.random(1..10_000) / 100),
          date: Date.utc_today()
        }
      end
    end
  end
end
