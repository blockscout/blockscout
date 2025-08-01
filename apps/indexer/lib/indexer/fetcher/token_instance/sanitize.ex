defmodule Indexer.Fetcher.TokenInstance.Sanitize do
  @moduledoc """
  Fetches information about a token instance.
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
      Instance.stream_token_instances_with_unfetched_metadata(initial_acc, fn data, acc ->
        reducer.(data, acc)
      end)

    acc
  end

  @impl BufferedTask
  def run(token_instances, _) when is_list(token_instances) do
    token_instances
    |> Enum.filter(fn %{contract_address_hash: hash, token_id: token_id} ->
      Instance.token_instance_with_unfetched_metadata?(token_id, hash)
    end)
    |> batch_fetch_instances()

    :ok
  end

  def async_fetch(token_instances) do
    token_instances =
      Enum.map(token_instances, fn %{token_contract_address_hash: hash, token_id: token_id} ->
        %{contract_address_hash: hash, token_id: token_id}
      end)

    BufferedTask.buffer(__MODULE__, token_instances, false, :infinity)
  end

  defp defaults do
    [
      flush_interval: :timer.seconds(5),
      max_concurrency: Application.get_env(:indexer, __MODULE__)[:concurrency] || @default_max_concurrency,
      max_batch_size: Application.get_env(:indexer, __MODULE__)[:batch_size] || @default_max_batch_size,
      poll: false,
      task_supervisor: __MODULE__.TaskSupervisor
    ]
  end
end
