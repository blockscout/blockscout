defmodule ExplorerWeb.BlockView do
  use ExplorerWeb, :view

  alias Explorer.Chain.{Block, Wei}

  @dialyzer :no_match

  # Functions

  def age(%Block{timestamp: timestamp}) do
    Timex.from_now(timestamp)
  end

  def formatted_timestamp(%Block{timestamp: timestamp}) do
    Timex.format!(timestamp, "%b-%d-%Y %H:%M:%S %p %Z", :strftime)
  end

  def to_gwei(%Wei{} = wei) do
    Wei.to(wei, :gwei)
  end
end
