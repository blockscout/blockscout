defmodule Explorer.ExchangeRates.Source.NoOpSource do
  @moduledoc false

  alias Explorer.ExchangeRates.Source

  @behaviour Source

  @impl Source
  def fetch_exchange_rates, do: {:ok, []}
end
