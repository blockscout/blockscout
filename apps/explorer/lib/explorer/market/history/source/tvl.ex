defmodule Explorer.Market.History.Source.TVL do
  @moduledoc """
  Interface for a source that allows for fetching of TVL history.
  """

  @typedoc """
  Record of market values for a specific date.
  """
  @type record :: %{
          date: Date.t(),
          tvl: Decimal.t()
        }

  @doc """
  Fetch history for a specified amount of days in the past.
  """
  @callback fetch_tvl(previous_days :: non_neg_integer()) :: {:ok, [record()]} | :error
end
