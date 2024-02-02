defmodule Explorer.Chain.CSVExport.Helper do
  @moduledoc """
  CSV export helper functions.
  """

  alias Explorer.Chain
  alias NimbleCSV.RFC4180

  @page_size 150

  def dump_to_stream(items) do
    res =
      items
      |> RFC4180.dump_to_stream()

    res
  end

  def page_size do
    @page_size
  end

  def block_from_period(from_period, to_period) do
    from_block = Chain.convert_date_to_min_block(from_period)
    to_block = Chain.convert_date_to_max_block(to_period)

    {from_block, to_block}
  end
end
