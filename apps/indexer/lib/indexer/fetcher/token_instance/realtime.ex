defmodule Indexer.Fetcher.TokenInstance.Realtime do
  @moduledoc """
  Fetches information about a token instance.
  """

  use Indexer.Fetcher, restart: :permanent
  use Spandex.Decorators

  import Indexer.Fetcher.TokenInstance.Helper

  alias Explorer.Chain.Token.Instance
  alias Indexer.BufferedTask

  @behaviour BufferedTask

  @default_max_batch_size 1
  @default_max_concurrency 10

  @errors_whitelisted_for_retry ["request error: 404", "request error: 500"]

  @doc false
  def child_spec([init_options, gen_server_options]) do
    merged_init_opts =
      defaults()
      |> Keyword.merge(init_options)
      |> Keyword.merge(state: [])

    Supervisor.child_spec({BufferedTask, [{__MODULE__, merged_init_opts}, gen_server_options]}, id: __MODULE__)
  end

  @impl BufferedTask
  def init(_, _, _) do
    {0, []}
  end

  @impl BufferedTask
  def run(token_instances, _) when is_list(token_instances) do
    retry? = Application.get_env(:indexer, Indexer.Fetcher.TokenInstance.Realtime)[:retry_with_cooldown?]

    token_instances_retry_map = token_instance_to_retry_map(retry?, token_instances)

    token_instances
    |> Enum.filter(fn %{contract_address_hash: hash, token_id: token_id} = instance ->
      instance[:retry?] || Instance.token_instance_with_unfetched_metadata?(token_id, hash)
    end)
    |> batch_fetch_instances()
    |> retry_some_instances(retry?, token_instances_retry_map)

    :ok
  end

  @doc """
  Fetches token instance data asynchronously.
  """
  def async_fetch(data) do
    async_fetch(data, __MODULE__.Supervisor.disabled?())
  end

  def async_fetch(_data, true), do: :ok

  def async_fetch(token_transfers, _disabled?) when is_list(token_transfers) do
    data =
      token_transfers
      |> Enum.reject(fn token_transfer -> is_nil(token_transfer.token_ids) end)
      |> Enum.map(fn token_transfer ->
        Enum.map(token_transfer.token_ids, fn token_id ->
          %{
            contract_address_hash: token_transfer.token_contract_address_hash,
            token_id: token_id
          }
        end)
      end)
      |> List.flatten()
      |> Enum.uniq()

    BufferedTask.buffer(__MODULE__, data, true)
  end

  def async_fetch(data, _disabled?) do
    BufferedTask.buffer(__MODULE__, data, true)
  end

  @spec retry_some_instances([map()], boolean(), map()) :: any()
  defp retry_some_instances(token_instances, true, token_instances_retry_map) do
    token_instances_to_refetch =
      Enum.flat_map(token_instances, fn
        %Instance{metadata: nil, error: error} = instance
        when error in @errors_whitelisted_for_retry ->
          if token_instances_retry_map[{instance.token_contract_address_hash.bytes, instance.token_id}] do
            []
          else
            [
              %{
                contract_address_hash: instance.token_contract_address_hash,
                token_id: instance.token_id,
                retry?: true
              }
            ]
          end

        _ ->
          []
      end)

    if token_instances_to_refetch != [] do
      timeout = Application.get_env(:indexer, Indexer.Fetcher.TokenInstance.Realtime)[:retry_timeout]
      Process.send_after(__MODULE__, {:buffer, token_instances_to_refetch, false}, timeout)
    end
  end

  defp retry_some_instances(_, _, _), do: nil

  defp token_instance_to_retry_map(false, _token_instances), do: nil

  defp token_instance_to_retry_map(true, token_instances) do
    token_instances
    |> Enum.flat_map(fn
      %{contract_address_hash: hash, token_id: token_id, retry?: true} ->
        [{{hash.bytes, token_id}, true}]

      _ ->
        []
    end)
    |> Enum.into(%{})
  end

  defp defaults do
    [
      flush_interval: 100,
      max_concurrency: Application.get_env(:indexer, __MODULE__)[:concurrency] || @default_max_concurrency,
      max_batch_size: Application.get_env(:indexer, __MODULE__)[:batch_size] || @default_max_batch_size,
      poll: false,
      task_supervisor: __MODULE__.TaskSupervisor
    ]
  end
end
