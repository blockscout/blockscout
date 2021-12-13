defmodule Explorer.Export.CSV.Exporter do
  @moduledoc "A behavior to define required functionality for a type of CSV export."

  alias Explorer.Chain.Address

  @doc "Returns a list of CSV headers to be used when generating output"
  @callback row_names() :: [String.t()]

  @doc "A list of foreign key associations that should be fetched with the record to get all necessary data for output"
  @callback associations() :: list(term())

  @doc "Transforms a given struct into a list to be sent to the csv lib"
  @callback transform(object :: term(), address :: Address.t()) :: list(term())

  @doc "Creates an Ecto query to be used to fetch all applicable records within a timeframe"
  @callback query(address :: Address.t(), from_period :: String.t(), to_period :: String.t()) :: Ecto.Query.t()
end
