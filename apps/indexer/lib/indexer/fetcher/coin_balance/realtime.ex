defmodule Indexer.Fetcher.CoinBalance.Realtime do
  @moduledoc """
  Separate version of `Indexer.Fetcher.CoinBalance.Catchup` for fetching balances from realtime block fetcher
  """

  use Indexer.Fetcher, restart: :permanent
  use Spandex.Decorators

  alias Explorer.Chain.{Block, Hash}
  alias Indexer.{BufferedTask, Tracer}
  alias Indexer.Fetcher.CoinBalance.Helper

  @behaviour BufferedTask

  @default_max_batch_size 500
  @default_max_concurrency 4

  @doc """
  Asynchronously fetches balances for each address `hash` at the `block_number`.
  """
  @spec async_fetch_balances([
          %{required(:address_hash) => Hash.Address.t(), required(:block_number) => Block.block_number()}
        ]) :: :ok
  def async_fetch_balances(balance_fields) when is_list(balance_fields) do
    entries = Enum.map(balance_fields, &Helper.entry/1)

    BufferedTask.buffer(__MODULE__, entries, true)
  end

  def child_spec(params) do
    Helper.child_spec(params, defaults(), __MODULE__)
  end

  @impl BufferedTask
  def init(_, _, _) do
    {0, []}
  end

  @impl BufferedTask
  @decorate trace(
              name: "fetch",
              resource: "Indexer.Fetcher.CoinBalance.Realtime.run/2",
              service: :indexer,
              tracer: Tracer
            )
  def run(entries, json_rpc_named_arguments) do
    Helper.run(entries, json_rpc_named_arguments, :realtime)
  end

  defp defaults do
    [
      poll: false,
      flush_interval: :timer.seconds(3),
      max_batch_size: Application.get_env(:indexer, __MODULE__)[:batch_size] || @default_max_batch_size,
      max_concurrency: Application.get_env(:indexer, __MODULE__)[:concurrency] || @default_max_concurrency,
      task_supervisor: Indexer.Fetcher.CoinBalance.Realtime.TaskSupervisor,
      metadata: [fetcher: :coin_balance_realtime]
    ]
  end
end
