defmodule Explorer.Market.History.Historian do
  @moduledoc """
  Implements behaviour Historian for Market History. Compiles market history from a source and then saves it into the database.
  """
  use Explorer.History.Historian
  alias Explorer.History.Process, as: HistoryProcess
  alias Explorer.Market

  @behaviour Historian

  @impl Historian
  def compile_records(previous_days) do
    source =
      HistoryProcess.config_or_default(
        :source,
        Explorer.Market.History.Source.CryptoCompare,
        Explorer.Market.History.Historian
      )

    source.fetch_history(previous_days)
  end

  @impl Historian
  def save_records(records) do
    {num_inserted, _} = Market.bulk_insert_history(records)
    num_inserted
  end
end
