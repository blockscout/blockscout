defmodule Indexer.Fetcher.TokenInstance do
  @moduledoc """
  Fetches information about a token instance.
  """

  use Indexer.Fetcher
  use Spandex.Decorators

  alias Explorer.Chain
  alias Explorer.Token.InstanceMetadataRetriever
  alias Indexer.BufferedTask

  @behaviour BufferedTask

  @defaults [
    flush_interval: 300,
    max_batch_size: 1,
    max_concurrency: 10,
    task_supervisor: Indexer.Fetcher.TokenInstacne.TaskSupervisor
  ]

  @doc false
  def child_spec([init_options, gen_server_options]) do
    {state, mergeable_init_options} = Keyword.pop(init_options, :json_rpc_named_arguments)

    unless state do
      raise ArgumentError,
            ":json_rpc_named_arguments must be provided to `#{__MODULE__}.child_spec " <>
              "to allow for json_rpc calls when running."
    end

    merged_init_opts =
      @defaults
      |> Keyword.merge(mergeable_init_options)
      |> Keyword.put(:state, state)

    Supervisor.child_spec({BufferedTask, [{__MODULE__, merged_init_opts}, gen_server_options]}, id: __MODULE__)
  end

  @impl BufferedTask
  def init(initial_acc, reducer, _) do
    {:ok, acc} =
      Chain.stream_unfetched_token_instances(initial_acc, fn data, acc ->
        reducer.(data, acc)
      end)

    acc
  end

  @impl BufferedTask
  def run([%{token_contract_address_hash: token_contract_address_hash, token_id: token_id}], _json_rpc_named_arguments) do
    {:ok, metadata} = InstanceMetadataRetriever.fetch_metadata(token_contract_address_hash, token_id)

    params = %{
      token_id: token_id,
      token_contract_address_hash: token_contract_address_hash,
      metadata: metadata
    }

    {:ok, _result} = Chain.upsert_token_instance(params)

    :ok
  end

  @doc """
  Fetches token instance data asynchronously.
  """
  def async_fetch(data) do
    BufferedTask.buffer(__MODULE__, data)
  end
end
