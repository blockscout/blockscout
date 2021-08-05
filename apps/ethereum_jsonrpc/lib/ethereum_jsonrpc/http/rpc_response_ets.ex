defmodule EthereumJSONRPC.HTTP.RpcResponseEts do
  @moduledoc """
  Create and manage an ETS table that keeps the start and end time of json-rpc requests and deletes them after they've
  been processed for metrics or in case of error.
  """
  use GenServer

  def init(arg) do
    :ets.new(:wrapper, [
      :bag,
      :public,
      :named_table,
      {:read_concurrency, true},
      {:write_concurrency, true}
    ])

    {:ok, arg}
  end

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def get_all do
    :ets.tab2list(:wrapper)
  end

  def put(key, value) do
    :ets.insert(:wrapper, {key, value})
  end

  def delete(key) do
    :ets.delete(:wrapper, key)
  end
end
