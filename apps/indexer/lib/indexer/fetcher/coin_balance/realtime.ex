defmodule Indexer.Fetcher.CoinBalance.Realtime do
  @moduledoc """
  Separate version of `Indexer.Fetcher.CoinBalance.Catchup` for fetching balances from realtime block fetcher
  """

  use Indexer.Fetcher, restart: :permanent
  use Spandex.Decorators

  alias Explorer.Chain.{Block, Hash}
  alias Indexer.{BufferedTask, Tracer}
  alias Indexer.Fetcher.CoinBalance.Helper
  alias Indexer.Fetcher.CoinBalance.Realtime.Supervisor, as: CoinBalanceSupervisor

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

      BufferedTask.buffer(__MODULE__, entries)
    end
  end

  @doc false
  # credo:disable-for-next-line Credo.Check.Design.DuplicatedCode
  def child_spec([init_options, gen_server_options]) do
    {state, mergeable_init_options} = Keyword.pop(init_options, :json_rpc_named_arguments)

    unless state do
      raise ArgumentError,
            ":json_rpc_named_arguments must be provided to `#{__MODULE__}.child_spec " <>
              "to allow for json_rpc calls when running."
    end

    merged_init_options =
      defaults()
      |> Keyword.merge(mergeable_init_options)
      |> Keyword.put(:state, state)

    Supervisor.child_spec({BufferedTask, [{__MODULE__, merged_init_options}, gen_server_options]}, id: __MODULE__)
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
    Helper.run(entries, json_rpc_named_arguments)
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
