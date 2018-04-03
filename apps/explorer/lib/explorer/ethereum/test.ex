defmodule Explorer.Ethereum.Test do
  @moduledoc """
  An interface for the Ethereum node that does not hit the network
  """
  @behaviour Explorer.Ethereum.API
  def download_balance(_hash) do
    "0x15d231fca629c7c0"
  end
end
