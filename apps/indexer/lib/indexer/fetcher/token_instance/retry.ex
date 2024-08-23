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

  @default_max_batch_size 10
  @default_max_concurrency 10
  @max_queue_size 5000
  @busy_waiting_timeout 500

  @doc false
  def child_spec([init_options, gen_server_options]) do
    merged_init_opts =
      defaults()
      |> Keyword.merge(init_options)
      |> Keyword.merge(state: [])

    Supervisor.child_spec({BufferedTask, [{__MODULE__, merged_init_opts}, gen_server_options]}, id: __MODULE__)
  end

  @impl BufferedTask
  def init(initial_acc, reducer, _) do
    {:ok, acc} =
      Chain.stream_token_instances_with_error(
        initial_acc,
        fn data, acc ->
          reduce_if_queue_is_not_full(data, acc, reducer)
        end
      )

    acc
  end

  defp reduce_if_queue_is_not_full(data, acc, reducer) do
    bound_queue = GenServer.call(__MODULE__, :state).bound_queue

    if bound_queue.size >= @max_queue_size or (bound_queue.maximum_size && bound_queue.size >= bound_queue.maximum_size) do
      :timer.sleep(@busy_waiting_timeout)

      reduce_if_queue_is_not_full(data, acc, reducer)
    else
      reducer.(data, acc)
    end
  end

  @impl BufferedTask
  def run(token_instances, _json_rpc_named_arguments) when is_list(token_instances) do
    batch_fetch_instances(token_instances)

    :ok
  end

  defp defaults do
    [
      flush_interval: :timer.seconds(10),
      max_concurrency: Application.get_env(:indexer, __MODULE__)[:concurrency] || @default_max_concurrency,
      max_batch_size: Application.get_env(:indexer, __MODULE__)[:batch_size] || @default_max_batch_size,
      task_supervisor: __MODULE__.TaskSupervisor
    ]
  end
end
