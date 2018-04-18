defmodule ExplorerWeb.BlockView do
  use ExplorerWeb, :view

  alias Explorer.Chain.Block

  @dialyzer :no_match

  # Functions

  def age(%Block{timestamp: timestamp}) do
    Timex.from_now(timestamp)
  end

  def formatted_timestamp(%Block{timestamp: timestamp}) do
    Timex.format!(timestamp, "%b-%d-%Y %H:%M:%S %p %Z", :strftime)
  end
end
