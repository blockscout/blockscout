defmodule Indexer.Fetcher.CoinBalance.Catchup do
  @moduledoc """
  Fetches `t:Explorer.Chain.Address.CoinBalance.t/0` and updates `t:Explorer.Chain.Address.t/0` `fetched_coin_balance` and
  `fetched_coin_balance_block_number` to value at max `t:Explorer.Chain.Address.CoinBalance.t/0` `block_number` for the given `t:Explorer.Chain.Address.t/` `hash`.
  """

  use Indexer.Fetcher, restart: :permanent
  use Spandex.Decorators

  alias Explorer.Chain.Address.CoinBalance
  alias Explorer.Chain.{Block, Hash}
  alias Indexer.{BufferedTask, Tracer}
  alias Indexer.Fetcher.CoinBalance.Catchup.Supervisor, as: CoinBalanceSupervisor
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
    if CoinBalanceSupervisor.disabled?() do
      :ok
    else
      entries = Enum.map(balance_fields, &Helper.entry/1)

      BufferedTask.buffer(__MODULE__, entries, false)
    end
  end

  def child_spec(params) do
    Helper.child_spec(params, defaults(), __MODULE__)
  end

  @impl BufferedTask
  def init(initial, reducer, _) do
    {:ok, final} =
      CoinBalance.stream_unfetched_balances(
        initial,
        fn address_fields, acc ->
          address_fields
          |> Helper.entry()
          |> reducer.(acc)
        end,
        true
      )

    final
  end

  @impl BufferedTask
  @decorate trace(
              name: "fetch",
              resource: "Indexer.Fetcher.CoinBalance.Catchup.run/2",
              service: :indexer,
              tracer: Tracer
            )
  def run(entries, json_rpc_named_arguments) do
    Helper.run(entries, json_rpc_named_arguments, :catchup)
  end

  defp defaults do
    [
      flush_interval: :timer.seconds(3),
      max_batch_size: Application.get_env(:indexer, __MODULE__)[:batch_size] || @default_max_batch_size,
      max_concurrency: Application.get_env(:indexer, __MODULE__)[:concurrency] || @default_max_concurrency,
      task_supervisor: Indexer.Fetcher.CoinBalance.Catchup.TaskSupervisor,
      metadata: [fetcher: :coin_balance_catchup]
    ]
  end
end
