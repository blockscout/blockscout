defmodule Explorer.LatestBlock do
  alias Explorer.Fetcher
  import Ethereumex.HttpClient, only: [eth_block_number: 0]

  @moduledoc false

  @dialyzer {:nowarn_function, fetch: 0}
  def fetch do
    get_latest_block() |> Fetcher.fetch
  end

  def get_latest_block do
    {:ok, block_number} = eth_block_number()
    block_number
  end
end
