defmodule Indexer.Fetcher.TokenInstance.Refetch do
  @moduledoc """
  Fetches information about a token instance, which is marked to be re-fetched.
  """

  use Indexer.Fetcher, restart: :permanent
  use Spandex.Decorators

  import Indexer.Fetcher.TokenInstance.Helper

  alias Explorer.Chain.Token.Instance
  alias Indexer.BufferedTask

  @behaviour BufferedTask

  @default_max_batch_size 10
  @default_max_concurrency 10
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
      Instance.stream_token_instances_marked_to_refetch(initial_acc, fn data, acc ->
        reducer.(data, acc)
      end)

    acc
  end

  @impl BufferedTask
  def run(token_instances, _) when is_list(token_instances) do
    token_instances
    |> batch_fetch_instances()

    :ok
  end

  defp defaults do
    [
      flush_interval: :infinity,
      max_concurrency: Application.get_env(:indexer, __MODULE__)[:concurrency] || @default_max_concurrency,
      max_batch_size: Application.get_env(:indexer, __MODULE__)[:batch_size] || @default_max_batch_size,
      task_supervisor: __MODULE__.TaskSupervisor
    ]
  end
end
