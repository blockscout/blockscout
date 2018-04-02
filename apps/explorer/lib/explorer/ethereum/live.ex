defmodule Explorer.Ethereum.Live do
  @moduledoc """
  An implementation for Ethereum that uses the actual node.
  """

  @behaviour Explorer.Ethereum.API

  import Ethereumex.HttpClient, only: [eth_get_balance: 1]

  def download_balance(hash) do
    {:ok, result} = eth_get_balance(hash)
    result
  end
end
