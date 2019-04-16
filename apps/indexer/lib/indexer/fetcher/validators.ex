defmodule Indexer.Fetcher.Validators do
  @moduledoc """
  Fetch current validators list
  """

  use Indexer.Fetcher
  use Spandex.Decorators

  require Logger

  alias Explorer.Validator.MetadataRetriever
  alias Explorer.Chain
  alias Indexer.BufferedTask

  @behaviour BufferedTask

  @max_batch_size 10
  @max_concurrency 4
  @defaults [
    flush_interval: :timer.seconds(3),
    max_concurrency: @max_concurrency,
    max_batch_size: @max_batch_size,
    task_supervisor: Indexer.Fetcher.Validators.TaskSupervisor,
    metadata: [fetcher: :validators]
  ]

  @doc false
  def child_spec([init_options, gen_server_options]) do
    merged_init_opts =
      @defaults
      |> Keyword.merge(init_options)
      |> Keyword.put(:state, {0, []})

    Supervisor.child_spec({BufferedTask, [{__MODULE__, merged_init_opts}, gen_server_options]}, id: __MODULE__)
  end

  @impl BufferedTask
  def init(_initial, reducer, acc) do
    validators = MetadataRetriever.fetch_data()
    reducer.(validators, acc)
  end

  @impl BufferedTask
  def run([validators], _) do
    case Chain.import(%{validators: %{params: validators}}) do
      {:ok, _} -> :ok
      _ -> :retry
    end
  end
end
