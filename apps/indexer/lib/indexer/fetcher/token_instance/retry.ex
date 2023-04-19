defmodule Indexer.Fetcher.TokenInstance.Retry do
  @moduledoc """
  Fetches information about a token instance.
  """

  use Indexer.Fetcher, restart: :permanent
  use Spandex.Decorators

  import Indexer.Fetcher.TokenInstance.Helper

  alias Explorer.Chain
  alias Indexer.BufferedTask

  @behaviour BufferedTask

  @default_max_batch_size 1
  @default_max_concurrency 10

  @doc false
  def child_spec([init_options, gen_server_options]) do
    {state, mergeable_init_options} = Keyword.pop(init_options, :json_rpc_named_arguments)

    unless state do
      raise ArgumentError,
            ":json_rpc_named_arguments must be provided to `#{__MODULE__}.child_spec " <>
              "to allow for json_rpc calls when running."
    end

    merged_init_opts =
      defaults()
      |> Keyword.merge(mergeable_init_options)
      |> Keyword.put(:state, state)

    Supervisor.child_spec({BufferedTask, [{__MODULE__, merged_init_opts}, gen_server_options]}, id: __MODULE__)
  end

  @impl BufferedTask
  def init(initial_acc, reducer, _) do
    {:ok, acc} =
      Chain.stream_token_instances_with_error(initial_acc, fn data, acc ->
        reducer.(data, acc)
      end)

    acc
  end

  @impl BufferedTask
  def run([%{contract_address_hash: hash, token_id: token_id, updated_at: updated_at}], _json_rpc_named_arguments) do
    refetch_interval = Application.get_env(:indexer, __MODULE__)[:refetch_interval]

    if updated_at
       |> DateTime.add(refetch_interval, :millisecond)
       |> DateTime.compare(DateTime.utc_now()) != :gt do
      fetch_instance(hash, token_id, true)
    end

    :ok
  end

  defp defaults do
    [
      flush_interval: :timer.minutes(10),
      max_concurrency: Application.get_env(:indexer, __MODULE__)[:concurrency] || @default_max_concurrency,
      max_batch_size: @default_max_batch_size,
      poll: true,
      task_supervisor: __MODULE__.TaskSupervisor
    ]
  end
end
