defmodule ExplorerWeb.BlockView do
  use ExplorerWeb, :view

  alias Explorer.Chain.Block

  @dialyzer :no_match

  def age(%Block{timestamp: timestamp}) do
    Timex.from_now(timestamp)
  end

  def formatted_timestamp(%Block{timestamp: timestamp}) do
    Timex.format!(timestamp, "%b-%d-%Y %H:%M:%S %p %Z", :strftime)
  end

  def hash(%Block{hash: hash}) do
    to_string(hash)
  end

  def miner_hash(%Block{miner_hash: miner_hash}) do
    to_string(miner_hash)
  end

  def parent_hash(%Block{parent_hash: parent_hash}) do
    to_string(parent_hash)
  end
end
