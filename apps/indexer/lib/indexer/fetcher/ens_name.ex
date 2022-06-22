defmodule Indexer.Fetcher.ENSName do
  @moduledoc """
  Fetches information about an ENS name of an address.
  """

  use Indexer.Fetcher
  use Spandex.Decorators

  require Logger

  alias Explorer.Chain
  alias Explorer.ENS.NameRetriever
  alias Indexer.BufferedTask

  @behaviour BufferedTask

  @defaults [
    flush_interval: 300,
    max_batch_size: 1,
    max_concurrency: 100,
    task_supervisor: Indexer.Fetcher.ENSName.TaskSupervisor,
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
    Logger.info("Start refreshing ENS names for addresses in DB.")
    {:ok, acc} =
      Chain.stream_address_hashes(initial_acc, fn data, acc ->
        reducer.(data, acc)
      end)

    acc
  end

  @impl BufferedTask
  def run([address_hash], _json_rpc_named_arguments) do
    case NameRetriever.fetch_name_of(to_string(address_hash)) do
      {:ok, name} ->
        params = %{
          address_hash: address_hash,
          name: name,
          metadata: %{type: "ens"}
        }

        {:ok, _result} = Chain.upsert_address_name(params)
        :ok

      {:error, error} ->
        Logger.debug(
          [
            "failed to fetch ENS name for #{inspect({to_string(address_hash)})}: ",
            inspect(error)
          ],
          fetcher: :address_names
        )

        :ok
    end

    :ok
  end

  @doc """
  Fetches ENS name data asynchronously.
  """
  def async_fetch(addresses) when is_list(addresses) do
    data =
      addresses
      |> Enum.uniq()

    BufferedTask.buffer(__MODULE__, data)
  end

  def async_fetch(data) do
    BufferedTask.buffer(__MODULE__, data)
  end
end
