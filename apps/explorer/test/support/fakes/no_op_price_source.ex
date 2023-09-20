defmodule Explorer.ExchangeRates.Source.NoOpPriceSource do
  @moduledoc false

  alias Explorer.Market.History.Source.Price, as: SourcePrice

  @behaviour SourcePrice

  @impl SourcePrice
  def fetch_price_history(_previous_days) do
    {:ok, []}
  end
end
