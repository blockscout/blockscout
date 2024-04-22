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
          reducer.(data, acc)
        end
      )

    acc
  end

  @impl BufferedTask
  def run(token_instances, _json_rpc_named_arguments) when is_list(token_instances) do
    refetch_interval = Application.get_env(:indexer, __MODULE__)[:refetch_interval]

    token_instances
    |> Enum.filter(fn %{contract_address_hash: _hash, token_id: _token_id, updated_at: updated_at} ->
      updated_at
      |> DateTime.add(refetch_interval, :millisecond)
      |> DateTime.compare(DateTime.utc_now()) != :gt
    end)
    |> batch_fetch_instances()

    :ok
  end

  defp defaults do
    [
      flush_interval: :timer.minutes(10),
      max_concurrency: Application.get_env(:indexer, __MODULE__)[:concurrency] || @default_max_concurrency,
      max_batch_size: Application.get_env(:indexer, __MODULE__)[:batch_size] || @default_max_batch_size,
      task_supervisor: __MODULE__.TaskSupervisor
    ]
  end
end
